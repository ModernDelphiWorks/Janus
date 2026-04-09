unit Model.Procedimento;

interface

uses
  DB,
  Classes,
  SysUtils,
  Generics.Collections,
  /// Units Associadas
  Model.Setor,
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
  [Table('PROCEDIMENTOS', '')]
  [PrimaryKey('MNEMONICO', TAutoIncType.NotInc,
                           TGeneratorType.NoneInc,
                           TSortingOrder.NoSort,
                           False, 'Chave prim�ria')]
  TProcedimento = class
  private
    { Private declarations }
    FPROCEDIMENTO: Double;
    FNOME: String;
    FMNEMONICO: String;
    FSETOR: Nullable<Integer>;
    FSetoresList: Lazy<TObjectList<TSetor>>;
    function GetSetoresList: TObjectList<TSetor>;
  public
    { Public declarations }
    constructor Create;
    destructor Destroy; override;
    [Restrictions([TRestriction.NotNull])]
    [Column('PROCEDIMENTO', ftBCD, 8, 0)]
    [Dictionary('PROCEDIMENTO', 'Mensagem de valida��o', '0', '', '', taRightJustify)]
    property PROCEDIMENTO: Double read FPROCEDIMENTO write FPROCEDIMENTO;

    [Restrictions([TRestriction.NotNull])]
    [Column('NOME', ftString, 60)]
    [Dictionary('NOME', 'Mensagem de valida��o', '', '', '', taLeftJustify)]
    property NOME: String read FNOME write FNOME;

    [Restrictions([TRestriction.NotNull])]
    [Column('MNEMONICO', ftString, 7)]
    [Dictionary('MNEMONICO', 'Mensagem de valida��o', '', '', '', taLeftJustify)]
    property MNEMONICO: String read FMNEMONICO write FMNEMONICO;

    [Restrictions([TRestriction.NotNull])]
    [Column('SETOR', ftInteger)]
    [Dictionary('SETOR', 'Mensagem de valida��o', '', '', '', taCenter)]
    property SETOR: Nullable<Integer> read FSETOR write FSETOR;

    /// Lazy lista de objeto
    [Association(TMultiplicity.OneToMany,'SETOR','SETORES','SETOR',True)]
    property SetoresList: TObjectList<TSetor> read GetSetoresList;
  end;

implementation

constructor TProcedimento.Create;
begin

end;

destructor TProcedimento.Destroy;
begin
  inherited;
end;

function TProcedimento.GetSetoresList: TObjectList<TSetor>;
begin
  Result := FSetoresList.Value;
end;

initialization
  TRegisterClass.RegisterEntity(TProcedimento)

end.


