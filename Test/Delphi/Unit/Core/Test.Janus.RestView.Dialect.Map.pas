{
  ------------------------------------------------------------------------------
  Janus
  Modern Object-Relational Mapping (ORM) framework for Delphi.

  SPDX-License-Identifier: MIT
  Copyright (c) 2016-2026 Isaque Pinheiro

  Licensed under the MIT License.
  See the LICENSE file in the project root for full license information.
  ------------------------------------------------------------------------------
}

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
}

/// <summary> WHICH DIALECT THE REST SERVER WRITES A [View] IN. Issue #357.
///
///  THE SECOND DIALECT MAP, AND THE ONE #355 COULD NOT REACH.
///  TRESTViewManager._MapDriverToFluent turns a DataEngine TDriverName into the
///  FluentSQL dialect that serializes CREATE VIEW / DROP VIEW. It is not a
///  generator, so the abstract SerializationDialect that #355 planted in
///  TDMLGeneratorAbstract does not govern it, and nothing accused it of
///  diverging. Test.Janus.DML.Dialect.Wiring pins the OTHER map; these clauses
///  pin this one, in the same project on purpose, so that anyone who decides to
///  "unify the two maps" trips both fixtures at once instead of neither.
///
///  WHAT WAS WRONG. Measured at a286f38 by walking all nineteen TDriverName
///  members through the PUBLIC TRESTViewManager.EnsureView:
///    - dnInterbase raised ENotSupportedException, so no view was ever created
///      for an InterBase connection;
///    - the else answered dbnSQLite, so NINE drivers - dnInformix, dnADS,
///      dnASA, dnFirebase, dnAbsoluteDB, dnMongoDB, dnElevateDB, dnNexusDB,
///      dnMemory - had their view written with SQLite backticks IN SILENCE.
///  The raising one at least announces itself; the silent nine do not, which is
///  why the else is the worse half of this defect.
///
///  WHY THE CLAUSES ARE READ THROUGH THE CONNECTION AND NOT THROUGH THE MAP.
///  _MapDriverToFluent is private and EnsureView returns nothing - it hands the
///  DDL to IDBConnection.ExecuteDirect. So the double records what it was asked
///  to execute (TFakeConnection.ExecutedDDL) and the clauses read the answer the
///  same way a real server would receive it. A clause that called the map
///  directly would prove the map and not the path; the path is
///  GET on a [View] resource -> Janus.Server.Resource.pas:584-585 ->
///  EnsureViewLazy -> EnsureView -> this map, in all five server adapters.
///
///  WHY THIS PROJECT AND NOT ONE OF THE FOUR REST ONES. The unit under test is
///  compiled by five of the seven test projects (Units, RESTHorse, RESTMARS,
///  RESTOracle, RESTWiRL), so the fixture had a choice. Nothing here needs a
///  listening HTTP server or a live database: the whole measurement is
///  TDriverName in, DDL text out, through a double. The four REST projects exist
///  to exercise the wire, and one of them - RESTOracle - cannot even run on a
///  machine without OCI. TFakeConnection, the only double in the tree that can
///  impersonate all nineteen drivers, lives in this project and only in this
///  project (grepped: Test.Janus.DML.Generator.SQLite appears in
///  Janus.Tests.Units.dpr and in no other .dpr). </summary>
unit Test.Janus.RestView.Dialect.Map;

interface

uses
  SysUtils,
  TypInfo,
  DUnitX.TestFramework,
  DataEngine.FactoryInterfaces,
  FluentSQL,
  FluentSQL.Interfaces,
  Janus.Server.RestView.Manager,
  Janus.Model.Client,
  Test.Janus.DML.Generator.SQLite;

type
  [TestFixture]
  TTestRestViewDialectMap = class
  private
    /// <summary> Drives one TDriverName through the public EnsureView and
    ///  reports both halves of the outcome: everything the connection was asked
    ///  to execute, and the refusal if there was one. Both are needed in the
    ///  same call - "it refused" is only half the claim, "and it executed
    ///  nothing while refusing" is the other half, and a map that raised AFTER
    ///  handing a DROP to the server would satisfy the first alone. </summary>
    function RunEnsureView(const ADriver: TDriverName;
      out AExecutedDDL: String): String;
    function DDLFor(const ADriver: TDriverName): String;
    function RefusalFor(const ADriver: TDriverName): String;
    function NameOf(const ADriver: TDriverName): String;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure InterbaseGetsItsViewWrittenInFirebirdQuotingInsteadOfRaising;
    [Test]
    procedure MongoDBIsRefusedByNameInsteadOfBeingHandedSQLiteDDL;
    [Test]
    procedure ADSIsRefusedByNameInsteadOfBeingHandedSQLiteDDL;
    [Test]
    procedure EveryDriverWithoutADDLDialectIsNamedInItsOwnRefusal;
    [Test]
    procedure TheEightDriversThatAlreadyWorkedStillEmitTheirOwnViewDDL;
    [Test]
    procedure MySQLAndMariaDBKeepTheDialectTheDMLSideRefused;
    [Test]
    procedure DB2IsStillRefusedByFluentSQLAndTheRefusalNamesTheDatabase;
    [Test]
    procedure TheNineteenDriversPartitionWithNothingLeftSilent;
    [Test]
    procedure ThisMapWritesTheWrapperAndNotTheQueryInsideIt;
  end;

implementation

const
  /// <summary> THE POPULATION, ENUMERATED, NOT SAMPLED. TDriverName has
  ///  nineteen members (DataEngine.FactoryInterfaces.pas:50-53) and every one of
  ///  them appears in exactly one of the three arrays below. The arrays are what
  ///  make "the else swallowed NINE drivers" a count instead of an impression.
  ///
  ///  CDialectDrivers - a DDL serializer answers for them and a view is built.
  ///  CRegistryRefusals - the map has a clause, but FluentSQL has no DDL
  ///    serializer registered for the dialect it names, so FluentSQL refuses.
  ///  CMapRefusals - no dialect at all; the map itself refuses, by name.
  ///  8 + 1 + 9 + dnInterbase (pinned on its own, below) = 19. </summary>
  CDialectDrivers: array[0..7] of TDriverName = (
    dnMSSQL, dnMySQL, dnFirebird, dnFirebird3, dnSQLite, dnOracle,
    dnPostgreSQL, dnMariaDB);

  /// The wrapper each of the eight above must still write. Measured at a286f38,
  /// BEFORE this repair, which is what makes them a control: if one of these
  /// moves, the repair broke a dialect that already worked.
  CDialectWrapper: array[0..7] of String = (
    'CREATE VIEW [client] AS',
    'CREATE OR REPLACE VIEW `client` AS',
    'CREATE VIEW "client" AS',
    'CREATE VIEW "client" AS',
    'CREATE VIEW `client` AS',
    'CREATE OR REPLACE VIEW "CLIENT" AS',
    'CREATE OR REPLACE VIEW "client" AS',
    'CREATE OR REPLACE VIEW `client` AS');

  CRegistryRefusals: array[0..0] of TDriverName = (dnDB2);

  CMapRefusals: array[0..8] of TDriverName = (
    dnInformix, dnADS, dnASA, dnFirebase, dnAbsoluteDB, dnMongoDB,
    dnElevateDB, dnNexusDB, dnMemory);

{ TTestRestViewDialectMap }

procedure TTestRestViewDialectMap.Setup;
begin
  TRESTViewManager.ClearCache;
end;

procedure TTestRestViewDialectMap.TearDown;
begin
  TRESTViewManager.ClearCache;
end;

function TTestRestViewDialectMap.NameOf(const ADriver: TDriverName): String;
begin
  Result := GetEnumName(TypeInfo(TDriverName), Ord(ADriver));
end;

function TTestRestViewDialectMap.RunEnsureView(const ADriver: TDriverName;
  out AExecutedDDL: String): String;
var
  LFake: TFakeConnection;
  LConnection: IDBConnection;
  LSelect: IFluentSQL;
begin
  Result := '';
  AExecutedDDL := '';
  LFake := TFakeConnection.Create(ADriver);
  /// The object reference above stays valid because this interface holds the
  /// only reference count on it for the whole call.
  LConnection := LFake;
  /// dbnSQLite on the SELECT deliberately, for every driver. The select carries
  /// its own dialect and the map under test does not touch it - see
  /// ThisMapWritesTheWrapperAndNotTheQueryInsideIt. Holding it fixed is what
  /// makes any difference in the emitted text attributable to the map.
  LSelect := FluentSQL.Query(dbnSQLite)
    .Select('client_name')
    .From('client');
  try
    TRESTViewManager.EnsureView(Tclient, LSelect, LConnection);
  except
    on E: Exception do
      Result := E.ClassName + ': ' + E.Message;
  end;
  AExecutedDDL := LFake.ExecutedDDL;
end;

function TTestRestViewDialectMap.DDLFor(const ADriver: TDriverName): String;
var
  LRefusal: String;
begin
  LRefusal := RunEnsureView(ADriver, Result);
  if LRefusal <> '' then
    Assert.Fail(NameOf(ADriver) + ' must build a view, it refused with ' + LRefusal);
end;

function TTestRestViewDialectMap.RefusalFor(const ADriver: TDriverName): String;
var
  LExecuted: String;
begin
  Result := RunEnsureView(ADriver, LExecuted);
  if Result = '' then
    Assert.Fail(NameOf(ADriver) + ' must refuse, it silently emitted [' +
      LExecuted + ']');
end;

/// <summary> THE ENTRY THIS MAP HAD POINTING AT A DIALECT THAT CANNOT WRITE DDL.
///  dbnInterbase exists in TFluentSQLDriver but its {$DEFINE} is off in
///  FluentSQL.inc and _RegisterInterbase never calls RegisterDDLSerialize
///  (FluentSQL.Register.pas:175-181): there is no
///  FluentSQL.DDL.Serialize.Interbase.pas to register, so turning the {$DEFINE}
///  on would not have helped. Measured at a286f38: every InterBase [View] GET
///  came out as ENotSupportedException and no view was ever created.
///
///  dbnFirebird is what the DML side already declares for InterBase
///  (Janus.DML.Generator.InterBase.pas:61-64) and it writes the SQL-standard
///  double quoting InterBase shares with Firebird. The clause pins BOTH halves:
///  that a view is now written, and that it is not written in the backticks the
///  else would have supplied - because "stopped raising" would also be satisfied
///  by silently falling into the SQLite default, which is the other bug.
///
///  NOT MEASURED: acceptance by a live InterBase server. There is none here.
///  What is measured is the text, one frame below the call the route makes. </summary>
procedure TTestRestViewDialectMap.InterbaseGetsItsViewWrittenInFirebirdQuotingInsteadOfRaising;
var
  LDDL: String;
begin
  LDDL := DDLFor(dnInterbase);
  Assert.Contains(LDDL, 'CREATE VIEW "client" AS',
    'InterBase must get a view written in the double quoting it accepts');
  Assert.Contains(LDDL, 'DROP VIEW IF EXISTS "client"',
    'InterBase has no CREATE OR REPLACE VIEW, so the DROP must come first');
  Assert.DoesNotContain(LDDL, '`client`',
    'InterBase must not be handed the SQLite backticks the old else supplied');
end;

/// <summary> THE DRIVER THE APPROVED DESIGN WANTED MAPPED TO dbnMongoDB, AND THE
///  MEASUREMENT THAT SAID NO. The design's reason was "dnMongoDB has a DDL
///  serializer registered". The registration is real
///  (FluentSQL.Register.pas:219) - the inference from it is not.
///  TFluentDDLSerializerMongoDB (FluentSQL.DDL.Serialize.MongoDB.pas:28-40)
///  descends from TFluentDDLSerializeAbstract and overrides six DDL verbs:
///  CreateTable, DropTable, CreateIndex, DropIndex, AlterTableRenameTable,
///  TruncateTable. CreateView and DropView are not among them, and the base
///  raises EAbstractError for both (FluentSQL.DDL.SerializeAbstract.pas:404-412).
///  So dbnMongoDB would not have emitted Mongo view DDL; it would have raised
///  EAbstractError naming a SERIALIZER CLASS instead of the driver the operator
///  configured - and MongoDB has no SQL views to create either way.
///
///  The mutation table records this: putting the approved dnMongoDB -> dbnMongoDB
///  back kills this clause, and it kills it with EAbstractError, not with a
///  Mongo CREATE VIEW.
///
///  The clause asserts the driver's own name is in the message. "It raises" is
///  not the fix - dnInterbase raised before this repair and that was the defect;
///  what makes the refusal useful is that the operator reads which of the
///  nineteen drivers has no dialect. </summary>
procedure TTestRestViewDialectMap.MongoDBIsRefusedByNameInsteadOfBeingHandedSQLiteDDL;
var
  LRefusal: String;
  LExecuted: String;
begin
  LRefusal := RunEnsureView(dnMongoDB, LExecuted);
  Assert.AreEqual('', LExecuted,
    'dnMongoDB must not receive SQLite DDL in silence - it did until #357');
  Assert.Contains(LRefusal, 'ENotSupportedException',
    'the refusal must be the class this condition already raises for dnDB2');
  Assert.Contains(LRefusal, 'dnMongoDB',
    'the refusal must name the driver that arrived');
end;

/// <summary> THE SAME CLAIM FOR A DRIVER THAT HAS NO DIALECT AT ALL, PINNED
///  SEPARATELY. dnADS is not a near miss like dnMongoDB: dbnADS exists in
///  TFluentSQLDriver but there is no unit for it anywhere in FluentSQL\Source
///  \Drivers and no {$DEFINE} it could be given (FluentSQL.inc says so in
///  prose). Pinned on its own so that a change which special-cases dnMongoDB
///  alone still leaves the other eight of the else uncovered and visibly so. </summary>
procedure TTestRestViewDialectMap.ADSIsRefusedByNameInsteadOfBeingHandedSQLiteDDL;
var
  LRefusal: String;
  LExecuted: String;
begin
  LRefusal := RunEnsureView(dnADS, LExecuted);
  Assert.AreEqual('', LExecuted,
    'dnADS must not receive SQLite DDL in silence - it did until #357');
  Assert.Contains(LRefusal, 'ENotSupportedException',
    'the refusal must be the class this condition already raises for dnDB2');
  Assert.Contains(LRefusal, 'dnADS',
    'the refusal must name the driver that arrived');
end;

/// <summary> THE WHOLE ELSE, ENUMERATED. The two clauses above pin one near miss
///  and one plain miss; this one refuses to let the other seven be taken on
///  faith. Each of the nine must name ITSELF - a refusal that named a fixed
///  driver, or none, would pass a "does it raise" clause and tell the operator
///  nothing. </summary>
procedure TTestRestViewDialectMap.EveryDriverWithoutADDLDialectIsNamedInItsOwnRefusal;
var
  LFor: Integer;
  LRefusal: String;
begin
  for LFor := Low(CMapRefusals) to High(CMapRefusals) do
  begin
    LRefusal := RefusalFor(CMapRefusals[LFor]);
    Assert.Contains(LRefusal, NameOf(CMapRefusals[LFor]),
      'the refusal for ' + NameOf(CMapRefusals[LFor]) + ' must name it');
  end;
end;

/// <summary> THE POSITIVE CONTROL. Eight drivers already produced the right
///  wrapper at a286f38 and must go on producing exactly it. Without this clause
///  "InterBase stopped raising" and "the else refuses by name" would both still
///  pass if the repair had, say, routed everything through one dialect or turned
///  the whole map into a refusal. The expected strings were measured BEFORE the
///  repair, which is what makes them a control and not a restatement of the new
///  code. Note that three different quoting conventions and two different
///  CREATE forms appear among them: any collapse into one shows up here. </summary>
procedure TTestRestViewDialectMap.TheEightDriversThatAlreadyWorkedStillEmitTheirOwnViewDDL;
var
  LFor: Integer;
begin
  for LFor := Low(CDialectDrivers) to High(CDialectDrivers) do
    Assert.Contains(DDLFor(CDialectDrivers[LFor]), CDialectWrapper[LFor],
      NameOf(CDialectDrivers[LFor]) + ' must keep writing the view it always wrote');
end;

/// <summary> THE CLAUSE AGAINST THE OBVIOUS SYMMETRY. The DML side declares
///  dbnMSSQL for MySQL - measured and deliberate, because the MySQL DML
///  serializer rewrites ':pN' to '?' over the whole string
///  (FluentSQL.SerializeMySQL.pas:39-52) and the #337 guard refuses that. Sooner
///  or later somebody will read the two maps side by side and "unify" them.
///
///  That rewrite is in the DML AsString and is guarded by Assigned(AAST.Params);
///  DDL has no params, so it never runs on this path. Here the map picks the DDL
///  serializer, and dbnMySQL writes CREATE OR REPLACE VIEW with backticks, which
///  is what MySQL and MariaDB accept. Unifying was MEASURED, by mutating the
///  dnMySQL line to dbnMSSQL and watching this clause die: it sends
///  'CREATE OR ALTER VIEW [client] AS ...' to a MySQL server - MSSQL brackets
///  and MSSQL's spelling of OR REPLACE, since dnMySQL is in
///  _SupportsCreateOrReplace. The clause pins both halves: the backticked
///  OR REPLACE must be there, and the brackets must not. </summary>
procedure TTestRestViewDialectMap.MySQLAndMariaDBKeepTheDialectTheDMLSideRefused;
var
  LMySQL: String;
  LMariaDB: String;
begin
  LMySQL := DDLFor(dnMySQL);
  LMariaDB := DDLFor(dnMariaDB);
  Assert.Contains(LMySQL, 'CREATE OR REPLACE VIEW `client` AS',
    'dnMySQL must keep the MySQL DDL dialect, not follow the DML side');
  Assert.DoesNotContain(LMySQL, '[client]',
    'MSSQL brackets at a MySQL server is what unifying the two maps would cost');
  Assert.Contains(LMariaDB, 'CREATE OR REPLACE VIEW `client` AS',
    'dnMariaDB rides the same clause as dnMySQL and must move with it');
  Assert.DoesNotContain(LMariaDB, '[client]',
    'MSSQL brackets at a MariaDB server is the same regression');
end;

/// <summary> THE ENTRY THAT STAYED, AND STAYED RAISING. dbnDB2 sits where
///  dbnInterbase sat - {$DEFINE} off, no RegisterDDLSerialize
///  (FluentSQL.Register.pas:183-189), no serializer unit - so it refuses. It
///  keeps its own clause in the map rather than falling into the else because
///  FluentSQL's own refusal already names the database, and because "mapped
///  dialect whose serializer is not compiled in" is a different fact from "no
///  dialect for this driver". Unlike InterBase there is no measured neighbour to
///  borrow from. This clause is green on both sides of the repair on purpose:
///  it is here so that the day someone gives DB2 a serializer, or moves it into
///  the else, the change is a deliberate one. </summary>
procedure TTestRestViewDialectMap.DB2IsStillRefusedByFluentSQLAndTheRefusalNamesTheDatabase;
var
  LRefusal: String;
begin
  LRefusal := RefusalFor(dnDB2);
  Assert.Contains(LRefusal, 'ENotSupportedException',
    'FluentSQL refuses an unregistered DDL serializer with this class');
  Assert.Contains(LRefusal, 'DB2',
    'the refusal must name the database, which is why the clause was kept');
end;

/// <summary> NOTHING LEFT SILENT, COUNTED. Every one of the nineteen either
///  writes a view or refuses, and no driver does both - a map that raised after
///  handing the DROP to the connection would leave a real server with the old
///  view dropped and no new one. Before this repair the split was seventeen
///  emitting and two refusing, and eight of those seventeen were emitting SQLite
///  for a server that is not SQLite. </summary>
procedure TTestRestViewDialectMap.TheNineteenDriversPartitionWithNothingLeftSilent;
var
  LDriver: TDriverName;
  LRefusal: String;
  LExecuted: String;
  LEmitted: Integer;
  LRefused: Integer;
begin
  LEmitted := 0;
  LRefused := 0;
  for LDriver := Low(TDriverName) to High(TDriverName) do
  begin
    LRefusal := RunEnsureView(LDriver, LExecuted);
    if LRefusal = '' then
    begin
      Inc(LEmitted);
      Assert.Contains(LExecuted, 'CREATE',
        NameOf(LDriver) + ' did not refuse, so it must have written a view');
    end
    else
    begin
      Inc(LRefused);
      Assert.AreEqual('', LExecuted,
        NameOf(LDriver) + ' must not execute DDL and then refuse');
    end;
  end;
  Assert.AreEqual(9, LEmitted,
    'nine drivers have a DDL dialect: the eight that always did, plus InterBase');
  Assert.AreEqual(10, LRefused,
    'ten refuse: dnDB2 through FluentSQL and the nine the else used to swallow');
end;

/// <summary> THE BOUNDARY OF THIS MAP, PINNED SO THE NEXT REPAIR DOES NOT
///  OVERREACH. The map chooses the dialect of the CREATE VIEW / DROP VIEW
///  WRAPPER. The SELECT that goes inside carries the dialect of the IFluentSQL
///  the caller built and this map never touches it. Measured: across all the
///  drivers that emit, the wrapper differs in three quoting conventions and two
///  CREATE forms while the embedded query is byte-identical. Somebody reading
///  "the REST server picks the wrong dialect" could reasonably conclude the
///  SELECT is wrong too and start rewriting it here; it is not, and this is
///  where that reading dies. </summary>
procedure TTestRestViewDialectMap.ThisMapWritesTheWrapperAndNotTheQueryInsideIt;
const
  CQuery = 'SELECT client_name FROM client';
var
  LFor: Integer;
  LDDL: String;
begin
  for LFor := Low(CDialectDrivers) to High(CDialectDrivers) do
  begin
    LDDL := DDLFor(CDialectDrivers[LFor]);
    Assert.Contains(LDDL, CQuery,
      NameOf(CDialectDrivers[LFor]) +
      ' must embed the query the caller built, untouched by this map');
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRestViewDialectMap);

end.
