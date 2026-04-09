unit uFrameLista;

interface

uses
  Generics.Collections,
  Generics.Defaults,

  Windows,
  Messages,
  SysUtils,
  Variants,
  Classes,
  Graphics,
  Controls,
  Forms,
  Dialogs,
  Buttons,
  ExtCtrls,
  StdCtrls,
  ComCtrls;

type
  TPacotes = TList<TCheckBox>;

  TframePacotes = class(TFrame)
    pnlBotoesMarcar: TPanel;
    btnPacotesDesmarcarTodos: TSpeedButton;
    btnPacotesMarcarTodos: TSpeedButton;
    ScrollBox1: TScrollBox;
    Label6: TLabel;
    Bevel2: TBevel;
    DataEngineConnectionMongoWire_dpk: TCheckBox;
    Label13: TLabel;
    Label1: TLabel;
    JanusLibrary_dpk: TCheckBox;
    Label2: TLabel;
    Label3: TLabel;
    Label7: TLabel;
    Bevel1: TBevel;
    JanusDriversLinks_dpk: TCheckBox;
    Label8: TLabel;
    Label9: TLabel;
    Label10: TLabel;
    DataEngineConnectionFireDAC_dpk: TCheckBox;
    Label11: TLabel;
    Label12: TLabel;
    DataEngineConnectionDBExpress_dpk: TCheckBox;
    Label15: TLabel;
    Label16: TLabel;
    DataEngineConnectionZeos_dpk: TCheckBox;
    Label17: TLabel;
    Label18: TLabel;
    Label14: TLabel;
    Label19: TLabel;
    DataEngineConnectionUniDAC_dpk: TCheckBox;
    Label20: TLabel;
    Label21: TLabel;
    DataEngineConnectionFIBPlus_dpk: TCheckBox;
    Label22: TLabel;
    Label23: TLabel;
    DataEngineConnectionSQLDirect_dpk: TCheckBox;
    Label24: TLabel;
    Label25: TLabel;
    DataEngineConnectionIBObjects_dpk: TCheckBox;
    Label26: TLabel;
    Label27: TLabel;
    DataEngineConnectionNexusDB_dpk: TCheckBox;
    Label28: TLabel;
    Label29: TLabel;
    DataEngineConnectionADO_dpk: TCheckBox;
    Label4: TLabel;
    Label5: TLabel;
    JanusCore_dpk: TCheckBox;
    Label30: TLabel;
    Label31: TLabel;
    DataEngineCore_dpk: TCheckBox;
    Bevel3: TBevel;
    JanusManagerClientDataSet_dpk: TCheckBox;
    Label33: TLabel;
    Label34: TLabel;
    Label35: TLabel;
    Bevel5: TBevel;
    Label36: TLabel;
    Label37: TLabel;
    JanusManagerFDMemTable_dpk: TCheckBox;
    Label38: TLabel;
    Label39: TLabel;
    JanusManagerObjectSet_dpk: TCheckBox;
    Label32: TLabel;
    Label40: TLabel;
    MetaDbDiffCore_dpk: TCheckBox;
    procedure btnPacotesMarcarTodosClick(Sender: TObject);
    procedure btnPacotesDesmarcarTodosClick(Sender: TObject);
    procedure VerificarCheckboxes(Sender: TObject);
  private
    FPacotes: TPacotes;
    FUtilizarBotoesMarcar: Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    property Pacotes: TPacotes read FPacotes write FPacotes;
  end;

implementation

uses
  StrUtils;

{$R *.dfm}

constructor TframePacotes.Create(AOwner: TComponent);
var
  I: Integer;
begin
  inherited;

  // variavel para controle do verificar checkboxes
  // utilizada para evitar estouro de pilha por conta da redundância
  // e também para que pacotes dependentes não atrapalhem a rotina
  FUtilizarBotoesMarcar := False;

  // lista de pacotes (checkboxes) disponiveis
  FPacotes := TPacotes.Create;

  // popular a lista de pacotes com os pacotes disponíveis
  // colocar todos os checkboxes disponíveis na lista
  FPacotes.Clear;
  for I := 0 to Self.ComponentCount - 1 do
  begin
    if Self.Components[I] is TCheckBox then
      if TCheckBox(Self.Components[I]).Tag = 0 then
         FPacotes.Add(TCheckBox(Self.Components[I]));
  end;
  FPacotes.Sort(TComparer<TCheckBox>.Construct(
      function(const Dpk1, Dpk2: TCheckBox): Integer
      begin
         Result := CompareStr( FormatFloat('0000', Dpk1.TabOrder), FormatFloat('0000', Dpk2.TabOrder) );
      end));
end;

destructor TframePacotes.Destroy;
begin
  FreeAndNil(FPacotes);

  inherited;
end;

// botão para marcar todos os checkboxes
procedure TframePacotes.btnPacotesMarcarTodosClick(Sender: TObject);
var
  I: Integer;
begin
  FUtilizarBotoesMarcar := True;
  try
    for I := 0 to Self.ComponentCount -1 do
    begin
      if Self.Components[I] is TCheckBox then
      begin
        if TCheckBox(Self.Components[I]).Enabled then
          TCheckBox(Self.Components[I]).Checked := True;
      end;
    end;
  finally
    FUtilizarBotoesMarcar := False;
    VerificarCheckboxes(Sender);
  end;
end;

// botão para desmarcar todos os checkboxes
procedure TframePacotes.btnPacotesDesmarcarTodosClick(Sender: TObject);
var
  I: Integer;
begin
  FUtilizarBotoesMarcar := True;
  try
    for I := 0 to Self.ComponentCount -1 do
    begin
      if Self.Components[I] is TCheckBox then
      begin
        if TCheckBox(Self.Components[I]).Enabled then
          TCheckBox(Self.Components[I]).Checked := False;
      end;
    end;
  finally
    FUtilizarBotoesMarcar := False;
    VerificarCheckboxes(Sender);
  end;
end;

// rotina de verificação de dependência e marcação dos pacotes base
procedure TframePacotes.VerificarCheckboxes(Sender: TObject);
begin
  if not FUtilizarBotoesMarcar then
  begin
    FUtilizarBotoesMarcar := True;
    try
    finally
      FUtilizarBotoesMarcar := False;
    end;
  end;
end;

end.
