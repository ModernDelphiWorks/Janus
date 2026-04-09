program Janus_FiredacCrudSimples;

uses
  Forms,
  SysUtils,
  uMainFormORM in 'uMainFormORM.pas' {Form3},
  Janus.Model.Client in 'Janus.Model.Client.pas';

{$R *.res}

begin
  Application.Initialize;
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm3, Form3);
  Application.Run;
end.
