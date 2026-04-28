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

unit Test.Janus.REST.Horse.MethodGrant;

interface

uses
  SysUtils,
  Classes,
  Net.HTTPClient,
  Net.URLClient,
  DUnitX.TestFramework,
  RestHorseTest.Base,
  RestHorseTest.Models;

type
  [TestFixture]
  TTestRESTMethodGrant = class(TRestHorseTestBase)
  private
    FHTTPClient: THTTPClient;
    function _BuildURL(const AResource: String): String;
    function _Get(const AURL: String): String;
    function _Post(const AURL: String; const ABody: String): String;
    function _Put(const AURL: String; const ABody: String): String;
    function _Delete(const AURL: String): String;
    function _GetStatusCode(const AURL: String): Integer;
    function _PostStatusCode(const AURL: String; const ABody: String): Integer;
    function _PutStatusCode(const AURL: String; const ABody: String): Integer;
    function _DeleteStatusCode(const AURL: String): Integer;
  public
    [SetupFixture]
    procedure SetupFixture;
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // CA-005: [RESTAllowGET] only — POST/PUT/DELETE blocked
    [Test]
    procedure GETOnly_Get_Succeeds;
    [Test]
    procedure GETOnly_Post_ReturnsVerbNotAllowedError;
    [Test]
    procedure GETOnly_Put_ReturnsVerbNotAllowedError;
    [Test]
    procedure GETOnly_Delete_ReturnsVerbNotAllowedError;

    // CA-006: [RESTAllowGET] + [RESTAllowPOST] — GET and POST succeed; PUT/DELETE blocked
    [Test]
    procedure GETAndPOST_Get_Succeeds;
    [Test]
    procedure GETAndPOST_Post_Succeeds;
    [Test]
    procedure GETAndPOST_Put_ReturnsVerbNotAllowedError;
    [Test]
    procedure GETAndPOST_Delete_ReturnsVerbNotAllowedError;

    // CA-007: all four [RESTAllow*] — all verbs pass
    [Test]
    procedure FullAllow_Get_Succeeds;
    [Test]
    procedure FullAllow_Post_Succeeds;
    [Test]
    procedure FullAllow_Put_Succeeds;
    [Test]
    procedure FullAllow_Delete_Succeeds;

    // CA-008: [RESTReadOnly] + [RESTAllowPOST] — [RESTReadOnly] wins
    [Test]
    procedure ReadOnlyWithPOST_Get_Succeeds;
    [Test]
    procedure ReadOnlyWithPOST_Post_ReturnsReadOnlyError;

    // CA-009: no attribute — all verbs pass (unchanged behavior)
    [Test]
    procedure NoAttribute_Get_Succeeds;
    [Test]
    procedure NoAttribute_Post_Succeeds;
  end;

implementation

const
  cTIMEOUT_MS = 2000;
  cVERBNOTALLOWED_FRAGMENT = 'not allowed for';
  cREADONLY_MSG = 'read-only (RESTReadOnly)';

{ TTestRESTMethodGrant }

procedure TTestRESTMethodGrant.SetupFixture;
begin
  FPrefix := 'api/Janus';
  inherited SetupFixture;
end;

procedure TTestRESTMethodGrant.Setup;
begin
  inherited Setup;
  FHTTPClient := THTTPClient.Create;
  FHTTPClient.ConnectionTimeout := cTIMEOUT_MS;
  FHTTPClient.ResponseTimeout := cTIMEOUT_MS;
  SeedCustomers;
  ExecuteSQL('INSERT INTO grant_get_only_test (name) VALUES (''Seed'')');
  ExecuteSQL('INSERT INTO grant_full_allow_test (name) VALUES (''Seed'')');
end;

procedure TTestRESTMethodGrant.TearDown;
begin
  FreeAndNil(FHTTPClient);
  inherited TearDown;
end;

function TTestRESTMethodGrant._BuildURL(const AResource: String): String;
begin
  Result := BuildResourceURL(AResource);
end;

function TTestRESTMethodGrant._Get(const AURL: String): String;
begin
  Result := FHTTPClient.Get(AURL).ContentAsString(TEncoding.UTF8);
end;

function TTestRESTMethodGrant._Post(const AURL: String; const ABody: String): String;
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

function TTestRESTMethodGrant._Put(const AURL: String; const ABody: String): String;
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

function TTestRESTMethodGrant._Delete(const AURL: String): String;
begin
  Result := FHTTPClient.Delete(AURL).ContentAsString(TEncoding.UTF8);
end;

function TTestRESTMethodGrant._GetStatusCode(const AURL: String): Integer;
begin
  Result := FHTTPClient.Get(AURL).StatusCode;
end;

function TTestRESTMethodGrant._PostStatusCode(const AURL: String;
  const ABody: String): Integer;
var
  LStream: TStringStream;
begin
  LStream := TStringStream.Create(ABody, TEncoding.UTF8);
  try
    Result := FHTTPClient.Post(AURL, LStream, nil,
      [TNameValuePair.Create('Content-Type', 'application/json')]).StatusCode;
  finally
    LStream.Free;
  end;
end;

function TTestRESTMethodGrant._PutStatusCode(const AURL: String;
  const ABody: String): Integer;
var
  LStream: TStringStream;
begin
  LStream := TStringStream.Create(ABody, TEncoding.UTF8);
  try
    Result := FHTTPClient.Put(AURL, LStream, nil,
      [TNameValuePair.Create('Content-Type', 'application/json')]).StatusCode;
  finally
    LStream.Free;
  end;
end;

function TTestRESTMethodGrant._DeleteStatusCode(const AURL: String): Integer;
begin
  Result := FHTTPClient.Delete(AURL).StatusCode;
end;

// CA-005: [RESTAllowGET] only

procedure TTestRESTMethodGrant.GETOnly_Get_Succeeds;
var
  LResult: String;
begin
  LResult := _Get(_BuildURL('GrantGETOnly'));
  Assert.IsFalse(LResult.Contains(cVERBNOTALLOWED_FRAGMENT),
    'GET must succeed on [RESTAllowGET] class, got: ' + LResult);
end;

procedure TTestRESTMethodGrant.GETOnly_Post_ReturnsVerbNotAllowedError;
var
  LResult: String;
begin
  LResult := _Post(_BuildURL('GrantGETOnly'), '{"name":"Blocked"}');
  Assert.IsTrue(LResult.Contains(cVERBNOTALLOWED_FRAGMENT),
    'POST must return verb-not-allowed error, got: ' + LResult);
  Assert.IsTrue(LResult.Contains('POST'),
    'Error message must contain verb name, got: ' + LResult);
end;

procedure TTestRESTMethodGrant.GETOnly_Put_ReturnsVerbNotAllowedError;
var
  LResult: String;
begin
  LResult := _Put(_BuildURL('GrantGETOnly'), '{"id":1,"name":"Blocked"}');
  Assert.IsTrue(LResult.Contains(cVERBNOTALLOWED_FRAGMENT),
    'PUT must return verb-not-allowed error, got: ' + LResult);
end;

procedure TTestRESTMethodGrant.GETOnly_Delete_ReturnsVerbNotAllowedError;
var
  LResult: String;
begin
  LResult := _Delete(_BuildURL('GrantGETOnly(1)'));
  Assert.IsTrue(LResult.Contains(cVERBNOTALLOWED_FRAGMENT),
    'DELETE must return verb-not-allowed error, got: ' + LResult);
end;

// CA-006: [RESTAllowGET] + [RESTAllowPOST]

procedure TTestRESTMethodGrant.GETAndPOST_Get_Succeeds;
var
  LResult: String;
begin
  LResult := _Get(_BuildURL('GrantGETAndPOST'));
  Assert.IsFalse(LResult.Contains(cVERBNOTALLOWED_FRAGMENT),
    'GET must succeed on GET+POST class, got: ' + LResult);
end;

procedure TTestRESTMethodGrant.GETAndPOST_Post_Succeeds;
var
  LResult: String;
begin
  LResult := _Post(_BuildURL('GrantGETAndPOST'), '{"name":"NewRecord"}');
  Assert.IsFalse(LResult.Contains(cVERBNOTALLOWED_FRAGMENT),
    'POST must succeed on GET+POST class, got: ' + LResult);
end;

procedure TTestRESTMethodGrant.GETAndPOST_Put_ReturnsVerbNotAllowedError;
var
  LResult: String;
begin
  LResult := _Put(_BuildURL('GrantGETAndPOST'), '{"id":1,"name":"Blocked"}');
  Assert.IsTrue(LResult.Contains(cVERBNOTALLOWED_FRAGMENT),
    'PUT must return verb-not-allowed error, got: ' + LResult);
end;

procedure TTestRESTMethodGrant.GETAndPOST_Delete_ReturnsVerbNotAllowedError;
var
  LResult: String;
begin
  LResult := _Delete(_BuildURL('GrantGETAndPOST(1)'));
  Assert.IsTrue(LResult.Contains(cVERBNOTALLOWED_FRAGMENT),
    'DELETE must return verb-not-allowed error, got: ' + LResult);
end;

// CA-007: all four [RESTAllow*]

procedure TTestRESTMethodGrant.FullAllow_Get_Succeeds;
var
  LResult: String;
begin
  LResult := _Get(_BuildURL('GrantFullAllow'));
  Assert.IsFalse(LResult.Contains(cVERBNOTALLOWED_FRAGMENT),
    'GET must succeed on full-allow class, got: ' + LResult);
end;

procedure TTestRESTMethodGrant.FullAllow_Post_Succeeds;
var
  LResult: String;
begin
  LResult := _Post(_BuildURL('GrantFullAllow'), '{"name":"NewFull"}');
  Assert.IsFalse(LResult.Contains(cVERBNOTALLOWED_FRAGMENT),
    'POST must succeed on full-allow class, got: ' + LResult);
end;

procedure TTestRESTMethodGrant.FullAllow_Put_Succeeds;
var
  LResult: String;
begin
  LResult := _Put(_BuildURL('GrantFullAllow'), '{"id":1,"name":"UpdatedFull"}');
  Assert.IsFalse(LResult.Contains(cVERBNOTALLOWED_FRAGMENT),
    'PUT must succeed on full-allow class, got: ' + LResult);
end;

procedure TTestRESTMethodGrant.FullAllow_Delete_Succeeds;
var
  LResult: String;
begin
  LResult := _Delete(_BuildURL('GrantFullAllow(1)'));
  Assert.IsFalse(LResult.Contains(cVERBNOTALLOWED_FRAGMENT),
    'DELETE must succeed on full-allow class, got: ' + LResult);
end;

// CA-008: [RESTReadOnly] + [RESTAllowPOST] — RESTReadOnly wins

procedure TTestRESTMethodGrant.ReadOnlyWithPOST_Get_Succeeds;
var
  LResult: String;
begin
  LResult := _Get(_BuildURL('GrantReadOnlyWithPOST'));
  Assert.IsFalse(LResult.Contains(cREADONLY_MSG),
    'GET must succeed on read-only+POST class, got: ' + LResult);
  Assert.IsFalse(LResult.Contains(cVERBNOTALLOWED_FRAGMENT),
    'GET must not return verb error, got: ' + LResult);
end;

procedure TTestRESTMethodGrant.ReadOnlyWithPOST_Post_ReturnsReadOnlyError;
var
  LResult: String;
begin
  LResult := _Post(_BuildURL('GrantReadOnlyWithPOST'), '{"name":"ShouldFail"}');
  Assert.IsTrue(LResult.Contains(cREADONLY_MSG),
    '[RESTReadOnly] must win over [RESTAllowPOST], got: ' + LResult);
end;

// CA-009: no attribute — all verbs pass

procedure TTestRESTMethodGrant.NoAttribute_Get_Succeeds;
var
  LResult: String;
begin
  LResult := _Get(_BuildURL('CustomerTest'));
  Assert.IsFalse(LResult.Contains(cVERBNOTALLOWED_FRAGMENT),
    'GET must pass on no-attribute class, got: ' + LResult);
end;

procedure TTestRESTMethodGrant.NoAttribute_Post_Succeeds;
var
  LResult: String;
begin
  LResult := _Post(_BuildURL('CustomerTest'),
    '{"name":"TestNoAttr","email":"test@test.com","active":true}');
  Assert.IsFalse(LResult.Contains(cVERBNOTALLOWED_FRAGMENT),
    'POST must pass on no-attribute class, got: ' + LResult);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRESTMethodGrant);

end.
