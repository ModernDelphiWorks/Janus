program JanusClient;

uses
  Vcl.Forms,
  Client.Forms.Main in 'Client.Forms.Main.pas' {Form3},
  Janus.Model.Client in '..\Janus.Model.Client.pas',
  Janus.Model.Detail in '..\Janus.Model.Detail.pas',
  Janus.Model.Lookup in '..\Janus.Model.Lookup.pas',
  Janus.Model.Master in '..\Janus.Model.Master.pas',
  Janus.Client.WiRL in '..\..\..\..\Source\RESTful Components\Client\Janus.Client.WiRL.pas',
  Janus.driver.rest.wirl in '..\..\..\..\Source\RESTful Components\Client\Janus.driver.rest.wirl.pas',
  Janus.factory.rest.wirl in '..\..\..\..\Source\RESTful Components\Client\Janus.factory.rest.wirl.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm3, Form3);
  Application.Run;
end.

