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

(* ISSUE #376 - WHETHER THE TRANSPORT'S ERROR ENVELOPE IS STILL A JSON DOCUMENT
  AFTER THE EXCEPTION MESSAGE IS PUT INSIDE IT.

  WHAT IS UNDER TEST

  cEXCEPTION and the four handlers that Format it, in
  TRESTServerHorse.AddResources - one per verb. The envelope names a single
  key whose VALUE IS A JSON STRING, and the exception message goes into that
  string. A quote, a backslash or a control character in the message therefore
  closes or corrupts the string it was pasted into, and the answer stops being
  a document. Anchored by SYMBOL: cEXCEPTION, TRESTServerHorse.AddResources.

  WHY AN UNPARSEABLE ENVELOPE IS THE WHOLE DEFECT AND NOT A COSMETIC ONE

  TCustomRESTResponse.GetJSONValue answers nil for a body Delphi's parser
  refuses; TRESTClientHorse hands that nil to TJanusClient.ResponseValue,
  which raises cRESTNOJSONVALUE - "the body was empty, was not JSON, or the
  configured root element is absent from it". So the consumer of a REST write
  is told ITS OWN PAYLOAD was unreadable, about an answer the SERVER wrote.
  Every anchor here is by SYMBOL, in Janus.Client.Horse and Janus.Client.

  THE TWO MESSAGE SHAPES THIS FIXTURE DRIVES, AND WHY BOTH ARE REAL

  ONE - a message that is plain prose. ParseDelete's not-found signal is the
  live case issue #376 was opened on, and it used to be raised as a JSON
  DOCUMENT rather than as a sentence. Both halves of the repair meet here: the
  message became prose, and the envelope escapes whatever it is given.

  TWO - a message that is STILL a JSON document, quotes and all.
  cRESOURCENOTREGISTER is spelled that way and is NOT changed by issue #376, so
  it is the standing proof that the escape - and not the wording of one
  message - is what keeps the envelope parseable. It reaches the wire through
  ParseUpdate's nil-LClassType raise. Anchored by SYMBOL.

  WHAT THIS FIXTURE DELIBERATELY DOES NOT SETTLE

  THE ENVELOPE'S SHAPE. `Exception` stays a single JSON STRING key, on purpose:
  consumers already read it as a string, and nesting a document under it would
  be a wire-contract change. So the clauses below assert that the value PARSES
  and that it carries the message TEXT - never that the text is itself further
  structured.

  THE STATUS. Everything this transport emits is 200, errors included, and no
  clause here pins it.

  ANCHORS ARE BY SYMBOL, NEVER BY file:line. *)

unit Test.Janus.Server.ExceptionEnvelope;

interface

uses
  SysUtils,
  Classes,
  Variants,
  JSON,
  Net.HTTPClient,
  Net.URLClient,
  DUnitX.TestFramework,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Comp.Client,
  RestHorseTest.Base;

type
  [TestFixture]
  TTestServerExceptionEnvelope = class(TRestHorseTestBase)
  private
    FProbeDb: TFDConnection;
    FHttp: THTTPClient;
    function _Delete(const AResource: String): IHTTPResponse;
    function _Put(const AResource, ABody: String): IHTTPResponse;
    function _Body(const AResponse: IHTTPResponse): String;
    /// True when Delphi's own parser accepts the body. That is the SAME
    /// question TCustomRESTResponse.GetJSONValue asks before it answers nil,
    /// and a nil there is what makes TJanusClient.ResponseValue raise.
    function _Parses(const ABody: String): Boolean;
    /// The value of the envelope's only key, read the way a consumer reads it.
    /// Answers cUNREADABLE when the body is not a document, or is a document
    /// with no such string key - so a failure PRINTS which of the two happened
    /// instead of just "expected X".
    function _ExceptionField(const ABody: String): String;
    function _Scalar(const ASQL: String): String;
    function _Count(const ASQL: String): Integer;
  public
    [SetupFixture]
    procedure SetupFixture;
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// PREMISE. Without it the clauses below could be measuring a route that
    /// never reached ParseDelete's not-found signal at all.
    [Test]
    procedure Premise_TheKeyTheDefectClausesUseNamesNoRow;

    /// PREMISE. The answer has to CARRY the not-found signal before it is
    /// worth asking whether it parses.
    [Test]
    procedure Premise_TheDeleteThatMatchesNoRowSaysSo;

    /// THE HEADLINE, AND THE LIVE CASE OF THE ISSUE. The envelope of the
    /// DELETE not-found answer has to be a JSON document.
    [Test]
    procedure ADeleteThatMatchesNoRow_TheEnvelopeMustParseAsJson;

    /// ...and parsing is not enough: the one key the envelope names has to
    /// hand the consumer back the readable message.
    [Test]
    procedure ADeleteThatMatchesNoRow_TheExceptionFieldMustCarryTheMessage;

    /// THE ESCAPE ITSELF, over a message that still holds quotes.
    /// cRESOURCENOTREGISTER is a JSON document and is untouched by this issue,
    /// so this clause dies for a repair that only reworded one message.
    [Test]
    procedure AMessageBearingQuotes_TheEnvelopeMustParseAsJson;

    /// ...and the quoted message has to come back out BYTE FOR BYTE. This is
    /// the clause that dies for an escape that strips or mangles instead of
    /// escaping.
    [Test]
    procedure AMessageBearingQuotes_TheExceptionFieldMustCarryItVerbatim;

    /// CONTROL, GREEN ON BOTH SIDES. The answers this server RETURNS travel
    /// through Res.Send unwrapped, and the envelope must not appear over them.
    /// A repair that wrapped every answer would satisfy every clause above.
    [Test]
    procedure Control_ASuccessfulDeleteIsNotWrappedByTheEnvelope;
  end;

implementation

const
  cTIMEOUT_MS  = 5000;
  cGHOSTKEY    = '999999';
  cUNMAPPED    = 'NotAnEntityAtAll';
  cENVELOPEKEY = 'Exception';
  /// Answered by _ExceptionField when the body is not a document, or names no
  /// such string key. It is not a value any message can spell.
  cUNREADABLE  = '<NO READABLE Exception FIELD>';
  /// Spelled by ParseDelete's not-found raise and by nothing else in Source.
  cDELETENOTFOUND = 'No records found to delete, with the filter entered!';
  /// Spelled by cRESOURCENOTREGISTER, with AQuery.ResourceName filled in. It
  /// is a JSON document, and this fixture depends on it staying one.
  cNOTREGISTERED =
    '{"exception":"Resource [T' + cUNMAPPED + '] not registered on the server!"}';
  /// Any body at all, so the PUT reaches the nil-LClassType raise of
  /// ParseUpdate rather than dying earlier.
  cANYBODY = '{"id":1}';
  /// Spelled by cRESOURCEDELETE in Janus.Server.Resource.
  cDELETEOK =
    '{"result":"Resource TCustomerTest delete command executed successfully"}';

{ TTestServerExceptionEnvelope }

procedure TTestServerExceptionEnvelope.SetupFixture;
begin
  FPrefix := 'api/Janus';
  inherited SetupFixture;
end;

procedure TTestServerExceptionEnvelope.Setup;
begin
  inherited Setup;
  FProbeDb := TFDConnection.Create(nil);
  FProbeDb.Params.DriverID := 'SQLite';
  FProbeDb.Params.Database := cTEST_DB_PATH;
  FProbeDb.Params.Values['OpenMode'] := 'CreateUTF8';
  FProbeDb.ResourceOptions.SilentMode := True;
  FProbeDb.Connected := True;
  FHttp := THTTPClient.Create;
  FHttp.ConnectionTimeout := cTIMEOUT_MS;
  FHttp.ResponseTimeout := cTIMEOUT_MS;
  SeedCustomers;
end;

procedure TTestServerExceptionEnvelope.TearDown;
begin
  FreeAndNil(FHttp);
  if Assigned(FProbeDb) then
  begin
    FProbeDb.Connected := False;
    FreeAndNil(FProbeDb);
  end;
  inherited TearDown;
end;

function TTestServerExceptionEnvelope._Delete(
  const AResource: String): IHTTPResponse;
begin
  Result := FHttp.Delete(BuildResourceURL(AResource));
end;

function TTestServerExceptionEnvelope._Put(const AResource,
  ABody: String): IHTTPResponse;
var
  LStream: TStringStream;
begin
  LStream := TStringStream.Create(ABody, TEncoding.UTF8);
  try
    Result := FHttp.Put(BuildResourceURL(AResource), LStream, nil,
      [TNameValuePair.Create('Content-Type', 'application/json')]);
  finally
    LStream.Free;
  end;
end;

function TTestServerExceptionEnvelope._Body(
  const AResponse: IHTTPResponse): String;
begin
  Result := AResponse.ContentAsString(TEncoding.UTF8);
end;

function TTestServerExceptionEnvelope._Parses(const ABody: String): Boolean;
var
  LValue: TJSONValue;
begin
  LValue := TJSONObject.ParseJSONValue(ABody);
  try
    Result := LValue <> nil;
  finally
    LValue.Free;
  end;
end;

function TTestServerExceptionEnvelope._ExceptionField(
  const ABody: String): String;
var
  LValue: TJSONValue;
begin
  Result := cUNREADABLE;
  LValue := TJSONObject.ParseJSONValue(ABody);
  try
    if LValue is TJSONObject then
      if not TJSONObject(LValue).TryGetValue<String>(cENVELOPEKEY, Result) then
        Result := cUNREADABLE;
  finally
    LValue.Free;
  end;
end;

function TTestServerExceptionEnvelope._Scalar(const ASQL: String): String;
var
  LValue: Variant;
begin
  LValue := FProbeDb.ExecSQLScalar(ASQL);
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Result := '<null>'
  else
    Result := VarToStr(LValue);
end;

function TTestServerExceptionEnvelope._Count(const ASQL: String): Integer;
begin
  Result := StrToIntDef(_Scalar(ASQL), -99);
end;

procedure TTestServerExceptionEnvelope.Premise_TheKeyTheDefectClausesUseNamesNoRow;
begin
  Assert.AreEqual(0,
    _Count('SELECT COUNT(*) FROM customer_test WHERE id = ' + cGHOSTKEY),
    'premise: the key the defect clauses use must name no row, or they are '
    + 'not measuring "not found" at all.');
end;

procedure TTestServerExceptionEnvelope.Premise_TheDeleteThatMatchesNoRowSaysSo;
var
  LBody: String;
begin
  LBody := _Body(_Delete('CustomerTest(' + cGHOSTKEY + ')'));
  Assert.IsTrue(LBody.Contains(cDELETENOTFOUND),
    'premise: the DELETE under test did not come out of ParseDelete''s '
    + 'not-found raise. That sentence is spelled there and nowhere else in '
    + 'Source, so the clauses below are measuring an unknown route until this '
    + 'one passes. Body was: [' + LBody + ']');
end;

procedure TTestServerExceptionEnvelope.ADeleteThatMatchesNoRow_TheEnvelopeMustParseAsJson;
var
  LBody: String;
begin
  LBody := _Body(_Delete('CustomerTest(' + cGHOSTKEY + ')'));
  Assert.IsTrue(_Parses(LBody),
    'THE ERROR ENVELOPE OF A DELETE THAT LOCATED NO ROW IS NOT A JSON '
    + 'DOCUMENT. cEXCEPTION pastes the exception message into a `%s` that '
    + 'sits INSIDE a JSON string, so a message carrying a quote, a backslash '
    + 'or a control character closes that string early and the body stops '
    + 'parsing. TCustomRESTResponse.GetJSONValue then answers nil and '
    + 'TJanusClient.ResponseValue raises cRESTNOJSONVALUE, which blames the '
    + 'CALLER''s payload for an answer the server wrote. Body was: ['
    + LBody + ']');
end;

procedure TTestServerExceptionEnvelope.ADeleteThatMatchesNoRow_TheExceptionFieldMustCarryTheMessage;
var
  LBody: String;
begin
  LBody := _Body(_Delete('CustomerTest(' + cGHOSTKEY + ')'));
  Assert.AreEqual(cDELETENOTFOUND, _ExceptionField(LBody),
    'The envelope''s only key did not hand back the message ParseDelete '
    + 'raised. A consumer that reads `' + cENVELOPEKEY + '` as a string is '
    + 'the reason that key stays a STRING rather than becoming a nested '
    + 'document. Body was: [' + LBody + ']');
end;

procedure TTestServerExceptionEnvelope.AMessageBearingQuotes_TheEnvelopeMustParseAsJson;
var
  LBody: String;
begin
  LBody := _Body(_Put(cUNMAPPED, cANYBODY));
  Assert.IsTrue(LBody.Contains('not registered'),
    'premise: this PUT did not reach the nil-LClassType raise of ParseUpdate, '
    + 'so it is not carrying a quoted message at all. Body was: ['
    + LBody + ']');
  Assert.IsTrue(_Parses(LBody),
    'THE ESCAPE IS WHAT KEEPS THE ENVELOPE PARSEABLE, AND THIS MESSAGE PROVES '
    + 'IT IS THE ESCAPE AND NOT THE WORDING. cRESOURCENOTREGISTER is itself a '
    + 'JSON document, quotes included, and issue #376 does not change it - so '
    + 'if this body does not parse, the envelope is still interpolating raw '
    + 'text into a JSON string. Body was: [' + LBody + ']');
end;

procedure TTestServerExceptionEnvelope.AMessageBearingQuotes_TheExceptionFieldMustCarryItVerbatim;
var
  LBody: String;
begin
  LBody := _Body(_Put(cUNMAPPED, cANYBODY));
  Assert.AreEqual(cNOTREGISTERED, _ExceptionField(LBody),
    'The quoted message did not survive the envelope BYTE FOR BYTE. Escaping '
    + 'is reversible and stripping is not: a repair that deletes or replaces '
    + 'the quotes would make the body parse and would still lose what the '
    + 'server said. Body was: [' + LBody + ']');
end;

procedure TTestServerExceptionEnvelope.Control_ASuccessfulDeleteIsNotWrappedByTheEnvelope;
var
  LId: String;
  LBody: String;
begin
  LId := _Scalar('SELECT MIN(id) FROM customer_test');
  Assert.AreNotEqual('<null>', LId, 'premise: the seed wrote no row at all.');
  LBody := _Body(_Delete('CustomerTest(' + LId + ')'));
  Assert.AreEqual(cDELETEOK, LBody,
    'A DELETE that DID locate its row came back wrapped, or came back saying '
    + 'something else. Only an EXCEPTION reaches the envelope; what this class '
    + 'RETURNS leaves through Res.Send as it stands. Got: [' + LBody + ']');
  Assert.AreEqual(cUNREADABLE, _ExceptionField(LBody),
    'A successful answer names the envelope''s key. The envelope would then '
    + 'be over every answer, which makes every clause above pass for the '
    + 'wrong reason. Got: [' + LBody + ']');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestServerExceptionEnvelope);

end.
