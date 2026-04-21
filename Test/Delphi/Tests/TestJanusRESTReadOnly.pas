unit TestJanusRESTReadOnly;

interface

uses
  SysUtils,
  Classes,
  Net.HTTPClient,
  Net.URLClient,
  DUnitX.TestFramework,
  MetaDbDiff.Mapping.Explorer,
  RestHorseTest.Base,
  RestHorseTest.Models;

type
  [TestFixture]
  TTestRESTReadOnly = class(TRestHorseTestBase)
  private
    FHTTPClient: THTTPClient;
    function _BuildURL(const AResource: String; const AQuery: String = ''): String;
    function _Get(const AURL: String): String;
    function _Post(const AURL: String; const ABody: String): String;
    function _Put(const AURL: String; const ABody: String): String;
    function _Delete(const AURL: String): String;
  public
    [SetupFixture]
    procedure SetupFixture;
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // CA-003 unit-level tests
    [Test]
    procedure GetRESTReadOnly_ClassWithoutAttribute_ReturnsFalse;
    [Test]
    procedure GetRESTReadOnly_ClassWithAttribute_ReturnsTrue;

    // CA-003 integration-level tests
    [Test]
    procedure Get_ReadOnlyResource_Succeeds;
    [Test]
    procedure Post_ReadOnlyResource_ReturnsReadOnlyError;
    [Test]
    procedure Put_ReadOnlyResource_ReturnsReadOnlyError;
    [Test]
    procedure Delete_ReadOnlyResource_ReturnsReadOnlyError;
  end;

implementation

const
  cTIMEOUT_MS = 2000;
  cREADONLY_MSG = 'read-only (RESTReadOnly)';

{ TTestRESTReadOnly }

procedure TTestRESTReadOnly.SetupFixture;
begin
  FPrefix := 'api/Janus';
  inherited SetupFixture;
end;

procedure TTestRESTReadOnly.Setup;
begin
  inherited Setup;
  FHTTPClient := THTTPClient.Create;
  FHTTPClient.ConnectionTimeout := cTIMEOUT_MS;
  FHTTPClient.ResponseTimeout := cTIMEOUT_MS;
end;

procedure TTestRESTReadOnly.TearDown;
begin
  FreeAndNil(FHTTPClient);
  inherited TearDown;
end;

function TTestRESTReadOnly._BuildURL(const AResource: String;
  const AQuery: String): String;
begin
  Result := BuildResourceURL(AResource);
  if AQuery <> '' then
    Result := Result + '?' + AQuery;
end;

function TTestRESTReadOnly._Get(const AURL: String): String;
begin
  Result := FHTTPClient.Get(AURL).ContentAsString(TEncoding.UTF8);
end;

function TTestRESTReadOnly._Post(const AURL: String; const ABody: String): String;
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

function TTestRESTReadOnly._Put(const AURL: String; const ABody: String): String;
var
  LStream: TStringStream;
begin
  LStream := TStringStream.Create(ABody, TEncoding.UTF8);
  try
    Result := FHTTPClient.Put(AURL, LStream, nil,
      [TNameValuePair.Create('Content-Type', 'application/json')])
      .ContentAsString(TEncoding.UTF8);
  finally
    LStream.Free;
  end;
end;

function TTestRESTReadOnly._Delete(const AURL: String): String;
begin
  Result := FHTTPClient.Delete(AURL).ContentAsString(TEncoding.UTF8);
end;

// Unit: class without [RESTReadOnly] → False
procedure TTestRESTReadOnly.GetRESTReadOnly_ClassWithoutAttribute_ReturnsFalse;
begin
  Assert.IsFalse(TMappingExplorer.GetRESTReadOnly(TCustomerTest));
end;

// Unit: class with [RESTReadOnly] → True
procedure TTestRESTReadOnly.GetRESTReadOnly_ClassWithAttribute_ReturnsTrue;
begin
  Assert.IsTrue(TMappingExplorer.GetRESTReadOnly(TProductTest));
end;

// Integration: GET on read-only resource must succeed (SELECT is never blocked)
procedure TTestRESTReadOnly.Get_ReadOnlyResource_Succeeds;
var
  LResult: String;
begin
  LResult := _Get(_BuildURL('ProductTest'));
  Assert.IsFalse(LResult.Contains(cREADONLY_MSG),
    'GET should not return read-only error but got: ' + LResult);
end;

// Integration: POST on read-only resource must return error JSON
procedure TTestRESTReadOnly.Post_ReadOnlyResource_ReturnsReadOnlyError;
var
  LResult: String;
begin
  LResult := _Post(_BuildURL('ProductTest'),
    '{"name":"Blocked","price":9.99}');
  Assert.Contains(LResult, cREADONLY_MSG,
    'POST on read-only resource must return read-only error, got: ' + LResult);
end;

// Integration: PUT on read-only resource must return error JSON
procedure TTestRESTReadOnly.Put_ReadOnlyResource_ReturnsReadOnlyError;
var
  LResult: String;
begin
  LResult := _Put(_BuildURL('ProductTest'),
    '{"id":1,"name":"Blocked","price":9.99}');
  Assert.Contains(LResult, cREADONLY_MSG,
    'PUT on read-only resource must return read-only error, got: ' + LResult);
end;

// Integration: DELETE on read-only resource must return error JSON
procedure TTestRESTReadOnly.Delete_ReadOnlyResource_ReturnsReadOnlyError;
var
  LResult: String;
begin
  LResult := _Delete(_BuildURL('ProductTest(1)'));
  Assert.Contains(LResult, cREADONLY_MSG,
    'DELETE on read-only resource must return read-only error, got: ' + LResult);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRESTReadOnly);

end.
