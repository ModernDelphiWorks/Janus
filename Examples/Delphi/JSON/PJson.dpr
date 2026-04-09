program PJSON;

uses
  Forms,
  uJSON in 'uJSON.pas' {Form4},
  Janus.model.person in 'Janus.model.person.pas',
  JsonFlow.Utils in '..\..\Source\Dependencies\JsonFlow\Source\Core\JsonFlow.Utils.pas',
  JsonFlow.Builders in '..\..\Source\Dependencies\JsonFlow\Source\Core\JsonFlow.Builders.pas',
  JsonFlow.Reader in '..\..\Source\Dependencies\JsonFlow\Source\Reader\JsonFlow.Reader.pas',
  JsonFlow.Writer in '..\..\Source\Dependencies\JsonFlow\Source\Writer\JsonFlow.Writer.pas',
  JsonFlow.Types in '..\..\Source\Dependencies\JsonFlow\Source\Core\JsonFlow.Types.pas',
  JsonFlow in '..\..\Source\Dependencies\JsonFlow\Source\JsonFlow.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm4, Form4);
  Application.Run;
end.
