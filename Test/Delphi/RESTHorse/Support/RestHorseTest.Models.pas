{
  ------------------------------------------------------------------------------
  Janus
  Modern Object-Relational Mapping (ORM) framework for Delphi.

  SPDX-License-Identifier: MIT
  Copyright (c) 2016-2026 Isaque Pinheiro

  Licensed under the MIT License.
  See the LICENSE file in the project root for full license information.
  ------------------------------------------------------------------------------
}

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

unit RestHorseTest.Models;

interface

uses
  DB,
  MetaDbDiff.Types.Mapping,
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

  // Grant-list: GET only
  [Entity]
  [Table('grant_get_only_test', '')]
  [PrimaryKey('id', 'Primary key')]
  [RESTAllowGET]
  TGrantGETOnly = class
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

  // Grant-list: GET + POST
  [Entity]
  [Table('grant_get_post_test', '')]
  [PrimaryKey('id', 'Primary key')]
  [RESTAllowGET]
  [RESTAllowPOST]
  TGrantGETAndPOST = class
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

  // Grant-list: all four verbs allowed
  [Entity]
  [Table('grant_full_allow_test', '')]
  [PrimaryKey('id', 'Primary key')]
  [RESTAllowGET]
  [RESTAllowPOST]
  [RESTAllowPUT]
  [RESTAllowDELETE]
  TGrantFullAllow = class
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

  // RESTReadOnly + RESTAllowPOST: RESTReadOnly must win
  [Entity]
  [Table('grant_readonly_post_test', '')]
  [PrimaryKey('id', 'Primary key')]
  [RESTReadOnly]
  [RESTAllowPOST]
  TGrantReadOnlyWithPOST = class
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
