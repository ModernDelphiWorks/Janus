unit Janus.Model.Detail;

interface

uses
  Classes, 
  DB, 
  SysUtils, 
  Generics.Collections, 
  /// orm 
  MetaDbDiff.mapping.attributes,
  MetaDbDiff.Types.Mapping,
  Janus.Types.Lazy,
  Janus.Types.Nullable,
  Janus.Model.Lookup,
  MetaDbDiff.Mapping.Register;

type
  [Entity]
  [Table('detail','')]
  [PrimaryKey('detail_id; master_id', 'Chave prim�ria')]
  [AggregateField('AGGPRICE', 'SUM(PRICE)', taRightJustify, '#,###,##0.00')]
  Tdetail = class
  private
    { Private declarations }
    Fdetail_id: Integer;
    Fmaster_id: Integer;
    Flookup_id: Integer;
    Flookup_description: String;
    Fprice: Double;
  public
    { Public declarations }
    [Restrictions([NoUpdate, NotNull])]
    [Column('detail_id', ftInteger)]
    [Dictionary('ID Detalhe','Mensagem de valida��o','','','',taCenter)]
    property detail_id: Integer read Fdetail_id write Fdetail_id;

    [Restrictions([NotNull])]
    [Column('master_id', ftInteger)]
    [ForeignKey('FK_IDMASTER', 'master_id', 'master', 'master_id', Cascade, Cascade)]
    [Dictionary('ID Mestre','Mensagem de valida��o','','','',taCenter)]
    property master_id: Integer read Fmaster_id write Fmaster_id;

    [Restrictions([NotNull])]
    [Column('lookup_id', ftInteger)]
    [ForeignKey('FK_IDLOOKUP', 'lookup_id', 'lookup', 'lookup_id', None, None)]
    [Dictionary('ID Lookup','Mensagem de valida��o','0','','',taCenter)]
    property lookup_id: Integer read Flookup_id write Flookup_id;

    [Column('lookup_description', ftString, 30)]
    [Dictionary('Descri��o Lookup','Mensagem de valida��o','','','',taLeftJustify)]
    property lookup_description: String read Flookup_description write Flookup_description;

    [Restrictions([NotNull])]
    [Column('price', ftFloat, 18, 3)]
    [Dictionary('Pre�o Unit�rio','Mensagem de valida��o','','#,###,##0.00','',taRightJustify)]
    property price: Double read Fprice write Fprice;
  end;

implementation

initialization
  TRegisterClass.RegisterEntity(Tdetail);

end.
