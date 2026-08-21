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

{ @abstract(Janus Framework - the CONCRETE WiRL REST client chain.)

  WHAT IS UNDER TEST

  The chain a user touches to get an IRESTConnection out of the WiRL driver:

    Janus.Client.WiRL             TRESTClientWiRL.Create / SetBaseURL /
                                  AccessToken
    Janus.Client.RestDriver.WiRL  TRESTDriverWiRL - every getter
    Janus.Client.RestWiRL.Factory TRESTFactoryWiRL.Create

  Nothing here opens a socket: every getter below is answered from the
  component's own fields.

  WHY IT EXISTS (#213)

  TRESTDriverWiRL shipped with THREE empty bodies - GetMethodToken,
  GetUsername and GetPassword - each silently returning ''. They are overrides,
  not omissions: the four sibling drivers (MARS, DMVC, DataSnap, WS) do not
  declare them at all, so WiRL is the one driver that declared the contract and
  left it blank.

  HOW A CROSS-WIRE IS MADE VISIBLE

  Same discipline as Test.Janus.Driver.HorseClientChain: every property is
  loaded with its OWN DISTINCT marker before anything is read back, and each
  assertion names the exact marker it expects. A getter that forwards to the
  wrong neighbour therefore returns the WRONG marker, not merely a non-empty
  string. Markers_AreAllDistinct asserts that premise first.

  Asserting the SET of values would be worthless here: the defect this fixture
  guards is precisely a getter answering with a neighbour's storage, and a set
  assertion cannot see two getters swapping.

  WHAT THIS FIXTURE DOES NOT COVER

  The acquired-token half of TRESTClientWiRL.AccessToken - the branch that
  answers FAccessToken when the Authenticator carries no explicit token - needs
  a live login. Test.Janus.Driver.WiRLTokenAcquire covers it against a loopback
  stub.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Driver.WiRLClientChain;

interface

uses
  Classes,
  SysUtils,
  Generics.Collections,
  DUnitX.TestFramework,
  Janus.Client.Base,
  Janus.Client,
  Janus.Client.WiRL,
  Janus.Client.Methods,
  Janus.RestFactory.Interfaces;

type
  [TestFixture]
  TTestDriverWiRLClientChain = class
  private
    FClient: TRESTClientWiRL;
    procedure LoadDistinctMarkers;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// The premise. If two markers were equal, every cross-wire assertion
    /// below could pass with the wires crossed.
    [Test]
    procedure Markers_AreAllDistinct;

    /// Constructing the component must build the factory chain
    /// TRESTClientWiRL -> TRESTFactoryWiRL -> TRESTDriverWiRL.
    [Test]
    procedure Chain_TheComponentExposesARestConnection;

    /// Every method-name getter, read through IRESTConnection, must come back
    /// with ITS OWN marker.
    [Test]
    procedure Chain_EveryMethodNameGetterCarriesItsOwnValue;

    /// #213 proper. The shipped driver returned '' here.
    [Test]
    procedure Token_IsNotEmptyWhenTheConnectionCarriesOne;

    /// ... and it is the AUTHENTICATOR's token, not any of its five
    /// neighbours. Named one by one, so a re-wire to any of them is red with
    /// a message that says which one.
    [Test]
    procedure Token_IsTheAuthenticatorTokenAndNotANeighbour;

    /// #213, the other two empty bodies in the same class.
    [Test]
    procedure Credentials_ComeFromTheAuthenticator;

    /// BaseURL is assembled from Host, Port and the WiRL REST context.
    [Test]
    procedure Chain_BaseURLIsAssembledFromHostAndRestContext;
  end;

implementation

const
  cGET             = 'wirl-mk-get';
  cGETID           = 'wirl-mk-getid';
  cGETWHERE        = 'wirl-mk-getwhere';
  cPOST            = 'wirl-mk-post';
  cPUT             = 'wirl-mk-put';
  cDELETE          = 'wirl-mk-delete';
  cNEXTPACKET      = 'wirl-mk-nextpacket';
  cNEXTPACKETWHERE = 'wirl-mk-nextpacketwhere';
  cMETHODTOKEN     = 'wirl-mk-methodtoken-property';
  cAUTHTOKEN       = 'wirl-mk-authenticator-token';
  cUSERNAME        = 'wirl-mk-username';
  cPASSWORD        = 'wirl-mk-password';
  cHOST            = 'janus-wirl-test-host';
  cAPICONTEXT      = 'wirl-mk-apicontext';
  cRESTCONTEXT     = 'wirl-mk-restcontext';

{ TTestDriverWiRLClientChain }

procedure TTestDriverWiRLClientChain.Setup;
begin
  FClient := TRESTClientWiRL.Create(nil);
  LoadDistinctMarkers;
end;

procedure TTestDriverWiRLClientChain.TearDown;
begin
  FreeAndNil(FClient);
end;

procedure TTestDriverWiRLClientChain.LoadDistinctMarkers;
begin
  FClient.MethodGET := cGET;
  FClient.MethodGETId := cGETID;
  FClient.MethodGETWhere := cGETWHERE;
  FClient.MethodPOST := cPOST;
  FClient.MethodPUT := cPUT;
  FClient.MethodDELETE := cDELETE;
  FClient.MethodGETNextPacket := cNEXTPACKET;
  FClient.MethodGETNextPacketWhere := cNEXTPACKETWHERE;
  /// O nome do RECURSO de login. Storage diferente do token em si - e o par
  /// que a #213 confunde.
  FClient.MethodToken := cMETHODTOKEN;
  FClient.Authenticator.Token := cAUTHTOKEN;
  FClient.Authenticator.Username := cUSERNAME;
  FClient.Authenticator.Password := cPASSWORD;
  FClient.APIContext := cAPICONTEXT;
  FClient.RESTContext := cRESTCONTEXT;
  FClient.Host := cHOST;
end;

procedure TTestDriverWiRLClientChain.Markers_AreAllDistinct;
var
  LSeen: TDictionary<string, Integer>;
  LAll: TArray<string>;
  LMarker: string;
begin
  LAll := TArray<string>.Create(cGET, cGETID, cGETWHERE, cPOST, cPUT, cDELETE,
            cNEXTPACKET, cNEXTPACKETWHERE, cMETHODTOKEN, cAUTHTOKEN, cUSERNAME,
            cPASSWORD, cHOST, cAPICONTEXT, cRESTCONTEXT);
  LSeen := TDictionary<string, Integer>.Create;
  try
    for LMarker in LAll do
    begin
      Assert.IsFalse(LSeen.ContainsKey(LMarker),
        'two markers share the value "' + LMarker + '" - with a repeated ' +
        'marker a crossed wire is undetectable and this whole fixture is ' +
        'decorative');
      LSeen.Add(LMarker, 0);
    end;
    Assert.AreEqual(Length(LAll), LSeen.Count, 'every marker must be distinct');
  finally
    LSeen.Free;
  end;
end;

procedure TTestDriverWiRLClientChain.Chain_TheComponentExposesARestConnection;
var
  LConnection: IRESTConnection;
begin
  LConnection := FClient.AsConnection;
  Assert.IsNotNull(LConnection,
    'TRESTClientWiRL.Create must have built TRESTFactoryWiRL, which builds ' +
    'TRESTDriverWiRL - a nil here means the chain was never assembled');
end;

procedure TTestDriverWiRLClientChain.Chain_EveryMethodNameGetterCarriesItsOwnValue;
var
  LConnection: IRESTConnection;
begin
  LConnection := FClient.AsConnection;
  Assert.AreEqual(cGET, LConnection.MethodGET, 'MethodGET');
  Assert.AreEqual(cGETID, LConnection.MethodGETId, 'MethodGETId');
  Assert.AreEqual(cGETWHERE, LConnection.MethodGETWhere, 'MethodGETWhere');
  Assert.AreEqual(cPOST, LConnection.MethodPOST, 'MethodPOST');
  Assert.AreEqual(cPUT, LConnection.MethodPUT, 'MethodPUT');
  Assert.AreEqual(cDELETE, LConnection.MethodDELETE, 'MethodDELETE');
  Assert.AreEqual(cNEXTPACKET, LConnection.MethodGETNextPacket,
    'MethodGETNextPacket');
  Assert.AreEqual(cNEXTPACKETWHERE, LConnection.MethodGETNextPacketWhere,
    'MethodGETNextPacketWhere');
end;

procedure TTestDriverWiRLClientChain.Token_IsNotEmptyWhenTheConnectionCarriesOne;
var
  LConnection: IRESTConnection;
begin
  LConnection := FClient.AsConnection;
  Assert.IsNotEmpty(LConnection.MethodToken,
    '#213 verbatim: TRESTDriverWiRL.GetMethodToken had an EMPTY BODY, so the ' +
    'connection answered '''' no matter what token it was carrying. The ' +
    'Authenticator of this client holds "' + cAUTHTOKEN + '"');
end;

procedure TTestDriverWiRLClientChain.Token_IsTheAuthenticatorTokenAndNotANeighbour;
var
  LConnection: IRESTConnection;
begin
  LConnection := FClient.AsConnection;
  Assert.AreEqual(cAUTHTOKEN, LConnection.MethodToken,
    'with an explicit Authenticator.Token loaded, the WiRL driver must answer ' +
    'THAT token - it is the one SetAuthenticatorTypeValues puts in the ' +
    'Authorization: Bearer header, and its branch returns before FAccessToken ' +
    'is ever consulted');
  Assert.AreNotEqual(cMETHODTOKEN, LConnection.MethodToken,
    'and NOT the component''s own MethodToken property, which is the NAME of ' +
    'the login resource (TRESTClientWiRL.AcquireAccessToken assigns it to ' +
    'LTokenResource.Resource) - the two are different storage');
  Assert.AreNotEqual(cUSERNAME, LConnection.MethodToken, 'not the username');
  Assert.AreNotEqual(cPASSWORD, LConnection.MethodToken, 'not the password');
  Assert.AreNotEqual(cNEXTPACKETWHERE, LConnection.MethodToken,
    'not MethodGETNextPacketWhere - that was the wrong getter #208 found the ' +
    'factory reading, on the very same property');
end;

procedure TTestDriverWiRLClientChain.Credentials_ComeFromTheAuthenticator;
var
  LConnection: IRESTConnection;
begin
  LConnection := FClient.AsConnection;
  Assert.AreEqual(cUSERNAME, LConnection.Username,
    'TRESTDriverWiRL.GetUsername was the second empty body in the same class');
  Assert.AreEqual(cPASSWORD, LConnection.Password,
    'TRESTDriverWiRL.GetPassword was the third');
  Assert.AreNotEqual(LConnection.Username, LConnection.Password,
    'username and password must not answer from the same storage');
end;

procedure TTestDriverWiRLClientChain.Chain_BaseURLIsAssembledFromHostAndRestContext;
var
  LConnection: IRESTConnection;
  LBaseURL: string;
begin
  LConnection := FClient.AsConnection;
  LBaseURL := LConnection.BaseURL;
  Assert.AreNotEqual('', LBaseURL, 'SetBaseURL must have produced something');
  Assert.IsTrue(Pos(cHOST, LBaseURL) > 0,
    'the host must appear in the base URL. Found: ' + LBaseURL);
  Assert.IsTrue(Pos(cRESTCONTEXT, LBaseURL) > 0,
    'TRESTClientWiRL.SetBaseURL appends the REST context. Found: ' + LBaseURL);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDriverWiRLClientChain);

end.
