program JanusGeneratorModel;



uses
  Forms,
  Frm_Principal in 'Frm_Principal.pas' {FrmPrincipal},
  Frm_Connection in 'Frm_Connection.pas' {FrmConnection},
  Janus.CodeGen.Types in '..\..\Source\CodeGen\Janus.CodeGen.Types.pas',
  Janus.CodeGen.Schema in '..\..\Source\CodeGen\Janus.CodeGen.Schema.pas',
  Janus.CodeGen.Template in '..\..\Source\CodeGen\Janus.CodeGen.Template.pas',
  Janus.CodeGen.Options in '..\..\Source\CodeGen\Janus.CodeGen.Options.pas',
  Janus.CodeGen.Engine in '..\..\Source\CodeGen\Janus.CodeGen.Engine.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFrmPrincipal, FrmPrincipal);
  Application.Run;
end.
