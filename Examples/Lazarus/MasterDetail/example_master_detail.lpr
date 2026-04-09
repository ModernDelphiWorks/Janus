program example_master_detail;

{$mode objfpc}{$H+}

// =============================================================================
// JANUS ORM -- Lazarus Master/Detail Example (SPRINT-07)
//
// Demonstrates programmatic definition of related entities (orders -> order_items)
// using JanusBuilder() fluent API with the Helper Layer (Janus.Lazarus.Helper).
//
// Features demonstrated:
//   - Entity registration with FK constraints via JanusBuilder()
//   - DDL generation with FOREIGN KEY
//   - SELECT with automatic JOINs
//   - Cascade delete (delete order -> deletes order_items)
//   - Cascade insert validation (insert item checks master exists)
// =============================================================================

uses
  SysUtils,
  Janus.DLL.Interfaces,
  Janus.IncludeDll,
  Janus.Lazarus.Helper;

var
  LConn:      IJanusConnection;
  LOrders:    TJanusSetHelper;
  LItems:     TJanusSetHelper;
  LRec:       TJanusRecordHelper;
  LOrderRec:  TJanusRecordHelper;
  LIdx:       Integer;

begin
  WriteLn('Janus ORM -- Master/Detail Example (SPRINT-07)');
  WriteLn('================================================');
  WriteLn('');

  // 1. Define master entity: TOrder
  if not JanusBuilder()
    .EntityName('TOrder')
    .TableName('orders')
    .AddColumn('id',            'integer', 0)
    .AddColumn('customer_name', 'string',  100)
    .AddColumn('order_date',    'string',  20)
    .PrimaryKey('id')
    .Build
  then
  begin
    WriteLn('ERROR: Failed to build TOrder entity.');
    Halt(1);
  end;
  WriteLn('Entity TOrder registered.');

  // 2. Define detail entity: TOrderItem with FK, JoinColumn and Association
  if not JanusBuilder()
    .EntityName('TOrderItem')
    .TableName('order_items')
    .AddColumn('id',           'integer', 0)
    .AddColumn('order_id',     'integer', 0)
    .AddColumn('product_name', 'string',  100)
    .AddColumn('quantity',     'integer', 0)
    .AddColumn('price',        'float',   0)
    .PrimaryKey('id')
    // FK: order_items.order_id -> orders.id
    .AddForeignKey('fk_order', 'orders', 'order_id', 'id')
    .ForeignKeyRule(1, 0)  // OnDelete=Cascade, OnUpdate=NoAction
    // JoinColumn: enables automatic LEFT JOIN with orders
    .AddJoinColumn('order_id', 'orders', 'id', 1)  // 1 = LeftJoin
    // Association: ManyToOne -> TOrder (enables cascade insert/delete)
    .AddAssociation(2, 'order_id', 'id', 'TOrder')  // 2 = ManyToOne
    .Build
  then
  begin
    WriteLn('ERROR: Failed to build TOrderItem entity.');
    Halt(1);
  end;
  WriteLn('Entity TOrderItem registered.');
  WriteLn('');

  // 3. Connect to SQLite
  LConn := JanusConnectSQLiteStr('master_detail_test.db');
  if (LConn = nil) or (not LConn.IsConnected) then
  begin
    WriteLn('ERROR: Connection failed.');
    Halt(1);
  end;
  WriteLn('Connected to master_detail_test.db');

  // 4. Create ObjectSets
  LOrders := JanusObjectSetStr('TOrder', LConn);
  LItems  := JanusObjectSetStr('TOrderItem', LConn);
  if (LOrders.FInner = nil) or (LItems.FInner = nil) then
  begin
    WriteLn('ERROR: CreateObjectSet failed.');
    Halt(1);
  end;

  // 5. Ensure tables exist (Open triggers _EnsureTableExists)
  LOrders.Open;
  LItems.Open;
  WriteLn('Tables created (orders, order_items with FK constraint).');
  WriteLn('');

  // 6. INSERT master records (orders)
  LRec := LOrders.NewRecord;
  LRec.SetInt('id', 1);
  LRec.SetStr('customer_name', 'Isaque Pinheiro');
  LRec.SetStr('order_date', '2026-04-03');
  LOrders.Insert(LRec);
  LRec := Default(TJanusRecordHelper);

  LRec := LOrders.NewRecord;
  LRec.SetInt('id', 2);
  LRec.SetStr('customer_name', 'Carlos Silva');
  LRec.SetStr('order_date', '2026-04-03');
  LOrders.Insert(LRec);
  LRec := Default(TJanusRecordHelper);
  WriteLn('Inserted 2 orders.');

  // 7. INSERT detail records (order_items for order #1)
  LRec := LItems.NewRecord;
  LRec.SetInt('id', 1);
  LRec.SetInt('order_id', 1);
  LRec.SetStr('product_name', 'Notebook Dell');
  LRec.SetInt('quantity', 2);
  LRec.SetStr('price', '3500.00');
  LItems.Insert(LRec);
  LRec := Default(TJanusRecordHelper);

  LRec := LItems.NewRecord;
  LRec.SetInt('id', 2);
  LRec.SetInt('order_id', 1);
  LRec.SetStr('product_name', 'Mouse Logitech');
  LRec.SetInt('quantity', 1);
  LRec.SetStr('price', '150.00');
  LItems.Insert(LRec);
  LRec := Default(TJanusRecordHelper);

  LRec := LItems.NewRecord;
  LRec.SetInt('id', 3);
  LRec.SetInt('order_id', 2);
  LRec.SetStr('product_name', 'Teclado Mecanico');
  LRec.SetInt('quantity', 1);
  LRec.SetStr('price', '450.00');
  LItems.Insert(LRec);
  LRec := Default(TJanusRecordHelper);
  WriteLn('Inserted 3 order_items (2 for order #1, 1 for order #2).');
  WriteLn('');

  // 8. SELECT with JOIN: order_items with orders data
  WriteLn('--- SELECT order_items with JOIN (customer_name from orders) ---');
  if LItems.Open then
  begin
    WriteLn('Order items found: ', LItems.RecordCount);
    for LIdx := 0 to LItems.RecordCount - 1 do
    begin
      LRec := LItems.GetRecord(LIdx);
      WriteLn(
        '  Item #', LRec.GetStr('id'),
        ' | Order #', LRec.GetStr('order_id'),
        ' | Product: ', LRec.GetStr('product_name'),
        ' | Customer: ', LRec.GetStr('orders_customer_name')
      );
    end;
  end;
  LRec := Default(TJanusRecordHelper);
  WriteLn('');

  // 9. CASCADE DELETE: Delete order #1 -> should delete its items automatically
  WriteLn('--- CASCADE DELETE: deleting order #1 ---');
  LOrderRec := LOrders.FindByID(1);
  if LOrderRec.FInner <> nil then
  begin
    LOrders.Delete(LOrderRec);
    WriteLn('Order #1 deleted.');
    LOrderRec := Default(TJanusRecordHelper);

    // Verify items were cascade-deleted
    if LItems.Open then
    begin
      WriteLn('Order items remaining after cascade delete: ', LItems.RecordCount);
      for LIdx := 0 to LItems.RecordCount - 1 do
      begin
        LRec := LItems.GetRecord(LIdx);
        WriteLn(
          '  Item #', LRec.GetStr('id'),
          ' | Order #', LRec.GetStr('order_id'),
          ' | Product: ', LRec.GetStr('product_name')
        );
      end;
    end;
  end
  else
    WriteLn('WARNING: Order #1 not found for cascade delete test.');

  WriteLn('');

  // 10. CASCADE INSERT VALIDATION: Try inserting item for non-existent order #99
  WriteLn('--- CASCADE INSERT: inserting item for non-existent order #99 ---');
  LRec := LItems.NewRecord;
  LRec.SetInt('id', 99);
  LRec.SetInt('order_id', 99);
  LRec.SetStr('product_name', 'Ghost Product');
  LRec.SetInt('quantity', 1);
  LRec.SetStr('price', '0.00');
  LItems.Insert(LRec);
  LRec := Default(TJanusRecordHelper);

  // Verify the item was NOT inserted (master order #99 does not exist)
  if LItems.Open then
  begin
    WriteLn('Order items after invalid insert attempt: ', LItems.RecordCount);
    WriteLn('(Should still be 1 — only order #2 items remain)');
  end;

  // Cleanup
  LItems  := Default(TJanusSetHelper);
  LOrders := Default(TJanusSetHelper);
  LConn   := nil;
  WriteLn('');
  WriteLn('Master/Detail example completed successfully.');
end.
