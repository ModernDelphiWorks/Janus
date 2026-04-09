unit Janus.DLL.Entity.Builder;

// =============================================================================
// JANUS ORM -- DLL Bridge: Entity Builder (SPRINT-03)
//
// TJanusEntityBuilder — implements IJanusEntityBuilder with fluent interface.
// Collects entity metadata and registers the resulting TEntitySchema in
// TDynamicEntityRegistry on Build.
//
// Build rules:
//   1. EntityName must not be empty.
//   2. TableName must not be empty.
//   3. At least one column must be added via AddColumn.
//   4. If PrimaryKey is set, the named column must exist in the schema.
//   5. On success, ownership of TEntitySchema transfers to TDynamicEntityRegistry.
// =============================================================================

interface

uses
  Janus.DLL.Interfaces,
  Janus.DLL.Dynamic.Entity.Registry;

type
  TJanusEntityBuilder = class(TInterfacedObject, IJanusEntityBuilder)
  private
    FSchema:      TEntitySchema;
    FBuilt:       Boolean;
    FLastFKIndex: Integer;
  public
    constructor Create;
    destructor  Destroy; override;
    function EntityName(AName: PWideChar): IJanusEntityBuilder; stdcall;
    function TableName(AName: PWideChar): IJanusEntityBuilder; stdcall;
    function AddColumn(AName, AType: PWideChar; ASize: Integer): IJanusEntityBuilder; stdcall;
    function PrimaryKey(AColumn: PWideChar): IJanusEntityBuilder; stdcall;
    function Build: LongBool; stdcall;
    // SPRINT-04 — Relationship methods
    function AddForeignKey(AName, ARefTable, AFromColumn, AToColumn: PWideChar): IJanusEntityBuilder; stdcall;
    function ForeignKeyRule(AOnDelete, AOnUpdate: Integer): IJanusEntityBuilder; stdcall;
    function AddJoinColumn(AColumn, ARefTable, ARefColumn: PWideChar; AJoinType: Integer): IJanusEntityBuilder; stdcall;
    function AddAssociation(AMultiplicity: Integer; AColumn, ARefColumn, ARefEntity: PWideChar): IJanusEntityBuilder; stdcall;
  end;

implementation

uses
  System.SysUtils;

{ TJanusEntityBuilder }

constructor TJanusEntityBuilder.Create;
begin
  inherited Create;
  FSchema      := TEntitySchema.Create;
  FBuilt       := False;
  FLastFKIndex := -1;
end;

destructor TJanusEntityBuilder.Destroy;
begin
  // Only free the schema if Build was not called (or failed).
  // On success, TDynamicEntityRegistry owns it.
  if not FBuilt then
    FreeAndNil(FSchema);
  inherited;
end;

function TJanusEntityBuilder.EntityName(AName: PWideChar): IJanusEntityBuilder;
begin
  FSchema.EntityName := string(AName);
  Result := Self;
end;

function TJanusEntityBuilder.TableName(AName: PWideChar): IJanusEntityBuilder;
begin
  FSchema.TableName := string(AName);
  Result := Self;
end;

function TJanusEntityBuilder.AddColumn(AName, AType: PWideChar;
  ASize: Integer): IJanusEntityBuilder;
var
  LDef: TColumnDef;
begin
  LDef.Name    := string(AName);
  LDef.ColType := LowerCase(string(AType));
  LDef.Size    := ASize;
  FSchema.Columns.Add(LDef);
  Result := Self;
end;

function TJanusEntityBuilder.PrimaryKey(AColumn: PWideChar): IJanusEntityBuilder;
begin
  FSchema.PrimaryKey := string(AColumn);
  Result := Self;
end;

function TJanusEntityBuilder.Build: LongBool;
var
  LFKDef: TForeignKeyDef;
  LJCDef: TJoinColumnDef;
begin
  Result := False;
  if FSchema.EntityName = '' then
    Exit;
  if FSchema.TableName = '' then
    Exit;
  if FSchema.Columns.Count = 0 then
    Exit;
  if (FSchema.PrimaryKey <> '') and
     not FSchema.HasColumn(FSchema.PrimaryKey) then
    Exit;

  // SPRINT-04 — Validate FK columns exist in schema
  for LFKDef in FSchema.ForeignKeys do
    if not FSchema.HasColumn(LFKDef.FromColumn) then
      Exit;

  // SPRINT-04 — Validate JoinColumn columns exist in schema
  for LJCDef in FSchema.JoinColumns do
    if not FSchema.HasColumn(LJCDef.ColumnName) then
      Exit;

  TDynamicEntityRegistry.Instance.Register(FSchema);
  FBuilt := True;
  Result := True;
end;

function TJanusEntityBuilder.AddForeignKey(AName, ARefTable, AFromColumn,
  AToColumn: PWideChar): IJanusEntityBuilder;
var
  LDef: TForeignKeyDef;
begin
  LDef.Name       := string(AName);
  LDef.RefTable   := string(ARefTable);
  LDef.FromColumn := string(AFromColumn);
  LDef.ToColumn   := string(AToColumn);
  LDef.RuleDelete := 0;  // NoAction
  LDef.RuleUpdate := 0;  // NoAction
  FSchema.ForeignKeys.Add(LDef);
  FLastFKIndex := FSchema.ForeignKeys.Count - 1;
  Result := Self;
end;

function TJanusEntityBuilder.ForeignKeyRule(AOnDelete,
  AOnUpdate: Integer): IJanusEntityBuilder;
var
  LDef: TForeignKeyDef;
begin
  if FLastFKIndex >= 0 then
  begin
    LDef := FSchema.ForeignKeys[FLastFKIndex];
    LDef.RuleDelete := AOnDelete;
    LDef.RuleUpdate := AOnUpdate;
    FSchema.ForeignKeys[FLastFKIndex] := LDef;
  end;
  Result := Self;
end;

function TJanusEntityBuilder.AddJoinColumn(AColumn, ARefTable,
  ARefColumn: PWideChar; AJoinType: Integer): IJanusEntityBuilder;
var
  LDef: TJoinColumnDef;
begin
  LDef.ColumnName    := string(AColumn);
  LDef.RefTableName  := string(ARefTable);
  LDef.RefColumnName := string(ARefColumn);
  LDef.JoinType      := AJoinType;
  FSchema.JoinColumns.Add(LDef);
  Result := Self;
end;

function TJanusEntityBuilder.AddAssociation(AMultiplicity: Integer;
  AColumn, ARefColumn, ARefEntity: PWideChar): IJanusEntityBuilder;
var
  LDef: TAssociationDef;
begin
  LDef.Multiplicity  := AMultiplicity;
  LDef.ColumnName    := string(AColumn);
  LDef.RefColumnName := string(ARefColumn);
  LDef.RefEntityName := string(ARefEntity);
  LDef.CascadeInsert := True;
  LDef.CascadeDelete := True;
  FSchema.Associations.Add(LDef);
  Result := Self;
end;

end.
