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
  Janus.Types.Nullable,
  MetaDbDiff.Types.Mapping,
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
    FSETOR: Integer;
    /// NIVEL 4
    FSetoresList: TObjectList<TSetor>;
  public
    { Public declarations }
    constructor Create;
    destructor Destroy; override;

    [Restrictions([TRestriction.NotNull])]
    [Column('PROCEDIMENTO', ftInteger)]
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
    property SETOR: Integer read FSETOR write FSETOR;

    /// NIVEL 4
    [Association(TMultiplicity.OneToMany,'SETOR','SETORES','SETOR',False)]
    property SetoresList: TObjectList<TSetor> read FSetoresList;
  end;

implementation

constructor TProcedimento.Create;
begin
  FSetoresList := TObjectList<TSetor>.Create;
end;

destructor TProcedimento.Destroy;
begin
  FSetoresList.Free;
  inherited;
end;

initialization
  TRegisterClass.RegisterEntity(TProcedimento)

end.


