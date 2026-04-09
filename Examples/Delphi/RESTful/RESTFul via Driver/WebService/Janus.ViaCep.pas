unit Janus.ViaCep;

interface

uses
  Classes,
  DB,
  SysUtils,

  MetaDbDiff.mapping.attributes,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Register;

type
  [Entity]
  [Table('Endereco', '')]
  TEndereco = class (TObject)
  private
    FCep: String;
    FLogradouro: String;
    FComplemento: String;
    FBairro: String;
    FLocalidade: String;
    FUF: String;
    FUnidade: String;
    FIBGE: String;
    FGia: String;
  public
    [Column('Cep', ftString, 9)]
    [Dictionary('Cep','Mensagem de valida��o','','','',taCenter)]
    property Cep: String read FCep write FCep;

    [Column('Logradouro', ftString, 60)]
    [Dictionary('Endere�o','Mensagem de valida��o','','','',taLeftJustify)]
    property Logradouro: String read FLogradouro write FLogradouro;

    [Column('Complemento', ftString, 60)]
    [Dictionary('Complemento','Mensagem de valida��o','','','',taLeftJustify)]
    property Complemento: String read FComplemento write FComplemento;

    [Column('Bairro', ftString, 40)]
    [Dictionary('Bairro','Mensagem de valida��o','','','',taLeftJustify)]
    property Bairro: String read FBairro write FBairro;

    [Column('Localidade', ftString, 40)]
    [Dictionary('Cidade','Mensagem de valida��o','','','',taLeftJustify)]
    property Localidade: String read FLocalidade write FLocalidade;

    [Column('UF', ftString, 2)]
    [Dictionary('UF','Mensagem de valida��o','','','',taCenter)]
    property UF: String read FUF write FUF;

    [Column('Unidade', ftString, 10)]
    [Dictionary('Unidade','Mensagem de valida��o','','','',taCenter)]
    property Unidade: String read FUnidade write FUnidade;

    [Column('IBGE', ftString, 10)]
    [Dictionary('IBGE','Mensagem de valida��o','','','',taCenter)]
    property IBGE: String read FIBGE write FIBGE;

    [Column('Gia', ftString, 10)]
    [Dictionary('Gia','Mensagem de valida��o','','','',taCenter)]
    property Gia: String read FGia write FGia;
  end;

implementation

end.
