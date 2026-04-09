unit Janus.Model.Detail;

interface

uses
  Classes, 
  DB, 
  SysUtils, 
  Generics.Collections, 
  /// orm 
  Janus.Model.Lookup,
  Janus.Types.Lazy,
  Janus.Types.Nullable,
  MetaDbDiff.mapping.attributes,
  MetaDbDiff.Types.Mapping,
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
    FVisto: Boolean;
  public
    { Public declarations }
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('detail_id', ftInteger)]
    [Dictionary('ID Detalhe','Mensagem de valida��o','','','',taCenter)]
    property detail_id: Integer read Fdetail_id write Fdetail_id;

    [Restrictions([TRestriction.NotNull])]
    [Column('master_id', ftInteger)]
    [ForeignKey('FK_IDMASTER', 'master_id', 'master', 'master_id', TRuleAction.Cascade, TRuleAction.Cascade)]
    [Dictionary('ID Mestre','Mensagem de valida��o','','','',taCenter)]
    property master_id: Integer read Fmaster_id write Fmaster_id;

    [Restrictions([TRestriction.NotNull])]
    [Column('lookup_id', ftInteger)]
    [ForeignKey('FK_IDLOOKUP', 'lookup_id', 'lookup', 'lookup_id', TRuleAction.None,  TRuleAction.None)]
    [Dictionary('ID Lookup','Mensagem de valida��o','0','','',taCenter)]
    property lookup_id: Integer read Flookup_id write Flookup_id;

    [Column('lookup_description', ftString, 30)]
    [Dictionary('Descri��o Lookup','Mensagem de valida��o','','','',taLeftJustify)]
    property lookup_description: String read Flookup_description write Flookup_description;

    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('price', ftFloat, 18, 3)]
    [Dictionary('Pre�o Unit�rio','Mensagem de valida��o','','#,###,##0.00','',taRightJustify)]
    property price: Double read Fprice write Fprice;

    [Restrictions([TRestriction.NoUpdate, TRestriction.NoInsert, TRestriction.VirtualData])]
    [Column('Visto', ftBoolean)]
    [Dictionary('Virtual','Mensagem de valida��o','','','',taRightJustify)]
    property Visto: Boolean read FVisto write FVisto;
  end;

implementation

initialization
  TRegisterClass.RegisterEntity(Tdetail);

end.
