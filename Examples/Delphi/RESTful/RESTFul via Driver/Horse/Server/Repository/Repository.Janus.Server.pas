unit Repository.Janus.Server;

interface

uses
  Provider.Interfaces,
  Provider.Janus.Server;

type
  TRepositoryServer = class
  private
    FProvider: IProvider;
  protected
  public
    constructor Create;
    destructor Destroy; override;
  end;

implementation

{ TRepositoryServer }

constructor TRepositoryServer.Create;
begin
  FProvider := TProviderJanus.Create;
end;

destructor TRepositoryServer.Destroy;
begin
  inherited;
end;

end.

