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
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

{ THE SEVEN DISTRIBUTED DML GENERATORS - issue #341, Level 1.

  These seven units ship. They are in the `uses` clause of `library
  JanusFramework` (Source\Janus\JanusFramework.dpr), and the design-time
  package injects three of them - InterBase, MongoDB and MySQL - straight into
  the `uses` clause of the CLIENT's own project. Until this fixture, the
  compile-coverage census measured them at 0 of 7 test projects: nothing in
  this repository ever asked the compiler to read them, let alone run them.

  LINKING IS NOT COVERAGE. Adding the seven to the .dpr would make the census
  number go green while proving nothing, so every unit linked here is claimed
  by at least one clause that DIES when the unit lies:

    - the registration each `initialization` promises. Six of the seven put a
      factory in TDriverRegister under a specific TDriverName; swap that name
      for a neighbour's, or make the factory build a neighbour's class, and
      Registry_* fails. Janus.DML.Generator.NoSQL is the seventh and registers
      NOTHING - it has no initialization section at all - so its clause is the
      one honest thing left: MongoDB descends from it and inherits its whole
      criteria body, which is what SelectAll_MongoDbSpeaksCriteriaNotSql
      measures.

    - the DIALECT TOKEN each generator inserts into a paginated SELECT. This
      is what separates a generator from its neighbour: AbsoluteDB, ElevateDB
      and NexusDB insert 'TOP n, m' after SELECT; InterBase inherits Firebird's
      'FIRST n SKIP m'; MySQL appends ' LIMIT n OFFSET m'; MongoDB emits no SQL
      at all. A factory that hands back the wrong class still resolves and
      still returns a non-nil interface - only the token catches it.

  The negative control is CProbeUnpaginated: the same call with APageSize = -1
  must NOT carry the token. Without it, "the SQL contains TOP" would also pass
  for a generator that emitted TOP unconditionally, and the paginated assertion
  would be measuring nothing about pagination. }

unit Test.Janus.DML.Generator.Distributed;

interface

uses
  SysUtils,
  StrUtils,
  Rtti,
  DUnitX.TestFramework,
  DataEngine.FactoryInterfaces,
  Janus.DML.Interfaces,
  Janus.Driver.Register,
  Janus.DML.Generator,
  /// The seven under test. Named here, and not only in the .dpr, so that the
  /// clauses below and the units they speak about travel together.
  Janus.DML.Generator.NoSQL,
  Janus.DML.Generator.AbsoluteDB,
  Janus.DML.Generator.ElevateDB,
  Janus.DML.Generator.InterBase,
  Janus.DML.Generator.MongoDB,
  Janus.DML.Generator.MySQL,
  Janus.DML.Generator.NexusDB,
  /// Two dialects that are NOT among the seven. MSSQL is the positive control
  /// of the pertinence tripwire below (it pages with ROW_NUMBER() OVER);
  /// SQLite is the measured overlap that same tripwire records.
  Janus.DML.Generator.MSSQL,
  Janus.DML.Generator.SQLite,
  Janus.Model.Client,
  /// TFakeConnection: the existing IDBConnection double for generator tests,
  /// reused rather than duplicated.
  Test.Janus.DML.Generator.SQLite;

type
  [TestFixture]
  TTestDMLGeneratorDistributed = class
  private
    /// A page size >= 0 is what switches every generator's pagination arm on.
    /// -1 is the documented "no paging" value (Janus.Command.Selecter sets
    /// FPageSize := -1 in its constructor).
    const CProbePageSize = 10;
    const CProbeUnpaginated = -1;
  private
    function Resolve(const ADriver: TDriverName): IDMLGeneratorCommand;
    /// The SELECT the REGISTERED generator for ADriver produces for Tclient.
    /// Goes through TDriverRegister on purpose: constructing the class by name
    /// would test the class and leave the registration - the thing the
    /// distributed unit actually promises - unmeasured.
    function SelectAllFor(const ADriver: TDriverName;
      const APageSize: Integer): String;
    function ClassNameOf(const AGenerator: IDMLGeneratorCommand): String;
  public
    [Test]
    procedure Registry_ResolvesEveryDistributedDialect;
    [Test]
    procedure Registry_HandsBackTheClassEachUnitPromises;
    [Test]
    procedure Registry_MongoDbGeneratorIsANoSqlGenerator;

    [Test]
    procedure SelectAll_AbsoluteDbInsertsTop;
    [Test]
    procedure SelectAll_ElevateDbInsertsTop;
    [Test]
    procedure SelectAll_NexusDbInsertsTop;
    [Test]
    procedure SelectAll_InterBaseInsertsFirstSkip;
    [Test]
    procedure SelectAll_MySqlAppendsLimitOffset;
    [Test]
    procedure SelectAll_MongoDbSpeaksCriteriaNotSql;

    [Test]
    procedure SelectAll_UnpaginatedCarriesNoDialectToken;
    [Test]
    procedure Tripwire_TheTokensTellTheDialectsApart;
  end;

implementation

{ TTestDMLGeneratorDistributed }

function TTestDMLGeneratorDistributed.Resolve(
  const ADriver: TDriverName): IDMLGeneratorCommand;
begin
  Result := TDriverRegister.GetDriver(ADriver);
end;

function TTestDMLGeneratorDistributed.ClassNameOf(
  const AGenerator: IDMLGeneratorCommand): String;
begin
  Result := (AGenerator as TObject).ClassName;
end;

function TTestDMLGeneratorDistributed.SelectAllFor(const ADriver: TDriverName;
  const APageSize: Integer): String;
var
  LGenerator: IDMLGeneratorCommand;
begin
  LGenerator := Resolve(ADriver);
  LGenerator.SetConnection(TFakeConnection.Create(ADriver));
  Result := LGenerator.GeneratorSelectAll(Tclient, APageSize,
                                          TValue.From<String>('-1'));
end;

{ A distributed unit that stops registering - or registers under the wrong
  TDriverName - reaches the user as the named registry exception, not as a
  crash, so this clause reads it as the pass/fail it is. }
procedure TTestDMLGeneratorDistributed.Registry_ResolvesEveryDistributedDialect;
const
  CDistributed: array[0..5] of TDriverName =
    (dnAbsoluteDB, dnElevateDB, dnInterbase, dnMongoDB, dnMySQL, dnNexusDB);
var
  LFor: Integer;
begin
  for LFor := Low(CDistributed) to High(CDistributed) do
    Assert.IsNotNull(Resolve(CDistributed[LFor]),
      Format('The distributed generator for %s must be registered by its own ' +
             'initialization section; got nil',
             [TStrDriverName[CDistributed[LFor]]]));
end;

{ Resolving is not enough: a factory that builds a NEIGHBOUR's class resolves
  fine and returns a non-nil interface. This names the class each unit's
  initialization promises. }
procedure TTestDMLGeneratorDistributed.Registry_HandsBackTheClassEachUnitPromises;
begin
  Assert.AreEqual('TDMLGeneratorAbsoluteDB', ClassNameOf(Resolve(dnAbsoluteDB)),
    'Janus.DML.Generator.AbsoluteDB registers dnAbsoluteDB');
  Assert.AreEqual('TDMLGeneratorElevateDB', ClassNameOf(Resolve(dnElevateDB)),
    'Janus.DML.Generator.ElevateDB registers dnElevateDB');
  Assert.AreEqual('TDMLGeneratorInterbase', ClassNameOf(Resolve(dnInterbase)),
    'Janus.DML.Generator.InterBase registers dnInterbase');
  Assert.AreEqual('TDMLGeneratorMongoDB', ClassNameOf(Resolve(dnMongoDB)),
    'Janus.DML.Generator.MongoDB registers dnMongoDB');
  Assert.AreEqual('TDMLGeneratorMySQL', ClassNameOf(Resolve(dnMySQL)),
    'Janus.DML.Generator.MySQL registers dnMySQL');
  Assert.AreEqual('TDMLGeneratorNexusDB', ClassNameOf(Resolve(dnNexusDB)),
    'Janus.DML.Generator.NexusDB registers dnNexusDB');
end;

{ THE ONLY HONEST CLAUSE Janus.DML.Generator.NoSQL SUPPORTS.
  That unit has no initialization section and registers no driver, so no
  registry clause can reach it. What it DOES own is the criteria body MongoDB
  inherits whole - TDMLGeneratorMongoDB adds a constructor and nothing else.
  Break the descent and this dies. }
procedure TTestDMLGeneratorDistributed.Registry_MongoDbGeneratorIsANoSqlGenerator;
var
  LGenerator: TObject;
begin
  LGenerator := Resolve(dnMongoDB) as TObject;

  Assert.IsTrue(LGenerator is TDMLGeneratorNoSQL,
    Format('TDMLGeneratorMongoDB must descend from TDMLGeneratorNoSQL - the ' +
           'criteria body it answers with lives there, not in its own unit. ' +
           'Got %s', [LGenerator.ClassName]));
end;

procedure TTestDMLGeneratorDistributed.SelectAll_AbsoluteDbInsertsTop;
begin
  Assert.Contains(SelectAllFor(dnAbsoluteDB, CProbePageSize), 'TOP %s, %s',
    True, 'AbsoluteDB pages with TOP n, m inserted after SELECT');
end;

procedure TTestDMLGeneratorDistributed.SelectAll_ElevateDbInsertsTop;
begin
  Assert.Contains(SelectAllFor(dnElevateDB, CProbePageSize), 'TOP %s, %s',
    True, 'ElevateDB pages with TOP n, m inserted after SELECT');
end;

procedure TTestDMLGeneratorDistributed.SelectAll_NexusDbInsertsTop;
begin
  Assert.Contains(SelectAllFor(dnNexusDB, CProbePageSize), 'TOP %s, %s',
    True, 'NexusDB pages with TOP n, m inserted after SELECT');
end;

{ InterBase adds no pagination of its own: it descends from
  TDMLGeneratorFirebird and inherits FIRST/SKIP. Asserting the Firebird token
  here is deliberate - it is what makes "InterBase IS a Firebird dialect" a
  measurement instead of a comment, and it dies if the descent changes. }
procedure TTestDMLGeneratorDistributed.SelectAll_InterBaseInsertsFirstSkip;
var
  LSQL: String;
begin
  LSQL := SelectAllFor(dnInterbase, CProbePageSize);

  Assert.Contains(LSQL, 'FIRST %s SKIP %s', True,
    'InterBase inherits Firebird pagination: FIRST n SKIP m after SELECT');
  Assert.IsFalse(ContainsText(LSQL, 'TOP '),
    'InterBase must not page like AbsoluteDB/ElevateDB/NexusDB: ' + LSQL);
end;

procedure TTestDMLGeneratorDistributed.SelectAll_MySqlAppendsLimitOffset;
var
  LSQL: String;
begin
  LSQL := SelectAllFor(dnMySQL, CProbePageSize);

  Assert.Contains(LSQL, 'LIMIT %s OFFSET %s', True,
    'MySQL pages by APPENDING LIMIT n OFFSET m, not by inserting after SELECT');
  Assert.IsFalse(ContainsText(LSQL, 'TOP '),
    'MySQL must not page like AbsoluteDB/ElevateDB/NexusDB: ' + LSQL);
end;

{ MongoDB is not a SQL dialect and its generator does not pretend to be one.
  The whole body answering here lives in Janus.DML.Generator.NoSQL. }
procedure TTestDMLGeneratorDistributed.SelectAll_MongoDbSpeaksCriteriaNotSql;
var
  LCriteria: String;
begin
  LCriteria := SelectAllFor(dnMongoDB, CProbePageSize);

  Assert.StartsWith('command=find&', LCriteria,
    'The MongoDB generator answers a find command, not SQL: ' + LCriteria);
  Assert.Contains(LCriteria, 'collection=client', True,
    'The criteria must name the mapped collection of Tclient');
  Assert.Contains(LCriteria, 'limit=%s', True,
    'Paged criteria carries limit/skip, the NoSQL pagination of ' +
    'TDMLGeneratorNoSQL.GetGeneratorSelectNoSQL');
  Assert.Contains(LCriteria, 'skip=%s', True,
    'Paged criteria carries limit/skip');
  Assert.IsFalse(ContainsText(LCriteria, 'SELECT '),
    'A NoSQL generator must not emit a SELECT clause: ' + LCriteria);
end;

{ NEGATIVE CONTROL for every token clause above. Without it, a generator that
  emitted its token unconditionally would satisfy all six and the assertions
  would be measuring the dialect but not the PAGINATION arm. }
procedure TTestDMLGeneratorDistributed.SelectAll_UnpaginatedCarriesNoDialectToken;
begin
  Assert.IsFalse(ContainsText(SelectAllFor(dnAbsoluteDB, CProbeUnpaginated), 'TOP '),
    'AbsoluteDB must only insert TOP when a page size was asked for');
  Assert.IsFalse(ContainsText(SelectAllFor(dnElevateDB, CProbeUnpaginated), 'TOP '),
    'ElevateDB must only insert TOP when a page size was asked for');
  Assert.IsFalse(ContainsText(SelectAllFor(dnNexusDB, CProbeUnpaginated), 'TOP '),
    'NexusDB must only insert TOP when a page size was asked for');
  Assert.IsFalse(ContainsText(SelectAllFor(dnInterbase, CProbeUnpaginated), 'FIRST '),
    'InterBase must only insert FIRST/SKIP when a page size was asked for');
  Assert.IsFalse(ContainsText(SelectAllFor(dnMySQL, CProbeUnpaginated), 'LIMIT '),
    'MySQL must only append LIMIT/OFFSET when a page size was asked for');
  Assert.IsFalse(ContainsText(SelectAllFor(dnMongoDB, CProbeUnpaginated), 'limit='),
    'The MongoDB criteria must only carry limit/skip when a page size was asked for');
end;

{ PERTINENCE TRIPWIRE for the word ONLY in the clauses above.
  Six of the assertions say a dialect must NOT carry a neighbour's token. That
  is worth nothing unless the tokens really do differ, so the positive control
  is dnMSSQL - a dialect NOT among the seven, already linked here - whose
  paginated SELECT is built from ROW_NUMBER() OVER and carries none of the four
  tokens. If every dialect started emitting the same string, this dies first
  and says so.

  THE FIRST VERSION OF THIS TRIPWIRE USED dnSQLite AND WAS WRONG - IT FAILED,
  AND THE FAILURE WAS THE MEASUREMENT. SQLite and MySQL produce a
  BYTE-IDENTICAL paginated SELECT for Tclient, because
  Janus.DML.Generator.SQLite.GetGeneratorSelect and
  Janus.DML.Generator.MySQL.GetGeneratorSelect both return the same
  ' LIMIT %s OFFSET %s'. That is CORRECT - the two engines really do share the
  syntax - but it has a consequence worth stating out loud: the LIMIT/OFFSET
  clause alone does NOT prove which class answered for dnMySQL, because SQLite
  would satisfy it too. What pins that down is
  Registry_HandsBackTheClassEachUnitPromises, and the two clauses are
  load-bearing only TOGETHER. }
procedure TTestDMLGeneratorDistributed.Tripwire_TheTokensTellTheDialectsApart;
var
  LAbsolute: String;
  LMySql: String;
  LInterBase: String;
  LMongo: String;
  LMSSql: String;
  LSQLite: String;
begin
  LAbsolute  := SelectAllFor(dnAbsoluteDB, CProbePageSize);
  LMySql     := SelectAllFor(dnMySQL, CProbePageSize);
  LInterBase := SelectAllFor(dnInterbase, CProbePageSize);
  LMongo     := SelectAllFor(dnMongoDB, CProbePageSize);
  LMSSql     := SelectAllFor(dnMSSQL, CProbePageSize);
  LSQLite    := SelectAllFor(dnSQLite, CProbePageSize);

  Assert.AreNotEqual(LAbsolute, LMySql,
    'AbsoluteDB and MySQL page differently; identical output means one of the ' +
    'two registrations is answering for both');
  Assert.AreNotEqual(LAbsolute, LInterBase,
    'AbsoluteDB and InterBase page differently');
  Assert.AreNotEqual(LMySql, LInterBase,
    'MySQL and InterBase page differently');
  Assert.AreNotEqual(LMSSql, LAbsolute,
    'Positive control: MSSQL is NOT one of the seven and pages with ' +
    'ROW_NUMBER() OVER, not with TOP n, m');
  Assert.AreNotEqual(LMSSql, LMySql,
    'Positive control: MSSQL must not answer like MySQL');
  Assert.AreNotEqual(LMongo, LMSSql,
    'Positive control: the NoSQL criteria and a SQL SELECT are not the same ' +
    'string');

  { The measured overlap, asserted rather than left as prose: if MySQL ever
    stops sharing SQLite's LIMIT/OFFSET, the comment above goes stale and this
    is what says so. }
  Assert.AreEqual(LSQLite, LMySql,
    'MEASURED: SQLite and MySQL page identically (both return ' +
    '" LIMIT %s OFFSET %s"). If this fails, one of the two changed and the ' +
    'comment on this method needs re-reading.');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDMLGeneratorDistributed);

end.
