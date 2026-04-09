unit TestMappingCache;

interface

uses
  DUnitX.TestFramework,
  Janus.Objects.Helper,
  MetaDbDiff.mapping.explorer,
  MetaDbDiff.mapping.classes,
  MetaDbDiff.mapping.attributes,
  MetaDbDiff.Types.Mapping,
  Model.Atendimento;

type
  [Table('HELPER_CACHE_TABLE', 'helper table')]
  [Sequence('HELPER_CACHE_SEQ', 5, 2)]
  [NotServerUse]
  THelperCacheEntity = class
  end;

  [Table('HELPER_NO_NOTSERVERUSE', '')]
  THelperNoNotServerUseEntity = class
  end;

  [View('HELPER_CACHE_VIEW', 'helper view')]
  TViewOnlyEntity = class
  end;

  [TestFixture]
  TTestMappingCache = class
  public
    [Test]
    procedure TestGetMappingTable_Atendimento;
    [Test]
    procedure TestGetMappingColumn_Atendimento;
    [Test]
    procedure TestGetMappingAssociation_Atendimento;
    [Test]
    procedure TestGetMappingPrimaryKey_Atendimento;
    [Test]
    procedure TestGetMappingTable_ReturnsSameCachedInstance;
    [Test]
    procedure TestHelperGetTable_UsesExplorerCache;
    [Test]
    procedure TestHelperGetSequence_UsesExplorerCache;
    [Test]
    procedure TestHelperGetNotServerUse_UsesExplorerCache;
    [Test]
    procedure TestHelperGetNotServerUse_ReturnsNilWhenMissing;
    [Test]
    procedure TestHelperGetTable_ReturnsNilForViewEntity;
    [Test]
    procedure TestGetMappingView_ReturnsViewMappingForViewEntity;
  end;

implementation

{ TTestMappingCache }

procedure TTestMappingCache.TestGetMappingTable_Atendimento;
var
  LTable: TTableMapping;
begin
  LTable := TMappingExplorer.GetMappingTable(TAtendimento);
  Assert.IsNotNull(LTable, 'TTableMapping must not be nil');
  Assert.AreEqual('ATENDIMENTOS', LTable.Name);
end;

procedure TTestMappingCache.TestGetMappingColumn_Atendimento;
var
  LColumns: TColumnMappingList;
  LHasPosto: Boolean;
  LHasAtendimento: Boolean;
  LColumn: TColumnMapping;
begin
  LColumns := TMappingExplorer.GetMappingColumn(TAtendimento);
  Assert.IsNotNull(LColumns, 'Column list must not be nil');
  Assert.IsTrue(LColumns.Count >= 2, 'Must have at least 2 columns');

  LHasPosto := False;
  LHasAtendimento := False;
  for LColumn in LColumns do
  begin
    if LColumn.ColumnName = 'POSTO' then
      LHasPosto := True;
    if LColumn.ColumnName = 'ATENDIMENTO' then
      LHasAtendimento := True;
  end;
  Assert.IsTrue(LHasPosto, 'Must contain column POSTO');
  Assert.IsTrue(LHasAtendimento, 'Must contain column ATENDIMENTO');
end;

procedure TTestMappingCache.TestGetMappingAssociation_Atendimento;
var
  LAssociations: TAssociationMappingList;
begin
  LAssociations := TMappingExplorer.GetMappingAssociation(TAtendimento);
  Assert.IsNotNull(LAssociations, 'Association list must not be nil');
  Assert.IsTrue(LAssociations.Count >= 1, 'Must have at least 1 association');
  Assert.AreEqual(Ord(TMultiplicity.OneToMany),
    Ord(LAssociations[0].Multiplicity), 'First association must be OneToMany');
end;

procedure TTestMappingCache.TestGetMappingPrimaryKey_Atendimento;
var
  LPrimaryKey: TPrimaryKeyMapping;
begin
  LPrimaryKey := TMappingExplorer.GetMappingPrimaryKey(TAtendimento);
  Assert.IsNotNull(LPrimaryKey, 'PrimaryKey mapping must not be nil');
end;

procedure TTestMappingCache.TestGetMappingTable_ReturnsSameCachedInstance;
var
  LTable1: TTableMapping;
  LTable2: TTableMapping;
begin
  LTable1 := TMappingExplorer.GetMappingTable(TAtendimento);
  LTable2 := TMappingExplorer.GetMappingTable(TAtendimento);

  Assert.IsNotNull(LTable1, 'First table mapping must not be nil');
  Assert.AreSame(TObject(LTable1), TObject(LTable2),
    'TMappingExplorer must reuse the same cached table mapping instance');
end;

procedure TTestMappingCache.TestHelperGetTable_UsesExplorerCache;
var
  LEntity: THelperCacheEntity;
  LTable1: Table;
  LTable2: Table;
begin
  LEntity := THelperCacheEntity.Create;
  try
    LTable1 := LEntity.GetTable;
    LTable2 := LEntity.GetTable;

    Assert.IsNotNull(LTable1, 'GetTable must return a table attribute');
    Assert.AreEqual('HELPER_CACHE_TABLE', LTable1.Name);
    Assert.AreSame(TObject(LTable1), TObject(LTable2),
      'GetTable must return the same cached helper instance for the same class');
  finally
    LEntity.Free;
  end;
end;

procedure TTestMappingCache.TestHelperGetSequence_UsesExplorerCache;
var
  LEntity: THelperCacheEntity;
  LSequence1: Sequence;
  LSequence2: Sequence;
begin
  LEntity := THelperCacheEntity.Create;
  try
    LSequence1 := LEntity.GetSequence;
    LSequence2 := LEntity.GetSequence;

    Assert.IsNotNull(LSequence1, 'GetSequence must return a sequence attribute');
    Assert.AreEqual('HELPER_CACHE_SEQ', LSequence1.Name);
    Assert.AreEqual(5, LSequence1.Initial);
    Assert.AreEqual(2, LSequence1.Increment);
    Assert.AreSame(TObject(LSequence1), TObject(LSequence2),
      'GetSequence must return the same cached helper instance for the same class');
  finally
    LEntity.Free;
  end;
end;

procedure TTestMappingCache.TestHelperGetNotServerUse_UsesExplorerCache;
var
  LEntity: THelperCacheEntity;
  LNotServerUse1: NotServerUse;
  LNotServerUse2: NotServerUse;
begin
  LEntity := THelperCacheEntity.Create;
  try
    LNotServerUse1 := LEntity.GetNotServerUse;
    LNotServerUse2 := LEntity.GetNotServerUse;

    Assert.IsNotNull(LNotServerUse1, 'GetNotServerUse must return the marker attribute when mapped');
    Assert.AreSame(TObject(LNotServerUse1), TObject(LNotServerUse2),
      'GetNotServerUse must return the same cached helper instance for the same class');
  finally
    LEntity.Free;
  end;
end;

procedure TTestMappingCache.TestHelperGetNotServerUse_ReturnsNilWhenMissing;
var
  LEntity: THelperNoNotServerUseEntity;
begin
  LEntity := THelperNoNotServerUseEntity.Create;
  try
    Assert.IsNull(LEntity.GetNotServerUse,
      'GetNotServerUse must return nil when the attribute is not declared');
  finally
    LEntity.Free;
  end;
end;

procedure TTestMappingCache.TestHelperGetTable_ReturnsNilForViewEntity;
var
  LEntity: TViewOnlyEntity;
  LTable: Table;
begin
  LEntity := TViewOnlyEntity.Create;
  try
    LTable := LEntity.GetTable;
    Assert.IsNull(LTable,
      'GetTable must return nil when only [View] is declared and [Table] is absent');
  finally
    LEntity.Free;
  end;
end;

procedure TTestMappingCache.TestGetMappingView_ReturnsViewMappingForViewEntity;
var
  LView: TViewMapping;
begin
  LView := TMappingExplorer.GetMappingView(TViewOnlyEntity);
  Assert.IsNotNull(LView, 'View mapping must not be nil for [View] entity');
  Assert.AreEqual('HELPER_CACHE_VIEW', LView.Name);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestMappingCache);

end.
