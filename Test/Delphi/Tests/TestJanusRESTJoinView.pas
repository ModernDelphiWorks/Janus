unit TestJanusRESTJoinView;

interface

uses
  SysUtils,
  Classes,
  Net.HTTPClient,
  Net.URLClient,
  DUnitX.TestFramework,
  // FluentSQL
  FluentSQL,
  // Janus
  Janus.Server.RestView.Manager,
  RestHorseTest.Base,
  RestHorseTest.Models;

type
  [TestFixture]
  TTestRESTJoinView = class(TRestHorseTestBase)
  private
    FHTTPClient: THTTPClient;
    function _BuildURL(const AResource: String; const AQuery: String = ''): String;
    function _Get(const AURL: String): String;
    function _Post(const AURL: String; const ABody: String): String;
    function _Delete(const AURL: String): String;
    procedure _SeedOrderData;
    procedure _CreateSummaryView;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // CA-005: $expand via RTTI
    [Test]
    procedure Expand_MasterDetail_ReturnsRelatedData;
    [Test]
    procedure Expand_EmptyAssociation_ReturnsCustomerWithEmptyList;

    // CA-006: VIEW via FluentSQL + DataEngine
    [Test]
    procedure EnsureView_CreatesView_NoException;
    [Test]
    procedure EnsureView_Idempotent_SecondCallNoException;
    [Test]
    procedure Get_ViewResource_ReturnsData;
    [Test]
    procedure Post_ViewResource_ReturnsReadOnlyError;
  end;

implementation

const
  cTIMEOUT_MS = 2000;
  cREADONLY_MSG = 'read-only (RESTReadOnly)';

{ TTestRESTJoinView }

procedure TTestRESTJoinView.Setup;
begin
  FPrefix := 'api/Janus';
  inherited Setup;
  FHTTPClient := THTTPClient.Create;
  FHTTPClient.ConnectionTimeout := cTIMEOUT_MS;
  FHTTPClient.ResponseTimeout := cTIMEOUT_MS;
  _SeedOrderData;
end;

procedure TTestRESTJoinView.TearDown;
begin
  FreeAndNil(FHTTPClient);
  inherited TearDown;
end;

function TTestRESTJoinView._BuildURL(const AResource: String;
  const AQuery: String): String;
begin
  Result := BuildResourceURL(AResource);
  if AQuery <> '' then
    Result := Result + '?' + AQuery;
end;

function TTestRESTJoinView._Get(const AURL: String): String;
begin
  Result := FHTTPClient.Get(AURL).ContentAsString(TEncoding.UTF8);
end;

function TTestRESTJoinView._Post(const AURL: String; const ABody: String): String;
var
  LStream: TStringStream;
begin
  LStream := TStringStream.Create(ABody, TEncoding.UTF8);
  try
    Result := FHTTPClient.Post(AURL, LStream, nil,
      [TNameValuePair.Create('Content-Type', 'application/json')])
      .ContentAsString(TEncoding.UTF8);
  finally
    LStream.Free;
  end;
end;

function TTestRESTJoinView._Delete(const AURL: String): String;
begin
  Result := FHTTPClient.Delete(AURL).ContentAsString(TEncoding.UTF8);
end;

procedure TTestRESTJoinView._SeedOrderData;
begin
  SeedCustomers;
  ExecuteSQL(
    'INSERT INTO order_test (customer_id, description, total) VALUES (1, ''Order A'', 100.00)');
  ExecuteSQL(
    'INSERT INTO order_test (customer_id, description, total) VALUES (1, ''Order B'', 200.00)');
  ExecuteSQL(
    'INSERT INTO order_test (customer_id, description, total) VALUES (2, ''Order C'', 50.00)');
end;

procedure TTestRESTJoinView._CreateSummaryView;
var
  LSelect: IFluentSQL;
begin
  LSelect := FluentSQL.Query(dbnSQLite)
    .Select(['c.id AS customer_id',
             'c.name AS customer_name',
             'COUNT(o.id) AS order_count',
             'COALESCE(SUM(o.total), 0) AS total_amount'])
    .From('customer_test c')
    .LeftJoin('order_test o', 'o.customer_id = c.id')
    .GroupBy(['c.id', 'c.name']);

  TRESTViewManager.EnsureView(TCustomerOrderSummary, LSelect, Connection);
end;

// CA-005 Test 1: $expand returns master + detail
procedure TTestRESTJoinView.Expand_MasterDetail_ReturnsRelatedData;
var
  LResult: String;
begin
  LResult := _Get(_BuildURL('CustomerTest(1)', '$expand=OrderTest'));
  Assert.IsFalse(LResult.Contains('"exception"'),
    '$expand returned exception: ' + LResult);
end;

// CA-005 Test 2: $expand with customer with no orders still returns customer
procedure TTestRESTJoinView.Expand_EmptyAssociation_ReturnsCustomerWithEmptyList;
var
  LResult: String;
begin
  // Customer 3 (Carol) has no orders
  LResult := _Get(_BuildURL('CustomerTest(3)', '$expand=OrderTest'));
  Assert.IsFalse(LResult.Contains('"exception"'),
    '$expand empty list returned exception: ' + LResult);
end;

// CA-006 Test 1: EnsureView creates the VIEW without exception
procedure TTestRESTJoinView.EnsureView_CreatesView_NoException;
begin
  Assert.WillNotRaise(
    procedure
    begin
      _CreateSummaryView;
    end,
    Exception,
    'EnsureView should not raise');
end;

// CA-006 Test 2: calling EnsureView again (idempotent) does not raise
procedure TTestRESTJoinView.EnsureView_Idempotent_SecondCallNoException;
begin
  _CreateSummaryView;
  Assert.WillNotRaise(
    procedure
    begin
      _CreateSummaryView;
    end,
    Exception,
    'Second EnsureView call should not raise');
end;

// CA-006 Test 3: GET on view resource returns data
procedure TTestRESTJoinView.Get_ViewResource_ReturnsData;
var
  LResult: String;
begin
  _CreateSummaryView;
  LResult := _Get(_BuildURL('CustomerOrderSummary'));
  Assert.IsFalse(LResult.Contains('"exception"'),
    'GET view resource returned exception: ' + LResult);
end;

// CA-006 Test 4: POST on view resource must be blocked
procedure TTestRESTJoinView.Post_ViewResource_ReturnsReadOnlyError;
var
  LResult: String;
begin
  _CreateSummaryView;
  LResult := _Post(_BuildURL('CustomerOrderSummary'),
    '{"customer_id":1,"customer_name":"Test","order_count":0,"total_amount":0}');
  Assert.Contains(LResult, cREADONLY_MSG,
    'POST on view must return read-only error, got: ' + LResult);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRESTJoinView);

end.
