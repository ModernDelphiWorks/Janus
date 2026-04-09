unit Orion.Model.TelefoneContato;

interface

uses
  DB, 
  Classes, 
  SysUtils, 
  Generics.Collections, 

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
  [Table('telefonecontato', '')]
  [PrimaryKey('id', TAutoIncType.NotInc,
                    TGeneratorType.NoneInc,
                    TSortingOrder.NoSort,
                    False, 'Chave prim�ria')]
  Ttelefonecontato = class
  private
    { Private declarations } 
    Fid: Nullable<Integer>;
    Ftipo: Nullable<String>;
    Fnumero: Nullable<String>;
    Framal: Nullable<String>;
    Fcontato_id: Nullable<Integer>;
  public
    { Public declarations } 
    constructor Create;
    destructor Destroy; override;
    [Column('id', ftInteger)]
    [Dictionary('id', 'Mensagem de valida��o', '', '', '', taCenter)]
    property id: Nullable<Integer> read Fid write Fid;

    [Column('tipo', ftString, 1)]
    [Dictionary('tipo', 'Mensagem de valida��o', '', '', '', taLeftJustify)]
    property tipo: Nullable<String> read Ftipo write Ftipo;

    [Column('numero', ftString, 15)]
    [Dictionary('numero', 'Mensagem de valida��o', '', '', '', taLeftJustify)]
    property numero: Nullable<String> read Fnumero write Fnumero;

    [Column('ramal', ftString, 10)]
    [Dictionary('ramal', 'Mensagem de valida��o', '', '', '', taLeftJustify)]
    property ramal: Nullable<String> read Framal write Framal;

    [Column('contato_id', ftInteger)]
    [ForeignKey('fk_telefonecontato_contato', 'contato_id', 'contato', 'id', TRuleAction.Cascade, TRuleAction.Cascade)]
    [Dictionary('contato_id', 'Mensagem de valida��o', '', '', '', taCenter)]
    property contato_id: Nullable<Integer> read Fcontato_id write Fcontato_id;
  end;

implementation

constructor Ttelefonecontato.Create;
begin

end;

destructor Ttelefonecontato.Destroy;
begin

  inherited;
end;

initialization

  TRegisterClass.RegisterEntity(Ttelefonecontato)

end.

