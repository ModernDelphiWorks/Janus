program Janus_MiddlewareEvents;

uses
  Forms,
  SysUtils,
  uMainFormORM in 'uMainFormORM.pas' {Form3},
  Janus.Model.Client in 'Janus.Model.Client.pas',
  Janus.Model.Detail in 'Janus.Model.Detail.pas',
  Janus.Model.Lookup in 'Janus.Model.Lookup.pas',
  Janus.Model.Master in 'Janus.Model.Master.pas',
  MetaDbDiff.Types.Mapping in '..\..\..\..\MetaDbDiff\Source\Core\MetaDbDiff.Types.Mapping.pas',
  Janus.Events.Middleware in '..\..\..\Source\Middleware\Janus.Events.Middleware.pas',
  Janus.After.Delete.Middleware in '..\..\..\Source\Middleware\Janus.After.Delete.Middleware.pas',
  Janus.After.Insert.Middleware in '..\..\..\Source\Middleware\Janus.After.Insert.Middleware.pas',
  Janus.After.Update.Middleware in '..\..\..\Source\Middleware\Janus.After.Update.Middleware.pas',
  Janus.Before.Delete.Middleware in '..\..\..\Source\Middleware\Janus.Before.Delete.Middleware.pas',
  Janus.Before.Insert.Middleware in '..\..\..\Source\Middleware\Janus.Before.Insert.Middleware.pas',
  Janus.Before.Update.Middleware in '..\..\..\Source\Middleware\Janus.Before.Update.Middleware.pas';

{$R *.res}

begin
  Application.Initialize;
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm3, Form3);
  Application.Run;
end.
