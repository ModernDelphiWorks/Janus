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

{ @abstract(Janus Framework - which HTTP verb TRESTClientDataSnap puts ON THE
  WIRE, which server method that verb reaches, and what its PUT answers.)

  WHAT IS UNDER TEST

    Janus.Client.DataSnap     TRESTClientDataSnap - DoPOST, DoPUT, DoGET and
                              DoDELETE: the verb each one sends, the label each
                              one reports, and the payload DoPUT answers

  ============================================================================
  THE VERB PAIR IS SWAPPED ON PURPOSE. DO NOT "FIX" IT.
  ============================================================================

  DoPOST sets FRequestMethod to 'POST' and sends TRESTRequestMethod.rmPUT.
  DoPUT sets 'PUT' and sends rmPOST. Read plainly that is an inversion, and
  issue #338 opened on exactly that reading. It is not one. It COMPENSATES a
  mapping that DataSnap itself inverts, and straightening the client is what
  would turn an insert into an update against a real server.

  THE RULE THAT MAKES IT NECESSARY - Embarcadero's, not this framework's

  Studio 37.0, Datasnap.DSService.pas, TDSRESTService.SetMethodNameWithPrefix,
  applied from ProcessREST:

      if RequestType = 'PUT'    then Prefix := 'accept'
      else if RequestType = 'POST'   then Prefix := 'update'
      else if RequestType = 'DELETE' then Prefix := 'cancel';

  The dispatcher then invokes ClassName.PrefixMethodName. So on a DataSnap
  server HTTP PUT reaches accept* and HTTP POST reaches update* - the opposite
  of the REST convention the rest of this framework follows. Both transports
  land there: the Indy TDSRESTServer and the WebBroker TDSHTTPWebDispatcher
  both route into TDSRESTService (Datasnap.DSHTTP.pas ProcessPOSTRequest /
  ProcessPUTRequest, and Datasnap.DSHTTPWebBroker.pas maps mtPost/mtPut to
  hcPOST/hcPUT with no inversion of its own).

  AND THIS REPOSITORY'S OWN SERVER IS WRITTEN TO THAT RULE

    Janus.Server.Resource.DataSnap    acceptapp -> FAppResource.insert
                                      updateapp -> FAppResource.update
                                      cancelapp -> ParseDelete
                                      app       -> ParseFind

  So the client's DoPOST, whose job is to INSERT, must put PUT on the wire to
  reach acceptapp; its DoPUT, whose job is to UPDATE, must put POST on the wire
  to reach updateapp. The shipped example server agrees, with the same four
  names over a different resource: acceptmaster inserts and updatemaster
  updates, under Examples\Delphi\RESTful\RESTFul via Driver\Datasnap\Server.

  The swap is also as old as the file - it arrived in the initial commit of
  Janus.Client.DataSnap.pas alongside that server, not in a later edit.

  WHY THE SIBLING BEING STRAIGHT PROVES NOTHING

  Issue #338 argues from TRESTClientWS, which maps 'POST' to rmPOST. That
  client is not a DataSnap peer: its constructor leaves FAPIContext empty
  while the DataSnap one sets 'datasnap', and the shipped example points it at
  a plain public address web service. Plain REST is not dispatched by method
  name prefix at all, so there is nothing there to compensate. Two clients
  speaking two protocols are not evidence about each other.

  WHAT THE ISSUE GOT RIGHT, AND WHAT IT COSTS

  The label and the wire DO disagree, and that half of #338 is confirmed here
  by measurement, not conceded: FRequestMethod - the string that reaches
  OnBeforeCommand, OnAfterCommand, OnErrorCommand and the 'Method : ' line of
  EJanusRESTException - says POST while the packet says PUT. What it names is
  the OPERATION in REST terms, which is right; what it does not name is the
  verb a packet capture will show, which is what a reader comparing the two
  will trip over. Both facts are pinned below, so neither can drift.

  HOW THE DISPATCH IS OBSERVED

  The stub records ARequestInfo.Command - the verb that actually crossed the
  socket - and applies the prefix rule quoted above to it. That second step is
  a MODEL of Embarcadero's rule, spelled out in DataSnapPrefixFor, not the RTL
  executing. It is fair to model here because the rule is the published
  contract of the dispatcher and the method names it produces are the ones
  Janus.Server.Resource.DataSnap actually declares; a real TDSRESTService in
  this fixture would test Embarcadero's code, not Janus's. What is NOT modelled
  is measured directly: the verb itself comes off the socket.

  NOT MEASURED HERE

  Nothing in this fixture speaks to a live DataSnap server. The dispatch
  clauses assert the METHOD NAME the rule yields, not that a TDSServer invoked
  it. Issue #338 records the same gap.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Client.DataSnapVerb;

{$IFNDEF DRIVERRESTFUL}
{$MESSAGE FATAL 'This unit belongs to the DRIVERRESTFUL configuration.'}
{$ENDIF}

interface

uses
  Classes,
  SysUtils,
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
  Janus.Client.DataSnap;

type
  /// <summary>
  ///   A loan server that answers every verb with one body the test chooses,
  ///   and REMEMBERS the verb that arrived. The verb on the wire is the whole
  ///   question here, so it is read off the request rather than inferred.
  /// </summary>
  TVerbRecorderServer = class
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
  TTestClientDataSnapVerb = class
  private
    FStub: TVerbRecorderServer;
    FDataSnap: TRESTClientDataSnap;
    FLabelSeen: String;
    FAnswerSeen: String;
    FErrorSeen: String;
    FErrorLabelSeen: String;
    /// TAfterCommandEvent and TErrorCommandEvent are method pointers, not
    /// anonymous methods, so the handlers have to be methods of the fixture.
    procedure CaptureAfterCommand(AStatusCode: Integer;
      var AResponseString: String; ARequestMethod: String);
    procedure CaptureErrorCommand(const AURLBase, AResource, ASubResource,
      ARequestMethod, AMessage: String; const AResponseCode: Integer);
    /// Runs one verb over the live stub and answers what Execute answered.
    function Run(const ARequestMethod: TRESTRequestMethodType;
      const ABody: String): String;
    /// Runs one verb and answers the message of the EJanusRESTException that
    /// has to come out of it.
    function Capture(const ARequestMethod: TRESTRequestMethodType;
      const ABody: String): String;
    /// An envelope carrying one distinct payload, in the shape the DataSnap
    /// client is configured to unwrap.
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
    /// Four clauses, not two: the pair that is swapped is only meaningful
    /// against the pair that is not. GET and DELETE go out straight, which is
    /// exactly what the RTL rule predicts - it prefixes nothing for GET and
    /// maps DELETE to cancel without crossing it with anything.

    [Test]
    procedure Wire_GET_SendsGET;
    [Test]
    procedure Wire_DELETE_SendsDELETE;
    /// THE COMPENSATION. Straightening either of these two breaks insert and
    /// update against every DataSnap server. See the header.
    [Test]
    procedure Wire_POST_SendsPUT_BecauseDataSnapMapsPUTToAccept;
    [Test]
    procedure Wire_PUT_SendsPOST_BecauseDataSnapMapsPOSTToUpdate;

    /// ---- THE SERVER METHOD THAT VERB REACHES ----
    ///
    /// The same four facts stated in the terms that make them read as correct
    /// rather than as a typo: the names are the ones
    /// Janus.Server.Resource.DataSnap declares, and acceptapp is the one that
    /// inserts.

    [Test]
    procedure Dispatch_GET_ReachesFind;
    [Test]
    procedure Dispatch_POST_ReachesInsert;
    [Test]
    procedure Dispatch_PUT_ReachesUpdate;
    [Test]
    procedure Dispatch_DELETE_ReachesDelete;

    /// ---- THE LABEL THE MONITOR AND THE EXCEPTION CARRY ----
    ///
    /// FRequestMethod names the OPERATION, and issue #338's "the log mentions
    /// a verb it did not send" is true of the HTTP verb specifically. Pinned
    /// in both directions so a later change cannot quietly pick one.

    [Test]
    procedure Label_POST_IsPOST;
    [Test]
    procedure Label_PUT_IsPUT;
    [Test]
    procedure Label_AndWire_DisagreeForBothWriteVerbs;
    [Test]
    procedure Label_PUT_ReachesTheErrorPathAsPUT;

    /// ---- WHAT DoPUT ANSWERS ----
    ///
    /// The other half of #338. DoPUT executed the request and returned without
    /// ever assigning Result, so every PUT answered '' whatever the server
    /// said. The contract it now meets is the one the other three verbs of
    /// THIS class already met - measured, not borrowed from the sibling.

    [Test]
    procedure PUT_AnswersTheEnvelopePayload;
    [Test]
    procedure PUT_AnswerReachesTheCaller;
    /// Joining that contract means joining its failure half too: a body with
    /// no 'result' key is the ordinary shape of a failed DataSnap call, and
    /// PUT used to swallow it silently. It now reports, like its siblings.
    [Test]
    procedure PUT_AbsentResultKey_IsNamed;
  end;

implementation

const
  cLOOPBACK = '127.0.0.1';
  cROOT     = 'result';

  /// One distinct marker per verb - a cross-wire cannot pass for a pass.
  cDSV_GET    = '{"s338":"datasnap-get"}';
  cDSV_POST   = '{"s338":"datasnap-post"}';
  cDSV_PUT    = '{"s338":"datasnap-put"}';
  cDSV_DELETE = '{"s338":"datasnap-delete"}';

  /// The four method names Janus.Server.Resource.DataSnap declares.
  cM_FIND   = 'app';
  cM_INSERT = 'acceptapp';
  cM_UPDATE = 'updateapp';
  cM_DELETE = 'cancelapp';

/// <summary>
///   A MODEL of Studio 37.0's TDSRESTService.SetMethodNameWithPrefix
///   (Datasnap.DSService.pas), applied to the verb that actually arrived. It
///   is the rule that makes the swap in TRESTClientDataSnap correct, so it is
///   written out here rather than described: a reader who doubts the swap can
///   check this table against the RTL and against the four method names
///   Janus.Server.Resource.DataSnap declares.
/// </summary>
function DataSnapMethodFor(const AWireVerb, AResource: String): String;
var
  LPrefix: String;
begin
  LPrefix := '';
  if AWireVerb = 'PUT' then
    LPrefix := 'accept'
  else if AWireVerb = 'POST' then
    LPrefix := 'update'
  else if AWireVerb = 'DELETE' then
    LPrefix := 'cancel';
  Result := LPrefix + AResource;
end;

{ TVerbRecorderServer }

constructor TVerbRecorderServer.Create;
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
  ///   Hunts for a free port rather than fixing one, for the reason the
  ///   neighbouring stub in Test.Janus.Client.ResponseShape records: a port
  ///   still in TIME_WAIT from an earlier run would fail the bind and turn the
  ///   suite red for a reason unrelated to what is measured.
  ///
  ///   Enumerated at HEAD, every listener under Test\Delphi:
  ///
  ///     9700..9799  RestHorseOracleTest.Base            RESTOracle
  ///     9730..9789  Test.Janus.Driver.HorseExecuteOverload
  ///                                                     RESTfulDriver
  ///     9830..9889  Test.Janus.Driver.WiRLExecuteOverload
  ///                                                     RESTWiRL
  ///     9840..9879  Test.Janus.Client.RestExceptionFields
  ///                                                     RESTMARS
  ///     9890..9989  RestHorseTest.Base                  RESTHorse
  ///     9900..9939  Test.Janus.Client.ResponseShape     RESTfulDriver
  ///     9930..9989  Test.Janus.Driver.WiRLTokenAcquire  RESTWiRL
  ///     9940..9979  THIS STUB                           RESTfulDriver
  ///
  ///   In THIS process the other two listeners are HorseExecuteOverload and
  ///   the ResponseShape stub, and this range is disjoint from both. It does
  ///   overlap RestHorseTest.Base and WiRLTokenAcquire, which live in other
  ///   binaries; the suite runs one binary at a time, so a clash needs a
  ///   listener left over from an earlier run - which the upward scan walks
  ///   past.
  /// </summary>
  for LFor := 0 to 39 do
  begin
    FPort := 9940 + LFor;
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
  raise Exception.Create('No free port for the DataSnap verb stub HTTP server.');
end;

destructor TVerbRecorderServer.Destroy;
begin
  if FServer.Active then
    FServer.Active := False;
  FServer.Free;
  inherited;
end;

procedure TVerbRecorderServer.DoCommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
begin
  FLastVerb := UpperCase(ARequestInfo.Command);
  Inc(FHits);
  AResponseInfo.ResponseNo := 200;
  AResponseInfo.ContentType := 'application/json';
  AResponseInfo.ContentText := FBody;
end;

{ TTestClientDataSnapVerb }

procedure TTestClientDataSnapVerb.Setup;
begin
  FLabelSeen := '';
  FAnswerSeen := '';
  FErrorSeen := '';
  FErrorLabelSeen := '';
  FStub := TVerbRecorderServer.Create;
  FDataSnap := TRESTClientDataSnap.Create(nil);
  FDataSnap.Host := cLOOPBACK;
  FDataSnap.Port := FStub.Port;
end;

procedure TTestClientDataSnapVerb.TearDown;
begin
  FreeAndNil(FDataSnap);
  FreeAndNil(FStub);
end;

procedure TTestClientDataSnapVerb.CaptureAfterCommand(AStatusCode: Integer;
  var AResponseString: String; ARequestMethod: String);
begin
  FLabelSeen := ARequestMethod;
  FAnswerSeen := AResponseString;
end;

procedure TTestClientDataSnapVerb.CaptureErrorCommand(const AURLBase,
  AResource, ASubResource, ARequestMethod, AMessage: String;
  const AResponseCode: Integer);
begin
  FErrorLabelSeen := ARequestMethod;
  FErrorSeen := AMessage;
end;

function TTestClientDataSnapVerb.Envelope(const APayload: String): String;
begin
  Result := '{"' + cROOT + '":[' + APayload + ',{"tail":"ignored"}]}';
end;

function TTestClientDataSnapVerb.Run(
  const ARequestMethod: TRESTRequestMethodType; const ABody: String): String;
begin
  FStub.Body := ABody;
  Result := FDataSnap.Execute('s338', '', ARequestMethod,
                              procedure
                              begin
                                /// The write verbs refuse an empty body before
                                /// it reaches the wire; the content itself does
                                /// not matter to what is measured here.
                                FDataSnap.AddBodyParam('{"probe":1}');
                              end);
end;

function TTestClientDataSnapVerb.Capture(
  const ARequestMethod: TRESTRequestMethodType; const ABody: String): String;
begin
  Result := '';
  try
    Run(ARequestMethod, ABody);
  except
    on E: EJanusRESTException do
      Result := E.Message;
  end;
  Assert.AreNotEqual('', Result,
    'The call should have raised EJanusRESTException.');
end;

procedure TTestClientDataSnapVerb.Markers_AreAllDistinct;
begin
  Assert.AreNotEqual(cDSV_GET, cDSV_POST);
  Assert.AreNotEqual(cDSV_GET, cDSV_PUT);
  Assert.AreNotEqual(cDSV_GET, cDSV_DELETE);
  Assert.AreNotEqual(cDSV_POST, cDSV_PUT);
  Assert.AreNotEqual(cDSV_POST, cDSV_DELETE);
  Assert.AreNotEqual(cDSV_PUT, cDSV_DELETE);
  Assert.AreNotEqual(cM_FIND, cM_INSERT);
  Assert.AreNotEqual(cM_INSERT, cM_UPDATE);
  Assert.AreNotEqual(cM_UPDATE, cM_DELETE);
end;

procedure TTestClientDataSnapVerb.Wire_GET_SendsGET;
begin
  Run(TRESTRequestMethodType.rtGET, Envelope(cDSV_GET));
  Assert.AreEqual(1, FStub.Hits, 'The stub was not reached at all.');
  Assert.AreEqual('GET', FStub.LastVerb);
end;

procedure TTestClientDataSnapVerb.Wire_DELETE_SendsDELETE;
begin
  Run(TRESTRequestMethodType.rtDELETE, Envelope(cDSV_DELETE));
  Assert.AreEqual(1, FStub.Hits, 'The stub was not reached at all.');
  Assert.AreEqual('DELETE', FStub.LastVerb);
end;

procedure TTestClientDataSnapVerb.Wire_POST_SendsPUT_BecauseDataSnapMapsPUTToAccept;
begin
  Run(TRESTRequestMethodType.rtPOST, Envelope(cDSV_POST));
  Assert.AreEqual(1, FStub.Hits, 'The stub was not reached at all.');
  Assert.AreEqual('PUT', FStub.LastVerb,
    'A DataSnap INSERT must travel as HTTP PUT: the dispatcher prefixes ' +
    '''accept'' to a PUT, and acceptapp is the method that inserts. Sending ' +
    'POST here would reach updateapp and turn every insert into an update.');
end;

procedure TTestClientDataSnapVerb.Wire_PUT_SendsPOST_BecauseDataSnapMapsPOSTToUpdate;
begin
  Run(TRESTRequestMethodType.rtPUT, Envelope(cDSV_PUT));
  Assert.AreEqual(1, FStub.Hits, 'The stub was not reached at all.');
  Assert.AreEqual('POST', FStub.LastVerb,
    'A DataSnap UPDATE must travel as HTTP POST: the dispatcher prefixes ' +
    '''update'' to a POST, and updateapp is the method that updates. Sending ' +
    'PUT here would reach acceptapp and turn every update into an insert.');
end;

procedure TTestClientDataSnapVerb.Dispatch_GET_ReachesFind;
begin
  Run(TRESTRequestMethodType.rtGET, Envelope(cDSV_GET));
  Assert.AreEqual(cM_FIND, DataSnapMethodFor(FStub.LastVerb, 'app'));
end;

procedure TTestClientDataSnapVerb.Dispatch_POST_ReachesInsert;
begin
  Run(TRESTRequestMethodType.rtPOST, Envelope(cDSV_POST));
  Assert.AreEqual(cM_INSERT, DataSnapMethodFor(FStub.LastVerb, 'app'),
    'The client''s POST has to land on the method that INSERTS.');
end;

procedure TTestClientDataSnapVerb.Dispatch_PUT_ReachesUpdate;
begin
  Run(TRESTRequestMethodType.rtPUT, Envelope(cDSV_PUT));
  Assert.AreEqual(cM_UPDATE, DataSnapMethodFor(FStub.LastVerb, 'app'),
    'The client''s PUT has to land on the method that UPDATES.');
end;

procedure TTestClientDataSnapVerb.Dispatch_DELETE_ReachesDelete;
begin
  Run(TRESTRequestMethodType.rtDELETE, Envelope(cDSV_DELETE));
  Assert.AreEqual(cM_DELETE, DataSnapMethodFor(FStub.LastVerb, 'app'));
end;

procedure TTestClientDataSnapVerb.Label_POST_IsPOST;
begin
  FDataSnap.OnAfterCommand := CaptureAfterCommand;
  Run(TRESTRequestMethodType.rtPOST, Envelope(cDSV_POST));
  Assert.AreEqual('POST', FLabelSeen,
    'The monitor and the exception name the OPERATION, and the operation ' +
    'this method performs is the REST POST.');
end;

procedure TTestClientDataSnapVerb.Label_PUT_IsPUT;
begin
  FDataSnap.OnAfterCommand := CaptureAfterCommand;
  Run(TRESTRequestMethodType.rtPUT, Envelope(cDSV_PUT));
  Assert.AreEqual('PUT', FLabelSeen);
end;

procedure TTestClientDataSnapVerb.Label_AndWire_DisagreeForBothWriteVerbs;
begin
  /// ISSUE #338's second complaint, confirmed rather than conceded: whoever
  /// reads the label and then a packet capture sees two different verbs. The
  /// label is right about WHAT was done and silent about HOW it travelled.
  FDataSnap.OnAfterCommand := CaptureAfterCommand;
  Run(TRESTRequestMethodType.rtPOST, Envelope(cDSV_POST));
  Assert.AreEqual('POST', FLabelSeen);
  Assert.AreEqual('PUT', FStub.LastVerb);
  Assert.AreNotEqual(FLabelSeen, FStub.LastVerb,
    'The reported verb and the sent verb differ for POST.');

  FLabelSeen := '';
  Run(TRESTRequestMethodType.rtPUT, Envelope(cDSV_PUT));
  Assert.AreEqual('PUT', FLabelSeen);
  Assert.AreEqual('POST', FStub.LastVerb);
  Assert.AreNotEqual(FLabelSeen, FStub.LastVerb,
    'The reported verb and the sent verb differ for PUT.');
end;

procedure TTestClientDataSnapVerb.Label_PUT_ReachesTheErrorPathAsPUT;
begin
  FDataSnap.OnErrorCommand := CaptureErrorCommand;
  /// No 'result' key, so JSONValue is nil and the shape rule reports.
  Run(TRESTRequestMethodType.rtPUT, '{"no-result-key":1}');
  Assert.AreNotEqual('', FErrorSeen,
    'The shape failure should have reached OnErrorCommand.');
  Assert.AreEqual('PUT', FErrorLabelSeen);
end;

procedure TTestClientDataSnapVerb.PUT_AnswersTheEnvelopePayload;
begin
  Assert.AreEqual(cDSV_PUT,
    Run(TRESTRequestMethodType.rtPUT, Envelope(cDSV_PUT)),
    'DoPUT executed the request and returned without ever assigning Result, ' +
    'so every PUT answered '''' whatever the server said. Its three siblings ' +
    'in this same class all answer the unwrapped payload.');
end;

procedure TTestClientDataSnapVerb.PUT_AnswerReachesTheCaller;
begin
  /// The same fact one frame up: what Execute hands to OnAfterCommand, and
  /// therefore to TRESTDriverDatasnap, is the payload and not ''.
  FDataSnap.OnAfterCommand := CaptureAfterCommand;
  Run(TRESTRequestMethodType.rtPUT, Envelope(cDSV_PUT));
  Assert.AreEqual(cDSV_PUT, FAnswerSeen);
end;

procedure TTestClientDataSnapVerb.PUT_AbsentResultKey_IsNamed;
var
  LMessage: String;
begin
  LMessage := Capture(TRESTRequestMethodType.rtPUT, '{"no-result-key":1}');
  Assert.Contains(LMessage, 'PUT',
    'The exception names the method that failed.');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestClientDataSnapVerb);

end.
