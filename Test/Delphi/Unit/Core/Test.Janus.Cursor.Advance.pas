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
    Janus.Query.ResultSet.pas   TJanusQueryObject<M>.AsList

  Fixed but NOT covered by any test, and why:

  1) Janus.Mapping.Lazy.pas  CreateLazyManyAssociationLoadFunc
     No test can reach that loop. The function instantiates the list property
     BEFORE touching the cursor, and both possible property shapes fail first
     (both measured):
       * a plain TObjectList<T>: LObjectList.MethodCall('Create', [True]) ->
         TRttiType.GetMethod('Create') resolves to the inherited ZERO-argument
         TList<T>.Create, so Invoke raises 'Parameter count mismatch'.
         Reproduced on two independent instantiations.
       * a TObjectList<T> DESCENDANT (which fixes the above): the item type is
         recovered by TRttiPropertyHelper.GetTypeValue, which strips
         'TObjectList<' / '>' TEXTUALLY from the type name; a descendant name
         yields FindType(<unqualified name>) = nil -> access violation.
     The test author has no degree of freedom between the two: it is the same
     property feeding both paths. Pinned in CI by
     LazyManyAssociation_CannotRun_KNOWN_DEFECT below.

  2) Janus.RestDataSet.Adapter.pas  TRESTDataSetAdapter<M>.SetAutoIncValueChilds
     Reaching it needs a live REST client session with master-detail children.
     The reason the .Next was added there is measured instead by
     MasterDetailPost_DoesNotAdvanceCursor_ASSUMPTION below.
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
    [Test]
    procedure LazySingleAssociation_ZeroRows_ReturnsNil;

    // ---- fatos medidos que este trabalho consagra em CI -------------------
    [Test]
    procedure MasterDetailPost_DoesNotAdvanceCursor_ASSUMPTION;
    [Test]
    procedure LazyManyAssociation_CannotRun_KNOWN_DEFECT;
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
  // LSeen owns every object the loop creates; the loop returns only the last,
  // so the test has to reclaim the rest itself.
  LSeen := TObjectList<TObject>.Create(True);
  LFactory := TDMLCommandFactory.Create(LOwner, LConn, dnSQLite);
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

// ---------------------------------------------------------------------------
// Fatos medidos que este trabalho consagra em CI
// ---------------------------------------------------------------------------

procedure TTestCursorAdvance.MasterDetailPost_DoesNotAdvanceCursor_ASSUMPTION;

  // 0 = master-detail ligado E valor do master ALTERADO (o caso real de
  //     SetAutoIncValueChilds); 1 = SEM vinculo; 2 = ligado, valor INALTERADO.
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

      // espelho do corpo do laco de SetAutoIncValueChilds, com teto rigido
      // para esta sonda jamais travar a suite.
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
  Assert.AreEqual(0, Iterations(0),
    'com o vinculo ativo e o valor do master ja alterado, o conjunto filho ' +
    'fica VAZIO antes do laco: o corpo nem chega a rodar');
  Assert.AreEqual(50, Iterations(1),
    'SEM vinculo master-detail o Post NAO move o cursor - o laco bateu no ' +
    'teto da sonda, ou seja, em producao seria INFINITO sem o .Next');
  Assert.AreEqual(50, Iterations(2),
    'com vinculo mas valor do master inalterado o Post tambem NAO move o ' +
    'cursor - de novo infinito sem o .Next');
end;

procedure TTestCursorAdvance.LazyManyAssociation_CannotRun_KNOWN_DEFECT;
var
  LConn: IDBConnection;
  LFactory: TDMLCommandFactory;
  LOwner: TProcedimento;
  LAssoc: TAssociationMapping;
  LFunc: TLazyLoadFunc;
  LRaised: Boolean;
  LMessage: string;
begin
  // TESTE QUE CONSAGRA UM DEFEITO. Ele NAO descreve o comportamento desejado.
  //
  // COMPORTAMENTO ATUAL (medido): CreateLazyManyAssociationLoadFunc nunca
  //   executa. Antes de tocar o cursor ela faz LObjectList.MethodCall(
  //   'Create', [True]) (Janus.Mapping.Lazy.pas, em CreateLazyManyAssociation-
  //   LoadFunc); TObjectHelper.MethodCall usa RttiType.GetMethod('Create'),
  //   que para um TObjectList<T> resolve para o construtor de ZERO argumentos
  //   herdado de TList<T>. Invocar com 1 argumento levanta 'Parameter count
  //   mismatch'. Consequencia: o caminho lazy OneToMany/ManyToMany e CODIGO
  //   MORTO em runtime, para qualquer model.
  //
  // COMPORTAMENTO CORRETO: a funcao deveria instanciar a lista e devolver um
  //   objeto por linha do cursor.
  //
  // QUEM CONSERTAR O DEFEITO DEVE REESCREVER OU APAGAR ESTE TESTE - nao
  //   ajustar a assercao. Ele existe para ficar VERMELHO no dia do conserto,
  //   porque esse e exatamente o dia em que o laco de
  //   CreateLazyManyAssociationLoadFunc vira testavel com o duble
  //   Test.Janus.Cursor.Double, e o sitio de avanco de cursor que hoje esta
  //   descoberto passa a poder ser coberto como todos os outros.
  LConn := LazyConnection(cROWS);
  LAssoc := AssociationOf(TProcedimento, TMultiplicity.OneToMany);
  Assert.IsNotNull(LAssoc, 'TProcedimento precisa expor uma associacao OneToMany');
  LOwner := TProcedimento.Create;
  LFactory := TDMLCommandFactory.Create(LOwner, LConn, dnSQLite);
  LRaised := False;
  LMessage := '';
  try
    LFunc := CreateLazyManyAssociationLoadFunc(LOwner, LAssoc, LFactory,
      procedure(const AResultSet: IDBDataSet; const AObject: TObject)
      begin
      end,
      nil, nil);
    try
      LFunc();
    except
      on E: Exception do
      begin
        LRaised := True;
        LMessage := E.Message;
      end;
    end;
    Assert.IsTrue(LRaised,
      'se isto ficou verde, o defeito F1 foi consertado - REESCREVA OU APAGUE ' +
      'este teste e cubra o laco de CreateLazyManyAssociationLoadFunc com o ' +
      'duble Test.Janus.Cursor.Double, como os demais sitios');
    Assert.IsTrue(Pos('Parameter count mismatch', LMessage) > 0,
      'o defeito consagrado e a resolucao do construtor por RTTI; a mensagem ' +
      'mudou para: ' + LMessage);
  finally
    LFactory.Free;
    LOwner.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestCursorAdvance);

end.
