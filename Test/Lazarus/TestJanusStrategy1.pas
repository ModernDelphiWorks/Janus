unit TestJanusStrategy1;

// =============================================================================
// JANUS ORM -- FPCUnit Tests: Strategy 1 (Pre-compiled TClientModel)
//
// 10 tests covering CRUD, paginação, navegação with TClientModel.
// Uses helper layer (TJanusSetHelper, TJanusRecordHelper).
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
  TTestJanusStrategy1 = class(TJanusTestBase)
  published
    procedure TestOpenEmptyTable;
    procedure TestInsertSingle;
    procedure TestInsertMultiple;
    procedure TestUpdateRecord;
    procedure TestDeleteRecord;
    procedure TestFindByID;
    procedure TestOpenWhere;
    procedure TestNextPacket;
    procedure TestNavigation;
    procedure TestCurrentRecord;
  end;

implementation

procedure TTestJanusStrategy1.TestOpenEmptyTable;
var
  LSet: TJanusSetHelper;
begin
  LSet := JanusObjectSetStr('TClientModel', FConn);
  AssertTrue('Open must succeed', LSet.Open);
  AssertEquals('Empty table must have 0 records', 0, LSet.RecordCount);
end;

procedure TTestJanusStrategy1.TestInsertSingle;
var
  LSet: TJanusSetHelper;
  LRec: TJanusRecordHelper;
begin
  LSet := JanusObjectSetStr('TClientModel', FConn);
  LRec := LSet.NewRecord;
  LRec.SetInt('client_id', 1);
  LRec.SetStr('client_name', 'Test Client');
  LSet.Insert(LRec);
  LRec := Default(TJanusRecordHelper);

  LSet.Open;
  AssertEquals('Must have 1 record after insert', 1, LSet.RecordCount);
  AssertEquals('Name must match', 'Test Client', LSet.GetRecord(0).GetStr('client_name'));
end;

procedure TTestJanusStrategy1.TestInsertMultiple;
var
  LSet: TJanusSetHelper;
  LRec: TJanusRecordHelper;
  LIndex: Integer;
begin
  LSet := JanusObjectSetStr('TClientModel', FConn);
  for LIndex := 1 to 3 do
  begin
    LRec := LSet.NewRecord;
    LRec.SetInt('client_id', LIndex);
    LRec.SetStr('client_name', 'Client ' + IntToStr(LIndex));
    LSet.Insert(LRec);
    LRec := Default(TJanusRecordHelper);
  end;

  LSet.Open;
  AssertEquals('Must have 3 records', 3, LSet.RecordCount);
end;

procedure TTestJanusStrategy1.TestUpdateRecord;
var
  LSet: TJanusSetHelper;
  LRec: TJanusRecordHelper;
begin
  LSet := JanusObjectSetStr('TClientModel', FConn);
  LRec := LSet.NewRecord;
  LRec.SetInt('client_id', 1);
  LRec.SetStr('client_name', 'Original');
  LSet.Insert(LRec);
  LRec := Default(TJanusRecordHelper);

  LSet.Open;
  LRec := LSet.GetRecord(0);
  LRec.SetStr('client_name', 'Updated');
  LSet.Update(LRec);
  LRec := Default(TJanusRecordHelper);

  LSet.Open;
  AssertEquals('Name must be updated', 'Updated', LSet.GetRecord(0).GetStr('client_name'));
end;

procedure TTestJanusStrategy1.TestDeleteRecord;
var
  LSet: TJanusSetHelper;
  LRec: TJanusRecordHelper;
begin
  LSet := JanusObjectSetStr('TClientModel', FConn);
  LRec := LSet.NewRecord;
  LRec.SetInt('client_id', 1);
  LRec.SetStr('client_name', 'ToDelete');
  LSet.Insert(LRec);
  LRec := Default(TJanusRecordHelper);

  LSet.Open;
  LRec := LSet.GetRecord(0);
  LSet.Delete(LRec);
  LRec := Default(TJanusRecordHelper);

  LSet.Open;
  AssertEquals('Must have 0 records after delete', 0, LSet.RecordCount);
end;

procedure TTestJanusStrategy1.TestFindByID;
var
  LSet: TJanusSetHelper;
  LRec: TJanusRecordHelper;
begin
  LSet := JanusObjectSetStr('TClientModel', FConn);
  LRec := LSet.NewRecord;
  LRec.SetInt('client_id', 42);
  LRec.SetStr('client_name', 'FindMe');
  LSet.Insert(LRec);
  LRec := Default(TJanusRecordHelper);

  LRec := LSet.FindByID(42);
  AssertNotNull('FindByID must return a record', LRec.FInner);
  AssertEquals('Name must match', 'FindMe', LRec.GetStr('client_name'));
end;

procedure TTestJanusStrategy1.TestOpenWhere;
var
  LSet: TJanusSetHelper;
  LRec: TJanusRecordHelper;
  LIndex: Integer;
const
  CNames: array[1..3] of string = ('Alpha', 'Target', 'Gamma');
begin
  LSet := JanusObjectSetStr('TClientModel', FConn);
  for LIndex := 1 to 3 do
  begin
    LRec := LSet.NewRecord;
    LRec.SetInt('client_id', LIndex);
    LRec.SetStr('client_name', CNames[LIndex]);
    LSet.Insert(LRec);
    LRec := Default(TJanusRecordHelper);
  end;

  LSet.OpenWhere('client_name = ''Target''', '');
  AssertEquals('OpenWhere must return 1 record', 1, LSet.RecordCount);
  AssertEquals('Name must match filter', 'Target', LSet.GetRecord(0).GetStr('client_name'));
end;

procedure TTestJanusStrategy1.TestNextPacket;
var
  LSet: TJanusSetHelper;
  LRec: TJanusRecordHelper;
  LIndex: Integer;
begin
  LSet := JanusObjectSetStr('TClientModel', FConn);
  for LIndex := 1 to 10 do
  begin
    LRec := LSet.NewRecord;
    LRec.SetInt('client_id', LIndex);
    LRec.SetStr('client_name', 'Client ' + IntToStr(LIndex));
    LSet.Insert(LRec);
    LRec := Default(TJanusRecordHelper);
  end;

  LSet.Open;
  LSet.NextPacket(3, 1);
  AssertEquals('Page 1 must have 3 records', 3, LSet.RecordCount);

  LSet.NextPacket(3, 4);
  AssertEquals('Page 4 must have 1 record (10 mod 3)', 1, LSet.RecordCount);

  LSet.NextPacket(3, 5);
  AssertEquals('Page beyond total must have 0 records', 0, LSet.RecordCount);
end;

procedure TTestJanusStrategy1.TestNavigation;
var
  LSet: TJanusSetHelper;
  LRec: TJanusRecordHelper;
  LIndex: Integer;
begin
  LSet := JanusObjectSetStr('TClientModel', FConn);
  for LIndex := 1 to 3 do
  begin
    LRec := LSet.NewRecord;
    LRec.SetInt('client_id', LIndex);
    LRec.SetStr('client_name', 'Nav ' + IntToStr(LIndex));
    LSet.Insert(LRec);
    LRec := Default(TJanusRecordHelper);
  end;

  LSet.Open;
  AssertTrue('First must succeed', LSet.First);
  AssertFalse('Eof must be False after First', Boolean(LSet.Eof));
  AssertTrue('Next must succeed (2nd)', LSet.Next);
  AssertTrue('Next must succeed (3rd)', LSet.Next);
  LSet.Next;
  AssertTrue('Eof must be True after last Next', Boolean(LSet.Eof));
  AssertTrue('Prior must succeed', LSet.Prior);
end;

procedure TTestJanusStrategy1.TestCurrentRecord;
var
  LSet: TJanusSetHelper;
  LRec: TJanusRecordHelper;
begin
  LSet := JanusObjectSetStr('TClientModel', FConn);
  LRec := LSet.NewRecord;
  LRec.SetInt('client_id', 1);
  LRec.SetStr('client_name', 'CurrentTest');
  LSet.Insert(LRec);
  LRec := Default(TJanusRecordHelper);

  LSet.Open;
  LSet.First;
  LRec := LSet.Current;
  AssertNotNull('Current must return a record after First', LRec.FInner);
  AssertEquals('Current name must match', 'CurrentTest', LRec.GetStr('client_name'));
end;

initialization
  RegisterTest(TTestJanusStrategy1);

end.
