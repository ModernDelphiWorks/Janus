unit Orion.Model.EmailContato;

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
  [Table('emailcontato', '')]
  [PrimaryKey('id', TAutoIncType.NotInc,
                    TGeneratorType.NoneInc,
                    TSortingOrder.NoSort,
                    False, 'Chave prim�ria')]
  Temailcontato = class
  private
    { Private declarations } 
    Fid: Nullable<Integer>;
    Ftipo: Nullable<String>;
    Fendereco: Nullable<String>;
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

    [Column('endereco', ftString, 150)]
    [Dictionary('endereco', 'Mensagem de valida��o', '', '', '', taLeftJustify)]
    property endereco: Nullable<String> read Fendereco write Fendereco;

    [Column('contato_id', ftInteger)]
    [ForeignKey('fk_emailcontato_contato', 'contato_id', 'contato', 'id', TRuleAction.Cascade, TRuleAction.Cascade)]
    [Dictionary('contato_id', 'Mensagem de valida��o', '', '', '', taCenter)]
    property contato_id: Nullable<Integer> read Fcontato_id write Fcontato_id;
  end;

implementation

constructor Temailcontato.Create;
begin

end;

destructor Temailcontato.Destroy;
begin

  inherited;
end;

initialization

  TRegisterClass.RegisterEntity(Temailcontato)

end.

