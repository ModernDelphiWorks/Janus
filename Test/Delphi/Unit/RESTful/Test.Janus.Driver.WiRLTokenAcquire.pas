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

{ @abstract(Janus Framework - the WiRL token the connection actually presents.)

  WHY A LIVE STUB AND NOT A DOUBLE

  After #228 the WiRL client no longer holds a token component. It LOGS IN:
  TRESTClientWiRL.AcquireAccessToken POSTs to the auth resource and keeps the
  answer in the private FAccessToken, and SetAuthenticatorTypeValues sends it
  as `Authorization: Bearer`. The Authenticator is never written back.

  That is the whole point of #213. Copying the Horse driver - whose
  GetMethodToken returns Authenticator.Token - would answer '' for every
  connection that logged in with username and password, which is the ONLY
  authentication flow the WiRL client implements today. So the driver answers
  TRESTClientWiRL.AccessToken, and the acquired branch of that getter cannot be
  reached without a login actually happening.

  The stub is a bare TIdHTTPServer on the loopback interface. It is not a WiRL
  server and does not pretend to be one: it answers the two documents the
  client asks for and records what arrived. Nothing leaves the machine.
  Janus.Tests.RESTHorse already starts a real listener on a port for the same
  reason.

  WHAT IS PROVED HERE

    1. the token the server issued becomes the token the connection reports;
    2. an explicit Authenticator.Token still wins over it, which is the
       precedence SetAuthenticatorTypeValues implements;
    3. the reported token is the one that actually travelled in the
       Authorization header - so the getter cannot drift from the wire.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Driver.WiRLTokenAcquire;

interface

uses
  Classes,
  SysUtils,
  SyncObjs,
  DUnitX.TestFramework,
  IdContext,
  IdCustomHTTPServer,
  IdHTTPServer,
  IdSocketHandle,
  Janus.Client.Base,
  Janus.Client,
  Janus.Client.WiRL,
  Janus.Client.Methods,
  Janus.RestFactory.Interfaces;

type
  /// <summary> Servidor minimo de emprestimo. Responde o recurso de login com
  ///   um access_token e qualquer outro documento com uma lista vazia, e
  ///   guarda o cabecalho Authorization que chegou em cada um. </summary>
  TStubAuthServer = class
  private
    FServer: TIdHTTPServer;
    FLock: TCriticalSection;
    FIssuedToken: string;
    FLoginHits: Integer;
    FDataAuthHeader: string;
    FLoginAuthHeader: string;
    FPort: Integer;
    procedure DoCommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
    procedure DoParseAuthentication(AContext: TIdContext;
      const AAuthType, AAuthData: string; var VUsername, VPassword: string;
      var VHandled: Boolean);
    function GetDataAuthHeader: string;
    function GetLoginAuthHeader: string;
    function GetLoginHits: Integer;
  public
    constructor Create(const AIssuedToken, ATokenDocument: string);
    destructor Destroy; override;
    property Port: Integer read FPort;
    property IssuedToken: string read FIssuedToken;
    property LoginHits: Integer read GetLoginHits;
    property DataAuthHeader: string read GetDataAuthHeader;
    property LoginAuthHeader: string read GetLoginAuthHeader;
  end;

  [TestFixture]
  TTestDriverWiRLTokenAcquire = class
  private
    FStub: TStubAuthServer;
    FClient: TRESTClientWiRL;
    procedure BuildClient;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// The premise: before any request the connection has no token at all, so
    /// a getter that answered a constant would be caught here.
    [Test]
    procedure BeforeAnyRequest_TheConnectionReportsNoToken;

    /// The acquired branch. Authenticator carries credentials and NO token;
    /// after one request the connection must report what the server issued.
    [Test]
    procedure AfterLogin_TheConnectionReportsTheAcquiredToken;

    /// The reported token is the one that TRAVELLED. Ties the getter to the
    /// wire, so it cannot drift into reporting some other storage.
    [Test]
    procedure TheReportedToken_IsTheOneSentAsBearer;

    /// The precedence: an explicit Authenticator.Token wins, and no login is
    /// even attempted.
    [Test]
    procedure ExplicitToken_WinsOverTheAcquiredOne;

    /// The ONLY case that pins the precedence, and it took a surviving
    /// mutation to find it. In the test above FAccessToken is empty, so an
    /// INVERTED precedence answers the same value and stays green. Here both
    /// storages are loaded - the client logs in first, and only then is an
    /// explicit token assigned - so the two orders give different answers.
    [Test]
    procedure WithBothTokensLoaded_TheExplicitOneWins;
  end;

implementation

const
  cTOKEN_DOCUMENT = 'token';
  cAPI_CONTEXT    = 'app';
  cREST_CONTEXT   = 'rest';
  cDATA_RESOURCE  = 'customers';
  cISSUED_TOKEN   = 'wirl-server-issued-token-9f3a';
  cEXPLICIT_TOKEN = 'wirl-explicit-authenticator-token-11c7';
  cUSERNAME       = 'wirl-user';
  cPASSWORD       = 'wirl-secret';

{ TStubAuthServer }

constructor TStubAuthServer.Create(const AIssuedToken, ATokenDocument: string);
var
  LBinding: TIdSocketHandle;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FIssuedToken := AIssuedToken;
  FLoginHits := 0;
  FDataAuthHeader := '';
  FLoginAuthHeader := '';
  FPort := 9930 + Random(60);
  FServer := TIdHTTPServer.Create(nil);
  FServer.OnCommandGet := DoCommandGet;
  FServer.OnCommandOther := DoCommandGet;
  /// <summary> Sem isto o proprio Indy responde 401 "Unsupported
  ///   authorization scheme" antes de chegar no handler: o parser embutido so
  ///   conhece Basic, e o que este teste manda e Bearer. Quem le o cabecalho
  ///   aqui e o teste, nao o Indy. </summary>
  FServer.OnParseAuthentication := DoParseAuthentication;
  LBinding := FServer.Bindings.Add;
  LBinding.IP := '127.0.0.1';
  LBinding.Port := FPort;
  FServer.Active := True;
end;

destructor TStubAuthServer.Destroy;
begin
  if FServer.Active then
    FServer.Active := False;
  FServer.Free;
  FLock.Free;
  inherited;
end;

procedure TStubAuthServer.DoCommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  LAuth: string;
begin
  LAuth := ARequestInfo.RawHeaders.Values['Authorization'];
  AResponseInfo.ResponseNo := 200;
  AResponseInfo.ContentType := 'application/json';
  FLock.Acquire;
  try
    if Pos('/' + cTOKEN_DOCUMENT, ARequestInfo.Document) > 0 then
    begin
      Inc(FLoginHits);
      FLoginAuthHeader := LAuth;
      AResponseInfo.ContentText := '{"access_token":"' + FIssuedToken + '"}';
    end
    else
    begin
      FDataAuthHeader := LAuth;
      AResponseInfo.ContentText := '[]';
    end;
  finally
    FLock.Release;
  end;
end;

procedure TStubAuthServer.DoParseAuthentication(AContext: TIdContext;
  const AAuthType, AAuthData: string; var VUsername, VPassword: string;
  var VHandled: Boolean);
begin
  VHandled := True;
end;

function TStubAuthServer.GetDataAuthHeader: string;
begin
  FLock.Acquire;
  try
    Result := FDataAuthHeader;
  finally
    FLock.Release;
  end;
end;

function TStubAuthServer.GetLoginAuthHeader: string;
begin
  FLock.Acquire;
  try
    Result := FLoginAuthHeader;
  finally
    FLock.Release;
  end;
end;

function TStubAuthServer.GetLoginHits: Integer;
begin
  FLock.Acquire;
  try
    Result := FLoginHits;
  finally
    FLock.Release;
  end;
end;

{ TTestDriverWiRLTokenAcquire }

procedure TTestDriverWiRLTokenAcquire.BuildClient;
begin
  FClient := TRESTClientWiRL.Create(nil);
  FClient.Host := '127.0.0.1';
  FClient.Port := FStub.Port;
  FClient.RESTContext := cREST_CONTEXT;
  FClient.APIContext := cAPI_CONTEXT;
  /// O NOME do recurso de login, nao o token.
  FClient.MethodToken := cTOKEN_DOCUMENT;
  FClient.Authenticator.AuthenticatorType := TAuthenticatorType.atBearerToken;
  FClient.Authenticator.Username := cUSERNAME;
  FClient.Authenticator.Password := cPASSWORD;
end;

procedure TTestDriverWiRLTokenAcquire.Setup;
begin
  FStub := TStubAuthServer.Create(cISSUED_TOKEN, cTOKEN_DOCUMENT);
  BuildClient;
end;

procedure TTestDriverWiRLTokenAcquire.TearDown;
begin
  FreeAndNil(FClient);
  FreeAndNil(FStub);
end;

procedure TTestDriverWiRLTokenAcquire.BeforeAnyRequest_TheConnectionReportsNoToken;
var
  LConnection: IRESTConnection;
begin
  LConnection := FClient.AsConnection;
  Assert.AreEqual('', LConnection.MethodToken,
    'nothing has logged in yet and the Authenticator carries no explicit ' +
    'token, so there is no token to report. A getter answering a constant, ' +
    'or answering the login RESOURCE NAME "' + cTOKEN_DOCUMENT + '", fails here');
end;

procedure TTestDriverWiRLTokenAcquire.AfterLogin_TheConnectionReportsTheAcquiredToken;
var
  LConnection: IRESTConnection;
begin
  LConnection := FClient.AsConnection;
  FClient.Execute(cDATA_RESOURCE, '', TRESTRequestMethodType.rtGET);
  Assert.AreEqual(1, FStub.LoginHits,
    'the client must have POSTed the auth resource exactly once - without ' +
    'that, the assertion below would be measuring nothing');
  Assert.AreEqual(cISSUED_TOKEN, LConnection.MethodToken,
    '#213: the token this connection holds was ACQUIRED by ' +
    'AcquireAccessToken and lives in FAccessToken, NOT in the Authenticator. ' +
    'Answering Authenticator.Token the way the Horse driver does returns '''' ' +
    'here, which is the very defect the issue reports');
  Assert.AreNotEqual(cTOKEN_DOCUMENT, LConnection.MethodToken,
    'and it is not the login resource name');
  Assert.AreEqual('', FClient.Authenticator.Token,
    'premise of this test: the acquired token is NOT written back to the ' +
    'Authenticator. If it ever is, this fixture stops discriminating and the ' +
    'driver could go back to reading Authenticator.Token unnoticed');
end;

procedure TTestDriverWiRLTokenAcquire.TheReportedToken_IsTheOneSentAsBearer;
var
  LConnection: IRESTConnection;
begin
  LConnection := FClient.AsConnection;
  FClient.Execute(cDATA_RESOURCE, '', TRESTRequestMethodType.rtGET);
  Assert.AreEqual('Bearer ' + cISSUED_TOKEN, FStub.DataAuthHeader,
    'the data request must have carried the acquired token as a bearer');
  Assert.AreEqual('Bearer ' + LConnection.MethodToken, FStub.DataAuthHeader,
    'and what the connection REPORTS must be exactly what it SENT - if these ' +
    'two ever disagree the getter is describing a different storage from the ' +
    'one SetAuthenticatorTypeValues writes into the header');
end;

procedure TTestDriverWiRLTokenAcquire.ExplicitToken_WinsOverTheAcquiredOne;
var
  LConnection: IRESTConnection;
begin
  FClient.Authenticator.Token := cEXPLICIT_TOKEN;
  LConnection := FClient.AsConnection;
  FClient.Execute(cDATA_RESOURCE, '', TRESTRequestMethodType.rtGET);
  Assert.AreEqual(0, FStub.LoginHits,
    'with an explicit token there is nothing to log in for - ' +
    'SetAuthenticatorTypeValues returns before it reaches AcquireAccessToken');
  Assert.AreEqual(cEXPLICIT_TOKEN, LConnection.MethodToken,
    'the explicit Authenticator token wins over FAccessToken, the same ' +
    'precedence the header path uses');
  Assert.AreEqual('Bearer ' + cEXPLICIT_TOKEN, FStub.DataAuthHeader,
    'and it is the one that travelled');
  Assert.AreNotEqual(cISSUED_TOKEN, LConnection.MethodToken,
    'the server''s token must not appear - it was never asked for');
end;

procedure TTestDriverWiRLTokenAcquire.WithBothTokensLoaded_TheExplicitOneWins;
var
  LConnection: IRESTConnection;
begin
  LConnection := FClient.AsConnection;
  /// Primeiro faz o login: FAccessToken passa a valer.
  FClient.Execute(cDATA_RESOURCE, '', TRESTRequestMethodType.rtGET);
  Assert.AreEqual(cISSUED_TOKEN, LConnection.MethodToken,
    'premise: the login must have happened, otherwise only one storage is ' +
    'loaded and this test cannot tell the two precedences apart');
  /// Agora o usuario impoe um token proprio. As DUAS fontes estao cheias.
  FClient.Authenticator.Token := cEXPLICIT_TOKEN;
  FClient.Execute(cDATA_RESOURCE, '', TRESTRequestMethodType.rtGET);
  Assert.AreEqual(cEXPLICIT_TOKEN, LConnection.MethodToken,
    'with BOTH an acquired token and an explicit one, the explicit token ' +
    'wins - that is the order SetAuthenticatorTypeValues implements, whose ' +
    'explicit branch returns before FAccessToken is ever read');
  Assert.AreEqual('Bearer ' + cEXPLICIT_TOKEN, FStub.DataAuthHeader,
    'and the explicit token is the one that travelled, so the getter and the ' +
    'header agree on which storage wins');
  Assert.AreEqual(1, FStub.LoginHits,
    'the second request must NOT log in again - it already has a token');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDriverWiRLTokenAcquire);

end.
