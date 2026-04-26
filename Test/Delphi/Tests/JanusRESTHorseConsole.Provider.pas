unit JanusRESTHorseConsole.Provider;

interface

uses
  DataEngine.FactoryInterfaces,
  DataEngine.FactoryFireDAC,
  Janus.DML.Generator.SQLite,
  Janus.Server.Horse,
  JanusRESTHorseConsole.DataModule,
  JanusRESTHorseConsole.Interfaces;

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
  // DataEngine Engine de Conexão a Banco de Dados
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
