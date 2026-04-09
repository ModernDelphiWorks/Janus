program JanusServer;
{$APPTYPE GUI}

uses
  Vcl.Forms,
  Web.WebReq,
  IdHTTPWebBrokerBridge,
  uFormServer in 'uFormServer.pas' {Form1},
  uServerModule in 'uServerModule.pas' {Janus: TDSServerModule},
  uServerContainer in 'uServerContainer.pas' {ServerContainer1: TDataModule},
  uWebModule in 'uWebModule.pas' {WebModule1: TWebModule},
  Janus.Model.Client in '..\..\Data\Models\Janus.Model.Client.pas',
  Janus.Model.Detail in '..\..\Data\Models\Janus.Model.Detail.pas',
  Janus.Model.Lookup in '..\..\Data\Models\Janus.Model.Lookup.pas',
  Janus.Model.Master in '..\..\Data\Models\Janus.Model.Master.pas';

{$R *.res}

begin
  if WebRequestHandler <> nil then
    WebRequestHandler.WebModuleClass := WebModuleClass;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
