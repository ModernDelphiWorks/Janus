program JanusServer;
{$APPTYPE GUI}

uses
  Vcl.Forms,
  Provider.DataModule in 'Provider\Provider.DataModule.pas' {ProviderDM: TDataModule},
  Main.Server in 'Main.Server.pas' {FormServer},
  Janus.Model.Client in '..\Model\Janus.Model.Client.pas',
  Janus.Model.Detail in '..\Model\Janus.Model.Detail.pas',
  Janus.Model.Lookup in '..\Model\Janus.Model.Lookup.pas',
  Janus.Model.Master in '..\Model\Janus.Model.Master.pas',
  Controller.Janus.Server in 'Controller\Controller.Janus.Server.pas',
  Repository.Janus.Server in 'Repository\Repository.Janus.Server.pas',
  Provider.Janus.Server in 'Provider\Provider.Janus.Server.pas',
  Provider.Interfaces in 'Provider\Provider.Interfaces.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := true;
  Application.Initialize;
  Application.CreateForm(TFormServer, FormServer);
  Application.Run;
end.

