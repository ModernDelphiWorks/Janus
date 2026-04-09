unit Janus.DLL.Entity.Proxy;

interface

uses
  SysUtils,
  Generics.Collections,
  DataEngine.FactoryInterfaces,
  Janus.Container.ObjectSet,
  Janus.Container.ObjectSet.Interfaces;

type
  /// <summary>
  /// Abstract non-generic base for entity proxies. Used as a COM-safe boundary:
  /// all method signatures use TObject so no generics cross the DLL boundary.
  /// </summary>
  TEntityProxyBase = class abstract
  public
    function FindAll: TObjectList<TObject>; virtual; abstract;
    function FindByID(const AID: Integer): TObject; virtual; abstract;
    function FindByIDStr(const AID: string): TObject; virtual; abstract;
    function NewObj: TObject; virtual; abstract;
    procedure InsertObj(const AObj: TObject); virtual; abstract;
    procedure UpdateObj(const AObj: TObject); virtual; abstract;
    procedure DeleteObj(const AObj: TObject); virtual; abstract;
    function FindWhere(const AWhere, AOrderBy: string): TObjectList<TObject>; virtual; abstract;
    // SPRINT-08 — Pagination support (ADR-009)
    function NextPacketObj(const APageSize, APageNext: Integer): TObjectList<TObject>; virtual; abstract;
  end;

  /// <summary>
  /// Generic implementation of TEntityProxyBase for a specific entity type T.
  /// Compiled only inside the DLL; never exported externally.
  /// </summary>
  TEntityProxy<T: class, constructor> = class(TEntityProxyBase)
  private
    FContainer: IContainerObjectSet<T>;
  public
    constructor Create(const AConnection: IDBConnection;
      const APageSize: Integer = -1);
    function FindAll: TObjectList<TObject>; override;
    function FindByID(const AID: Integer): TObject; override;
    function FindByIDStr(const AID: string): TObject; override;
    function NewObj: TObject; override;
    procedure InsertObj(const AObj: TObject); override;
    procedure UpdateObj(const AObj: TObject); override;
    procedure DeleteObj(const AObj: TObject); override;
    function FindWhere(const AWhere, AOrderBy: string): TObjectList<TObject>; override;
    function NextPacketObj(const APageSize, APageNext: Integer): TObjectList<TObject>; override;
  end;

  /// <summary>
  /// Factory function signature: given a connection, returns a new proxy.
  /// </summary>
  TProxyFactory = TFunc<IDBConnection, TEntityProxyBase>;

  /// <summary>
  /// Singleton registry mapping entity class names to proxy factories.
  /// RegisterFactory stores the factory; CreateProxy instantiates a new proxy
  /// with the provided connection — called on each CreateObjectSet invocation.
  /// </summary>
  TEntityProxyRegistry = class
  private
    class var FInstance: TEntityProxyRegistry;
    FFactories: TDictionary<string, TProxyFactory>;
    procedure _ClearFactories;
  public
    constructor Create;
    destructor Destroy; override;
    class function Instance: TEntityProxyRegistry;
    class procedure FreeInstance; reintroduce;
    procedure RegisterFactory(const AEntityName: string;
      const AFactory: TProxyFactory);
    function CreateProxy(const AEntityName: string;
      const AConnection: IDBConnection): TEntityProxyBase;
    function HasFactory(const AEntityName: string): Boolean;
    procedure Clear;
  end;

implementation

{ TEntityProxy<T> }

constructor TEntityProxy<T>.Create(const AConnection: IDBConnection;
  const APageSize: Integer);
begin
  inherited Create;
  FContainer := TContainerObjectSet<T>.Create(AConnection, APageSize);
end;

function TEntityProxy<T>.FindAll: TObjectList<TObject>;
var
  LTyped: TObjectList<T>;
  LItem: T;
begin
  Result := TObjectList<TObject>.Create(False);
  LTyped := FContainer.Find;
  for LItem in LTyped do
    Result.Add(LItem);
end;

function TEntityProxy<T>.FindByID(const AID: Integer): TObject;
begin
  Result := FContainer.Find(Int64(AID));
end;

function TEntityProxy<T>.FindByIDStr(const AID: string): TObject;
begin
  Result := FContainer.Find(AID);
end;

function TEntityProxy<T>.NewObj: TObject;
begin
  Result := T.Create;
end;

procedure TEntityProxy<T>.InsertObj(const AObj: TObject);
begin
  FContainer.Insert(T(AObj));
end;

procedure TEntityProxy<T>.UpdateObj(const AObj: TObject);
begin
  FContainer.Update(T(AObj));
end;

procedure TEntityProxy<T>.DeleteObj(const AObj: TObject);
begin
  FContainer.Delete(T(AObj));
end;

function TEntityProxy<T>.FindWhere(const AWhere,
  AOrderBy: string): TObjectList<TObject>;
var
  LTyped: TObjectList<T>;
  LItem: T;
begin
  Result := TObjectList<TObject>.Create(False);
  LTyped := FContainer.FindWhere(AWhere, AOrderBy);
  for LItem in LTyped do
    Result.Add(LItem);
end;

function TEntityProxy<T>.NextPacketObj(const APageSize,
  APageNext: Integer): TObjectList<TObject>;
var
  LTyped: TObjectList<T>;
  LItem: T;
begin
  Result := TObjectList<TObject>.Create(False);
  LTyped := FContainer.NextPacket(APageSize, APageNext);
  if Assigned(LTyped) then
    for LItem in LTyped do
      Result.Add(LItem);
end;

{ TEntityProxyRegistry }

constructor TEntityProxyRegistry.Create;
begin
  inherited;
  FFactories := TDictionary<string, TProxyFactory>.Create;
end;

destructor TEntityProxyRegistry.Destroy;
begin
  _ClearFactories;
  FFactories.Free;
  inherited;
end;

procedure TEntityProxyRegistry._ClearFactories;
begin
  FFactories.Clear;
end;

class function TEntityProxyRegistry.Instance: TEntityProxyRegistry;
begin
  if not Assigned(FInstance) then
    FInstance := TEntityProxyRegistry.Create;
  Result := FInstance;
end;

class procedure TEntityProxyRegistry.FreeInstance;
begin
  if Assigned(FInstance) then
  begin
    FInstance.Free;
    FInstance := nil;
  end;
end;

procedure TEntityProxyRegistry.RegisterFactory(const AEntityName: string;
  const AFactory: TProxyFactory);
begin
  FFactories.AddOrSetValue(AEntityName, AFactory);
end;

function TEntityProxyRegistry.CreateProxy(const AEntityName: string;
  const AConnection: IDBConnection): TEntityProxyBase;
var
  LFactory: TProxyFactory;
begin
  Result := nil;
  if FFactories.TryGetValue(AEntityName, LFactory) then
    Result := LFactory(AConnection);
end;

function TEntityProxyRegistry.HasFactory(const AEntityName: string): Boolean;
begin
  Result := FFactories.ContainsKey(AEntityName);
end;

procedure TEntityProxyRegistry.Clear;
begin
  _ClearFactories;
end;

initialization

finalization
  TEntityProxyRegistry.FreeInstance;

end.
