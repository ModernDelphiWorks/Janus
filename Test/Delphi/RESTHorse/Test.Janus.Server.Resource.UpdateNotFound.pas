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

(* ISSUE #363 - WHAT A PUT ANSWERS WHEN IT LOCATES NO ROW.

  WHAT IS UNDER TEST

  The two bare Exits of TAppResourceBase.ParseUpdate: the one taken when
  TMappingExplorer answers no class for the resource name, and the one taken
  when TRESTObjectSet.FindOne answers nil for the predicate built out of the
  body's primary key. Both leave Result at '', and TRESTServerHorse's PUT route
  hands that straight to Res.Send - so the request completes with an EMPTY BODY.
  Anchored by SYMBOL: ParseUpdate, TRESTServerHorse.AddResources.

  WHY AN EMPTY BODY IS NOT A NEUTRAL ANSWER

  It is the shape the Janus REST CLIENT cannot read. TRESTClientHorse.DoPUT
  passes Response.JSONValue to TJanusClient.ResponseValue, which raises
  cRESTNOJSONVALUE - "The response carried no JSON value: the body was empty,
  was not JSON, or the configured root element is absent from it." So a PUT that
  named a key no row carries comes back to the caller as a complaint ABOUT THE
  PAYLOAD IT SENT. All three anchored by SYMBOL, in Janus.Client.Horse and
  Janus.Client.

  MEASURED ON 8f5864f, OVER A LIVE HORSE SERVER, BEFORE THE REPAIR

    PUT    CustomerTest {"id":999999,...}   ->  200  LEN=0   ParseJSONValue=nil
    PUT    CustomerTest {"id":1,...}        ->  200  LEN=72  TJSONObject
    PUT    NotAnEntityAtAll {...}           ->  200  LEN=0   ParseJSONValue=nil
    PUT    CustomerTest "this is not json"  ->  200  LEN=0   ParseJSONValue=nil
    DELETE CustomerTest(999999)             ->  200  LEN=82  ParseJSONValue=nil
    GET    CustomerTest(999999)             ->  200  LEN=4   TJSONNull

  Three separate mistakes - a key that names no row, a resource that is not
  registered, and a body that is not JSON at all - come back as the SAME empty
  answer, so the wire cannot tell them apart either.

  WHY THE ANSWER IS RETURNED AND NOT RAISED, WHICH IS THE WHOLE DESIGN

  The house already has a not-found signal, and it is ParseDelete's: it RAISES
  Exception.Create with a message that is itself a JSON document. That looks
  like the precedent to copy, and the fifth measurement above is why it is not.
  TRESTServerHorse's four routes catch the exception and emit Format with
  cEXCEPTION - which pastes a JSON document raw INSIDE a JSON string. The 82
  bytes DELETE answers are

    {"Exception": "{"result":"No records found to delete, with the filter entered!"}"}

  and that does not parse. So the sibling's not-found answer reaches the client
  as the very same cRESTNOJSONVALUE this issue was opened about. Copying it
  verbatim would have reproduced the defect inside the repair.

  What is copied is its WORDING and its intent - say so in the body. What is
  NOT copied is the raise: the answer leaves as the function's Result, exactly
  like cRESOURCEUPDATE, cRESOURCEDELETE and cRESOURCEINSERT, which travel
  through Res.Send unwrapped and which the second measurement shows do parse.

  AND THE UNREGISTERED-RESOURCE EXIT IS REPAIRED THE OTHER WAY, ON PURPOSE.
  "Resource not registered" is not a question about data, and its two siblings
  in this very class - ParseInsert and ParseFind - both RAISE
  cRESOURCENOTREGISTER for it. PUT was the only one of the three that answered
  silence. It now raises what they raise, which means it also inherits the
  wrapper defect above: the clause below asserts the resource NAME travels, and
  deliberately does not assert that the document parses, because on this route
  it does not. That is the wrapper's defect and not ParseUpdate's, it is
  reported rather than repaired here, and the characterisation clause at the end
  pins it so that whoever repairs it finds this note.

  WHAT THIS FIXTURE DOES NOT SETTLE

  The STATUS. Everything the Horse transport emits is 200, errors included, and
  no seam between TAppResourceBase and any of the five transports carries a
  status at all. A 404 would also not have removed the symptom this issue
  reports: ResponseValue raises on a nil JSONValue whatever the status is. So
  the body is the repair and the status is a contract question for the owner;
  no clause here pins 200, so answering 404 later breaks nothing in this file.

  ANCHORS ARE BY SYMBOL, NEVER BY file:line. *)

unit Test.Janus.Server.Resource.UpdateNotFound;

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
  TTestServerResourceUpdateNotFound = class(TRestHorseTestBase)
  private
    FProbeDb: TFDConnection;
    FHttp: THTTPClient;
    function _Put(const AResource, ABody: String): IHTTPResponse;
    function _Delete(const AResource: String): IHTTPResponse;
    function _Body(const AResponse: IHTTPResponse): String;
    /// True when Delphi's own parser accepts the body. That is the SAME
    /// question TCustomRESTResponse.GetJSONValue asks before it answers nil,
    /// and a nil there is what makes TJanusClient.ResponseValue raise.
    function _Parses(const ABody: String): Boolean;
    function _Scalar(const ASQL: String): String;
    function _Count(const ASQL: String): Integer;
  public
    [SetupFixture]
    procedure SetupFixture;
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// PREMISE. Without this the clauses below say nothing: they would be
    /// measuring some other route, or a route that is broken for every PUT.
    /// The body asserted here is spelled by cRESOURCEUPDATE and by nothing
    /// else in Source, so reading it back proves the request reached
    /// ParseUpdate and came out of its successful end.
    [Test]
    procedure Premise_ThePutRouteReachesParseUpdateAndItsHappyPath;

    /// PREMISE. The key the defect clauses use has to name no row, or
    /// "not found" is not what is being measured.
    [Test]
    procedure Premise_TheKeyTheDefectClausesUseNamesNoRow;

    /// THE HEADLINE. An empty body is the shape the client cannot read.
    [Test]
    procedure APutThatMatchesNoRow_MustNotAnswerAnEmptyBody;

    /// ...and "not empty" is not enough: it has to be a document. This is the
    /// clause that dies for a repair that answers a bare sentence, and it is
    /// the one that stands directly in front of cRESTNOJSONVALUE.
    [Test]
    procedure APutThatMatchesNoRow_TheAnswerMustParseAsJson;

    /// ...and the document has to say WHICH mistake was made. A parseable
    /// answer that does not name the reason still sends the caller looking at
    /// its payload.
    [Test]
    procedure APutThatMatchesNoRow_TheAnswerMustSayNoRecordWasFound;

    /// ...and it must name the resource, like every other answer of this class.
    [Test]
    procedure APutThatMatchesNoRow_TheAnswerMustNameTheResource;

    /// CONTROL. The guard against the cheapest wrong repair - answering the
    /// success document for a write that did not happen. Green before the
    /// repair (the body was empty) and green after.
    [Test]
    procedure APutThatMatchesNoRow_TheAnswerMustNotClaimSuccess;

    /// CONTROL. Green on both sides. A repair that starts INSERTING the row it
    /// could not find would satisfy every clause above.
    [Test]
    procedure APutThatMatchesNoRow_MustNotWriteOrTouchAnyRow;

    /// THE SECOND EXIT. A PUT naming a resource the server never registered
    /// answered the same silence, while GET and POST both name it.
    [Test]
    procedure APutToAnUnregisteredResource_MustNotAnswerAnEmptyBody;

    /// ...and it has to name the resource that was asked for. Deliberately NOT
    /// a parse assertion - see the header: this answer travels through the
    /// transport's exception wrapper, which is where it stops being JSON.
    [Test]
    procedure APutToAnUnregisteredResource_TheAnswerMustNameTheResource;

    /// CHARACTERISATION, GREEN BEFORE AND AFTER. It pins the measurement the
    /// design above rests on: the house's OTHER not-found answer is raised, and
    /// arrives unparseable. When the transport wrapper is repaired this clause
    /// goes RED, and that is the signal to come read the header - it is not a
    /// regression.
    [Test]
    procedure Characterisation_TheRaisedNotFoundOfDeleteDoesNotParse;
  end;

implementation

const
  cTIMEOUT_MS = 5000;
  cGHOSTKEY   = '999999';
  cGHOSTBODY  = '{"id":999999,"name":"Ghost","email":"ghost@test.com","active":true}';
  cUNMAPPED   = 'NotAnEntityAtAll';
  /// Spelled by cRESOURCEUPDATE in Janus.Server.Resource and by nothing else.
  cHAPPYBODY  = '{"result":"Resource TCustomerTest update command executed successfully"}';

{ TTestServerResourceUpdateNotFound }

procedure TTestServerResourceUpdateNotFound.SetupFixture;
begin
  FPrefix := 'api/Janus';
  inherited SetupFixture;
end;

procedure TTestServerResourceUpdateNotFound.Setup;
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

procedure TTestServerResourceUpdateNotFound.TearDown;
begin
  FreeAndNil(FHttp);
  if Assigned(FProbeDb) then
  begin
    FProbeDb.Connected := False;
    FreeAndNil(FProbeDb);
  end;
  inherited TearDown;
end;

function TTestServerResourceUpdateNotFound._Put(const AResource,
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

function TTestServerResourceUpdateNotFound._Delete(
  const AResource: String): IHTTPResponse;
begin
  Result := FHttp.Delete(BuildResourceURL(AResource));
end;

function TTestServerResourceUpdateNotFound._Body(
  const AResponse: IHTTPResponse): String;
begin
  Result := AResponse.ContentAsString(TEncoding.UTF8);
end;

function TTestServerResourceUpdateNotFound._Parses(const ABody: String): Boolean;
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

function TTestServerResourceUpdateNotFound._Scalar(const ASQL: String): String;
var
  LValue: Variant;
begin
  LValue := FProbeDb.ExecSQLScalar(ASQL);
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Result := '<null>'
  else
    Result := VarToStr(LValue);
end;

function TTestServerResourceUpdateNotFound._Count(const ASQL: String): Integer;
begin
  Result := StrToIntDef(_Scalar(ASQL), -99);
end;

procedure TTestServerResourceUpdateNotFound.Premise_ThePutRouteReachesParseUpdateAndItsHappyPath;
var
  LId: String;
  LBody: String;
begin
  LId := _Scalar('SELECT MIN(id) FROM customer_test');
  Assert.AreNotEqual('<null>', LId, 'premise: the seed wrote no row at all.');
  LBody := _Body(_Put('CustomerTest',
    '{"id":' + LId + ',"name":"AliceEdited","email":"alice@test.com","active":true}'));
  Assert.AreEqual(cHAPPYBODY, LBody,
    'The PUT under test did not come out of the successful end of ParseUpdate. '
    + 'That body is spelled by cRESOURCEUPDATE and by nothing else in Source, '
    + 'so every other clause in this fixture is measuring an unknown route '
    + 'until this one passes. Got: [' + LBody + ']');
  Assert.AreEqual('AliceEdited',
    _Scalar('SELECT name FROM customer_test WHERE id = ' + LId),
    'The PUT answered success and the row did not move, so the answer this '
    + 'fixture reads back means nothing.');
end;

procedure TTestServerResourceUpdateNotFound.Premise_TheKeyTheDefectClausesUseNamesNoRow;
begin
  Assert.AreEqual(0,
    _Count('SELECT COUNT(*) FROM customer_test WHERE id = ' + cGHOSTKEY),
    'premise: the key the defect clauses use must name no row, or they are '
    + 'not measuring "not found" at all.');
end;

procedure TTestServerResourceUpdateNotFound.APutThatMatchesNoRow_MustNotAnswerAnEmptyBody;
var
  LBody: String;
begin
  LBody := _Body(_Put('CustomerTest', cGHOSTBODY));
  Assert.AreNotEqual('', LBody,
    'A PUT that located no row answered an EMPTY BODY. That is the shape '
    + 'TJanusClient.ResponseValue turns into cRESTNOJSONVALUE - a complaint '
    + 'about the payload the caller sent - so the one mistake the server knows '
    + 'about is the one thing the answer does not carry.');
end;

procedure TTestServerResourceUpdateNotFound.APutThatMatchesNoRow_TheAnswerMustParseAsJson;
var
  LBody: String;
begin
  LBody := _Body(_Put('CustomerTest', cGHOSTBODY));
  Assert.IsTrue(_Parses(LBody),
    'The answer of a PUT that located no row is not a JSON document, so '
    + 'Response.JSONValue is nil and the client raises cRESTNOJSONVALUE '
    + 'anyway. Being non-empty is not the contract; being readable is. '
    + 'Body was: [' + LBody + ']');
end;

procedure TTestServerResourceUpdateNotFound.APutThatMatchesNoRow_TheAnswerMustSayNoRecordWasFound;
var
  LBody: String;
begin
  LBody := _Body(_Put('CustomerTest', cGHOSTBODY));
  Assert.IsTrue(LBody.Contains('found no record'),
    'The answer does not say that no record was found. A parseable answer '
    + 'that does not name the reason still sends the caller looking at its '
    + 'own payload. Body was: [' + LBody + ']');
end;

procedure TTestServerResourceUpdateNotFound.APutThatMatchesNoRow_TheAnswerMustNameTheResource;
var
  LBody: String;
begin
  LBody := _Body(_Put('CustomerTest', cGHOSTBODY));
  Assert.IsTrue(LBody.Contains('TCustomerTest'),
    'The answer does not name the resource it is about, which every other '
    + 'answer of TAppResourceBase does. Body was: [' + LBody + ']');
end;

procedure TTestServerResourceUpdateNotFound.APutThatMatchesNoRow_TheAnswerMustNotClaimSuccess;
var
  LBody: String;
begin
  LBody := _Body(_Put('CustomerTest', cGHOSTBODY));
  Assert.IsFalse(LBody.Contains('executed successfully'),
    'The server reported a successful update for a row it never located. '
    + 'Body was: [' + LBody + ']');
end;

procedure TTestServerResourceUpdateNotFound.APutThatMatchesNoRow_MustNotWriteOrTouchAnyRow;
var
  LBefore: Integer;
begin
  LBefore := _Count('SELECT COUNT(*) FROM customer_test');
  Assert.AreEqual(3, LBefore, 'premise: SeedCustomers wrote three rows.');
  _Put('CustomerTest', cGHOSTBODY);
  Assert.AreEqual(LBefore, _Count('SELECT COUNT(*) FROM customer_test'),
    'The PUT that located no row changed how many rows there are. A repair '
    + 'that INSERTS what it cannot find satisfies every other clause here.');
  Assert.AreEqual('Alice', _Scalar('SELECT name FROM customer_test ORDER BY id'),
    'The PUT that located no row reached a row it does not name.');
  Assert.AreEqual(0,
    _Count('SELECT COUNT(*) FROM customer_test WHERE name = ''Ghost'''),
    'The row the PUT could not find was written by it instead.');
end;

procedure TTestServerResourceUpdateNotFound.APutToAnUnregisteredResource_MustNotAnswerAnEmptyBody;
var
  LBody: String;
begin
  LBody := _Body(_Put(cUNMAPPED, cGHOSTBODY));
  Assert.AreNotEqual('', LBody,
    'A PUT naming a resource the server never registered answered an EMPTY '
    + 'BODY, while GET and POST both raise cRESOURCENOTREGISTER for the same '
    + 'mistake. PUT was the only one of the three that answered silence.');
end;

procedure TTestServerResourceUpdateNotFound.APutToAnUnregisteredResource_TheAnswerMustNameTheResource;
var
  LBody: String;
begin
  LBody := _Body(_Put(cUNMAPPED, cGHOSTBODY));
  Assert.IsTrue(LBody.Contains('T' + cUNMAPPED),
    'The answer does not name the resource that was asked for. Body was: ['
    + LBody + ']');
  Assert.IsTrue(LBody.Contains('not registered'),
    'The answer does not say what was wrong with it. Body was: [' + LBody + ']');
end;

procedure TTestServerResourceUpdateNotFound.Characterisation_TheRaisedNotFoundOfDeleteDoesNotParse;
var
  LBody: String;
begin
  LBody := _Body(_Delete('CustomerTest(' + cGHOSTKEY + ')'));
  Assert.IsTrue(LBody.Contains('No records found to delete'),
    'premise: ParseDelete still signals not-found by RAISING a message. '
    + 'Body was: [' + LBody + ']');
  Assert.IsFalse(_Parses(LBody),
    'THE TRANSPORT WRAPPER HAS BEEN REPAIRED, AND THIS CLAUSE IS THE SIGNAL, '
    + 'NOT A REGRESSION. It pinned the measurement the repair of ParseUpdate '
    + 'rests on: an exception message that is itself a JSON document comes out '
    + 'of the cEXCEPTION wrapper unparseable, which is why ParseUpdate RETURNS '
    + 'its not-found answer instead of raising it. If the wrapper now escapes '
    + 'or forwards the document, go read the header of this unit and decide '
    + 'whether ParseUpdate should join ParseDelete in raising. Body was: ['
    + LBody + ']');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestServerResourceUpdateNotFound);

end.
