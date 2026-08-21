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

/// <summary> WHICH FluentSQL DIALECT EACH DML GENERATOR SERIALIZES THROUGH.
///  Issue #355.
///
///  TDMLGeneratorAbstract keeps the dialect in FFluentSQLDriver and the only
///  reader of that field is CreateFluentSQL - so every statement FluentSQL
///  renders for Janus is rendered in whatever dialect that field holds. Before
///  this fixture the field was set by TWO constructors out of the whole tree
///  and the rest inherited the ENUM'S ZERO VALUE, which is not "no dialect" but
///  dbnMSSQL. The repair moved the choice into the base class through an
///  ABSTRACT class function, so a descendant can no longer stay silent: it
///  either names its dialect or it does not compile.
///
///  ONE CLAUSE PER GENERATOR, and that is deliberate. Five of the twelve emit
///  byte-identical SQL whichever of the two dialects they are given, so a
///  single clause covering all twelve would be killed by a mutation in any one
///  of them and would prove nothing about the others. Each sibling is pinned on
///  its own so that mutating ONE kills ITS clause and only its clause. </summary>
unit Test.Janus.DML.Dialect.Wiring;

interface

uses
  SysUtils,
  Classes,
  DB,
  Rtti,
  TypInfo,
  Generics.Collections,
  DUnitX.TestFramework,
  DataEngine.FactoryInterfaces,
  FluentSQL,
  FluentSQL.Interfaces,
  Janus.DML.Generator,
  Janus.DML.Generator.ADS,
  Janus.DML.Generator.AbsoluteDB,
  Janus.DML.Generator.ElevateDB,
  Janus.DML.Generator.Firebird,
  Janus.DML.Generator.Firebird3,
  Janus.DML.Generator.InterBase,
  Janus.DML.Generator.MSSQL,
  Janus.DML.Generator.MySQL,
  Janus.DML.Generator.NexusDB,
  Janus.DML.Generator.Oracle,
  Janus.DML.Generator.PostgreSQL,
  Janus.DML.Generator.SQLite,
  Janus.Model.Client,
  Janus.Model.Master,
  Test.Janus.DML.Generator.SQLite;

type
  TDMLGeneratorClass = class of TDMLGeneratorAbstract;

  [TestFixture]
  TTestDMLDialectWiring = class
  private
    FConnection: IDBConnection;
    FRow: Tclient;
    FParams: TParams;
    FChanges: TDictionary<String, String>;
    function NewGenerator(const AClass: TDMLGeneratorClass): TDMLGeneratorAbstract;
    /// <summary> The dialect the generator ACTUALLY holds, plus the four
    ///  statements it renders through FluentSQL. The statements are exercised
    ///  in the same clause as the dialect on purpose: naming a dialect that
    ///  FluentSQL has not registered is not a text difference, it is an
    ///  EFluentSQLDriverNotRegistered on every DML the generator emits, and
    ///  the clause has to fail on that too. </summary>
    procedure AssertGenerator(const AClass: TDMLGeneratorClass;
      const AExpected: TFluentSQLDriver; const AName: String);
    function SelectOf(const AClass: TDMLGeneratorClass): String;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure DialectOf_ADS;
    [Test]
    procedure DialectOf_AbsoluteDB;
    [Test]
    procedure DialectOf_ElevateDB;
    [Test]
    procedure DialectOf_Firebird;
    [Test]
    procedure DialectOf_Firebird3;
    [Test]
    procedure DialectOf_InterBase;
    [Test]
    procedure DialectOf_MSSQL;
    [Test]
    procedure DialectOf_MySQL;
    [Test]
    procedure DialectOf_NexusDB;
    [Test]
    procedure DialectOf_Oracle;
    [Test]
    procedure DialectOf_PostgreSQL;
    [Test]
    procedure DialectOf_SQLite;

    [Test]
    procedure OracleWritesTheJoinAliasWithoutAS;
    [Test]
    procedure TheOtherElevenStillWriteTheJoinAliasWithAS;
    [Test]
    procedure TheFirebirdSelectIsWhatTheSQLiteDialectWouldHaveWritten;
  end;

implementation

type
  /// <summary> FFluentSQLDriver is protected and CreateFluentSQL is the only
  ///  reader of it in the whole of Source. A descendant is the only legitimate
  ///  way to read the field, and _BuildSelectSQL is likewise protected - it is
  ///  the SELECT path that goes through FluentSQL, as opposed to the pagination
  ///  and the WHERE, which every generator writes itself. </summary>
  TDialectReader = class(TDMLGeneratorAbstract)
  public
    function Driver: TFluentSQLDriver;
    function SelectSQL(AClass: TClass): String;
  end;

function TDialectReader.Driver: TFluentSQLDriver;
begin
  Result := FFluentSQLDriver;
end;

function TDialectReader.SelectSQL(AClass: TClass): String;
begin
  Result := _BuildSelectSQL(AClass, -1).AsString;
end;

{ TTestDMLDialectWiring }

procedure TTestDMLDialectWiring.Setup;
begin
  FConnection := TFakeConnection.Create(dnSQLite);
  FRow := Tclient.Create;
  FRow.client_id := 7;
  FRow.client_name := 'NAME';
  FParams := TParams.Create(nil);
  FParams.CreateParam(ftInteger, 'client_id', ptInput).AsInteger := 7;
  FChanges := TDictionary<String, String>.Create;
  FChanges.Add('client_name', 'client_name');
end;

procedure TTestDMLDialectWiring.TearDown;
begin
  FChanges.Free;
  FParams.Free;
  FRow.Free;
  FConnection := nil;
end;

function TTestDMLDialectWiring.NewGenerator(
  const AClass: TDMLGeneratorClass): TDMLGeneratorAbstract;
begin
  Result := AClass.Create;
  Result.SetConnection(FConnection);
end;

function TTestDMLDialectWiring.SelectOf(const AClass: TDMLGeneratorClass): String;
var
  LGenerator: TDMLGeneratorAbstract;
begin
  LGenerator := NewGenerator(AClass);
  try
    Result := LGenerator.GeneratorSelectAll(Tmaster, -1, -1);
  finally
    LGenerator.Free;
  end;
end;

procedure TTestDMLDialectWiring.AssertGenerator(const AClass: TDMLGeneratorClass;
  const AExpected: TFluentSQLDriver; const AName: String);
var
  LGenerator: TDMLGeneratorAbstract;
begin
  LGenerator := NewGenerator(AClass);
  try
    Assert.AreEqual(GetEnumName(TypeInfo(TFluentSQLDriver), Ord(AExpected)),
                    GetEnumName(TypeInfo(TFluentSQLDriver),
                                Ord(TDialectReader(LGenerator).Driver)),
      AName + ' must serialize through the dialect it declares');
    /// A dialect FluentSQL has not registered does not change the text - it
    /// raises EFluentSQLDriverNotRegistered on every one of these four.
    Assert.WillNotRaiseAny(
      procedure
      begin
        LGenerator.GeneratorInsert(FRow);
        LGenerator.GeneratorUpdate(FRow, FParams, FChanges);
        LGenerator.GeneratorDelete(FRow, FParams);
        TDialectReader(LGenerator).SelectSQL(Tmaster);
      end,
      AName + ' must not ask FluentSQL for a dialect it cannot serialize');
  finally
    LGenerator.Free;
  end;
end;

/// <summary> dbnADS, dbnAbsoluteDB, dbnElevateDB and dbnNexusDB EXIST in
///  TFluentSQLDriver and are NOT implemented: there is no
///  FluentSQL.Serialize*/Select* unit for them and no _Register* call, so
///  FluentSQL.Register.pas raises EFluentSQLDriverNotRegistered when asked.
///  Measured on this fixture's own probe: naming dbnADS here turns every one of
///  the four statements above into that exception. So these four serialize
///  through dbnMSSQL - not because MSSQL is right for them, but because it is
///  the dialect they have been serializing through since the field existed, and
///  it is the one registered serializer that leaves ':pN' alone. </summary>
procedure TTestDMLDialectWiring.DialectOf_ADS;
begin
  AssertGenerator(TDMLGeneratorADS, dbnMSSQL, 'ADS');
end;

procedure TTestDMLDialectWiring.DialectOf_AbsoluteDB;
begin
  AssertGenerator(TDMLGeneratorAbsoluteDB, dbnMSSQL, 'AbsoluteDB');
end;

procedure TTestDMLDialectWiring.DialectOf_ElevateDB;
begin
  AssertGenerator(TDMLGeneratorElevateDB, dbnMSSQL, 'ElevateDB');
end;

procedure TTestDMLDialectWiring.DialectOf_Firebird;
begin
  AssertGenerator(TDMLGeneratorFirebird, dbnFirebird, 'Firebird');
end;

procedure TTestDMLDialectWiring.DialectOf_Firebird3;
begin
  AssertGenerator(TDMLGeneratorFirebird3, dbnFirebird, 'Firebird3');
end;

/// <summary> dbnInterbase is in the enum and its {$DEFINE} is OFF in
///  FluentSQL.inc, so it is as unregistered as the four above. InterBase
///  descends from the Firebird generator and therefore already answered
///  dbnFirebird before this repair - by inheritance, which is why the issue's
///  count of ten was two too high. It is declared here in its own right so that
///  moving the Firebird dialect cannot move InterBase in silence. </summary>
procedure TTestDMLDialectWiring.DialectOf_InterBase;
begin
  AssertGenerator(TDMLGeneratorInterbase, dbnFirebird, 'InterBase');
end;

procedure TTestDMLDialectWiring.DialectOf_MSSQL;
begin
  AssertGenerator(TDMLGeneratorMSSql, dbnMSSQL, 'MSSQL');
end;

/// <summary> THE ONE THE #337 GUARD IS WAITING FOR. dbnMySQL IS registered and
///  its serializer rewrites every ':pN' to '?' over the whole string
///  (FluentSQL.SerializeMySQL.pas:52), so the marker Janus put in the value slot
///  has nothing left to be restored over. Measured on this fixture's probe:
///  naming dbnMySQL here makes GeneratorInsert and GeneratorUpdate refuse by
///  name - "allocated 2 bind(s) but only 0 marker(s) could be put back" - which
///  is the #337 guard doing exactly what it was planted for. DELETE and SELECT
///  are unaffected, because neither allocates a bind.
///
///  So the MySQL generator keeps serializing through dbnMSSQL and the real
///  question - whether Janus should consume the positional '?' MySQL wants -
///  is left OPEN and reported, not answered here by silently disarming a guard
///  that was written before this repair on purpose. </summary>
procedure TTestDMLDialectWiring.DialectOf_MySQL;
begin
  AssertGenerator(TDMLGeneratorMySQL, dbnMSSQL, 'MySQL');
end;

procedure TTestDMLDialectWiring.DialectOf_NexusDB;
begin
  AssertGenerator(TDMLGeneratorNexusDB, dbnMSSQL, 'NexusDB');
end;

procedure TTestDMLDialectWiring.DialectOf_Oracle;
begin
  AssertGenerator(TDMLGeneratorOracle, dbnOracle, 'Oracle');
end;

procedure TTestDMLDialectWiring.DialectOf_PostgreSQL;
begin
  AssertGenerator(TDMLGeneratorPostgreSQL, dbnPostgreSQL, 'PostgreSQL');
end;

procedure TTestDMLDialectWiring.DialectOf_SQLite;
begin
  AssertGenerator(TDMLGeneratorSQLite, dbnSQLite, 'SQLite');
end;

/// <summary> THE ONE PLACE WHERE THE WRONG DIALECT CHANGED THE TEXT. Of the
///  four statements Janus renders through FluentSQL, only the SELECT carries a
///  relation alias, and the alias keyword is the single thing the seven
///  registered serializers do not agree on: Oracle emits none
///  (FluentSQL.SerializeOracle.pas RelationAliasKeyword) and the rest emit
///  'AS'. Oracle rejects AS in front of a TABLE alias, so every join view Janus
///  built for Oracle was unparseable by the engine it was built for. </summary>
procedure TTestDMLDialectWiring.OracleWritesTheJoinAliasWithoutAS;
var
  LSQL: String;
begin
  LSQL := SelectOf(TDMLGeneratorOracle);
  Assert.Contains(LSQL, 'INNER JOIN client aliastable',
    'Oracle names a table alias with no keyword in front of it');
  Assert.DoesNotContain(LSQL, 'INNER JOIN client AS aliastable',
    'Oracle rejects AS in front of a table alias');
end;

/// <summary> THE POSITIVE CONTROL FOR THE CLAUSE ABOVE. Without it "Oracle has
///  no AS" would also pass if the keyword had been dropped for EVERYBODY, which
///  is the change that would break the other eleven engines at once. </summary>
procedure TTestDMLDialectWiring.TheOtherElevenStillWriteTheJoinAliasWithAS;
const
  COthers: array[0..10] of TDMLGeneratorClass = (
    TDMLGeneratorADS, TDMLGeneratorAbsoluteDB, TDMLGeneratorElevateDB,
    TDMLGeneratorFirebird, TDMLGeneratorFirebird3, TDMLGeneratorInterbase,
    TDMLGeneratorMSSql, TDMLGeneratorMySQL, TDMLGeneratorNexusDB,
    TDMLGeneratorPostgreSQL, TDMLGeneratorSQLite);
var
  LFor: Integer;
begin
  for LFor := Low(COthers) to High(COthers) do
    Assert.Contains(SelectOf(COthers[LFor]), 'INNER JOIN client AS aliastable',
      COthers[LFor].ClassName + ' must keep the AS its engine accepts');
end;

/// <summary> WHY THE HAND-WRITTEN dbnSQLite SWAP INSIDE THE FIREBIRD GENERATOR
///  WAS DEAD WEIGHT. It saved FFluentSQLDriver, forced dbnSQLite, built the
///  SELECT and restored - a local workaround for this very issue, written in
///  the one generator that already configured its dialect correctly.
///
///  It never changed a byte. FluentSQL's Firebird SELECT differs from its
///  SQLite SELECT by exactly one fragment, FQualifiers.SerializePagination, and
///  that fragment is empty unless FIRST/SKIP was asked of FluentSQL - which
///  Janus never does: every generator writes its own pagination into the
///  finished string (TDMLGeneratorFirebird inserts 'FIRST %s SKIP %s' by hand
///  two lines below where the swap used to be). This clause is what allows the
///  swap to be deleted rather than left standing next to the base-class wiring
///  as a second, silent mechanism. </summary>
procedure TTestDMLDialectWiring.TheFirebirdSelectIsWhatTheSQLiteDialectWouldHaveWritten;
var
  LFirebird: TDMLGeneratorAbstract;
  LSQLite: TDMLGeneratorAbstract;
begin
  LFirebird := NewGenerator(TDMLGeneratorFirebird);
  LSQLite := NewGenerator(TDMLGeneratorSQLite);
  try
    Assert.AreEqual(TDialectReader(LSQLite).SelectSQL(Tmaster),
                    TDialectReader(LFirebird).SelectSQL(Tmaster),
      'the Firebird dialect renders the SELECT exactly as SQLite does, so the ' +
      'hand-written swap that used to sit in GeneratorSelectAll bought nothing');
  finally
    LSQLite.Free;
    LFirebird.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDMLDialectWiring);

end.
