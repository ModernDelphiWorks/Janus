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

{ @abstract(Janus Framework - cursor advance regression suite.)

  Every test here drives ONE production loop of the shape

      while not <cursor>.Eof do begin ... end;

  over a cursor that really has rows (Test.Janus.Cursor.Double). If the loop
  body does not call <cursor>.Next, the loop never terminates: in production
  that is a hang, here the double converts it into ECursorRunaway, so the test
  goes RED in milliseconds instead of wedging the suite.

  Sibling of commit 1ad296b, which fixed the same defect in
  ExecuteOneToOne/ExecuteOneToMany (Janus.Command.Executor.pas:331,:370) and
  left the neighbours of the very same file untouched.

  ANCHORS ARE BY METHOD, DELIBERATELY. An `arquivo:linha` anchor rots on the
  first commit that inserts a line above it, and a rotten anchor in a file whose
  whole job is to say WHICH SITES ARE COVERED is worse than no anchor: whoever
  checks it reads the wrong code and concludes the coverage is somewhere it is
  not. Where a line number appears below it is glued to the method name, never
  alone.

  Covered sites - one production loop each:
    Janus.Command.Executor.pas  TSQLCommandExecutor<M>.NextPacketList(
                                  AObjectList; AWhere, AOrderBy; APageSize, APageNext)
    Janus.Command.Executor.pas  TSQLCommandExecutor<M>.NextPacketList(
                                  AObjectList; APageSize, APageNext)
    Janus.Session.DataSet.pas   TSessionDataSet<M>.RefreshRecord(TParams)
    Janus.Session.DataSet.pas   TSessionDataSet<M>.RefreshRecordWhere(string)
    Janus.Session.DataSet.pas   TSessionDataSet<M>._PopularDataSet (the Open path)
    Janus.Mapping.Lazy.pas      CreateLazySingleAssociationLoadFunc
    Janus.Mapping.Lazy.pas      CreateLazyManyAssociationLoadFunc
    Janus.Query.ResultSet.pas   TJanusQueryObject<M>.AsList

  Sites this fixture does NOT drive directly, and why:

  1) HISTORICAL - no longer open. CreateLazyManyAssociationLoadFunc used to be
     unreachable, and this file carried a test named
     LazyManyAssociation_CannotRun_KNOWN_DEFECT that pinned WHY: the function
     built the list with `LListClass.Create` followed by
     `MethodCall('Create', [True])`, and TRttiType.GetMethod('Create') over a
     TObjectList<T> answers the ZERO-argument constructor, so Invoke raised
     'Parameter count mismatch' before the cursor was ever touched - the loop
     was dead code at runtime for every model. #210. The construction now goes
     through the constructor the RTTI actually returned, invoked on the
     METACLASS, and the three LazyManyAssociation_* tests below drive the loop
     for the first time.

     ONE LIMIT SURVIVES, AND IT IS NOT JANUS'S. A property typed as a
     DESCENDANT of TObjectList<T> still dies, because
     TRttiPropertyHelper.GetTypeValue recovers the item type by stripping
     'TObjectList<' / '>' TEXTUALLY from the type name, and a descendant's name
     yields FindType(<name>) = nil. Measured on Studio 37, together with the
     correction of one premise of #210: the descendant does NOT resolve a
     one-argument constructor there either - GetMethod('Create') answers
     paramcount 0 on BOTH shapes. That helper lives in MetaDbDiff
     (MetaDbDiff.RTTI.Helper.pas, TRttiPropertyHelper.GetTypeValue) and the
     EAGER path reads it the same way at
     TSQLCommandExecutor<M>.ExecuteOneToMany, so lazy is no worse than eager.
     Upstream: ModernDelphiWorks/MetaDbDiff#18.

  2) HISTORICAL - no longer open. The ninth loop lived in
     TRESTDataSetAdapter<M>.SetAutoIncValueChilds, which could not be reached
     from here without a live REST client session, so the reason its .Next was
     added was measured indirectly by
     MasterDetailPost_DoesNotAdvanceCursor_ASSUMPTION below.
     That override has since been deleted: it was a copy of
     TDataSetBaseAdapter<M>.SetAutoIncValueChilds that had lost the multi-level
     recursion, and the whole REST family now runs the base implementation. The
     base implementation IS driven directly, by Test.Janus.AutoInc.Childs, which
     also shows what the empty child set below actually costs: zero children
     updated.
}

unit Test.Janus.Cursor.Advance;

interface

uses
  DB,
  Rtti,
  Classes,
  SysUtils,
  Generics.Collections,
  DUnitX.TestFramework,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Param,
  FireDAC.Stan.Error,
  FireDAC.DatS,
  FireDAC.Phys.Intf,
  FireDAC.DApt.Intf,
  FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Explorer,
  MetaDbDiff.Types.Mapping,
  Janus.Command.Factory,
  Janus.Command.Executor,
  Janus.Session.ObjectSet,
  Janus.Container.DataSet.Interfaces,
  Janus.Container.FDMemTable,
  Janus.Mapping.Lazy,
  Janus.Query.ResultSet,
  Janus.DML.Generator.SQLite,
  Model.Exame,
  Model.Procedimento,
  Model.Setor,
  Test.Janus.Model.KeyOnly,
  Test.Janus.Model.LazyCtor,
  Test.Janus.Cursor.Double;

type
  [TestFixture]
  TTestCursorAdvance = class
  private
    function NewConnection(const ARows: Integer): TRowsConnection;
    function LazyConnection(const ARows: Integer): TRowsConnection;
    function AssociationOf(const AClass: TClass;
      const AMultiplicity: TMultiplicity): TAssociationMapping;
  public
    // ---- the double itself: a gate that cannot fail is not a gate ---------
    /// The double must hand out a cursor that really walks N rows.
    [Test]
    procedure Double_WalksEveryRow;
    /// The double must turn a NON-advancing loop into a fast, readable
    /// exception. Without this the whole fixture would hang instead of fail.
    [Test]
    procedure Double_NonAdvancingLoop_RaisesInsteadOfHanging;
    /// ...and it must NOT punish a loop that advances correctly.
    [Test]
    procedure Double_AdvancingLoop_DoesNotRaise;

    // ---- Janus.Query.ResultSet.pas : TJanusQueryObject<M>.AsList ----------
    [Test]
    procedure AsList_ThreeRows_ReturnsThree;
    [Test]
    procedure AsList_OneRow_ReturnsOne;
    [Test]
    procedure AsList_ZeroRows_ReturnsNil;

    // ---- Janus.Command.Executor.pas : NextPacketList (2 overloads) --------
    [Test]
    procedure NextPacketList_PageOnly_ThreeRows_ReturnsThree;
    [Test]
    procedure NextPacketList_PageOnly_OneRow_ReturnsOne;
    [Test]
    procedure NextPacketList_PageOnly_ZeroRows_ReturnsEmpty;
    [Test]
    procedure NextPacketList_WithWhere_ThreeRows_ReturnsThree;
    [Test]
    procedure NextPacketList_WithWhere_OneRow_ReturnsOne;
    [Test]
    procedure NextPacketList_WithWhere_ZeroRows_ReturnsEmpty;

    // ---- Janus.Session.DataSet.pas : _PopularDataSet / Refresh* ----------
    [Test]
    procedure PopularDataSet_ThreeRows_LoadsThreeRecords;
    [Test]
    procedure PopularDataSet_OneRow_LoadsOneRecord;
    [Test]
    procedure PopularDataSet_ZeroRows_LoadsNothing;
    [Test]
    procedure RefreshRecordWhere_ThreeRows_Terminates;
    [Test]
    procedure RefreshRecord_ThreeRows_Terminates;

    // ---- Janus.Mapping.Lazy.pas : the two lazy load funcs -----------------
    [Test]
    procedure LazySingleAssociation_ThreeRows_Terminates;
    /// The loop yields ONE object per row and returns only the LAST, so every
    /// earlier instance has to be released by the loop itself - nothing else
    /// ever learns those instances existed. The clause reads
    /// TLazyCtorChild's per-address destruction ledger; see the method body
    /// for how it is made immune to address reuse.
    [Test]
    procedure LazySingleAssociation_ThreeRows_FreesEveryDiscardedInstance;
    [Test]
    procedure LazySingleAssociation_ZeroRows_ReturnsNil;
    /// The loop of CreateLazyManyAssociationLoadFunc, driven for the first
    /// time. Until #210 it was unreachable: the function raised before the
    /// cursor was ever touched. Asserted ROW BY ROW and IN ORDER, so a loop
    /// that yields the right COUNT out of the wrong rows still goes red.
    [Test]
    procedure LazyManyAssociation_ThreeRows_ReturnsOneObjectPerRowInOrder;
    /// The list the lazy proxy hands back must OWN its items - it is the only
    /// thing that will ever free them, because TLazyProxyLoader frees the list
    /// and nothing else knows the items exist.
    [Test]
    procedure LazyManyAssociation_TheListItReturnsOwnsItsItems;
    [Test]
    procedure LazyManyAssociation_ZeroRows_ReturnsAnEmptyList;

    // ---- fatos medidos que este trabalho consagra em CI -------------------
    [Test]
    procedure MasterDetailPost_DoesNotAdvanceCursor_ASSUMPTION;
  end;

implementation

const
  cROWS = 3;

{ TTestCursorAdvance }

function TTestCursorAdvance.NewConnection(const ARows: Integer): TRowsConnection;
begin
  Result := TRowsConnection.Create(dnSQLite, ARows, KeyOnlySchema(), KeyOnlyRow(),
                                   'keyonly');
end;

function TTestCursorAdvance.LazyConnection(const ARows: Integer): TRowsConnection;
begin
  Result := TRowsConnection.Create(dnSQLite, ARows, LazySchema(), LazyRow(), 'lazy');
end;

function TTestCursorAdvance.AssociationOf(const AClass: TClass;
  const AMultiplicity: TMultiplicity): TAssociationMapping;
var
  LList: TAssociationMappingList;
  LItem: TAssociationMapping;
begin
  Result := nil;
  LList := TMappingExplorer.GetMappingAssociation(AClass);
  if LList = nil then
    Exit;
  for LItem in LList do
    if LItem.Multiplicity = AMultiplicity then
      Exit(LItem);
end;

// ---------------------------------------------------------------------------
// The double
// ---------------------------------------------------------------------------

procedure TTestCursorAdvance.Double_WalksEveryRow;
var
  LConn: IDBConnection;
  LRows: TRowsConnection;
  LSet: IDBDataSet;
  LSeen: Integer;
begin
  LRows := NewConnection(cROWS);
  LConn := LRows;
  LSet := LConn.CreateDataSet('SELECT * FROM keyonly');
  LSeen := 0;
  while not LSet.Eof do
  begin
    Assert.AreEqual(100 + LSeen, LSet.FieldByName('k1').AsInteger,
      'the double must expose REAL, distinct rows - not the same row N times');
    Inc(LSeen);
    LSet.Next;
  end;
  Assert.AreEqual(cROWS, LSeen, 'the double must yield exactly N rows');
end;

procedure TTestCursorAdvance.Double_NonAdvancingLoop_RaisesInsteadOfHanging;
var
  LConn: IDBConnection;
  LRows: TRowsConnection;
  LSet: IDBDataSet;
begin
  // This is the meta-check: it reproduces the DEFECT SHAPE on purpose. If the
  // double were toothless this loop would never return and the suite would
  // hang, so a green here is what licenses every other test in this fixture.
  LRows := NewConnection(cROWS);
  LConn := LRows;
  LSet := LConn.CreateDataSet('SELECT * FROM keyonly');
  Assert.WillRaise(
    procedure
    begin
      while not LSet.Eof do
      begin
        // deliberately NO LSet.Next - exactly the production defect
      end;
    end,
    ECursorRunaway,
    'a loop that never advances the cursor must fail fast, never hang');
end;

procedure TTestCursorAdvance.Double_AdvancingLoop_DoesNotRaise;
var
  LConn: IDBConnection;
  LRows: TRowsConnection;
  LSet: IDBDataSet;
begin
  // The mirror image: the budget must be wide enough that correct code is
  // never punished, otherwise the double would produce false reds.
  LRows := NewConnection(cROWS);
  LConn := LRows;
  LSet := LConn.CreateDataSet('SELECT * FROM keyonly');
  Assert.WillNotRaise(
    procedure
    begin
      while not LSet.Eof do
        LSet.Next;
    end,
    ECursorRunaway);
end;

// ---------------------------------------------------------------------------
// Janus.Query.ResultSet.pas - TJanusQueryObject<M>.AsList
// ---------------------------------------------------------------------------

procedure TTestCursorAdvance.AsList_ThreeRows_ReturnsThree;
var
  LConn: IDBConnection;
  LList: TObjectList<TKeyOnly>;
begin
  LConn := NewConnection(cROWS);
  LList := TJanusQueryObject<TKeyOnly>.New
             .SetConnection(LConn)
             .SQL('SELECT * FROM keyonly')
             .AsList;
  try
    Assert.IsNotNull(LList, 'AsList must return a list for a populated cursor');
    Assert.AreEqual(cROWS, LList.Count,
      'AsList must yield one object PER ROW - not the first row N times');
    Assert.AreEqual(100, LList[0].k1);
    Assert.AreEqual(102, LList[cROWS - 1].k1,
      'the last object must carry the LAST row, proving the cursor advanced');
  finally
    LList.Free;
  end;
end;

procedure TTestCursorAdvance.AsList_OneRow_ReturnsOne;
var
  LConn: IDBConnection;
  LList: TObjectList<TKeyOnly>;
begin
  LConn := NewConnection(1);
  LList := TJanusQueryObject<TKeyOnly>.New
             .SetConnection(LConn)
             .SQL('SELECT * FROM keyonly')
             .AsList;
  try
    Assert.IsNotNull(LList);
    Assert.AreEqual(1, LList.Count);
  finally
    LList.Free;
  end;
end;

procedure TTestCursorAdvance.AsList_ZeroRows_ReturnsNil;
var
  LConn: IDBConnection;
begin
  // Degenerate case: AsList short-circuits on RecordCount = 0 and returns nil.
  LConn := NewConnection(0);
  Assert.IsNull(TJanusQueryObject<TKeyOnly>.New
                  .SetConnection(LConn)
                  .SQL('SELECT * FROM keyonly')
                  .AsList);
end;

// ---------------------------------------------------------------------------
// Janus.Command.Executor.pas - the two NextPacketList overloads
// ---------------------------------------------------------------------------

procedure TTestCursorAdvance.NextPacketList_PageOnly_ThreeRows_ReturnsThree;
var
  LConn: IDBConnection;
  LSession: TSessionObjectSet<TKeyOnly>;
  LExecutor: TSQLCommandExecutor<TKeyOnly>;
  LList: TObjectList<TKeyOnly>;
begin
  LConn := NewConnection(cROWS);
  LSession := TSessionObjectSet<TKeyOnly>.Create(LConn, 10);
  LExecutor := TSQLCommandExecutor<TKeyOnly>.Create(LSession, LConn, 10);
  LList := TObjectList<TKeyOnly>.Create;
  try
    LExecutor.NextPacketList(LList, 10, 0);
    Assert.AreEqual(cROWS, LList.Count,
      'NextPacketList must append one object PER ROW of the packet');
    Assert.AreEqual(100, LList[0].k1);
    Assert.AreEqual(102, LList[cROWS - 1].k1);
  finally
    LList.Free;
    LExecutor.Free;
    LSession.Free;
  end;
end;

procedure TTestCursorAdvance.NextPacketList_PageOnly_OneRow_ReturnsOne;
var
  LConn: IDBConnection;
  LSession: TSessionObjectSet<TKeyOnly>;
  LExecutor: TSQLCommandExecutor<TKeyOnly>;
  LList: TObjectList<TKeyOnly>;
begin
  LConn := NewConnection(1);
  LSession := TSessionObjectSet<TKeyOnly>.Create(LConn, 10);
  LExecutor := TSQLCommandExecutor<TKeyOnly>.Create(LSession, LConn, 10);
  LList := TObjectList<TKeyOnly>.Create;
  try
    LExecutor.NextPacketList(LList, 10, 0);
    Assert.AreEqual(1, LList.Count);
  finally
    LList.Free;
    LExecutor.Free;
    LSession.Free;
  end;
end;

procedure TTestCursorAdvance.NextPacketList_PageOnly_ZeroRows_ReturnsEmpty;
var
  LConn: IDBConnection;
  LSession: TSessionObjectSet<TKeyOnly>;
  LExecutor: TSQLCommandExecutor<TKeyOnly>;
  LList: TObjectList<TKeyOnly>;
begin
  // Degenerate case: an empty packet must add nothing AND must flag the owner
  // session as done fetching (the `finally` branch that needs a real owner).
  LConn := NewConnection(0);
  LSession := TSessionObjectSet<TKeyOnly>.Create(LConn, 10);
  LExecutor := TSQLCommandExecutor<TKeyOnly>.Create(LSession, LConn, 10);
  LList := TObjectList<TKeyOnly>.Create;
  try
    LExecutor.NextPacketList(LList, 10, 0);
    Assert.AreEqual(0, LList.Count);
    Assert.IsTrue(LSession.FetchingRecords,
      'an empty packet must stop the session from asking for more');
  finally
    LList.Free;
    LExecutor.Free;
    LSession.Free;
  end;
end;

procedure TTestCursorAdvance.NextPacketList_WithWhere_ThreeRows_ReturnsThree;
var
  LConn: IDBConnection;
  LSession: TSessionObjectSet<TKeyOnly>;
  LExecutor: TSQLCommandExecutor<TKeyOnly>;
  LList: TObjectList<TKeyOnly>;
begin
  LConn := NewConnection(cROWS);
  LSession := TSessionObjectSet<TKeyOnly>.Create(LConn, 10);
  LExecutor := TSQLCommandExecutor<TKeyOnly>.Create(LSession, LConn, 10);
  LList := TObjectList<TKeyOnly>.Create;
  try
    LExecutor.NextPacketList(LList, 'k1 > 0', 'k1', 10, 0);
    Assert.AreEqual(cROWS, LList.Count,
      'the WHERE overload must append one object PER ROW of the packet');
    Assert.AreEqual(102, LList[cROWS - 1].k1);
  finally
    LList.Free;
    LExecutor.Free;
    LSession.Free;
  end;
end;

procedure TTestCursorAdvance.NextPacketList_WithWhere_OneRow_ReturnsOne;
var
  LConn: IDBConnection;
  LSession: TSessionObjectSet<TKeyOnly>;
  LExecutor: TSQLCommandExecutor<TKeyOnly>;
  LList: TObjectList<TKeyOnly>;
begin
  LConn := NewConnection(1);
  LSession := TSessionObjectSet<TKeyOnly>.Create(LConn, 10);
  LExecutor := TSQLCommandExecutor<TKeyOnly>.Create(LSession, LConn, 10);
  LList := TObjectList<TKeyOnly>.Create;
  try
    LExecutor.NextPacketList(LList, 'k1 > 0', 'k1', 10, 0);
    Assert.AreEqual(1, LList.Count);
  finally
    LList.Free;
    LExecutor.Free;
    LSession.Free;
  end;
end;

procedure TTestCursorAdvance.NextPacketList_WithWhere_ZeroRows_ReturnsEmpty;
var
  LConn: IDBConnection;
  LSession: TSessionObjectSet<TKeyOnly>;
  LExecutor: TSQLCommandExecutor<TKeyOnly>;
  LList: TObjectList<TKeyOnly>;
begin
  LConn := NewConnection(0);
  LSession := TSessionObjectSet<TKeyOnly>.Create(LConn, 10);
  LExecutor := TSQLCommandExecutor<TKeyOnly>.Create(LSession, LConn, 10);
  LList := TObjectList<TKeyOnly>.Create;
  try
    LExecutor.NextPacketList(LList, 'k1 > 0', 'k1', 10, 0);
    Assert.AreEqual(0, LList.Count);
    Assert.IsTrue(LSession.FetchingRecords);
  finally
    LList.Free;
    LExecutor.Free;
    LSession.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Janus.Session.DataSet.pas - _PopularDataSet and the two Refresh paths
// ---------------------------------------------------------------------------

procedure TTestCursorAdvance.PopularDataSet_ThreeRows_LoadsThreeRecords;
var
  LConn: IDBConnection;
  LTable: TFDMemTable;
  LContainer: IContainerDataSet<TKeyOnly>;
begin
  LConn := NewConnection(cROWS);
  LTable := TFDMemTable.Create(nil);
  try
    LContainer := TContainerFDMemTable<TKeyOnly>.Create(LConn, LTable);
    LContainer.Open;
    Assert.AreEqual(cROWS, LTable.RecordCount,
      'the Open path must append one DataSet record PER ROW of the result set');
    LTable.First;
    Assert.AreEqual(100, LTable.FieldByName('k1').AsInteger);
    LTable.Last;
    Assert.AreEqual(102, LTable.FieldByName('k1').AsInteger,
      'the last record must carry the LAST row, proving the cursor advanced');
    LContainer := nil;
  finally
    LTable.Free;
  end;
end;

procedure TTestCursorAdvance.PopularDataSet_OneRow_LoadsOneRecord;
var
  LConn: IDBConnection;
  LTable: TFDMemTable;
  LContainer: IContainerDataSet<TKeyOnly>;
begin
  LConn := NewConnection(1);
  LTable := TFDMemTable.Create(nil);
  try
    LContainer := TContainerFDMemTable<TKeyOnly>.Create(LConn, LTable);
    LContainer.Open;
    Assert.AreEqual(1, LTable.RecordCount);
    LContainer := nil;
  finally
    LTable.Free;
  end;
end;

procedure TTestCursorAdvance.PopularDataSet_ZeroRows_LoadsNothing;
var
  LConn: IDBConnection;
  LTable: TFDMemTable;
  LContainer: IContainerDataSet<TKeyOnly>;
begin
  LConn := NewConnection(0);
  LTable := TFDMemTable.Create(nil);
  try
    LContainer := TContainerFDMemTable<TKeyOnly>.Create(LConn, LTable);
    LContainer.Open;
    Assert.AreEqual(0, LTable.RecordCount);
    LContainer := nil;
  finally
    LTable.Free;
  end;
end;

procedure TTestCursorAdvance.RefreshRecordWhere_ThreeRows_Terminates;
var
  LConn: IDBConnection;
  LTable: TFDMemTable;
  LContainer: IContainerDataSet<TKeyOnly>;
begin
  // RefreshRecordWhere re-applies EVERY row of the result set onto the current
  // record (that is the shipped semantic). What matters here is that it stops:
  // without the fix it re-applies row 1 forever.
  LConn := NewConnection(cROWS);
  LTable := TFDMemTable.Create(nil);
  try
    LContainer := TContainerFDMemTable<TKeyOnly>.Create(LConn, LTable);
    LContainer.Open;
    LTable.First;
    LContainer.RefreshRecordWhere('k1 = 100');
    Assert.AreEqual(cROWS, LTable.RecordCount,
      'refreshing must not add or drop records');
    LContainer := nil;
  finally
    LTable.Free;
  end;
end;

procedure TTestCursorAdvance.RefreshRecord_ThreeRows_Terminates;
var
  LConn: IDBConnection;
  LTable: TFDMemTable;
  LContainer: IContainerDataSet<TKeyOnly>;
begin
  LConn := NewConnection(cROWS);
  LTable := TFDMemTable.Create(nil);
  try
    LContainer := TContainerFDMemTable<TKeyOnly>.Create(LConn, LTable);
    LContainer.Open;
    LTable.First;
    LContainer.RefreshRecord;
    Assert.AreEqual(cROWS, LTable.RecordCount,
      'refreshing must not add or drop records');
    LContainer := nil;
  finally
    LTable.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Janus.Mapping.Lazy.pas - the two lazy association load funcs
// ---------------------------------------------------------------------------

procedure TTestCursorAdvance.LazySingleAssociation_ThreeRows_Terminates;
var
  LConn: IDBConnection;
  LFactory: TDMLCommandFactory;
  LOwner: TExame;
  LAssoc: TAssociationMapping;
  LFunc: TLazyLoadFunc;
  LSeen: TObjectList<TObject>;
  LResult: TObject;
begin
  LConn := LazyConnection(cROWS);
  LAssoc := AssociationOf(TExame, TMultiplicity.OneToOne);
  Assert.IsNotNull(LAssoc, 'TExame must expose a OneToOne association');
  LOwner := TExame.Create;
  // LSeen MUST NOT own what it collects. The loop releases every instance it
  // discards, so an owning list here would free those a second time. What the
  // loop does NOT release is the instance it RETURNS: on this direct-call
  // route no proxy takes it, so the test frees LResult itself.
  LSeen := TObjectList<TObject>.Create(False);
  LFactory := TDMLCommandFactory.Create(LOwner, LConn, dnSQLite);
  LResult := nil;
  try
    LFunc := CreateLazySingleAssociationLoadFunc(LOwner, LAssoc, LFactory,
      procedure(const AResultSet: IDBDataSet; const AObject: TObject)
      begin
        LSeen.Add(AObject);
      end,
      nil, nil);
    LResult := LFunc();
    Assert.IsNotNull(LResult, 'a populated cursor must yield an object');
    Assert.AreEqual(cROWS, LSeen.Count,
      'the loop must visit every row exactly once - proof it advanced');
  finally
    LResult.Free;
    LSeen.Free;
    LFactory.Free;
    LOwner.Free;
  end;
end;

procedure TTestCursorAdvance.LazySingleAssociation_ThreeRows_FreesEveryDiscardedInstance;
var
  LConn: IDBConnection;
  LFactory: TDMLCommandFactory;
  LOwner: TLazyCtorLazyRoot;
  LAssoc: TAssociationMapping;
  LFunc: TLazyLoadFunc;
  LSeen: TList<Pointer>;
  LDistinct: TList<Pointer>;
  LResult: TObject;
  LPtr: Pointer;
  LDestroyed: Integer;
begin
  // WHY THIS OWNER AND NOT TExame. The class the loop instantiates is the type
  // of the association property, and only TLazyCtorChild carries the
  // per-address destruction ledger this clause reads.
  LConn := LazyConnection(cROWS);
  LAssoc := AssociationOf(TLazyCtorLazyRoot, TMultiplicity.OneToOne);
  Assert.IsNotNull(LAssoc,
    'TLazyCtorLazyRoot must expose a OneToOne association');
  LOwner := TLazyCtorLazyRoot.Create;
  // ADDRESSES, never references: every pointer collected here may already
  // name a destroyed object by the time the clause runs, and nothing below
  // ever dereferences one.
  LSeen := TList<Pointer>.Create;
  LDistinct := TList<Pointer>.Create;
  LFactory := TDMLCommandFactory.Create(LOwner, LConn, dnSQLite);
  LResult := nil;
  try
    TLazyCtorChild.ResetLedger;
    // ABindToObject is the only seam that sees EVERY instance the loop makes.
    // The load func hands the object to it before deciding what to keep.
    LFunc := CreateLazySingleAssociationLoadFunc(LOwner, LAssoc, LFactory,
      procedure(const AResultSet: IDBDataSet; const AObject: TObject)
      begin
        LSeen.Add(Pointer(AObject));
      end,
      nil, nil);
    LResult := LFunc();
    Assert.IsNotNull(LResult, 'a populated cursor must yield an object');
    // Without this the clause below could pass on a loop that built ONE
    // object: no instance discarded, nothing to release.
    Assert.AreEqual(cROWS, LSeen.Count,
      'the callback must see one instance per row');

    // HOW ADDRESS REUSE IS HANDLED. Releasing an instance hands its block back
    // to the memory manager, so a LATER instance of the loop may be allocated
    // at an address an EARLIER one used - and then LSeen holds the same
    // pointer twice. Summing the ledger over the DISTINCT addresses collected
    // survives that: each destruction is recorded once against whatever
    // address it happened at, and every such address is in the collection,
    // so the sum equals the number of instances released during the window -
    // no matter how the addresses were shared. Reading one chosen address
    // instead would not survive it, which is why no clause here does.
    for LPtr in LSeen do
      if LDistinct.IndexOf(LPtr) < 0 then
        LDistinct.Add(LPtr);
    LDestroyed := 0;
    for LPtr in LDistinct do
      Inc(LDestroyed, TLazyCtorChild.DestructionsOf(LPtr));
    Assert.AreEqual(cROWS - 1, LDestroyed,
      'the loop must release every instance it discards - one per row except ' +
      'the one it returns');
  finally
    LResult.Free;
    LDistinct.Free;
    LSeen.Free;
    LFactory.Free;
    LOwner.Free;
  end;
end;

procedure TTestCursorAdvance.LazySingleAssociation_ZeroRows_ReturnsNil;
var
  LConn: IDBConnection;
  LFactory: TDMLCommandFactory;
  LOwner: TExame;
  LAssoc: TAssociationMapping;
  LFunc: TLazyLoadFunc;
begin
  LConn := LazyConnection(0);
  LAssoc := AssociationOf(TExame, TMultiplicity.OneToOne);
  LOwner := TExame.Create;
  LFactory := TDMLCommandFactory.Create(LOwner, LConn, dnSQLite);
  try
    LFunc := CreateLazySingleAssociationLoadFunc(LOwner, LAssoc, LFactory,
      procedure(const AResultSet: IDBDataSet; const AObject: TObject)
      begin
      end,
      nil, nil);
    Assert.IsNull(LFunc(), 'an empty cursor must yield nil');
  finally
    LFactory.Free;
    LOwner.Free;
  end;
end;

/// Binds the MNEMONICO of the current row into TSetor.NOME, so every object
/// the loop produces carries the MARKER OF THE ROW IT CAME FROM. LazyRow
/// writes 'MN0', 'MN1', 'MN2' - distinct, ordered and named. Without this a
/// count assertion would pass on three copies of row zero.
function LazyRowMarker: TLazyBindToObjectProc;
begin
  Result :=
    procedure(const AResultSet: IDBDataSet; const AObject: TObject)
    begin
      TSetor(AObject).NOME := AResultSet.FieldByName('MNEMONICO').AsString;
    end;
end;

procedure TTestCursorAdvance.LazyManyAssociation_ThreeRows_ReturnsOneObjectPerRowInOrder;
var
  LConn: IDBConnection;
  LFactory: TDMLCommandFactory;
  LOwner: TProcedimento;
  LAssoc: TAssociationMapping;
  LFunc: TLazyLoadFunc;
  LResult: TObject;
  LList: TObjectList<TSetor>;
  LFor: Integer;
begin
  // ESTE TESTE SUBSTITUI LazyManyAssociation_CannotRun_KNOWN_DEFECT, que
  // consagrava o defeito #210: CreateLazyManyAssociationLoadFunc levantava
  // 'Parameter count mismatch' em LObjectList.MethodCall('Create', [True])
  // ANTES de tocar o cursor, e por isso o laco OneToMany era codigo morto em
  // runtime - o unico sitio de avanco de cursor que esta fixture nao cobria.
  // Trocar aquela assercao em vez de reescrever o teste teria reconsagrado o
  // defeito, e era exatamente o que aquele teste pedia para nao se fazer.
  LConn := LazyConnection(cROWS);
  LAssoc := AssociationOf(TProcedimento, TMultiplicity.OneToMany);
  Assert.IsNotNull(LAssoc, 'TProcedimento must expose a OneToMany association');
  LOwner := TProcedimento.Create;
  LFactory := TDMLCommandFactory.Create(LOwner, LConn, dnSQLite);
  LResult := nil;
  try
    LFunc := CreateLazyManyAssociationLoadFunc(LOwner, LAssoc, LFactory,
      LazyRowMarker(), nil, nil);
    LResult := LFunc();

    Assert.IsNotNull(LResult,
      'the lazy OneToMany factory must hand back a list. Before #210 it never ' +
      'got this far: the list was built with TClass.Create followed by ' +
      'MethodCall(''Create'', [True]), and that second call raised');
    Assert.IsTrue(LResult is TObjectList<TSetor>,
      'and the list must be of the property''s own type, not some substitute: ' +
      LResult.ClassName);
    LList := TObjectList<TSetor>(LResult);
    Assert.AreEqual(cROWS, LList.Count,
      'one object per row, and the cursor really advanced - a loop that did ' +
      'not would have been stopped by ECursorRunaway long before this line');
    // ORDEM, nao conjunto: uma troca entre duas linhas passa despercebida por
    // qualquer assercao que so olhe para o conjunto ou para a contagem.
    for LFor := 0 to cROWS - 1 do
      Assert.AreEqual('MN' + IntToStr(LFor), LList.Items[LFor].NOME,
        'row ' + IntToStr(LFor) + ' of the cursor must be item ' +
        IntToStr(LFor) + ' of the list, IN THAT ORDER');
  finally
    LResult.Free;
    LFactory.Free;
    LOwner.Free;
  end;
end;

procedure TTestCursorAdvance.LazyManyAssociation_TheListItReturnsOwnsItsItems;
var
  LConn: IDBConnection;
  LFactory: TDMLCommandFactory;
  LOwner: TProcedimento;
  LAssoc: TAssociationMapping;
  LFunc: TLazyLoadFunc;
  LResult: TObject;
begin
  LConn := LazyConnection(cROWS);
  LAssoc := AssociationOf(TProcedimento, TMultiplicity.OneToMany);
  LOwner := TProcedimento.Create;
  LFactory := TDMLCommandFactory.Create(LOwner, LConn, dnSQLite);
  LResult := nil;
  try
    LFunc := CreateLazyManyAssociationLoadFunc(LOwner, LAssoc, LFactory,
      LazyRowMarker(), nil, nil);
    LResult := LFunc();
    Assert.IsTrue(TObjectList<TSetor>(LResult).OwnsObjects,
      'THE LIST MUST OWN ITS ITEMS. TLazyProxyLoader.Destroy frees the list ' +
      'and nothing else in the framework holds a reference to the objects the ' +
      'loop created, so a list built without ownership leaks one object per ' +
      'row of every lazy collection ever loaded. MEDIDO: the parameterless ' +
      'TObjectList<T>.Create the RTTI hands back is the RTL one, which sets ' +
      'OwnsObjects to True');
  finally
    LResult.Free;
    LFactory.Free;
    LOwner.Free;
  end;
end;

procedure TTestCursorAdvance.LazyManyAssociation_ZeroRows_ReturnsAnEmptyList;
var
  LConn: IDBConnection;
  LFactory: TDMLCommandFactory;
  LOwner: TProcedimento;
  LAssoc: TAssociationMapping;
  LFunc: TLazyLoadFunc;
  LResult: TObject;
begin
  LConn := LazyConnection(0);
  LAssoc := AssociationOf(TProcedimento, TMultiplicity.OneToMany);
  LOwner := TProcedimento.Create;
  LFactory := TDMLCommandFactory.Create(LOwner, LConn, dnSQLite);
  LResult := nil;
  try
    LFunc := CreateLazyManyAssociationLoadFunc(LOwner, LAssoc, LFactory,
      LazyRowMarker(), nil, nil);
    LResult := LFunc();
    Assert.IsNotNull(LResult,
      'AN EMPTY COLLECTION IS AN EMPTY LIST, NOT nil - the OneToOne sibling ' +
      'answers nil for no rows and this one must not, because the property ' +
      'the proxy feeds is a list and a consumer will iterate it');
    Assert.AreEqual(0, TObjectList<TSetor>(LResult).Count,
      'and it must be empty');
  finally
    LResult.Free;
    LFactory.Free;
    LOwner.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Fatos medidos que este trabalho consagra em CI
// ---------------------------------------------------------------------------

procedure TTestCursorAdvance.MasterDetailPost_DoesNotAdvanceCursor_ASSUMPTION;

  // 0 = master-detail ligado E valor do master ALTERADO; 1 = SEM vinculo;
  //     2 = ligado, valor INALTERADO. O cenario 0 ERA o que
  //     SetAutoIncValueChilds enfrentava de frente; hoje o metodo desliga o
  //     vinculo antes de escrever, precisamente PORQUE o cenario 0 mede o que
  //     mede aqui.
  function Iterations(const AScenario: Integer): Integer;
  var
    LMaster, LDetail: TFDMemTable;
    LSource: TDataSource;
    LFor: Integer;
  begin
    LMaster := TFDMemTable.Create(nil);
    LDetail := TFDMemTable.Create(nil);
    LSource := TDataSource.Create(nil);
    try
      LMaster.FieldDefs.Add('pid', ftInteger);
      LMaster.CreateDataSet;
      LMaster.Append; LMaster.FieldByName('pid').AsInteger := 1; LMaster.Post;

      LDetail.FieldDefs.Add('cid', ftInteger);
      LDetail.FieldDefs.Add('pid', ftInteger);
      LDetail.CreateDataSet;
      for LFor := 0 to cROWS - 1 do
      begin
        LDetail.Append;
        LDetail.FieldByName('cid').AsInteger := 500 + LFor;
        LDetail.FieldByName('pid').AsInteger := 1;
        LDetail.Post;
      end;

      LSource.DataSet := LMaster;
      if AScenario <> 1 then
      begin
        // espelho de Janus.RestDataSet.FDMemTable.pas _FilterDataSetChilds
        LDetail.MasterSource := LSource;
        LDetail.IndexFieldNames := 'pid';
        LDetail.MasterFields := 'pid';
      end;

      // espelho de TRESTDataSetAdapter<M>.ApplyInserter: o master fica em
      // dsEdit com o autoinc recem-gerado ainda NAO postado.
      LMaster.Edit;
      if AScenario <> 2 then
        LMaster.FieldByName('pid').AsInteger := 500;

      // espelho do corpo que SetAutoIncValueChilds TINHA - Edit/Post sobre a
      // linha corrente -, com teto rigido para esta sonda jamais travar a
      // suite.
      LDetail.First;
      Result := 0;
      while (not LDetail.Eof) and (Result < 50) do
      begin
        LDetail.Edit;
        LDetail.FieldByName('pid').Value := LMaster.FieldByName('pid').Value;
        LDetail.Post;
        Inc(Result);
      end;
    finally
      LDetail.MasterSource := nil;
      LSource.Free;
      LDetail.Free;
      LMaster.Free;
    end;
  end;

begin
  // POR QUE ESTE TESTE EXISTE. O codigo de SetAutoIncValueChilds carregava um
  // comentario afirmando que o NEXT era desnecessario "porque o dataset esta
  // com filtro que faz a navegacao ao mudar o valor do campo". Isso e falso, e
  // o comentario sobreviveu anos por nunca ter sido medido. Este teste fixa o
  // comportamento REAL do vinculo master-detail do FireDAC, que e a premissa
  // de que aquele codigo depende. Se a Embarcadero um dia mudar isso, este
  // teste fica vermelho e avisa - em vez de o ERP travar em producao.
  //
  // ELE CONTINUA VALIDO DEPOIS DO CONSERTO DO AUTOINC, e por construcao: nao
  // descreve o comportamento do Janus, descreve o do FireDAC, que e a premissa
  // que o conserto CONTORNA desligando o vinculo antes de escrever. O preco do
  // cenario 0 - zero filhos atualizados - esta medido em
  // Test.Janus.AutoInc.Childs.
  Assert.AreEqual(0, Iterations(0),
    'com o vinculo ativo e o valor do master ja alterado, o conjunto filho ' +
    'fica VAZIO: qualquer laco sobre ele visita zero linhas');
  Assert.AreEqual(50, Iterations(1),
    'SEM vinculo master-detail o Post NAO move o cursor - o laco bateu no ' +
    'teto da sonda, ou seja, em producao seria INFINITO sem o .Next');
  Assert.AreEqual(50, Iterations(2),
    'com vinculo mas valor do master inalterado o Post tambem NAO move o ' +
    'cursor - de novo infinito sem o .Next');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestCursorAdvance);

end.
