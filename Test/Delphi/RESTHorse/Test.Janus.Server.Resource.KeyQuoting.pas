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

(* @abstract(Janus Framework - the primary key the insert response carries back,
  issue #311.)

  This header is a parenthesis-star comment rather than a brace comment ON
  PURPOSE: it quotes JSON documents, and a closing brace inside a brace comment
  ends the comment where the text does not.

  WHAT IS UNDER TEST

  TAppResourceBase.ParseInsert, the loop that builds the `params` element of
  cRESOURCEINSERT. It is the ONLY producer of that element in Source\ - the
  Horse, WiRL, MARS, DMVC and DataSnap resources all reach it through
  TAppResourceBase.insert and none of them assembles a response of its own.

  WHAT THE LOOP USED TO DO

  It concatenated text. The key NAME was quoted by hand and the key VALUE was
  pasted in raw, straight out of VarToStr. An integer key produced {"ID":10},
  which is valid JSON by coincidence: a bare integer is also a JSON number. Any
  other type produced a bare token where JSON requires a quoted string, and a
  bare token is not JSON at all.

  WHY THE SUITE NEVER SAW IT

  Two independent reasons, both measured rather than assumed.

  Every primary key in the test tree is an integer, save one: a scan of every
  [PrimaryKey] under Test\ resolved against its [Column] declaration returns 39
  ftInteger and 1 ftString, and that ftString entity - TStrMaster, in
  Test.Janus.Model.RestLazyKeys - is linked only into Janus.Tests.RESTfulDriver
  and Janus.Tests.Units. Neither compiles Janus.Server.Resource: proved with a
  {$MESSAGE ERROR} tripwire in that unit, which only Janus.Tests.RESTHorse,
  Janus.Tests.RESTMARS and Janus.Tests.RESTOracle echoed.

  And on the client the response is read behind a gate. TSessionRestFul<M>.Insert
  parses it, but the only consumer of the FResultParams it fills - the REST
  dataset adapter - reads them only `if FSession.ExistSequence`, and
  TSessionRestFul<M>.ExistSequence answers by asking TMappingExplorer for the
  entity's [Sequence] mapping. No textual-key model in this tree carries one.
  Note this corrects the wording of the issue, which attributed the gate to
  TAutoIncType: the gate reads GetMappingSequence, not the AutoInc type. Both
  statements happen to be true of this tree, but only one of them is the gate.

  HOW THE FAILURE PRESENTS

  Silently. TSessionRestFul<M>.Insert hands the body to
  TJanusJson.JSONStringToJSONObject, which is TJSONObject.ParseJSONValue and
  answers nil for a malformed document, and the method then leaves through a
  bare Exit with FResultParams still empty. No exception, no log: the insert
  reports success and the key in memory stays whatever it was.

  WHY THE PREMISE CLAUSE FEEDS THE REAL PARSER

  A clause that asserted "the response contains a quote character" would pass
  against a response that is still not JSON. These clauses push the server's own
  output through TJanusJson.JSONStringToJSONObject - the very call the client
  makes - so the thing being asserted is the thing the client actually does.

  WHY THE INTEGER CONTROL IS NOT DECORATIVE

  The cheapest possible repair is to quote every value. It turns every clause
  about textual keys green and silently rewrites the integer contract from
  {"ktid":10} to {"ktid":"10"}. IntegerKey_MustStillRenderAsAJsonNumber is the
  clause that dies for it.

  WHY THE ESCAPE CLAUSES DECIDE THE SHAPE OF THE FIX

  Two repairs were on the table: quote conditionally by column type, or stop
  concatenating and let a TJSONObject serialise. They are indistinguishable on
  a well-behaved value. They part company on a key that CONTAINS a double quote
  or a backslash, where hand-quoting produces a document that is malformed
  again in a new way. Those two clauses are the measurement that chose.

  WHAT THIS FIXTURE DELIBERATELY DOES NOT ASSERT

  The date and fractional clauses assert only that the response PARSES and that
  the value survives the round trip verbatim. They do not pin a rendering -
  ISO-8601 versus the ambient FormatSettings is a contract question about what
  a consumer receives, and it is not this issue's to settle. What is settled
  here is that whatever the server renders, it renders as JSON.

  ANCHORS ARE BY METHOD, NEVER BY file:line. *)

unit Test.Janus.Server.Resource.KeyQuoting;

interface

uses
  Classes,
  SysUtils,
  Variants,
  IOUtils,
  DateUtils,
  JSON,
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
  DataEngine.FactoryInterfaces,
  Janus.Json,
  Janus.Server.Resource,
  Test.Janus.Model.KeyTypes;

type
  [TestFixture]
  TTestServerResourceKeyQuoting = class
  private
    FDConnection: TFDConnection;
    FConnection: IDBConnection;
    /// Drives TAppResourceBase.insert and hands back the raw response body,
    /// exactly as the transport layer would put it on the wire.
    function InsertRaw(const AResource, ABody: String): String;
    /// The response body, pushed through the SAME parser the client uses.
    /// Fails - naming the body - when the document does not parse at all.
    function ParamsOf(const AResponse: String): TJSONObject;
    function KeyPairOf(const AResource, ABody: String): TJSONPair;
    function ScalarInt(const ASQL: String): Integer;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;
    [Setup]
    procedure Setup;

    /// The headline. A textual key must come back inside a document the client
    /// can parse.
    [Test]
    procedure TextualKey_TheResponseMustBeParseableJson;

    /// Parsing is not enough: the pair must name the key column and carry the
    /// value that was written.
    [Test]
    procedure TextualKey_TheResponseMustNameTheKeyItWrote;

    /// The control against a fix that quotes everything.
    [Test]
    procedure IntegerKey_MustStillRenderAsAJsonNumber;

    /// The two clauses that chose between quoting by type and serialising a
    /// real TJSONObject. Hand-quoting passes every clause above and dies here.
    [Test]
    procedure TextualKeyCarryingADoubleQuote_MustSurviveIntoTheResponse;
    [Test]
    procedure TextualKeyCarryingABackslash_MustSurviveIntoTheResponse;

    /// Types whose ambient rendering carries a separator: a hyphen and braces,
    /// a slash, and - on a pt-BR machine - a decimal comma.
    [Test]
    procedure GuidKey_TheResponseMustBeParseableJson;
    [Test]
    procedure DateKey_TheResponseMustBeParseableJson;
    [Test]
    procedure FractionalKey_TheResponseMustBeParseableJson;

    /// The whole response, not just its params element, must stay a single
    /// well-formed document - the `result` message has to survive intact.
    [Test]
    procedure TheResponseKeepsItsResultMessage;
  end;

implementation

uses
  DataEngine.FactoryFireDAC;

const
  cDBFILE = 'janus_server_resource_keyquoting.db';

  cDDL_TEXT  = 'CREATE TABLE IF NOT EXISTS kttext ('  +
               '  ktcode VARCHAR(60) PRIMARY KEY, kttag VARCHAR(60))';
  cDDL_NUM   = 'CREATE TABLE IF NOT EXISTS ktnum ('   +
               '  ktid INTEGER PRIMARY KEY, kttag VARCHAR(60))';
  cDDL_GUID  = 'CREATE TABLE IF NOT EXISTS ktguid ('  +
               '  ktuid VARCHAR(38) PRIMARY KEY, kttag VARCHAR(60))';
  cDDL_DATE  = 'CREATE TABLE IF NOT EXISTS ktdate ('  +
               '  ktday DATE PRIMARY KEY, kttag VARCHAR(60))';
  cDDL_FLOAT = 'CREATE TABLE IF NOT EXISTS ktfloat (' +
               '  ktnum NUMERIC(18,4) PRIMARY KEY, kttag VARCHAR(60))';

{ TTestServerResourceKeyQuoting }

procedure TTestServerResourceKeyQuoting.SetupFixture;
begin
  if TFile.Exists(cDBFILE) then
    TFile.Delete(cDBFILE);
  FDConnection := TFDConnection.Create(nil);
  FDConnection.Params.DriverID := 'SQLite';
  FDConnection.Params.Database := cDBFILE;
  FDConnection.Params.Values['OpenMode'] := 'CreateUTF8';
  FDConnection.ResourceOptions.SilentMode := True;
  FDConnection.Connected := True;
  FConnection := TFactoryFireDAC.Create(FDConnection, dnSQLite);
  /// The entities are registered in the INITIALIZATION of
  /// Test.Janus.Model.KeyTypes, not here - see the note in that unit.
  FConnection.ExecuteDirect(cDDL_TEXT);
  FConnection.ExecuteDirect(cDDL_NUM);
  FConnection.ExecuteDirect(cDDL_GUID);
  FConnection.ExecuteDirect(cDDL_DATE);
  FConnection.ExecuteDirect(cDDL_FLOAT);
end;

procedure TTestServerResourceKeyQuoting.TearDownFixture;
begin
  FConnection := nil;
  if Assigned(FDConnection) then
  begin
    FDConnection.Connected := False;
    FreeAndNil(FDConnection);
  end;
  if TFile.Exists(cDBFILE) then
    TFile.Delete(cDBFILE);
end;

procedure TTestServerResourceKeyQuoting.Setup;
begin
  FConnection.ExecuteDirect('DELETE FROM kttext');
  FConnection.ExecuteDirect('DELETE FROM ktnum');
  FConnection.ExecuteDirect('DELETE FROM ktguid');
  FConnection.ExecuteDirect('DELETE FROM ktdate');
  FConnection.ExecuteDirect('DELETE FROM ktfloat');
end;

function TTestServerResourceKeyQuoting.ScalarInt(const ASQL: String): Integer;
var
  LValue: Variant;
begin
  LValue := FDConnection.ExecSQLScalar(ASQL);
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Result := -1
  else
    Result := LValue;
end;

function TTestServerResourceKeyQuoting.InsertRaw(const AResource,
  ABody: String): String;
var
  LResource: TAppResourceBase;
begin
  LResource := TAppResourceBase.Create(FConnection);
  try
    Result := LResource.insert(AResource, ABody);
  finally
    LResource.Free;
  end;
end;

function TTestServerResourceKeyQuoting.ParamsOf(
  const AResponse: String): TJSONObject;
var
  LRoot: TJSONObject;
  LArray: TJSONArray;
begin
  /// TJanusJson.JSONStringToJSONObject is literally what the client calls, and
  /// it answers nil - never an exception - for a document that does not parse.
  LRoot := TJanusJson.JSONStringToJSONObject(AResponse);
  Assert.IsNotNull(LRoot,
    'The insert response is not parseable JSON. The client discards it through '
    + 'a bare Exit and leaves the key at its placeholder. Body was: ' + AResponse);
  LArray := LRoot.Values['params'] as TJSONArray;
  Assert.IsNotNull(LArray,
    'The response parsed but carries no "params" array. Body was: ' + AResponse);
  Assert.AreEqual(1, LArray.Count,
    'Expected exactly one params element. Body was: ' + AResponse);
  Result := LArray.Items[0] as TJSONObject;
  Assert.IsNotNull(Result,
    'The params element is not a JSON object. Body was: ' + AResponse);
end;

function TTestServerResourceKeyQuoting.KeyPairOf(const AResource,
  ABody: String): TJSONPair;
var
  LParams: TJSONObject;
begin
  LParams := ParamsOf(InsertRaw(AResource, ABody));
  Assert.AreEqual(1, LParams.Count, 'Expected a single key pair.');
  Result := LParams.Pairs[0];
end;

procedure TTestServerResourceKeyQuoting.TextualKey_TheResponseMustBeParseableJson;
begin
  ParamsOf(InsertRaw('KeyTypeText', '{"ktcode":"ABC","kttag":"plain"}'));
end;

procedure TTestServerResourceKeyQuoting.TextualKey_TheResponseMustNameTheKeyItWrote;
var
  LPair: TJSONPair;
begin
  LPair := KeyPairOf('KeyTypeText', '{"ktcode":"ABC","kttag":"plain"}');
  Assert.AreEqual('ktcode', LPair.JsonString.Value,
    'The response no longer names the key column.');
  Assert.IsTrue(LPair.JsonValue is TJSONString,
    'A textual key must come back as a JSON string, not as a bare token. Got: '
    + LPair.JsonValue.ClassName);
  Assert.AreEqual('ABC', LPair.JsonValue.Value,
    'The key value did not survive the round trip.');
end;

procedure TTestServerResourceKeyQuoting.IntegerKey_MustStillRenderAsAJsonNumber;
var
  LPair: TJSONPair;
begin
  LPair := KeyPairOf('KeyTypeNum', '{"ktid":10,"kttag":"plain"}');
  Assert.AreEqual('ktid', LPair.JsonString.Value,
    'The response no longer names the key column.');
  Assert.IsTrue(LPair.JsonValue is TJSONNumber,
    'An integer key must stay a JSON NUMBER. Quoting every value repairs the '
    + 'textual clauses and silently rewrites this contract. Got: '
    + LPair.JsonValue.ClassName + ' / ' + LPair.JsonValue.ToJSON);
  Assert.AreEqual('10', LPair.JsonValue.Value,
    'The key value did not survive the round trip.');
end;

procedure TTestServerResourceKeyQuoting.TextualKeyCarryingADoubleQuote_MustSurviveIntoTheResponse;
var
  LPair: TJSONPair;
begin
  /// The body carries A"B. Hand-quoting emits "A"B" and the document breaks at
  /// the second quote; a serialiser emits "A\"B" and it does not.
  LPair := KeyPairOf('KeyTypeText', '{"ktcode":"A\"B","kttag":"quoted"}');
  Assert.AreEqual('A"B', LPair.JsonValue.Value,
    'A double quote inside the key did not survive into the response.');
end;

procedure TTestServerResourceKeyQuoting.TextualKeyCarryingABackslash_MustSurviveIntoTheResponse;
var
  LPair: TJSONPair;
begin
  /// The body carries A\B.
  LPair := KeyPairOf('KeyTypeText', '{"ktcode":"A\\B","kttag":"slashed"}');
  Assert.AreEqual('A\B', LPair.JsonValue.Value,
    'A backslash inside the key did not survive into the response.');
end;

procedure TTestServerResourceKeyQuoting.GuidKey_TheResponseMustBeParseableJson;
var
  LPair: TJSONPair;
begin
  /// The caller supplies NO key: TGeneratorType.Guid38Inc makes one on the
  /// server. The response is therefore the only channel through which the
  /// caller can ever learn it.
  LPair := KeyPairOf('KeyTypeGuid', '{"kttag":"guid"}');
  Assert.AreEqual('ktuid', LPair.JsonString.Value,
    'The response no longer names the key column.');
  Assert.IsTrue(LPair.JsonValue is TJSONString,
    'A generated GUID key must come back as a JSON string. Got: '
    + LPair.JsonValue.ClassName);
  Assert.AreEqual(38, Length(LPair.JsonValue.Value),
    'The generated GUID key did not survive the round trip in its braced, '
    + 'hyphenated form. Got: ' + LPair.JsonValue.ToJSON);
  Assert.AreEqual(1, ScalarInt('SELECT COUNT(*) FROM ktguid WHERE ktuid = ' +
    QuotedStr(LPair.JsonValue.Value)),
    'The key the response names is not the key the row was written with.');
end;

procedure TTestServerResourceKeyQuoting.DateKey_TheResponseMustBeParseableJson;
var
  LPair: TJSONPair;
begin
  LPair := KeyPairOf('KeyTypeDate', '{"ktday":"2026-03-17","kttag":"dated"}');
  Assert.AreEqual('ktday', LPair.JsonString.Value,
    'The response no longer names the key column.');
  /// No rendering is pinned here - see the header. Only that the value is a
  /// JSON string and is not empty.
  Assert.IsTrue(LPair.JsonValue is TJSONString,
    'A date key must come back as a JSON string. Got: '
    + LPair.JsonValue.ClassName);
  Assert.IsFalse(LPair.JsonValue.Value.IsEmpty,
    'The date key came back empty.');
end;

procedure TTestServerResourceKeyQuoting.FractionalKey_TheResponseMustBeParseableJson;
var
  LPair: TJSONPair;
begin
  LPair := KeyPairOf('KeyTypeFloat', '{"ktnum":10.5,"kttag":"fraction"}');
  Assert.AreEqual('ktnum', LPair.JsonString.Value,
    'The response no longer names the key column.');
  /// Whatever it renders as, it must round trip to the same number - which a
  /// decimal comma pasted into a JSON document cannot do.
  Assert.AreEqual(10.5, StrToFloat(LPair.JsonValue.Value,
    TFormatSettings.Invariant), 0.0001,
    'The fractional key did not survive the round trip. Got: '
    + LPair.JsonValue.ToJSON);
end;

procedure TTestServerResourceKeyQuoting.TheResponseKeepsItsResultMessage;
var
  LRoot: TJSONObject;
  LRaw: String;
begin
  LRaw := InsertRaw('KeyTypeText', '{"ktcode":"ABC","kttag":"plain"}');
  LRoot := TJanusJson.JSONStringToJSONObject(LRaw);
  Assert.IsNotNull(LRoot, 'The insert response is not parseable JSON: ' + LRaw);
  Assert.AreEqual('Resource TKeyTypeText insert command executed successfully',
    LRoot.GetValue<String>('result'),
    'The result message of the insert response changed.');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestServerResourceKeyQuoting);

end.
