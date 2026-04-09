program Janus_ObjectLazy;

uses
  Vcl.Forms,
  Principal in 'Principal.pas' {Form1},
  Model.Atendimento in 'Model.Atendimento.pas',
  Model.Exame in 'Model.Exame.pas',
  Model.Procedimento in 'Model.Procedimento.pas',
  Model.Setor in 'Model.Setor.pas',
  Janus.Types.Lazy in '..\..\..\Source\Core\Janus.Types.Lazy.pas',
  Janus.Form.Monitor in '..\..\..\Source\Monitor\Janus.Form.Monitor.pas' {CommandMonitor};

{$R *.res}

begin
  Application.Initialize;
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
