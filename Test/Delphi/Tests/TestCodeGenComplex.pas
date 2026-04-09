unit TestCodeGenComplex;

interface

uses
  DUnitX.TestFramework,
  SysUtils,
  Classes,
  Generics.Collections,
  Janus.CodeGen.Types,
  Janus.CodeGen.Schema,
  Janus.CodeGen.Engine,
  Janus.CodeGen.Options,
  TestCodeGenEngine;

type
  [TestFixture]
  TTestCodeGenComplex = class
  private
    FMock: TMockSchemaReader;
    FMockIntf: IJanusSchemaReader;
    FOptions: TJanusCodeGenOptions;
    function _CreateColumn(const AName, ADataType, ADelphiType: String;
      ASize: Integer; ANullable, AIsPK, ARequired: Boolean): TColumnInfo;
    function _CreatePK(const AColumnName, ADescription: String): TPrimaryKeyInfo;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure TestCodeGen_CompositeForeignKey;
    [Test]
    procedure TestCodeGen_MultipleIndexes_AllGenerated;
    [Test]
    procedure TestCodeGen_MultipleChecks_AllGenerated;
    [Test]
    procedure TestCodeGen_FullEntity_AllAttributesCombined;
    [Test]
    procedure TestCodeGen_NullableLazyDictionary_Combined;
    [Test]
    procedure TestCodeGen_MultiTableWithRelationships;
  end;

implementation

{ TTestCodeGenComplex }

function TTestCodeGenComplex._CreateColumn(const AName, ADataType,
  ADelphiType: String; ASize: Integer; ANullable, AIsPK,
  ARequired: Boolean): TColumnInfo;
begin
  Result.Name := AName;
  Result.DataTypeName := ADataType;
  Result.DelphiType := ADelphiType;
  Result.Size := ASize;
  Result.Precision := 0;
  Result.Scale := 0;
  Result.Nullable := ANullable;
  Result.IsPrimaryKey := AIsPK;
  Result.Required := ARequired;
end;

function TTestCodeGenComplex._CreatePK(const AColumnName,
  ADescription: String): TPrimaryKeyInfo;
begin
  Result.ColumnName := AColumnName;
  Result.Description := ADescription;
end;

procedure TTestCodeGenComplex.Setup;
begin
  FMock := TMockSchemaReader.Create;
  FMockIntf := FMock;
  FOptions := TJanusCodeGenOptions.Create;
end;

procedure TTestCodeGenComplex.TearDown;
begin
  FreeAndNil(FOptions);
  FMockIntf := nil;
end;

procedure TTestCodeGenComplex.TestCodeGen_CompositeForeignKey;
var
  LEngine: TJanusCodeGenEngine;
  LSource: String;
  LTable: TTableInfo;
  LColumns: TArray<TColumnInfo>;
  LPKs: TArray<TPrimaryKeyInfo>;
  LFKs: TArray<TForeignKeyInfo>;
  LFK1, LFK2: TForeignKeyInfo;
begin
  LTable.Name := 'PEDIDO_ITEM';
  LTable.Schema := '';
  LTable.Catalog := '';
  FMock.AddTable('PEDIDO_ITEM');

  SetLength(LColumns, 4);
  LColumns[0] := _CreateColumn('ID', 'ftInteger', 'Integer', 0, False, True, True);
  LColumns[1] := _CreateColumn('PEDIDO_ID', 'ftInteger', 'Integer', 0, False, False, True);
  LColumns[2] := _CreateColumn('PRODUTO_ID', 'ftInteger', 'Integer', 0, False, False, True);
  LColumns[3] := _CreateColumn('QUANTIDADE', 'ftInteger', 'Integer', 0, False, False, True);
  FMock.SetColumns('PEDIDO_ITEM', LColumns);

  SetLength(LPKs, 1);
  LPKs[0] := _CreatePK('ID', 'Chave prim' + #225 + 'ria');
  FMock.SetPrimaryKeys('PEDIDO_ITEM', LPKs);

  LFK1.ForeignKeyName := 'FK_PEDIDO_ITEM_PEDIDO';
  LFK1.ColumnName := 'PEDIDO_ID';
  LFK1.ReferenceTableName := 'PEDIDOS';
  LFK1.ReferenceColumnName := 'ID';
  LFK1.DeleteRule := drCascade;
  LFK1.UpdateRule := urCascade;

  LFK2.ForeignKeyName := 'FK_PEDIDO_ITEM_PRODUTO';
  LFK2.ColumnName := 'PRODUTO_ID';
  LFK2.ReferenceTableName := 'PRODUTOS';
  LFK2.ReferenceColumnName := 'ID';
  LFK2.DeleteRule := drNone;
  LFK2.UpdateRule := urNone;

  SetLength(LFKs, 2);
  LFKs[0] := LFK1;
  LFKs[1] := LFK2;
  FMock.SetForeignKeys('PEDIDO_ITEM', LFKs);

  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSource := LEngine.GenerateUnit(LTable);
    Assert.Contains(LSource, '[ForeignKey(''FK_PEDIDO_ITEM_PEDIDO''');
    Assert.Contains(LSource, '[ForeignKey(''FK_PEDIDO_ITEM_PRODUTO''');
    Assert.Contains(LSource, 'PEDIDOS');
    Assert.Contains(LSource, 'PRODUTOS');
  finally
    LEngine.Free;
  end;
end;

procedure TTestCodeGenComplex.TestCodeGen_MultipleIndexes_AllGenerated;
var
  LEngine: TJanusCodeGenEngine;
  LSource: String;
  LTable: TTableInfo;
  LIdx1, LIdx2, LIdx3: TIndexInfo;
  LPK: TPrimaryKeyInfo;
begin
  LTable.Name := 'PRODUTOS';
  LTable.Schema := '';
  LTable.Catalog := '';
  FMock.AddTable('PRODUTOS');

  FMock.SetColumns('PRODUTOS', TArray<TColumnInfo>.Create(
    _CreateColumn('ID', 'ftInteger', 'Integer', 0, False, True, True),
    _CreateColumn('NOME', 'ftString', 'String', 100, False, False, True),
    _CreateColumn('CATEGORIA', 'ftString', 'String', 50, True, False, False),
    _CreateColumn('PRECO', 'ftCurrency', 'Currency', 0, True, False, False)
  ));

  LPK := _CreatePK('ID', 'PK');
  FMock.SetPrimaryKeys('PRODUTOS', TArray<TPrimaryKeyInfo>.Create(LPK));
  FMock.SetForeignKeys('PRODUTOS', nil);

  LIdx1.Name := 'idx_produtos_nome';
  LIdx1.Columns := 'NOME';
  LIdx1.Unique := False;
  LIdx1.SortingOrder := 'NoSort';

  LIdx2.Name := 'idx_produtos_categoria';
  LIdx2.Columns := 'CATEGORIA';
  LIdx2.Unique := False;
  LIdx2.SortingOrder := 'NoSort';

  LIdx3.Name := 'idx_produtos_nome_cat';
  LIdx3.Columns := 'NOME,CATEGORIA';
  LIdx3.Unique := True;
  LIdx3.SortingOrder := 'NoSort';

  FMock.SetIndexes('PRODUTOS', TArray<TIndexInfo>.Create(LIdx1, LIdx2, LIdx3));

  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSource := LEngine.GenerateUnit(LTable);
    Assert.Contains(LSource, '[Indexe(''idx_produtos_nome''');
    Assert.Contains(LSource, '[Indexe(''idx_produtos_categoria''');
    Assert.Contains(LSource, '[Indexe(''idx_produtos_nome_cat''');
    Assert.Contains(LSource, '''NOME,CATEGORIA''');
    Assert.Contains(LSource, 'True');
  finally
    LEngine.Free;
  end;
end;

procedure TTestCodeGenComplex.TestCodeGen_MultipleChecks_AllGenerated;
var
  LEngine: TJanusCodeGenEngine;
  LSource: String;
  LTable: TTableInfo;
  LChk1, LChk2, LChk3: TCheckInfo;
  LPK: TPrimaryKeyInfo;
begin
  LTable.Name := 'FINANCEIRO';
  LTable.Schema := '';
  LTable.Catalog := '';
  FMock.AddTable('FINANCEIRO');

  FMock.SetColumns('FINANCEIRO', TArray<TColumnInfo>.Create(
    _CreateColumn('ID', 'ftInteger', 'Integer', 0, False, True, True),
    _CreateColumn('VALOR', 'ftCurrency', 'Currency', 0, False, False, True),
    _CreateColumn('TIPO', 'ftString', 'String', 1, False, False, True),
    _CreateColumn('PARCELAS', 'ftInteger', 'Integer', 0, False, False, False)
  ));

  LPK := _CreatePK('ID', 'PK');
  FMock.SetPrimaryKeys('FINANCEIRO', TArray<TPrimaryKeyInfo>.Create(LPK));
  FMock.SetForeignKeys('FINANCEIRO', nil);

  LChk1.Name := 'CHK_VALOR';
  LChk1.Condition := 'VALOR >= 0';

  LChk2.Name := 'CHK_TIPO';
  LChk2.Condition := 'TIPO IN (''C'', ''D'')';

  LChk3.Name := 'CHK_PARCELAS';
  LChk3.Condition := 'PARCELAS BETWEEN 1 AND 60';

  FMock.SetChecks('FINANCEIRO', TArray<TCheckInfo>.Create(LChk1, LChk2, LChk3));

  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSource := LEngine.GenerateUnit(LTable);
    Assert.Contains(LSource, '[Check(''CHK_VALOR''');
    Assert.Contains(LSource, '[Check(''CHK_TIPO''');
    Assert.Contains(LSource, '[Check(''CHK_PARCELAS''');
    Assert.Contains(LSource, 'VALOR >= 0');
  finally
    LEngine.Free;
  end;
end;

procedure TTestCodeGenComplex.TestCodeGen_FullEntity_AllAttributesCombined;
var
  LEngine: TJanusCodeGenEngine;
  LSource: String;
  LTable: TTableInfo;
  LFK: TForeignKeyInfo;
  LIdx: TIndexInfo;
  LChk: TCheckInfo;
  LPK: TPrimaryKeyInfo;
begin
  LTable.Name := 'CONTRATOS';
  LTable.Schema := '';
  LTable.Catalog := '';
  FMock.AddTable('CONTRATOS');

  FMock.SetColumns('CONTRATOS', TArray<TColumnInfo>.Create(
    _CreateColumn('ID', 'ftInteger', 'Integer', 0, False, True, True),
    _CreateColumn('NUMERO', 'ftString', 'String', 20, False, False, True),
    _CreateColumn('CLIENTE_ID', 'ftInteger', 'Integer', 0, False, False, True),
    _CreateColumn('VALOR_TOTAL', 'ftCurrency', 'Currency', 0, True, False, False),
    _CreateColumn('OBSERVACOES', 'ftString', 'String', 500, True, False, False)
  ));

  LPK := _CreatePK('ID', 'PK');
  FMock.SetPrimaryKeys('CONTRATOS', TArray<TPrimaryKeyInfo>.Create(LPK));

  LFK.ForeignKeyName := 'FK_CONTRATOS_CLIENTE';
  LFK.ColumnName := 'CLIENTE_ID';
  LFK.ReferenceTableName := 'CLIENTES';
  LFK.ReferenceColumnName := 'ID';
  LFK.DeleteRule := drNone;
  LFK.UpdateRule := urCascade;
  FMock.SetForeignKeys('CONTRATOS', TArray<TForeignKeyInfo>.Create(LFK));

  LIdx.Name := 'idx_contratos_numero';
  LIdx.Columns := 'NUMERO';
  LIdx.Unique := True;
  LIdx.SortingOrder := 'NoSort';
  FMock.SetIndexes('CONTRATOS', TArray<TIndexInfo>.Create(LIdx));

  LChk.Name := 'CHK_VALOR_TOTAL';
  LChk.Condition := 'VALOR_TOTAL >= 0';
  FMock.SetChecks('CONTRATOS', TArray<TCheckInfo>.Create(LChk));

  FOptions.GenerateNullable := True;
  FOptions.GenerateDictionary := True;

  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSource := LEngine.GenerateUnit(LTable);
    Assert.Contains(LSource, '[Entity]');
    Assert.Contains(LSource, '[Table(''CONTRATOS''');
    Assert.Contains(LSource, '[PrimaryKey(''ID''');
    Assert.Contains(LSource, '[ForeignKey(''FK_CONTRATOS_CLIENTE''');
    Assert.Contains(LSource, '[Indexe(''idx_contratos_numero''');
    Assert.Contains(LSource, '[Check(''CHK_VALOR_TOTAL''');
    Assert.Contains(LSource, 'Nullable<Currency>');
    Assert.Contains(LSource, '[Dictionary(');
  finally
    LEngine.Free;
  end;
end;

procedure TTestCodeGenComplex.TestCodeGen_NullableLazyDictionary_Combined;
var
  LEngine: TJanusCodeGenEngine;
  LSource: String;
  LTable: TTableInfo;
  LFK: TForeignKeyInfo;
  LPK: TPrimaryKeyInfo;
begin
  LTable.Name := 'DETALHES';
  LTable.Schema := '';
  LTable.Catalog := '';
  FMock.AddTable('DETALHES');

  FMock.SetColumns('DETALHES', TArray<TColumnInfo>.Create(
    _CreateColumn('ID', 'ftInteger', 'Integer', 0, False, True, True),
    _CreateColumn('DESCRICAO', 'ftString', 'String', 200, True, False, False),
    _CreateColumn('MASTER_ID', 'ftInteger', 'Integer', 0, False, False, True)
  ));

  LPK := _CreatePK('ID', 'PK');
  FMock.SetPrimaryKeys('DETALHES', TArray<TPrimaryKeyInfo>.Create(LPK));

  LFK.ForeignKeyName := 'FK_DETALHES_MASTER';
  LFK.ColumnName := 'MASTER_ID';
  LFK.ReferenceTableName := 'MASTERS';
  LFK.ReferenceColumnName := 'ID';
  LFK.DeleteRule := drCascade;
  LFK.UpdateRule := urCascade;
  FMock.SetForeignKeys('DETALHES', TArray<TForeignKeyInfo>.Create(LFK));

  FOptions.GenerateNullable := True;
  FOptions.GenerateLazy := True;
  FOptions.GenerateDictionary := True;

  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSource := LEngine.GenerateUnit(LTable);
    Assert.Contains(LSource, 'Nullable<String>');
    Assert.Contains(LSource, 'Lazy<');
    Assert.Contains(LSource, '[Dictionary(');
    Assert.Contains(LSource, '[ForeignKey(''FK_DETALHES_MASTER''');
  finally
    LEngine.Free;
  end;
end;

procedure TTestCodeGenComplex.TestCodeGen_MultiTableWithRelationships;
var
  LEngine: TJanusCodeGenEngine;
  LSourceMaster, LSourceDetail: String;
  LTableMaster, LTableDetail: TTableInfo;
  LFK: TForeignKeyInfo;
  LPK1, LPK2: TPrimaryKeyInfo;
begin
  LTableMaster.Name := 'CATEGORIAS';
  LTableMaster.Schema := '';
  LTableMaster.Catalog := '';

  LTableDetail.Name := 'ITENS';
  LTableDetail.Schema := '';
  LTableDetail.Catalog := '';

  FMock.AddTable('CATEGORIAS');
  FMock.AddTable('ITENS');

  FMock.SetColumns('CATEGORIAS', TArray<TColumnInfo>.Create(
    _CreateColumn('ID', 'ftInteger', 'Integer', 0, False, True, True),
    _CreateColumn('NOME', 'ftString', 'String', 80, False, False, True)
  ));
  LPK1 := _CreatePK('ID', 'PK');
  FMock.SetPrimaryKeys('CATEGORIAS', TArray<TPrimaryKeyInfo>.Create(LPK1));
  FMock.SetForeignKeys('CATEGORIAS', nil);

  FMock.SetColumns('ITENS', TArray<TColumnInfo>.Create(
    _CreateColumn('ID', 'ftInteger', 'Integer', 0, False, True, True),
    _CreateColumn('DESCRICAO', 'ftString', 'String', 100, False, False, True),
    _CreateColumn('CATEGORIA_ID', 'ftInteger', 'Integer', 0, False, False, True)
  ));
  LPK2 := _CreatePK('ID', 'PK');
  FMock.SetPrimaryKeys('ITENS', TArray<TPrimaryKeyInfo>.Create(LPK2));

  LFK.ForeignKeyName := 'FK_ITENS_CATEGORIA';
  LFK.ColumnName := 'CATEGORIA_ID';
  LFK.ReferenceTableName := 'CATEGORIAS';
  LFK.ReferenceColumnName := 'ID';
  LFK.DeleteRule := drNone;
  LFK.UpdateRule := urCascade;
  FMock.SetForeignKeys('ITENS', TArray<TForeignKeyInfo>.Create(LFK));

  LEngine := TJanusCodeGenEngine.Create(FMockIntf, FOptions);
  try
    LSourceMaster := LEngine.GenerateUnit(LTableMaster);
    LSourceDetail := LEngine.GenerateUnit(LTableDetail);

    Assert.DoesNotContain(LSourceMaster, '[ForeignKey(');
    Assert.Contains(LSourceMaster, 'TCATEGORIAS');

    Assert.Contains(LSourceDetail, '[ForeignKey(''FK_ITENS_CATEGORIA''');
    Assert.Contains(LSourceDetail, 'CATEGORIAS');
    Assert.Contains(LSourceDetail, 'TITENS');
    Assert.AreNotEqual(LSourceMaster, LSourceDetail);
  finally
    LEngine.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestCodeGenComplex);

end.
