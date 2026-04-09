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
