program JanusClient;

uses
  Forms,
  SysUtils,
  Main.Client in 'View\Main.Client.pas' {FormClient},
  Janus.Model.Client in '..\Model\Janus.Model.Client.pas',
  Janus.Model.Detail in '..\Model\Janus.Model.Detail.pas',
  Janus.Model.Lookup in '..\Model\Janus.Model.Lookup.pas',
  Janus.Model.Master in '..\Model\Janus.Model.Master.pas',
  Provider.Janus in 'Provider\Provider.Janus.pas',
  Repository.Master in 'Repository\Repository.Master.pas',
  Controller.Master in 'Controller\Controller.Master.pas',
  Provider.DataModule in 'Provider\Provider.DataModule.pas' {ProviderDM: TDataModule},
  Janus.Manager.DataSet in '..\..\..\..\..\Source\Dataset\Janus.Manager.DataSet.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFormClient, FormClient);
  Application.Run;
end.

