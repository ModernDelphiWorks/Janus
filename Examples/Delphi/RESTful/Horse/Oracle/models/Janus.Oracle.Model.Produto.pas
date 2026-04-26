unit Janus.Oracle.Model.Produto;

interface

uses
  DB,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Attributes;

type
  [Entity]
  [Table('produtos', '')]
  [PrimaryKey('id_produto', 'Product primary key')]
  TModelProduto = class
  private
    FIdProduto: Integer;
    FDescricao: String;
    FPreco: Double;
    FCategoria: String;
  public
    [Restrictions([NoUpdate, NotNull])]
    [Column('id_produto', ftInteger)]
    property IdProduto: Integer read FIdProduto write FIdProduto;

    [Restrictions([NotNull])]
    [Column('descricao', ftString, 200)]
    property Descricao: String read FDescricao write FDescricao;

    [Restrictions([NotNull])]
    [Column('preco', ftFloat)]
    property Preco: Double read FPreco write FPreco;

    [Column('categoria', ftString, 50)]
    property Categoria: String read FCategoria write FCategoria;
  end;

implementation

end.
