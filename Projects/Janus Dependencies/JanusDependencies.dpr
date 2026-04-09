program JanusDependencies;

uses
  Vcl.Forms,
  Janus.Dependencies.Main in 'Janus.Dependencies.Main.pas' {frmJanusDependencies},
  Janus.Dependencies.Interfaces in 'Janus.Dependencies.Interfaces.pas',
  Janus.Dependencies.Executor in 'Janus.Dependencies.Executor.pas',
  Janus.Dependencies.Command.Base in 'Janus.Dependencies.Command.Base.pas',
  Janus.Dependencies.Command.DataEngine in 'Janus.Dependencies.Command.DataEngine.pas',
  Janus.Dependencies.Command.FluentSQL in 'Janus.Dependencies.Command.FluentSQL.pas',
  Janus.Dependencies.Command.MetaDbDiff in 'Janus.Dependencies.Command.MetaDbDiff.pas',
  Janus.Dependencies.Command.JsonFlow in 'Janus.Dependencies.Command.JsonFlow.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  ReportMemoryLeaksOnShutdown := True;
  Application.CreateForm(TfrmJanusDependencies, frmJanusDependencies);
  Application.Run;
end.
