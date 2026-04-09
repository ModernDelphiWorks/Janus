program LazarusConsoleExample;

{$mode objfpc}{$H+}

// =============================================================================
// JANUS ORM -- Lazarus Console Example (SPRINT-07)
//
// Demonstrates Janus ORM consumption from Lazarus/FPC via JanusFramework.dll
// using the Helper Layer (Janus.Lazarus.Helper) for simplified syntax.
//
// Features demonstrated:
//   - Strategy 1: CRUD with pre-compiled Delphi models
//   - Strategy 2: Programmatic mapping via JanusBuilder()
//   - Criteria API with JW()/JStr() conversion
// =============================================================================

uses
  Janus.DLL.Interfaces,
  Janus.IncludeDll,
  Janus.Lazarus.Helper;

var
  LConn:     IJanusConnection;
  LSet:      TJanusSetHelper;
  LRec:      TJanusRecordHelper;
  LQuery: IJanusQuery;
  LFiltered: TJanusSetHelper;

begin
  WriteLn('Janus ORM via DLL -- Lazarus Example');
  WriteLn('-------------------------------------');

  // ===== STRATEGY 1: pre-compiled Delphi models =====

  // 1. Register entity models inside the DLL
  if not JanusRegisterModels then
  begin
    WriteLn('ERROR: RegisterModels failed.');
    Halt(1);
  end;

  // 2. Connect to SQLite
  LConn := JanusConnectSQLiteStr('test.db');
  if (LConn = nil) or (not LConn.IsConnected) then
  begin
    WriteLn('ERROR: Connection failed.');
    Halt(1);
  end;
  WriteLn('Connected to test.db');

  // 3. Create ObjectSet for TClientModel
  LSet := JanusObjectSetStr('TClientModel', LConn);
  if LSet.FInner = nil then
  begin
    WriteLn('ERROR: CreateObjectSet failed (model not registered?).');
    Halt(1);
  end;

  // 4. INSERT
  LRec := LSet.NewRecord;
  LRec.SetStr('client_name', 'Isaque Pinheiro');
  LRec.SetStr('client_email', 'isaque@janus.com');
  LSet.Insert(LRec);
  WriteLn('INSERT done.');

  // Release record before Open re-populates the list
  LRec := Default(TJanusRecordHelper);

  // 5. SELECT ALL
  if not LSet.Open then
  begin
    WriteLn('ERROR: Open failed.');
    Halt(1);
  end;
  WriteLn('Records found: ', LSet.RecordCount);

  if LSet.RecordCount > 0 then
  begin
    LRec := LSet.GetRecord(0);
    WriteLn('Name : ', LRec.GetStr('client_name'));
    WriteLn('Email: ', LRec.GetStr('client_email'));

    // 6. DELETE
    LSet.Delete(LRec);
    LRec := Default(TJanusRecordHelper);
    WriteLn('DELETE done.');
  end;

  // Release set (triggers IUnknown.Release -> reference counting cleanup)
  LSet := Default(TJanusSetHelper);

  // ===== SPRINT-02: Criteria Demo =====
  // Insert additional records to demonstrate filtering
  LSet := JanusObjectSetStr('TClientModel', LConn);
  if LSet.FInner <> nil then
  begin
    LRec := LSet.NewRecord;
    LRec.SetStr('client_name', 'Alpha Corp');
    LSet.Insert(LRec);
    LRec := Default(TJanusRecordHelper);

    LRec := LSet.NewRecord;
    LRec.SetStr('client_name', 'Beta Ltd');
    LSet.Insert(LRec);
    LRec := Default(TJanusRecordHelper);

    LSet := Default(TJanusSetHelper);
    WriteLn('Extra records inserted for criteria demo.');
  end;

  // Query: filter by name prefix + order + page size
  // IJanusQuery has no record wrapper — use JW()/JStr() for conversion
  LQuery := JanusCreateQuery(JW('TClientModel'), LConn);
  if Assigned(LQuery) then
  begin
    LFiltered := JanusSet(LQuery
      .Where(JW('client_name LIKE ''A%'''))
      .OrderBy(JW('client_name'))
      .PageSize(5)
      .Execute);
    if LFiltered.FInner <> nil then
    begin
      WriteLn('Filtered records (A%): ', LFiltered.RecordCount);
      LFiltered := Default(TJanusSetHelper);
    end
    else
      WriteLn('WARNING: criteria Execute returned nil.');
    LQuery := nil;
  end;

  LConn := nil;
  WriteLn('Strategy 1: OK');
  WriteLn('');

  // ===== STRATEGY 2: Programmatic mapping — no pre-compiled Delphi models =====
  WriteLn('--- Strategy 2: Programmatic Mapping ---');

  // 1. Define the entity schema at runtime via JanusBuilder().
  //    No JanusRegisterModels needed; schema lives entirely in Lazarus code.
  if not JanusBuilder()
    .EntityName('TOrder')
    .TableName('orders')
    .AddColumn('id',    'integer', 0)
    .AddColumn('descr', 'string',  100)
    .PrimaryKey('id')
    .Build
  then
  begin
    WriteLn('ERROR: EntityBuilder.Build failed.');
    Halt(1);
  end;
  WriteLn('Entity TOrder registered.');

  // 2. Connect (reuse or create a new connection)
  LConn := JanusConnectSQLiteStr('strategy2_test.db');
  if (LConn = nil) or (not LConn.IsConnected) then
  begin
    WriteLn('ERROR: Strategy 2 connection failed.');
    Halt(1);
  end;
  WriteLn('Connected to strategy2_test.db');

  // 3. Obtain an ObjectSet for the dynamically registered entity.
  //    The DLL auto-executes the DDL below on first Open so the table is created if absent:
  //    CREATE TABLE IF NOT EXISTS orders (id INTEGER, descr VARCHAR(100), PRIMARY KEY (id))
  LSet := JanusObjectSetStr('TOrder', LConn);
  if LSet.FInner = nil then
  begin
    WriteLn('ERROR: CreateObjectSet returned nil for TOrder.');
    Halt(1);
  end;

  // 4. INSERT two rows
  LRec := LSet.NewRecord;
  LRec.SetStr('descr', 'Pedido 1');
  LSet.Insert(LRec);
  LRec := Default(TJanusRecordHelper);

  LRec := LSet.NewRecord;
  LRec.SetStr('descr', 'Pedido 2');
  LSet.Insert(LRec);
  LRec := Default(TJanusRecordHelper);
  WriteLn('Strategy 2 INSERTs done.');

  // 5. SELECT ALL
  if not LSet.Open then
  begin
    WriteLn('ERROR: Strategy 2 Open failed.');
    Halt(1);
  end;
  WriteLn('Strategy 2 records found: ', LSet.RecordCount);
  if LSet.RecordCount > 0 then
    WriteLn('First descr: ', LSet.GetRecord(0).GetStr('descr'));

  // 6. DELETE first record
  if LSet.RecordCount > 0 then
  begin
    LSet.Delete(LSet.GetRecord(0));
    LSet.Open;
    WriteLn('After delete: ', LSet.RecordCount, ' record(s) remaining.');
  end;

  LSet  := Default(TJanusSetHelper);
  LConn := nil;
  WriteLn('Strategy 2: OK');
  WriteLn('');
  WriteLn('Done. No Access Violation.');
end.
