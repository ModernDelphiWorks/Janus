program Janus_LivebindingsVCL;

uses
  Vcl.Forms,
  UPrincipal in 'UPrincipal.pas' {FormPrincipal},
  produto in 'produto.pas',
  Janus.Controls.Helpers in '..\..\..\Source\Livebindings\Janus.Controls.Helpers.pas',
  Janus.LiveBindings in '..\..\..\Source\Livebindings\Janus.LiveBindings.pas',
  Janus.VCL.Controls in '..\..\..\Source\Livebindings\Janus.VCL.Controls.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFormPrincipal, FormPrincipal);
  Application.Run;
end.
