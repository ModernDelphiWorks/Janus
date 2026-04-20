unit TestJanusRESTHorseDriver;

interface

uses
  SysUtils,
  Net.HTTPClient,
  Net.URLClient,
  DUnitX.TestFramework,
  RestHorseTest.Base;

type
  [TestFixture]
  TTestRESTHorseDriver = class(TRestHorseTestBase)
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

    [Test]
    procedure GetList_WithPrefix_ReturnsJSONArray;
    [Test]
    procedure GetByID_WithPrefix_ReturnsJSON;
    [Test]
    procedure Post_WithPrefix_InsertsRecord;
    [Test]
    procedure Put_WithPrefix_UpdatesRecord;
    [Test]
    procedure Delete_WithPrefix_ByID;
    [Test]
    procedure Get_UnknownResource_WithPrefix_ReturnsError;
    [Test]
    procedure GetWithFilter_WithPrefix_ReturnsFiltered;
    [Test]
    procedure GetWithPagination_WithPrefix_ReturnsPaged;
  end;

implementation

const
  cTIMEOUT_MS = 2000;

{ TTestRESTHorseDriver }

procedure TTestRESTHorseDriver.Setup;
begin
  FPrefix := 'api/Janus';
  inherited Setup;
  FHTTPClient := THTTPClient.Create;
  FHTTPClient.ConnectionTimeout := cTIMEOUT_MS;
  FHTTPClient.ResponseTimeout := cTIMEOUT_MS;
  SeedCustomers;
end;

procedure TTestRESTHorseDriver.TearDown;
begin
  FreeAndNil(FHTTPClient);
  inherited TearDown;
end;

function TTestRESTHorseDriver._BuildURL(const AResource: String;
  const AQuery: String): String;
begin
  Result := BuildResourceURL(AResource);
  if AQuery <> '' then
    Result := Result + '?' + AQuery;
end;

function TTestRESTHorseDriver._Get(const AURL: String): String;
var
  LResponse: IHTTPResponse;
begin
  LResponse := FHTTPClient.Get(AURL);
  Result := LResponse.ContentAsString(TEncoding.UTF8);
end;

function TTestRESTHorseDriver._Post(const AURL: String;
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

function TTestRESTHorseDriver._Put(const AURL: String;
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

function TTestRESTHorseDriver._Delete(const AURL: String): String;
var
  LResponse: IHTTPResponse;
begin
  LResponse := FHTTPClient.Delete(AURL);
  Result := LResponse.ContentAsString(TEncoding.UTF8);
end;

// 1. GET list with prefix → 200, JSON array
procedure TTestRESTHorseDriver.GetList_WithPrefix_ReturnsJSONArray;
var
  LResult: String;
begin
  LResult := _Get(_BuildURL('CustomerTest'));
  Assert.IsNotEmpty(LResult);
  Assert.StartsWith('[', LResult.Trim);
end;

// 2. GET by ID with prefix → 200, JSON object
procedure TTestRESTHorseDriver.GetByID_WithPrefix_ReturnsJSON;
var
  LResult: String;
begin
  LResult := _Get(_BuildURL('CustomerTest(1)'));
  Assert.IsNotEmpty(LResult);
  Assert.IsFalse(LResult.Contains('"exception"'));
end;

// 3. POST with prefix → inserts record
procedure TTestRESTHorseDriver.Post_WithPrefix_InsertsRecord;
var
  LResult: String;
begin
  ResetDatabase;
  LResult := _Post(_BuildURL('CustomerTest'),
    '{"name":"Dave","email":"dave@test.com","active":true}');
  Assert.IsFalse(LResult.Contains('"exception"'), 'POST returned exception: ' + LResult);
  Assert.Contains(LResult, 'CustomerTest');
end;

// 4. PUT with prefix → updates record
procedure TTestRESTHorseDriver.Put_WithPrefix_UpdatesRecord;
var
  LResult: String;
begin
  _Post(_BuildURL('CustomerTest'),
    '{"name":"UpdateMe","email":"u@test.com","active":true}');
  LResult := _Put(_BuildURL('CustomerTest'),
    '{"id":1,"name":"Updated","email":"upd@test.com","active":true}');
  Assert.IsFalse(LResult.Contains('"exception"'), 'PUT returned exception: ' + LResult);
end;

// 5. DELETE by ID with prefix
procedure TTestRESTHorseDriver.Delete_WithPrefix_ByID;
var
  LResult: String;
begin
  _Post(_BuildURL('CustomerTest'),
    '{"name":"ToDelete","email":"del@test.com","active":true}');
  LResult := _Delete(_BuildURL('CustomerTest(1)'));
  Assert.IsFalse(LResult.Contains('"exception"'), 'DELETE returned exception: ' + LResult);
end;

// 6. GET unknown resource with prefix → structured error
procedure TTestRESTHorseDriver.Get_UnknownResource_WithPrefix_ReturnsError;
var
  LResult: String;
begin
  LResult := _Get(_BuildURL('NonExistentResource9999'));
  Assert.Contains(LResult, 'exception');
end;

// 7. GET with $filter using prefix → filtered result
procedure TTestRESTHorseDriver.GetWithFilter_WithPrefix_ReturnsFiltered;
var
  LResult: String;
begin
  LResult := _Get(_BuildURL('CustomerTest', '$filter=active eq 1'));
  Assert.IsFalse(LResult.Contains('"exception"'), 'Filter returned exception: ' + LResult);
  Assert.IsNotEmpty(LResult);
end;

// 8. GET with $top and $skip using prefix → paged result
procedure TTestRESTHorseDriver.GetWithPagination_WithPrefix_ReturnsPaged;
var
  LResult: String;
begin
  LResult := _Get(_BuildURL('CustomerTest', '$top=2&$skip=1'));
  Assert.IsNotEmpty(LResult);
  Assert.IsFalse(LResult.Contains('"exception"'), 'Pagination returned exception: ' + LResult);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRESTHorseDriver);

end.
