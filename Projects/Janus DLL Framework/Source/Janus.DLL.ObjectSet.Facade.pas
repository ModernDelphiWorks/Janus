unit Janus.DLL.ObjectSet.Facade;

// NOTE: IJanusObjectSet and IJanusRecord are declared in Janus.DLL.Interfaces.pas.
// This unit implements TJanusObjectSet — DLL-internal only.

interface

uses
  System.SysUtils,
  Generics.Collections,
  Janus.DLL.Interfaces,
  Janus.DLL.Entity.Proxy,
  Janus.DLL.JanusRecord.Facade;

type
  /// <summary>
  /// Implements IJanusObjectSet. Delegates all persistence to TEntityProxyBase
  /// so that no generics reach the DLL boundary.
  /// </summary>
  TJanusObjectSet = class(TInterfacedObject, IJanusObjectSet)
  private
    FProxy: TEntityProxyBase;
    FList: TObjectList<TObject>;
    FCurrentIndex: Integer;
  public
    constructor Create(const AProxy: TEntityProxyBase);
    constructor CreateFromList(const AProxy: TEntityProxyBase;
      const AList: TObjectList<TObject>);
    destructor Destroy; override;
    // IJanusObjectSet
    function Open: LongBool; stdcall;
    function OpenWhere(AWhere, AOrderBy: PWideChar): LongBool; stdcall;
    function FindByID(AID: Integer): IJanusRecord; stdcall;
    function RecordCount: Integer; stdcall;
    function GetRecord(AIndex: Integer): IJanusRecord; stdcall;
    function NewRecord: IJanusRecord; stdcall;
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

{ TJanusObjectSet }

constructor TJanusObjectSet.Create(const AProxy: TEntityProxyBase);
begin
  inherited Create;
  FProxy := AProxy;
  FCurrentIndex := -1;
  // OwnsObjects = False: object lifetime managed by proxy/container
  FList := TObjectList<TObject>.Create(False);
end;

constructor TJanusObjectSet.CreateFromList(const AProxy: TEntityProxyBase;
  const AList: TObjectList<TObject>);
begin
  inherited Create;
  FProxy := AProxy;
  FCurrentIndex := -1;
  FList := AList;
end;

destructor TJanusObjectSet.Destroy;
begin
  FList.Free;
  FProxy.Free;   // proxy is created per CreateObjectSet call; ObjectSet owns it
  inherited;
end;

function TJanusObjectSet.Open: LongBool;
var
  LResult: TObjectList<TObject>;
begin
  try
    FList.Clear;
    LResult := FProxy.FindAll;
    try
      FList.AddRange(LResult);
    finally
      LResult.Free;
    end;
    FCurrentIndex := -1;
    Result := True;
  except
    Result := False;
  end;
end;

function TJanusObjectSet.OpenWhere(AWhere, AOrderBy: PWideChar): LongBool;
var
  LResult: TObjectList<TObject>;
begin
  try
    FList.Clear;
    LResult := FProxy.FindWhere(string(AWhere), string(AOrderBy));
    try
      FList.AddRange(LResult);
    finally
      LResult.Free;
    end;
    FCurrentIndex := -1;
    Result := True;
  except
    Result := False;
  end;
end;

function TJanusObjectSet.FindByID(AID: Integer): IJanusRecord;
var
  LEntity: TObject;
begin
  Result := nil;
  LEntity := FProxy.FindByID(AID);
  if Assigned(LEntity) then
    Result := TJanusRecord.Create(LEntity, False);
end;

function TJanusObjectSet.RecordCount: Integer;
begin
  Result := FList.Count;
end;

function TJanusObjectSet.GetRecord(AIndex: Integer): IJanusRecord;
begin
  Result := nil;
  if (AIndex < 0) or (AIndex >= FList.Count) then
    Exit;
  Result := TJanusRecord.Create(FList[AIndex], False);
end;

function TJanusObjectSet.NewRecord: IJanusRecord;
begin
  Result := TJanusRecord.Create(FProxy.NewObj, True);
end;

procedure TJanusObjectSet.Insert(ARecord: IJanusRecord);
var
  LEntity: TObject;
begin
  LEntity := (ARecord as TJanusRecord).GetEntity;
  FProxy.InsertObj(LEntity);
end;

procedure TJanusObjectSet.Update(ARecord: IJanusRecord);
var
  LEntity: TObject;
begin
  LEntity := (ARecord as TJanusRecord).GetEntity;
  FProxy.UpdateObj(LEntity);
end;

procedure TJanusObjectSet.Delete(ARecord: IJanusRecord);
var
  LEntity: TObject;
begin
  LEntity := (ARecord as TJanusRecord).GetEntity;
  FProxy.DeleteObj(LEntity);
end;

{ SPRINT-08 — Pagination + Navigation }

function TJanusObjectSet.NextPacket(APageSize, APageNext: Integer): LongBool;
var
  LResult: TObjectList<TObject>;
begin
  try
    FList.Clear;
    LResult := FProxy.NextPacketObj(APageSize, APageNext);
    try
      FList.AddRange(LResult);
    finally
      LResult.Free;
    end;
    FCurrentIndex := -1;
    Result := True;
  except
    Result := False;
  end;
end;

function TJanusObjectSet.First: LongBool;
begin
  if FList.Count > 0 then
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

function TJanusObjectSet.Next: LongBool;
begin
  Inc(FCurrentIndex);
  Result := (FCurrentIndex >= 0) and (FCurrentIndex < FList.Count);
end;

function TJanusObjectSet.Prior: LongBool;
begin
  Dec(FCurrentIndex);
  Result := (FCurrentIndex >= 0) and (FCurrentIndex < FList.Count);
end;

function TJanusObjectSet.Eof: LongBool;
begin
  Result := (FList.Count = 0) or (FCurrentIndex >= FList.Count);
end;

function TJanusObjectSet.CurrentRecord: IJanusRecord;
begin
  Result := nil;
  if (FCurrentIndex >= 0) and (FCurrentIndex < FList.Count) then
    Result := TJanusRecord.Create(FList[FCurrentIndex], False);
end;

end.
