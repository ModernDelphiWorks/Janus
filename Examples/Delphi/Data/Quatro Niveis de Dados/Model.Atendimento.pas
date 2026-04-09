unit Model.Atendimento;

interface

uses
  DB,
  Classes,
  SysUtils,
  Generics.Collections,
  /// Units Associadas
  Model.Exame,
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
  [Table('ATENDIMENTOS', '')]
  [PrimaryKey('POSTO', TAutoIncType.AutoInc,
                       TGeneratorType.NoneInc,
                       TSortingOrder.NoSort,
                       False, 'Chave prim�ria')]
  [Sequence('ATENDIMENTOS')]
  TAtendimento = class
  private
    { Private declarations }
    FPosto: Integer;
    FAtendimento: Integer;
    /// NIVEL 2
    FExames: TObjectList<TExame>;
  public
    { Public declarations }
    constructor Create;
    destructor Destroy; override;

    [Restrictions([TRestriction.NotNull])]
    [Column('POSTO', ftInteger)]
    [Dictionary('POSTO', 'Mensagem de valida��o', '', '', '', taCenter)]
    property Posto: Integer read FPosto write FPosto;

    [Restrictions([TRestriction.NotNull])]
    [Column('ATENDIMENTO', ftInteger)]
    [Dictionary('ATENDIMENTO', 'Mensagem de valida��o', '', '', '', taCenter)]
    property Atendimento: Integer read FAtendimento write FAtendimento;

    /// NIVEL 2
    [Association(TMultiplicity.OneToMany,'POSTO','EXAMES','POSTO')]
    [CascadeActions([TCascadeAction.CascadeAutoInc,
                     TCascadeAction.CascadeInsert,
                     TCascadeAction.CascadeUpdate,
                     TCascadeAction.CascadeDelete])]
    [Dictionary('Exame do Atendimento')]
    property Exames: TObjectList<TExame> read FExames write FExames;
  end;

implementation

constructor TAtendimento.Create;
begin
  FExames := TObjectList<TExame>.Create;
end;

destructor TAtendimento.Destroy;
begin
  FExames.Free;
  inherited;
end;

initialization
  TRegisterClass.RegisterEntity(TAtendimento)

end.
