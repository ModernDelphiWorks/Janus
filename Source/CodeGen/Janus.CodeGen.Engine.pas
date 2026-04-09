unit Janus.CodeGen.Engine;

interface

uses
  SysUtils,
  Classes,
  StrUtils,
  Generics.Collections,
  Janus.CodeGen.Types,
  Janus.CodeGen.Schema,
  Janus.CodeGen.Template,
  Janus.CodeGen.Options;

type
  TJanusCodeGenEngine = class
  private
    FSchemaReader: IJanusSchemaReader;
    FOptions: TJanusCodeGenOptions;
    function _GetFieldTypeName(const ADelphiType: String): String;
    function _BuildUsesClause(const AForeignKeys: TArray<TForeignKeyInfo>): String;
    function _BuildPrivateFields(const AColumns: TArray<TColumnInfo>): String;
    function _BuildRelationFields(const AForeignKeys: TArray<TForeignKeyInfo>): String;
    function _BuildProperties(const ATableName: String;
      const AColumns: TArray<TColumnInfo>;
      const APrimaryKeys: TArray<TPrimaryKeyInfo>;
      const AForeignKeys: TArray<TForeignKeyInfo>): String;
    function _BuildRelationProperties(const AForeignKeys: TArray<TForeignKeyInfo>): String;
    function _BuildPrimaryKeyAttributes(const APrimaryKeys: TArray<TPrimaryKeyInfo>): String;
    function _BuildIndexAttributes(const AIndexes: TArray<TIndexInfo>): String;
    function _BuildCheckAttributes(const AChecks: TArray<TCheckInfo>): String;
    function _BuildConstructorDeclaration(const AForeignKeys: TArray<TForeignKeyInfo>;
      const ATableName: String): String;
    function _BuildDestructorDeclaration(const AForeignKeys: TArray<TForeignKeyInfo>): String;
    function _BuildConstructorImplementation(const ATableName: String;
      const AForeignKeys: TArray<TForeignKeyInfo>): String;
    function _BuildDestructorImplementation(const ATableName: String;
      const AForeignKeys: TArray<TForeignKeyInfo>): String;
    function _BuildLazyLoadImplementation(const ATableName: String;
      const AForeignKeys: TArray<TForeignKeyInfo>): String;
    function _IsPrimaryKey(const AColumnName: String;
      const APrimaryKeys: TArray<TPrimaryKeyInfo>): Boolean;
    function _FindForeignKeyForColumn(const AColumnName: String;
      const AForeignKeys: TArray<TForeignKeyInfo>;
      out AFK: TForeignKeyInfo): Boolean;
    function _GetColumnDefault(const ADelphiType: String; ARequired: Boolean): String;
    function _GetColumnAlign(const ADelphiType: String): String;
    function _GetColumnMask(const ADelphiType: String; ARequired: Boolean): String;
  public
    constructor Create(const ASchemaReader: IJanusSchemaReader;
      AOptions: TJanusCodeGenOptions);
    function GenerateUnit(const ATableInfo: TTableInfo): String;
    procedure GenerateAll(const ATables: TArray<TTableInfo>;
      const AOutputPath: String);
  end;

implementation

{ TJanusCodeGenEngine }

constructor TJanusCodeGenEngine.Create(const ASchemaReader: IJanusSchemaReader;
  AOptions: TJanusCodeGenOptions);
begin
  inherited Create;
  FSchemaReader := ASchemaReader;
  FOptions := AOptions;
end;

function TJanusCodeGenEngine._GetFieldTypeName(const ADelphiType: String): String;
begin
  if ADelphiType = 'String' then Result := 'ftString'
  else if ADelphiType = 'Double' then Result := 'ftBCD'
  else if ADelphiType = 'Integer' then Result := 'ftInteger'
  else if ADelphiType = 'TTime' then Result := 'ftTime'
  else if ADelphiType = 'TDateTime' then Result := 'ftDateTime'
  else if ADelphiType = 'Boolean' then Result := 'ftBoolean'
  else if ADelphiType = 'Currency' then Result := 'ftCurrency'
  else if ADelphiType = 'TBlob' then Result := 'ftBlob'
  else Result := 'ftString';
end;

function TJanusCodeGenEngine._IsPrimaryKey(const AColumnName: String;
  const APrimaryKeys: TArray<TPrimaryKeyInfo>): Boolean;
var
  LIndex: Integer;
begin
  Result := False;
  for LIndex := 0 to Length(APrimaryKeys) - 1 do
    if SameText(APrimaryKeys[LIndex].ColumnName, AColumnName) then
      Exit(True);
end;

function TJanusCodeGenEngine._FindForeignKeyForColumn(const AColumnName: String;
  const AForeignKeys: TArray<TForeignKeyInfo>;
  out AFK: TForeignKeyInfo): Boolean;
var
  LIndex: Integer;
begin
  Result := False;
  for LIndex := 0 to Length(AForeignKeys) - 1 do
    if SameText(AForeignKeys[LIndex].ColumnName, AColumnName) then
    begin
      AFK := AForeignKeys[LIndex];
      Exit(True);
    end;
end;

function TJanusCodeGenEngine._GetColumnDefault(const ADelphiType: String;
  ARequired: Boolean): String;
begin
  if (ADelphiType = 'Currency') or (ADelphiType = 'Double') then
    Result := '''0'''
  else if (ADelphiType = 'TDateTime') and ARequired then
    Result := '''Date'''
  else
    Result := '''''';
end;

function TJanusCodeGenEngine._GetColumnAlign(const ADelphiType: String): String;
begin
  if (ADelphiType = 'Integer') or (ADelphiType = 'TTime') or
     (ADelphiType = 'TDateTime') then
    Result := 'taCenter'
  else if (ADelphiType = 'Currency') or (ADelphiType = 'Double') then
    Result := 'taRightJustify'
  else
    Result := 'taLeftJustify';
end;

function TJanusCodeGenEngine._GetColumnMask(const ADelphiType: String;
  ARequired: Boolean): String;
begin
  if (ADelphiType = 'TDateTime') and ARequired then
    Result := '''!##/##/####;1;_'''
  else
    Result := '''''';
end;

function TJanusCodeGenEngine._BuildUsesClause(
  const AForeignKeys: TArray<TForeignKeyInfo>): String;
var
  LResult: TStringList;
  LIndex: Integer;
  LUses: String;
begin
  LResult := TStringList.Create;
  try
    for LIndex := 0 to Length(AForeignKeys) - 1 do
    begin
      LUses := '  ' + FOptions.ProjectPrefix +
        LowerCase(AForeignKeys[LIndex].ReferenceTableName);
      if LResult.IndexOf(LUses) = -1 then
        LResult.Add(LUses);
    end;
    Result := '';
    for LIndex := 0 to LResult.Count - 1 do
      Result := Result + LResult[LIndex] + ',' + sLineBreak;
  finally
    LResult.Free;
  end;
end;

function TJanusCodeGenEngine._BuildPrivateFields(
  const AColumns: TArray<TColumnInfo>): String;
var
  LIndex: Integer;
  LType: String;
begin
  Result := '';
  for LIndex := 0 to Length(AColumns) - 1 do
  begin
    LType := AColumns[LIndex].DelphiType;
    if FOptions.GenerateNullable and AColumns[LIndex].Nullable and
       (LType <> 'TBlob') then
      LType := 'Nullable<' + LType + '>';
    Result := Result + '    F' + AColumns[LIndex].Name + ': ' + LType + ';' + sLineBreak;
  end;
end;

function TJanusCodeGenEngine._BuildRelationFields(
  const AForeignKeys: TArray<TForeignKeyInfo>): String;
var
  LIndex: Integer;
  LRefTable: String;
  LFieldType: String;
begin
  Result := '';
  if Length(AForeignKeys) = 0 then
    Exit;
  Result := sLineBreak;
  for LIndex := 0 to Length(AForeignKeys) - 1 do
  begin
    LRefTable := AForeignKeys[LIndex].ReferenceTableName;
    if FOptions.GenerateLazy then
      LFieldType := 'Lazy< T' + LRefTable + ' >'
    else
      LFieldType := 'T' + LRefTable;
    Result := Result + '    F' + LRefTable + '_' + IntToStr(LIndex) +
      ': ' + LFieldType + ' ;' + sLineBreak;
  end;
end;

function TJanusCodeGenEngine._BuildProperties(const ATableName: String;
  const AColumns: TArray<TColumnInfo>;
  const APrimaryKeys: TArray<TPrimaryKeyInfo>;
  const AForeignKeys: TArray<TForeignKeyInfo>): String;
var
  LIndex: Integer;
  LCol: TColumnInfo;
  LType: String;
  LFieldType: String;
  LFK: TForeignKeyInfo;
  LColumnAttr: String;
  LPropName: String;
begin
  Result := '';
  for LIndex := 0 to Length(AColumns) - 1 do
  begin
    LCol := AColumns[LIndex];
    LType := LCol.DelphiType;
    LFieldType := _GetFieldTypeName(LType);

    if FOptions.GenerateNullable and LCol.Nullable and (LType <> 'TBlob') then
      LType := 'Nullable<' + LType + '>';

    if LIndex > 0 then
      Result := Result + sLineBreak;

    // Restrictions
    if LCol.Required then
      Result := Result + '    [Restrictions([NotNull])]' + sLineBreak;

    // Column attribute
    if LCol.Size > 0 then
      LColumnAttr := QuotedStr(LCol.Name) + ', ' + LFieldType + ', ' +
        IntToStr(LCol.Size)
    else if (LCol.Precision > 0) and (LCol.Scale > 0) then
      LColumnAttr := QuotedStr(LCol.Name) + ', ' + LFieldType + ', ' +
        IntToStr(LCol.Precision) + ', ' + IntToStr(LCol.Scale)
    else
      LColumnAttr := QuotedStr(LCol.Name) + ', ' + LFieldType;

    Result := Result + '    [Column(' + LColumnAttr + ')]' + sLineBreak;

    // ForeignKey attribute inline
    if _FindForeignKeyForColumn(LCol.Name, AForeignKeys, LFK) then
      Result := Result + '    [ForeignKey(' +
        QuotedStr(LFK.ForeignKeyName) + ', ' +
        QuotedStr(LFK.ColumnName) + ', ' +
        QuotedStr(LFK.ReferenceTableName) + ', ' +
        QuotedStr(LFK.ReferenceColumnName) + ', ' +
        DeleteRuleToStr(LFK.DeleteRule) + ', ' +
        UpdateRuleToStr(LFK.UpdateRule) + ')]' + sLineBreak;

    // Dictionary attribute
    if FOptions.GenerateDictionary then
      Result := Result + '    [Dictionary(''' + LCol.Name +
        ''', ''Mensagem de valida' + #231 + #227 + 'o'', ' +
        _GetColumnDefault(LCol.DelphiType, LCol.Required) + ', '''', ' +
        _GetColumnMask(LCol.DelphiType, LCol.Required) + ', ' +
        _GetColumnAlign(LCol.DelphiType) + ')]' + sLineBreak;

    // Property
    LPropName := LCol.Name;
    if FOptions.LowerCaseNames then
      LPropName := LowerCase(LPropName);
    Result := Result + '    property ' + LPropName + ': ' + LType +
      ' read F' + LCol.Name + ' write F' + LCol.Name + ';' + sLineBreak;
  end;
end;

function TJanusCodeGenEngine._BuildRelationProperties(
  const AForeignKeys: TArray<TForeignKeyInfo>): String;
var
  LIndex: Integer;
  LRefTable: String;
  LReadWrite: String;
  LPropName: String;
begin
  Result := '';
  if Length(AForeignKeys) = 0 then
    Exit;
  Result := sLineBreak;
  for LIndex := 0 to Length(AForeignKeys) - 1 do
  begin
    LRefTable := AForeignKeys[LIndex].ReferenceTableName;

    if FOptions.GenerateLazy then
      LReadWrite := ' read get' + LRefTable + '_' + IntToStr(LIndex)
    else
      LReadWrite := ' read F' + LRefTable + '_' + IntToStr(LIndex) +
        ' write F' + LRefTable + '_' + IntToStr(LIndex);

    Result := Result + '    [Association(OneToOne,' +
      QuotedStr(AForeignKeys[LIndex].ColumnName) + ',' +
      QuotedStr(LRefTable) + ',' +
      QuotedStr(AForeignKeys[LIndex].ReferenceColumnName) +
      IfThen(FOptions.GenerateLazy, ', True', '') + ')]' + sLineBreak;

    LPropName := LRefTable;
    if FOptions.LowerCaseNames then
      LPropName := LowerCase(LPropName);

    Result := Result + '    property ' + LPropName + ': ' +
      'T' + LRefTable + LReadWrite + ';' + sLineBreak;
    Result := Result + sLineBreak;
  end;
end;

function TJanusCodeGenEngine._BuildPrimaryKeyAttributes(
  const APrimaryKeys: TArray<TPrimaryKeyInfo>): String;
var
  LIndex: Integer;
begin
  Result := '';
  for LIndex := 0 to Length(APrimaryKeys) - 1 do
    Result := Result + '  [PrimaryKey(' + QuotedStr(APrimaryKeys[LIndex].ColumnName) +
      ', NotInc, NoSort, False, ' + QuotedStr('Chave prim' + #225 + 'ria') + ')]' + sLineBreak;
end;

function TJanusCodeGenEngine._BuildIndexAttributes(
  const AIndexes: TArray<TIndexInfo>): String;
var
  LIndex: Integer;
  LUniqueStr: String;
begin
  Result := '';
  for LIndex := 0 to Length(AIndexes) - 1 do
  begin
    if AIndexes[LIndex].Unique then
      LUniqueStr := 'True'
    else
      LUniqueStr := 'False';
    Result := Result + '  [Indexe(' +
      QuotedStr(AIndexes[LIndex].Name) + ', ' +
      QuotedStr(AIndexes[LIndex].Columns) + ', ' +
      AIndexes[LIndex].SortingOrder + ', ' +
      LUniqueStr + ', ' +
      QuotedStr('') + ')]' + sLineBreak;
  end;
end;

function TJanusCodeGenEngine._BuildCheckAttributes(
  const AChecks: TArray<TCheckInfo>): String;
var
  LIndex: Integer;
begin
  Result := '';
  for LIndex := 0 to Length(AChecks) - 1 do
    Result := Result + '  [Check(' +
      QuotedStr(AChecks[LIndex].Name) + ', ' +
      QuotedStr(AChecks[LIndex].Condition) + ')]' + sLineBreak;
end;

function TJanusCodeGenEngine._BuildConstructorDeclaration(
  const AForeignKeys: TArray<TForeignKeyInfo>;
  const ATableName: String): String;
var
  LIndex: Integer;
  LRefTable: String;
begin
  Result := '';
  if Length(AForeignKeys) = 0 then
    Exit;
  Result := '    constructor Create;' + sLineBreak;
  if FOptions.GenerateLazy then
    for LIndex := 0 to Length(AForeignKeys) - 1 do
    begin
      LRefTable := AForeignKeys[LIndex].ReferenceTableName;
      Result := Result + '    function get' + LRefTable + '_' +
        IntToStr(LIndex) + ' : T' + LRefTable + ';' + sLineBreak;
    end;
end;

function TJanusCodeGenEngine._BuildDestructorDeclaration(
  const AForeignKeys: TArray<TForeignKeyInfo>): String;
begin
  Result := '';
  if Length(AForeignKeys) = 0 then
    Exit;
  Result := '    destructor Destroy; override;' + sLineBreak;
end;

function TJanusCodeGenEngine._BuildConstructorImplementation(
  const ATableName: String;
  const AForeignKeys: TArray<TForeignKeyInfo>): String;
var
  LIndex: Integer;
  LRefTable: String;
begin
  Result := '';
  if Length(AForeignKeys) = 0 then
    Exit;
  Result := sLineBreak +
    'constructor T' + ATableName + '.Create;' + sLineBreak +
    'begin' + sLineBreak;
  if not FOptions.GenerateLazy then
    for LIndex := 0 to Length(AForeignKeys) - 1 do
    begin
      LRefTable := AForeignKeys[LIndex].ReferenceTableName;
      Result := Result + '  F' + LRefTable + '_' + IntToStr(LIndex) +
        ' := T' + LRefTable + '.Create;' + sLineBreak;
    end;
  Result := Result + 'end;' + sLineBreak;
end;

function TJanusCodeGenEngine._BuildDestructorImplementation(
  const ATableName: String;
  const AForeignKeys: TArray<TForeignKeyInfo>): String;
var
  LIndex: Integer;
  LRefTable: String;
  LValueSuffix: String;
begin
  Result := '';
  if Length(AForeignKeys) = 0 then
    Exit;
  Result := sLineBreak +
    'destructor T' + ATableName + '.Destroy;' + sLineBreak +
    'begin' + sLineBreak;
  for LIndex := 0 to Length(AForeignKeys) - 1 do
  begin
    LRefTable := AForeignKeys[LIndex].ReferenceTableName;
    if FOptions.GenerateLazy then
      LValueSuffix := '.Value'
    else
      LValueSuffix := '';
    Result := Result + '  if Assigned(F' + LRefTable + '_' +
      IntToStr(LIndex) + LValueSuffix + ') then' + sLineBreak;
    Result := Result + '    F' + LRefTable + '_' +
      IntToStr(LIndex) + LValueSuffix + '.Free;' + sLineBreak;
    Result := Result + sLineBreak;
  end;
  Result := Result + '  inherited;' + sLineBreak;
  Result := Result + 'end;' + sLineBreak;
end;

function TJanusCodeGenEngine._BuildLazyLoadImplementation(
  const ATableName: String;
  const AForeignKeys: TArray<TForeignKeyInfo>): String;
var
  LIndex: Integer;
  LRefTable: String;
begin
  Result := '';
  if not FOptions.GenerateLazy then
    Exit;
  for LIndex := 0 to Length(AForeignKeys) - 1 do
  begin
    LRefTable := AForeignKeys[LIndex].ReferenceTableName;
    Result := Result + sLineBreak;
    Result := Result + 'function T' + ATableName + '.get' + LRefTable +
      '_' + IntToStr(LIndex) + ' : T' + LRefTable + ';' + sLineBreak;
    Result := Result + 'begin' + sLineBreak;
    Result := Result + '  Result := F' + LRefTable + '_' +
      IntToStr(LIndex) + '.Value;' + sLineBreak;
    Result := Result + 'end;' + sLineBreak;
  end;
end;

function TJanusCodeGenEngine.GenerateUnit(const ATableInfo: TTableInfo): String;
var
  LColumns: TArray<TColumnInfo>;
  LPrimaryKeys: TArray<TPrimaryKeyInfo>;
  LForeignKeys: TArray<TForeignKeyInfo>;
  LIndexes: TArray<TIndexInfo>;
  LChecks: TArray<TCheckInfo>;
  LPlaceholders: TDictionary<String, String>;
  LUnitName: String;
begin
  LColumns := FSchemaReader.GetColumns(ATableInfo.Name);
  LPrimaryKeys := FSchemaReader.GetPrimaryKeys(ATableInfo.Name);
  LForeignKeys := FSchemaReader.GetForeignKeys(ATableInfo.Name);
  LIndexes := FSchemaReader.GetIndexes(ATableInfo.Name);
  LChecks := FSchemaReader.GetChecks(ATableInfo.Name);

  LUnitName := FOptions.ProjectPrefix + LowerCase(ATableInfo.Name);

  LPlaceholders := TDictionary<String, String>.Create;
  try
    LPlaceholders.Add('UnitName', LUnitName);
    LPlaceholders.Add('TableNameQuoted', QuotedStr(ATableInfo.Name));
    LPlaceholders.Add('ClassName', ATableInfo.Name);
    LPlaceholders.Add('UsesRelations', _BuildUsesClause(LForeignKeys));
    LPlaceholders.Add('PrimaryKeyAttributes', _BuildPrimaryKeyAttributes(LPrimaryKeys));
    LPlaceholders.Add('IndexAttributes', _BuildIndexAttributes(LIndexes));
    LPlaceholders.Add('CheckAttributes', _BuildCheckAttributes(LChecks));
    LPlaceholders.Add('PrivateFields', _BuildPrivateFields(LColumns));
    LPlaceholders.Add('RelationFields', _BuildRelationFields(LForeignKeys));
    LPlaceholders.Add('ConstructorDeclaration', _BuildConstructorDeclaration(LForeignKeys, ATableInfo.Name));
    LPlaceholders.Add('DestructorDeclaration', _BuildDestructorDeclaration(LForeignKeys));
    LPlaceholders.Add('Properties', _BuildProperties(ATableInfo.Name, LColumns, LPrimaryKeys, LForeignKeys));
    LPlaceholders.Add('RelationProperties', _BuildRelationProperties(LForeignKeys));
    LPlaceholders.Add('ConstructorImplementation', _BuildConstructorImplementation(ATableInfo.Name, LForeignKeys));
    LPlaceholders.Add('DestructorImplementation', _BuildDestructorImplementation(ATableInfo.Name, LForeignKeys));
    LPlaceholders.Add('LazyLoadImplementation', _BuildLazyLoadImplementation(ATableInfo.Name, LForeignKeys));

    Result := TJanusCodeTemplate.Apply(sUnitTemplate, LPlaceholders);
  finally
    LPlaceholders.Free;
  end;
end;

procedure TJanusCodeGenEngine.GenerateAll(const ATables: TArray<TTableInfo>;
  const AOutputPath: String);
var
  LIndex: Integer;
  LOutput: String;
  LFileName: String;
  LLines: TStringList;
begin
  for LIndex := 0 to Length(ATables) - 1 do
  begin
    LOutput := GenerateUnit(ATables[LIndex]);
    LFileName := AOutputPath + '\' + FOptions.ProjectPrefix +
      ATables[LIndex].Name + '.pas';
    LLines := TStringList.Create;
    try
      LLines.Text := LOutput;
      if not DirectoryExists(AOutputPath) then
        ForceDirectories(AOutputPath);
      LLines.SaveToFile(LFileName);
    finally
      LLines.Free;
    end;
  end;
end;

end.
