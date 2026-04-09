{******************************************************************************}
{                                                                              }
{       WiRL: RESTful Library for Delphi                                       }
{                                                                              }
{       Copyright (c) 2015-2017 WiRL Team                                      }
{                                                                              }
{       https://github.com/delphi-blocks/WiRL                                  }
{                                                                              }
{******************************************************************************}
program JanusServer;

uses
  Forms,
  Server.Forms.Main in 'Server.Forms.Main.pas' {MainForm},
  Janus.Model.Client in '..\Janus.Model.Client.pas',
  Janus.Model.Detail in '..\Janus.Model.Detail.pas',
  Janus.Model.Lookup in '..\Janus.Model.Lookup.pas',
  Janus.Model.Master in '..\Janus.Model.Master.pas',
  Server.Datamodule in 'Server.Datamodule.pas' {ServerDataModule: TDataModule},
  Janus.Server.Resource.WiRL in '..\..\..\..\Source\RESTful Components\Server\Janus.Server.Resource.WiRL.pas',
  Janus.Server.WiRL in '..\..\..\..\Source\RESTful Components\Server\Janus.Server.WiRL.pas',
  Server.Resources in 'Server.Resources.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TServerDataModule, ServerDataModule);
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
