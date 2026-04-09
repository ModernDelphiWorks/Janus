unit Janus.DLL.Connection.Facade;

// NOTE: IJanusConnection is declared in Janus.DLL.Interfaces.pas.
// TJanusConnection wraps IDBConnection from DataEngine — DLL-internal only.

interface

uses
  FireDAC.Comp.Client,
  DataEngine.FactoryInterfaces,
  Janus.DLL.Interfaces;

type
  /// <summary>
  /// DLL-internal interface to extract the underlying IDBConnection.
  /// Exposed only within the DLL; not declared in Janus.IncludeDll.pas.
  /// </summary>
  IJanusConnectionInternal = interface(IInterface)
    ['{D4E5F6A7-B8C9-0123-DEF0-1234567890A4}']
    function InternalConnection: IDBConnection;
    function FDConnection: TFDConnection;
  end;

  /// <summary>
  /// Implements IJanusConnection and IJanusConnectionInternal.
  /// InternalConnection is used by CreateObjectSet to pass the real
  /// IDBConnection into TEntityProxy<T>.
  /// AOwnedNative (optional): a TObject created by the DLL Connect* functions
  /// (typically TFDConnection) whose lifetime is tied to this wrapper.
  /// IMPORTANT: release all IJanusObjectSet instances BEFORE releasing this
  /// connection — the underlying TFDConnection is freed in this destructor.
  /// </summary>
  TJanusConnection = class(TInterfacedObject, IJanusConnection,
    IJanusConnectionInternal)
  private
    FDBConnection: IDBConnection;
    FOwnedNative: TObject;
  public
    constructor Create(const ADBConnection: IDBConnection;
      const AOwnedNative: TObject = nil);
    destructor Destroy; override;
    // IJanusConnection
    function IsConnected: LongBool; stdcall;
    // IJanusConnectionInternal
    function InternalConnection: IDBConnection;
    function FDConnection: TFDConnection;
  end;

implementation

{ TJanusConnection }

constructor TJanusConnection.Create(const ADBConnection: IDBConnection;
  const AOwnedNative: TObject);
begin
  inherited Create;
  FDBConnection := ADBConnection;
  FOwnedNative := AOwnedNative;
end;

destructor TJanusConnection.Destroy;
begin
  FDBConnection := nil; // release IDBConnection ref (TFactoryFiredac) first
  FOwnedNative.Free;    // then free TFDConnection; safe once IDBConnection freed
  inherited;
end;

function TJanusConnection.IsConnected: LongBool;
begin
  Result := Assigned(FDBConnection) and FDBConnection.IsConnected;
end;

function TJanusConnection.InternalConnection: IDBConnection;
begin
  Result := FDBConnection;
end;

function TJanusConnection.FDConnection: TFDConnection;
begin
  if FOwnedNative is TFDConnection then
    Result := TFDConnection(FOwnedNative)
  else
    Result := nil;
end;

end.
