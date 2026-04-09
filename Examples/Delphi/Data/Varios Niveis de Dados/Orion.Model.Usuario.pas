unit Orion.Model.Usuario;

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
  [Table('usuario', '')]
  [PrimaryKey('id', TAutoIncType.NotInc,
                    TGeneratorType.NoneInc,
                    TSortingOrder.NoSort,
                    False, 'Chave prim�ria')]
  Tusuario = class
  private
    { Private declarations } 
    Fid: Nullable<Integer>;
    Fnome: Nullable<String>;
    Flogin: Nullable<String>;
    Fsenha: Nullable<String>;
    Fdata_cadastro: Nullable<TDateTime>;
    Fdata_alteracao: Nullable<TDateTime>;
  public 
    { Public declarations } 
    [Column('id', ftInteger)]
    [Dictionary('id', 'Mensagem de valida��o', '', '', '', taCenter)]
    property id: Nullable<Integer> read Fid write Fid;

    [Column('nome', ftString, 50)]
    [Dictionary('nome', 'Mensagem de valida��o', '', '', '', taLeftJustify)]
    property nome: Nullable<String> read Fnome write Fnome;

    [Column('login', ftString, 30)]
    [Dictionary('login', 'Mensagem de valida��o', '', '', '', taLeftJustify)]
    property login: Nullable<String> read Flogin write Flogin;

    [Column('senha', ftString, 10)]
    [Dictionary('senha', 'Mensagem de valida��o', '', '', '', taLeftJustify)]
    property senha: Nullable<String> read Fsenha write Fsenha;

    [Column('data_cadastro', ftDateTime)]
    [Dictionary('data_cadastro', 'Mensagem de valida��o', '', '', '', taCenter)]
    property data_cadastro: Nullable<TDateTime> read Fdata_cadastro write Fdata_cadastro;

    [Column('data_alteracao', ftDateTime)]
    [Dictionary('data_alteracao', 'Mensagem de valida��o', '', '', '', taCenter)]
    property data_alteracao: Nullable<TDateTime> read Fdata_alteracao write Fdata_alteracao;
  end;

implementation

initialization

  TRegisterClass.RegisterEntity(Tusuario)

end.

