program JanusSQLDirect;

uses
  Forms,
  SysUtils,
  uMainFormORM in 'uMainFormORM.pas' {Form3},
  Janus.Model.Client in '..\Models\Janus.Model.Client.pas',
  Janus.Model.Detail in '..\Models\Janus.Model.Detail.pas',
  Janus.Model.Lookup in '..\Models\Janus.Model.Lookup.pas',
  Janus.Model.Master in '..\Models\Janus.Model.Master.pas',
  Janus.driver.sqldirect in '..\..\..\Source\Drivers\Janus.driver.sqldirect.pas',
  Janus.driver.sqldirect.transaction in '..\..\..\Source\Drivers\Janus.driver.sqldirect.transaction.pas',
  Janus.factory.sqldirect in '..\..\..\Source\Drivers\Janus.factory.sqldirect.pas',
  Janus.Form.Monitor in '..\..\..\Source\Monitor\Janus.Form.Monitor.pas' {CommandMonitor},
  Janus.monitor in '..\..\..\Source\Monitor\Janus.monitor.pas',
  Janus.Container.ClientDataSet in '..\..\..\Source\Dataset\Janus.Container.ClientDataSet.pas',
  Janus.Container.DataSet.Interfaces in '..\..\..\Source\Dataset\Janus.Container.DataSet.Interfaces.pas',
  Janus.Container.DataSet in '..\..\..\Source\Dataset\Janus.Container.DataSet.pas',
  Janus.Container.FDMemTable in '..\..\..\Source\Dataset\Janus.Container.FDMemTable.pas',
  Janus.DataSet.Adapter in '..\..\..\Source\Dataset\Janus.DataSet.Adapter.pas',
  Janus.DataSet.Base.Adapter in '..\..\..\Source\Dataset\Janus.DataSet.Base.Adapter.pas',
  Janus.dataset.bind in '..\..\..\Source\Dataset\Janus.dataset.bind.pas',
  Janus.DataSet.ClientDataSet in '..\..\..\Source\Dataset\Janus.DataSet.ClientDataSet.pas',
  Janus.DataSet.Consts in '..\..\..\Source\Dataset\Janus.DataSet.Consts.pas',
  Janus.DataSet.Events in '..\..\..\Source\Dataset\Janus.DataSet.Events.pas',
  Janus.DataSet.FDMemTable in '..\..\..\Source\Dataset\Janus.DataSet.FDMemTable.pas',
  Janus.DataSet.Fields in '..\..\..\Source\Dataset\Janus.DataSet.Fields.pas',
  Janus.Manager.DataSet in '..\..\..\Source\Dataset\Janus.Manager.DataSet.pas',
  Janus.Session.DataSet in '..\..\..\Source\Dataset\Janus.Session.DataSet.pas';

{$R *.res}

begin
  Application.Initialize;
  ReportMemoryLeaksOnShutdown := True;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm3, Form3);
  Application.Run;
end.
