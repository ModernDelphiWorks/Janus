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

{ @abstract(Janus Framework - the ONE-RESOURCE Execute overload, and FullURL.)

  WHAT WAS WRONG (#211)

  IRESTConnection publishes TWO Execute overloads. The two-resource one is
  implemented everywhere. The ONE-resource one was declared
  `virtual; abstract` in TRESTFactoryConnection and in TRESTDriver, and NOT ONE
  of the six factories nor the six drivers overrode it - while the classes are
  instantiated in the constructor of every client component. Calling it raised
  EAbstractError.

  It survived because no compiler ever named it. MEASURED on this project,
  before the fix: TRESTDriverWiRL had TWO unoverridden abstract methods - this
  Execute overload and GetFullURL - and dcc32 emitted exactly ONE warning, at
  TRESTFactoryWiRL.Create, and it was about GetFullURL:

    W1020 Constructing instance of 'TRESTDriverWiRL' containing abstract method
    'TRESTDriver.GetFullURL'

  Nothing was said about Execute, whose two-resource sibling overload IS
  implemented. So the two holes are the same shape and only one of them had a
  witness. Both are closed together.

  WHY THE FIX IS NOT SIX OVERRIDES

  One resource IS the pair (resource, ''). That is the rule
  Janus.Session.RESTful already follows every time it has no sub-resource, so
  the overload is defined once in each base class in terms of the two-resource
  overload, which is virtual and lands on the concrete driver.

  The trap avoided: TRESTClientHorse.Execute and TRESTClientWiRL.Execute have a
  one-argument overload too, but its parameter is AURL and it REPLACES the base
  URL. Wiring the connection's AResource into that AURL would compile, run, and
  send the request somewhere else - the #213 failure mode. The fixture below
  refuses it by naming the path.

  HOW A WRONG WIRING IS MADE VISIBLE

  The stub records the PATH of every request that arrives, in order. Assertions
  compare the recorded path of the one-resource call against the recorded path
  of the two-resource call with an empty sub-resource - CHARACTER FOR
  CHARACTER, not as a set - and Premise_TheRecorderTellsThePathsApart proves
  first that the recorder can tell two different paths apart at all. A wiring to
  the AURL overload loses both the app context and the resource, and is red with
  the two paths printed side by side.

  WHAT THIS FIXTURE DOES NOT COVER

  FullURL for WiRL: TRESTClientWiRL does not override TJanusClient.GetFullURL,
  so it answers FBaseURL - for this client FullURL and BaseURL are the SAME
  storage, and only TRESTClientHorse answers the response URI. The assertion
  below therefore catches the abstract method and a cross-wire into any OTHER
  storage, but it cannot tell FullURL from BaseURL, because today there is
  nothing to tell apart. That limit is in the delegate's comment too.

  The five sibling drivers (DataSnap, DMVC, MARS, WS - and WiRL for the three
  auth getters) are NOT covered here: no .dproj compiles them, so nothing can be
  proved about them.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Driver.WiRLExecuteOverload;

interface

uses
  Classes,
  SysUtils,
  SyncObjs,
  Generics.Collections,
  DUnitX.TestFramework,
  IdContext,
  IdCustomHTTPServer,
  IdHTTPServer,
  IdSocketHandle,
  Janus.Client.Base,
  Janus.Client,
  Janus.Client.WiRL,
  Janus.Client.RestDriver.WiRL,
  Janus.Client.Methods,
  Janus.RestFactory.Interfaces;

type
  /// <summary> Servidor minimo de emprestimo. Responde qualquer documento com
  ///   uma lista vazia e guarda, em ordem, o CAMINHO de cada requisicao que
  ///   chegou. Nada sai da maquina. </summary>
  TStubPathServer = class
  private
    FServer: TIdHTTPServer;
    FLock: TCriticalSection;
    FPaths: TList<string>;
    FPort: Integer;
    procedure DoCommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
    procedure DoParseAuthentication(AContext: TIdContext;
      const AAuthType, AAuthData: string; var VUsername, VPassword: string;
      var VHandled: Boolean);
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary> Quantas requisicoes chegaram ate agora. </summary>
    function Count: Integer;
    /// <summary> O caminho da requisicao AIndex, base zero. </summary>
    function Path(const AIndex: Integer): string;
    property Port: Integer read FPort;
  end;

  [TestFixture]
  TTestDriverWiRLExecuteOverload = class
  private
    FStub: TStubPathServer;
    FClient: TRESTClientWiRL;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// The premise. Every assertion below compares recorded paths; if the
    /// recorder could not tell two different requests apart, all of them would
    /// pass with the wires crossed.
    [Test]
    procedure Premise_TheRecorderTellsThePathsApart;

    /// #211 verbatim, through the published interface. The shipped code raised
    /// EAbstractError right here.
    [Test]
    procedure OneResource_ThroughTheConnection_DoesNotDieAbstract;

    /// ... and it must reach EXACTLY the path the two-resource overload reaches
    /// with an empty sub-resource. Character for character.
    [Test]
    procedure OneResource_LandsOnTheSamePathAsAnEmptySubResource;

    /// The wiring this fixture refuses: the client's OTHER one-argument
    /// overload takes a full URL and drops the app context and the resource.
    [Test]
    procedure OneResource_IsAResourceAndNotAReplacementURL;

    /// The same hole one layer down: TRESTDriver, called directly.
    [Test]
    procedure OneResource_OnTheDriverItself_DoesNotDieAbstract;

    /// The optional params procedure must still be run - dropping it would be
    /// invisible in the path.
    [Test]
    procedure OneResource_StillRunsTheParamsProcedure;

    /// The sibling hole, the one the compiler denounced.
    [Test]
    procedure FullURL_IsNoLongerAnAbstractMethod;
  end;

implementation

const
  cAPI_CONTEXT  = 'app';
  cREST_CONTEXT = 'rest';
  cRESOURCE     = 'wirl-mk-resource';
  cSUBRESOURCE  = 'wirl-mk-subresource';
  cUSERNAME     = 'wirl-mk-username';
  cPASSWORD     = 'wirl-mk-password';
  cAUTHTOKEN    = 'wirl-mk-authenticator-token';

{ TStubPathServer }

constructor TStubPathServer.Create;
var
  LBinding: TIdSocketHandle;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FPaths := TList<string>.Create;
  FPort := 9830 + Random(60);
  FServer := TIdHTTPServer.Create(nil);
  FServer.OnCommandGet := DoCommandGet;
  FServer.OnCommandOther := DoCommandGet;
  /// <summary> Mesma razao do Test.Janus.Driver.WiRLTokenAcquire: sem isto o
  ///   proprio Indy responde 401 antes do handler quando chega um esquema que
  ///   o parser embutido nao conhece. </summary>
  FServer.OnParseAuthentication := DoParseAuthentication;
  LBinding := FServer.Bindings.Add;
  LBinding.IP := '127.0.0.1';
  LBinding.Port := FPort;
  FServer.Active := True;
end;

destructor TStubPathServer.Destroy;
begin
  if FServer.Active then
    FServer.Active := False;
  FServer.Free;
  FPaths.Free;
  FLock.Free;
  inherited;
end;

procedure TStubPathServer.DoCommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
begin
  FLock.Acquire;
  try
    FPaths.Add(ARequestInfo.Document);
  finally
    FLock.Release;
  end;
  AResponseInfo.ResponseNo := 200;
  AResponseInfo.ContentType := 'application/json';
  AResponseInfo.ContentText := '[]';
end;

procedure TStubPathServer.DoParseAuthentication(AContext: TIdContext;
  const AAuthType, AAuthData: string; var VUsername, VPassword: string;
  var VHandled: Boolean);
begin
  VHandled := True;
end;

function TStubPathServer.Count: Integer;
begin
  FLock.Acquire;
  try
    Result := FPaths.Count;
  finally
    FLock.Release;
  end;
end;

function TStubPathServer.Path(const AIndex: Integer): string;
begin
  FLock.Acquire;
  try
    if (AIndex < 0) or (AIndex >= FPaths.Count) then
      Result := ''
    else
      Result := FPaths[AIndex];
  finally
    FLock.Release;
  end;
end;

{ TTestDriverWiRLExecuteOverload }

procedure TTestDriverWiRLExecuteOverload.Setup;
begin
  FStub := TStubPathServer.Create;
  FClient := TRESTClientWiRL.Create(nil);
  FClient.Host := '127.0.0.1';
  FClient.Port := FStub.Port;
  FClient.RESTContext := cREST_CONTEXT;
  FClient.APIContext := cAPI_CONTEXT;
  /// <summary> atNoAuth sai de SetAuthenticatorTypeValues sem cabecalho e sem
  ///   login, entao TODA requisicao que o stub registrar foi pedida por um
  ///   Execute deste teste - nenhuma vem de AcquireAccessToken. Os markers de
  ///   credencial ficam carregados so para as asercoes de cruzamento. </summary>
  FClient.Authenticator.AuthenticatorType := TAuthenticatorType.atNoAuth;
  FClient.Authenticator.Username := cUSERNAME;
  FClient.Authenticator.Password := cPASSWORD;
  FClient.Authenticator.Token := cAUTHTOKEN;
end;

procedure TTestDriverWiRLExecuteOverload.TearDown;
begin
  FreeAndNil(FClient);
  FreeAndNil(FStub);
end;

procedure TTestDriverWiRLExecuteOverload.Premise_TheRecorderTellsThePathsApart;
var
  LConnection: IRESTConnection;
begin
  LConnection := FClient.AsConnection;
  LConnection.Execute(cRESOURCE, '', TRESTRequestMethodType.rtGET);
  LConnection.Execute(cRESOURCE, cSUBRESOURCE, TRESTRequestMethodType.rtGET);
  Assert.AreEqual(2, FStub.Count,
    'both requests must have reached the stub - with nothing recorded every ' +
    'path assertion in this fixture would be comparing two empty strings');
  Assert.IsTrue(Pos(cRESOURCE, FStub.Path(0)) > 0,
    'the resource marker must appear in the path. Found: ' + FStub.Path(0));
  Assert.IsTrue(Pos(cAPI_CONTEXT, FStub.Path(0)) > 0,
    'the app context must appear in the path. Found: ' + FStub.Path(0));
  Assert.IsTrue(Pos(cSUBRESOURCE, FStub.Path(0)) = 0,
    'the empty sub-resource must contribute nothing. Found: ' + FStub.Path(0));
  Assert.IsTrue(Pos(cSUBRESOURCE, FStub.Path(1)) > 0,
    'the sub-resource marker must appear when one is given. Found: ' +
    FStub.Path(1));
  Assert.AreNotEqual(FStub.Path(0), FStub.Path(1),
    'a sub-resource must CHANGE the path; if it did not, this recorder could ' +
    'not discriminate and the whole fixture would be decorative');
end;

procedure TTestDriverWiRLExecuteOverload.OneResource_ThroughTheConnection_DoesNotDieAbstract;
var
  LConnection: IRESTConnection;
begin
  LConnection := FClient.AsConnection;
  LConnection.Execute(cRESOURCE, TRESTRequestMethodType.rtGET);
  Assert.AreEqual(1, FStub.Count,
    '#211 verbatim: the one-resource Execute was `virtual; abstract` in ' +
    'TRESTFactoryConnection and no concrete factory overrode it, so this line ' +
    'raised EAbstractError and no request ever left');
end;

procedure TTestDriverWiRLExecuteOverload.OneResource_LandsOnTheSamePathAsAnEmptySubResource;
var
  LConnection: IRESTConnection;
begin
  LConnection := FClient.AsConnection;
  LConnection.Execute(cRESOURCE, '', TRESTRequestMethodType.rtGET);
  LConnection.Execute(cRESOURCE, TRESTRequestMethodType.rtGET);
  Assert.AreEqual(2, FStub.Count, 'both calls must have travelled');
  Assert.AreEqual(FStub.Path(0), FStub.Path(1),
    'one resource IS the pair (resource, ''''). The two-resource call reached ' +
    '"' + FStub.Path(0) + '" and the one-resource call reached "' +
    FStub.Path(1) + '" - they must be the same path, character for character');
end;

procedure TTestDriverWiRLExecuteOverload.OneResource_IsAResourceAndNotAReplacementURL;
var
  LConnection: IRESTConnection;
  LPath: string;
begin
  LConnection := FClient.AsConnection;
  LConnection.Execute(cRESOURCE, TRESTRequestMethodType.rtGET);
  Assert.AreEqual(1, FStub.Count, 'the call must have travelled');
  LPath := FStub.Path(0);
  Assert.IsTrue(Pos(cRESOURCE, LPath) > 0,
    'AResource is a RESOURCE, appended to the configured base - it must be in ' +
    'the path. TRESTClientWiRL.Execute(AURL) clears FRESTResource.Resource, so ' +
    'delegating to THAT overload loses it. Found: ' + LPath);
  Assert.IsTrue(Pos(cAPI_CONTEXT, LPath) > 0,
    'and the app context must survive too - TRESTClientWiRL.Execute(AURL) also ' +
    'blanks FRESTClientApp.AppName. Found: ' + LPath);
  Assert.IsTrue(Pos(cREST_CONTEXT, LPath) > 0,
    'and the REST context, which SetBaseURL appended. Found: ' + LPath);
end;

procedure TTestDriverWiRLExecuteOverload.OneResource_OnTheDriverItself_DoesNotDieAbstract;
var
  LDriver: TRESTDriverWiRL;
begin
  /// <summary> A conexao passa pela FABRICA. TRESTDriver tinha a MESMA
  ///   sobrecarga abstrata, e so uma chamada direta ao driver a exercita. </summary>
  LDriver := TRESTDriverWiRL.Create(FClient);
  try
    LDriver.Execute(cRESOURCE, TRESTRequestMethodType.rtGET);
    Assert.AreEqual(1, FStub.Count,
      '#211 in TRESTDriver: the one-resource overload was abstract there too, ' +
      'and none of the six drivers overrode it');
    Assert.IsTrue(Pos(cRESOURCE, FStub.Path(0)) > 0,
      'and it must carry the resource. Found: ' + FStub.Path(0));
  finally
    LDriver.Free;
  end;
end;

procedure TTestDriverWiRLExecuteOverload.OneResource_StillRunsTheParamsProcedure;
var
  LConnection: IRESTConnection;
  LRan: Boolean;
begin
  LRan := False;
  LConnection := FClient.AsConnection;
  LConnection.Execute(cRESOURCE, TRESTRequestMethodType.rtGET,
    procedure
    begin
      LRan := True;
    end);
  Assert.IsTrue(LRan,
    'the optional AParams procedure must be forwarded down to the client, ' +
    'which runs it before the URL is assembled. An implementation that dropped ' +
    'the third argument would reach the right path and still be wrong');
  Assert.AreEqual(1, FStub.Count, 'and the request must still have travelled');
end;

procedure TTestDriverWiRLExecuteOverload.FullURL_IsNoLongerAnAbstractMethod;
var
  LConnection: IRESTConnection;
  LFullURL: string;
begin
  LConnection := FClient.AsConnection;
  LFullURL := LConnection.FullURL;
  Assert.IsNotEmpty(LFullURL,
    'TRESTDriver.GetFullURL is `virtual; abstract` and only the Horse driver ' +
    'overrode it - reading FullURL through the WiRL connection raised ' +
    'EAbstractError, which is what W1020 was warning about at ' +
    'TRESTFactoryWiRL.Create');
  Assert.AreEqual(FClient.FullURL, LFullURL,
    'the driver must answer the COMPONENT''s FullURL, the same way ' +
    'TRESTDriverHorse.GetFullURL does');
  Assert.AreNotEqual(cAUTHTOKEN, LFullURL, 'not the authenticator token');
  Assert.AreNotEqual(cUSERNAME, LFullURL, 'not the username');
  Assert.AreNotEqual(cPASSWORD, LFullURL, 'not the password');
  Assert.IsTrue(Pos(cREST_CONTEXT, LFullURL) > 0,
    'and it must be a URL of THIS client - the REST context SetBaseURL ' +
    'appended has to be in it. Found: ' + LFullURL);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDriverWiRLExecuteOverload);

end.
