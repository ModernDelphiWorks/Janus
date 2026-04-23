unit JanusRESTHorseConsole.Models;

interface

uses
  DB,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Attributes;

type
  // No REST attribute — full CRUD allowed
  [Entity]
  [Table('demo_product', '')]
  [PrimaryKey('id', 'Primary key')]
  TDemoProduct = class
  private
    FId: Integer;
    FName: String;
    FPrice: Double;
  public
    [Restrictions([NoUpdate, NotNull])]
    [Column('id', ftInteger)]
    property Id: Integer read FId write FId;

    [Column('name', ftString, 100)]
    property Name: String read FName write FName;

    [Column('price', ftFloat)]
    property Price: Double read FPrice write FPrice;
  end;

  // RESTReadOnly — only GET allowed
  [Entity]
  [Table('demo_readonly', '')]
  [PrimaryKey('id', 'Primary key')]
  [RESTReadOnly]
  TDemoReadOnly = class
  private
    FId: Integer;
    FName: String;
  public
    [Restrictions([NoUpdate, NotNull])]
    [Column('id', ftInteger)]
    property Id: Integer read FId write FId;

    [Column('name', ftString, 100)]
    property Name: String read FName write FName;
  end;

  // RESTAllowGET — GET only via grant
  [Entity]
  [Table('demo_get_only', '')]
  [PrimaryKey('id', 'Primary key')]
  [RESTAllowGET]
  TDemoGetOnly = class
  private
    FId: Integer;
    FName: String;
  public
    [Restrictions([NoUpdate, NotNull])]
    [Column('id', ftInteger)]
    property Id: Integer read FId write FId;

    [Column('name', ftString, 100)]
    property Name: String read FName write FName;
  end;

  // RESTAllowGET + RESTAllowPOST — GET and POST allowed; PUT/DELETE blocked
  [Entity]
  [Table('demo_get_post', '')]
  [PrimaryKey('id', 'Primary key')]
  [RESTAllowGET]
  [RESTAllowPOST]
  TDemoGetPost = class
  private
    FId: Integer;
    FName: String;
  public
    [Restrictions([NoUpdate, NotNull])]
    [Column('id', ftInteger)]
    property Id: Integer read FId write FId;

    [Column('name', ftString, 100)]
    property Name: String read FName write FName;
  end;

implementation

end.
