program Janus_LivebindingsVCL;

uses
  Vcl.Forms,
  UPrincipal in 'UPrincipal.pas' {FormPrincipal},
  produto in 'produto.pas',
  Janus.Binder.Attributes in '..\..\..\Source\Livebindings\Janus.Binder.Attributes.pas',
  Janus.Binder in '..\..\..\Source\Livebindings\Janus.Binder.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFormPrincipal, FormPrincipal);
  Application.Run;
end.
