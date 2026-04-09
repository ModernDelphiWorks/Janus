program JanusUniDAC;

uses
  Forms,
  SysUtils,
  uMainFormORM in 'uMainFormORM.pas' {Form3},
  Janus.Model.Client in '..\Models\Janus.Model.Client.pas',
  Janus.Model.Detail in '..\Models\Janus.Model.Detail.pas',
  Janus.Model.Lookup in '..\Models\Janus.Model.Lookup.pas',
  Janus.Model.Master in '..\Models\Janus.Model.Master.pas',
  Janus.Command.Abstract in '..\..\..\Source\Core\Janus.Command.Abstract.pas',
  Janus.Command.Deleter in '..\..\..\Source\Core\Janus.Command.Deleter.pas',
  Janus.Command.Factory in '..\..\..\Source\Core\Janus.Command.Factory.pas',
  Janus.Command.Inserter in '..\..\..\Source\Core\Janus.Command.Inserter.pas',
  Janus.Command.Selecter in '..\..\..\Source\Core\Janus.Command.Selecter.pas',
  Janus.Command.Updater in '..\..\..\Source\Core\Janus.Command.Updater.pas',
  Janus.DML.Generator.Firebird in '..\..\..\Source\Core\Janus.DML.Generator.Firebird.pas',
  Janus.DML.Generator.InterBase in '..\..\..\Source\Core\Janus.DML.Generator.InterBase.pas',
  Janus.DML.Generator.MSSQL in '..\..\..\Source\Core\Janus.DML.Generator.MSSQL.pas',
  Janus.DML.Generator.MySQL in '..\..\..\Source\Core\Janus.DML.Generator.MySQL.pas',
  Janus.DML.Generator in '..\..\..\Source\Core\Janus.DML.Generator.pas',
  Janus.DML.Generator.PostgreSQL in '..\..\..\Source\Core\Janus.DML.Generator.PostgreSQL.pas',
  Janus.DML.Generator.SQLite in '..\..\..\Source\Core\Janus.DML.Generator.SQLite.pas',
  Janus.DML.Interfaces in '..\..\..\Source\Core\Janus.DML.Interfaces.pas',
  Janus.Driver.Register in '..\..\..\Source\Core\Janus.Driver.Register.pas',
  Janus.mapping.attributes in '..\..\..\Source\Core\Janus.mapping.attributes.pas',
  Janus.mapping.classes in '..\..\..\Source\Core\Janus.mapping.classes.pas',
  Janus.mapping.exceptions in '..\..\..\Source\Core\Janus.mapping.exceptions.pas',
  Janus.mapping.explorer in '..\..\..\Source\Core\Janus.mapping.explorer.pas',
  Janus.mapping.explorerstrategy in '..\..\..\Source\Core\Janus.mapping.explorerstrategy.pas',
  Janus.mapping.popular in '..\..\..\Source\Core\Janus.mapping.popular.pas',
  Janus.mapping.register in '..\..\..\Source\Core\Janus.mapping.register.pas',
  Janus.mapping.repository in '..\..\..\Source\Core\Janus.mapping.repository.pas',
  Janus.mapping.rttiutils in '..\..\..\Source\Core\Janus.mapping.rttiutils.pas',
  Janus.Objects.Helper in '..\..\..\Source\Core\Janus.Objects.Helper.pas',
  Janus.objects.manager in '..\..\..\Source\Core\Janus.objects.manager.pas',
  Janus.RTTI.Helper in '..\..\..\Source\Core\Janus.RTTI.Helper.pas',
  Janus.types.database in '..\..\..\Source\Core\Janus.types.database.pas',
  Janus.Types.Lazy in '..\..\..\Source\Core\Janus.Types.Lazy.pas',
  Janus.types.mapping in '..\..\..\Source\Core\Janus.types.mapping.pas',
  Janus.Types.Nullable in '..\..\..\Source\Core\Janus.Types.Nullable.pas',
  Janus.Json in '..\..\..\Source\Core\Janus.Json.pas',
  Janus.encddecd in '..\..\..\Source\Core\Janus.encddecd.pas',
  Janus.Types.Blob in '..\..\..\Source\Core\Janus.Types.Blob.pas',
  Janus.Container.ObjectSet.Interfaces in '..\..\..\Source\Objectset\Janus.Container.ObjectSet.Interfaces.pas',
  Janus.Container.ObjectSet in '..\..\..\Source\Objectset\Janus.Container.ObjectSet.pas',
  Janus.ObjectSet.Abstract in '..\..\..\Source\Objectset\Janus.ObjectSet.Abstract.pas',
  Janus.ObjectSet.Adapter in '..\..\..\Source\Objectset\Janus.ObjectSet.Adapter.pas',
  Janus.objectset.bind in '..\..\..\Source\Objectset\Janus.objectset.bind.pas',
  Janus.Form.Monitor in '..\..\..\Source\Monitor\Janus.Form.Monitor.pas' {CommandMonitor},
  Janus.monitor in '..\..\..\Source\Monitor\Janus.monitor.pas';

{$R *.res}

begin
  Application.Initialize;
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm3, Form3);
  Application.Run;
end.
