unit Janus.DLL.Models.Registry;

// This unit registers all entity models into the TEntityProxyRegistry and
// into Janus's TRegisterClass. Called by the exported RegisterModels function.
// To add a new entity: register it in RegisterAllModels following the pattern
// used for TClientModel below.

interface

uses
  Janus.DLL.Entity.Proxy,
  Janus.DLL.Model.Client;

/// <summary>
/// Registers all known entity proxy factories into TEntityProxyRegistry
/// and all entity types into Janus's TRegisterClass.
/// Must be called once at startup before any CreateObjectSet call.
/// </summary>
procedure RegisterAllModels;

implementation

uses
  DataEngine.FactoryInterfaces;

procedure RegisterAllModels;
begin
  TEntityProxyRegistry.Instance.RegisterFactory(
    'TClientModel',
    function(AConn: IDBConnection): TEntityProxyBase
    begin
      Result := TEntityProxy<TClientModel>.Create(AConn);
    end
  );
end;

end.
