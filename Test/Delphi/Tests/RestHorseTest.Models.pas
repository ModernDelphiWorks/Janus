unit RestHorseTest.Models;

interface

uses
  DB,
  MetaDbDiff.Mapping.Attributes;

type
  // Standard read-write entity for CRUD integration tests
  [Entity]
  [Table('customer_test', '')]
  [PrimaryKey('id', 'Primary key')]
  TCustomerTest = class
  private
    FId: Integer;
    FName: String;
    FEmail: String;
    FActive: Boolean;
  public
    [Restrictions([NoUpdate, NotNull])]
    [Column('id', ftInteger)]
    property Id: Integer read FId write FId;

    [Column('name', ftString, 100)]
    property Name: String read FName write FName;

    [Column('email', ftString, 200)]
    property Email: String read FEmail write FEmail;

    [Column('active', ftBoolean)]
    property Active: Boolean read FActive write FActive;
  end;

  // Detail entity with foreign key to TCustomerTest
  [Entity]
  [Table('order_test', '')]
  [PrimaryKey('id', 'Primary key')]
  TOrderTest = class
  private
    FId: Integer;
    FCustomerId: Integer;
    FDescription: String;
    FTotal: Double;
  public
    [Restrictions([NoUpdate, NotNull])]
    [Column('id', ftInteger)]
    property Id: Integer read FId write FId;

    [Column('customer_id', ftInteger)]
    [ForeignKey('fk_order_customer', 'TCustomerTest', 'id', 'customer_id')]
    property CustomerId: Integer read FCustomerId write FCustomerId;

    [Column('description', ftString, 200)]
    property Description: String read FDescription write FDescription;

    [Column('total', ftFloat)]
    property Total: Double read FTotal write FTotal;
  end;

  // Read-only entity (RESTReadOnly attribute)
  [Entity]
  [Table('product_test', '')]
  [PrimaryKey('id', 'Primary key')]
  [RESTReadOnly]
  TProductTest = class
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

  // View entity — read-only by nature (ADR-002 + ADR-003)
  [Entity]
  [View('customer_order_summary', '')]
  [Table('customer_order_summary', '')]
  TCustomerOrderSummary = class
  private
    FCustomerId: Integer;
    FCustomerName: String;
    FOrderCount: Integer;
    FTotalAmount: Double;
  public
    [Column('customer_id', ftInteger)]
    property CustomerId: Integer read FCustomerId write FCustomerId;

    [Column('customer_name', ftString, 100)]
    property CustomerName: String read FCustomerName write FCustomerName;

    [Column('order_count', ftInteger)]
    property OrderCount: Integer read FOrderCount write FOrderCount;

    [Column('total_amount', ftFloat)]
    property TotalAmount: Double read FTotalAmount write FTotalAmount;
  end;

implementation

end.
