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
    Janus.Client.MARS           the four raise sites of TRESTClientMARS, read
                                back through the message the user receives

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

  THE MARS SITES ARE EXERCISED, NOT SIMULATED

  Reading the constructor alone would prove the constructor and nothing about
  the call sites. So TRESTClientMARS is pointed at a loopback port with nothing
  listening and asked to GET, POST and DELETE. The connection is refused, MARS
  hands the exception to the OnException handler Janus installed, and that
  handler is the raise site under test. The verb is known ('GET'/'POST'/
  'DELETE'), the resource and sub-resource carry their own markers, and the URL
  is the component's own BaseURL - four values that must each land under their
  own label.

  WHAT THIS FIXTURE DOES NOT COVER

  - TRESTClientMARS.DoPUT. Its argument list is byte-identical to DoDELETE's
    and DoGET's; it is not separately driven here.
  - The four sites in Janus.Client.DMVC. DelphiMVC does not compile on Studio
    37 beyond the MVCFramework.RESTClient path, there is no Janus.Tests.RESTDMVC
    project to host a fixture, and the DMVC error handler dereferences
    FRESTResponse - which is nil exactly when the transport fails - so the
    loopback trick used here would AV before reaching the raise. Those four
    sites are covered by compilation only.
  - 'Message : ' for MARS. At the raise site MARS has already freed the
    response stream, so the field carries ResponseText (the HTTP reason
    phrase), which a refused connection leaves empty. The assertions therefore
    pin what that field must NOT be - the verb - which is exactly the swap
    being guarded.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Client.RestExceptionFields;

interface

uses
  Classes,
  SysUtils,
  StrUtils,
  DUnitX.TestFramework,
  Janus.Client,
  Janus.Client.Base,
  Janus.Client.Methods,
  Janus.Client.MARS,
  Janus.Client.RestException;

type
  [TestFixture]
  TTestRestExceptionFields = class
  private
    FClient: TRESTClientMARS;
    /// Value printed under ALabel, or a sentinel that can never be mistaken
    /// for a marker when the label is absent.
    function FieldOf(const AMessage, ALabel: String): String;
    /// Drives one verb against the dead port and answers the message of the
    /// EJanusRESTException that must come out of it.
    function CaptureRestException(
      const ARequestMethod: TRESTRequestMethodType): String;
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

    /// TRESTClientMARS.DoPOST - the site that shipped with E.Message and
    /// FRequestMethod transposed.
    [Test]
    procedure MARS_POST_EachValueLandsUnderItsOwnLabel;

    /// The swap named on its own, so a regression reads as what it is.
    [Test]
    procedure MARS_POST_VerbIsNotPrintedAsTheMessage;
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

  cABSENT       = '<<label-absent>>';

{ TTestRestExceptionFields }

procedure TTestRestExceptionFields.Setup;
begin
  FClient := TRESTClientMARS.Create(nil);
  FClient.Host := cDEADHOST;
  FClient.Port := cDEADPORT;
end;

procedure TTestRestExceptionFields.TearDown;
begin
  FreeAndNil(FClient);
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
    'A chamada deveria ter levantado EJanusRESTException contra a porta morta '
    + cDEADHOST + ':' + IntToStr(cDEADPORT) + '.');
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
    Assert.AreEqual(8, LSeen.Count, 'Marcadores repetidos invalidam o resto.');
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
var
  LMessage: String;
begin
  LMessage := CaptureRestException(TRESTRequestMethodType.rtGET);

  Assert.AreEqual(FClient.BaseURL, FieldOf(LMessage, 'URL'),
    'A URL do engine tem de sair sob URL.');
  Assert.AreEqual(cRESOURCE, FieldOf(LMessage, 'Resource'),
    'O recurso tem de sair sob Resource.');
  Assert.AreEqual(cSUBRESOURCE, FieldOf(LMessage, 'SubResource'),
    'O sub-recurso tem de sair sob SubResource.');
  Assert.AreEqual('GET', FieldOf(LMessage, 'Method'),
    'O verbo tem de sair sob Method.');
  Assert.AreNotEqual('GET', FieldOf(LMessage, 'Message'),
    'O verbo NAO pode sair sob Message.');
  Assert.AreNotEqual('GET', FieldOf(LMessage, 'Error'),
    'O verbo NAO pode sair sob Error.');
  Assert.AreNotEqual('', FieldOf(LMessage, 'Error'),
    'A mensagem da excecao local tem de sair sob Error.');
end;

procedure TTestRestExceptionFields.MARS_DELETE_EachValueLandsUnderItsOwnLabel;
var
  LMessage: String;
begin
  LMessage := CaptureRestException(TRESTRequestMethodType.rtDELETE);

  Assert.AreEqual(FClient.BaseURL, FieldOf(LMessage, 'URL'),
    'A URL do engine tem de sair sob URL.');
  Assert.AreEqual(cRESOURCE, FieldOf(LMessage, 'Resource'),
    'O recurso tem de sair sob Resource.');
  Assert.AreEqual(cSUBRESOURCE, FieldOf(LMessage, 'SubResource'),
    'O sub-recurso tem de sair sob SubResource.');
  Assert.AreEqual('DELETE', FieldOf(LMessage, 'Method'),
    'O verbo tem de sair sob Method.');
  Assert.AreNotEqual('DELETE', FieldOf(LMessage, 'Message'),
    'O verbo NAO pode sair sob Message.');
  Assert.AreNotEqual('', FieldOf(LMessage, 'Error'),
    'A mensagem da excecao local tem de sair sob Error.');
end;

procedure TTestRestExceptionFields.MARS_POST_EachValueLandsUnderItsOwnLabel;
var
  LMessage: String;
begin
  LMessage := CaptureRestException(TRESTRequestMethodType.rtPOST);

  Assert.AreEqual(FClient.BaseURL, FieldOf(LMessage, 'URL'),
    'A URL do engine tem de sair sob URL.');
  Assert.AreEqual(cRESOURCE, FieldOf(LMessage, 'Resource'),
    'O recurso tem de sair sob Resource.');
  Assert.AreEqual(cSUBRESOURCE, FieldOf(LMessage, 'SubResource'),
    'O sub-recurso tem de sair sob SubResource.');
  Assert.AreEqual('POST', FieldOf(LMessage, 'Method'),
    'O verbo tem de sair sob Method.');
  Assert.AreNotEqual('', FieldOf(LMessage, 'Error'),
    'A mensagem da excecao local tem de sair sob Error.');
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

initialization
  TDUnitX.RegisterTestFixture(TTestRestExceptionFields);

end.
