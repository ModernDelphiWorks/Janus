unit TestCodeGenEngine;

interface

uses
  DUnitX.TestFramework,
  SysUtils,
  Classes,
  Generics.Collections,
  Janus.CodeGen.Types,
  Janus.CodeGen.Schema,
  Janus.CodeGen.Engine,
  Janus.CodeGen.Options;

type
  TMockSchemaReader = class(TInterfacedObject, IJanusSchemaReader)
  private
    FTables: TArray<TTableInfo>;
    FColumns: TDictionary<String, TArray<TColumnInfo>>;
    FPrimaryKeys: TDictionary<String, TArray<TPrimaryKeyInfo>>;
    FForeignKeys: TDictionary<String, TArray<TForeignKeyInfo>>;
    FIndexes: TDictionary<String, TArray<TIndexInfo>>;
    FChecks: TDictionary<String, TArray<TCheckInfo>>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddTable(const AName: String);
    procedure SetColumns(const ATableName: String; const AColumns: TArray<TColumnInfo>);
    procedure SetPrimaryKeys(const ATableName: String; const AKeys: TArray<TPrimaryKeyInfo>);
    procedure SetForeignKeys(const ATableName: String; const AKeys: TArray<TForeignKeyInfo>);
    procedure SetIndexes(const ATableName: String; const AIndexes: TArray<TIndexInfo>);
    procedure SetChecks(const ATableName: String; const AChecks: TArray<TCheckInfo>);
    function GetTables: TArray<TTableInfo>;
    function GetColumns(const ATableName: String): TArray<TColumnInfo>;
    function GetPrimaryKeys(const ATableName: String): TArray<TPrimaryKeyInfo>;
    function GetForeignKeys(const ATableName: String): TArray<TForeignKeyInfo>;
    function GetIndexes(const ATableName: String): TArray<TIndexInfo>;
    function GetChecks(const ATableName: String): TArray<TCheckInfo>;
    procedure Connect;
    procedure Disconnect;
    function IsConnected: Boolean;
  end;

  [TestFixture]
  TTestCodeGenEngine = class
  private
    FMock: TMockSchemaReader;
    FMockIntf: IJanusSchemaReader;
    FOptions: TJanusCodeGenOptions;
    function _CreateSimpleTable: TTableInfo;
    function _CreateColumns: TArray<TColumnInfo>;
    function _CreatePK: TArray<TPrimaryKeyInfo>;
    function _CreateFK: TArray<TForeignKeyInfo>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestGenerateUnit_ContainsUnitName;

    [Test]
    procedure TestGenerateUnit_ContainsTableAttribute;

    [Test]
    procedure TestGenerateUnit_ContainsEntityAttribute;

    [Test]
    procedure TestGenerateUnit_ContainsPrimaryKeyAttribute;

    [Test]
    procedure TestGenerateUnit_ContainsColumnAttribute;

    [Test]
    procedure TestGenerateUnit_ContainsPrivateField;

    [Test]
    procedure TestGenerateUnit_NullableWrapping;

    [Test]
    procedure TestGenerateUnit_ForeignKeyAttribute;

    [Test]
    procedure TestGenerateUnit_LowerCaseProperty;

    [Test]
    procedure TestGenerateUnit_LazyField;

    [Test]
    procedure TestGenerateUnit_DictionaryAttribute;

    [Test]
    procedure TestGenerateUnit_ForeignKeyConstructorDestructor;

    [Test]
    procedure TestSchemaReader_MockReturnsTables;

    [Test]
    procedure TestSchemaReader_MockReturnsColumns;

    [Test]
    procedure TestGenerateAll_MultipleTablesMultipleUnits;

    [Test]
    procedure TestGenerateUnit_NoIndexes_EmptyAttributes;

    [Test]
    procedure TestGenerateUnit_SingleIndex_GeneratesIndexeAttribute;

    [Test]
    procedure TestGenerateUnit_CompositeIndex_ColumnsConcatenated;

    [Test]
    procedure TestGenerateUnit_CheckConstraint_GeneratesCheckAttribute;

    [Test]
    procedure TestGenerateUnit_UniqueIndex_UniqueTrue;

    [Test]
    procedure TestGenerateUnit_MultipleIndexesAndChecks_AllGenerated;
  end;

implementation

{ TMockSchemaReader }

constructor TMockSchemaReader.Create;
begin
  inherited Create;
  FColumns := TDictionary<String, TArray<TColumnInfo>>.Create;
  FPrimaryKeys := TDictionary<String, TArray<TPrimaryKeyInfo>>.Create;
  FForeignKeys := TDictionary<String, TArray<TForeignKeyInfo>>.Create;
  FIndexes := TDictionary<String, TArray<TIndexInfo>>.Create;
  FChecks := TDictionary<String, TArray<TCheckInfo>>.Create;
end;

destructor TMockSchemaReader.Destroy;
begin
  FColumns.Free;
  FPrimaryKeys.Free;
  FForeignKeys.Free;
  FIndexes.Free;
  FChecks.Free;
  inherited;
end;

procedure TMockSchemaReader.AddTable(const AName: String);
var
  LTable: TTableInfo;
begin
  LTable.Name := AName;
  LTable.Schema := '';
  LTable.Catalog := '';
  SetLength(FTables, Length(FTables) + 1);
  FTables[Length(FTables) - 1] := LTable;
end;

procedure TMockSchemaReader.SetColumns(const ATableName: String;
  const AColumns: TArray<TColumnInfo>);
begin
  FColumns.AddOrSetValue(ATableName, AColumns);
end;

procedure TMockSchemaReader.SetPrimaryKeys(const ATableName: String;
  const AKeys: TArray<TPrimaryKeyInfo>);
begin
  FPrimaryKeys.AddOrSetValue(ATableName, AKeys);
end;

procedure TMockSchemaReader.SetForeignKeys(const ATableName: String;
  const AKeys: TArray<TForeignKeyInfo>);
begin
  FForeignKeys.AddOrSetValue(ATableName, AKeys);
end;

procedure TMockSchemaReader.SetIndexes(const ATableName: String;
  const AIndexes: TArray<TIndexInfo>);
begin
  FIndexes.AddOrSetValue(ATableName, AIndexes);
end;

procedure TMockSchemaReader.SetChecks(const ATableName: String;
  const AChecks: TArray<TCheckInfo>);
begin
  FChecks.AddOrSetValue(ATableName, AChecks);
end;

function TMockSchemaReader.GetTables: TArray<TTableInfo>;
begin
  Result := FTables;
end;

function TMockSchemaReader.GetColumns(const ATableName: String): TArray<TColumnInfo>;
begin
  if not FColumns.TryGetValue(ATableName, Result) then
    Result := nil;
end;

function TMockSchemaReader.GetPrimaryKeys(const ATableName: String): TArray<TPrimaryKeyInfo>;
begin
  if not FPrimaryKeys.TryGetValue(ATableName, Result) then
    Result := nil;
end;

function TMockSchemaReader.GetForeignKeys(const ATableName: String): TArray<TForeignKeyInfo>;
begin
  if not FForeignKeys.TryGetValue(ATableName, Result) then
    Result := nil;
end;

function TMockSchemaReader.GetIndexes(const ATableName: String): TArray<TIndexInfo>;
begin
  if not FIndexes.TryGetValue(ATableName, Result) then
    Result := nil;
end;

function TMockSchemaReader.GetChecks(const ATableName: String): TArray<TCheckInfo>;
begin
  if not FChecks.TryGetValue(ATableName, Result) then
    Result := nil;
end;

procedure TMockSchemaReader.Connect;
begin
  // no-op for mock
end;

procedure TMockSchemaReader.Disconnect;
begin
  // no-op for mock
end;

function TMockSchemaReader.IsConnected: Boolean;
begin
  Result := True;
end;

{ TTestCodeGenEngine }

function TTestCodeGenEngine._CreateSimpleTable: TTableInfo;
begin
  Result.Name := 'CLIENTES';
  Result.Schema := '';
  Result.Catalog := '';
end;

function TTestCodeGenEngine._CreateColumns: TArray<TColumnInfo>;
var
  LCol: TColumnInfo;
begin
  SetLength(Result, 3);

  LCol.Name := 'ID';
  LCol.DataTypeName := 'ftInteger';
  LCol.DelphiType := 'Integer';
  LCol.Size := 0;
  LCol.Precision := 0;
  LCol.Scale := 0;
  LCol.Nullable := False;
  LCol.IsPrimaryKey := True;
  LCol.Required := True;
  Result[0] := LCol;

  LCol.Name := 'NOME';
  LCol.DataTypeName := 'ftString';
  LCol.DelphiType := 'String';
  LCol.Size := 100;
  LCol.Precision := 0;
  LCol.Scale := 0;
  LCol.Nullable := True;
  LCol.IsPrimaryKey := False;
  LCol.Required := False;
  Result[1] := LCol;

  LCol.Name := 'SALDO';
  LCol.DataTypeName := 'ftCurrency';
  LCol.DelphiType := 'Currency';
  LCol.Size := 0;
  LCol.Precision := 0;
  LCol.Scale := 0;
  LCol.Nullable := True;
  LCol.IsPrimaryKey := False;
  LCol.Required := False;
  Result[2] := LCol;
end;

function TTestCodeGenEngine._CreatePK: TArray<TPrimaryKeyInfo>;
begin
  SetLength(Result, 1);
  Result[0].ColumnName := 'ID';
  Result[0].Description := 'Chave prim' + #225 + 'ria';
end;

function TTestCodeGenEngine._CreateFK: TArray<TForeignKeyInfo>;
begin
  SetLength(Result, 1);
  Result[0].ForeignKeyName := 'FK_CLIENTES_CIDADE';
  Result[0].ColumnName := 'CIDADE_ID';
  Result[0].ReferenceTableName := 'CIDADES';
  Result[0].ReferenceColumnName := 'ID';
  Result[0].DeleteRule := drNone;
  Result[0].UpdateRule := urCascade;
end;

procedure TTestCodeGenEngine.Setup;
begin
  FMock := TMockSchemaReader.Create;
  FMockIntf := FMock;
  FOptions := TJanusCodeGenOptions.Create;
  FMock.AddTable('CLIENTES');
  FMock.SetColumns('CLIENTES', _CreateColumns);
  FMock.SetPrimaryKeys('CLIENTES', _CreatePK);
  FMock.SetForeignKeys('CLIENTES', nil);
end;

procedure TTestCodeGenEngine.TearDown;
begin
  FreeAndNil(FOptions);
  FMockIntf := nil;
end;

procedure TTestCodeGenEngine.TestGenerateUnit_ContainsUnitName;
var
  LEngine: TJanusCodeGenEngine;
  LSource: String;
begin
  FOptions.ProjectPrefix := 'Model.';
  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSource := LEngine.GenerateUnit(_CreateSimpleTable);
    Assert.Contains(LSource, 'unit Model.clientes;');
  finally
    LEngine.Free;
  end;
end;

procedure TTestCodeGenEngine.TestGenerateUnit_ContainsTableAttribute;
var
  LEngine: TJanusCodeGenEngine;
  LSource: String;
begin
  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSource := LEngine.GenerateUnit(_CreateSimpleTable);
    Assert.Contains(LSource, '[Table(''CLIENTES''');
  finally
    LEngine.Free;
  end;
end;

procedure TTestCodeGenEngine.TestGenerateUnit_ContainsEntityAttribute;
var
  LEngine: TJanusCodeGenEngine;
  LSource: String;
begin
  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSource := LEngine.GenerateUnit(_CreateSimpleTable);
    Assert.Contains(LSource, '[Entity]');
  finally
    LEngine.Free;
  end;
end;

procedure TTestCodeGenEngine.TestGenerateUnit_ContainsPrimaryKeyAttribute;
var
  LEngine: TJanusCodeGenEngine;
  LSource: String;
begin
  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSource := LEngine.GenerateUnit(_CreateSimpleTable);
    Assert.Contains(LSource, '[PrimaryKey(''ID''');
  finally
    LEngine.Free;
  end;
end;

procedure TTestCodeGenEngine.TestGenerateUnit_ContainsColumnAttribute;
var
  LEngine: TJanusCodeGenEngine;
  LSource: String;
begin
  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSource := LEngine.GenerateUnit(_CreateSimpleTable);
    Assert.Contains(LSource, '[Column(''NOME'', ftString, 100)]');
  finally
    LEngine.Free;
  end;
end;

procedure TTestCodeGenEngine.TestGenerateUnit_ContainsPrivateField;
var
  LEngine: TJanusCodeGenEngine;
  LSource: String;
begin
  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSource := LEngine.GenerateUnit(_CreateSimpleTable);
    Assert.Contains(LSource, 'FID: Integer;');
    Assert.Contains(LSource, 'FSALDO: ');
  finally
    LEngine.Free;
  end;
end;

procedure TTestCodeGenEngine.TestGenerateUnit_NullableWrapping;
var
  LEngine: TJanusCodeGenEngine;
  LSource: String;
begin
  FOptions.GenerateNullable := True;
  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSource := LEngine.GenerateUnit(_CreateSimpleTable);
    Assert.Contains(LSource, 'Nullable<String>');
    Assert.Contains(LSource, 'Nullable<Currency>');
  finally
    LEngine.Free;
  end;
end;

procedure TTestCodeGenEngine.TestGenerateUnit_ForeignKeyAttribute;
var
  LEngine: TJanusCodeGenEngine;
  LSource: String;
  LColumns: TArray<TColumnInfo>;
  LCol: TColumnInfo;
begin
  // Add a column for the FK
  LColumns := _CreateColumns;
  SetLength(LColumns, Length(LColumns) + 1);
  LCol.Name := 'CIDADE_ID';
  LCol.DataTypeName := 'ftInteger';
  LCol.DelphiType := 'Integer';
  LCol.Size := 0;
  LCol.Precision := 0;
  LCol.Scale := 0;
  LCol.Nullable := False;
  LCol.IsPrimaryKey := False;
  LCol.Required := True;
  LColumns[Length(LColumns) - 1] := LCol;

  FMock.SetColumns('CLIENTES', LColumns);
  FMock.SetForeignKeys('CLIENTES', _CreateFK);

  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSource := LEngine.GenerateUnit(_CreateSimpleTable);
    Assert.Contains(LSource, '[ForeignKey(''FK_CLIENTES_CIDADE''');
    Assert.Contains(LSource, '[Association(OneToOne,');
  finally
    LEngine.Free;
  end;
end;

procedure TTestCodeGenEngine.TestGenerateUnit_LowerCaseProperty;
var
  LEngine: TJanusCodeGenEngine;
  LSource: String;
begin
  FOptions.LowerCaseNames := True;
  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSource := LEngine.GenerateUnit(_CreateSimpleTable);
    Assert.Contains(LSource, 'property id:');
    Assert.Contains(LSource, 'property nome:');
  finally
    LEngine.Free;
  end;
end;

procedure TTestCodeGenEngine.TestGenerateUnit_LazyField;
var
  LEngine: TJanusCodeGenEngine;
  LSource: String;
  LColumns: TArray<TColumnInfo>;
  LCol: TColumnInfo;
begin
  FOptions.GenerateLazy := True;

  LColumns := _CreateColumns;
  SetLength(LColumns, Length(LColumns) + 1);
  LCol.Name := 'CIDADE_ID';
  LCol.DataTypeName := 'ftInteger';
  LCol.DelphiType := 'Integer';
  LCol.Size := 0;
  LCol.Precision := 0;
  LCol.Scale := 0;
  LCol.Nullable := False;
  LCol.IsPrimaryKey := False;
  LCol.Required := True;
  LColumns[Length(LColumns) - 1] := LCol;

  FMock.SetColumns('CLIENTES', LColumns);
  FMock.SetForeignKeys('CLIENTES', _CreateFK);

  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSource := LEngine.GenerateUnit(_CreateSimpleTable);
    Assert.Contains(LSource, 'Lazy<');
  finally
    LEngine.Free;
  end;
end;

procedure TTestCodeGenEngine.TestGenerateUnit_DictionaryAttribute;
var
  LEngine: TJanusCodeGenEngine;
  LSource: String;
begin
  FOptions.GenerateDictionary := True;
  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSource := LEngine.GenerateUnit(_CreateSimpleTable);
    Assert.Contains(LSource, '[Dictionary(');
    Assert.Contains(LSource, 'taLeftJustify');
    Assert.Contains(LSource, 'taRightJustify');
  finally
    LEngine.Free;
  end;
end;

procedure TTestCodeGenEngine.TestGenerateUnit_ForeignKeyConstructorDestructor;
var
  LEngine: TJanusCodeGenEngine;
  LSource: String;
  LColumns: TArray<TColumnInfo>;
  LCol: TColumnInfo;
begin
  LColumns := _CreateColumns;
  SetLength(LColumns, Length(LColumns) + 1);
  LCol.Name := 'CIDADE_ID';
  LCol.DataTypeName := 'ftInteger';
  LCol.DelphiType := 'Integer';
  LCol.Size := 0;
  LCol.Precision := 0;
  LCol.Scale := 0;
  LCol.Nullable := False;
  LCol.IsPrimaryKey := False;
  LCol.Required := True;
  LColumns[Length(LColumns) - 1] := LCol;

  FMock.SetColumns('CLIENTES', LColumns);
  FMock.SetForeignKeys('CLIENTES', _CreateFK);

  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSource := LEngine.GenerateUnit(_CreateSimpleTable);
    Assert.Contains(LSource, 'constructor Create;');
    Assert.Contains(LSource, 'destructor Destroy; override;');
    Assert.Contains(LSource, 'constructor TCLIENTES.Create;');
    Assert.Contains(LSource, 'destructor TCLIENTES.Destroy;');
  finally
    LEngine.Free;
  end;
end;

procedure TTestCodeGenEngine.TestSchemaReader_MockReturnsTables;
var
  LTables: TArray<TTableInfo>;
begin
  FMock.AddTable('PEDIDOS');
  LTables := FMockIntf.GetTables;
  Assert.AreEqual(2, Length(LTables));
  Assert.AreEqual('CLIENTES', LTables[0].Name);
  Assert.AreEqual('PEDIDOS', LTables[1].Name);
end;

procedure TTestCodeGenEngine.TestSchemaReader_MockReturnsColumns;
var
  LColumns: TArray<TColumnInfo>;
begin
  LColumns := FMockIntf.GetColumns('CLIENTES');
  Assert.AreEqual(3, Length(LColumns));
  Assert.AreEqual('ID', LColumns[0].Name);
  Assert.AreEqual('Integer', LColumns[0].DelphiType);
  Assert.AreEqual('NOME', LColumns[1].Name);
  Assert.AreEqual('String', LColumns[1].DelphiType);
  Assert.AreEqual('SALDO', LColumns[2].Name);
  Assert.AreEqual('Currency', LColumns[2].DelphiType);
end;

procedure TTestCodeGenEngine.TestGenerateAll_MultipleTablesMultipleUnits;
var
  LEngine: TJanusCodeGenEngine;
  LSource1, LSource2: String;
  LTable1, LTable2: TTableInfo;
  LCol: TColumnInfo;
  LPK: TPrimaryKeyInfo;
begin
  // Setup second table
  LCol.Name := 'ID';
  LCol.DataTypeName := 'ftInteger';
  LCol.DelphiType := 'Integer';
  LCol.Size := 0;
  LCol.Precision := 0;
  LCol.Scale := 0;
  LCol.Nullable := False;
  LCol.IsPrimaryKey := True;
  LCol.Required := True;

  LPK.ColumnName := 'ID';
  LPK.Description := 'Chave prim' + #225 + 'ria';

  FMock.AddTable('PEDIDOS');
  FMock.SetColumns('PEDIDOS', TArray<TColumnInfo>.Create(LCol));
  FMock.SetPrimaryKeys('PEDIDOS', TArray<TPrimaryKeyInfo>.Create(LPK));
  FMock.SetForeignKeys('PEDIDOS', nil);

  LTable1.Name := 'CLIENTES';
  LTable1.Schema := '';
  LTable1.Catalog := '';
  LTable2.Name := 'PEDIDOS';
  LTable2.Schema := '';
  LTable2.Catalog := '';

  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSource1 := LEngine.GenerateUnit(LTable1);
    LSource2 := LEngine.GenerateUnit(LTable2);
    Assert.Contains(LSource1, 'TCLIENTES');
    Assert.Contains(LSource2, 'TPEDIDOS');
    Assert.AreNotEqual(LSource1, LSource2);
  finally
    LEngine.Free;
  end;
end;

procedure TTestCodeGenEngine.TestGenerateUnit_NoIndexes_EmptyAttributes;
var
  LEngine: TJanusCodeGenEngine;
  LSource: String;
begin
  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSource := LEngine.GenerateUnit(_CreateSimpleTable);
    Assert.DoesNotContain(LSource, '[Indexe(');
    Assert.DoesNotContain(LSource, '[Check(');
  finally
    LEngine.Free;
  end;
end;

procedure TTestCodeGenEngine.TestGenerateUnit_SingleIndex_GeneratesIndexeAttribute;
var
  LEngine: TJanusCodeGenEngine;
  LSource: String;
  LIdx: TIndexInfo;
begin
  LIdx.Name := 'idx_clientes_nome';
  LIdx.Columns := 'NOME';
  LIdx.Unique := False;
  LIdx.SortingOrder := 'NoSort';
  FMock.SetIndexes('CLIENTES', TArray<TIndexInfo>.Create(LIdx));

  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSource := LEngine.GenerateUnit(_CreateSimpleTable);
    Assert.Contains(LSource, '[Indexe(''idx_clientes_nome'', ''NOME'', NoSort, False, '''')]');
  finally
    LEngine.Free;
  end;
end;

procedure TTestCodeGenEngine.TestGenerateUnit_CompositeIndex_ColumnsConcatenated;
var
  LEngine: TJanusCodeGenEngine;
  LSource: String;
  LIdx: TIndexInfo;
begin
  LIdx.Name := 'idx_clientes_nome_saldo';
  LIdx.Columns := 'NOME,SALDO';
  LIdx.Unique := False;
  LIdx.SortingOrder := 'NoSort';
  FMock.SetIndexes('CLIENTES', TArray<TIndexInfo>.Create(LIdx));

  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSource := LEngine.GenerateUnit(_CreateSimpleTable);
    Assert.Contains(LSource, '''NOME,SALDO''');
  finally
    LEngine.Free;
  end;
end;

procedure TTestCodeGenEngine.TestGenerateUnit_CheckConstraint_GeneratesCheckAttribute;
var
  LEngine: TJanusCodeGenEngine;
  LSource: String;
  LChk: TCheckInfo;
begin
  LChk.Name := 'CHK_SALDO';
  LChk.Condition := 'SALDO >= 0';
  FMock.SetChecks('CLIENTES', TArray<TCheckInfo>.Create(LChk));

  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSource := LEngine.GenerateUnit(_CreateSimpleTable);
    Assert.Contains(LSource, '[Check(''CHK_SALDO'', ''SALDO >= 0'')]');
  finally
    LEngine.Free;
  end;
end;

procedure TTestCodeGenEngine.TestGenerateUnit_UniqueIndex_UniqueTrue;
var
  LEngine: TJanusCodeGenEngine;
  LSource: String;
  LIdx: TIndexInfo;
begin
  LIdx.Name := 'idx_clientes_nome_unique';
  LIdx.Columns := 'NOME';
  LIdx.Unique := True;
  LIdx.SortingOrder := 'NoSort';
  FMock.SetIndexes('CLIENTES', TArray<TIndexInfo>.Create(LIdx));

  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSource := LEngine.GenerateUnit(_CreateSimpleTable);
    Assert.Contains(LSource, '[Indexe(''idx_clientes_nome_unique'', ''NOME'', NoSort, True, '''')]');
  finally
    LEngine.Free;
  end;
end;

procedure TTestCodeGenEngine.TestGenerateUnit_MultipleIndexesAndChecks_AllGenerated;
var
  LEngine: TJanusCodeGenEngine;
  LSource: String;
  LIdx1, LIdx2: TIndexInfo;
  LChk: TCheckInfo;
begin
  LIdx1.Name := 'idx_nome';
  LIdx1.Columns := 'NOME';
  LIdx1.Unique := False;
  LIdx1.SortingOrder := 'NoSort';

  LIdx2.Name := 'idx_saldo';
  LIdx2.Columns := 'SALDO';
  LIdx2.Unique := True;
  LIdx2.SortingOrder := 'NoSort';

  LChk.Name := 'CHK_SALDO';
  LChk.Condition := 'SALDO >= 0';

  FMock.SetIndexes('CLIENTES', TArray<TIndexInfo>.Create(LIdx1, LIdx2));
  FMock.SetChecks('CLIENTES', TArray<TCheckInfo>.Create(LChk));

  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSource := LEngine.GenerateUnit(_CreateSimpleTable);
    Assert.Contains(LSource, '[Indexe(''idx_nome''');
    Assert.Contains(LSource, '[Indexe(''idx_saldo''');
    Assert.Contains(LSource, '[Check(''CHK_SALDO''');
  finally
    LEngine.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestCodeGenEngine);

end.
