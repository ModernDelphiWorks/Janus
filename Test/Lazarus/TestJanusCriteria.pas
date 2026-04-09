unit TestJanusCriteria;

// =============================================================================
// JANUS ORM -- FPCUnit Tests: Criteria API
//
// 3 tests covering Where, OrderBy, PageSize via JanusCreateQuery.
// Query API does not have a helper record — uses JW() and JStr() directly.
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
  TTestJanusCriteria = class(TJanusTestBase)
  private
    procedure _InsertClients(ASet: TJanusSetHelper; ACount: Integer);
  published
    procedure TestWhereFilter;
    procedure TestOrderBy;
    procedure TestPageSize;
  end;

implementation

procedure TTestJanusCriteria._InsertClients(ASet: TJanusSetHelper; ACount: Integer);
var
  LRec: TJanusRecordHelper;
  LIndex: Integer;
const
  CNames: array[1..5] of string = ('Alpha', 'Beta', 'Gamma', 'Delta', 'Epsilon');
begin
  for LIndex := 1 to ACount do
  begin
    LRec := ASet.NewRecord;
    LRec.SetInt('client_id', LIndex);
    LRec.SetStr('client_name', CNames[LIndex]);
    ASet.Insert(LRec);
    LRec := Default(TJanusRecordHelper);
  end;
end;

procedure TTestJanusCriteria.TestWhereFilter;
var
  LSet: TJanusSetHelper;
  LQuery: IJanusQuery;
  LFiltered: TJanusSetHelper;
begin
  LSet := JanusObjectSetStr('TClientModel', FConn);
  _InsertClients(LSet, 3);

  LQuery := JanusCreateQuery(JW('TClientModel'), FConn);
  LFiltered := JanusSet(LQuery.Where(JW('client_name = ''Alpha''')).Execute);
  AssertEquals('Where must return 1 record', 1, LFiltered.RecordCount);
  AssertEquals('Name must be Alpha', 'Alpha', LFiltered.GetRecord(0).GetStr('client_name'));
end;

procedure TTestJanusCriteria.TestOrderBy;
var
  LSet: TJanusSetHelper;
  LQuery: IJanusQuery;
  LOrdered: TJanusSetHelper;
begin
  LSet := JanusObjectSetStr('TClientModel', FConn);
  _InsertClients(LSet, 3);

  LQuery := JanusCreateQuery(JW('TClientModel'), FConn);
  LOrdered := JanusSet(LQuery.OrderBy(JW('client_name')).Execute);
  AssertTrue('Must have records', LOrdered.RecordCount >= 3);
  AssertEquals('First must be Alpha (ASC)', 'Alpha', LOrdered.GetRecord(0).GetStr('client_name'));
  AssertEquals('Second must be Beta', 'Beta', LOrdered.GetRecord(1).GetStr('client_name'));
  AssertEquals('Third must be Gamma', 'Gamma', LOrdered.GetRecord(2).GetStr('client_name'));
end;

procedure TTestJanusCriteria.TestPageSize;
var
  LSet: TJanusSetHelper;
  LQuery: IJanusQuery;
  LPaged: TJanusSetHelper;
begin
  LSet := JanusObjectSetStr('TClientModel', FConn);
  _InsertClients(LSet, 5);

  LQuery := JanusCreateQuery(JW('TClientModel'), FConn);
  LPaged := JanusSet(LQuery.PageSize(2).Execute);
  AssertEquals('PageSize(2) must return 2 records', 2, LPaged.RecordCount);
end;

initialization
  RegisterTest(TTestJanusCriteria);

end.
