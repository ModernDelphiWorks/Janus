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

{ @abstract(Janus Framework - EJanusRESTException field CORRESPONDENCE.)

  WHAT IS UNDER TEST

    Janus.Client.RestException  EJanusRESTException.Create - which argument
                                is printed under which label
    Janus.Client.MARS           all four raise sites of TRESTClientMARS, plus
                                ResponseBodyOf, read back through the message
                                the user receives

  WHY IT EXISTS

  The constructor takes SEVEN arguments and SIX of them are String:

    AURL, AResource, ASubResource, AMethodType, AMessage, AMessageError,
    AStatusCode

  Janus.Client.MARS and Janus.Client.DMVC were both calling it with SIX, so
  neither unit had compiled since AMessageError was added - and no test project
  read either unit, which is how that survived. Worse than the arity, one of
  the eight sites (TRESTClientMARS.DoPOST) also had E.Message and
  FRequestMethod in the WRONG ORDER. Both are String, so once the arity is
  repaired that swap COMPILES CLEANLY and merely prints the HTTP verb under
  'Message : ' and the error text under 'Method : '.

  HOW A SWAP IS MADE VISIBLE

  Every assertion here names ONE label and ONE expected marker. Asserting that
  the set of markers appears somewhere in the message would be worthless: the
  defect is precisely two values changing places, and a set assertion cannot
  see a swap. So the message is split into lines, the line carrying each label
  is located by its own prefix, and its value is compared on its own.

  Markers_AreAllDistinct asserts the premise first: if two markers were equal,
  a crossed pair could pass.

  EVERY RAISE SITE IS DRIVEN, NONE IS ARGUED BY SIMILARITY

  Reading the constructor alone would prove the constructor and nothing about
  the call sites. So TRESTClientMARS is really driven, once per verb - GET,
  DELETE, PUT and POST - with the resource and sub-resource carrying their own
  markers and the verb known from the call.

  DoPUT gets its own test even though its argument list is currently identical
  to DoDELETE's. "Identical to its sibling, so it needs no guard" is EXACTLY
  the reasoning that let the DoPOST transposition reach production in the first
  place, in this very file. Measured: shuffling the six String arguments of
  DoPUT compiles with exit 0 and the suite stays green without this test.

  TWO ENVIRONMENTS, BECAUSE ONE OF THEM CANNOT SEE THE MESSAGE/ERROR SWAP

  The four per-verb tests point the client at a loopback port with nothing
  listening. That covers the TRANSPORT failure path and the fallback branch of
  ResponseBodyOf, but it cannot discriminate AMessage from AMessageError: with
  a refused connection there is no server text at all, so 'Message : ' is
  empty and a swap of the two would only be caught by luck.

  So there is a second set of tests against a live loopback stub answering 500
  with a DISTINCT body marker and a DISTINCT reason phrase. There the two
  fields carry two different named values and the swap is caught BY DESIGN,
  not by accident of the environment. Those tests are also what prove
  ResponseBodyOf reaches the body at all.

  AND THERE IS ONE OF THEM PER VERB, FOR THE SAME REASON DoPUT GOT ITS OWN

  ResponseBodyOf is called at FOUR independent sites. A single GET-only live
  test pins one of them and leaves three free to rot. Measured, before this
  was parametrised: replacing ResponseBodyOf(E) with E.Message in DoPUT alone
  - the exact one-token regression that throws the body away - compiled and
  left the suite fully green, and likewise for DoDELETE and DoPOST. That is
  the regression this whole fixture exists to prevent, invisible.

  This is the third time reasoning-by-similarity has been caught in this file:
  first the DoPOST transposition that reached production, then DoPUT excused
  as a copy of its siblings, then the live-error path argued from GET alone.
  Every site is now driven on its own.

  WHAT THIS FIXTURE DOES NOT COVER

  The four sites in Janus.Client.DMVC - by omission, not by impossibility.
  There is no Janus.Tests.RESTDMVC project linking MVCFramework.RESTClient to
  host a fixture, and building one was not attempted here. It is known to be
  feasible: the client path compiles on Studio 37 (a throwaway harness proved
  it while this fix was being made), and the raise site IS reachable against a
  live server - DMVC's own Indy client swallows EIdHTTPProtocolException and
  writes the body into the response object, so the interface is assigned and
  the handler runs normally on an HTTP error.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Client.RestExceptionFields;

interface

uses
  Classes,
  SysUtils,
  StrUtils,
  DUnitX.TestFramework,
  IdContext,
  IdCustomHTTPServer,
  IdHTTPServer,
  IdSocketHandle,
  Janus.Client,
  Janus.Client.Base,
  Janus.Client.Methods,
  Janus.Client.MARS,
  Janus.Client.RestException;

type
  /// <summary> Servidor minimo de emprestimo: responde QUALQUER documento com
  ///   um erro HTTP cujo corpo e a razao sao marcadores distintos e
  ///   nomeados. E o unico jeito de separar AMessage de AMessageError, que
  ///   contra porta morta ficam ambos sem texto de servidor. </summary>
  TStubErrorServer = class
  private
    FServer: TIdHTTPServer;
    FPort: Integer;
    FStatusCode: Integer;
    FReasonPhrase: string;
    FBody: string;
    procedure DoCommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
  public
    constructor Create(const AStatusCode: Integer;
      const AReasonPhrase, ABody: string);
    destructor Destroy; override;
    property Port: Integer read FPort;
  end;

  [TestFixture]
  TTestRestExceptionFields = class
  private
    FClient: TRESTClientMARS;
    FStub: TStubErrorServer;
    /// Value printed under ALabel, or a sentinel that can never be mistaken
    /// for a marker when the label is absent.
    function FieldOf(const AMessage, ALabel: String): String;
    /// Drives one verb and answers the message of the EJanusRESTException that
    /// must come out of it.
    function CaptureRestException(
      const ARequestMethod: TRESTRequestMethodType): String;
    /// The four values every raise site must place under its own label,
    /// whatever the verb and whatever the failure mode.
    procedure AssertCommonFields(const AMessage, AVerb: String);
    /// The body/reason pair, against the live stub, for ONE verb. Every verb
    /// gets its own [Test] over this - see the header for why sharing one
    /// GET-only test would leave the other three sites unpinned.
    procedure AssertHttpErrorFields(
      const ARequestMethod: TRESTRequestMethodType; const AVerb: String);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// The premise. With two equal markers a crossed pair could pass.
    [Test]
    procedure Markers_AreAllDistinct;

    /// The constructor contract itself: seven arguments, seven labels, one
    /// marker each.
    [Test]
    procedure Constructor_EachArgumentLandsUnderItsOwnLabel;

    /// TRESTClientMARS.DoGET.
    [Test]
    procedure MARS_GET_EachValueLandsUnderItsOwnLabel;

    /// TRESTClientMARS.DoDELETE.
    [Test]
    procedure MARS_DELETE_EachValueLandsUnderItsOwnLabel;

    /// TRESTClientMARS.DoPUT. Driven on its own merits, not excused as a
    /// copy of DoDELETE - see the header.
    [Test]
    procedure MARS_PUT_EachValueLandsUnderItsOwnLabel;

    /// TRESTClientMARS.DoPOST - the site that shipped with E.Message and
    /// FRequestMethod transposed.
    [Test]
    procedure MARS_POST_EachValueLandsUnderItsOwnLabel;

    /// The swap named on its own, so a regression reads as what it is.
    [Test]
    procedure MARS_POST_VerbIsNotPrintedAsTheMessage;

    /// The only tests that can tell AMessage from AMessageError, and the ones
    /// that prove ResponseBodyOf recovers the body from the Indy exception.
    /// ONE PER VERB: ResponseBodyOf is called at four independent sites, and
    /// a single GET test leaves the other three free to throw the body away.
    [Test]
    procedure MARS_GET_HttpError_BodyUnderMessageAndReasonUnderError;
    [Test]
    procedure MARS_DELETE_HttpError_BodyUnderMessageAndReasonUnderError;
    [Test]
    procedure MARS_PUT_HttpError_BodyUnderMessageAndReasonUnderError;
    [Test]
    procedure MARS_POST_HttpError_BodyUnderMessageAndReasonUnderError;
  end;

implementation

const
  /// Loopback with nothing listening. The connection is refused immediately,
  /// so no test here waits on a timeout.
  cDEADHOST     = '127.0.0.1';
  cDEADPORT     = 65431;

  cRESOURCE     = 'restexc-mk-resource';
  cSUBRESOURCE  = 'restexc-mk-subresource';

  /// Constructor-contract markers - one per parameter.
  cURL_MK       = 'restexc-mk-url';
  cRES_MK       = 'restexc-mk-res';
  cSUB_MK       = 'restexc-mk-sub';
  cMETHOD_MK    = 'restexc-mk-methodtype';
  cMESSAGE_MK   = 'restexc-mk-message';
  cERROR_MK     = 'restexc-mk-messageerror';
  cSTATUS_MK    = 599;

  /// Live-stub markers. The body and the reason phrase must be TELLABLE
  /// APART - that is the whole point of this pair.
  cHTTP_STATUS  = 500;
  cREASON_MK    = 'RestexcReasonPhraseMarker';
  cBODY_MK      = 'restexc-server-body-marker';

  cABSENT       = '<<label-absent>>';

{ TStubErrorServer }

constructor TStubErrorServer.Create(const AStatusCode: Integer;
  const AReasonPhrase, ABody: string);
var
  LBinding: TIdSocketHandle;
  LFor: Integer;
begin
  inherited Create;
  FStatusCode := AStatusCode;
  FReasonPhrase := AReasonPhrase;
  FBody := ABody;
  FServer := TIdHTTPServer.Create(nil);
  FServer.OnCommandGet := DoCommandGet;
  FServer.OnCommandOther := DoCommandGet;
  /// <summary> Procura uma porta livre em vez de fixar uma: uma porta ainda
  ///   em TIME_WAIT de uma execucao anterior faria o bind falhar e a suite
  ///   ficaria vermelha por motivo que nada tem a ver com o que se mede
  ///   aqui. </summary>
  for LFor := 0 to 39 do
  begin
    FPort := 9840 + LFor;
    FServer.Bindings.Clear;
    LBinding := FServer.Bindings.Add;
    LBinding.IP := cDEADHOST;
    LBinding.Port := FPort;
    try
      FServer.Active := True;
      Exit;
    except
      on E: Exception do
        ;
    end;
  end;
  raise Exception.Create('Nenhuma porta livre para o stub HTTP de emprestimo.');
end;

destructor TStubErrorServer.Destroy;
begin
  if FServer.Active then
    FServer.Active := False;
  FServer.Free;
  inherited;
end;

procedure TStubErrorServer.DoCommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
begin
  /// <summary> ResponseNo tem de vir ANTES de ResponseText: o setter de
  ///   ResponseNo sobrescreve o texto com a razao padrao do codigo
  ///   (IdCustomHTTPServer.pas, TIdHTTPResponseInfo.SetResponseNo). Na ordem
  ///   trocada o marcador de razao seria descartado e o teste mediria
  ///   'Internal Server Error'. </summary>
  AResponseInfo.ResponseNo := FStatusCode;
  AResponseInfo.ResponseText := FReasonPhrase;
  AResponseInfo.ContentType := 'application/json';
  AResponseInfo.ContentText := FBody;
end;

{ TTestRestExceptionFields }

procedure TTestRestExceptionFields.Setup;
begin
  FStub := nil;
  FClient := TRESTClientMARS.Create(nil);
  FClient.Host := cDEADHOST;
  FClient.Port := cDEADPORT;
end;

procedure TTestRestExceptionFields.TearDown;
begin
  FreeAndNil(FClient);
  FreeAndNil(FStub);
end;

function TTestRestExceptionFields.FieldOf(const AMessage,
  ALabel: String): String;
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

function TTestRestExceptionFields.CaptureRestException(
  const ARequestMethod: TRESTRequestMethodType): String;
begin
  Result := '';
  try
    FClient.Execute(cRESOURCE, cSUBRESOURCE, ARequestMethod,
                    procedure
                    begin
                      /// POST e PUT recusam corpo vazio antes de chegar na
                      /// rede; o conteudo em si nao importa aqui.
                      FClient.AddBodyParam('{"probe":1}');
                    end);
  except
    on E: EJanusRESTException do
      Result := E.Message;
  end;
  Assert.AreNotEqual('', Result,
    'A chamada deveria ter levantado EJanusRESTException.');
end;

procedure TTestRestExceptionFields.AssertCommonFields(const AMessage,
  AVerb: String);
begin
  Assert.AreEqual(FClient.BaseURL, FieldOf(AMessage, 'URL'),
    'A URL do engine tem de sair sob URL.');
  Assert.AreEqual(cRESOURCE, FieldOf(AMessage, 'Resource'),
    'O recurso tem de sair sob Resource.');
  Assert.AreEqual(cSUBRESOURCE, FieldOf(AMessage, 'SubResource'),
    'O sub-recurso tem de sair sob SubResource.');
  Assert.AreEqual(AVerb, FieldOf(AMessage, 'Method'),
    'O verbo tem de sair sob Method.');
  Assert.AreNotEqual(AVerb, FieldOf(AMessage, 'Message'),
    'O verbo NAO pode sair sob Message.');
  Assert.AreNotEqual(AVerb, FieldOf(AMessage, 'Error'),
    'O verbo NAO pode sair sob Error.');
  Assert.AreNotEqual('', FieldOf(AMessage, 'Error'),
    'A mensagem da excecao local tem de sair sob Error.');
end;

procedure TTestRestExceptionFields.Markers_AreAllDistinct;
var
  LSeen: TStringList;
begin
  LSeen := TStringList.Create;
  try
    LSeen.Duplicates := dupError;
    LSeen.Sorted := True;
    LSeen.Add(cRESOURCE);
    LSeen.Add(cSUBRESOURCE);
    LSeen.Add(cURL_MK);
    LSeen.Add(cRES_MK);
    LSeen.Add(cSUB_MK);
    LSeen.Add(cMETHOD_MK);
    LSeen.Add(cMESSAGE_MK);
    LSeen.Add(cERROR_MK);
    LSeen.Add(cREASON_MK);
    LSeen.Add(cBODY_MK);
    Assert.AreEqual(10, LSeen.Count, 'Marcadores repetidos invalidam o resto.');
  finally
    LSeen.Free;
  end;
end;

procedure TTestRestExceptionFields.Constructor_EachArgumentLandsUnderItsOwnLabel;
var
  LException: EJanusRESTException;
  LMessage: String;
begin
  LException := EJanusRESTException.Create(cURL_MK, cRES_MK, cSUB_MK,
                                           cMETHOD_MK, cMESSAGE_MK, cERROR_MK,
                                           cSTATUS_MK);
  try
    LMessage := LException.Message;
  finally
    LException.Free;
  end;

  Assert.AreEqual(cURL_MK,     FieldOf(LMessage, 'URL'),
    'O 1o argumento tem de sair sob URL.');
  Assert.AreEqual(cRES_MK,     FieldOf(LMessage, 'Resource'),
    'O 2o argumento tem de sair sob Resource.');
  Assert.AreEqual(cSUB_MK,     FieldOf(LMessage, 'SubResource'),
    'O 3o argumento tem de sair sob SubResource.');
  Assert.AreEqual(cMETHOD_MK,  FieldOf(LMessage, 'Method'),
    'O 4o argumento tem de sair sob Method.');
  Assert.AreEqual(cMESSAGE_MK, FieldOf(LMessage, 'Message'),
    'O 5o argumento tem de sair sob Message.');
  Assert.AreEqual(cERROR_MK,   FieldOf(LMessage, 'Error'),
    'O 6o argumento tem de sair sob Error.');
  Assert.AreEqual(IntToStr(cSTATUS_MK), FieldOf(LMessage, 'Status Code'),
    'O 7o argumento tem de sair sob Status Code.');
end;

procedure TTestRestExceptionFields.MARS_GET_EachValueLandsUnderItsOwnLabel;
begin
  AssertCommonFields(CaptureRestException(TRESTRequestMethodType.rtGET), 'GET');
end;

procedure TTestRestExceptionFields.MARS_DELETE_EachValueLandsUnderItsOwnLabel;
begin
  AssertCommonFields(CaptureRestException(TRESTRequestMethodType.rtDELETE),
                     'DELETE');
end;

procedure TTestRestExceptionFields.MARS_PUT_EachValueLandsUnderItsOwnLabel;
begin
  AssertCommonFields(CaptureRestException(TRESTRequestMethodType.rtPUT), 'PUT');
end;

procedure TTestRestExceptionFields.MARS_POST_EachValueLandsUnderItsOwnLabel;
begin
  AssertCommonFields(CaptureRestException(TRESTRequestMethodType.rtPOST),
                     'POST');
end;

procedure TTestRestExceptionFields.MARS_POST_VerbIsNotPrintedAsTheMessage;
var
  LMessage: String;
begin
  /// O defeito exato que este sitio carregava: E.Message passava na posicao
  /// de AMethodType e FRequestMethod na de AMessage. Os dois sao String, entao
  /// o compilador nao ve nada - so o texto final denuncia.
  LMessage := CaptureRestException(TRESTRequestMethodType.rtPOST);

  Assert.AreNotEqual('POST', FieldOf(LMessage, 'Message'),
    'O verbo saiu sob Message: AMethodType e AMessage estao trocados.');
  Assert.AreEqual('POST', FieldOf(LMessage, 'Method'),
    'O verbo tem de sair sob Method.');
end;

procedure TTestRestExceptionFields.AssertHttpErrorFields(
  const ARequestMethod: TRESTRequestMethodType; const AVerb: String);
var
  LMessage: String;
begin
  FStub := TStubErrorServer.Create(cHTTP_STATUS, cREASON_MK, cBODY_MK);
  FClient.Port := FStub.Port;

  LMessage := CaptureRestException(ARequestMethod);

  AssertCommonFields(LMessage, AVerb);

  /// O par que so este ambiente consegue separar. Contra porta morta os dois
  /// campos ficam sem texto de servidor e uma troca passaria batida.
  Assert.AreEqual(cBODY_MK, FieldOf(LMessage, 'Message'),
    AVerb + ': o CORPO da resposta tem de sair sob Message. Se sair a razao ' +
    'da linha de status, ResponseBodyOf nao esta lendo ErrorMessage da ' +
    'EIdHTTPProtocolException NESTE sitio - e o corpo se perdeu.');
  Assert.IsTrue(ContainsStr(FieldOf(LMessage, 'Error'), cREASON_MK),
    AVerb + ': a razao da linha de status tem de sair sob Error, que e a ' +
    'mensagem da excecao local. Encontrado: ' + FieldOf(LMessage, 'Error'));
  Assert.AreNotEqual(cBODY_MK, FieldOf(LMessage, 'Error'),
    AVerb + ': o corpo NAO pode sair sob Error - AMessage e AMessageError ' +
    'estao trocados.');
  Assert.IsFalse(ContainsStr(FieldOf(LMessage, 'Message'), cREASON_MK),
    AVerb + ': e a razao NAO pode sair sob Message, pelo mesmo motivo.');
  Assert.AreEqual(IntToStr(cHTTP_STATUS), FieldOf(LMessage, 'Status Code'),
    AVerb + ': o codigo HTTP do servidor tem de sair sob Status Code.');
end;

procedure TTestRestExceptionFields.MARS_GET_HttpError_BodyUnderMessageAndReasonUnderError;
begin
  AssertHttpErrorFields(TRESTRequestMethodType.rtGET, 'GET');
end;

procedure TTestRestExceptionFields.MARS_DELETE_HttpError_BodyUnderMessageAndReasonUnderError;
begin
  AssertHttpErrorFields(TRESTRequestMethodType.rtDELETE, 'DELETE');
end;

procedure TTestRestExceptionFields.MARS_PUT_HttpError_BodyUnderMessageAndReasonUnderError;
begin
  AssertHttpErrorFields(TRESTRequestMethodType.rtPUT, 'PUT');
end;

procedure TTestRestExceptionFields.MARS_POST_HttpError_BodyUnderMessageAndReasonUnderError;
begin
  AssertHttpErrorFields(TRESTRequestMethodType.rtPOST, 'POST');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRestExceptionFields);

end.
