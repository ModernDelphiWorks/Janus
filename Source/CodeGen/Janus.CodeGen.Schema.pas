unit Janus.CodeGen.Schema;

interface

uses
  SysUtils,
  Classes,
  DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Phys.Intf,
  FireDAC.DatS,
  FireDAC.DApt.Intf,
  FireDAC.DApt,
  FireDAC.Comp.DataSet,
  Janus.CodeGen.Types;

type
  IJanusSchemaReader = interface
    ['{A7D3F1E2-4B5C-6D7E-8F9A-0B1C2D3E4F5A}']
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

  TFireDACSchemaReader = class(TInterfacedObject, IJanusSchemaReader)
  private
    FConnection: TFDConnection;
    FOwnsConnection: Boolean;
    FCatalogName: String;
    function _MapFieldType(AFieldType: TFieldType; ASize: Integer;
      APrecision: Integer; AScale: Integer): String;
    function _FieldTypeToDelphiType(AFieldType: TFieldType): String;
    function _DriverUsesCatalog: Boolean;
  public
    constructor Create(AConnection: TFDConnection; AOwnsConnection: Boolean = False);
    destructor Destroy; override;
    function GetTables: TArray<TTableInfo>;
    function GetColumns(const ATableName: String): TArray<TColumnInfo>;
    function GetPrimaryKeys(const ATableName: String): TArray<TPrimaryKeyInfo>;
    function GetForeignKeys(const ATableName: String): TArray<TForeignKeyInfo>;
    function GetIndexes(const ATableName: String): TArray<TIndexInfo>;
    function GetChecks(const ATableName: String): TArray<TCheckInfo>;
    procedure Connect;
    procedure Disconnect;
    function IsConnected: Boolean;
    property CatalogName: String read FCatalogName write FCatalogName;
  end;

implementation

uses
  StrUtils;

{ TFireDACSchemaReader }

constructor TFireDACSchemaReader.Create(AConnection: TFDConnection;
  AOwnsConnection: Boolean);
begin
  inherited Create;
  FConnection := AConnection;
  FOwnsConnection := AOwnsConnection;
  FCatalogName := '';
end;

destructor TFireDACSchemaReader.Destroy;
begin
  if FOwnsConnection then
    FConnection.Free;
  inherited;
end;

procedure TFireDACSchemaReader.Connect;
begin
  if Assigned(FConnection) and (not FConnection.Connected) then
    FConnection.Connected := True;
end;

procedure TFireDACSchemaReader.Disconnect;
begin
  if Assigned(FConnection) and FConnection.Connected then
    FConnection.Connected := False;
end;

function TFireDACSchemaReader.IsConnected: Boolean;
begin
  Result := Assigned(FConnection) and FConnection.Connected;
end;

function TFireDACSchemaReader._DriverUsesCatalog: Boolean;
begin
  Result := AnsiMatchStr(UpperCase(FConnection.DriverName), ['MYSQL']);
end;

function TFireDACSchemaReader.GetTables: TArray<TTableInfo>;
var
  LMeta: TFDMetaInfoQuery;
  LList: TArray<TTableInfo>;
  LCount: Integer;
begin
  LCount := 0;
  LMeta := TFDMetaInfoQuery.Create(nil);
  try
    LMeta.Connection := FConnection;
    LMeta.ObjectScopes := [osMy];
    LMeta.TableKinds := [tkTable, tkView];
    if _DriverUsesCatalog and (FCatalogName <> '') then
      LMeta.CatalogName := FCatalogName;
    LMeta.Active := True;
    LMeta.First;
    SetLength(LList, LMeta.RecordCount);
    while not LMeta.Eof do
    begin
      LList[LCount].Name := LMeta.FieldByName('TABLE_NAME').AsString;
      LList[LCount].Schema := '';
      LList[LCount].Catalog := '';
      Inc(LCount);
      LMeta.Next;
    end;
    SetLength(LList, LCount);
  finally
    LMeta.Free;
  end;
  Result := LList;
end;

function TFireDACSchemaReader.GetColumns(const ATableName: String): TArray<TColumnInfo>;
var
  LQuery: TFDQuery;
  LColumns: TArray<TColumnInfo>;
  LCount: Integer;
  LIndex: Integer;
  LFieldType: TFieldType;
begin
  LCount := 0;
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := 'SELECT * FROM ' + ATableName;
    LQuery.Open;
    SetLength(LColumns, LQuery.FieldCount);
    for LIndex := 0 to LQuery.FieldCount - 1 do
    begin
      LFieldType := LQuery.Fields[LIndex].DataType;
      LColumns[LCount].Name := LQuery.Fields[LIndex].FieldName;
      LColumns[LCount].DataTypeName := _MapFieldType(LFieldType,
        LQuery.Fields[LIndex].Size,
        0, 0);
      LColumns[LCount].DelphiType := _FieldTypeToDelphiType(LFieldType);
      LColumns[LCount].Size := LQuery.Fields[LIndex].Size;
      if LFieldType in [ftFMTBcd, ftBCD] then
      begin
        LColumns[LCount].Precision := TBCDField(LQuery.Fields[LIndex]).Precision;
        LColumns[LCount].Scale := TBCDField(LQuery.Fields[LIndex]).Size;
      end
      else
      begin
        LColumns[LCount].Precision := 0;
        LColumns[LCount].Scale := 0;
      end;
      LColumns[LCount].Nullable := not LQuery.Fields[LIndex].Required;
      LColumns[LCount].Required := LQuery.Fields[LIndex].Required;
      LColumns[LCount].IsPrimaryKey := False;
      Inc(LCount);
    end;
    LQuery.Close;
  finally
    LQuery.Free;
  end;
  Result := LColumns;
end;

function TFireDACSchemaReader.GetPrimaryKeys(const ATableName: String): TArray<TPrimaryKeyInfo>;
var
  LMeta: TFDMetaInfoQuery;
  LList: TArray<TPrimaryKeyInfo>;
  LCount: Integer;
begin
  LCount := 0;
  LMeta := TFDMetaInfoQuery.Create(nil);
  try
    LMeta.Connection := FConnection;
    LMeta.MetaInfoKind := mkPrimaryKeyFields;
    LMeta.BaseObjectName := ATableName;
    LMeta.Open;
    SetLength(LList, LMeta.RecordCount);
    while not LMeta.Eof do
    begin
      LList[LCount].ColumnName := LMeta.FieldByName('COLUMN_NAME').AsString;
      LList[LCount].Description := 'Chave prim' + #225 + 'ria';
      Inc(LCount);
      LMeta.Next;
    end;
    SetLength(LList, LCount);
  finally
    LMeta.Free;
  end;
  Result := LList;
end;

function TFireDACSchemaReader.GetForeignKeys(const ATableName: String): TArray<TForeignKeyInfo>;
var
  LMeta: TFDMetaInfoQuery;
  LFields: TFDMetaInfoQuery;
  LList: TArray<TForeignKeyInfo>;
  LCount: Integer;
begin
  LCount := 0;
  LMeta := TFDMetaInfoQuery.Create(nil);
  LFields := TFDMetaInfoQuery.Create(nil);
  try
    LMeta.Connection := FConnection;
    LMeta.MetaInfoKind := mkForeignKeys;
    LMeta.ObjectName := ATableName;
    LMeta.IndexFieldNames := 'PKEY_TABLE_NAME';
    LMeta.Open;
    SetLength(LList, LMeta.RecordCount);
    while not LMeta.Eof do
    begin
      LFields.Close;
      LFields.Connection := FConnection;
      LFields.MetaInfoKind := mkForeignKeyFields;
      LFields.BaseObjectName := LMeta.FieldByName('TABLE_NAME').AsString;
      LFields.ObjectName := LMeta.FieldByName('FKEY_NAME').AsString;
      LFields.Open;

      LList[LCount].ForeignKeyName := LMeta.FieldByName('FKEY_NAME').AsString;
      LList[LCount].ColumnName := LFields.FieldByName('COLUMN_NAME').AsString;
      LList[LCount].ReferenceTableName := LMeta.FieldByName('PKEY_TABLE_NAME').AsString;
      LList[LCount].ReferenceColumnName := LFields.FieldByName('PKEY_COLUMN_NAME').AsString;
      LList[LCount].DeleteRule := IntToDeleteRule(LMeta.FieldByName('DELETE_RULE').AsInteger);
      LList[LCount].UpdateRule := IntToUpdateRule(LMeta.FieldByName('UPDATE_RULE').AsInteger);
      Inc(LCount);
      LMeta.Next;
    end;
    SetLength(LList, LCount);
  finally
    LFields.Free;
    LMeta.Free;
  end;
  Result := LList;
end;

function TFireDACSchemaReader._FieldTypeToDelphiType(AFieldType: TFieldType): String;
begin
  case AFieldType of
    ftString, ftWideString:
      Result := 'String';
    ftBoolean:
      Result := 'Boolean';
    ftLargeint, ftSmallint, ftInteger, ftWord, ftAutoInc:
      Result := 'Integer';
    ftFloat, ftCurrency:
      Result := 'Currency';
    ftTime:
      Result := 'TTime';
    ftDate, ftDateTime, ftTimeStamp:
      Result := 'TDateTime';
    ftBlob, ftMemo, ftWideMemo, ftOraBlob, ftOraClob:
      Result := 'TBlob';
    ftFMTBcd, ftBCD:
      Result := 'Double';
  else
    Result := 'String';
  end;
end;

function TFireDACSchemaReader._MapFieldType(AFieldType: TFieldType;
  ASize: Integer; APrecision: Integer; AScale: Integer): String;
begin
  case AFieldType of
    ftString, ftWideString:
      Result := 'ftString';
    ftBoolean:
      Result := 'ftBoolean';
    ftLargeint, ftSmallint, ftInteger, ftWord, ftAutoInc:
      Result := 'ftInteger';
    ftFloat, ftCurrency:
      Result := 'ftCurrency';
    ftTime:
      Result := 'ftTime';
    ftDate, ftDateTime, ftTimeStamp:
      Result := 'ftDateTime';
    ftBlob, ftMemo, ftWideMemo, ftOraBlob, ftOraClob:
      Result := 'ftBlob';
    ftFMTBcd, ftBCD:
      Result := 'ftBCD';
  else
    Result := 'ftString';
  end;
end;

function TFireDACSchemaReader.GetIndexes(const ATableName: String): TArray<TIndexInfo>;
var
  LMetaIdx: TFDMetaInfoQuery;
  LMetaFld: TFDMetaInfoQuery;
  LList: TArray<TIndexInfo>;
  LCount: Integer;
  LIndexName: String;
  LColumns: String;
  LUnique: Boolean;
  LPKColumns: TArray<TPrimaryKeyInfo>;
  LPKNames: String;
  LIndex: Integer;
begin
  LPKColumns := GetPrimaryKeys(ATableName);
  LPKNames := '';
  for LIndex := 0 to Length(LPKColumns) - 1 do
  begin
    if LPKNames <> '' then
      LPKNames := LPKNames + ',';
    LPKNames := LPKNames + UpperCase(LPKColumns[LIndex].ColumnName);
  end;

  LCount := 0;
  LMetaIdx := TFDMetaInfoQuery.Create(nil);
  LMetaFld := TFDMetaInfoQuery.Create(nil);
  try
    LMetaIdx.Connection := FConnection;
    LMetaIdx.MetaInfoKind := mkIndexes;
    LMetaIdx.ObjectName := ATableName;
    LMetaIdx.Open;
    SetLength(LList, LMetaIdx.RecordCount);
    while not LMetaIdx.Eof do
    begin
      LIndexName := LMetaIdx.FieldByName('INDEX_NAME').AsString;

      LMetaFld.Close;
      LMetaFld.Connection := FConnection;
      LMetaFld.MetaInfoKind := mkIndexFields;
      LMetaFld.BaseObjectName := ATableName;
      LMetaFld.ObjectName := LIndexName;
      LMetaFld.Open;

      LColumns := '';
      while not LMetaFld.Eof do
      begin
        if LColumns <> '' then
          LColumns := LColumns + ',';
        LColumns := LColumns + LMetaFld.FieldByName('COLUMN_NAME').AsString;
        LMetaFld.Next;
      end;

      if SameText(UpperCase(LColumns), LPKNames) then
      begin
        LMetaIdx.Next;
        Continue;
      end;

      if LMetaIdx.FindField('INDEX_TYPE') <> nil then
        LUnique := SameText(LMetaIdx.FieldByName('INDEX_TYPE').AsString, 'Unique')
      else
        LUnique := False;

      if LCount >= Length(LList) then
        SetLength(LList, LCount + 8);

      LList[LCount].Name := LIndexName;
      LList[LCount].Columns := LColumns;
      LList[LCount].Unique := LUnique;
      LList[LCount].SortingOrder := 'NoSort';
      Inc(LCount);
      LMetaIdx.Next;
    end;
    SetLength(LList, LCount);
  finally
    LMetaFld.Free;
    LMetaIdx.Free;
  end;
  Result := LList;
end;

function TFireDACSchemaReader.GetChecks(const ATableName: String): TArray<TCheckInfo>;
begin
  Result := nil;
end;

end.
