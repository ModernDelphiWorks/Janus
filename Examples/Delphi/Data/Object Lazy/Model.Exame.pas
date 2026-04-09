unit Model.Exame;

interface

uses
  DB,
  Classes,
  SysUtils,
  Generics.Collections,
  /// Units Associadas
  Model.Procedimento,
  /// orm
  Janus.Types.Blob,
  Janus.Types.Lazy,
  MetaDbDiff.Types.Mapping,
  Janus.Types.Nullable,
  MetaDbDiff.mapping.classes,
  MetaDbDiff.Mapping.Register,
  MetaDbDiff.mapping.attributes;

type
  [Entity]
  [Table('EXAMES', '')]
  [PrimaryKey('POSTO;ATENDIMENTO;CORREL', TAutoIncType.NotInc,
                                          TGeneratorType.NoneInc,
                                          TSortingOrder.NoSort,
                                          False, 'Chave prim�ria')]
  TExame = class
  private
    { Private declarations }
    FPosto: Integer;
    FAtendimento: Integer;
    FCorrel: Integer;
    FMNEMONICO: String;
    FProcedimento: Lazy<TProcedimento>;
    function GetProcedimento: TProcedimento;
  public
    { Public declarations }
    constructor Create;
    destructor Destroy; override;

    [Restrictions([TRestriction.NotNull])]
    [Column('POSTO', ftInteger)]
    [ForeignKey('EXAMES_ATENDIMENTOS_FK', 'POSTO;ATENDIMENTO', 'ATENDIMENTOS', 'POSTO;ATENDIMENTO', TRuleAction.Cascade, TRuleAction.SetNull)]
    [Dictionary('POSTO', 'Mensagem de valida��o', '', '', '', taCenter)]
    property Posto: Integer read FPosto write FPosto;

    [Restrictions([TRestriction.NotNull])]
    [Column('ATENDIMENTO', ftInteger)]
    [Dictionary('ATENDIMENTO', 'Mensagem de valida��o', '', '', '', taCenter)]
    property Atendimento: Integer read FAtendimento write FAtendimento;

    [Restrictions([TRestriction.NotNull])]
    [Column('CORREL', ftInteger)]
    [Dictionary('CORREL', 'Mensagem de valida��o', '', '', '', taCenter)]
    property Correl: Integer read FCorrel write FCorrel;

    [Restrictions([TRestriction.NotNull])]
    [Column('MNEMONICO', ftString, 7)]
    [Dictionary('MNEMONICO', 'Mensagem de valida��o', '', '', '', taLeftJustify)]
    property MNEMONICO: String read FMNEMONICO write FMNEMONICO;

    [Association(TMultiplicity.OneToOne,'MNEMONICO','PROCEDIMENTOS','MNEMONICO',True)]
    property Procedimento: TProcedimento read GetProcedimento;
  end;

implementation

constructor TExame.Create;
begin

end;

destructor TExame.Destroy;
begin

  inherited;
end;

function TExame.GetProcedimento: TProcedimento;
begin
  Result := FProcedimento.Value;
end;

initialization
  TRegisterClass.RegisterEntity(TExame)

end.

