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
  MetaDbDiff.Types.Mapping,
  Janus.Types.Nullable,
  MetaDbDiff.mapping.classes,
  MetaDbDiff.Mapping.Register,
  MetaDbDiff.mapping.attributes;
type
  [Entity]
  [Table('ATENDIMENTOS', '')]
  [PrimaryKey('POSTO; ATENDIMENTO', TAutoIncType.NotInc,
                                    TGeneratorType.NoneInc,
                                    TSortingOrder.NoSort,
                                    False, 'Chave prim�ria')]
  TAtendimento = class
  private
    { Private declarations }
    FPosto: Integer;
    FAtendimento: Integer;
//    FDataAtd: TDateTime;
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

    [Association(TMultiplicity.OneToMany,'POSTO;ATENDIMENTO','EXAMES','POSTO;ATENDIMENTO')]
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
