program JanusMetadata;

uses
  System.StartUpCopy,
  FMX.Forms,
  uPrincipal in 'uPrincipal.pas' {Form4},
  Janus.Model.Client in '..\..\..\Data\Models\Janus.Model.Client.pas',
  Janus.Model.Detail in '..\..\..\Data\Models\Janus.Model.Detail.pas',
  Janus.Model.Lookup in '..\..\..\Data\Models\Janus.Model.Lookup.pas',
  Janus.Model.Master in '..\..\..\Data\Models\Janus.Model.Master.pas';

{$R *.res}

begin
  Application.Initialize;
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
  Application.CreateForm(TForm4, Form4);
  Application.Run;
end.
