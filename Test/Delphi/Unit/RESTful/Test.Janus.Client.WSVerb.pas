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

{ @abstract(Janus Framework - which HTTP verb TRESTClientWS puts ON THE WIRE,
  and what its PUT answers.)

  WHAT IS UNDER TEST

    Janus.Client.WS           TRESTClientWS - DoGET, DoPOST, DoPUT and
                              DoDELETE: the verb each one sends, the label each
                              one reports, and the payload DoPUT answers

  ============================================================================
  WHY THIS FIXTURE EXISTS - TWO SURVIVORS DECLARED BY ISSUE #338
  ============================================================================

  #338 measured, and this fixture RE-MEASURED at its own HEAD before writing a
  line, that NOTHING in the RESTfulDriver suite pinned this family's verbs.
  Both mutations were applied with a compiler-echoed directive so that "the
  mutation was really in the binary" is a fact and not an assumption:

    M09  TRESTClientWS.DoPOST  rmPOST -> rmPUT   W1054 echoed at DoPOST
    R7   TRESTClientWS.DoPUT   rmPUT  -> rmPOST  W1054 echoed at DoPUT

  THOSE TWO IDS ARE #338's, AND ONE OF THEM IS TAKEN. Test.Janus.Client.
  ResponseShape numbers its own mutation table from M01, and ITS M09 is a
  different experiment entirely - "POST result discarded again", which kills 2
  of its clauses. The collision is real and it is the reason this paragraph
  spells both mutations out as source edits instead of quoting a bare label: a
  mutation id is only meaningful inside the fixture that assigned it.

  Each was built and run on its own against 0d21f2c: 214 found, 214 passed,
  0 failed - ZERO clauses killed by either. The reason is not that the verb
  does not matter; it is that the #323 stub in Test.Janus.Client.ResponseShape
  answers every verb with the same body, so verb identity is INVISIBLE to it.
  Wire_POST_SendsPOST and Wire_PUT_SendsPUT below are the two clauses that make
  it visible, by reading the verb off the socket instead of inferring it.

  ============================================================================
  THE WS VERBS GO OUT STRAIGHT. THAT IS NOT AN ACCIDENT, AND IT IS NOT THE
  SAME STATEMENT AS THE DataSnap SIBLING'S.
  ============================================================================

  TTestClientDataSnapVerb pins the opposite arrangement for TRESTClientDataSnap
  - POST travels as HTTP PUT and PUT travels as HTTP POST - because DataSnap
  dispatches by METHOD NAME PREFIX and its own table is inverted (Studio 37.0,
  Datasnap.DSService.pas, TDSRESTService.SetMethodNameWithPrefix: 'PUT' ->
  'accept', 'POST' -> 'update', 'DELETE' -> 'cancel'). That compensation is
  correct THERE and would be a defect HERE, and the difference is measurable on
  this class rather than argued from the sibling:

    TRESTClientWS.Create      leaves FAPIContext EMPTY
    TRESTClientDataSnap.Create sets FAPIContext to 'datasnap'

  An empty API context is what NoApiContext_LeavesTheBaseUrlWithoutAContext
  pins below, off the client's own BaseURL. There is no DataSnap dispatcher in
  front of a plain REST endpoint, so there is no prefix rule to compensate and
  the verbs are the operation itself. Straightening the DataSnap client would
  swap insert with update; crossing this one would do the same damage in the
  other direction, against any ordinary REST server.

  ============================================================================
  AND THE OTHER HALF OF #338: DoPUT NEVER ASSIGNED Result
  ============================================================================

  #338 repaired exactly this hole in TRESTClientDataSnap.DoPUT and DELIBERATELY
  left it open here, because the contract had been measured on THAT class and
  "the sibling does it" is not an argument this house accepts. So the contract
  was measured on THIS class, and it is NOT the same contract:

    DoGET     Result := ResponsePayload(JSONValue, Length(RootElement) > 0)
    DoPOST    Result := ResponsePayload(JSONValue, Length(RootElement) > 0)
    DoDELETE  Result := ResponsePayload(JSONValue, Length(RootElement) > 0)
    DoPUT     - no assignment at all -

  Three of the four agree, and the fourth answers '' by construction. The
  expression the three share is the WS class's own, and it has TWO ARMS here
  where the DataSnap one has only one:

    TRESTClientWS.Create        FRESTResponse.RootElement := ''   -> NO unwrap
    TRESTClientDataSnap.Create  FRESTResponse.RootElement := 'result'

  and RootElement is a PUBLISHED, WRITABLE property of TRESTClientWS alone, so
  the flag is genuinely variable here and constant-True there. That is why the
  DataSnap repair could be pinned with one clause per outcome and this one
  needs both arms driven: PUT_NoRootElement_AnswersTheWholeBody and
  PUT_RootElement_AnswersTheEnvelopePayload are two different facts, and a
  repair that satisfied only one of them would be wrong for the default
  configuration of this very class.

  Both are red against 0d21f2c, and so is PUT_AnswerReachesTheCaller - because
  TRESTClientWS.Execute called DoPUT as a STATEMENT, the one arm of its case
  that did not assign Result.

  JOINING THE CONTRACT MEANS JOINING ITS FAILURE HALF

  ResponsePayload raises INSIDE the try of the calling method for a nil,
  non-array or empty answer. A PUT that read nothing could not fail that way;
  one that answers the payload can, and must, exactly as its three siblings in
  this class already do. PUT_RootElement_Absent_IsNamed drives it.

  ============================================================================
  THE LABEL AND THE WIRE AGREE HERE - PINNED IN BOTH DIRECTIONS
  ============================================================================

  Label_AndWire_AgreeForEveryVerb is the WS counterpart of the DataSnap
  fixture's Label_AndWire_DisagreeForBothWriteVerbs, and the pair is what makes
  either one mean anything. Exception_Method_CarriesNoWireAnnotation states the
  same fact where a reader actually meets it - the 'Method : ' line of
  EJanusRESTException. On the DataSnap side that line now reads
  'PUT (wire: POST)' because the two DO diverge there; here it stays plain
  because they do not, and the annotation is driven by the divergence and not
  by the class.

  HOW THE VERB IS OBSERVED

  Off the socket. The stub records ARequestInfo.Command - the verb that
  actually crossed - in the pattern Test.Janus.Client.DataSnapVerb established.
  Nothing is modelled here: unlike the DataSnap fixture there is no dispatch
  rule to reproduce, because a plain REST endpoint has none.

  ============================================================================
  MUTATION - EVERY FIGURE MEASURED, EVERY SURVIVOR DECLARED
  ============================================================================

  Janus.Tests.RESTfulDriver Debug/Win32, 233 clauses, 233/0/0 unmutated. Each
  mutation applied with a $MESSAGE WARN directive - written without its braces
  HERE, because inside this comment they would close it - and the W1054 echo
  checked BEFORE the
  run - a mutation the compiler did not report is not in the binary, and a
  green suite would then be meaningless. Each reverted immediately after. The
  figures are clauses killed ACROSS THE WHOLE BINARY, so a mutation that
  reached another fixture would show here.

    TRESTClientWS.DoPOST / DoPUT - the verb on the wire
      M09  DoPOST sends rmPUT instead of rmPOST              2
      R7   DoPUT sends rmPOST instead of rmPUT               2
    TRESTClientWS.DoPUT - the root-element rule it now obeys
      W1   DoPUT never unwraps    (flag forced False)        1
      W2   DoPUT always unwraps   (flag forced True)         5
    TRESTClientWS.Execute - the frame above it
      W3   the PUT answer is discarded again                 3

  5 mutations, NO SURVIVORS.

  W1 AND W2 ARE THE PAIR THAT MATTERS, and they are complementary rather than
  redundant: W1 kills ONLY PUT_RootElement_AnswersTheEnvelopePayload and W2
  kills PUT_NoRootElement_AnswersTheWholeBody and spares the other. Each kills
  what the other leaves alone. THAT is the measurement behind this header's
  claim that the WS contract has two live arms - without it the claim would be
  an assertion, and one clause would look like enough.

  W2's other three kills are collateral and are recorded as such: forcing the
  unwrap makes DoPUT raise before the assertion in Wire_PUT_SendsPUT,
  Label_PUT_IsPUT and Label_AndWire_AgreeForEveryVerb is reached. They are not
  evidence about the root-element rule.

  M09 and R7 both kill Label_AndWire_AgreeForEveryVerb as well as their own
  Wire_ clause, which is the point of that clause existing.

  AND THE RED-FIRST HALF, which mutation cannot show: against 0d21f2c the five
  clauses PUT_NoRootElement_AnswersTheWholeBody,
  PUT_RootElement_AnswersTheEnvelopePayload, PUT_AnswerReachesTheCaller,
  PUT_RootElement_Absent_IsNamed and Exception_Method_CarriesNoWireAnnotation
  were all RED. 228 found / 223 passed / 5 failed.

  NOT MEASURED HERE

  Nothing in this fixture speaks to the public web service the shipped example
  points TRESTClientWS at, nor to rtPATCH - which TRESTClientWS.Execute maps to
  an empty case arm, unchanged by this work. Nor is any of it measured against
  a real server: the stub is a loan Indy listener, so what is pinned is the
  verb this client SENDS, never what a server does with it.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Client.WSVerb;

{$IFNDEF DRIVERRESTFUL}
{$MESSAGE FATAL 'This unit belongs to the DRIVERRESTFUL configuration.'}
{$ENDIF}

interface

uses
  Classes,
  SysUtils,
  StrUtils,
  JSON,
  DUnitX.TestFramework,
  IdContext,
  IdCustomHTTPServer,
  IdHTTPServer,
  IdSocketHandle,
  Janus.Client,
  Janus.Client.Base,
  Janus.Client.Methods,
  Janus.Client.RestException,
  Janus.Client.WS;

type
  /// <summary>
  ///   A loan server that answers every verb with one body the test chooses,
  ///   and REMEMBERS the verb that arrived. The verb on the wire is the whole
  ///   question here, so it is read off the request rather than inferred.
  /// </summary>
  TWSVerbRecorderServer = class
  private
    FServer: TIdHTTPServer;
    FPort: Integer;
    FBody: String;
    FLastVerb: String;
    FHits: Integer;
    procedure DoCommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
  public
    constructor Create;
    destructor Destroy; override;
    property Port: Integer read FPort;
    property Body: String read FBody write FBody;
    property LastVerb: String read FLastVerb;
    property Hits: Integer read FHits;
  end;

  [TestFixture]
  TTestClientWSVerb = class
  private
    FStub: TWSVerbRecorderServer;
    FWS: TRESTClientWS;
    FLabelSeen: String;
    FAnswerSeen: String;
    /// TAfterCommandEvent is a method pointer, not an anonymous method, so the
    /// handler has to be a method of the fixture.
    procedure CaptureAfterCommand(AStatusCode: Integer;
      var AResponseString: String; ARequestMethod: String);
    /// Runs one verb over the live stub and answers what Execute answered.
    function Run(const ARequestMethod: TRESTRequestMethodType;
      const ARootElement, ABody: String): String;
    /// Runs one verb and answers the message of the EJanusRESTException that
    /// has to come out of it.
    function Capture(const ARequestMethod: TRESTRequestMethodType;
      const ARootElement, ABody: String): String;
    /// Value printed under ALabel in an EJanusRESTException message, or a
    /// sentinel that can never be mistaken for one when the label is absent.
    /// Same reader as Test.Janus.Client.RestExceptionFields uses, and for the
    /// same reason: a whole-message Contains cannot see WHICH line a value
    /// landed on.
    function FieldOf(const AMessage, ALabel: String): String;
    /// An envelope carrying one distinct payload, in the shape a configured
    /// root element makes the client unwrap.
    function Envelope(const APayload: String): String;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// The premise. Equal markers would let a cross-wire between two verbs
    /// pass for a pass.
    [Test]
    procedure Markers_AreAllDistinct;

    /// ---- THE VERB THAT CROSSES THE SOCKET ----
    ///
    /// Four clauses, one per verb. The two write verbs are the ones mutations
    /// M09 and R7 attack and the two read verbs are the control: a repair that
    /// crossed the pair the way the DataSnap client does would leave GET and
    /// DELETE untouched, so pinning only the write pair would not say whether
    /// this family compensates anything.

    [Test]
    procedure Wire_GET_SendsGET;
    [Test]
    procedure Wire_DELETE_SendsDELETE;
    /// KILLS M09. The WS client speaks plain REST: a POST is a POST.
    [Test]
    procedure Wire_POST_SendsPOST;
    /// KILLS R7. Likewise a PUT is a PUT.
    [Test]
    procedure Wire_PUT_SendsPUT;

    /// ---- WHY THEY GO OUT STRAIGHT ----
    ///
    /// The measurable difference from the DataSnap sibling, taken off THIS
    /// client rather than asserted about it.

    [Test]
    procedure NoApiContext_LeavesTheBaseUrlWithoutAContext;

    /// ---- THE LABEL THE MONITOR AND THE EXCEPTION CARRY ----

    [Test]
    procedure Label_POST_IsPOST;
    [Test]
    procedure Label_PUT_IsPUT;
    /// The counterpart of the DataSnap fixture's ..._DisagreeForBothWriteVerbs.
    [Test]
    procedure Label_AndWire_AgreeForEveryVerb;
    /// And the same fact where a reader meets it: no '(wire: ...)' annotation,
    /// because there is no divergence to annotate.
    [Test]
    procedure Exception_Method_CarriesNoWireAnnotation;

    /// ---- WHAT DoPUT ANSWERS ----
    ///
    /// The half of #338 left open on this side. Both arms of the class's own
    /// root-element rule are driven; see the header for why one would not do.

    [Test]
    procedure PUT_NoRootElement_AnswersTheWholeBody;
    [Test]
    procedure PUT_RootElement_AnswersTheEnvelopePayload;
    [Test]
    procedure PUT_AnswerReachesTheCaller;
    /// Joining that contract means joining its failure half.
    [Test]
    procedure PUT_RootElement_Absent_IsNamed;
  end;

implementation

const
  cLOOPBACK = '127.0.0.1';
  cROOT     = 'result';

  /// One distinct marker per verb - a cross-wire cannot pass for a pass.
  cWSV_GET    = '{"s338ws":"ws-get"}';
  cWSV_POST   = '{"s338ws":"ws-post"}';
  cWSV_PUT    = '{"s338ws":"ws-put"}';
  cWSV_DELETE = '{"s338ws":"ws-delete"}';

  cABSENT     = '<<label-absent>>';

{ TWSVerbRecorderServer }

constructor TWSVerbRecorderServer.Create;
var
  LBinding: TIdSocketHandle;
  LFor: Integer;
begin
  inherited Create;
  FBody := '{}';
  FLastVerb := '';
  FHits := 0;
  FServer := TIdHTTPServer.Create(nil);
  FServer.OnCommandGet := DoCommandGet;
  /// PUT and DELETE arrive through OnCommandOther, not OnCommandGet, and this
  /// fixture exists to observe precisely those.
  FServer.OnCommandOther := DoCommandGet;
  /// <summary>
  ///   Hunts for a free port rather than fixing one, for the reason the two
  ///   neighbouring stubs record: a port still in TIME_WAIT from an earlier run
  ///   would fail the bind and turn the suite red for a reason unrelated to
  ///   what is measured.
  ///
  ///   Re-enumerated at THIS HEAD, every listener under Test\Delphi - eight of
  ///   them, and the ranges are the ones each one actually binds:
  ///
  ///     9700..9799  RestHorseOracleTest.Base             RESTOracle
  ///     9730..9789  Test.Janus.Driver.HorseExecuteOverload
  ///                                                      RESTfulDriver
  ///     9800..9829  THIS STUB                            RESTfulDriver
  ///     9830..9889  Test.Janus.Driver.WiRLExecuteOverload RESTWiRL
  ///     9840..9879  Test.Janus.Client.RestExceptionFields RESTMARS
  ///     9890..9989  RestHorseTest.Base                   RESTHorse
  ///     9900..9939  Test.Janus.Client.ResponseShape      RESTfulDriver
  ///     9930..9989  Test.Janus.Driver.WiRLTokenAcquire   RESTWiRL
  ///     9940..9979  Test.Janus.Client.DataSnapVerb       RESTfulDriver
  ///
  ///   9800..9829 was the gap: it is disjoint from ALL eight, not merely from
  ///   the three that share this binary. So a listener left over from an
  ///   earlier run of any suite cannot collide with it either - and the upward
  ///   scan walks past one that somehow did.
  /// </summary>
  for LFor := 0 to 29 do
  begin
    FPort := 9800 + LFor;
    FServer.Bindings.Clear;
    LBinding := FServer.Bindings.Add;
    LBinding.IP := cLOOPBACK;
    LBinding.Port := FPort;
    try
      FServer.Active := True;
      Exit;
    except
      on E: Exception do
        ;
    end;
  end;
  raise Exception.Create('No free port for the WS verb stub HTTP server.');
end;

destructor TWSVerbRecorderServer.Destroy;
begin
  if FServer.Active then
    FServer.Active := False;
  FServer.Free;
  inherited;
end;

procedure TWSVerbRecorderServer.DoCommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
begin
  FLastVerb := UpperCase(ARequestInfo.Command);
  Inc(FHits);
  AResponseInfo.ResponseNo := 200;
  AResponseInfo.ContentType := 'application/json';
  AResponseInfo.ContentText := FBody;
end;

{ TTestClientWSVerb }

procedure TTestClientWSVerb.Setup;
begin
  FLabelSeen := '';
  FAnswerSeen := '';
  FStub := TWSVerbRecorderServer.Create;
  FWS := TRESTClientWS.Create(nil);
  FWS.Host := cLOOPBACK;
  FWS.Port := FStub.Port;
end;

procedure TTestClientWSVerb.TearDown;
begin
  FreeAndNil(FWS);
  FreeAndNil(FStub);
end;

procedure TTestClientWSVerb.CaptureAfterCommand(AStatusCode: Integer;
  var AResponseString: String; ARequestMethod: String);
begin
  FLabelSeen := ARequestMethod;
  FAnswerSeen := AResponseString;
end;

function TTestClientWSVerb.Envelope(const APayload: String): String;
begin
  Result := '{"' + cROOT + '":[' + APayload + ',{"tail":"ignored"}]}';
end;

function TTestClientWSVerb.FieldOf(const AMessage, ALabel: String): String;
var
  LLines: TStringList;
  LPrefix: String;
  LFor: Integer;
begin
  Result := cABSENT;
  LPrefix := ALabel + ' : ';
  LLines := TStringList.Create;
  try
    LLines.Text := AMessage;
    for LFor := 0 to LLines.Count - 1 do
    begin
      if StartsStr(LPrefix, LLines[LFor]) then
      begin
        Result := Copy(LLines[LFor], Length(LPrefix) + 1, MaxInt);
        Exit;
      end;
    end;
  finally
    LLines.Free;
  end;
end;

function TTestClientWSVerb.Run(const ARequestMethod: TRESTRequestMethodType;
  const ARootElement, ABody: String): String;
begin
  FStub.Body := ABody;
  FWS.RootElement := ARootElement;
  Result := FWS.Execute('s338ws', '', ARequestMethod,
                        procedure
                        begin
                          /// The write verbs refuse an empty body before it
                          /// reaches the wire; the content itself does not
                          /// matter to what is measured here.
                          FWS.AddBodyParam('{"probe":1}');
                        end);
end;

function TTestClientWSVerb.Capture(
  const ARequestMethod: TRESTRequestMethodType;
  const ARootElement, ABody: String): String;
begin
  Result := '';
  try
    Run(ARequestMethod, ARootElement, ABody);
  except
    on E: EJanusRESTException do
      Result := E.Message;
  end;
  Assert.AreNotEqual('', Result,
    'The call should have raised EJanusRESTException.');
end;

procedure TTestClientWSVerb.Markers_AreAllDistinct;
begin
  Assert.AreNotEqual(cWSV_GET, cWSV_POST);
  Assert.AreNotEqual(cWSV_GET, cWSV_PUT);
  Assert.AreNotEqual(cWSV_GET, cWSV_DELETE);
  Assert.AreNotEqual(cWSV_POST, cWSV_PUT);
  Assert.AreNotEqual(cWSV_POST, cWSV_DELETE);
  Assert.AreNotEqual(cWSV_PUT, cWSV_DELETE);
end;

procedure TTestClientWSVerb.Wire_GET_SendsGET;
begin
  Run(TRESTRequestMethodType.rtGET, '', cWSV_GET);
  Assert.AreEqual(1, FStub.Hits, 'The stub was not reached at all.');
  Assert.AreEqual('GET', FStub.LastVerb);
end;

procedure TTestClientWSVerb.Wire_DELETE_SendsDELETE;
begin
  Run(TRESTRequestMethodType.rtDELETE, '', cWSV_DELETE);
  Assert.AreEqual(1, FStub.Hits, 'The stub was not reached at all.');
  Assert.AreEqual('DELETE', FStub.LastVerb);
end;

procedure TTestClientWSVerb.Wire_POST_SendsPOST;
begin
  Run(TRESTRequestMethodType.rtPOST, '', cWSV_POST);
  Assert.AreEqual(1, FStub.Hits, 'The stub was not reached at all.');
  Assert.AreEqual('POST', FStub.LastVerb,
    'A WS INSERT travels as HTTP POST. This client speaks plain REST - its ' +
    'API context is empty, so nothing dispatches it by method-name prefix ' +
    'and there is no inversion to compensate. Sending PUT here would be the ' +
    'DataSnap compensation applied where it does not belong.');
end;

procedure TTestClientWSVerb.Wire_PUT_SendsPUT;
begin
  Run(TRESTRequestMethodType.rtPUT, '', cWSV_PUT);
  Assert.AreEqual(1, FStub.Hits, 'The stub was not reached at all.');
  Assert.AreEqual('PUT', FStub.LastVerb,
    'A WS UPDATE travels as HTTP PUT, for the mirror of the reason in ' +
    'Wire_POST_SendsPOST. Sending POST here would reach whatever a plain ' +
    'REST server routes POST to - which is the insert, not the update.');
end;

procedure TTestClientWSVerb.NoApiContext_LeavesTheBaseUrlWithoutAContext;
begin
  /// The measurable difference from TRESTClientDataSnap, taken off this
  /// client's OWN BaseURL rather than argued. TRESTClientWS.Create leaves
  /// FAPIContext empty and SetBaseURL appends it, so the address ends at the
  /// port; TRESTClientDataSnap.Create sets 'datasnap' and its address carries
  /// that segment. No prefix dispatcher stands in front of this one, so its
  /// verbs are the operation itself.
  Assert.AreEqual('', FWS.APIContext,
    'TRESTClientWS.Create leaves the API context empty.');
  Assert.IsFalse(ContainsText(FWS.BaseURL, 'datasnap'),
    'The WS address carries no DataSnap context: ' + FWS.BaseURL);
  Assert.AreEqual('http://' + cLOOPBACK + ':' + IntToStr(FStub.Port) + '/',
                  FWS.BaseURL,
    'The base address ends at the port, with no context segment after it.');
end;

procedure TTestClientWSVerb.Label_POST_IsPOST;
begin
  FWS.OnAfterCommand := CaptureAfterCommand;
  Run(TRESTRequestMethodType.rtPOST, '', cWSV_POST);
  Assert.AreEqual('POST', FLabelSeen);
end;

procedure TTestClientWSVerb.Label_PUT_IsPUT;
begin
  FWS.OnAfterCommand := CaptureAfterCommand;
  Run(TRESTRequestMethodType.rtPUT, '', cWSV_PUT);
  Assert.AreEqual('PUT', FLabelSeen);
end;

procedure TTestClientWSVerb.Label_AndWire_AgreeForEveryVerb;
begin
  /// The counterpart of TTestClientDataSnapVerb.
  /// Label_AndWire_DisagreeForBothWriteVerbs. Neither statement means anything
  /// without the other: "they agree" is only informative once there is a
  /// family in the same tree where they do not.
  FWS.OnAfterCommand := CaptureAfterCommand;

  Run(TRESTRequestMethodType.rtGET, '', cWSV_GET);
  Assert.AreEqual(FLabelSeen, FStub.LastVerb, 'GET: label and wire differ.');

  FLabelSeen := '';
  Run(TRESTRequestMethodType.rtPOST, '', cWSV_POST);
  Assert.AreEqual(FLabelSeen, FStub.LastVerb, 'POST: label and wire differ.');

  FLabelSeen := '';
  Run(TRESTRequestMethodType.rtPUT, '', cWSV_PUT);
  Assert.AreEqual(FLabelSeen, FStub.LastVerb, 'PUT: label and wire differ.');

  FLabelSeen := '';
  Run(TRESTRequestMethodType.rtDELETE, '', cWSV_DELETE);
  Assert.AreEqual(FLabelSeen, FStub.LastVerb, 'DELETE: label and wire differ.');
end;

procedure TTestClientWSVerb.Exception_Method_CarriesNoWireAnnotation;
var
  LMessage: String;
begin
  /// TRESTClientDataSnap now prints 'PUT (wire: POST)' under 'Method : ',
  /// because on that class the two genuinely diverge. The annotation is driven
  /// by the DIVERGENCE and not by the class, so here - where they agree - the
  /// line has to stay plain. Read as a field, not as a substring: 'PUT' is
  /// contained in 'PUT (wire: POST)' too, and a Contains assertion could not
  /// tell the two apart.
  LMessage := Capture(TRESTRequestMethodType.rtPUT, cROOT,
                      '{"no-result-key":1}');
  Assert.AreEqual('PUT', FieldOf(LMessage, 'Method'),
    'The WS label and wire agree, so the Method line carries no annotation.');
  Assert.IsFalse(ContainsStr(LMessage, '(wire:'),
    'Nothing on this class diverges, so nothing is annotated.');
end;

procedure TTestClientWSVerb.PUT_NoRootElement_AnswersTheWholeBody;
begin
  /// The DEFAULT configuration of this class: TRESTClientWS.Create leaves
  /// RootElement empty, so there is no envelope and the value IS the payload.
  Assert.AreEqual(cWSV_PUT,
    Run(TRESTRequestMethodType.rtPUT, '', cWSV_PUT),
    'DoPUT executed the request and returned without ever assigning Result, ' +
    'so every PUT answered '''' whatever the server said. Its three siblings ' +
    'in THIS class all answer ResponsePayload under this class''s own ' +
    'root-element rule.');
end;

procedure TTestClientWSVerb.PUT_RootElement_AnswersTheEnvelopePayload;
begin
  /// The other arm of the same rule, which the DataSnap repair had no need to
  /// distinguish because RootElement is constant there. A repair that answered
  /// the whole body unconditionally would pass the clause above and fail this
  /// one; a repair that unwrapped unconditionally would do the reverse.
  Assert.AreEqual(cWSV_PUT,
    Run(TRESTRequestMethodType.rtPUT, cROOT, Envelope(cWSV_PUT)),
    'With a root element configured the answer is an envelope, and the ' +
    'payload is its FIRST element.');
end;

procedure TTestClientWSVerb.PUT_AnswerReachesTheCaller;
begin
  /// The same fact one frame up. TRESTClientWS.Execute called DoPUT as a
  /// STATEMENT - the single arm of its case that did not assign Result - so
  /// even a DoPUT that answered correctly would have been dropped here, and
  /// TRESTDriverWS would still have seen ''.
  FWS.OnAfterCommand := CaptureAfterCommand;
  Run(TRESTRequestMethodType.rtPUT, '', cWSV_PUT);
  Assert.AreEqual(cWSV_PUT, FAnswerSeen);
end;

procedure TTestClientWSVerb.PUT_RootElement_Absent_IsNamed;
var
  LMessage: String;
begin
  /// The failure half of the contract PUT has now joined. With a root element
  /// configured and no such key in the body, TRESTResponse.JSONValue is nil -
  /// which is the ordinary shape of a failed call - and ResponsePayload raises
  /// inside DoPUT's try, so the handler already written there reports it with
  /// the server body still attached. Before the repair DoPUT read nothing and
  /// this was swallowed in silence.
  LMessage := Capture(TRESTRequestMethodType.rtPUT, cROOT,
                      '{"no-result-key":1}');
  Assert.AreEqual('PUT', FieldOf(LMessage, 'Method'),
    'The exception names the method that failed.');
  Assert.AreEqual(cRESTNOJSONVALUE, FieldOf(LMessage, 'Error'),
    'And it names WHICH of the three malformed shapes ran.');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestClientWSVerb);

end.
