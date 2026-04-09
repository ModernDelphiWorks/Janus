program JanusServer;

uses
  Forms,
  Server.Data.Main in 'Server.Data.Main.pas' {ServerDataModule: TDataModule},
  Server.Forms.Main in 'Server.Forms.Main.pas' {MainForm},
  Server.Resources in 'Server.Resources.pas',
  Janus.Model.Client in '..\Janus.Model.Client.pas',
  Janus.Model.Detail in '..\Janus.Model.Detail.pas',
  Janus.Model.Lookup in '..\Janus.Model.Lookup.pas',
  Janus.Model.Master in '..\Janus.Model.Master.pas',
  Janus.Server.MARS in '..\..\..\..\Source\RESTful Components\Server\Janus.Server.MARS.pas',
  Janus.Server.Resource.MARS in '..\..\..\..\Source\RESTful Components\Server\Janus.Server.Resource.MARS.pas';

{$R *.res}

begin
  Application.Initialize;
  ReportMemoryLeaksOnShutdown := True;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TServerDataModule, ServerDataModule);
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
