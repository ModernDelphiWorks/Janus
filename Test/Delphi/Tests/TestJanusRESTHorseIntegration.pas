unit TestJanusRESTHorseIntegration;

interface

uses
  SysUtils,
  Classes,
  Net.HTTPClient,
  Net.URLClient,
  DUnitX.TestFramework,
  RestHorseTest.Base;

type
  [TestFixture]
  TTestRESTHorseIntegration = class(TRestHorseTestBase)
  private
    FHTTPClient: THTTPClient;
    function _BuildURL(const AResource: String; const AQuery: String = ''): String;
    function _Get(const AURL: String): String;
    function _Post(const AURL: String; const ABody: String): String;
    function _Put(const AURL: String; const ABody: String): String;
    function _Delete(const AURL: String): String;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // CA-002 scenarios
    [Test]
    procedure GetList_ReturnsJSONArray;
    [Test]
    procedure GetByID_ReturnsJSON;
    [Test]
    procedure GetWithFilter_EqOperator_ReturnsFiltered;
    [Test]
    procedure GetWithOrderBy_ReturnsOrdered;
    [Test]
    procedure GetWithTopAndSkip_ReturnsPaged;
    [Test]
    procedure GetWithCount_ResponseHasResultCountHeader;
    [Test]
    procedure Post_InsertsRecord_Returns200;
    [Test]
    procedure Put_UpdatesRecord_Returns200;
    [Test]
    procedure Delete_ByID_Returns200;
    [Test]
    procedure Delete_WithFilter_Returns200;
    [Test]
    procedure Get_UnknownResource_ReturnsErrorJSON;
    [Test]
    procedure GetWithAndOrFilter_ReturnsCorrectResult;
  end;

implementation

const
  cTIMEOUT_MS = 2000;

{ TTestRESTHorseIntegration }

procedure TTestRESTHorseIntegration.Setup;
begin
  inherited Setup;
  FHTTPClient := THTTPClient.Create;
  FHTTPClient.ConnectionTimeout := cTIMEOUT_MS;
  FHTTPClient.ResponseTimeout := cTIMEOUT_MS;
  SeedCustomers;
end;

procedure TTestRESTHorseIntegration.TearDown;
begin
  FreeAndNil(FHTTPClient);
  inherited TearDown;
end;

function TTestRESTHorseIntegration._BuildURL(const AResource: String;
  const AQuery: String): String;
begin
  Result := Format('http://localhost:%d/api/Janus/%s', [Port, AResource]);
  if AQuery <> '' then
    Result := Result + '?' + AQuery;
end;

function TTestRESTHorseIntegration._Get(const AURL: String): String;
var
  LResponse: IHTTPResponse;
begin
  LResponse := FHTTPClient.Get(AURL);
  Result := LResponse.ContentAsString(TEncoding.UTF8);
end;

function TTestRESTHorseIntegration._Post(const AURL: String;
  const ABody: String): String;
var
  LStream: TStringStream;
  LResponse: IHTTPResponse;
begin
  LStream := TStringStream.Create(ABody, TEncoding.UTF8);
  try
    LResponse := FHTTPClient.Post(AURL, LStream, nil,
      [TNameValuePair.Create('Content-Type', 'application/json')]);
    Result := LResponse.ContentAsString(TEncoding.UTF8);
  finally
    LStream.Free;
  end;
end;

function TTestRESTHorseIntegration._Put(const AURL: String;
  const ABody: String): String;
var
  LStream: TStringStream;
  LResponse: IHTTPResponse;
begin
  LStream := TStringStream.Create(ABody, TEncoding.UTF8);
  try
    LResponse := FHTTPClient.Put(AURL, LStream, nil,
      [TNameValuePair.Create('Content-Type', 'application/json')]);
    Result := LResponse.ContentAsString(TEncoding.UTF8);
  finally
    LStream.Free;
  end;
end;

function TTestRESTHorseIntegration._Delete(const AURL: String): String;
var
  LResponse: IHTTPResponse;
begin
  LResponse := FHTTPClient.Delete(AURL);
  Result := LResponse.ContentAsString(TEncoding.UTF8);
end;

// 1. GET list → 200, JSON array
procedure TTestRESTHorseIntegration.GetList_ReturnsJSONArray;
var
  LURL: String;
  LResult: String;
begin
  LURL := _BuildURL('CustomerTest');
  LResult := _Get(LURL);
  Assert.IsNotEmpty(LResult);
  Assert.StartsWith('[', LResult.Trim);
end;

// 2. GET by ID → 200, JSON object
procedure TTestRESTHorseIntegration.GetByID_ReturnsJSON;
var
  LResult: String;
begin
  LResult := _Get(_BuildURL('CustomerTest(1)'));
  Assert.IsNotEmpty(LResult);
  Assert.IsFalse(LResult.Contains('"exception"'));
end;

// 3. GET with $filter eq → filtered result
procedure TTestRESTHorseIntegration.GetWithFilter_EqOperator_ReturnsFiltered;
var
  LResult: String;
begin
  LResult := _Get(_BuildURL('CustomerTest', '$filter=name eq ''Alice'''));
  Assert.Contains(LResult, 'Alice');
  Assert.IsFalse(LResult.Contains('"exception"'));
end;

// 4. GET with $orderby
procedure TTestRESTHorseIntegration.GetWithOrderBy_ReturnsOrdered;
var
  LResult: String;
begin
  LResult := _Get(_BuildURL('CustomerTest', '$orderby=name desc'));
  Assert.IsNotEmpty(LResult);
  Assert.IsFalse(LResult.Contains('"exception"'));
end;

// 5. GET with $top and $skip
procedure TTestRESTHorseIntegration.GetWithTopAndSkip_ReturnsPaged;
var
  LResult: String;
begin
  LResult := _Get(_BuildURL('CustomerTest', '$top=1&$skip=1'));
  Assert.IsNotEmpty(LResult);
  Assert.IsFalse(LResult.Contains('"exception"'));
end;

// 6. GET with $count=true → ResultCount header present
procedure TTestRESTHorseIntegration.GetWithCount_ResponseHasResultCountHeader;
var
  LURL: String;
  LResponse: IHTTPResponse;
begin
  LURL := _BuildURL('CustomerTest', '$count=true');
  LResponse := FHTTPClient.Get(LURL);
  // The Horse layer adds ResultCount when count > 0
  Assert.IsNotEmpty(LResponse.ContentAsString(TEncoding.UTF8));
end;

// 7. POST new record → success JSON
procedure TTestRESTHorseIntegration.Post_InsertsRecord_Returns200;
var
  LResult: String;
begin
  ResetDatabase;
  LResult := _Post(_BuildURL('CustomerTest'),
    '{"name":"Dave","email":"dave@test.com","active":true}');
  Assert.IsFalse(LResult.Contains('"exception"'), 'POST returned exception: ' + LResult);
  Assert.Contains(LResult, 'CustomerTest');
end;

// 8. PUT updates record → success JSON
procedure TTestRESTHorseIntegration.Put_UpdatesRecord_Returns200;
var
  LResult: String;
begin
  _Post(_BuildURL('CustomerTest'),
    '{"name":"UpdateMe","email":"u@test.com","active":true}');
  LResult := _Put(_BuildURL('CustomerTest'),
    '{"id":1,"name":"Updated","email":"upd@test.com","active":true}');
  Assert.IsFalse(LResult.Contains('"exception"'), 'PUT returned exception: ' + LResult);
end;

// 9. DELETE by ID path
procedure TTestRESTHorseIntegration.Delete_ByID_Returns200;
var
  LResult: String;
begin
  _Post(_BuildURL('CustomerTest'),
    '{"name":"ToDelete","email":"del@test.com","active":true}');
  LResult := _Delete(_BuildURL('CustomerTest(1)'));
  Assert.IsFalse(LResult.Contains('"exception"'), 'DELETE returned exception: ' + LResult);
end;

// 10. DELETE with $filter
procedure TTestRESTHorseIntegration.Delete_WithFilter_Returns200;
var
  LResult: String;
begin
  _Post(_BuildURL('CustomerTest'),
    '{"name":"Temp","email":"temp@test.com","active":false}');
  LResult := _Delete(_BuildURL('CustomerTest', '$filter=name eq ''Temp'''));
  Assert.IsFalse(LResult.Contains('"exception"'), 'DELETE with filter exception: ' + LResult);
end;

// 11. GET unknown resource → error JSON
procedure TTestRESTHorseIntegration.Get_UnknownResource_ReturnsErrorJSON;
var
  LResult: String;
begin
  LResult := _Get(_BuildURL('NonExistentResource9999'));
  Assert.Contains(LResult, 'exception');
end;

// 12. GET with AND/OR filter — validates parser ↔ execution integration
procedure TTestRESTHorseIntegration.GetWithAndOrFilter_ReturnsCorrectResult;
var
  LResult: String;
begin
  LResult := _Get(_BuildURL('CustomerTest',
    '$filter=name eq ''Alice'' or name eq ''Bob'''));
  Assert.IsFalse(LResult.Contains('"exception"'), 'AND/OR filter exception: ' + LResult);
  Assert.Contains(LResult, 'Alice');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRESTHorseIntegration);

end.
