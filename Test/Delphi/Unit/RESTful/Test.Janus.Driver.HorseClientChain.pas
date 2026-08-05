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

{ @abstract(Janus Framework - the CONCRETE Horse REST client chain.)

  WHAT IS UNDER TEST

  The five units a user actually touches to get an IRESTConnection out of the
  Horse driver, none of which produced a .dcu from any test binary on the base
  this was written against:

    Janus.Client.Consts
    Janus.Client.Base            TJanusClientBase.AsConnection
    Janus.Client                 TJanusClient - the method-token properties
    Janus.Client.Horse           TRESTClientHorse.Create / SetBaseURL
    Janus.Client.RestDriver.Horse TRESTDriverHorse - every getter
    Janus.Client.RestHorse.Factory TRESTFactoryHorse.Create
    Janus.Client.RestException

  WHY IT CLOSES A DECLARED GAP

  Test.Janus.RestFactory.MethodToken - the fixture written for the MethodToken
  defect - says in its own header: "the concrete drivers (TRESTDriverHorse and
  siblings) are not exercised. Reaching TRESTDriverHorse.GetMethodToken needs a
  live TRESTClientHorse". That is half right. It needs a live TRESTClientHorse;
  it does NOT need a live server, because every getter below is answered from
  the component's own fields and never opens a socket. Nothing here performs a
  request.

  HOW A CROSS-WIRE IS MADE VISIBLE

  Same discipline as the fixture above: each property is loaded with its own
  DISTINCT marker before anything is read back, so a getter that forwards to
  the wrong neighbour returns the wrong marker instead of merely returning a
  non-empty string. Markers_AreAllDistinct asserts that premise first.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Driver.HorseClientChain;

interface

{$IFNDEF DRIVERRESTFUL}
  {$MESSAGE FATAL 'This unit belongs to Janus.Tests.RESTfulDriver, whose .dproj carries DRIVERRESTFUL. If this fires, the configuration this suite exists to protect has been switched off.'}
{$ENDIF}

uses
  Classes,
  SysUtils,
  Generics.Collections,
  DUnitX.TestFramework,
  Janus.Client.Base,
  Janus.Client,
  Janus.Client.Horse,
  Janus.Client.Methods,
  Janus.RestFactory.Interfaces,
  Janus.Manager.DataSet;

type
  [TestFixture]
  TTestDriverHorseClientChain = class
  private
    FClient: TRESTClientHorse;
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
    /// TRESTClientHorse -> TRESTFactoryHorse -> TRESTDriverHorse.
    [Test]
    procedure Chain_TheComponentExposesARestConnection;

    /// Every method-name getter, read through IRESTConnection, must come back
    /// with ITS OWN marker.
    [Test]
    procedure Chain_EveryMethodNameGetterCarriesItsOwnValue;

    /// Characterisation, deliberately: in the Horse driver MethodToken is
    /// answered from Authenticator.Token and NOT from the component's own
    /// MethodToken property. The two are loaded with different markers, so
    /// this test states which one the shipped chain reads. It is not a claim
    /// about which one SHOULD be read - it is a tripwire for a silent change.
    [Test]
    procedure Chain_MethodTokenIsTheAuthenticatorToken;

    /// Username/Password come from the Authenticator too.
    [Test]
    procedure Chain_CredentialsComeFromTheAuthenticator;

    /// BaseURL is assembled from Host and APIContext by SetBaseURL.
    [Test]
    procedure Chain_BaseURLIsAssembledFromHostAndApiContext;

    /// The shape every Example uses, end to end:
    ///   TManagerDataSet.Create(RESTClientHorse1.AsConnection)
    /// This is the one assertion in the suite that joins the concrete client
    /// to the manager, and it only compiles under DRIVERRESTFUL.
    [Test]
    procedure Chain_TheManagerAcceptsTheClientConnection;
  end;

implementation

const
  cGET             = 'mk-get';
  cGETID           = 'mk-getid';
  cGETWHERE        = 'mk-getwhere';
  cPOST            = 'mk-post';
  cPUT             = 'mk-put';
  cDELETE          = 'mk-delete';
  cNEXTPACKET      = 'mk-nextpacket';
  cNEXTPACKETWHERE = 'mk-nextpacketwhere';
  cMETHODTOKEN     = 'mk-methodtoken-property';
  cAUTHTOKEN       = 'mk-authenticator-token';
  cUSERNAME        = 'mk-username';
  cPASSWORD        = 'mk-password';
  cHOST            = 'janus-test-host';
  cAPICONTEXT      = 'mk-apicontext';

{ TTestDriverHorseClientChain }

procedure TTestDriverHorseClientChain.Setup;
begin
  FClient := TRESTClientHorse.Create(nil);
  LoadDistinctMarkers;
end;

procedure TTestDriverHorseClientChain.TearDown;
begin
  FreeAndNil(FClient);
end;

procedure TTestDriverHorseClientChain.LoadDistinctMarkers;
begin
  FClient.MethodGET := cGET;
  FClient.MethodGETId := cGETID;
  FClient.MethodGETWhere := cGETWHERE;
  FClient.MethodPOST := cPOST;
  FClient.MethodPUT := cPUT;
  FClient.MethodDELETE := cDELETE;
  FClient.MethodGETNextPacket := cNEXTPACKET;
  FClient.MethodGETNextPacketWhere := cNEXTPACKETWHERE;
  FClient.MethodToken := cMETHODTOKEN;
  FClient.Authenticator.Token := cAUTHTOKEN;
  FClient.Authenticator.Username := cUSERNAME;
  FClient.Authenticator.Password := cPASSWORD;
  FClient.APIContext := cAPICONTEXT;
  FClient.Host := cHOST;
end;

procedure TTestDriverHorseClientChain.Markers_AreAllDistinct;
var
  LSeen: TDictionary<string, Integer>;
  LAll: TArray<string>;
  LMarker: string;
begin
  LAll := TArray<string>.Create(cGET, cGETID, cGETWHERE, cPOST, cPUT, cDELETE,
            cNEXTPACKET, cNEXTPACKETWHERE, cMETHODTOKEN, cAUTHTOKEN, cUSERNAME,
            cPASSWORD, cHOST, cAPICONTEXT);
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

procedure TTestDriverHorseClientChain.Chain_TheComponentExposesARestConnection;
var
  LConnection: IRESTConnection;
begin
  LConnection := FClient.AsConnection;
  Assert.IsNotNull(LConnection,
    'TRESTClientHorse.Create must have built TRESTFactoryHorse, which builds ' +
    'TRESTDriverHorse - a nil here means the chain was never assembled');
end;

procedure TTestDriverHorseClientChain.Chain_EveryMethodNameGetterCarriesItsOwnValue;
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

procedure TTestDriverHorseClientChain.Chain_MethodTokenIsTheAuthenticatorToken;
var
  LConnection: IRESTConnection;
begin
  LConnection := FClient.AsConnection;
  Assert.AreEqual(cAUTHTOKEN, LConnection.MethodToken,
    'the Horse driver answers MethodToken from Authenticator.Token');
  Assert.AreNotEqual(cMETHODTOKEN, LConnection.MethodToken,
    'and NOT from the component''s own MethodToken property - the two are ' +
    'different storage and this fixture pins which one the chain reads');
end;

procedure TTestDriverHorseClientChain.Chain_CredentialsComeFromTheAuthenticator;
var
  LConnection: IRESTConnection;
begin
  LConnection := FClient.AsConnection;
  Assert.AreEqual(cUSERNAME, LConnection.Username, 'Username');
  Assert.AreEqual(cPASSWORD, LConnection.Password, 'Password');
end;

procedure TTestDriverHorseClientChain.Chain_BaseURLIsAssembledFromHostAndApiContext;
var
  LConnection: IRESTConnection;
  LBaseURL: string;
begin
  LConnection := FClient.AsConnection;
  LBaseURL := LConnection.BaseURL;
  Assert.AreNotEqual('', LBaseURL, 'SetBaseURL must have produced something');
  Assert.IsTrue(Pos(cHOST, LBaseURL) > 0,
    'the host must appear in the base URL. Found: ' + LBaseURL);
  Assert.IsTrue(Pos(cAPICONTEXT, LBaseURL) > 0,
    'the API context must appear in the base URL. Found: ' + LBaseURL);
end;

procedure TTestDriverHorseClientChain.Chain_TheManagerAcceptsTheClientConnection;
var
  LManager: TManagerDataSet;
begin
  // Under the non-REST branch TManagerDataSet.Create takes an IDBConnection
  // and this line does not compile at all.
  LManager := TManagerDataSet.Create(FClient.AsConnection);
  try
    Assert.IsNotNull(LManager,
      'the Example shape TManagerDataSet.Create(client.AsConnection) must hold');
  finally
    LManager.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDriverHorseClientChain);

end.
