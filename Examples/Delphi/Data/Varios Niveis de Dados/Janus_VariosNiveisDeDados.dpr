program Janus_VariosNiveisDeDados;

uses
  Vcl.Forms,
  Principal in 'Principal.pas' {Form1},
  Orion.Model.Cidade in 'Orion.Model.Cidade.pas',
  Orion.Model.Contato in 'Orion.Model.Contato.pas',
  Orion.Model.EmailContato in 'Orion.Model.EmailContato.pas',
  Orion.Model.Empresa in 'Orion.Model.Empresa.pas',
  Orion.Model.Estado in 'Orion.Model.Estado.pas',
  Orion.Model.RedeSocialContato in 'Orion.Model.RedeSocialContato.pas',
  Orion.Model.TelefoneContato in 'Orion.Model.TelefoneContato.pas',
  Orion.Model.Usuario in 'Orion.Model.Usuario.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

