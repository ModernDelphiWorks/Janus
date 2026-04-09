unit Janus.DLL.Dynamic.Proxy;

// =============================================================================
// JANUS ORM -- DLL Bridge: Dynamic Record & ObjectSet Proxy (SPRINT-03/04)
//
// TDynamicRecord    — implements IJanusRecord via TDictionary<string,string>.
//                     No RTTI; field values stored as strings and converted
//                     on demand in GetInt/GetFloat/GetBool.
//
// TDynamicObjectSet — implements IJanusObjectSet via raw SQL + FireDAC.
//                     Schema is provided by TEntitySchema; connection is
//                     extracted from IJanusConnection via IJanusConnectionInternal.
//
// SPRINT-04 additions:
//   - _BuildCreateTable generates FOREIGN KEY constraints
//   - _BuildSelect generates JOINs when JoinColumns are defined
//   - Insert validates master existence (cascade insert)
//   - Delete propagates to child entities (cascade delete)
//
// SECURITY NOTE: SQL identifiers (table/column names) come from TEntitySchema,
// which is built by TJanusEntityBuilder and validated before registration.
// Parameters passed as :BindVar via TFDQuery to prevent SQL injection.
// =============================================================================

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  Janus.DLL.Interfaces,
  Janus.DLL.Connection.Facade,
  Janus.DLL.Dynamic.Entity.Registry;

type
  TDynamicRecord = class(TInterfacedObject, IJanusRecord)
  private
    FValues:  TDictionary<string, string>;
    FLastStr: string;
  public
    constructor Create;
    destructor  Destroy; override;
    // Internal helpers (non-stdcall — used within the DLL only)
    function  GetValueRaw(const AField: string): string;
    procedure SetValueRaw(const AField, AValue: string);
    // IJanusRecord
    function  GetStr(AField: PWideChar): PWideChar; stdcall;
    function  GetInt(AField: PWideChar): Integer; stdcall;
    function  GetFloat(AField: PWideChar): Double; stdcall;
    function  GetBool(AField: PWideChar): LongBool; stdcall;
    procedure SetStr(AField, AValue: PWideChar); stdcall;
    procedure SetInt(AField: PWideChar; AValue: Integer); stdcall;
    procedure SetFloat(AField: PWideChar; AValue: Double); stdcall;
    procedure SetBool(AField: PWideChar; AValue: LongBool); stdcall;
  end;

  TDynamicObjectSet = class(TInterfacedObject, IJanusObjectSet)
  private
    FSchema:  TEntitySchema;
    FFDConn:  TFDConnection;
    FConn:    IJanusConnection;   // holds lifetime of TFDConnection
    FRecords: TList<IJanusRecord>;
    FCurrentIndex: Integer;
    // SQL builders
    function _BuildSelect(const AWhere, AOrderBy: string): string;
    function _BuildSelectPaged(const AWhere, AOrderBy: string;
      APageSize, APageNext: Integer): string;
    function _BuildInsert: string;
    function _BuildUpdate: string;
    function _BuildDelete: string;
    function _BuildCreateTable: string;
    // SPRINT-04 — Cascade helpers (ADR-007: SQL manual)
    procedure _CascadeDelete(ARecord: IJanusRecord);
    function  _ValidateMasterExists(ARecord: IJanusRecord): Boolean;
    function  _RuleActionToSQL(ARuleAction: Integer): string;
    // FireDAC helpers
    procedure _PopulateRecords(AQuery: TFDQuery);
    procedure _BindParams(AQuery: TFDQuery; ARecord: IJanusRecord;
      ASkipPKInteger: Boolean);
    procedure _EnsureTableExists;
  public
    constructor Create(ASchema: TEntitySchema; AConn: IJanusConnection);
    destructor  Destroy; override;
    // IJanusObjectSet
    function  Open: LongBool; stdcall;
    function  OpenWhere(AWhere, AOrderBy: PWideChar): LongBool; stdcall;
    function  FindByID(AID: Integer): IJanusRecord; stdcall;
    function  RecordCount: Integer; stdcall;
    function  GetRecord(AIndex: Integer): IJanusRecord; stdcall;
    function  NewRecord: IJanusRecord; stdcall;
    procedure Insert(ARecord: IJanusRecord); stdcall;
    procedure Update(ARecord: IJanusRecord); stdcall;
    procedure Delete(ARecord: IJanusRecord); stdcall;
    // SPRINT-08 — Pagination + Navigation (ADR-009)
    function  NextPacket(APageSize, APageNext: Integer): LongBool; stdcall;
    function  First: LongBool; stdcall;
    function  Next: LongBool; stdcall;
    function  Prior: LongBool; stdcall;
    function  Eof: LongBool; stdcall;
    function  CurrentRecord: IJanusRecord; stdcall;
  end;

implementation

{ TDynamicRecord }

constructor TDynamicRecord.Create;
begin
  inherited Create;
  FValues := TDictionary<string, string>.Create;
end;

destructor TDynamicRecord.Destroy;
begin
  FValues.Free;
  inherited;
end;

function TDynamicRecord.GetValueRaw(const AField: string): string;
begin
  if not FValues.TryGetValue(LowerCase(AField), Result) then
    Result := '';
end;

procedure TDynamicRecord.SetValueRaw(const AField, AValue: string);
begin
  FValues.AddOrSetValue(LowerCase(AField), AValue);
end;

function TDynamicRecord.GetStr(AField: PWideChar): PWideChar;
begin
  FLastStr := GetValueRaw(string(AField));
  Result   := PWideChar(FLastStr);
end;

function TDynamicRecord.GetInt(AField: PWideChar): Integer;
begin
  Result := StrToIntDef(GetValueRaw(string(AField)), 0);
end;

function TDynamicRecord.GetFloat(AField: PWideChar): Double;
var
  LFormat: TFormatSettings;
begin
  LFormat := TFormatSettings.Create('en-US');
  Result  := StrToFloatDef(GetValueRaw(string(AField)), 0.0, LFormat);
end;

function TDynamicRecord.GetBool(AField: PWideChar): LongBool;
begin
  Result := GetValueRaw(string(AField)) = '1';
end;

procedure TDynamicRecord.SetStr(AField, AValue: PWideChar);
begin
  SetValueRaw(string(AField), string(AValue));
end;

procedure TDynamicRecord.SetInt(AField: PWideChar; AValue: Integer);
begin
  SetValueRaw(string(AField), IntToStr(AValue));
end;

procedure TDynamicRecord.SetFloat(AField: PWideChar; AValue: Double);
var
  LFormat: TFormatSettings;
begin
  LFormat := TFormatSettings.Create('en-US');
  SetValueRaw(string(AField), FloatToStr(AValue, LFormat));
end;

procedure TDynamicRecord.SetBool(AField: PWideChar; AValue: LongBool);
begin
  if AValue then
    SetValueRaw(string(AField), '1')
  else
    SetValueRaw(string(AField), '0');
end;

{ TDynamicObjectSet }

constructor TDynamicObjectSet.Create(ASchema: TEntitySchema;
  AConn: IJanusConnection);
var
  LInternal: IJanusConnectionInternal;
begin
  inherited Create;
  FSchema  := ASchema;
  FConn    := AConn;
  FFDConn  := nil;
  if Assigned(AConn) and Supports(AConn, IJanusConnectionInternal, LInternal) then
    FFDConn := LInternal.FDConnection;
  FRecords := TList<IJanusRecord>.Create;
  FCurrentIndex := -1;
end;

destructor TDynamicObjectSet.Destroy;
begin
  FRecords.Free;
  FConn := nil;
  inherited;
end;

function TDynamicObjectSet._BuildSelect(const AWhere, AOrderBy: string): string;
var
  LJC:         TJoinColumnDef;
  LRefSchema:  TEntitySchema;
  LRefCol:     TColumnDef;
  LJoinClause: string;
  LExtraCols:  string;
  LAliasIdx:   Integer;
  LAlias:      string;
  LJoinType:   string;
begin
  // SPRINT-04: When JoinColumns are defined, generate SELECT with JOINs
  if FSchema.JoinColumns.Count > 0 then
  begin
    LJoinClause := '';
    LExtraCols  := '';
    LAliasIdx   := 1;
    for LJC in FSchema.JoinColumns do
    begin
      // Try finding referenced schema by table name, then by entity name
      LRefSchema := TDynamicEntityRegistry.Instance.FindSchemaByTableName(LJC.RefTableName);
      if not Assigned(LRefSchema) then
        LRefSchema := TDynamicEntityRegistry.Instance.FindSchema(LJC.RefTableName);
      if not Assigned(LRefSchema) then
        Continue;

      LAlias := 't' + IntToStr(LAliasIdx);

      case LJC.JoinType of
        0: LJoinType := 'INNER JOIN';
        1: LJoinType := 'LEFT JOIN';
        2: LJoinType := 'RIGHT JOIN';
        3: LJoinType := 'FULL JOIN';
      else
        LJoinType := 'LEFT JOIN';
      end;

      LJoinClause := LJoinClause + ' ' + LJoinType + ' ' +
        LRefSchema.TableName + ' ' + LAlias + ' ON t0.' +
        LJC.ColumnName + ' = ' + LAlias + '.' + LJC.RefColumnName;

      for LRefCol in LRefSchema.Columns do
        LExtraCols := LExtraCols + ', ' + LAlias + '.' + LRefCol.Name +
          ' AS ' + LRefSchema.TableName + '_' + LRefCol.Name;

      Inc(LAliasIdx);
    end;

    Result := 'SELECT t0.*' + LExtraCols + ' FROM ' +
      FSchema.TableName + ' t0' + LJoinClause;
  end
  else
    Result := 'SELECT * FROM ' + FSchema.TableName;

  if AWhere <> '' then
    Result := Result + ' WHERE ' + AWhere;
  if AOrderBy <> '' then
    Result := Result + ' ORDER BY ' + AOrderBy;
end;

function TDynamicObjectSet._BuildSelectPaged(const AWhere, AOrderBy: string;
  APageSize, APageNext: Integer): string;
var
  LOffset: Integer;
begin
  Result := _BuildSelect(AWhere, AOrderBy);
  LOffset := (APageNext - 1) * APageSize;
  Result := Result + ' LIMIT ' + IntToStr(APageSize) +
            ' OFFSET ' + IntToStr(LOffset);
end;

function TDynamicObjectSet._BuildInsert: string;
var
  LCol:    TColumnDef;
  LCols:   string;
  LParams: string;
  LFirst:  Boolean;
  LSkipPK: Boolean;
begin
  LCols   := '';
  LParams := '';
  LFirst  := True;
  for LCol in FSchema.Columns do
  begin
    LSkipPK := SameText(LCol.Name, FSchema.PrimaryKey) and
               SameText(LCol.ColType, 'integer');
    if LSkipPK then
      Continue;
    if not LFirst then
    begin
      LCols   := LCols   + ', ';
      LParams := LParams + ', ';
    end;
    LCols   := LCols   + LCol.Name;
    LParams := LParams + ':' + LCol.Name;
    LFirst  := False;
  end;
  Result := 'INSERT INTO ' + FSchema.TableName +
            ' (' + LCols + ') VALUES (' + LParams + ')';
end;

function TDynamicObjectSet._BuildUpdate: string;
var
  LCol:   TColumnDef;
  LSet:   string;
  LFirst: Boolean;
begin
  LSet   := '';
  LFirst := True;
  for LCol in FSchema.Columns do
  begin
    if SameText(LCol.Name, FSchema.PrimaryKey) then
      Continue;
    if not LFirst then
      LSet := LSet + ', ';
    LSet  := LSet + LCol.Name + ' = :' + LCol.Name;
    LFirst := False;
  end;
  Result := 'UPDATE ' + FSchema.TableName +
            ' SET ' + LSet +
            ' WHERE ' + FSchema.PrimaryKey + ' = :' + FSchema.PrimaryKey;
end;

function TDynamicObjectSet._BuildDelete: string;
begin
  Result := 'DELETE FROM ' + FSchema.TableName +
            ' WHERE ' + FSchema.PrimaryKey + ' = :' + FSchema.PrimaryKey;
end;

function TDynamicObjectSet._BuildCreateTable: string;
var
  LCol:   TColumnDef;
  LFK:    TForeignKeyDef;
  LCols:  string;
  LFirst: Boolean;
  LType:  string;
begin
  LCols  := '';
  LFirst := True;
  for LCol in FSchema.Columns do
  begin
    if not LFirst then
      LCols := LCols + ', ';
    if SameText(LCol.ColType, 'integer') then
      LType := 'INTEGER'
    else if SameText(LCol.ColType, 'float') then
      LType := 'REAL'
    else if SameText(LCol.ColType, 'boolean') then
      LType := 'INTEGER'
    else if SameText(LCol.ColType, 'date') or SameText(LCol.ColType, 'datetime') then
      LType := 'TEXT'
    else if LCol.Size > 0 then
      LType := 'VARCHAR(' + IntToStr(LCol.Size) + ')'
    else
      LType := 'TEXT';
    LCols  := LCols + LCol.Name + ' ' + LType;
    LFirst := False;
  end;
  if FSchema.PrimaryKey <> '' then
    LCols := LCols + ', PRIMARY KEY (' + FSchema.PrimaryKey + ')';

  // SPRINT-04 — FOREIGN KEY constraints
  for LFK in FSchema.ForeignKeys do
  begin
    LCols := LCols + ', CONSTRAINT ' + LFK.Name +
      ' FOREIGN KEY (' + LFK.FromColumn + ') REFERENCES ' +
      LFK.RefTable + '(' + LFK.ToColumn + ')' +
      ' ON DELETE ' + _RuleActionToSQL(LFK.RuleDelete) +
      ' ON UPDATE ' + _RuleActionToSQL(LFK.RuleUpdate);
  end;

  Result := 'CREATE TABLE IF NOT EXISTS ' + FSchema.TableName +
            ' (' + LCols + ')';
end;

procedure TDynamicObjectSet._EnsureTableExists;
var
  LQuery: TFDQuery;
begin
  if not Assigned(FFDConn) then
    Exit;
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FFDConn;
    // SPRINT-04: Enable FK enforcement for SQLite
    if Pos('SQLITE', UpperCase(FFDConn.DriverName)) > 0 then
    begin
      LQuery.SQL.Text := 'PRAGMA foreign_keys = ON';
      try
        LQuery.ExecSQL;
      except
        // Silently ignore if PRAGMA not supported
      end;
    end;
    LQuery.SQL.Text := _BuildCreateTable;
    try
      LQuery.ExecSQL;
    except
      // Silently ignore: table may already exist or engine may not support IF NOT EXISTS
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TDynamicObjectSet._PopulateRecords(AQuery: TFDQuery);
var
  LRec:      TDynamicRecord;
  LCol:      TColumnDef;
  LFieldIdx: Integer;
begin
  FRecords.Clear;
  AQuery.First;
  while not AQuery.Eof do
  begin
    LRec := TDynamicRecord.Create;
    // Populate schema columns
    for LCol in FSchema.Columns do
    begin
      if AQuery.FieldByName(LCol.Name) <> nil then
        LRec.SetValueRaw(LCol.Name,
          AQuery.FieldByName(LCol.Name).AsString);
    end;
    // SPRINT-04: Populate extra fields from JOINs (aliased as table_column)
    for LFieldIdx := 0 to AQuery.FieldCount - 1 do
    begin
      if Pos('_', AQuery.Fields[LFieldIdx].FieldName) > 0 then
        if not FSchema.HasColumn(AQuery.Fields[LFieldIdx].FieldName) then
          LRec.SetValueRaw(AQuery.Fields[LFieldIdx].FieldName,
            AQuery.Fields[LFieldIdx].AsString);
    end;
    FRecords.Add(LRec);
    AQuery.Next;
  end;
end;

procedure TDynamicObjectSet._BindParams(AQuery: TFDQuery; ARecord: IJanusRecord;
  ASkipPKInteger: Boolean);
var
  LCol:    TColumnDef;
  LRaw:    TDynamicRecord;
  LValue:  string;
begin
  LRaw := ARecord as TDynamicRecord;
  for LCol in FSchema.Columns do
  begin
    if ASkipPKInteger and SameText(LCol.Name, FSchema.PrimaryKey) and
       SameText(LCol.ColType, 'integer') then
      Continue;
    LValue := LRaw.GetValueRaw(LCol.Name);
    AQuery.ParamByName(LCol.Name).AsString := LValue;
  end;
end;

function TDynamicObjectSet.Open: LongBool;
var
  LQuery: TFDQuery;
begin
  Result := False;
  if not Assigned(FFDConn) then
    Exit;
  _EnsureTableExists;
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FFDConn;
    LQuery.SQL.Text   := _BuildSelect('', '');
    LQuery.Open;
    _PopulateRecords(LQuery);
    FCurrentIndex := -1;
    Result := True;
  finally
    LQuery.Free;
  end;
end;

function TDynamicObjectSet.OpenWhere(AWhere, AOrderBy: PWideChar): LongBool;
var
  LQuery: TFDQuery;
begin
  Result := False;
  if not Assigned(FFDConn) then
    Exit;
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FFDConn;
    LQuery.SQL.Text   := _BuildSelect(string(AWhere), string(AOrderBy));
    LQuery.Open;
    _PopulateRecords(LQuery);
    FCurrentIndex := -1;
    Result := True;
  finally
    LQuery.Free;
  end;
end;

function TDynamicObjectSet.FindByID(AID: Integer): IJanusRecord;
var
  LQuery: TFDQuery;
  LRec:   TDynamicRecord;
  LCol:   TColumnDef;
begin
  Result := nil;
  if not Assigned(FFDConn) then
    Exit;
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FFDConn;
    LQuery.SQL.Text   := 'SELECT * FROM ' + FSchema.TableName +
                         ' WHERE ' + FSchema.PrimaryKey + ' = :AID';
    LQuery.ParamByName('AID').AsInteger := AID;
    LQuery.Open;
    if not LQuery.IsEmpty then
    begin
      LRec := TDynamicRecord.Create;
      for LCol in FSchema.Columns do
      begin
        if LQuery.FieldByName(LCol.Name) <> nil then
          LRec.SetValueRaw(LCol.Name,
            LQuery.FieldByName(LCol.Name).AsString);
      end;
      Result := LRec;
    end;
  finally
    LQuery.Free;
  end;
end;

function TDynamicObjectSet.RecordCount: Integer;
begin
  Result := FRecords.Count;
end;

function TDynamicObjectSet.GetRecord(AIndex: Integer): IJanusRecord;
begin
  Result := FRecords[AIndex];
end;

function TDynamicObjectSet.NewRecord: IJanusRecord;
begin
  Result := TDynamicRecord.Create;
end;

function TDynamicObjectSet._RuleActionToSQL(ARuleAction: Integer): string;
begin
  case ARuleAction of
    1: Result := 'CASCADE';
    2: Result := 'SET NULL';
    3: Result := 'SET DEFAULT';
  else
    Result := 'NO ACTION';
  end;
end;

procedure TDynamicObjectSet._CascadeDelete(ARecord: IJanusRecord);
var
  LChildSchemas: TList<TEntitySchema>;
  LChildSchema:  TEntitySchema;
  LAssociation:  TAssociationDef;
  LQuery:        TFDQuery;
  LRaw:          TDynamicRecord;
  LPKValue:      string;
begin
  LRaw    := ARecord as TDynamicRecord;
  LPKValue := LRaw.GetValueRaw(FSchema.PrimaryKey);
  LChildSchemas := TDynamicEntityRegistry.Instance.FindChildSchemas(FSchema.EntityName);
  try
    for LChildSchema in LChildSchemas do
    begin
      for LAssociation in LChildSchema.Associations do
      begin
        if SameText(LAssociation.RefEntityName, FSchema.EntityName) and
           LAssociation.CascadeDelete then
        begin
          LQuery := TFDQuery.Create(nil);
          try
            LQuery.Connection := FFDConn;
            LQuery.SQL.Text := 'DELETE FROM ' + LChildSchema.TableName +
              ' WHERE ' + LAssociation.ColumnName + ' = :PKValue';
            LQuery.ParamByName('PKValue').AsString := LPKValue;
            LQuery.ExecSQL;
          finally
            LQuery.Free;
          end;
          Break;
        end;
      end;
    end;
  finally
    LChildSchemas.Free;
  end;
end;

function TDynamicObjectSet._ValidateMasterExists(
  ARecord: IJanusRecord): Boolean;
var
  LAssociation:  TAssociationDef;
  LMasterSchema: TEntitySchema;
  LQuery:        TFDQuery;
  LRaw:          TDynamicRecord;
  LFKValue:      string;
begin
  Result := True;
  LRaw   := ARecord as TDynamicRecord;
  for LAssociation in FSchema.Associations do
  begin
    if not LAssociation.CascadeInsert then
      Continue;
    LMasterSchema := TDynamicEntityRegistry.Instance.FindSchema(LAssociation.RefEntityName);
    if not Assigned(LMasterSchema) then
      Continue;
    LFKValue := LRaw.GetValueRaw(LAssociation.ColumnName);
    if LFKValue = '' then
      Continue;
    LQuery := TFDQuery.Create(nil);
    try
      LQuery.Connection := FFDConn;
      LQuery.SQL.Text := 'SELECT COUNT(*) AS cnt FROM ' +
        LMasterSchema.TableName + ' WHERE ' +
        LAssociation.RefColumnName + ' = :FKValue';
      LQuery.ParamByName('FKValue').AsString := LFKValue;
      LQuery.Open;
      if LQuery.FieldByName('cnt').AsInteger = 0 then
      begin
        Result := False;
        Exit;
      end;
    finally
      LQuery.Free;
    end;
  end;
end;

procedure TDynamicObjectSet.Insert(ARecord: IJanusRecord);
var
  LQuery: TFDQuery;
begin
  if not Assigned(FFDConn) or not Assigned(ARecord) then
    Exit;
  // SPRINT-04: Validate master existence for cascade insert (ADR-007)
  if FSchema.Associations.Count > 0 then
    if not _ValidateMasterExists(ARecord) then
      Exit;
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FFDConn;
    LQuery.SQL.Text   := _BuildInsert;
    _BindParams(LQuery, ARecord, True);
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

procedure TDynamicObjectSet.Update(ARecord: IJanusRecord);
var
  LQuery: TFDQuery;
begin
  if not Assigned(FFDConn) or not Assigned(ARecord) then
    Exit;
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FFDConn;
    LQuery.SQL.Text   := _BuildUpdate;
    _BindParams(LQuery, ARecord, False);
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

procedure TDynamicObjectSet.Delete(ARecord: IJanusRecord);
var
  LQuery:  TFDQuery;
  LRaw:    TDynamicRecord;
begin
  if not Assigned(FFDConn) or not Assigned(ARecord) then
    Exit;
  // SPRINT-04: Cascade delete to child entities first (ADR-007)
  if FSchema.PrimaryKey <> '' then
    _CascadeDelete(ARecord);
  LRaw   := ARecord as TDynamicRecord;
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FFDConn;
    LQuery.SQL.Text   := _BuildDelete;
    LQuery.ParamByName(FSchema.PrimaryKey).AsString :=
      LRaw.GetValueRaw(FSchema.PrimaryKey);
    LQuery.ExecSQL;
  finally
    LQuery.Free;
  end;
end;

{ SPRINT-08 — Pagination + Navigation }

function TDynamicObjectSet.NextPacket(APageSize, APageNext: Integer): LongBool;
var
  LQuery: TFDQuery;
begin
  Result := False;
  if not Assigned(FFDConn) then
    Exit;
  _EnsureTableExists;
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FFDConn;
    LQuery.SQL.Text   := _BuildSelectPaged('', '', APageSize, APageNext);
    LQuery.Open;
    _PopulateRecords(LQuery);
    FCurrentIndex := -1;
    Result := True;
  finally
    LQuery.Free;
  end;
end;

function TDynamicObjectSet.First: LongBool;
begin
  if FRecords.Count > 0 then
  begin
    FCurrentIndex := 0;
    Result := True;
  end
  else
  begin
    FCurrentIndex := -1;
    Result := False;
  end;
end;

function TDynamicObjectSet.Next: LongBool;
begin
  Inc(FCurrentIndex);
  Result := (FCurrentIndex >= 0) and (FCurrentIndex < FRecords.Count);
end;

function TDynamicObjectSet.Prior: LongBool;
begin
  Dec(FCurrentIndex);
  Result := (FCurrentIndex >= 0) and (FCurrentIndex < FRecords.Count);
end;

function TDynamicObjectSet.Eof: LongBool;
begin
  Result := (FRecords.Count = 0) or (FCurrentIndex >= FRecords.Count);
end;

function TDynamicObjectSet.CurrentRecord: IJanusRecord;
begin
  Result := nil;
  if (FCurrentIndex >= 0) and (FCurrentIndex < FRecords.Count) then
    Result := FRecords[FCurrentIndex];
end;

end.
