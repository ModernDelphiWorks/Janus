unit Janus.DLL.Dynamic.Entity.Registry;

// =============================================================================
// JANUS ORM -- DLL Bridge: Dynamic Entity Registry (SPRINT-03 / SPRINT-04)
//
// Provides schema storage for entities registered programmatically via
// IJanusEntityBuilder (Strategy 2). No RTTI required.
//
// TEntitySchema     — describes a single entity (name, table, columns, PK,
//                     foreign keys, join columns, associations).
// TDynamicEntityRegistry — singleton registry; survives for the DLL lifetime.
// =============================================================================

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TColumnDef = record
    Name:    string;
    ColType: string;  // 'string','integer','float','boolean','date','datetime'
    Size:    Integer;
  end;

  // SPRINT-04 — Foreign key definition (single-column)
  TForeignKeyDef = record
    Name:       string;
    RefTable:   string;
    FromColumn: string;
    ToColumn:   string;
    RuleDelete: Integer;  // 0=NoAction, 1=Cascade, 2=SetNull, 3=SetDefault
    RuleUpdate: Integer;  // 0=NoAction, 1=Cascade, 2=SetNull, 3=SetDefault
  end;

  // SPRINT-04 — Join column definition
  TJoinColumnDef = record
    ColumnName:    string;
    RefTableName:  string;
    RefColumnName: string;
    JoinType:      Integer;  // 0=InnerJoin, 1=LeftJoin, 2=RightJoin, 3=FullJoin
  end;

  // SPRINT-04 — Association definition (master/detail relationship)
  TAssociationDef = record
    Multiplicity:  Integer;  // 0=OneToOne, 1=OneToMany, 2=ManyToOne, 3=ManyToMany
    ColumnName:    string;
    RefColumnName: string;
    RefEntityName: string;
    CascadeInsert: Boolean;
    CascadeDelete: Boolean;
  end;

  TEntitySchema = class
  private
    FEntityName:   string;
    FTableName:    string;
    FPrimaryKey:   string;
    FColumns:      TList<TColumnDef>;
    FForeignKeys:  TList<TForeignKeyDef>;
    FJoinColumns:  TList<TJoinColumnDef>;
    FAssociations: TList<TAssociationDef>;
  public
    constructor Create;
    destructor  Destroy; override;
    property EntityName:   string                  read FEntityName   write FEntityName;
    property TableName:    string                  read FTableName    write FTableName;
    property PrimaryKey:   string                  read FPrimaryKey   write FPrimaryKey;
    property Columns:      TList<TColumnDef>       read FColumns;
    property ForeignKeys:  TList<TForeignKeyDef>   read FForeignKeys;
    property JoinColumns:  TList<TJoinColumnDef>   read FJoinColumns;
    property Associations: TList<TAssociationDef>  read FAssociations;
    function HasColumn(const AName: string): Boolean;
  end;

  TDynamicEntityRegistry = class
  private
    class var FInstance: TDynamicEntityRegistry;
    FSchemas: TObjectDictionary<string, TEntitySchema>;
    procedure _Clear;
  public
    constructor Create;
    destructor  Destroy; override;
    class function  Instance: TDynamicEntityRegistry;
    class procedure FreeInstance; reintroduce;
    procedure Register(const ASchema: TEntitySchema);
    function  FindSchema(const AEntityName: string): TEntitySchema;
    function  FindSchemaByTableName(const ATableName: string): TEntitySchema;
    function  HasSchema(const AEntityName: string): Boolean;
    function  FindChildSchemas(const AParentEntity: string): TList<TEntitySchema>;
  end;

implementation

{ TEntitySchema }

constructor TEntitySchema.Create;
begin
  inherited Create;
  FColumns      := TList<TColumnDef>.Create;
  FForeignKeys  := TList<TForeignKeyDef>.Create;
  FJoinColumns  := TList<TJoinColumnDef>.Create;
  FAssociations := TList<TAssociationDef>.Create;
end;

destructor TEntitySchema.Destroy;
begin
  FAssociations.Free;
  FJoinColumns.Free;
  FForeignKeys.Free;
  FColumns.Free;
  inherited;
end;

function TEntitySchema.HasColumn(const AName: string): Boolean;
var
  LDef: TColumnDef;
begin
  Result := False;
  for LDef in FColumns do
    if SameText(LDef.Name, AName) then
    begin
      Result := True;
      Break;
    end;
end;

{ TDynamicEntityRegistry }

constructor TDynamicEntityRegistry.Create;
begin
  inherited Create;
  FSchemas := TObjectDictionary<string, TEntitySchema>.Create([doOwnsValues]);
end;

destructor TDynamicEntityRegistry.Destroy;
begin
  FSchemas.Free;
  inherited;
end;

class function TDynamicEntityRegistry.Instance: TDynamicEntityRegistry;
begin
  if not Assigned(FInstance) then
    FInstance := TDynamicEntityRegistry.Create;
  Result := FInstance;
end;

class procedure TDynamicEntityRegistry.FreeInstance;
begin
  FreeAndNil(FInstance);
end;

procedure TDynamicEntityRegistry._Clear;
begin
  FSchemas.Clear;
end;

procedure TDynamicEntityRegistry.Register(const ASchema: TEntitySchema);
begin
  // If a schema with the same name already exists it is replaced.
  // TObjectDictionary with doOwnsValues frees the old value automatically.
  FSchemas.AddOrSetValue(ASchema.EntityName, ASchema);
end;

function TDynamicEntityRegistry.FindSchema(const AEntityName: string): TEntitySchema;
begin
  if not FSchemas.TryGetValue(AEntityName, Result) then
    Result := nil;
end;

function TDynamicEntityRegistry.FindSchemaByTableName(
  const ATableName: string): TEntitySchema;
var
  LPair: TPair<string, TEntitySchema>;
begin
  Result := nil;
  for LPair in FSchemas do
    if SameText(LPair.Value.TableName, ATableName) then
    begin
      Result := LPair.Value;
      Break;
    end;
end;

function TDynamicEntityRegistry.HasSchema(const AEntityName: string): Boolean;
begin
  Result := FSchemas.ContainsKey(AEntityName);
end;

function TDynamicEntityRegistry.FindChildSchemas(
  const AParentEntity: string): TList<TEntitySchema>;
var
  LPair:       TPair<string, TEntitySchema>;
  LAssociation: TAssociationDef;
begin
  Result := TList<TEntitySchema>.Create;
  for LPair in FSchemas do
  begin
    for LAssociation in LPair.Value.Associations do
    begin
      if SameText(LAssociation.RefEntityName, AParentEntity) then
      begin
        Result.Add(LPair.Value);
        Break;
      end;
    end;
  end;
end;

initialization

finalization
  TDynamicEntityRegistry.FreeInstance;

end.
