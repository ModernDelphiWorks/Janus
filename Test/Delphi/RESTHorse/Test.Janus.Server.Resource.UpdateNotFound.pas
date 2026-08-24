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

  AND THE REPAIR SEPARATES TWO OF THE THREE, NOT THREE. Measured on the HEAD of
  this branch, over the same live server:

    PUT CustomerTest "this is not json" ->  200  LEN=88  ParseJSONValue=object
      body: {"result":"Resource TCustomerTest update command found no record
             with the key informed"}

  That is not silence any more, but it is the WRONG REASON -
  a payload the server could not read at all is reported as a key that located
  no row. The route is plain: TJanusJson.JsonToObject fills nothing, every key
  column renders as the empty literal, ParseUpdate emits `(1 = 0)` and reaches
  the same not-found exit (all anchored by SYMBOL in TAppResourceBase.
  ParseUpdate). A Nullable key the caller simply did not send arrives at the
  same answer by the same road. So the third mistake moved from MUTE to
  MISLABELLED, which is better and is not fixed; telling it apart needs a JSON
  parse check before the mapping walk, and that is not this issue's to add.
  That reading is held by a CLAUSE and not by this paragraph -
  Characterisation_ANonJsonBodyIsMislabelledAsNotFound - for the same reason
  the leftover silence of ParseDelete is: a measurement left in prose goes
  stale without anything turning red.

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
  "Resource not registered" is not a question about data, and ParseInsert and
  ParseFind both RAISE cRESOURCENOTREGISTER for it. PUT answered silence and now
  raises what they raise, which means it also inherits the wrapper defect above:
  the clause below asserts the resource NAME travels, and deliberately does not
  assert that the document parses, because on this route it does not. That is
  the wrapper's defect and not ParseUpdate's, it is reported rather than
  repaired here, and the characterisation clause at the end pins it so that
  whoever repairs it finds this note.

  FOUR VERBS SHARE THAT EXIT AND ONE OF THEM IS STILL MUTE. An earlier draft of
  this header, and of the note in Source, said PUT was "the only one of the
  three that answered silence". That count was wrong: ParseDelete carries the
  SAME bare `Exit` on the SAME nil LClassType, and it is untouched. Measured on
  the HEAD of this branch:

    DELETE NotAnEntityAtAll(1)              ->  200  LEN=0   ParseJSONValue=nil

  So the house is THREE-RAISE / ONE-SILENT, and what is left over is ParseDelete
  - named here, and pinned below by
  Characterisation_TheUnregisteredResourceExitOfDeleteStillAnswersSilence, so
  that the count cannot go stale in prose a second time.

  WHAT THIS FIXTURE DOES NOT SETTLE

  THE STATUS. Everything the Horse transport emits is 200, errors included, and
  no seam between TAppResourceBase and any of the five transports carries a
  status at all. A 404 would also not have removed the symptom this issue
  reports: ResponseValue raises on a nil JSONValue whatever the status is. So
  the body is the repair and the status is a contract question for the owner;
  no clause here pins 200, so answering 404 later breaks nothing in this file.

  AND THE ONE THIS FIXTURE HAS TO CONFESS: THE CLIENT WENT QUIET. This repair
  moves the symptom one layer up rather than removing it, and the issue said
  the opposite was fine - "the client raises, which is right". Measured with a
  real Janus client against this live server, the same PUT, both sides:

    base 8f5864f, TSessionRestFul<M>.Update  ->  EJanusRESTException
    HEAD of this branch, same call           ->  <NO EXCEPTION>

  Nothing was broken by that; what changed is which of two bad answers the
  caller gets. Before, the caller was told something was wrong FOR THE WRONG
  REASON - the empty body made TCustomRESTResponse.GetJSONValue answer nil,
  TJanusClient.ResponseValue raised cRESTNOJSONVALUE, and TRESTClientHorse.DoPUT
  re-raised it as EJanusRESTException blaming the caller's payload. Now the body
  parses, so DoPUT returns it, and the TRUE document is DISCARDED:
  TSessionRestFul<M>.Update assigns it to a local named LResult, and that local
  has exactly ONE reader - the `if FConnection.CommandMonitor <> nil` block in
  the same method's finally. Update is a PROCEDURE and hands the caller nothing.
  So a PUT that updates no row now completes in TOTAL SILENCE for any consumer
  that has no monitor installed - which is the very shape this issue was opened
  against, promoted one layer. (Anchored by SYMBOL, like everything else here:
  TSessionRestFul<M>.Update, and the local it assigns.)

  THERE IS NO EXIT FROM THAT WITH THIS TRANSPORT, and that is why it was
  accepted rather than fixed: a body that parses is a body the client does not
  raise on, and a body that does not parse is a body the client raises the
  MISLEADING cRESTNOJSONVALUE on. The server cannot buy client-side signalling
  with the shape of its answer alone. Making Update SIGNAL is a change on the
  CLIENT, and it is the owner's call, not this repair's.

  WHAT IT WOULD COST, MEASURED RATHER THAN GUESSED, so the decision is not an
  open question. One statement changes - the body of TSessionRestFul<M>.Update -
  and TWO callers in Source would newly be able to see an exception:
  TRESTObjectSetAdapter<M>.Update and TRESTDataSetAdapter<M>.ApplyUpdater (both
  anchored by SYMBOL).

  Inside this repository the blast radius is ONE CLAUSE, and it is in THIS FILE:
  Characterisation_TheJanusClientSwallowsThisAnswer. Measured by mutation -
  Update made to raise on the not-found answer it gets back, all seven projects
  rebuilt and run, on this branch with origin/develop f03ef0b merged in - it is
  the only red anywhere: Units 730/730, LiveBindings 31/31, RESTfulDriver
  283/283, RESTHorse 191/192, RESTMARS 33/33, RESTWiRL 30/30, and RESTOracle's
  12 errored, which is its basal state here with or without the mutation.

  Test.Janus.Rest.ObjectSetOwnership, which drives
  TRESTObjectSetAdapter<M>.Update through a recording double, stays GREEN under
  that mutation: the double never answers a not-found document, so it is on the
  PATH without being in the blast radius. AN EARLIER DRAFT OF THIS PARAGRAPH
  NAMED IT AS THE BLAST RADIUS AND NAMED NOTHING THAT BREAKS - it named the unit
  that does NOT go red and omitted the clause that does, in the same file whose
  doc-comment on that clause, and whose assertion message inside it, both already
  said it would go RED. That was falsified by the measurement above, not deleted.

  And ZERO examples - the FIVE Examples/Delphi/RESTful `.Update(` sites are the
  SERVER side over IDBConnection, none of them this session: four in the driver
  servers (Datasnap, DelphiMVC, MARS, WiRL) and, the fifth, HorseJanus.DAO.Base's
  IContainerObjectSet<T>. The count in this sentence used to read FOUR and it was
  short by that fifth one.

  The one that is NOT cheap is ApplyUpdater: it clears the dsEdit marker of
  EVERY filtered row before it calls Update once with the whole list, so an
  exception on row k leaves rows k+1..N marked as applied and never sent. A
  raise there buys a signal and pays with a silently partial apply.

  AND THERE IS AN ADDITIVE PATH THAT IS ALREADY SHIPPED, which is the part worth
  knowing before anything is changed at all: TJanusClient.OnAfterCommand fires
  on this very PUT and is handed the whole document. Measured through the real
  client against this live server:

    OnAfterCommand  ->  AStatusCode=200
                        AResponseString={"result":"Resource TCustomerTest
                        update command found no record with the key informed"}

  So a consumer can detect this TODAY with no change to Janus. What that hook is
  NOT: it is per-CONNECTION and not per-call, it carries text and not a typed
  signal, it cannot say WHICH object of a batch the answer belongs to, and it
  lives on TJanusClient rather than on IRESTConnection - so TSessionRestFul
  itself cannot reach it. A middle option exists too and is also additive: the
  session already owns ResultParams and ResultEntities, cleared and filled by
  Insert from an answer of exactly this shape, and Update could fill one of them
  instead of raising - but neither is exposed above the adapter today, so that
  option costs one pass-through property as well.

  Both halves of the measurement are pinned below by
  Characterisation_TheJanusClientSwallowsThisAnswer, which is where whoever
  repairs Update will land.

  ANCHORS ARE BY SYMBOL, NEVER BY file:line. *)

unit Test.Janus.Server.Resource.UpdateNotFound;

interface

uses
  DB,
  SysUtils,
  Classes,
  Variants,
  JSON,
  Generics.Collections,
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
  Janus.RestFactory.Interfaces,
  Janus.Client.Horse,
  Janus.Session.RESTful,
  /// LAST of the mapping-bearing units on purpose: [Resource], [Column] and
  /// friends must resolve to MetaDbDiff's, and the later unit wins.
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Attributes,
  RestHorseTest.Base;

type
  /// THE CLIENT'S VIEW OF customer_test, AND WHY IT IS DECLARED HERE.
  /// TSessionRestFul<M>.Create spells the resource out of [Resource] and, only
  /// failing that, out of [Table]. TCustomerTest's table is `customer_test`,
  /// which TRESTQueryParse.GetResourceName would turn into `Tcustomer_test` and
  /// the server would refuse as unregistered - so a real client cannot drive
  /// the server-side entity by its table name. Adding [Resource] to
  /// RestHorseTest.Models would work and is NOT done: that unit is shared with
  /// Janus.Tests.RESTMARS. This class carries the same four columns and is
  /// never registered; it exists to put a PUT on the wire at the same URL the
  /// raw-HTTP clauses above use.
  [Entity]
  [Resource('CustomerTest')]
  [Table('customer_test', '')]
  [PrimaryKey('id', 'Primary key')]
  TCustomerTestClientView = class
  private
    FId: Integer;
    FName: String;
    FEmail: String;
    FActive: Boolean;
  public
    [Restrictions([NoUpdate, NotNull])]
    [Column('id', ftInteger)]
    property Id: Integer read FId write FId;
    [Column('name', ftString, 100)]
    property Name: String read FName write FName;
    [Column('email', ftString, 200)]
    property Email: String read FEmail write FEmail;
    [Column('active', ftBoolean)]
    property Active: Boolean read FActive write FActive;
  end;

  /// The ONLY reader of what TSessionRestFul<M>.Update got back. That is not a
  /// convenience of this test - it IS the measurement: the local that method
  /// assigns the answer to is read in one place, the
  /// `if FConnection.CommandMonitor <> nil` block of its own finally, and
  /// nowhere else. Anchored by SYMBOL.
  TRecordingMonitor = class(TInterfacedObject, ICommandMonitor)
  private
    FLast: String;
  public
    procedure Command(const ASQL: String; AParams: TParams);
    procedure Show;
    property Last: String read FLast;
  end;

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
    /// One PUT through the REAL Janus client chain - TRESTClientHorse ->
    /// TRESTFactoryHorse -> TRESTDriverHorse -> TSessionRestFul<M>.Update.
    /// Answers what the CommandMonitor was shown, which is the only reader of
    /// the answer that exists, and reports through ARaised what the caller saw.
    function _ClientUpdate(const AId: Integer; const AName: String;
      out ARaised: String): String;
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

    /// CHARACTERISATION, GREEN BEFORE AND AFTER. What is left over from the
    /// unregistered-resource repair: ParseDelete still answers silence for it.
    /// It exists so the "three raise, one is mute" count in the header is held
    /// by a clause instead of by prose - the previous count was prose and it
    /// was wrong.
    [Test]
    procedure Characterisation_TheUnregisteredResourceExitOfDeleteStillAnswersSilence;

    /// CHARACTERISATION, GREEN TODAY. The THIRD mistake of the header's first
    /// table: a body the server could not parse at all is reported as a key
    /// that located no row. It is here because the repair separates two of the
    /// three and the third only moved from MUTE to MISLABELLED - see "AND THE
    /// REPAIR SEPARATES TWO OF THE THREE, NOT THREE" above - and that reading
    /// was carried by prose alone, which is exactly how the previous count in
    /// this header went wrong. It goes RED the day a JSON parse check lands
    /// before the mapping walk of ParseUpdate, and that is the signal to come
    /// read the header, not a regression.
    [Test]
    procedure Characterisation_ANonJsonBodyIsMislabelledAsNotFound;

    /// PREMISE FOR THE CLIENT CLAUSE BELOW, AND IT IS NOT A FORMALITY. Without
    /// it, "the client did not raise" could mean the client never reached
    /// ParseUpdate at all - a resource name the server does not resolve, or a
    /// body whose keys it cannot match, both end at the SAME not-found answer
    /// (see the header on the mislabelled non-JSON body). This drives the real
    /// Janus client at a row that DOES exist and reads back the success
    /// document plus the moved row, so the clause below is known to be
    /// measuring "the key named no row" and not "the server understood
    /// nothing".
    [Test]
    procedure Premise_TheJanusClientCanDriveThisRouteAtAll;

    /// CHARACTERISATION OF THE PRICE, AND THE TRIPWIRE FOR WHOEVER PAYS IT.
    /// Red on the base and green here, deliberately: on the base this same call
    /// raised EJanusRESTException (for the wrong reason - see the header), and
    /// now it raises nothing and throws the true answer away. Whoever makes
    /// TSessionRestFul<M>.Update signal will turn this clause RED, and that is
    /// the point - it is the note they have to read before they change it, not
    /// a regression. Its first half is the premise: the not-found document DID
    /// arrive, and the only thing that ever sees it is a monitor the ordinary
    /// consumer does not install.
    [Test]
    procedure Characterisation_TheJanusClientSwallowsThisAnswer;
  end;

implementation

const
  cTIMEOUT_MS = 5000;
  cGHOSTKEY   = '999999';
  cGHOSTBODY  = '{"id":999999,"name":"Ghost","email":"ghost@test.com","active":true}';
  cUNMAPPED   = 'NotAnEntityAtAll';
  /// The body of the header's fourth measurement, spelled the same there.
  cNOTJSON    = 'this is not json';
  /// Spelled out rather than compared with a Boolean so that a failure PRINTS
  /// the class of whatever was raised instead of just "expected True".
  cNOEXCEPTION = '<NO EXCEPTION>';
  /// Spelled by cRESOURCEUPDATE in Janus.Server.Resource and by nothing else.
  cHAPPYBODY  = '{"result":"Resource TCustomerTest update command executed successfully"}';

{ TRecordingMonitor }

procedure TRecordingMonitor.Command(const ASQL: String; AParams: TParams);
begin
  FLast := ASQL;
end;

procedure TRecordingMonitor.Show;
begin
end;

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
    + 'mistake. Of the four verbs that share this exit, PUT and DELETE were the '
    + 'two that answered silence; this clause holds PUT, and DELETE is still '
    + 'mute and is pinned by '
    + 'Characterisation_TheUnregisteredResourceExitOfDeleteStillAnswersSilence.');
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

procedure TTestServerResourceUpdateNotFound.Characterisation_TheUnregisteredResourceExitOfDeleteStillAnswersSilence;
var
  LBody: String;
begin
  LBody := _Body(_Delete(cUNMAPPED + '(1)'));
  Assert.AreEqual('', LBody,
    'ParseDelete NOW SAYS SOMETHING FOR AN UNREGISTERED RESOURCE, AND THIS '
    + 'CLAUSE IS THE SIGNAL, NOT A REGRESSION. It held the leftover of issue '
    + '#363: ParseInsert, ParseFind and (since #363) ParseUpdate all raise '
    + 'cRESOURCENOTREGISTER for a nil LClassType, and ParseDelete was the one '
    + 'that still answered an EMPTY BODY. If that is what you just repaired, '
    + 'delete this clause and correct the count in the header of this unit and '
    + 'in the note above ParseUpdate in Janus.Server.Resource. Body was: ['
    + LBody + ']');
  Assert.IsFalse(_Parses(LBody),
    'An empty body cannot parse; if this fails the measurement above is not '
    + 'measuring what it says. Body was: [' + LBody + ']');
end;

procedure TTestServerResourceUpdateNotFound.Characterisation_ANonJsonBodyIsMislabelledAsNotFound;
var
  LBody: String;
begin
  LBody := _Body(_Put('CustomerTest', cNOTJSON));
  Assert.IsTrue(LBody.Contains('found no record'),
    'A BODY THE SERVER CANNOT PARSE IS NO LONGER REPORTED AS A KEY THAT LOCATED '
    + 'NO ROW, AND THIS CLAUSE IS THE SIGNAL, NOT A REGRESSION. It held the half '
    + 'of issue #363 that was deliberately NOT repaired: TJanusJson.JsonToObject '
    + 'fills nothing from an unparseable body, every key column renders as the '
    + 'empty literal, ParseUpdate emits `(1 = 0)` and leaves through the SAME '
    + 'not-found exit - so the caller is told the wrong reason instead of '
    + 'nothing at all. If a JSON parse check now runs before the mapping walk, '
    + 'that is the repair this clause was waiting for: read the header of this '
    + 'unit, delete this clause, and say there what the third mistake answers '
    + 'now. Body was: [' + LBody + ']');
end;

function TTestServerResourceUpdateNotFound._ClientUpdate(const AId: Integer;
  const AName: String; out ARaised: String): String;
var
  LClient: TRESTClientHorse;
  LMonitor: TRecordingMonitor;
  /// Holds the monitor alive and destroys it, whatever happens below.
  /// TRecordingMonitor is a TInterfacedObject: without an interface reference
  /// of our own its refcount only rises when the factory takes it, so a raise
  /// between Create and SetCommandMonitor would leak it silently.
  LMonitorRef: ICommandMonitor;
  LSession: TSessionRestFul<TCustomerTestClientView>;
  LList: TObjectList<TCustomerTestClientView>;
  LRow: TCustomerTestClientView;
begin
  ARaised := cNOEXCEPTION;
  Result := '';
  LMonitor := TRecordingMonitor.Create;
  LMonitorRef := LMonitor;
  LClient := TRESTClientHorse.Create(nil);
  try
    /// The same URL the raw-HTTP clauses above use. JanusServerUse stays FALSE
    /// and the whole prefix goes into APIContext on purpose: with it True,
    /// TSessionRestFul<M>.Create spells the resource out of [Table] -
    /// `customer_test` - and the server would answer "not registered", which is
    /// a different measurement than the one this fixture wants.
    LClient.APIContext := FPrefix;
    LClient.Host := '127.0.0.1';
    LClient.Port := Port;
    LClient.SetCommandMonitor(LMonitor);
    LSession := TSessionRestFul<TCustomerTestClientView>.Create(LClient.AsConnection, nil);
    try
      LRow := TCustomerTestClientView.Create;
      /// OwnsObjects OFF and the row freed here: TSessionRestFul<M>.Update takes
      /// the list as transport and does not own it - issue #362, pinned by
      /// Test.Janus.Rest.ObjectSetOwnership.
      LList := TObjectList<TCustomerTestClientView>.Create(False);
      try
        LRow.Id := AId;
        LRow.Name := AName;
        LRow.Email := 'ghost@test.com';
        LRow.Active := True;
        LList.Add(LRow);
        try
          LSession.Update(LList);
        except
          on E: Exception do
            ARaised := E.ClassName;
        end;
        Result := LMonitor.Last;
      finally
        LList.Free;
        LRow.Free;
      end;
    finally
      LSession.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestServerResourceUpdateNotFound.Premise_TheJanusClientCanDriveThisRouteAtAll;
var
  LId: String;
  LSeen: String;
  LRaised: String;
begin
  LId := _Scalar('SELECT MIN(id) FROM customer_test');
  Assert.AreNotEqual('<null>', LId, 'premise: the seed wrote no row at all.');
  LSeen := _ClientUpdate(StrToInt(LId), 'AliceEditedByTheJanusClient', LRaised);
  Assert.AreEqual(cNOEXCEPTION, LRaised,
    'premise: the real Janus client cannot complete a PUT that DOES find its '
    + 'row, so nothing this fixture measures through it means anything. '
    + 'Got: [' + LRaised + ']');
  Assert.IsTrue(LSeen.Contains('executed successfully'),
    'premise: the real Janus client did not come out of the successful end of '
    + 'ParseUpdate. That wording is spelled by cRESOURCEUPDATE and by nothing '
    + 'else in Source. Monitor saw: [' + LSeen + ']');
  Assert.AreEqual('AliceEditedByTheJanusClient',
    _Scalar('SELECT name FROM customer_test WHERE id = ' + LId),
    'premise: the server answered success to the Janus client and the row did '
    + 'not move, so the client is not driving the route this fixture thinks it '
    + 'is - the keys it serialises are not the keys the server matches.');
end;

procedure TTestServerResourceUpdateNotFound.Characterisation_TheJanusClientSwallowsThisAnswer;
var
  LSeen: String;
  LRaised: String;
begin
  LSeen := _ClientUpdate(StrToInt(cGHOSTKEY), 'Ghost', LRaised);

  /// PREMISE. Without this, "it did not raise" could mean no request was ever
  /// sent. The monitor is fed from the very local the answer was assigned to,
  /// so a pass here is also the proof that the document DID come back.
  Assert.IsTrue(LSeen.Contains('found no record'),
    'premise: the real Janus client did not bring back the not-found document, '
    + 'so the clause below is measuring nothing. THIS IS WHAT THE BASE OF THIS '
    + 'BRANCH LOOKS LIKE: there the monitor is shown an EMPTY Result, because '
    + 'FConnection.Execute raised instead of returning. Caller saw: [' + LRaised
    + ']. Monitor saw: [' + LSeen + ']');

  Assert.AreEqual(cNOEXCEPTION, LRaised,
    'TSessionRestFul<M>.Update NOW SIGNALS A PUT THAT LOCATED NO ROW, AND THIS '
    + 'CLAUSE IS THE SIGNAL, NOT A REGRESSION. Read "WHAT THIS FIXTURE DOES NOT '
    + 'SETTLE" in the header of this unit before changing anything. It pins the '
    + 'PRICE of issue #363: making the server answer a document that PARSES '
    + 'stopped the client raising cRESTNOJSONVALUE - which blamed the caller''s '
    + 'payload - and put NOTHING in its place, because Update assigns the answer '
    + 'to a local that only its CommandMonitor block reads and hands the caller '
    + 'nothing. If you have just given Update a way to signal, this clause has '
    + 'done its job: delete it and say in the header what the caller now gets. '
    + 'Got: [' + LRaised + ']');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestServerResourceUpdateNotFound);

end.
