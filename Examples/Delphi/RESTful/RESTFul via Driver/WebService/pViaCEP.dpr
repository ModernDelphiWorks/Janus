program pViaCEP;

uses
  Vcl.Forms,
  uPrincipal in 'uPrincipal.pas' {Form2},
  Janus.ViaCep in 'Janus.ViaCep.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.
