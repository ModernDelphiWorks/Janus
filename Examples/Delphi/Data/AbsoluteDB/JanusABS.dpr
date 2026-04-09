program JanusABS;

uses
  Forms,
  SysUtils,
  uMainFormORM in 'uMainFormORM.pas' {Form3},
  Janus.Model.Client in '..\Models\Janus.Model.Client.pas',
  Janus.Model.Detail in '..\Models\Janus.Model.Detail.pas',
  Janus.Model.Lookup in '..\Models\Janus.Model.Lookup.pas',
  Janus.Model.Master in '..\Models\Janus.Model.Master.pas',
  Janus.driver.absolutedb in '..\..\..\Source\Drivers\Janus.driver.absolutedb.pas',
  Janus.driver.absolutedb.transaction in '..\..\..\Source\Drivers\Janus.driver.absolutedb.transaction.pas',
  Janus.factory.absolutedb in '..\..\..\Source\Drivers\Janus.factory.absolutedb.pas',
  Janus.Form.Monitor in '..\..\..\Source\Monitor\Janus.Form.Monitor.pas' {CommandMonitor},
  Janus.monitor in '..\..\..\Source\Monitor\Janus.monitor.pas',
  Janus.DML.Generator.AbsoluteDB in '..\..\..\Source\Core\Janus.DML.Generator.AbsoluteDB.pas';

{$R *.res}

begin
  Application.Initialize;
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm3, Form3);
  Application.Run;
end.
