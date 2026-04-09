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
  Janus.Types.Nullable,
  MetaDbDiff.Types.Mapping,
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
    /// NIVEL 3
    FProcedimento: TProcedimento;
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

    /// NIVEL 3
    [Association(TMultiplicity.OneToOne,'MNEMONICO','PROCEDIMENTOS','MNEMONICO')]
    property Procedimento: TProcedimento read FProcedimento write FProcedimento;
  end;

implementation

constructor TExame.Create;
begin
  FProcedimento := TProcedimento.Create;
end;

destructor TExame.Destroy;
begin
  FProcedimento.Free;
  inherited;
end;

initialization
  TRegisterClass.RegisterEntity(TExame)

end.

