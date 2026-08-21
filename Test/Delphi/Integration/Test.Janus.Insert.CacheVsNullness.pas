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

{ @abstract(Janus Framework - the INSERT statement against the null pattern of
  the object being written, through the PUBLIC container API. Issue #352.)

  WHAT IS UNDER TEST

  That the INSERT a consumer's object receives is the INSERT for THAT object -
  not the one a sibling of the same class happened to cause earlier.

  THE TWO THINGS THAT HAD TO AGREE AND DID NOT

  TDMLGeneratorAbstract.GeneratorInsert keyed FQueryCache on
  ClassName + '-INSERT' and returned on the hit before it had looked at the
  object, while the column list it cached had been built by asking IsNullValue
  of whichever INSTANCE arrived first. TCommandInserter.GenerateInsert then
  built the PARAMS from the instance in hand. Two instances of one class with
  different null patterns therefore disagreed about the statement.

  Separately, and with no cache involved, the two loops did not select the same
  columns at all: the generator skipped on four tests and the inserter on those
  four AND on IsJoinColumn.

  Both are closed by ONE change: TInsertColumns.Plan is now the single
  column-selection function that both call, and the signature it returns is
  cached beside the SQL so a hit is only taken when the pattern matches. See
  Janus.DML.Insert.Columns.

  WHY IT IS THE CONTAINER THAT ASKS, AND NOT THE GENERATOR

  The cache is a field of the generator, the generator is built once per
  TCommandInserter (Janus.Command.Abstract.pas, the constructor), the inserter
  is built once per TDMLCommandFactory, the factory is built once per
  TSQLCommandExecutor<M>, and the executor is built once per session - which is
  what the container holds for its whole life. So two Inserts on ONE container
  share one cache, and a fixture that drove the generator directly would prove
  nothing about a consumer. Nothing calls TQueryCache.Clear anywhere in Source.

  THE CONTROLS ARE PART OF THE FIXTURE

  Three tests here are negative controls, not clauses about the defect: a lone
  wide row, a lone narrow row, and the same two objects through two SEPARATE
  containers. Without them a green suite could not tell "the cache is fixed"
  from "the fixture never wrote anything interesting", and the two-container
  case is what showed the defect was the CACHE and not the save path.

  THE SHAPE OF THE ROW

  Four columns. k01 is the client-supplied key and is NotNull, so it is never
  skipped. k02 and k03 are NullIfEmpty text, so an empty string makes the
  generator skip them. k04 is NullIfEmpty text that both instances fill, so
  every statement has a column after the skipped pair - without it a dropped
  tail column would be indistinguishable from a shorter statement.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Insert.CacheVsNullness;

interface

uses
  Classes,
  DB,
  SysUtils,
  Variants,
  IOUtils,
  Generics.Collections,
  DUnitX.TestFramework,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.UI.Intf,
  FireDAC.ConsoleUI.Wait,
  FireDAC.Phys.Intf,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Comp.Client,
  DataEngine.FactoryInterfaces,
  FireDAC.Comp.DataSet,
  FireDAC.Stan.Option,
  FireDAC.Stan.Param,
  FireDAC.Stan.Error,
  FireDAC.DatS,
  FireDAC.DApt.Intf,
  FireDAC.Stan.StorageBin,
  Janus.Container.ObjectSet,
  Janus.Container.ObjectSet.Interfaces,
  Janus.Container.FDMemTable,
  Janus.Container.DataSet.Interfaces,
  /// Linked so dnSQLite has a registered generator when this fixture runs
  /// alone; TDriverRegister answers nothing without it.
  Janus.DML.Generator.SQLite,
  MetaDbDiff.mapping.attributes,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Register;

type
  [Entity]
  [Table('cnrow', '')]
  [PrimaryKey('k01', TAutoIncType.NotInc,
                     TGeneratorType.NoneInc,
                     TSortingOrder.NoSort,
                     True, 'Primary key')]
  TCacheNullRow = class
  private
    Fk01: Integer;
    Fk02: String;
    Fk03: String;
    Fk04: String;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('k01', ftInteger)]
    property k01: Integer read Fk01 write Fk01;

    [NullIfEmpty]
    [Column('k02', ftString, 20)]
    property k02: String read Fk02 write Fk02;

    [NullIfEmpty]
    [Column('k03', ftString, 20)]
    property k03: String read Fk03 write Fk03;

    [NullIfEmpty]
    [Column('k04', ftString, 20)]
    property k04: String read Fk04 write Fk04;
  end;

  /// The SAME shape under a second class name, so the wide-first direction and
  /// the narrow-first direction never share a cache entry even if a future
  /// container were to share one generator.
  [Entity]
  [Table('cnrowb', '')]
  [PrimaryKey('k01', TAutoIncType.NotInc,
                     TGeneratorType.NoneInc,
                     TSortingOrder.NoSort,
                     True, 'Primary key')]
  TCacheNullRowB = class
  private
    Fk01: Integer;
    Fk02: String;
    Fk03: String;
    Fk04: String;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('k01', ftInteger)]
    property k01: Integer read Fk01 write Fk01;

    [NullIfEmpty]
    [Column('k02', ftString, 20)]
    property k02: String read Fk02 write Fk02;

    [NullIfEmpty]
    [Column('k03', ftString, 20)]
    property k03: String read Fk03 write Fk03;

    [NullIfEmpty]
    [Column('k04', ftString, 20)]
    property k04: String read Fk04 write Fk04;
  end;

  /// The child of the cascade fixture. Same four-column shape.
  [Entity]
  [Table('cnchild', '')]
  [PrimaryKey('k01', TAutoIncType.NotInc,
                     TGeneratorType.NoneInc,
                     TSortingOrder.NoSort,
                     True, 'Primary key')]
  TCacheNullChild = class
  private
    Fk01: Integer;
    Fmaster_id: Integer;
    Fk02: String;
    Fk03: String;
    Fk04: String;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('k01', ftInteger)]
    property k01: Integer read Fk01 write Fk01;

    [Restrictions([TRestriction.NotNull])]
    [Column('master_id', ftInteger)]
    property master_id: Integer read Fmaster_id write Fmaster_id;

    [NullIfEmpty]
    [Column('k02', ftString, 20)]
    property k02: String read Fk02 write Fk02;

    [NullIfEmpty]
    [Column('k03', ftString, 20)]
    property k03: String read Fk03 write Fk03;

    [NullIfEmpty]
    [Column('k04', ftString, 20)]
    property k04: String read Fk04 write Fk04;
  end;

  [Entity]
  [Table('cnmaster', '')]
  [PrimaryKey('master_id', TAutoIncType.NotInc,
                           TGeneratorType.NoneInc,
                           TSortingOrder.NoSort,
                           True, 'Primary key')]
  TCacheNullMaster = class
  private
    Fmaster_id: Integer;
    Ftag: String;
    Fchilds: TObjectList<TCacheNullChild>;
  public
    constructor Create;
    destructor Destroy; override;

    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('master_id', ftInteger)]
    property master_id: Integer read Fmaster_id write Fmaster_id;

    [Restrictions([TRestriction.NotNull])]
    [Column('tag', ftString, 20)]
    property tag: String read Ftag write Ftag;

    [Association(TMultiplicity.OneToMany, 'master_id', 'cnchild', 'master_id')]
    [CascadeActions([TCascadeAction.CascadeAutoInc,
                     TCascadeAction.CascadeInsert])]
    property childs: TObjectList<TCacheNullChild> read Fchilds write Fchilds;
  end;

  /// THE NEIGHBOUR. Not the cache at all. GeneratorInsert used to skip a
  /// column on four tests while TCommandInserter.GenerateInsert skipped on
  /// those four AND on IsJoinColumn, so a join column that was NOT also
  /// NoInsert got a marker nobody bound - on a COLD cache, on the FIRST
  /// insert of a SINGLE object - and the driver then filled that marker BY
  /// POSITION with the next column's value. Both now call
  /// TInsertColumns.Plan, which is what this entity exists to keep true.
  ///
  /// EVERY [JoinColumn] this repository ships under Examples - thirteen of
  /// them - also carries NoInsert, which the generator honoured even then. So
  /// the disagreement was latent there and no shipped model could show it.
  /// This entity is what a consumer who did not copy that pairing gets, and
  /// it is the only thing in the tree that holds the unification honest.
  [Entity]
  [Table('cnjoin', '')]
  [PrimaryKey('k01', TAutoIncType.NotInc,
                     TGeneratorType.NoneInc,
                     TSortingOrder.NoSort,
                     True, 'Primary key')]
  TCacheNullJoin = class
  private
    Fk01: Integer;
    Fother_id: Integer;
    Fother_name: String;
    Fk04: String;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('k01', ftInteger)]
    property k01: Integer read Fk01 write Fk01;

    [Restrictions([TRestriction.NotNull])]
    [Column('other_id', ftInteger)]
    property other_id: Integer read Fother_id write Fother_id;

    /// NO NoInsert. That is the whole point.
    [Restrictions([TRestriction.NotNull])]
    [Column('other_name', ftString, 20)]
    [JoinColumn('other_id', 'cnother', 'other_id', 'other_name', TJoin.InnerJoin)]
    property other_name: String read Fother_name write Fother_name;

    [Restrictions([TRestriction.NotNull])]
    [Column('k04', ftString, 20)]
    property k04: String read Fk04 write Fk04;
  end;

  [TestFixture]
  TTestInsertCacheVsNullness = class
  private
    FDConnection: TFDConnection;
    FConnection: IDBConnection;
    FDbFile: String;
    function _Scalar(const ASQL: String): Variant;
    function _ScalarStr(const ASQL: String): String;
    function _ScalarInt(const ASQL: String): Integer;
    function _Row(const ATable: String; const AKey: Integer): String;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// The control. ONE instance through its own container has to land whole,
    /// otherwise the two directions below are measuring the fixture.
    [Test]
    procedure Premise_ASingleWideRowLandsWhole;
    [Test]
    procedure Premise_ASingleNarrowRowLandsWithItsNullsNull;

    /// Direction A: wide first, then narrow, ON THE SAME CONTAINER. The cached
    /// statement names k02 and k03; the narrow instance binds neither.
    [Test]
    procedure WideThenNarrow_OnOneContainer;

    /// Direction B: narrow first, then wide, ON THE SAME CONTAINER. The cached
    /// statement has no slot for k02/k03; the wide instance binds both.
    [Test]
    procedure NarrowThenWide_OnOneContainer;

    /// The comparison that separates "the cache did it" from "the framework
    /// does this to every second insert": the same two objects, each through
    /// its OWN container, so each gets its own cache.
    [Test]
    procedure NarrowThenWide_OnTwoContainers;

    /// The DataSet family, the same two directions, on ONE container.
    [Test]
    procedure DataSet_WideThenNarrow_OnOneContainer;
    [Test]
    procedure DataSet_NarrowThenWide_OnOneContainer;

    /// WHAT THE DRIVER DOES WITH A MISMATCH, measured on raw FireDAC with no
    /// Janus in the picture. TDriverFireDAC._InternalExecuteDirect sets
    /// SQL.Text and then does Params.Assign(AParams), so these two calls are
    /// the whole of the binding contract Janus relies on.
    [Test]
    procedure Driver_MoreMarkersThanParams;
    [Test]
    procedure Driver_MoreParamsThanMarkers;

    /// THE SHORTEST PATH TO THE DEFECT. Not two saves - ONE. A master whose
    /// child list holds two rows of one class with different null patterns.
    /// TObjectSetBaseAdapter<M>.OneToManyCascadeActionsExecute inserts every
    /// child through FSession, the master's own session, so both children meet
    /// the same cache inside a single Insert call.
    [Test]
    procedure OneSingleInsertCall_TwoChildrenOfOneClass;

    /// THE NEIGHBOUR, on a COLD cache and a SINGLE object. If this goes red
    /// the repair cannot be "key the cache better": the two column loops
    /// disagree on their own.
    [Test]
    procedure ColdCache_JoinColumnWithoutNoInsert;

  end;

implementation

uses
  DataEngine.FactoryFireDAC;

const
  cDBFILE = 'janus_insert_cache_vs_nullness.db';

  cDDL_A =
    'CREATE TABLE IF NOT EXISTS cnrow (' +
    '  k01 INTEGER PRIMARY KEY,' +
    '  k02 VARCHAR(20),' +
    '  k03 VARCHAR(20),' +
    '  k04 VARCHAR(20)' +
    ')';
  cDDL_B =
    'CREATE TABLE IF NOT EXISTS cnrowb (' +
    '  k01 INTEGER PRIMARY KEY,' +
    '  k02 VARCHAR(20),' +
    '  k03 VARCHAR(20),' +
    '  k04 VARCHAR(20)' +
    ')';
  cDDL_JOIN =
    'CREATE TABLE IF NOT EXISTS cnjoin (' +
    '  k01        INTEGER PRIMARY KEY,' +
    '  other_id   INTEGER,' +
    '  other_name VARCHAR(20),' +
    '  k04        VARCHAR(20)' +
    ')';
  cDDL_MASTER =
    'CREATE TABLE IF NOT EXISTS cnmaster (' +
    '  master_id INTEGER PRIMARY KEY,' +
    '  tag       VARCHAR(20)' +
    ')';
  cDDL_CHILD =
    'CREATE TABLE IF NOT EXISTS cnchild (' +
    '  k01       INTEGER PRIMARY KEY,' +
    '  master_id INTEGER,' +
    '  k02 VARCHAR(20),' +
    '  k03 VARCHAR(20),' +
    '  k04 VARCHAR(20)' +
    ')';

{ TCacheNullMaster }

constructor TCacheNullMaster.Create;
begin
  Fchilds := TObjectList<TCacheNullChild>.Create;
end;

destructor TCacheNullMaster.Destroy;
begin
  Fchilds.Free;
  inherited;
end;

{ TTestInsertCacheVsNullness }

procedure TTestInsertCacheVsNullness.Setup;
begin
  FDbFile := cDBFILE;
  if TFile.Exists(FDbFile) then
    TFile.Delete(FDbFile);
  FDConnection := TFDConnection.Create(nil);
  FDConnection.Params.DriverID := 'SQLite';
  FDConnection.Params.Database := FDbFile;
  FDConnection.Params.Values['OpenMode'] := 'CreateUTF8';
  FDConnection.ResourceOptions.SilentMode := True;
  FDConnection.Connected := True;
  FConnection := TFactoryFireDAC.Create(FDConnection, dnSQLite);
  FConnection.ExecuteDirect(cDDL_A);
  FConnection.ExecuteDirect(cDDL_B);
  FConnection.ExecuteDirect(cDDL_MASTER);
  FConnection.ExecuteDirect(cDDL_CHILD);
  FConnection.ExecuteDirect(cDDL_JOIN);
end;

procedure TTestInsertCacheVsNullness.TearDown;
begin
  FConnection := nil;
  if Assigned(FDConnection) then
  begin
    FDConnection.Connected := False;
    FreeAndNil(FDConnection);
  end;
  if TFile.Exists(FDbFile) then
    TFile.Delete(FDbFile);
end;

function TTestInsertCacheVsNullness._Scalar(const ASQL: String): Variant;
begin
  Result := FDConnection.ExecSQLScalar(ASQL);
end;

function TTestInsertCacheVsNullness._ScalarStr(const ASQL: String): String;
var
  LValue: Variant;
begin
  LValue := _Scalar(ASQL);
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Result := '<NULL>'
  else
    Result := VarToStr(LValue);
end;

function TTestInsertCacheVsNullness._ScalarInt(const ASQL: String): Integer;
var
  LValue: Variant;
begin
  LValue := _Scalar(ASQL);
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Result := -1
  else
    Result := LValue;
end;

function TTestInsertCacheVsNullness._Row(const ATable: String;
  const AKey: Integer): String;
begin
  Result := 'k02=' + _ScalarStr('SELECT k02 FROM ' + ATable +
                                ' WHERE k01 = ' + IntToStr(AKey)) +
            ' k03=' + _ScalarStr('SELECT k03 FROM ' + ATable +
                                ' WHERE k01 = ' + IntToStr(AKey)) +
            ' k04=' + _ScalarStr('SELECT k04 FROM ' + ATable +
                                ' WHERE k01 = ' + IntToStr(AKey));
end;

procedure TTestInsertCacheVsNullness.Premise_ASingleWideRowLandsWhole;
var
  LSet: IContainerObjectSet<TCacheNullRow>;
  LWide: TCacheNullRow;
begin
  LSet := TContainerObjectSet<TCacheNullRow>.Create(FConnection);
  LWide := TCacheNullRow.Create;
  try
    LWide.k01 := 1;
    LWide.k02 := 'B';
    LWide.k03 := 'C';
    LWide.k04 := 'D';
    LSet.Insert(LWide);
  finally
    LWide.Free;
  end;
  Assert.AreEqual('B', _ScalarStr('SELECT k02 FROM cnrow WHERE k01 = 1'),
    'k02 of a lone wide row');
  Assert.AreEqual('C', _ScalarStr('SELECT k03 FROM cnrow WHERE k01 = 1'),
    'k03 of a lone wide row');
  Assert.AreEqual('D', _ScalarStr('SELECT k04 FROM cnrow WHERE k01 = 1'),
    'k04 of a lone wide row');
end;

procedure TTestInsertCacheVsNullness.Premise_ASingleNarrowRowLandsWithItsNullsNull;
var
  LSet: IContainerObjectSet<TCacheNullRow>;
  LNarrow: TCacheNullRow;
begin
  LSet := TContainerObjectSet<TCacheNullRow>.Create(FConnection);
  LNarrow := TCacheNullRow.Create;
  try
    LNarrow.k01 := 2;
    LNarrow.k02 := '';
    LNarrow.k03 := '';
    LNarrow.k04 := 'D';
    LSet.Insert(LNarrow);
  finally
    LNarrow.Free;
  end;
  Assert.AreEqual('<NULL>', _ScalarStr('SELECT k02 FROM cnrow WHERE k01 = 2'),
    'k02 of a lone narrow row must be NULL - the generator skipped it');
  Assert.AreEqual('D', _ScalarStr('SELECT k04 FROM cnrow WHERE k01 = 2'),
    'k04 of a lone narrow row');
end;

procedure TTestInsertCacheVsNullness.WideThenNarrow_OnOneContainer;
var
  LSet: IContainerObjectSet<TCacheNullRow>;
  LWide: TCacheNullRow;
  LNarrow: TCacheNullRow;
  LRaised: String;
begin
  LRaised := '';
  LSet := TContainerObjectSet<TCacheNullRow>.Create(FConnection);
  LWide := TCacheNullRow.Create;
  LNarrow := TCacheNullRow.Create;
  try
    LWide.k01 := 1;
    LWide.k02 := 'B';
    LWide.k03 := 'C';
    LWide.k04 := 'D';
    LSet.Insert(LWide);

    LNarrow.k01 := 2;
    LNarrow.k02 := '';
    LNarrow.k03 := '';
    LNarrow.k04 := 'D2';
    try
      LSet.Insert(LNarrow);
    except
      on E: Exception do
        LRaised := E.ClassName + ': ' + E.Message;
    end;
  finally
    LNarrow.Free;
    LWide.Free;
  end;

  TDUnitX.CurrentRunner.Status('WIDE->NARROW raised = [' + LRaised + ']');
  TDUnitX.CurrentRunner.Status('WIDE->NARROW rows    = ' +
    IntToStr(_ScalarInt('SELECT COUNT(*) FROM cnrow')));
  TDUnitX.CurrentRunner.Status('WIDE->NARROW row2 k02= ' +
    _ScalarStr('SELECT k02 FROM cnrow WHERE k01 = 2'));
  TDUnitX.CurrentRunner.Status('WIDE->NARROW row2 k04= ' +
    _ScalarStr('SELECT k04 FROM cnrow WHERE k01 = 2'));

  Assert.AreEqual('', LRaised,
    'PROBE: the narrow insert must not raise on a statement cached by a wider ' +
    'sibling. A non-empty message here IS the finding, in its loud form.');
  Assert.AreEqual(2, _ScalarInt('SELECT COUNT(*) FROM cnrow'),
    'PROBE: both rows must be written');
  Assert.AreEqual('k02=<NULL> k03=<NULL> k04=D2', _Row('cnrow', 2),
    'PROBE WIDE->NARROW: the narrow row as the database kept it. Expected is ' +
    'what a lone narrow insert produces (see the premise). Anything else is ' +
    'the cached four-column statement of the WIDE sibling being fed two binds.');
end;

procedure TTestInsertCacheVsNullness.NarrowThenWide_OnOneContainer;
var
  LSet: IContainerObjectSet<TCacheNullRowB>;
  LWide: TCacheNullRowB;
  LNarrow: TCacheNullRowB;
  LRaised: String;
begin
  LRaised := '';
  LSet := TContainerObjectSet<TCacheNullRowB>.Create(FConnection);
  LNarrow := TCacheNullRowB.Create;
  LWide := TCacheNullRowB.Create;
  try
    LNarrow.k01 := 1;
    LNarrow.k02 := '';
    LNarrow.k03 := '';
    LNarrow.k04 := 'D';
    LSet.Insert(LNarrow);

    LWide.k01 := 2;
    LWide.k02 := 'B';
    LWide.k03 := 'C';
    LWide.k04 := 'D2';
    try
      LSet.Insert(LWide);
    except
      on E: Exception do
        LRaised := E.ClassName + ': ' + E.Message;
    end;
  finally
    LWide.Free;
    LNarrow.Free;
  end;

  TDUnitX.CurrentRunner.Status('NARROW->WIDE raised  = [' + LRaised + ']');
  TDUnitX.CurrentRunner.Status('NARROW->WIDE rows    = ' +
    IntToStr(_ScalarInt('SELECT COUNT(*) FROM cnrowb')));
  TDUnitX.CurrentRunner.Status('NARROW->WIDE row2 k02= ' +
    _ScalarStr('SELECT k02 FROM cnrowb WHERE k01 = 2'));
  TDUnitX.CurrentRunner.Status('NARROW->WIDE row2 k03= ' +
    _ScalarStr('SELECT k03 FROM cnrowb WHERE k01 = 2'));
  TDUnitX.CurrentRunner.Status('NARROW->WIDE row2 k04= ' +
    _ScalarStr('SELECT k04 FROM cnrowb WHERE k01 = 2'));

  Assert.AreEqual('', LRaised,
    'PROBE: the wide insert must not raise on a statement cached by a narrower ' +
    'sibling');
  Assert.AreEqual('k02=B k03=C k04=D2', _Row('cnrowb', 2),
    'PROBE NARROW->WIDE: THE DATA LOSS. k02 and k03 were set on the object and ' +
    'must reach the row. <NULL> here is a column of the client silently ' +
    'discarded because a narrower sibling of the same class was saved first ' +
    'through this container.');
end;

procedure TTestInsertCacheVsNullness.NarrowThenWide_OnTwoContainers;
var
  LSetOne: IContainerObjectSet<TCacheNullRowB>;
  LSetTwo: IContainerObjectSet<TCacheNullRowB>;
  LWide: TCacheNullRowB;
  LNarrow: TCacheNullRowB;
begin
  LSetOne := TContainerObjectSet<TCacheNullRowB>.Create(FConnection);
  LNarrow := TCacheNullRowB.Create;
  try
    LNarrow.k01 := 1;
    LNarrow.k02 := '';
    LNarrow.k03 := '';
    LNarrow.k04 := 'D';
    LSetOne.Insert(LNarrow);
  finally
    LNarrow.Free;
  end;
  LSetOne := nil;

  LSetTwo := TContainerObjectSet<TCacheNullRowB>.Create(FConnection);
  LWide := TCacheNullRowB.Create;
  try
    LWide.k01 := 2;
    LWide.k02 := 'B';
    LWide.k03 := 'C';
    LWide.k04 := 'D2';
    LSetTwo.Insert(LWide);
  finally
    LWide.Free;
  end;

  Assert.AreEqual('B', _ScalarStr('SELECT k02 FROM cnrowb WHERE k01 = 2'),
    'CONTROL: with a container of its own the wide row keeps k02. If THIS goes ' +
    'red the defect is not the cache.');
  Assert.AreEqual('C', _ScalarStr('SELECT k03 FROM cnrowb WHERE k01 = 2'),
    'CONTROL: same for k03');
end;

procedure TTestInsertCacheVsNullness.DataSet_WideThenNarrow_OnOneContainer;
var
  LTable: TFDMemTable;
  LSet: IContainerDataSet<TCacheNullRow>;
  LRaised: String;
begin
  LRaised := '';
  LTable := TFDMemTable.Create(nil);
  try
    LSet := TContainerFDMemTable<TCacheNullRow>.Create(FConnection, LTable);
    LSet.Open;

    LSet.Append;
    LTable.FieldByName('k01').AsInteger := 1;
    LTable.FieldByName('k02').AsString := 'B';
    LTable.FieldByName('k03').AsString := 'C';
    LTable.FieldByName('k04').AsString := 'D';
    LSet.Post;
    LSet.ApplyUpdates(0);

    LSet.Append;
    LTable.FieldByName('k01').AsInteger := 2;
    LTable.FieldByName('k02').AsString := '';
    LTable.FieldByName('k03').AsString := '';
    LTable.FieldByName('k04').AsString := 'D2';
    LSet.Post;
    try
      LSet.ApplyUpdates(0);
    except
      on E: Exception do
        LRaised := E.ClassName + ': ' + E.Message;
    end;
    LSet := nil;
  finally
    LTable.Free;
  end;

  Assert.AreEqual('', LRaised, 'DATASET WIDE->NARROW must not raise');
  Assert.AreEqual('k02=<NULL> k03=<NULL> k04=D2', _Row('cnrow', 2),
    'DATASET WIDE->NARROW: the narrow row as the database kept it');
end;

procedure TTestInsertCacheVsNullness.DataSet_NarrowThenWide_OnOneContainer;
var
  LTable: TFDMemTable;
  LSet: IContainerDataSet<TCacheNullRowB>;
  LRaised: String;
begin
  LRaised := '';
  LTable := TFDMemTable.Create(nil);
  try
    LSet := TContainerFDMemTable<TCacheNullRowB>.Create(FConnection, LTable);
    LSet.Open;

    LSet.Append;
    LTable.FieldByName('k01').AsInteger := 1;
    LTable.FieldByName('k02').AsString := '';
    LTable.FieldByName('k03').AsString := '';
    LTable.FieldByName('k04').AsString := 'D';
    LSet.Post;
    LSet.ApplyUpdates(0);

    LSet.Append;
    LTable.FieldByName('k01').AsInteger := 2;
    LTable.FieldByName('k02').AsString := 'B';
    LTable.FieldByName('k03').AsString := 'C';
    LTable.FieldByName('k04').AsString := 'D2';
    LSet.Post;
    try
      LSet.ApplyUpdates(0);
    except
      on E: Exception do
        LRaised := E.ClassName + ': ' + E.Message;
    end;
    LSet := nil;
  finally
    LTable.Free;
  end;

  Assert.AreEqual('', LRaised, 'DATASET NARROW->WIDE must not raise');
  Assert.AreEqual('k02=B k03=C k04=D2', _Row('cnrowb', 2),
    'DATASET NARROW->WIDE: THE DATA LOSS, DataSet family');
end;

procedure TTestInsertCacheVsNullness.Driver_MoreMarkersThanParams;
var
  LParams: TParams;
  LQuery: TFDQuery;
begin
  // Four markers, two params - the WIDE-cached statement fed a NARROW object.
  LParams := TParams.Create(nil);
  LQuery := TFDQuery.Create(nil);
  try
    LParams.CreateParam(ftInteger, 'k01', ptInput).AsInteger := 7;
    LParams.CreateParam(ftString, 'k04', ptInput).AsString := 'D2';
    LQuery.Connection := FDConnection;
    LQuery.SQL.Text :=
      'INSERT INTO cnrow (k01, k02, k03, k04) VALUES (:k01, :k02, :k03, :k04)';
    LQuery.Params.Assign(LParams);
    LQuery.ExecSQL;
  finally
    LQuery.Free;
    LParams.Free;
  end;
  // MEASURED, and it is the whole reason the wide->narrow direction is worse
  // than "a spare marker": Params.Assign REPLACES the collection FireDAC built
  // from the SQL text, so the surviving markers are filled BY POSITION. Marker
  // two (:k02) receives param two - which is k04's value - and markers three
  // and four are left unbound and go in as NULL. No exception.
  Assert.AreEqual('k02=D2 k03=<NULL> k04=<NULL>', _Row('cnrow', 7),
    'DRIVER, MORE MARKERS THAN PARAMS: FireDAC fills the surviving markers BY ' +
    'POSITION, so a value lands in the WRONG COLUMN and nothing raises');
end;

procedure TTestInsertCacheVsNullness.Driver_MoreParamsThanMarkers;
var
  LParams: TParams;
  LQuery: TFDQuery;
begin
  // Two markers, four params - the NARROW-cached statement fed a WIDE object.
  LParams := TParams.Create(nil);
  LQuery := TFDQuery.Create(nil);
  try
    LParams.CreateParam(ftInteger, 'k01', ptInput).AsInteger := 8;
    LParams.CreateParam(ftString, 'k02', ptInput).AsString := 'B';
    LParams.CreateParam(ftString, 'k03', ptInput).AsString := 'C';
    LParams.CreateParam(ftString, 'k04', ptInput).AsString := 'D2';
    LQuery.Connection := FDConnection;
    LQuery.SQL.Text := 'INSERT INTO cnrow (k01, k04) VALUES (:k01, :k04)';
    LQuery.Params.Assign(LParams);
    LQuery.ExecSQL;
  finally
    LQuery.Free;
    LParams.Free;
  end;
  // MEASURED: here FireDAC matches BY NAME and the two params naming no marker
  // are dropped without a word. k04 keeps its own value; k02 and k03 are gone.
  Assert.AreEqual('k02=<NULL> k03=<NULL> k04=D2', _Row('cnrow', 8),
    'DRIVER, MORE PARAMS THAN MARKERS: the two extra params are dropped ' +
    'silently and the named ones still land in their own columns');
end;

procedure TTestInsertCacheVsNullness.OneSingleInsertCall_TwoChildrenOfOneClass;
var
  LSet: IContainerObjectSet<TCacheNullMaster>;
  LMaster: TCacheNullMaster;
  LNarrow: TCacheNullChild;
  LWide: TCacheNullChild;
begin
  LSet := TContainerObjectSet<TCacheNullMaster>.Create(FConnection);
  LMaster := TCacheNullMaster.Create;
  try
    LMaster.master_id := 1;
    LMaster.tag := 'M';

    // The NARROW child first, so the cache is written narrow.
    LNarrow := TCacheNullChild.Create;
    LNarrow.k01 := 1;
    LNarrow.master_id := 1;
    LNarrow.k02 := '';
    LNarrow.k03 := '';
    LNarrow.k04 := 'D';
    LMaster.childs.Add(LNarrow);

    LWide := TCacheNullChild.Create;
    LWide.k01 := 2;
    LWide.master_id := 1;
    LWide.k02 := 'B';
    LWide.k03 := 'C';
    LWide.k04 := 'D2';
    LMaster.childs.Add(LWide);

    // ONE call.
    LSet.Insert(LMaster);
  finally
    LMaster.Free;
  end;

  Assert.AreEqual(2, _ScalarInt('SELECT COUNT(*) FROM cnchild'),
    'both children must be written');
  Assert.AreEqual('k02=B k03=C k04=D2', _Row('cnchild', 2),
    'ONE INSERT CALL: the second child of a single saved master lost k02 and ' +
    'k03 to the statement cached for its narrower sibling. No second save, no ' +
    'long-lived container - one call on a freshly built ObjectSet.');
end;

procedure TTestInsertCacheVsNullness.ColdCache_JoinColumnWithoutNoInsert;
var
  LSet: IContainerObjectSet<TCacheNullJoin>;
  LRow: TCacheNullJoin;
begin
  LSet := TContainerObjectSet<TCacheNullJoin>.Create(FConnection);
  LRow := TCacheNullJoin.Create;
  try
    LRow.k01 := 1;
    LRow.other_id := 9;
    LRow.other_name := 'NAME';
    LRow.k04 := 'D';
    LSet.Insert(LRow);
  finally
    LRow.Free;
  end;
  /// WHAT IS ASSERTED, AND WHAT IS DELIBERATELY NOT.
  ///
  /// ASSERTED: no OTHER column is harmed. k04 must carry its own value. Before
  /// #352 it came back <NULL> while other_name carried 'D' - k04's value, put
  /// there by the driver filling an unbound marker BY POSITION. That silent
  /// swap is the defect, and it needed no cache and no second object.
  ///
  /// NOT ASSERTED: that other_name reaches the row. It comes back NULL, because
  /// the unified selector skips a join column exactly as
  /// TCommandInserter.GenerateInsert always has - no param for it was ever
  /// built, so no value for it was ever written, and nothing that used to work
  /// stopped working. Whether a [JoinColumn] that is NOT also NoInsert OUGHT to
  /// be inserted is a question about what the attribute means to a consumer,
  /// not about this defect. It is the owner's to answer, and answering it here
  /// by asserting 'NAME' would have written a product decision into a
  /// regression test.
  Assert.AreEqual('9|<NULL>|D',
    _ScalarStr('SELECT other_id FROM cnjoin WHERE k01 = 1') + '|' +
    _ScalarStr('SELECT other_name FROM cnjoin WHERE k01 = 1') + '|' +
    _ScalarStr('SELECT k04 FROM cnjoin WHERE k01 = 1'),
    'COLD CACHE, ONE OBJECT: a join column without NoInsert. The two column ' +
    'loops must select the same set, or the markers outnumber the params on ' +
    'the very first statement and a value lands in the wrong column. k04 ' +
    'holding its own value is the assertion; other_name being NULL is the ' +
    'unchanged fact that no param for a join column is ever built.');
end;

initialization
  TRegisterClass.RegisterEntity(TCacheNullRow);
  TRegisterClass.RegisterEntity(TCacheNullRowB);
  TRegisterClass.RegisterEntity(TCacheNullChild);
  TRegisterClass.RegisterEntity(TCacheNullMaster);
  TRegisterClass.RegisterEntity(TCacheNullJoin);
  TDUnitX.RegisterTestFixture(TTestInsertCacheVsNullness);

end.
