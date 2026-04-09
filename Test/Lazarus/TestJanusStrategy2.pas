unit TestJanusStrategy2;

// =============================================================================
// JANUS ORM -- FPCUnit Tests: Strategy 2 (EntityBuilder dinâmico)
//
// ~9 tests covering CRUD, paginação, navegação and master/detail
// with programmatically registered entities via JanusBuilder().
//
// SPRINT-09 — ESP-006-FPCTEST
// =============================================================================

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  Janus.DLL.Interfaces,
  Janus.IncludeDll,
  Janus.Lazarus.Helper,
  TestBase;

type
  TTestJanusStrategy2 = class(TJanusTestBase)
  protected
    procedure SetUp; override;
  published
    procedure TestInsertAndOpen;
    procedure TestUpdateDynamic;
    procedure TestDeleteDynamic;
    procedure TestFindByIDDynamic;
    procedure TestOpenWhereDynamic;
    procedure TestNextPacketDynamic;
    procedure TestNavigationDynamic;
    procedure TestMasterDetailInsert;
    procedure TestMasterDetailCascadeDelete;
  end;

implementation

procedure TTestJanusStrategy2.SetUp;
begin
  inherited SetUp;

  JanusBuilder()
    .EntityName('TTestProduct')
    .TableName('test_products')
    .AddColumn('id', 'integer', 0)
    .AddColumn('name', 'string', 100)
    .AddColumn('price', 'float', 0)
    .PrimaryKey('id')
    .Build;
end;

procedure TTestJanusStrategy2.TestInsertAndOpen;
var
  LSet: TJanusSetHelper;
  LRec: TJanusRecordHelper;
begin
  LSet := JanusObjectSetStr('TTestProduct', FConn);
  LRec := LSet.NewRecord;
  LRec.SetInt('id', 1);
  LRec.SetStr('name', 'Widget');
  LRec.SetFloat('price', 19.99);
  LSet.Insert(LRec);
  LRec := Default(TJanusRecordHelper);

  LSet.Open;
  AssertEquals('Must have 1 record', 1, LSet.RecordCount);
  AssertEquals('Name must match', 'Widget', LSet.GetRecord(0).GetStr('name'));
end;

procedure TTestJanusStrategy2.TestUpdateDynamic;
var
  LSet: TJanusSetHelper;
  LRec: TJanusRecordHelper;
begin
  LSet := JanusObjectSetStr('TTestProduct', FConn);
  LRec := LSet.NewRecord;
  LRec.SetInt('id', 1);
  LRec.SetStr('name', 'OldName');
  LRec.SetFloat('price', 10.0);
  LSet.Insert(LRec);
  LRec := Default(TJanusRecordHelper);

  LSet.Open;
  LRec := LSet.GetRecord(0);
  LRec.SetStr('name', 'NewName');
  LSet.Update(LRec);
  LRec := Default(TJanusRecordHelper);

  LSet.Open;
  AssertEquals('Name must be updated', 'NewName', LSet.GetRecord(0).GetStr('name'));
end;

procedure TTestJanusStrategy2.TestDeleteDynamic;
var
  LSet: TJanusSetHelper;
  LRec: TJanusRecordHelper;
begin
  LSet := JanusObjectSetStr('TTestProduct', FConn);
  LRec := LSet.NewRecord;
  LRec.SetInt('id', 1);
  LRec.SetStr('name', 'ToDelete');
  LRec.SetFloat('price', 5.0);
  LSet.Insert(LRec);
  LRec := Default(TJanusRecordHelper);

  LSet.Open;
  LRec := LSet.GetRecord(0);
  LSet.Delete(LRec);
  LRec := Default(TJanusRecordHelper);

  LSet.Open;
  AssertEquals('Must have 0 records after delete', 0, LSet.RecordCount);
end;

procedure TTestJanusStrategy2.TestFindByIDDynamic;
var
  LSet: TJanusSetHelper;
  LRec: TJanusRecordHelper;
begin
  LSet := JanusObjectSetStr('TTestProduct', FConn);
  LRec := LSet.NewRecord;
  LRec.SetInt('id', 99);
  LRec.SetStr('name', 'FindProduct');
  LRec.SetFloat('price', 25.50);
  LSet.Insert(LRec);
  LRec := Default(TJanusRecordHelper);

  LRec := LSet.FindByID(99);
  AssertNotNull('FindByID must return a record', LRec.FInner);
  AssertEquals('Name must match', 'FindProduct', LRec.GetStr('name'));
end;

procedure TTestJanusStrategy2.TestOpenWhereDynamic;
var
  LSet: TJanusSetHelper;
  LRec: TJanusRecordHelper;
  LIndex: Integer;
const
  CNames: array[1..3] of string = ('Bolt', 'Screw', 'Nut');
begin
  LSet := JanusObjectSetStr('TTestProduct', FConn);
  for LIndex := 1 to 3 do
  begin
    LRec := LSet.NewRecord;
    LRec.SetInt('id', LIndex);
    LRec.SetStr('name', CNames[LIndex]);
    LRec.SetFloat('price', LIndex * 1.5);
    LSet.Insert(LRec);
    LRec := Default(TJanusRecordHelper);
  end;

  LSet.OpenWhere('name = ''Screw''', '');
  AssertEquals('OpenWhere must return 1 record', 1, LSet.RecordCount);
  AssertEquals('Name must match filter', 'Screw', LSet.GetRecord(0).GetStr('name'));
end;

procedure TTestJanusStrategy2.TestNextPacketDynamic;
var
  LSet: TJanusSetHelper;
  LRec: TJanusRecordHelper;
  LIndex: Integer;
begin
  LSet := JanusObjectSetStr('TTestProduct', FConn);
  for LIndex := 1 to 7 do
  begin
    LRec := LSet.NewRecord;
    LRec.SetInt('id', LIndex);
    LRec.SetStr('name', 'Product ' + IntToStr(LIndex));
    LRec.SetFloat('price', LIndex * 2.0);
    LSet.Insert(LRec);
    LRec := Default(TJanusRecordHelper);
  end;

  LSet.Open;
  LSet.NextPacket(3, 1);
  AssertEquals('Page 1 must have 3 records', 3, LSet.RecordCount);

  LSet.NextPacket(3, 3);
  AssertEquals('Page 3 must have 1 record (7 mod 3)', 1, LSet.RecordCount);
end;

procedure TTestJanusStrategy2.TestNavigationDynamic;
var
  LSet: TJanusSetHelper;
  LRec: TJanusRecordHelper;
  LIndex: Integer;
begin
  LSet := JanusObjectSetStr('TTestProduct', FConn);
  for LIndex := 1 to 2 do
  begin
    LRec := LSet.NewRecord;
    LRec.SetInt('id', LIndex);
    LRec.SetStr('name', 'NavProd ' + IntToStr(LIndex));
    LRec.SetFloat('price', LIndex * 3.0);
    LSet.Insert(LRec);
    LRec := Default(TJanusRecordHelper);
  end;

  LSet.Open;
  AssertTrue('First must succeed', LSet.First);
  AssertFalse('Eof must be False', Boolean(LSet.Eof));
  AssertTrue('Next must succeed', LSet.Next);
  LSet.Next;
  AssertTrue('Eof must be True after last', Boolean(LSet.Eof));
end;

procedure TTestJanusStrategy2.TestMasterDetailInsert;
var
  LOrders: TJanusSetHelper;
  LItems: TJanusSetHelper;
  LRec: TJanusRecordHelper;
begin
  JanusBuilder()
    .EntityName('TTestOrder')
    .TableName('test_orders')
    .AddColumn('id', 'integer', 0)
    .AddColumn('description', 'string', 200)
    .PrimaryKey('id')
    .Build;

  JanusBuilder()
    .EntityName('TTestOrderItem')
    .TableName('test_order_items')
    .AddColumn('id', 'integer', 0)
    .AddColumn('order_id', 'integer', 0)
    .AddColumn('product', 'string', 100)
    .PrimaryKey('id')
    .AddForeignKey('fk_order', 'test_orders', 'order_id', 'id')
    .ForeignKeyRule(1, 0)
    .AddJoinColumn('order_id', 'test_orders', 'id', 1)
    .AddAssociation(2, 'order_id', 'id', 'TTestOrder')
    .Build;

  LOrders := JanusObjectSetStr('TTestOrder', FConn);
  LRec := LOrders.NewRecord;
  LRec.SetInt('id', 1);
  LRec.SetStr('description', 'Order One');
  LOrders.Insert(LRec);
  LRec := Default(TJanusRecordHelper);

  LItems := JanusObjectSetStr('TTestOrderItem', FConn);
  LRec := LItems.NewRecord;
  LRec.SetInt('id', 1);
  LRec.SetInt('order_id', 1);
  LRec.SetStr('product', 'Item A');
  LItems.Insert(LRec);
  LRec := Default(TJanusRecordHelper);

  LRec := LItems.NewRecord;
  LRec.SetInt('id', 2);
  LRec.SetInt('order_id', 1);
  LRec.SetStr('product', 'Item B');
  LItems.Insert(LRec);
  LRec := Default(TJanusRecordHelper);

  LOrders.Open;
  AssertEquals('Must have 1 order', 1, LOrders.RecordCount);

  LItems.Open;
  AssertEquals('Must have 2 items', 2, LItems.RecordCount);
end;

procedure TTestJanusStrategy2.TestMasterDetailCascadeDelete;
var
  LOrders: TJanusSetHelper;
  LItems: TJanusSetHelper;
  LRec: TJanusRecordHelper;
begin
  JanusBuilder()
    .EntityName('TTestOrderCasc')
    .TableName('test_orders_casc')
    .AddColumn('id', 'integer', 0)
    .AddColumn('description', 'string', 200)
    .PrimaryKey('id')
    .Build;

  JanusBuilder()
    .EntityName('TTestOrderItemCasc')
    .TableName('test_order_items_casc')
    .AddColumn('id', 'integer', 0)
    .AddColumn('order_id', 'integer', 0)
    .AddColumn('product', 'string', 100)
    .PrimaryKey('id')
    .AddForeignKey('fk_order_casc', 'test_orders_casc', 'order_id', 'id')
    .ForeignKeyRule(1, 0)
    .AddJoinColumn('order_id', 'test_orders_casc', 'id', 1)
    .AddAssociation(2, 'order_id', 'id', 'TTestOrderCasc')
    .Build;

  LOrders := JanusObjectSetStr('TTestOrderCasc', FConn);
  LRec := LOrders.NewRecord;
  LRec.SetInt('id', 1);
  LRec.SetStr('description', 'CascOrder');
  LOrders.Insert(LRec);
  LRec := Default(TJanusRecordHelper);

  LItems := JanusObjectSetStr('TTestOrderItemCasc', FConn);
  LRec := LItems.NewRecord;
  LRec.SetInt('id', 1);
  LRec.SetInt('order_id', 1);
  LRec.SetStr('product', 'CascItem');
  LItems.Insert(LRec);
  LRec := Default(TJanusRecordHelper);

  LOrders.Open;
  LRec := LOrders.GetRecord(0);
  LOrders.Delete(LRec);
  LRec := Default(TJanusRecordHelper);

  LItems.Open;
  AssertEquals('Cascade delete must remove items', 0, LItems.RecordCount);
end;

initialization
  RegisterTest(TTestJanusStrategy2);

end.
