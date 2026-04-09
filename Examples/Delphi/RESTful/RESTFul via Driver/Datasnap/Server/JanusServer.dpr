program JanusServer;
{$APPTYPE GUI}

uses
  Vcl.Forms,
  Web.WebReq,
  IdHTTPWebBrokerBridge,
  uFormServer in 'uFormServer.pas' {Form1},
  uMasterServerModule in 'uMasterServerModule.pas' {apimaster: TDSServerModule},
  uWebModule in 'uWebModule.pas' {WebModule1: TWebModule},
  Janus.Model.Client in '..\Janus.Model.Client.pas',
  Janus.Model.Detail in '..\Janus.Model.Detail.pas',
  Janus.Model.Lookup in '..\Janus.Model.Lookup.pas',
  Janus.Model.Master in '..\Janus.Model.Master.pas',
  uLookupServerModule in 'uLookupServerModule.pas' {apilookup: TDSServerModule},
  uDataModuleServer in 'uDataModuleServer.pas' {DataModuleServer: TDataModule},
  Janus.Server.DataSnap in '..\..\..\..\Source\Server\Janus.Server.DataSnap.pas',
  Janus.Server.Resource.DataSnap in '..\..\..\..\Source\Server\Janus.Server.Resource.DataSnap.pas';

{$R *.res}

begin
  if WebRequestHandler <> nil then
    WebRequestHandler.WebModuleClass := WebModuleClass;
  Application.Initialize;
  Application.CreateForm(TDataModuleServer, DataModuleServer);
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
