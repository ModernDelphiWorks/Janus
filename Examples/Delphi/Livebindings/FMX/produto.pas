// ============================================================
// FMX MIGRATION NOTE (R22.5 / 2026-04-26)
// ------------------------------------------------------------
// Este exemplo ainda usa o engine legado (TJanusLiveBindings +
// Janus.FMX.Controls). Os símbolos legados foram marcados como
// deprecated no R22.4 e serão removidos no R22.6.
//
// A migração completa para TJanusBinder em FMX requer suporte
// a unidades FMX condicionais em Janus.Binder.pas, previsto para
// um ciclo futuro. Consulte o exemplo VCL migrado em:
//   Examples/Delphi/Livebindings/VCL/
// e o guia em:
//   docs-src/docs/janus/user/guides/livebindings.md
// ============================================================
unit produto;

interface

uses
  Janus.LiveBindings;

type
  TProduto = class(TJanusLiveBindings)
  private
    FID: Integer;
    FPreco: Double;
    FSoma: Double;
    procedure SetPreco(const Value: Double);
    procedure SetID(const Value: Integer);
  public
    [LiveBindingsControl('EditID', 'Text')]
    [LiveBindingsControl('LabelID', 'Text')]
    [LiveBindingsControl('ComboEditID', 'ItemIndex')]
    [LiveBindingsControl('ProgressBarID', 'Value')]
    [LiveBindingsControl('SpinBoxID', 'Value')]
    [LiveBindingsControl('NumberBoxID', 'Value')]
    property ID: Integer read FID write SetID;

    [LiveBindingsControl('EditPreco', 'Text')]
    [LiveBindingsControl('LabelPreco', 'Text')]
    property Preco: Double read FPreco write SetPreco;

    // N�o precisa do m�todo SET, porque ser� populado internamente pelo
    // livebindings, com a express�o matem�tica definida no par�metro.
    [LiveBindingsControl('EditSoma', 'Text', 'TProduto.ID * TProduto.Preco')]
    property Soma: Double read FSoma write FSoma;
  end;

implementation

uses
  Bindings.Helper;

{ TProduto }

procedure TProduto.SetID(const Value: Integer);
begin
  FID := Value;
  TBindings.Notify(Self, 'ID');
end;

procedure TProduto.SetPreco(const Value: Double);
begin
  FPreco := Value;
  TBindings.Notify(Self, 'Preco');
end;

end.
