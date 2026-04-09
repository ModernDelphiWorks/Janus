unit Janus.Model.Client;

interface

uses
  Classes, 
  DB, 
  SysUtils, 
  Generics.Collections, 
  /// orm 
  Janus.Types.Nullable,
  MetaDbDiff.mapping.attributes,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Register,
  Janus.Types.Blob,
  Janus.Model.Address;

type
  /// Mostrando como criar classe para o Janus para trabalhar com heran�a de
  /// classes
  TNome = class
  private
    Fclient_name: String;
  public
    [Column('client_name', ftString, 40)]
    [Dictionary('client_name','Mensagem de valida��o','','','',taLeftJustify)]
    property client_name: String read Fclient_name write Fclient_name;
  end;

  [Entity]
  [Table('client','')]
  [PrimaryKey('client_id', 'Chave prim�ria')]
  [Indexe('idx_client_name','client_name')]
  [OrderBy('client_id Desc')]
  Tclient = class(TNome)
  private
    { Private declarations }
    Fclient_id: Integer;
    Faddress: TObjectList<Taddress>;
//    Faddress: Taddress;
  public
    constructor Create;
    destructor Destroy; override;
    { Public declarations }
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('client_id', ftInteger)]
    [Dictionary('client_id','Mensagem de valida��o','','','',taCenter)]
    property client_id: Integer read Fclient_id write Fclient_id;

    [Restrictions([TRestriction.Hidden])]
    [Column('address', ftDataSet)]
    property address: TObjectList<Taddress> read Faddress write Faddress;
//    property address: Taddress read Faddress write Faddress;
  end;

implementation

{ Tclient }

constructor Tclient.Create;
begin
  Faddress := TObjectList<Taddress>.Create;
//  Faddress := Taddress.Create;
end;

destructor Tclient.Destroy;
begin
  Faddress.Free;
  inherited;
end;

initialization
  TRegisterClass.RegisterEntity(Tclient);

end.
