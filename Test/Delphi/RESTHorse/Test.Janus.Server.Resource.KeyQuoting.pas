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

  AT 865370e, the commit this branch starts from, every primary key in the test
  tree was an integer save one: a scan of every [PrimaryKey] under Test\
  resolved against its [Column] declaration returned 39 ftInteger and 1
  ftString THERE, and that ftString entity - TStrMaster, in
  Test.Janus.Model.RestLazyKeys - is linked only into Janus.Tests.RESTfulDriver
  and Janus.Tests.Units. Neither compiles Janus.Server.Resource: proved with a
  {$MESSAGE ERROR} tripwire in that unit, which only Janus.Tests.RESTHorse,
  Janus.Tests.RESTMARS and Janus.Tests.RESTOracle echoed.

  The count is pinned to that commit deliberately. Test.Janus.Model.KeyTypes,
  which arrives with this fixture, is a pile of non-integer keys, so re-running
  that scan anywhere on this branch answers something larger - which is the
  point of the fixture and not a contradiction of the sentence.

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
  again in a new way. Those clauses are the measurement that chose.

  THE FAILURE COUNTS FOR THAT MEASUREMENT NAME THEIR OWN POPULATION

  Conditional quoting was first measured against the NINE-clause version of
  this fixture - which is what existed at the time - and took it from 8
  failures to 3. Against the fixture as it now stands, 110 clauses, the same
  repair leaves 7. Neither figure is wrong and the two are not comparable: any
  quotation of them has to name the fixture it means, because the population
  changed and not the repair. What does not change with the fixture is the
  finding, which is that conditional quoting never reaches zero - a double
  quote, a backslash, an ambient decimal separator, a raw control character
  and a value-less key each defeat it independently.

  One result from the larger run is worth keeping in view, because it is an
  argument the escape clauses alone do not make: under conditional quoting,
  TextualKeyCarryingAControlCharacter PASSES. Delphi's parser accepts a raw
  control character, so the round trip succeeds over a document RFC 8259
  rejects. Only TheResponseCarriesNoRawControlCharacter, which reads the wire,
  catches that one.

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

    /// A control character in the key must round trip.
    [Test]
    procedure TextualKeyCarryingAControlCharacter_MustSurviveIntoTheResponse;

    /// ...and it must not travel RAW. RFC 8259 forbids an unescaped character
    /// below #32 inside a JSON string. Delphi's own parser accepts one anyway,
    /// so round-tripping it through TJSONObject.ParseJSONValue proves nothing
    /// about the document that leaves this machine - measured, not assumed:
    /// serialising with ToString instead of ToJSON keeps every other clause in
    /// this fixture green. TJSONAncestor.ToString runs ToChars with no options
    /// and ToJSON runs it with EncodeBelow32 / EncodeAbove127; the structural
    /// escaping of the quote and the backslash happens either way. This is the
    /// only clause that separates the two, and it asserts the WIRE, which is
    /// where a stricter consumer than Delphi is standing.
    [Test]
    procedure TheResponseCarriesNoRawControlCharacter;

    /// Types whose ambient rendering carries a separator: a hyphen and braces,
    /// a slash, and - on a pt-BR machine - a decimal comma.
    [Test]
    procedure GuidKey_TheResponseMustBeParseableJson;
    [Test]
    procedure DateKey_TheResponseMustBeParseableJson;
    [Test]
    procedure FractionalKey_TheResponseMustBeParseableJson;

    /// The float branch's own selection-versus-conversion seam, and the twin
    /// of BigIntegerKey_MustNotBeNarrowed. 10.5 survives every narrowing there
    /// is - Currency, Single, and the 15-significant-digit ceiling - so the
    /// clause above pins WHICH branch is taken and nothing about what that
    /// branch does once taken. Swap Double for Currency and a fractional key
    /// silently loses everything past four decimal places, with the whole
    /// suite green.
    [Test]
    procedure FractionalKey_MustNotBeTruncatedByANarrowerFloat;

    /// SELECTING the number branch is not the same as CONVERTING inside it.
    /// Nothing about the selection depends on width, so a conversion narrowed
    /// to 32 bits leaves every other clause in this fixture green and
    /// truncates a 64-bit key in silence.
    [Test]
    procedure BigIntegerKey_MustNotBeNarrowed;

    /// An unsigned key above High(Int64). A cast through varInt64 reinterprets
    /// the bit pattern and the key comes back NEGATIVE - still valid JSON, so
    /// only a clause about the VALUE can see it. This one is a REGRESSION
    /// guard: the concatenating code this fixture replaced got this case
    /// right, and the first version of the repair did not.
    [Test]
    procedure UnsignedKeyAboveHighInt64_MustNotFlipSign;

    /// The pair list is a LOOP. Every other clause here has a single key
    /// column, so a loop that stops after its first turn is invisible to all
    /// of them.
    [Test]
    procedure CompositeTextualKey_CarriesBothPairsEscaped;

    /// The pair names the PROPERTY, not the column. The response emits KEY
    /// columns and nothing else, and every PRIMARY KEY column in the units
    /// this project links spells the same as its property - 29 of them across
    /// the 24 units Janus.Tests.RESTHorse.dpr names with a path, with exactly
    /// one divergence, which is TKeyTypeAlias and exists for this clause. So
    /// nothing could tell the two apart and trading one for the other was
    /// invisible. NON-key columns diverge freely - five in RestHorseTest.Models
    /// alone - which is why this says KEY and not "every entity".
    [Test]
    procedure TheKeyPairNamesTheProperty_NotTheColumn;

    /// VarIsOrdinal answers True for varBoolean. Without an explicit exclusion
    /// a boolean key would leave as -1 / 0.
    [Test]
    procedure BooleanKey_IsNotSwallowedIntoTheNumberBranch;

    /// A key the server could not determine must come back as JSON null - not
    /// as an empty string, which a client would write into the field as if it
    /// were the value.
    [Test]
    procedure NullableKeyWithNoValue_ComesBackAsJsonNull;

    /// The OTHER half of that guard. GetNullableValue answers a Variant NULL
    /// for a Nullable with FHasValue clear, and an EMPTY TValue - varEmpty,
    /// not varNull - when the record has no FValue field at all. The clause
    /// above reaches the first; only TKeyTypeDecoy reaches the second.
    [Test]
    procedure NullableShapedKeyWithNoValueField_ComesBackAsJsonNull;

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
  cDDL_ALIAS = 'CREATE TABLE IF NOT EXISTS ktalias (' +
               '  kt_code VARCHAR(60) PRIMARY KEY, kttag VARCHAR(60))';
  cDDL_BOOL  = 'CREATE TABLE IF NOT EXISTS ktbool ('  +
               '  ktflag BOOLEAN PRIMARY KEY, kttag VARCHAR(60))';
  cDDL_NULL  = 'CREATE TABLE IF NOT EXISTS ktnull ('  +
               '  ktopt VARCHAR(60), kttag VARCHAR(60))';
  cDDL_BIG   = 'CREATE TABLE IF NOT EXISTS ktbig ('   +
               '  ktbig BIGINT PRIMARY KEY, kttag VARCHAR(60))';
  cDDL_UNS   = 'CREATE TABLE IF NOT EXISTS ktunsigned (' +
               '  ktu BIGINT PRIMARY KEY, kttag VARCHAR(60))';
  cDDL_DECOY = 'CREATE TABLE IF NOT EXISTS ktdecoy (' +
               '  ktdec VARCHAR(60), kttag VARCHAR(60))';
  cDDL_COMP  = 'CREATE TABLE IF NOT EXISTS ktcomp ('  +
               '  ktca VARCHAR(60), ktcb VARCHAR(60), kttag VARCHAR(60),' +
               '  PRIMARY KEY (ktca, ktcb))';

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
  FConnection.ExecuteDirect(cDDL_ALIAS);
  FConnection.ExecuteDirect(cDDL_BOOL);
  FConnection.ExecuteDirect(cDDL_NULL);
  FConnection.ExecuteDirect(cDDL_BIG);
  FConnection.ExecuteDirect(cDDL_UNS);
  FConnection.ExecuteDirect(cDDL_COMP);
  FConnection.ExecuteDirect(cDDL_DECOY);
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
  FConnection.ExecuteDirect('DELETE FROM ktalias');
  FConnection.ExecuteDirect('DELETE FROM ktbool');
  FConnection.ExecuteDirect('DELETE FROM ktnull');
  FConnection.ExecuteDirect('DELETE FROM ktbig');
  FConnection.ExecuteDirect('DELETE FROM ktunsigned');
  FConnection.ExecuteDirect('DELETE FROM ktcomp');
  FConnection.ExecuteDirect('DELETE FROM ktdecoy');
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

procedure TTestServerResourceKeyQuoting.TextualKeyCarryingAControlCharacter_MustSurviveIntoTheResponse;
var
  LPair: TJSONPair;
begin
  /// The body carries A<VT>B. The VERTICAL TAB and not the horizontal one:
  /// TJSONString.ToChars has a dedicated two-character escape for #9, #10,
  /// #13, #8 and #12 that it writes with or without options, so those five
  /// cannot tell ToJSON and ToString apart. #$0B falls into the \uXXXX branch,
  /// which is the branch the options govern.
  LPair := KeyPairOf('KeyTypeText', '{"ktcode":"A\u000BB","kttag":"vtabbed"}');
  Assert.AreEqual('A'#$0B'B', LPair.JsonValue.Value,
    'A control character inside the key did not survive into the response.');
end;

procedure TTestServerResourceKeyQuoting.TheResponseCarriesNoRawControlCharacter;
var
  LRaw: String;
  LIndex: Integer;
begin
  LRaw := InsertRaw('KeyTypeText', '{"ktcode":"A\u000BB","kttag":"vtabbed"}');
  for LIndex := 1 to Length(LRaw) do
    if LRaw[LIndex] < #32 then
      Assert.Fail(Format(
        'The response carries a RAW control character #%d at position %d. '
        + 'RFC 8259 forbids it unescaped inside a JSON string. Body was: %s',
        [Ord(LRaw[LIndex]), LIndex, LRaw]));
  Assert.Pass;
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

procedure TTestServerResourceKeyQuoting.FractionalKey_MustNotBeTruncatedByANarrowerFloat;
var
  LPair: TJSONPair;
begin
  /// Nine significant digits: past Currency's four decimal places and past
  /// Single's ~7 significant digits, and still inside the 15 that
  /// TJSONNumber's JSONFormatSettings will print. Measured at this commit -
  /// 0.123456789 comes back verbatim, 12345678.9012345678 comes back as
  /// 12345678.9012346, which is that 15-digit ceiling and not a defect of
  /// this branch.
  ///
  /// ONE WARNING FOR WHOEVER MUTATES THIS LINE NEXT. Writing Single(...) as a
  /// CAST around the expression does not narrow anything. MEASURED: Double(
  /// Single(x)) and Double(x) both print 0.123456789 and compare equal, while
  /// the same value assigned to a real Single variable and widened prints
  /// 0.123456791043282 and compares UNequal to both. So a mutation written as
  /// a cast survives because it changed NOTHING, not because this clause is
  /// blind - and narrowing for real, through a Single variable, is killed by
  /// this clause. WHY the cast is a no-op here was not measured; the compiler
  /// keeping the value at a wider working precision is a plausible mechanism
  /// and nothing above depends on it being the right one.
  LPair := KeyPairOf('KeyTypeFloat',
    '{"ktnum":0.123456789,"kttag":"precise"}');
  Assert.AreEqual('ktnum', LPair.JsonString.Value,
    'The response no longer names the key column.');
  Assert.IsTrue(LPair.JsonValue is TJSONNumber,
    'A fractional key must stay a JSON NUMBER. Got: '
    + LPair.JsonValue.ClassName);
  Assert.AreEqual('0.123456789', LPair.JsonValue.Value,
    'The fractional key was truncated on its way into the response. Currency '
    + 'would leave 0.1235 and Single 0.123456791043282; both are valid JSON, '
    + 'so only the VALUE says which one happened. Got: '
    + LPair.JsonValue.ToJSON);
end;

procedure TTestServerResourceKeyQuoting.BigIntegerKey_MustNotBeNarrowed;
var
  LPair: TJSONPair;
begin
  /// Above High(Integer) AND above 2^53, so both a 32-bit narrowing and a
  /// detour through Double are caught.
  LPair := KeyPairOf('KeyTypeBig', '{"ktbig":9007199254740993,"kttag":"big"}');
  Assert.AreEqual('ktbig', LPair.JsonString.Value,
    'The response no longer names the key column.');
  Assert.IsTrue(LPair.JsonValue is TJSONNumber,
    'A 64-bit key must stay a JSON NUMBER. Got: ' + LPair.JsonValue.ClassName);
  Assert.AreEqual('9007199254740993', LPair.JsonValue.Value,
    'The 64-bit key did not survive the round trip verbatim.');
end;

procedure TTestServerResourceKeyQuoting.UnsignedKeyAboveHighInt64_MustNotFlipSign;
var
  LPair: TJSONPair;
begin
  /// High(Int64) + 1. Read as a signed 64-bit integer this exact bit pattern
  /// is -9223372036854775808.
  LPair := KeyPairOf('KeyTypeUnsigned',
    '{"ktu":9223372036854775808,"kttag":"unsigned"}');
  Assert.AreEqual('ktu', LPair.JsonString.Value,
    'The response no longer names the key column.');
  Assert.AreEqual('9223372036854775808', LPair.JsonValue.Value,
    'An unsigned key above High(Int64) came back reinterpreted as a signed '
    + 'value. Both forms are valid JSON, so nothing but this assertion sees '
    + 'it. Got: ' + LPair.JsonValue.ToJSON);
end;

procedure TTestServerResourceKeyQuoting.CompositeTextualKey_CarriesBothPairsEscaped;
var
  LParams: TJSONObject;
begin
  LParams := ParamsOf(InsertRaw('KeyTypeComposite',
    '{"ktca":"A\"B","ktcb":"C\\D","kttag":"composite"}'));
  Assert.AreEqual(2, LParams.Count,
    'A composite key must name EVERY one of its columns. The pair list is a '
    + 'loop and this is the only clause that turns it more than once. Got: '
    + LParams.ToJSON);
  Assert.AreEqual('ktca', LParams.Pairs[0].JsonString.Value,
    'The first key column is not the one declared first.');
  Assert.AreEqual('ktcb', LParams.Pairs[1].JsonString.Value,
    'The second key column is not the one declared second.');
  Assert.AreEqual('A"B', LParams.Pairs[0].JsonValue.Value,
    'The first key column did not survive escaping.');
  Assert.AreEqual('C\D', LParams.Pairs[1].JsonValue.Value,
    'The second key column did not survive escaping.');
end;

procedure TTestServerResourceKeyQuoting.TheKeyPairNamesTheProperty_NotTheColumn;
var
  LPair: TJSONPair;
begin
  /// TKeyTypeAlias maps the property `ktcode` onto the column `kt_code`.
  LPair := KeyPairOf('KeyTypeAlias', '{"ktcode":"ABC","kttag":"aliased"}');
  Assert.AreEqual('ktcode', LPair.JsonString.Value,
    'The insert response names the COLUMN. It named the PROPERTY before, and '
    + 'the client looks the name up as a dataset field.');
  Assert.AreEqual('ABC', LPair.JsonValue.Value,
    'The key value did not survive the round trip.');
end;

procedure TTestServerResourceKeyQuoting.BooleanKey_IsNotSwallowedIntoTheNumberBranch;
var
  LPair: TJSONPair;
begin
  LPair := KeyPairOf('KeyTypeBool', '{"ktflag":true,"kttag":"flagged"}');
  Assert.AreEqual('ktflag', LPair.JsonString.Value,
    'The response no longer names the key column.');
  Assert.IsTrue(LPair.JsonValue is TJSONString,
    'A boolean key left as the number branch would render it. That is a '
    + 'contract change no clause here asked for. Got: '
    + LPair.JsonValue.ClassName + ' / ' + LPair.JsonValue.ToJSON);
  Assert.AreEqual('True', LPair.JsonValue.Value,
    'The boolean key did not survive the round trip in the form VarToStr '
    + 'already produced.');
end;

procedure TTestServerResourceKeyQuoting.NullableKeyWithNoValue_ComesBackAsJsonNull;
var
  LPair: TJSONPair;
begin
  /// The caller sends no key at all, and the property is Nullable, so nothing
  /// gives it a value: GetNullableValue answers a Variant Null.
  LPair := KeyPairOf('KeyTypeNullable', '{"kttag":"unset"}');
  Assert.AreEqual('ktopt', LPair.JsonString.Value,
    'The response no longer names the key column.');
  Assert.IsTrue(LPair.JsonValue is TJSONNull,
    'A key with no value must come back as JSON null, not as an empty string '
    + 'the client would take for the value. Got: '
    + LPair.JsonValue.ClassName + ' / ' + LPair.JsonValue.ToJSON);
end;

procedure TTestServerResourceKeyQuoting.NullableShapedKeyWithNoValueField_ComesBackAsJsonNull;
var
  LPair: TJSONPair;
begin
  LPair := KeyPairOf('KeyTypeDecoy', '{"kttag":"decoy"}');
  Assert.AreEqual('ktdec', LPair.JsonString.Value,
    'The response no longer names the key column.');
  Assert.IsTrue(LPair.JsonValue is TJSONNull,
    'An EMPTY Variant must come back as JSON null. Dropping the VarIsEmpty '
    + 'half of the guard sends it to the string branch, where it leaves as "" '
    + '- a value the client would write into the field. Got: '
    + LPair.JsonValue.ClassName + ' / ' + LPair.JsonValue.ToJSON);
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
