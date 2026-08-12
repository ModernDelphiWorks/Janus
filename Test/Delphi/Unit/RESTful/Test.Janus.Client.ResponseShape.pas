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
    /// the other two families it IS compiled and driven by three test projects,
    /// and it still answered "Access violation ... Read of address 00000000"
    /// to a body that is not JSON. One clause per verb, because four
    /// independent sites are four independent sites.
    [Test]
    procedure Horse_GET_NonJsonBody_IsNamed;
    [Test]
    procedure Horse_POST_NonJsonBody_IsNamed;
    [Test]
    procedure Horse_PUT_NonJsonBody_IsNamed;
    [Test]
    procedure Horse_DELETE_NonJsonBody_IsNamed;
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
  ///   reason that has nothing to do with what is measured here. Same reasoning
  ///   and a DIFFERENT range from the stub in
  ///   Test.Janus.Client.RestExceptionFields, so the two never collide.
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

initialization
  TDUnitX.RegisterTestFixture(TTestClientResponseShape);

end.
