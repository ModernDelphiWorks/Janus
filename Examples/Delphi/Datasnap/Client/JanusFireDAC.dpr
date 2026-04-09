program JanusFireDAC;

uses
  Forms,
  SysUtils,
  uMainFormORM in 'uMainFormORM.pas' {Form3},
  Janus.RestDataSet.FDMemTable in '..\..\..\Source\RESTful\Client\Janus.RestDataSet.FDMemTable.pas',
  Janus.RestDataSet.Adapter in '..\..\..\Source\RESTful\Client\Janus.RestDataSet.Adapter.pas',
  Janus.Client.DataSnap in '..\..\..\Source\RESTful\Client\Janus.Client.DataSnap.pas',
  Janus.Model.Client in '..\..\Data\Models\Janus.Model.Client.pas',
  Janus.Model.Detail in '..\..\Data\Models\Janus.Model.Detail.pas',
  Janus.Model.Lookup in '..\..\Data\Models\Janus.Model.Lookup.pas',
  Janus.Model.Master in '..\..\Data\Models\Janus.Model.Master.pas',
  Janus.Session.RESTful in '..\..\..\Source\RESTful\Client\Janus.Session.RESTful.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm3, Form3);
  Application.Run;
end.
