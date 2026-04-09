unit Orion.Model.Estado;

interface

uses
  DB, 
  Classes, 
  SysUtils, 
  Generics.Collections, 

  /// orm
  Orion.Model.Cidade,
  Janus.Types.Blob,
  Janus.Types.Lazy, 
  MetaDbDiff.Types.Mapping,
  Janus.Types.Nullable,
  MetaDbDiff.mapping.classes,
  MetaDbDiff.Mapping.Register,
  MetaDbDiff.mapping.attributes;

type
  [Entity]
  [Table('estado', '')]
  [PrimaryKey('id', TAutoIncType.NotInc,
                    TGeneratorType.NoneInc,
                    TSortingOrder.NoSort,
                    False, 'Chave prim�ria')]
  Testado = class
  private
    { Private declarations } 
    Fid: Nullable<String>;
    Fnome: Nullable<String>;
    Fsigla: Nullable<String>;
    Fregiao: Nullable<String>;
    Ficms_interestadual: Nullable<Double>;
    FCidades: TObjectList<Tcidade>;
  public
    constructor Create;
    destructor Destroy; override;

    { Public declarations } 
    [Column('id', ftString, 2)]
    [Dictionary('id', 'Mensagem de valida��o', '', '', '', taLeftJustify)]
    property id: Nullable<String> read Fid write Fid;

    [Column('nome', ftString, 60)]
    [Dictionary('nome', 'Mensagem de valida��o', '', '', '', taLeftJustify)]
    property nome: Nullable<String> read Fnome write Fnome;

    [Column('sigla', ftString, 2)]
    [Dictionary('sigla', 'Mensagem de valida��o', '', '', '', taLeftJustify)]
    property sigla: Nullable<String> read Fsigla write Fsigla;

    [Column('regiao', ftString, 1)]
    [Dictionary('regiao', 'Mensagem de valida��o', '', '', '', taLeftJustify)]
    property regiao: Nullable<String> read Fregiao write Fregiao;

    [Column('icms_interestadual', ftBCD, 8, 4)]
    [Dictionary('icms_interestadual', 'Mensagem de valida��o', '0', '', '', taRightJustify)]
    property icms_interestadual: Nullable<Double> read Ficms_interestadual write Ficms_interestadual;

//    [Association(OneToMany, 'id', 'cidade', 'estado_id')]
//    [CascadeActions([CascadeAutoInc, CascadeInsert, CascadeUpdate, CascadeDelete])]
//    property Cidades: TObjectList<Tcidade> read FCidades write FCidades;
  end;

implementation

{ Testado }

constructor Testado.Create;
begin
  //FCidades := TObjectList<Tcidade>.Create;
end;

destructor Testado.Destroy;
begin
  if Assigned(FCidades) then
    //FCidades.Free;
  inherited;
end;

initialization

  TRegisterClass.RegisterEntity(Testado)

end.

