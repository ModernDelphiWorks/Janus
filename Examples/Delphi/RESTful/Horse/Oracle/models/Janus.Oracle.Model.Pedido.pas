unit Janus.Oracle.Model.Pedido;

interface

uses
  DB,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Attributes;

type
  [Entity]
  [Table('pedidos', '')]
  [PrimaryKey('id_pedido', 'Order primary key')]
  TModelPedido = class
  private
    FIdPedido: Integer;
    FIdCliente: Integer;
    FIdProduto: Integer;
    FQuantidade: Integer;
    FValorTotal: Double;
    FDataPedido: TDate;
  public
    [Restrictions([NoUpdate, NotNull])]
    [Column('id_pedido', ftInteger)]
    property IdPedido: Integer read FIdPedido write FIdPedido;

    [Restrictions([NotNull])]
    [Column('id_cliente', ftInteger)]
    [ForeignKey('FK_PED_CLI', 'id_cliente', 'clientes', 'id_cliente')]
    property IdCliente: Integer read FIdCliente write FIdCliente;

    [Restrictions([NotNull])]
    [Column('id_produto', ftInteger)]
    [ForeignKey('FK_PED_PRO', 'id_produto', 'produtos', 'id_produto')]
    property IdProduto: Integer read FIdProduto write FIdProduto;

    [Restrictions([NotNull])]
    [Column('quantidade', ftInteger)]
    property Quantidade: Integer read FQuantidade write FQuantidade;

    [Restrictions([NotNull])]
    [Column('valor_total', ftFloat)]
    property ValorTotal: Double read FValorTotal write FValorTotal;

    [Column('data_pedido', ftDate)]
    property DataPedido: TDate read FDataPedido write FDataPedido;
  end;

implementation

end.
