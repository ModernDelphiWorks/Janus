unit Janus.DLL.JanusRecord.Facade;

// NOTE: IJanusRecord is declared in Janus.DLL.Interfaces.pas (the shared interfaces file).
// This unit implements TJanusRecord using only the RTTI available inside the DLL.
// It must NOT be included by consumer projects — DLL-internal only.

interface

uses
  System.SysUtils,
  System.Rtti,
  Generics.Collections,
  Janus.DLL.Interfaces;

type
  /// <summary>
  /// Implements IJanusRecord. Accesses entity fields by name via RTTI.
  /// FStringCache keeps WideString buffers alive for the lifetime of the
  /// interface so that PWideChar pointers returned by GetStr remain valid.
  /// </summary>
  TJanusRecord = class(TInterfacedObject, IJanusRecord)
  private
    FEntity: TObject;
    FOwnsEntity: Boolean;
    FStringCache: TDictionary<string, WideString>;
    FRttiContext: TRttiContext;
    function _PropertyByName(const AName: string): TRttiProperty;
  public
    constructor Create(const AEntity: TObject;
      const AOwnsEntity: Boolean = False);
    destructor Destroy; override;
    // IJanusRecord
    function GetStr(AField: PWideChar): PWideChar; stdcall;
    function GetInt(AField: PWideChar): Integer; stdcall;
    function GetFloat(AField: PWideChar): Double; stdcall;
    function GetBool(AField: PWideChar): LongBool; stdcall;
    procedure SetStr(AField, AValue: PWideChar); stdcall;
    procedure SetInt(AField: PWideChar; AValue: Integer); stdcall;
    procedure SetFloat(AField: PWideChar; AValue: Double); stdcall;
    procedure SetBool(AField: PWideChar; AValue: LongBool); stdcall;
    // Internal DLL helper
    function GetEntity: TObject;
  end;

implementation

{ TJanusRecord }

constructor TJanusRecord.Create(const AEntity: TObject;
  const AOwnsEntity: Boolean);
begin
  inherited Create;
  FEntity := AEntity;
  FOwnsEntity := AOwnsEntity;
  FStringCache := TDictionary<string, WideString>.Create;
  FRttiContext := TRttiContext.Create;
end;

destructor TJanusRecord.Destroy;
begin
  FStringCache.Free;
  FRttiContext.Free;
  if FOwnsEntity then
    FEntity.Free;
  inherited;
end;

function TJanusRecord._PropertyByName(const AName: string): TRttiProperty;
var
  LType: TRttiType;
begin
  Result := nil;
  if not Assigned(FEntity) then
    Exit;
  LType := FRttiContext.GetType(FEntity.ClassType);
  if Assigned(LType) then
    Result := LType.GetProperty(AName);
end;

function TJanusRecord.GetStr(AField: PWideChar): PWideChar;
var
  LProp: TRttiProperty;
  LFieldName: string;
  LValue: TValue;
  LStr: WideString;
begin
  Result := nil;
  LFieldName := string(AField);
  LProp := _PropertyByName(LFieldName);
  if not Assigned(LProp) then
    Exit;
  LValue := LProp.GetValue(FEntity);
  LStr := WideString(LValue.AsString);
  FStringCache.AddOrSetValue(LFieldName, LStr);
  // Reference into dictionary storage — valid while interface lives
  Result := PWideChar(FStringCache[LFieldName]);
end;

function TJanusRecord.GetInt(AField: PWideChar): Integer;
var
  LProp: TRttiProperty;
begin
  Result := 0;
  LProp := _PropertyByName(string(AField));
  if Assigned(LProp) then
    Result := LProp.GetValue(FEntity).AsInteger;
end;

function TJanusRecord.GetFloat(AField: PWideChar): Double;
var
  LProp: TRttiProperty;
begin
  Result := 0;
  LProp := _PropertyByName(string(AField));
  if Assigned(LProp) then
    Result := LProp.GetValue(FEntity).AsExtended;
end;

function TJanusRecord.GetBool(AField: PWideChar): LongBool;
var
  LProp: TRttiProperty;
begin
  Result := False;
  LProp := _PropertyByName(string(AField));
  if Assigned(LProp) then
    Result := LProp.GetValue(FEntity).AsBoolean;
end;

procedure TJanusRecord.SetStr(AField, AValue: PWideChar);
var
  LProp: TRttiProperty;
begin
  LProp := _PropertyByName(string(AField));
  if Assigned(LProp) then
    LProp.SetValue(FEntity, TValue.From<string>(string(AValue)));
end;

procedure TJanusRecord.SetInt(AField: PWideChar; AValue: Integer);
var
  LProp: TRttiProperty;
begin
  LProp := _PropertyByName(string(AField));
  if Assigned(LProp) then
    LProp.SetValue(FEntity, TValue.From<Integer>(AValue));
end;

procedure TJanusRecord.SetFloat(AField: PWideChar; AValue: Double);
var
  LProp: TRttiProperty;
begin
  LProp := _PropertyByName(string(AField));
  if Assigned(LProp) then
    LProp.SetValue(FEntity, TValue.From<Double>(AValue));
end;

procedure TJanusRecord.SetBool(AField: PWideChar; AValue: LongBool);
var
  LProp: TRttiProperty;
begin
  LProp := _PropertyByName(string(AField));
  if Assigned(LProp) then
    LProp.SetValue(FEntity, TValue.From<Boolean>(Boolean(AValue)));
end;

function TJanusRecord.GetEntity: TObject;
begin
  Result := FEntity;
end;

end.
