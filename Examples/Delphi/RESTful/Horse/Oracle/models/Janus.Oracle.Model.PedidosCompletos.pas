unit Janus.Oracle.Model.PedidosCompletos;

interface

uses
  DB,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Attributes;

type
  [Entity]
  [View('vw_pedidos_completos', '')]
  [Table('vw_pedidos_completos', '')]
  [PrimaryKey('id_pedido', 'Order identifier in view')]
  [RESTReadOnly]
  TModelPedidosCompletos = class
  private
    FIdPedido: Integer;
    FDataPedido: TDate;
    FIdCliente: Integer;
    FClienteNome: String;
    FClienteCidade: String;
    FIdProduto: Integer;
    FProdutoDescricao: String;
    FProdutoCategoria: String;
    FProdutoPreco: Double;
    FQuantidade: Integer;
    FValorTotal: Double;
  public
    [Restrictions([NoUpdate, NotNull])]
    [Column('id_pedido', ftInteger)]
    property IdPedido: Integer read FIdPedido write FIdPedido;

    [Column('data_pedido', ftDate)]
    property DataPedido: TDate read FDataPedido write FDataPedido;

    [Column('id_cliente', ftInteger)]
    property IdCliente: Integer read FIdCliente write FIdCliente;

    [Column('cliente_nome', ftString, 100)]
    property ClienteNome: String read FClienteNome write FClienteNome;

    [Column('cliente_cidade', ftString, 50)]
    property ClienteCidade: String read FClienteCidade write FClienteCidade;

    [Column('id_produto', ftInteger)]
    property IdProduto: Integer read FIdProduto write FIdProduto;

    [Column('produto_descricao', ftString, 200)]
    property ProdutoDescricao: String read FProdutoDescricao write FProdutoDescricao;

    [Column('produto_categoria', ftString, 50)]
    property ProdutoCategoria: String read FProdutoCategoria write FProdutoCategoria;

    [Column('produto_preco', ftFloat)]
    property ProdutoPreco: Double read FProdutoPreco write FProdutoPreco;

    [Column('quantidade', ftInteger)]
    property Quantidade: Integer read FQuantidade write FQuantidade;

    [Column('valor_total', ftFloat)]
    property ValorTotal: Double read FValorTotal write FValorTotal;
  end;

implementation

end.
