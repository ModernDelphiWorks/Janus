unit Orion.Model.RedeSocialContato;

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
  [Table('redesocialcontato', '')]
  [PrimaryKey('id', TAutoIncType.NotInc,
                    TGeneratorType.NoneInc,
                    TSortingOrder.NoSort,
                    False, 'Chave prim�ria')]
  Tredesocialcontato = class
  private
    { Private declarations } 
    Fid: Nullable<Integer>;
    Ftipo: Nullable<String>;
    Fnome_rede: Nullable<String>;
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

    [Column('nome_rede', ftString, 100)]
    [Dictionary('nome_rede', 'Mensagem de valida��o', '', '', '', taLeftJustify)]
    property nome_rede: Nullable<String> read Fnome_rede write Fnome_rede;

    [Column('contato_id', ftInteger)]
    [ForeignKey('fk_redesocialcontato_contato', 'contato_id', 'contato', 'id', TRuleAction.Cascade, TRuleAction.Cascade)]
    [Dictionary('contato_id', 'Mensagem de valida��o', '', '', '', taCenter)]
    property contato_id: Nullable<Integer> read Fcontato_id write Fcontato_id;
  end;

implementation

constructor Tredesocialcontato.Create;
begin

end;

destructor Tredesocialcontato.Destroy;
begin

  inherited;
end;

initialization

  TRegisterClass.RegisterEntity(Tredesocialcontato)

end.

