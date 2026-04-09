unit Provider.Janus.Server;

interface

uses
  // DataEngine Conex�o Database
  DataEngine.FactoryInterfaces,
  DataEngine.FactoryFireDac,
  // Janus Driver SQLite
  Janus.DML.Generator.SQLite,
  // Janus Server Horse
  Janus.Server.Horse,
  //
  Provider.DataModule,
  Provider.Interfaces;

type
  TProviderJanus = class(TInterfacedObject, IProvider)
  private
    FRESTServerHorse: TRESTServerHorse;
    FConnection: IDBConnection;
    FProviderDM: TProviderDM;
  protected
  public
    constructor Create;
    destructor Destroy; override;
  end;

implementation

{ TProviderJanus }

constructor TProviderJanus.Create;
begin
  FProviderDM := TProviderDM.Create(nil);
  // DataEngine Engine de Conex�o a Banco de Dados
  FConnection := TFactoryFireDAC.Create(FProviderDM.FDConnection1, dnSQLite);
  // Janus - REST Server Horse
  FRESTServerHorse := TRESTServerHorse.Create(nil, FConnection, 'api/Janus');
end;

destructor TProviderJanus.Destroy;
begin
  FProviderDM.Free;
  FRESTServerHorse.Free;
  inherited;
end;

end.

