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

{ @abstract(Janus Framework - the SHAPE of the answer the DataSnap and WS
  clients read, and what Execute does with it.)

  WHAT IS UNDER TEST

    Janus.Client              TJanusClient.ResponsePayload - the rule that says
                              whether the response value IS the payload or
                              CARRIES it, and what happens when it is neither
    Janus.Client.WS           TRESTClientWS - DoGET, DoPOST, DoDELETE and,
                              separately, what Execute returns
    Janus.Client.DataSnap     TRESTClientDataSnap - DoGET, DoPOST, DoDELETE

  NO PROJECT COMPILED EITHER CLIENT UNTIL THIS FIXTURE

  Measured at 0546a51 with a compile tripwire, not with grep: a $MESSAGE ERROR
  directive placed in the interface of Janus.Client.DataSnap and of
  Janus.Client.WS was echoed by NONE of the seven test projects, while the same
  tripwire in Janus.Client.Horse - the positive control, without which the probe
  would only have proved itself blind - failed Janus.Tests.RESTfulDriver and
  only that one. Inside Source both are reachable from nothing but each other:
  the client is used by its own RestDriver, the RestDriver by its own Factory,
  and the Factory by the client.

  THREE SHIPPED EXAMPLES DO NAME THEM, AND THAT IS THE POINT, NOT AN EXCEPTION

  Examples\Delphi\Datasnap\Client\JanusFireDAC.dpr carries
  Janus.Client.DataSnap in its own uses clause; uMainFormORM.pas under
  Examples\Delphi\RESTful\RESTFul via Driver\Datasnap\Client builds a
  TRESTClientDataSnap; uPrincipal.pas under ...\WebService builds a
  TRESTClientWS and points it at a public address web service. Those are
  standalone VCL programs that the suite never builds. So the two families are
  demonstrated to users and were covered by nothing - which is a worse state
  than dead code, not a better one.

  That is why the two of them are now in the uses of Janus.Tests.RESTfulDriver:
  a repair to a unit no compiler reads is not a repair.

  THE THREE SHAPES, AND WHY NONE OF THEM ANSWERS ''

  All six sites read the answer as (JSONValue as TJSONArray).Items[0], and
  each of the three ways that can go wrong used to escape as a DIFFERENT untyped
  error:

    JSONValue is nil     "Access violation at address ... in module
                         Janus.Tests.RESTfulDriver.exe" - nil as TJSONArray is
                         nil in Delphi, so the index dereferenced nil
    not an array         "Invalid class typecast"
    empty array          "List index out of bounds (0).
                         TList<System.JSON.TJSONValue> is empty"

  Those three are the strings a run of 0546a51 WITH THIS FIXTURE IN IT printed
  under 'Error : ' - not a reading of which exception class the RTL raises.

  None of the three names HTTP, server or response. All three are now
  EJanusRESTResponseShape raised INSIDE the try that was already there, so the
  handler already written reports it - through FErrorCommand when one is
  assigned, or wrapped in an EJanusRESTException naming URL, resource, method,
  status and body.

  They stay ERRORS, and the nil case is why. TCustomRESTResponse.GetJSONValue
  answers nil for an empty body, for a non-JSON body AND for a CONFIGURED ROOT
  ELEMENT THAT IS ABSENT (Studio 37.0, REST.Client.pas, GetJSONResponse raises
  EJSONValueError.InvalidRootElement and GetJSONValue swallows it). The DataSnap
  client configures RootElement 'result' in its constructor, and a DataSnap
  server that fails answers a body with no 'result' key at all - so nil is the
  ORDINARY shape of a failed call there, and answering '' to it would swallow
  every server error this client can receive. DataSnap_GET_AbsentResultKey_*
  drives exactly that body.

  WHETHER AN EMPTY ENVELOPE SHOULD ANSWER '' IS NOT DECIDED HERE

  an empty array under the root element is the one of the three that could be read as "no
  data" rather than "wrong shape", and issue #323 says so. It is left as an
  error, because the house does not answer it unanimously AT THIS SEAM: the
  precedents that read no answer as an answer (#297, #315, #320) are all one
  layer up, in the session, and inside these six methods every abnormal outcome
  reports. Answering '' to an empty envelope while nil still reports would put
  two answers to one question inside one method - which is what #315's own
  repair refused to do. It is reported as the owner's call.

  EVERY SITE IS DRIVEN, NONE IS ARGUED FROM ITS SIBLING

  Six sites, six verbs' worth of tests, each with its OWN marker in the body, so
  a cross-wire between two of them cannot pass for a pass. The six were NOT
  identical before this repair - TRESTClientWS.DoGET already branched on the
  root element and its DoPOST and DoDELETE did not - which is precisely the
  reason not to argue any of them from the others.

  WHAT EXECUTE DID WITH ALL OF IT, ON THE WS SIDE

  TRESTClientWS.Execute called DoPOST, DoPUT, DoGET and DoDELETE as STATEMENTS
  and never assigned Result, so it answered '' to every request ever made
  through it - the payload the six sites work to produce was read and dropped
  one frame above them. That is why every WS_Execute_* clause is red against
  0546a51 - though not all of them for that reason ALONE: the two that send no
  root element also had DoPOST and DoDELETE unwrapping unconditionally, and
  WS_Execute_DELETE_NoRootElement_AnswersTheWholeBody is the one that came out
  as an ERROR rather than a failure, because that unwrap raised EInvalidCast
  and the handler turned it into an EJanusRESTException. The PUT arm is left as a statement: TRESTClientWS.DoPUT reads nothing
  from the response and never assigns its own Result, so there is no payload
  there to lose and assigning it would pin nothing.

  ============================================================================
  MUTATION - EVERY FIGURE MEASURED, EVERY SURVIVOR DECLARED
  ============================================================================

  Measured on the tree this fixture ships in, Janus.Tests.RESTfulDriver
  Debug/Win32, 174 clauses, 174/0/0 unmutated. Every mutation carries a
  MESSAGE WARN 'S323-MUT-Mnn' directive on the line it changes and is listed
  only after dcc32 echoed it back as W1054 IN THE SAME BUILD. The directive is
  spelled without its braces on purpose: it is a directive, not a comment, and
  pasting it whole inside a curly-brace comment closes that comment at its own
  brace - which kills the build and leaves the PREVIOUS exe on disk to report a
  green that was never run.

    what was mutated                                  clauses killed

    TJanusClient.ResponseValue
      M01/M18 nil guard never fires                          9
      M23  ResponsePayload stops calling it                  5
      M08  raises Exception instead of the named class       2
    TJanusClient.ResponsePayload
      M02  always unwrap  (flag ignored, False arm dead)     6
      M03  never unwrap   (flag ignored, True arm dead)     19
      M04  non-array accepted                                6
      M05  empty envelope accepted                           4
      M06  answers the LAST element, not the first           9
      M07  empty envelope raises the not-an-array reason     4
      M28  the no-envelope arm renders ToString              1
      M29  the unwrapped element renders ToString            1
    TRESTClientWS.Execute
      M09  POST result discarded again                       2
      M10  GET result discarded again                        2
      M11  DELETE result discarded again                     2
    the root-element flag, one site at a time
      M12  WS DoDELETE always unwraps                        1
      M13  WS DoGET never unwraps                            4
      M14  WS DoPOST always unwraps                          1
      M15  DataSnap DoDELETE never unwraps                   1
      M16  DataSnap DoGET never unwraps                      3
      M17  DataSnap DoPOST never unwraps                     1
    TRESTClientHorse, one site at a time
      M19  DoDELETE unguarded again                          1
      M20  DoGET unguarded again                             1
      M21  DoPOST unguarded again                            1
      M22  DoPUT unguarded again                             1
      M24  DoDELETE renders ToJSON like its siblings         1
      M25  DoGET renders ToString                            1
      M26  DoPOST renders ToString                           1
      M27  DoPUT renders ToString                            1

  29 mutations, NO SURVIVORS.

  SIX OF THEM SURVIVED UNTIL THE CORPUS WAS FIXED, AND THAT IS THE LESSON HERE

  M24 through M29 - every renderer swap - survived a fully green 168-clause run
  before the above-127 clauses existed, because EVERY MARKER IN THIS FIXTURE
  WAS PURE ASCII and ToJSON and ToString render pure ASCII identically. Three
  of the six were found by an independent review, and re-measuring reproduced
  those three AND three more of the same shape. A corpus that cannot express a
  distinction cannot test it, however many clauses it has.

  Worse than the count: M24 is exactly the asymmetry the repair had DECLARED
  and deliberately not decided. A decision recorded only in prose is a decision
  nothing defends.

  THE ONE EQUIVALENT MUTATION, DECLARED

  Flipping the root-element flag at the three DataSnap sites to a literal True
  changes nothing that any clause can see, and it is a TRUE equivalent rather
  than a gap: RootElement is a published property of TRESTClientWS only, and
  TRESTClientDataSnap pins it to 'result' in its constructor with no way in
  from outside. So the expression is constant-True for that class TODAY. The
  expression is kept rather than replaced by the constant because the rule
  belongs to the response object and not to this class's constructor - and the
  OTHER direction of the same mutation is not equivalent at all: M15, M16 and
  M17 force it False and all three die.

  ANCHORS ARE BY METHOD, NEVER BY file:line.
}

unit Test.Janus.Client.ResponseShape;

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
  Janus.Client.DataSnap,
  Janus.Client.Horse,
  Janus.Client.WS;

type
  /// <summary>
  ///   A loan server that answers EVERY verb and EVERY path with one body that
  ///   the test chooses. The shapes under test are shapes of a RESPONSE, so a
  ///   dead port cannot produce any of them - only a live answer can.
  /// </summary>
  TStubShapeServer = class
  private
    FServer: TIdHTTPServer;
    FPort: Integer;
    FBody: String;
    FContentType: String;
    procedure DoCommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
  public
    constructor Create;
    destructor Destroy; override;
    property Port: Integer read FPort;
    property Body: String read FBody write FBody;
    property ContentType: String read FContentType write FContentType;
  end;

  [TestFixture]
  TTestClientResponseShape = class
  private
    FStub: TStubShapeServer;
    FWS: TRESTClientWS;
    FDataSnap: TRESTClientDataSnap;
    FHorse: TRESTClientHorse;
    FErrorSeen: String;
    /// TErrorCommandEvent is a method pointer and not an anonymous method, so
    /// the handler has to be a method of the fixture.
    procedure CaptureErrorCommand(const AURLBase, AResource, ASubResource,
      ARequestMethod, AMessage: String; const AResponseCode: Integer);
    /// Builds a JSON value from text and hands ownership to the caller.
    function Parsed(const AJson: String): TJSONValue;
    /// Runs one verb over the live stub and answers what Execute answered.
    function RunWS(const ARequestMethod: TRESTRequestMethodType;
      const ARootElement, ABody: String): String;
    function RunDataSnap(const ARequestMethod: TRESTRequestMethodType;
      const ABody: String): String;
    /// Runs one verb over the live stub and answers the message of the
    /// EJanusRESTException that has to come out of it.
    function CaptureWS(const ARequestMethod: TRESTRequestMethodType;
      const ARootElement, ABody: String): String;
    function CaptureDataSnap(const ARequestMethod: TRESTRequestMethodType;
      const ABody: String): String;
    /// Same, for the Horse client - which has no root element and so never
    /// unwraps, and whose only reachable shape failure is the absent value.
    function CaptureHorse(const ARequestMethod: TRESTRequestMethodType;
      const ABody: String): String;
    /// The Horse HAPPY path, which is where the RENDERING of the answer is
    /// decided and where an ASCII-only corpus sees nothing.
    function RunHorse(const ARequestMethod: TRESTRequestMethodType;
      const ABody: String): String;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// The premise. Two equal markers would let a cross-wire pass, and two
    /// equal shape messages would let a clause pass on the wrong branch.
    [Test]
    procedure Markers_AreAllDistinct;

    /// ---- TJanusClient.ResponsePayload, on its own ----

    /// nil is an error whether or not an envelope was expected: the caller has
    /// no value at all, and which unwrapping rule applies cannot change that.
    [Test]
    procedure Payload_Nil_Raises_Unwrapping;
    [Test]
    procedure Payload_Nil_Raises_NotUnwrapping;

    /// Without an envelope the value IS the payload - and that holds for an
    /// ARRAY as much as for an object, which is what tells this apart from
    /// "unwrap whenever you can".
    [Test]
    procedure Payload_NoEnvelope_AnswersTheObjectVerbatim;
    [Test]
    procedure Payload_NoEnvelope_AnswersTheArrayVerbatim;

    /// With an envelope only the FIRST element comes out. Two elements, so
    /// "answers the last" and "answers the whole array" both die.
    [Test]
    procedure Payload_Envelope_AnswersTheFirstElementOnly;
    /// The same rule over a different envelope, so a constant cannot pass.
    [Test]
    procedure Payload_Envelope_AnswersTheFirstElementOnly_OtherValues;

    /// The shapes an envelope can fail to be.
    [Test]
    procedure Payload_Envelope_Object_Raises;
    [Test]
    procedure Payload_Envelope_String_Raises;
    [Test]
    procedure Payload_Envelope_Number_Raises;
    [Test]
    procedure Payload_Envelope_Null_Raises;
    [Test]
    procedure Payload_Envelope_Empty_Raises;

    /// ---- TRESTClientWS, over the live stub ----

    /// What Execute answers. Red at 0546a51: it answered '' to everything.
    [Test]
    procedure WS_Execute_GET_NoRootElement_AnswersTheWholeBody;
    [Test]
    procedure WS_Execute_GET_RootElement_AnswersTheEnvelopePayload;
    /// DoPOST unwrapped unconditionally while DoGET branched. With no root
    /// element configured - which is what the constructor leaves - unwrapping
    /// was simply wrong.
    [Test]
    procedure WS_Execute_POST_NoRootElement_AnswersTheWholeBody;
    [Test]
    procedure WS_Execute_POST_RootElement_AnswersTheEnvelopePayload;
    /// DoDELETE, the third site, on its own merits.
    [Test]
    procedure WS_Execute_DELETE_NoRootElement_AnswersTheWholeBody;
    [Test]
    procedure WS_Execute_DELETE_RootElement_AnswersTheEnvelopePayload;

    /// The three malformed shapes, named. Red at 0546a51: an access violation,
    /// an invalid class typecast and an out-of-range argument.
    [Test]
    procedure WS_GET_NoRootElement_NonJsonBody_IsNamed;
    [Test]
    procedure WS_GET_RootElement_Absent_IsNamed;
    [Test]
    procedure WS_GET_RootElement_NotAnArray_IsNamed;
    [Test]
    procedure WS_GET_RootElement_EmptyArray_IsNamed;

    /// The path the issue calls the dangerous one: with FErrorCommand assigned
    /// nothing is raised and the caller is handed ''. The named reason has to
    /// reach the handler, because it is all the handler gets.
    [Test]
    procedure WS_GET_ErrorCommand_ReceivesTheNamedReason;

    /// ---- TRESTClientDataSnap, over the live stub ----

    [Test]
    procedure DataSnap_GET_AnswersTheEnvelopePayload;
    [Test]
    procedure DataSnap_POST_AnswersTheEnvelopePayload;
    [Test]
    procedure DataSnap_DELETE_AnswersTheEnvelopePayload;

    /// A DataSnap server error carries no 'result' key, so the configured root
    /// element is absent and JSONValue is nil - the access violation, and the
    /// reason '' can never be the answer to nil.
    [Test]
    procedure DataSnap_GET_AbsentResultKey_IsNamed;
    [Test]
    procedure DataSnap_GET_ResultNotAnArray_IsNamed;
    [Test]
    procedure DataSnap_GET_ResultEmptyArray_IsNamed;
    /// The body of a failed DataSnap call still has to reach the consumer:
    /// naming the shape must not cost the evidence.
    [Test]
    procedure DataSnap_GET_AbsentResultKey_StillCarriesTheServerBody;

    /// ---- TRESTClientHorse, over the live stub ----
    ///
    /// The Horse client casts nothing, so it was outside the ten hard casts
    /// issue #323 enumerates - but it dereferences the same nil, at the same
    /// point, in all four of its verbs: JSONValue.ToJSON with no guard. Unlike
    /// the other two families it IS compiled and driven - by ONE test project,
    /// Janus.Tests.RESTfulDriver, which is exactly what the positive control
    /// of the tripwire said ("failed Janus.Tests.RESTfulDriver and only that
    /// one"). An earlier version of this comment said THREE, contradicting the
    /// measurement quoted three paragraphs above it. It still answered
    /// "Access violation ... Read of address 00000000" to a body that is not
    /// JSON. One clause per verb, because four independent sites are four
    /// independent sites.
    [Test]
    procedure Horse_GET_NonJsonBody_IsNamed;
    [Test]
    procedure Horse_POST_NonJsonBody_IsNamed;
    [Test]
    procedure Horse_PUT_NonJsonBody_IsNamed;
    [Test]
    procedure Horse_DELETE_NonJsonBody_IsNamed;

    /// ---- ABOVE CHAR 127, WHERE ToJSON AND ToString STOP AGREEING ----
    ///
    /// Every marker above this point is pure ASCII, and ToJSON and ToString
    /// render pure ASCII IDENTICALLY - so until these clauses existed, SIX
    /// mutations swapping one renderer for the other survived a fully green
    /// 168-clause run: the four Horse sites and the two inside
    /// TJanusClient.ResponsePayload. All six measured surviving before these
    /// were written, all six measured dying after.
    ///
    /// The distinction is not cosmetic. ToJSON is ToChars with EncodeBelow32
    /// and EncodeAbove127; ToString is ToChars with neither (Studio 37.0,
    /// System.JSON.pas, TJSONAncestor.ToJSON and TJSONAncestor.ToString), and
    /// TJSONString.ToChars writes a backslash-u escape with FOUR UPPERCASE HEX
    /// DIGITS for anything over 127. The two answers therefore differ for
    /// every accented character - most of the interesting ones in this
    /// framework's own examples.
    ///
    /// This is also what turns the asymmetry the repair DECLARED but did not
    /// decide - DoDELETE renders ToString, its three siblings render ToJSON -
    /// from a sentence into a clause. A declared decision that nothing
    /// observes is a decision that evaporates.
    ///
    /// The wire stays pure ASCII: the body carries the escape and the parser
    /// decodes it, so no transport charset can decide the outcome. The
    /// expected raw form is written with a #$00E7-style literal, so this .pas
    /// is pure ASCII as well.
    [Test]
    procedure Payload_NoEnvelope_Above127_IsEscaped;
    [Test]
    procedure Payload_Envelope_Above127_IsEscaped;
    [Test]
    procedure Horse_GET_Above127_IsEscaped;
    [Test]
    procedure Horse_POST_Above127_IsEscaped;
    [Test]
    procedure Horse_PUT_Above127_IsEscaped;
    /// The odd one of the four. It answers ToString, so above 127 it answers
    /// the RAW character where its three siblings answer the escape.
    [Test]
    procedure Horse_DELETE_Above127_IsRawAndNotEscaped;
  end;

implementation

const
  cLOOPBACK = '127.0.0.1';

  /// One marker per site. Distinct on purpose - see Markers_AreAllDistinct.
  cWS_GET_PLAIN     = '{"s323":"ws-get-plain"}';
  cWS_GET_ROOT      = '{"s323":"ws-get-root"}';
  cWS_POST_PLAIN    = '[{"s323":"ws-post-plain"}]';
  cWS_POST_ROOT     = '{"s323":"ws-post-root"}';
  cWS_DELETE_PLAIN  = '{"s323":"ws-delete-plain"}';
  cWS_DELETE_ROOT   = '{"s323":"ws-delete-root"}';
  cDS_GET           = '{"s323":"ds-get"}';
  cDS_POST          = '{"s323":"ds-post"}';
  cDS_DELETE        = '{"s323":"ds-delete"}';

  cROOT             = 'result';
  cSERVERERROR_MK   = 's323-datasnap-server-error-marker';

  /// ---- the above-127 pairs ----
  /// Each is TWO renderings of ONE value: _WIRE is what the body carries AND
  /// what ToJSON answers back (the parser decodes the escape, ToJSON re-writes
  /// it), _RAW is what ToString answers. Six distinct characters, so no single
  /// constant satisfies more than its own clause.
  cACC_PLAIN_WIRE   = '{"s323":"acc-plain-\u00E7"}';
  cACC_PLAIN_RAW    = '{"s323":"acc-plain-' + #$00E7 + '"}';
  cACC_ENV_WIRE     = '[{"s323":"acc-env-\u00C3"},{"tail":"ignored"}]';
  cACC_ENV_HEAD     = '{"s323":"acc-env-\u00C3"}';
  cACC_ENV_HEAD_RAW = '{"s323":"acc-env-' + #$00C3 + '"}';
  cACC_HGET_WIRE    = '{"s323":"acc-horse-get-\u00E1"}';
  cACC_HGET_RAW     = '{"s323":"acc-horse-get-' + #$00E1 + '"}';
  cACC_HPOST_WIRE   = '{"s323":"acc-horse-post-\u00E9"}';
  cACC_HPOST_RAW    = '{"s323":"acc-horse-post-' + #$00E9 + '"}';
  cACC_HPUT_WIRE    = '{"s323":"acc-horse-put-\u00ED"}';
  cACC_HPUT_RAW     = '{"s323":"acc-horse-put-' + #$00ED + '"}';
  cACC_HDEL_WIRE    = '{"s323":"acc-horse-delete-\u00F3"}';
  cACC_HDEL_RAW     = '{"s323":"acc-horse-delete-' + #$00F3 + '"}';

  /// Two envelopes for the same rule, so no constant can satisfy both.
  cENVELOPE_A       = '[{"first":"a1"},{"second":"a2"}]';
  cENVELOPE_A_HEAD  = '{"first":"a1"}';
  cENVELOPE_B       = '[[7,8],{"tail":"b2"}]';
  cENVELOPE_B_HEAD  = '[7,8]';

  cPLAIN_OBJECT     = '{"plain":"object"}';
  cPLAIN_ARRAY      = '[{"plain":"array"},{"plain":"array2"}]';

{ TStubShapeServer }

constructor TStubShapeServer.Create;
var
  LBinding: TIdSocketHandle;
  LFor: Integer;
begin
  inherited Create;
  FBody := '{}';
  FContentType := 'application/json';
  FServer := TIdHTTPServer.Create(nil);
  FServer.OnCommandGet := DoCommandGet;
  FServer.OnCommandOther := DoCommandGet;
  /// <summary>
  ///   Hunts for a free port instead of fixing one: a port still in TIME_WAIT
  ///   from an earlier run would fail the bind and turn the suite red for a
  ///   reason that has nothing to do with what is measured here. THAT SCAN is
  ///   the protection, and it is the only one there is.
  ///
  ///   An earlier version of this comment claimed the range was disjoint from
  ///   its neighbour and concluded the two "never collide". It compared with
  ///   ONE of six. Enumerated at HEAD, every listener in Test\Delphi:
  ///
  ///     9700..9799  RestHorseOracleTest.Base          RESTOracle
  ///     9730..9789  Test.Janus.Driver.HorseExecuteOverload
  ///                                                   RESTfulDriver
  ///     9830..9889  Test.Janus.Driver.WiRLExecuteOverload
  ///                                                   RESTWiRL
  ///     9840..9879  Test.Janus.Client.RestExceptionFields
  ///                                                   RESTMARS
  ///     9890..9989  RestHorseTest.Base                RESTHorse
  ///     9900..9939  THIS STUB                         RESTfulDriver
  ///     9930..9989  Test.Janus.Driver.WiRLTokenAcquire
  ///                                                   RESTWiRL
  ///
  ///   This range OVERLAPS two of them - RestHorseTest.Base entirely, and
  ///   WiRLTokenAcquire from 9930 up. Neither runs in this process: the only
  ///   other listener in Janus.Tests.RESTfulDriver is HorseExecuteOverload,
  ///   which is disjoint. Across processes the suite runs one binary at a
  ///   time, so a clash needs a listener left over from an earlier run - and
  ///   that is precisely what the upward scan walks past.
  /// </summary>
  for LFor := 0 to 39 do
  begin
    FPort := 9900 + LFor;
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
  raise Exception.Create('No free port for the shape stub HTTP server.');
end;

destructor TStubShapeServer.Destroy;
begin
  if FServer.Active then
    FServer.Active := False;
  FServer.Free;
  inherited;
end;

procedure TStubShapeServer.DoCommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
begin
  AResponseInfo.ResponseNo := 200;
  AResponseInfo.ContentType := FContentType;
  AResponseInfo.ContentText := FBody;
end;

{ TTestClientResponseShape }

procedure TTestClientResponseShape.CaptureErrorCommand(const AURLBase,
  AResource, ASubResource, ARequestMethod, AMessage: String;
  const AResponseCode: Integer);
begin
  FErrorSeen := AMessage;
end;

procedure TTestClientResponseShape.Setup;
begin
  FErrorSeen := '';
  FStub := TStubShapeServer.Create;
  FWS := TRESTClientWS.Create(nil);
  FWS.Host := cLOOPBACK;
  FWS.Port := FStub.Port;
  FDataSnap := TRESTClientDataSnap.Create(nil);
  FDataSnap.Host := cLOOPBACK;
  FDataSnap.Port := FStub.Port;
  FHorse := TRESTClientHorse.Create(nil);
  FHorse.Host := cLOOPBACK;
  FHorse.Port := FStub.Port;
end;

procedure TTestClientResponseShape.TearDown;
begin
  FreeAndNil(FWS);
  FreeAndNil(FDataSnap);
  FreeAndNil(FHorse);
  FreeAndNil(FStub);
end;

function TTestClientResponseShape.Parsed(const AJson: String): TJSONValue;
begin
  Result := TJSONObject.ParseJSONValue(AJson);
  Assert.IsNotNull(Result, 'The fixture itself failed to parse: ' + AJson);
end;

function TTestClientResponseShape.RunWS(
  const ARequestMethod: TRESTRequestMethodType;
  const ARootElement, ABody: String): String;
begin
  FStub.Body := ABody;
  FWS.RootElement := ARootElement;
  Result := FWS.Execute('s323', '', ARequestMethod,
                        procedure
                        begin
                          /// POST refuses an empty body before it reaches the
                          /// wire; the content itself does not matter here.
                          FWS.AddBodyParam('{"probe":1}');
                        end);
end;

function TTestClientResponseShape.RunDataSnap(
  const ARequestMethod: TRESTRequestMethodType; const ABody: String): String;
begin
  FStub.Body := ABody;
  Result := FDataSnap.Execute('s323', '', ARequestMethod,
                              procedure
                              begin
                                FDataSnap.AddBodyParam('{"probe":1}');
                              end);
end;

function TTestClientResponseShape.CaptureWS(
  const ARequestMethod: TRESTRequestMethodType;
  const ARootElement, ABody: String): String;
begin
  Result := '';
  try
    RunWS(ARequestMethod, ARootElement, ABody);
  except
    on E: EJanusRESTException do
      Result := E.Message;
  end;
  Assert.AreNotEqual('', Result,
    'The call should have raised EJanusRESTException.');
end;

function TTestClientResponseShape.CaptureDataSnap(
  const ARequestMethod: TRESTRequestMethodType; const ABody: String): String;
begin
  Result := '';
  try
    RunDataSnap(ARequestMethod, ABody);
  except
    on E: EJanusRESTException do
      Result := E.Message;
  end;
  Assert.AreNotEqual('', Result,
    'The call should have raised EJanusRESTException.');
end;

function TTestClientResponseShape.CaptureHorse(
  const ARequestMethod: TRESTRequestMethodType; const ABody: String): String;
begin
  FStub.ContentType := 'text/plain';
  FStub.Body := ABody;
  Result := '';
  try
    FHorse.Execute('s323', '', ARequestMethod,
                   procedure
                   begin
                     FHorse.AddBodyParam('{"probe":1}');
                   end);
  except
    on E: EJanusRESTException do
      Result := E.Message;
  end;
  Assert.AreNotEqual('', Result,
    'The call should have raised EJanusRESTException.');
end;

function TTestClientResponseShape.RunHorse(
  const ARequestMethod: TRESTRequestMethodType; const ABody: String): String;
begin
  FStub.ContentType := 'application/json';
  FStub.Body := ABody;
  Result := FHorse.Execute('s323', '', ARequestMethod,
                           procedure
                           begin
                             FHorse.AddBodyParam('{"probe":1}');
                           end);
end;

procedure TTestClientResponseShape.Markers_AreAllDistinct;
var
  LSeen: TStringList;
begin
  LSeen := TStringList.Create;
  try
    LSeen.Duplicates := dupError;
    LSeen.Sorted := True;
    LSeen.Add(cWS_GET_PLAIN);
    LSeen.Add(cWS_GET_ROOT);
    LSeen.Add(cWS_POST_PLAIN);
    LSeen.Add(cWS_POST_ROOT);
    LSeen.Add(cWS_DELETE_PLAIN);
    LSeen.Add(cWS_DELETE_ROOT);
    LSeen.Add(cDS_GET);
    LSeen.Add(cDS_POST);
    LSeen.Add(cDS_DELETE);
    LSeen.Add(cENVELOPE_A_HEAD);
    LSeen.Add(cENVELOPE_B_HEAD);
    LSeen.Add(cPLAIN_OBJECT);
    Assert.AreEqual(12, LSeen.Count, 'Repeated markers invalidate the rest.');
    /// The three shape reasons have to be tellable apart too, or a clause
    /// could pass on the wrong branch.
    LSeen.Clear;
    LSeen.Add(cRESTNOJSONVALUE);
    LSeen.Add(cRESTNOTANARRAY);
    LSeen.Add(cRESTEMPTYARRAY);
    Assert.AreEqual(3, LSeen.Count, 'The three shape reasons must differ.');
  finally
    LSeen.Free;
  end;
end;

procedure TTestClientResponseShape.Payload_Nil_Raises_Unwrapping;
begin
  Assert.WillRaiseWithMessage(
    procedure
    begin
      TJanusClient.ResponsePayload(nil, True);
    end,
    EJanusRESTResponseShape, cRESTNOJSONVALUE);
end;

procedure TTestClientResponseShape.Payload_Nil_Raises_NotUnwrapping;
begin
  Assert.WillRaiseWithMessage(
    procedure
    begin
      TJanusClient.ResponsePayload(nil, False);
    end,
    EJanusRESTResponseShape, cRESTNOJSONVALUE);
end;

procedure TTestClientResponseShape.Payload_NoEnvelope_AnswersTheObjectVerbatim;
var
  LValue: TJSONValue;
begin
  LValue := Parsed(cPLAIN_OBJECT);
  try
    Assert.AreEqual(cPLAIN_OBJECT, TJanusClient.ResponsePayload(LValue, False));
  finally
    LValue.Free;
  end;
end;

procedure TTestClientResponseShape.Payload_NoEnvelope_AnswersTheArrayVerbatim;
var
  LValue: TJSONValue;
begin
  /// An ARRAY with no envelope stays whole. This is the clause that separates
  /// "unwrap when told to" from "unwrap whenever the value happens to be an
  /// array" - the second reading passes every other clause here.
  LValue := Parsed(cPLAIN_ARRAY);
  try
    Assert.AreEqual(cPLAIN_ARRAY, TJanusClient.ResponsePayload(LValue, False));
  finally
    LValue.Free;
  end;
end;

procedure TTestClientResponseShape.Payload_Envelope_AnswersTheFirstElementOnly;
var
  LValue: TJSONValue;
  LResult: String;
begin
  LValue := Parsed(cENVELOPE_A);
  try
    LResult := TJanusClient.ResponsePayload(LValue, True);
    Assert.AreEqual(cENVELOPE_A_HEAD, LResult);
    Assert.AreNotEqual(cENVELOPE_A, LResult,
      'The whole envelope is not the payload.');
  finally
    LValue.Free;
  end;
end;

procedure TTestClientResponseShape.Payload_Envelope_AnswersTheFirstElementOnly_OtherValues;
var
  LValue: TJSONValue;
begin
  LValue := Parsed(cENVELOPE_B);
  try
    Assert.AreEqual(cENVELOPE_B_HEAD, TJanusClient.ResponsePayload(LValue, True));
  finally
    LValue.Free;
  end;
end;

procedure TTestClientResponseShape.Payload_Envelope_Object_Raises;
var
  LValue: TJSONValue;
begin
  LValue := Parsed('{"not":"an array"}');
  try
    Assert.WillRaiseWithMessage(
      procedure
      begin
        TJanusClient.ResponsePayload(LValue, True);
      end,
      EJanusRESTResponseShape, cRESTNOTANARRAY + LValue.ClassName);
  finally
    LValue.Free;
  end;
end;

procedure TTestClientResponseShape.Payload_Envelope_String_Raises;
var
  LValue: TJSONValue;
begin
  LValue := TJSONString.Create('a bare string');
  try
    Assert.WillRaise(
      procedure
      begin
        TJanusClient.ResponsePayload(LValue, True);
      end,
      EJanusRESTResponseShape);
  finally
    LValue.Free;
  end;
end;

procedure TTestClientResponseShape.Payload_Envelope_Number_Raises;
var
  LValue: TJSONValue;
begin
  LValue := TJSONNumber.Create(42);
  try
    Assert.WillRaise(
      procedure
      begin
        TJanusClient.ResponsePayload(LValue, True);
      end,
      EJanusRESTResponseShape);
  finally
    LValue.Free;
  end;
end;

procedure TTestClientResponseShape.Payload_Envelope_Null_Raises;
var
  LValue: TJSONValue;
begin
  /// A server with nothing to report writes null rather than omitting the
  /// value, and TJSONNull is a TJSONValue like any other - so it arrives here
  /// as a value and not as nil.
  LValue := TJSONNull.Create;
  try
    Assert.WillRaise(
      procedure
      begin
        TJanusClient.ResponsePayload(LValue, True);
      end,
      EJanusRESTResponseShape);
  finally
    LValue.Free;
  end;
end;

procedure TTestClientResponseShape.Payload_Envelope_Empty_Raises;
var
  LValue: TJSONValue;
begin
  LValue := Parsed('[]');
  try
    Assert.WillRaiseWithMessage(
      procedure
      begin
        TJanusClient.ResponsePayload(LValue, True);
      end,
      EJanusRESTResponseShape, cRESTEMPTYARRAY);
  finally
    LValue.Free;
  end;
end;

procedure TTestClientResponseShape.WS_Execute_GET_NoRootElement_AnswersTheWholeBody;
begin
  Assert.AreEqual(cWS_GET_PLAIN,
    RunWS(TRESTRequestMethodType.rtGET, '', cWS_GET_PLAIN));
end;

procedure TTestClientResponseShape.WS_Execute_GET_RootElement_AnswersTheEnvelopePayload;
begin
  Assert.AreEqual(cWS_GET_ROOT,
    RunWS(TRESTRequestMethodType.rtGET, cROOT,
          '{"' + cROOT + '":[' + cWS_GET_ROOT + ',{"tail":"ignored"}]}'));
end;

procedure TTestClientResponseShape.WS_Execute_POST_NoRootElement_AnswersTheWholeBody;
begin
  Assert.AreEqual(cWS_POST_PLAIN,
    RunWS(TRESTRequestMethodType.rtPOST, '', cWS_POST_PLAIN));
end;

procedure TTestClientResponseShape.WS_Execute_POST_RootElement_AnswersTheEnvelopePayload;
begin
  Assert.AreEqual(cWS_POST_ROOT,
    RunWS(TRESTRequestMethodType.rtPOST, cROOT,
          '{"' + cROOT + '":[' + cWS_POST_ROOT + ',{"tail":"ignored"}]}'));
end;

procedure TTestClientResponseShape.WS_Execute_DELETE_NoRootElement_AnswersTheWholeBody;
begin
  Assert.AreEqual(cWS_DELETE_PLAIN,
    RunWS(TRESTRequestMethodType.rtDELETE, '', cWS_DELETE_PLAIN));
end;

procedure TTestClientResponseShape.WS_Execute_DELETE_RootElement_AnswersTheEnvelopePayload;
begin
  Assert.AreEqual(cWS_DELETE_ROOT,
    RunWS(TRESTRequestMethodType.rtDELETE, cROOT,
          '{"' + cROOT + '":[' + cWS_DELETE_ROOT + ',{"tail":"ignored"}]}'));
end;

procedure TTestClientResponseShape.WS_GET_NoRootElement_NonJsonBody_IsNamed;
var
  LMessage: String;
begin
  /// No root element, and a body that is not JSON at all: JSONValue is nil and
  /// the old code called ToJSON on it.
  FStub.ContentType := 'text/plain';
  LMessage := CaptureWS(TRESTRequestMethodType.rtGET, '', 'this is not json');
  Assert.IsTrue(ContainsText(LMessage, cRESTNOJSONVALUE),
    'The absent value has to be named. Message was: ' + LMessage);
end;

procedure TTestClientResponseShape.WS_GET_RootElement_Absent_IsNamed;
var
  LMessage: String;
begin
  LMessage := CaptureWS(TRESTRequestMethodType.rtGET, cROOT,
                        '{"other":"key"}');
  Assert.IsTrue(ContainsText(LMessage, cRESTNOJSONVALUE),
    'The absent root element has to be named. Message was: ' + LMessage);
end;

procedure TTestClientResponseShape.WS_GET_RootElement_NotAnArray_IsNamed;
var
  LMessage: String;
begin
  LMessage := CaptureWS(TRESTRequestMethodType.rtGET, cROOT,
                        '{"' + cROOT + '":{"an":"object"}}');
  Assert.IsTrue(ContainsText(LMessage, cRESTNOTANARRAY),
    'The wrong shape has to be named. Message was: ' + LMessage);
end;

procedure TTestClientResponseShape.WS_GET_RootElement_EmptyArray_IsNamed;
var
  LMessage: String;
begin
  LMessage := CaptureWS(TRESTRequestMethodType.rtGET, cROOT,
                        '{"' + cROOT + '":[]}');
  Assert.IsTrue(ContainsText(LMessage, cRESTEMPTYARRAY),
    'The empty envelope has to be named. Message was: ' + LMessage);
end;

procedure TTestClientResponseShape.WS_GET_ErrorCommand_ReceivesTheNamedReason;
var
  LAnswer: String;
begin
  FWS.OnErrorCommand := CaptureErrorCommand;
  LAnswer := RunWS(TRESTRequestMethodType.rtGET, cROOT,
                   '{"' + cROOT + '":[]}');
  Assert.AreEqual('', LAnswer,
    'With FErrorCommand assigned nothing is raised and the caller is handed ' +
    'an empty string.');
  Assert.IsTrue(ContainsText(FErrorSeen, cRESTEMPTYARRAY),
    'The handler only gets the message, so the message has to say what ' +
    'happened. It said: ' + FErrorSeen);
end;

procedure TTestClientResponseShape.DataSnap_GET_AnswersTheEnvelopePayload;
begin
  Assert.AreEqual(cDS_GET,
    RunDataSnap(TRESTRequestMethodType.rtGET,
                '{"' + cROOT + '":[' + cDS_GET + ',{"tail":"ignored"}]}'));
end;

procedure TTestClientResponseShape.DataSnap_POST_AnswersTheEnvelopePayload;
begin
  Assert.AreEqual(cDS_POST,
    RunDataSnap(TRESTRequestMethodType.rtPOST,
                '{"' + cROOT + '":[' + cDS_POST + ',{"tail":"ignored"}]}'));
end;

procedure TTestClientResponseShape.DataSnap_DELETE_AnswersTheEnvelopePayload;
begin
  Assert.AreEqual(cDS_DELETE,
    RunDataSnap(TRESTRequestMethodType.rtDELETE,
                '{"' + cROOT + '":[' + cDS_DELETE + ',{"tail":"ignored"}]}'));
end;

procedure TTestClientResponseShape.DataSnap_GET_AbsentResultKey_IsNamed;
var
  LMessage: String;
begin
  LMessage := CaptureDataSnap(TRESTRequestMethodType.rtGET,
                              '{"error":"' + cSERVERERROR_MK + '"}');
  Assert.IsTrue(ContainsText(LMessage, cRESTNOJSONVALUE),
    'The absent root element has to be named. Message was: ' + LMessage);
end;

procedure TTestClientResponseShape.DataSnap_GET_ResultNotAnArray_IsNamed;
var
  LMessage: String;
begin
  LMessage := CaptureDataSnap(TRESTRequestMethodType.rtGET,
                              '{"' + cROOT + '":{"an":"object"}}');
  Assert.IsTrue(ContainsText(LMessage, cRESTNOTANARRAY),
    'The wrong shape has to be named. Message was: ' + LMessage);
end;

procedure TTestClientResponseShape.DataSnap_GET_ResultEmptyArray_IsNamed;
var
  LMessage: String;
begin
  LMessage := CaptureDataSnap(TRESTRequestMethodType.rtGET,
                              '{"' + cROOT + '":[]}');
  Assert.IsTrue(ContainsText(LMessage, cRESTEMPTYARRAY),
    'The empty envelope has to be named. Message was: ' + LMessage);
end;

procedure TTestClientResponseShape.DataSnap_GET_AbsentResultKey_StillCarriesTheServerBody;
var
  LMessage: String;
begin
  /// Naming the shape must not cost the evidence: what the server actually
  /// said is the only thing in the message that can diagnose the call.
  LMessage := CaptureDataSnap(TRESTRequestMethodType.rtGET,
                              '{"error":"' + cSERVERERROR_MK + '"}');
  Assert.IsTrue(ContainsText(LMessage, cSERVERERROR_MK),
    'The server body has to survive into the message. Message was: ' +
    LMessage);
end;

procedure TTestClientResponseShape.Horse_GET_NonJsonBody_IsNamed;
var
  LMessage: String;
begin
  LMessage := CaptureHorse(TRESTRequestMethodType.rtGET, 'this is not json');
  Assert.IsTrue(ContainsText(LMessage, cRESTNOJSONVALUE),
    'The absent value has to be named. Message was: ' + LMessage);
end;

procedure TTestClientResponseShape.Horse_POST_NonJsonBody_IsNamed;
var
  LMessage: String;
begin
  LMessage := CaptureHorse(TRESTRequestMethodType.rtPOST, 'this is not json');
  Assert.IsTrue(ContainsText(LMessage, cRESTNOJSONVALUE),
    'The absent value has to be named. Message was: ' + LMessage);
end;

procedure TTestClientResponseShape.Horse_PUT_NonJsonBody_IsNamed;
var
  LMessage: String;
begin
  LMessage := CaptureHorse(TRESTRequestMethodType.rtPUT, 'this is not json');
  Assert.IsTrue(ContainsText(LMessage, cRESTNOJSONVALUE),
    'The absent value has to be named. Message was: ' + LMessage);
end;

procedure TTestClientResponseShape.Horse_DELETE_NonJsonBody_IsNamed;
var
  LMessage: String;
begin
  /// DoDELETE is the one of the four that answers ToString and not ToJSON.
  /// That asymmetry is NOT repaired here and it is not incidental: ToJSON is
  /// ToChars with EncodeBelow32 and EncodeAbove127 and ToString is ToChars
  /// with neither (Studio 37.0, System.JSON.pas, TJSONAncestor.ToJSON and
  /// TJSONAncestor.ToString), so the two answers differ for any character
  /// above 127 - which in this framework's own examples is most of them.
  /// Changing it changes an answer the consumer already receives, so it is
  /// reported and not decided here. The nil guard below does not touch it.
  LMessage := CaptureHorse(TRESTRequestMethodType.rtDELETE, 'this is not json');
  Assert.IsTrue(ContainsText(LMessage, cRESTNOJSONVALUE),
    'The absent value has to be named. Message was: ' + LMessage);
end;

procedure TTestClientResponseShape.Payload_NoEnvelope_Above127_IsEscaped;
var
  LValue: TJSONValue;
  LResult: String;
begin
  LValue := Parsed(cACC_PLAIN_WIRE);
  try
    LResult := TJanusClient.ResponsePayload(LValue, False);
    Assert.AreEqual(cACC_PLAIN_WIRE, LResult);
    Assert.AreNotEqual(cACC_PLAIN_RAW, LResult,
      'ResponsePayload renders with ToJSON, which escapes above 127.');
  finally
    LValue.Free;
  end;
end;

procedure TTestClientResponseShape.Payload_Envelope_Above127_IsEscaped;
var
  LValue: TJSONValue;
  LResult: String;
begin
  LValue := Parsed(cACC_ENV_WIRE);
  try
    LResult := TJanusClient.ResponsePayload(LValue, True);
    Assert.AreEqual(cACC_ENV_HEAD, LResult);
    Assert.AreNotEqual(cACC_ENV_HEAD_RAW, LResult,
      'The unwrapped element is rendered with ToJSON too.');
  finally
    LValue.Free;
  end;
end;

procedure TTestClientResponseShape.Horse_GET_Above127_IsEscaped;
var
  LResult: String;
begin
  LResult := RunHorse(TRESTRequestMethodType.rtGET, cACC_HGET_WIRE);
  Assert.AreEqual(cACC_HGET_WIRE, LResult);
  Assert.AreNotEqual(cACC_HGET_RAW, LResult,
    'TRESTClientHorse.DoGET answers ToJSON.');
end;

procedure TTestClientResponseShape.Horse_POST_Above127_IsEscaped;
var
  LResult: String;
begin
  LResult := RunHorse(TRESTRequestMethodType.rtPOST, cACC_HPOST_WIRE);
  Assert.AreEqual(cACC_HPOST_WIRE, LResult);
  Assert.AreNotEqual(cACC_HPOST_RAW, LResult,
    'TRESTClientHorse.DoPOST answers ToJSON.');
end;

procedure TTestClientResponseShape.Horse_PUT_Above127_IsEscaped;
var
  LResult: String;
begin
  LResult := RunHorse(TRESTRequestMethodType.rtPUT, cACC_HPUT_WIRE);
  Assert.AreEqual(cACC_HPUT_WIRE, LResult);
  Assert.AreNotEqual(cACC_HPUT_RAW, LResult,
    'TRESTClientHorse.DoPUT answers ToJSON.');
end;

procedure TTestClientResponseShape.Horse_DELETE_Above127_IsRawAndNotEscaped;
var
  LResult: String;
begin
  /// The asymmetry, PINNED rather than merely reported. If someone decides to
  /// make the four agree - in either direction - this clause and its three
  /// siblings say so out loud instead of letting the answer change in silence.
  LResult := RunHorse(TRESTRequestMethodType.rtDELETE, cACC_HDEL_WIRE);
  Assert.AreEqual(cACC_HDEL_RAW, LResult);
  Assert.AreNotEqual(cACC_HDEL_WIRE, LResult,
    'TRESTClientHorse.DoDELETE answers ToString, alone among the four.');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestClientResponseShape);

end.
