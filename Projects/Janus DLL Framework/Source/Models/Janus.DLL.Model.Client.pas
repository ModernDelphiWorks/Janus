unit Janus.DLL.Model.Client;

interface

uses
  Classes,
  DB,
  MetaDbDiff.mapping.attributes,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Register;

type
  [Entity]
  [Table('client', '')]
  [PrimaryKey('client_id', AutoInc, NoSort, False, 'Chave prim�ria')]
  [OrderBy('client_id')]
  TClientModel = class
  private
    Fclient_id: Integer;
    Fclient_name: String;
    Fclient_email: String;
  public
    [Restrictions([NoUpdate, NotNull])]
    [Column('client_id', ftInteger)]
    property client_id: Integer read Fclient_id write Fclient_id;

    [Column('client_name', ftString, 60)]
    property client_name: String read Fclient_name write Fclient_name;

    [Column('client_email', ftString, 100)]
    property client_email: String read Fclient_email write Fclient_email;
  end;

implementation

initialization
  TRegisterClass.RegisterEntity(TClientModel);

end.
