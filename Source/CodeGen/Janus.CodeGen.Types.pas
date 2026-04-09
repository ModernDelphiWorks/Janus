unit Janus.CodeGen.Types;

interface

uses
  SysUtils;

type
  TJanusDeleteRule = (drNone, drCascade, drSetNull, drSetDefault);
  TJanusUpdateRule = (urNone, urCascade, urSetNull, urSetDefault);

  TColumnInfo = record
    Name: String;
    DataTypeName: String;
    DelphiType: String;
    Size: Integer;
    Precision: Integer;
    Scale: Integer;
    Nullable: Boolean;
    IsPrimaryKey: Boolean;
    Required: Boolean;
  end;

  TPrimaryKeyInfo = record
    ColumnName: String;
    Description: String;
  end;

  TForeignKeyInfo = record
    ForeignKeyName: String;
    ColumnName: String;
    ReferenceTableName: String;
    ReferenceColumnName: String;
    DeleteRule: TJanusDeleteRule;
    UpdateRule: TJanusUpdateRule;
  end;

  TTableInfo = record
    Name: String;
    Schema: String;
    Catalog: String;
  end;

  TIndexInfo = record
    Name: String;
    Columns: String;
    Unique: Boolean;
    SortingOrder: String;
  end;

  TCheckInfo = record
    Name: String;
    Condition: String;
  end;

function DeleteRuleToStr(ARule: TJanusDeleteRule): String;
function UpdateRuleToStr(ARule: TJanusUpdateRule): String;
function IntToDeleteRule(AValue: Integer): TJanusDeleteRule;
function IntToUpdateRule(AValue: Integer): TJanusUpdateRule;

implementation

function DeleteRuleToStr(ARule: TJanusDeleteRule): String;
begin
  case ARule of
    drNone:       Result := 'None';
    drCascade:    Result := 'Cascade';
    drSetNull:    Result := 'SetNull';
    drSetDefault: Result := 'SetDefault';
  else
    Result := 'None';
  end;
end;

function UpdateRuleToStr(ARule: TJanusUpdateRule): String;
begin
  case ARule of
    urNone:       Result := 'None';
    urCascade:    Result := 'Cascade';
    urSetNull:    Result := 'SetNull';
    urSetDefault: Result := 'SetDefault';
  else
    Result := 'None';
  end;
end;

function IntToDeleteRule(AValue: Integer): TJanusDeleteRule;
begin
  case AValue of
    1: Result := drCascade;
    2: Result := drSetNull;
    3: Result := drSetDefault;
  else
    Result := drNone;
  end;
end;

function IntToUpdateRule(AValue: Integer): TJanusUpdateRule;
begin
  case AValue of
    1: Result := urCascade;
    2: Result := urSetNull;
    3: Result := urSetDefault;
  else
    Result := urNone;
  end;
end;

end.
