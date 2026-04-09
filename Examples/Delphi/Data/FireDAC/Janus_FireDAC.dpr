program Janus_Firedac;

uses
  Forms,
  SysUtils,
  uMainFormORM in 'uMainFormORM.pas' {Form3},
  Janus.Model.Client in 'Janus.Model.Client.pas',
  Janus.Model.Detail in 'Janus.Model.Detail.pas',
  Janus.Model.Lookup in 'Janus.Model.Lookup.pas',
  Janus.Model.Master in 'Janus.Model.Master.pas';

{$R *.res}

begin
  Application.Initialize;
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm3, Form3);
  Application.Run;
end.
