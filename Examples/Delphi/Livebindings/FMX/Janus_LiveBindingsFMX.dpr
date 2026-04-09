program Janus_LiveBindingsFMX;

uses
  System.StartUpCopy,
  FMX.Forms,
  UPrincipal in 'UPrincipal.pas' {FormPrincipal},
  produto in 'produto.pas',
  Janus.Controls.Helpers in '..\..\Source\Janus.Controls.Helpers.pas',
  Janus.FMX.Controls in '..\..\Source\Janus.FMX.Controls.pas',
  Janus.LiveBindings in '..\..\Source\Janus.LiveBindings.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFormPrincipal, FormPrincipal);
  Application.Run;
end.
