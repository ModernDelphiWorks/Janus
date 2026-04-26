unit Janus.Oracle.Model.Cliente;

interface

uses
  DB,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Attributes;

type
  [Entity]
  [Table('clientes', '')]
  [PrimaryKey('id_cliente', 'Client primary key')]
  TModelCliente = class
  private
    FIdCliente: Integer;
    FNome: String;
    FEmail: String;
    FCidade: String;
    FDataCadastro: TDate;
  public
    [Restrictions([NoUpdate, NotNull])]
    [Column('id_cliente', ftInteger)]
    property IdCliente: Integer read FIdCliente write FIdCliente;

    [Restrictions([NotNull])]
    [Column('nome', ftString, 100)]
    property Nome: String read FNome write FNome;

    [Column('email', ftString, 100)]
    property Email: String read FEmail write FEmail;

    [Column('cidade', ftString, 50)]
    property Cidade: String read FCidade write FCidade;

    [Column('data_cadastro', ftDate)]
    property DataCadastro: TDate read FDataCadastro write FDataCadastro;
  end;

implementation

end.
