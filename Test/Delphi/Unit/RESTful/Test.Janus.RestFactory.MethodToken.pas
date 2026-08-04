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

{ @abstract(Janus Framework - TRESTFactoryConnection property/getter wiring.)

  WHAT THIS FIXTURE GUARDS. Janus.RestFactory.Connection.pas declares fourteen
  read-only properties, each one a thin forward to a same-named getter that
  forwards again to TRESTDriver. Nothing in that block has any logic - which is
  exactly why a wrong getter name in it is invisible: it still compiles, still
  returns a String, and still returns a NON-EMPTY String. The class shipped with
  MethodToken reading GetMethodGETNextPacketWhere.

  WHY "NOT EMPTY" IS NOT A TEST. Both getters return a String, and in every
  realistic configuration both are non-empty. A test that only asserted
  MethodToken <> '' would have been green with the defect in place. The whole
  design of this fixture is therefore: the driver double must return a
  DIFFERENT, KNOWN marker from every getter, so that reading the wrong one is
  detectable by VALUE and not merely by shape. That premise is itself asserted
  first, in Double_EveryGetter_ReturnsADistinctValue - a toothless double would
  make every other assertion here vacuous.

  WHY THE CLASS-TYPED VIEW, NOT THE INTERFACE. IRESTConnection
  (Janus.RestFactory.Interfaces.pas) declares MethodToken with the CORRECT
  getter, and every production consumer holds the factory as IRESTConnection
  (see TJanusClientBase.FRESTFactory). The defect therefore only surfaces
  through a variable typed as the CLASS. A test written against IRESTConnection
  would be green with the defect in place. Every assertion below that targets
  the defect reads through a class-typed variable, deliberately.

  ANCHORS ARE BY METHOD/PROPERTY, DELIBERATELY - an `arquivo:linha` anchor rots
  on the first commit that inserts a line above it.

  Covered sites:
    Janus.RestFactory.Connection.pas  TRESTFactoryConnection.MethodToken
                                      (property -> getter binding)
    Janus.RestFactory.Connection.pas  TRESTFactoryConnection.MethodGET,
                                      MethodGETId, MethodGETWhere, MethodPOST,
                                      MethodPUT, MethodDELETE,
                                      MethodGETNextPacket,
                                      MethodGETNextPacketWhere, BaseURL,
                                      FullURL, Username, Password, ServerUse
                                      (same binding, swept so the NEXT
                                      copy-paste of this shape cannot ship)

  NOT covered here, and why: the concrete drivers (TRESTDriverHorse and
  siblings) are not exercised. Reaching TRESTDriverHorse.GetMethodToken needs a
  live TRESTClientHorse with an Authenticator; that is integration territory
  (Test\Delphi\RESTHorse), not this fixture. What is proved here is the
  forwarding layer, which is where the defect was.
}

unit Test.Janus.RestFactory.MethodToken;

interface

uses
  Classes,
  SysUtils,
  DUnitX.TestFramework,
  Janus.Client.Methods,
  Janus.Client.RestDriver,
  Janus.RestFactory.Interfaces,
  Janus.RestFactory.Connection;

type
  /// A TRESTDriver double whose every getter returns a DISTINCT, KNOWN marker.
  /// Distinctness is the entire point: it is what turns "read the wrong getter"
  /// from an invisible defect into a failing assertion.
  TRestDriverDouble = class(TRESTDriver)
  public
    function GetBaseURL: String; override;
    function GetFullURL: String; override;
    function GetUsername: String; override;
    function GetPassword: String; override;
    function GetMethodGET: String; override;
    function GetMethodGETId: String; override;
    function GetMethodGETWhere: String; override;
    function GetMethodPOST: String; override;
    function GetMethodPUT: String; override;
    function GetMethodDELETE: String; override;
    function GetMethodGETNextPacket: String; override;
    function GetMethodGETNextPacketWhere: String; override;
    function GetMethodToken: String; override;
    function GetServerUse: Boolean; override;
    function Execute(const AResource, ASubResource: String;
      const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): String; overload; override;
    function Execute(const AResource: String;
      const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): String; overload; override;
    procedure SetClassNotServerUse(const Value: Boolean); override;
    procedure AddParam(const AValue: String); override;
    procedure AddQueryParam(const AValue: String); override;
    procedure AddBodyParam(const AValue: String); override;
  end;

  /// The smallest possible concrete TRESTFactoryConnection: it exists only to
  /// plug the double into the protected FDriverConnection, exactly the way
  /// TRESTFactoryHorse.Create plugs in TRESTDriverHorse. No new seam is added
  /// to Source for the sake of this test.
  TRestFactoryConnectionDouble = class(TRESTFactoryConnection)
  public
    constructor Create(AConnection: TComponent); override;
    function Execute(const AResource, ASubResource: String;
      const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): String; overload; override;
    function Execute(const AResource: String;
      const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): String; overload; override;
  end;

  [TestFixture]
  TTestRestFactoryMethodToken = class
  public
    // ---- the double itself: a gate that cannot fail is not a gate ----------
    /// If two getters of the double returned the same text, every value
    /// assertion in this fixture would pass with the defect in place.
    [Test]
    procedure Double_EveryGetter_ReturnsADistinctValue;

    // ---- the defect ---------------------------------------------------------
    /// The one that goes RED with the shipped getter and GREEN with the fix.
    [Test]
    procedure MethodToken_ReturnsTheTokenValue;
    /// The same fact stated as the defect shape, so the failure message names
    /// what actually happened instead of just showing two strings.
    [Test]
    procedure MethodToken_DoesNotReturnTheNextPacketWhereValue;
    /// A "fix" that pointed BOTH properties at GetMethodToken would satisfy the
    /// two above. This one refuses that.
    [Test]
    procedure MethodGETNextPacketWhere_StillReturnsItsOwnValue;

    // ---- class view vs interface view --------------------------------------
    /// No literals: the class-typed property must read the same getter the
    /// interface-typed property reads. This is the assertion that generalises -
    /// it needs no knowledge of which getter is "right".
    [Test]
    procedure MethodToken_ClassView_AgreesWithInterfaceView;
    /// The sweep over the whole property block, so the next copy-paste of this
    /// shape cannot reach main unnoticed.
    [Test]
    procedure EveryProperty_ClassView_AgreesWithInterfaceView;
  end;

implementation

const
  // Distinct by construction. The numeric prefix makes an accidental cross-wire
  // readable at a glance in the assertion message.
  cBASEURL         = '01-baseurl';
  cFULLURL         = '02-fullurl';
  cUSERNAME        = '03-username';
  cPASSWORD        = '04-password';
  cGET             = '05-methodget';
  cGETID           = '06-methodgetid';
  cGETWHERE        = '07-methodgetwhere';
  cPOST            = '08-methodpost';
  cPUT             = '09-methodput';
  cDELETE          = '10-methoddelete';
  cNEXTPACKET      = '11-methodgetnextpacket';
  cNEXTPACKETWHERE = '12-methodgetnextpacketwhere-route';
  cTOKEN           = '13-methodtoken-Bearer-abc123';
  cSERVERUSE       = True;

{ TRestDriverDouble }

function TRestDriverDouble.GetBaseURL: String;
begin
  Result := cBASEURL;
end;

function TRestDriverDouble.GetFullURL: String;
begin
  Result := cFULLURL;
end;

function TRestDriverDouble.GetUsername: String;
begin
  Result := cUSERNAME;
end;

function TRestDriverDouble.GetPassword: String;
begin
  Result := cPASSWORD;
end;

function TRestDriverDouble.GetMethodGET: String;
begin
  Result := cGET;
end;

function TRestDriverDouble.GetMethodGETId: String;
begin
  Result := cGETID;
end;

function TRestDriverDouble.GetMethodGETWhere: String;
begin
  Result := cGETWHERE;
end;

function TRestDriverDouble.GetMethodPOST: String;
begin
  Result := cPOST;
end;

function TRestDriverDouble.GetMethodPUT: String;
begin
  Result := cPUT;
end;

function TRestDriverDouble.GetMethodDELETE: String;
begin
  Result := cDELETE;
end;

function TRestDriverDouble.GetMethodGETNextPacket: String;
begin
  Result := cNEXTPACKET;
end;

function TRestDriverDouble.GetMethodGETNextPacketWhere: String;
begin
  Result := cNEXTPACKETWHERE;
end;

function TRestDriverDouble.GetMethodToken: String;
begin
  // In the shipped Horse driver this is the AUTHENTICATOR TOKEN, not a route
  // name (TRESTDriverHorse.GetMethodToken returns FConnection.Authenticator.
  // Token). That is why reading the wrong getter here is a category error and
  // not a cosmetic one.
  Result := cTOKEN;
end;

function TRestDriverDouble.GetServerUse: Boolean;
begin
  Result := cSERVERUSE;
end;

function TRestDriverDouble.Execute(const AResource, ASubResource: String;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): String;
begin
  Result := '';
end;

function TRestDriverDouble.Execute(const AResource: String;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): String;
begin
  Result := '';
end;

procedure TRestDriverDouble.SetClassNotServerUse(const Value: Boolean);
begin
end;

procedure TRestDriverDouble.AddParam(const AValue: String);
begin
end;

procedure TRestDriverDouble.AddQueryParam(const AValue: String);
begin
end;

procedure TRestDriverDouble.AddBodyParam(const AValue: String);
begin
end;

{ TRestFactoryConnectionDouble }

constructor TRestFactoryConnectionDouble.Create(AConnection: TComponent);
begin
  inherited;
  FDriverConnection := TRestDriverDouble.Create(AConnection);
end;

function TRestFactoryConnectionDouble.Execute(const AResource, ASubResource: String;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): String;
begin
  Result := FDriverConnection.Execute(AResource, ASubResource, ARequestMethod, AParams);
end;

function TRestFactoryConnectionDouble.Execute(const AResource: String;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): String;
begin
  Result := FDriverConnection.Execute(AResource, ARequestMethod, AParams);
end;

{ TTestRestFactoryMethodToken }

procedure TTestRestFactoryMethodToken.Double_EveryGetter_ReturnsADistinctValue;
var
  LDriver: TRestDriverDouble;
begin
  // META-CHECK. This fixture proves "the property read the WRONG getter" by
  // comparing VALUES. That only works if the getters disagree. If this test
  // ever goes red, no other test in the fixture means anything.
  LDriver := TRestDriverDouble.Create(nil);
  try
    Assert.IsNotEmpty(LDriver.GetMethodToken,
      'the token marker must be non-empty, otherwise a non-empty check would ' +
      'be the only thing under test');
    Assert.IsNotEmpty(LDriver.GetMethodGETNextPacketWhere,
      'the nextpacketwhere marker must be non-empty - the shipped defect ' +
      'returns THIS value, and a test can only see the swap if it is real text');
    Assert.AreNotEqual(LDriver.GetMethodGETNextPacketWhere, LDriver.GetMethodToken,
      'the two getters at the heart of this defect MUST return different text; ' +
      'if they matched, MethodToken reading the wrong getter would be ' +
      'undetectable and this whole fixture would be decorative');
    // and the rest of the block, so the sweep below is equally meaningful
    Assert.AreNotEqual(LDriver.GetMethodGET, LDriver.GetMethodGETId);
    Assert.AreNotEqual(LDriver.GetMethodGETId, LDriver.GetMethodGETWhere);
    Assert.AreNotEqual(LDriver.GetMethodPOST, LDriver.GetMethodPUT);
    Assert.AreNotEqual(LDriver.GetMethodPUT, LDriver.GetMethodDELETE);
    Assert.AreNotEqual(LDriver.GetMethodGETNextPacket,
                       LDriver.GetMethodGETNextPacketWhere);
    Assert.AreNotEqual(LDriver.GetBaseURL, LDriver.GetFullURL);
    Assert.AreNotEqual(LDriver.GetUsername, LDriver.GetPassword);
  finally
    LDriver.Free;
  end;
end;

procedure TTestRestFactoryMethodToken.MethodToken_ReturnsTheTokenValue;
var
  LFactory: TRestFactoryConnectionDouble;
begin
  // CLASS-TYPED on purpose - see the unit header. Held as IRESTConnection this
  // would be green even with the defect.
  LFactory := TRestFactoryConnectionDouble.Create(nil);
  try
    Assert.AreEqual(cTOKEN, LFactory.MethodToken,
      'MethodToken must forward to GetMethodToken; the shipped class forwarded ' +
      'it to GetMethodGETNextPacketWhere, so it answered a route name where ' +
      'the caller asked for an authentication token');
  finally
    LFactory.Free;
  end;
end;

procedure TTestRestFactoryMethodToken.MethodToken_DoesNotReturnTheNextPacketWhereValue;
var
  LFactory: TRestFactoryConnectionDouble;
begin
  LFactory := TRestFactoryConnectionDouble.Create(nil);
  try
    Assert.AreNotEqual(cNEXTPACKETWHERE, LFactory.MethodToken,
      'this is the defect verbatim: MethodToken answering the value of ' +
      'MethodGETNextPacketWhere');
  finally
    LFactory.Free;
  end;
end;

procedure TTestRestFactoryMethodToken.MethodGETNextPacketWhere_StillReturnsItsOwnValue;
var
  LFactory: TRestFactoryConnectionDouble;
begin
  // Guards the lazy repair: pointing BOTH properties at GetMethodToken would
  // satisfy the two tests above and silently break paging.
  LFactory := TRestFactoryConnectionDouble.Create(nil);
  try
    Assert.AreEqual(cNEXTPACKETWHERE, LFactory.MethodGETNextPacketWhere,
      'fixing MethodToken must not disturb the property it was wrongly ' +
      'borrowing from');
  finally
    LFactory.Free;
  end;
end;

procedure TTestRestFactoryMethodToken.MethodToken_ClassView_AgreesWithInterfaceView;
var
  LObject: TRestFactoryConnectionDouble;
  LInterface: IRESTConnection;
begin
  // IRESTConnection.MethodToken is declared against GetMethodToken, so with the
  // defect in place the SAME instance answers two different things depending on
  // how the variable is typed. That divergence is the defect, stated without a
  // single literal.
  LObject := TRestFactoryConnectionDouble.Create(nil);
  LInterface := LObject;
  try
    Assert.AreEqual(LInterface.MethodToken, LObject.MethodToken,
      'one instance must not answer two different tokens depending on whether ' +
      'the caller holds it as IRESTConnection or as the class');
  finally
    // the interface owns the instance - never Free it as well
    LInterface := nil;
  end;
end;

procedure TTestRestFactoryMethodToken.EveryProperty_ClassView_AgreesWithInterfaceView;
var
  LObject: TRestFactoryConnectionDouble;
  LInterface: IRESTConnection;

  procedure Check(const AName, AFromInterface, AFromClass: string);
  begin
    Assert.AreEqual(AFromInterface, AFromClass,
      'property ' + AName + ' of TRESTFactoryConnection is bound to a getter ' +
      'other than the one IRESTConnection declares for it');
  end;

begin
  LObject := TRestFactoryConnectionDouble.Create(nil);
  LInterface := LObject;
  try
    Check('BaseURL', LInterface.BaseURL, LObject.BaseURL);
    Check('FullURL', LInterface.FullURL, LObject.FullURL);
    Check('Username', LInterface.Username, LObject.Username);
    Check('Password', LInterface.Password, LObject.Password);
    Check('MethodGET', LInterface.MethodGET, LObject.MethodGET);
    Check('MethodGETId', LInterface.MethodGETId, LObject.MethodGETId);
    Check('MethodGETWhere', LInterface.MethodGETWhere, LObject.MethodGETWhere);
    Check('MethodPOST', LInterface.MethodPOST, LObject.MethodPOST);
    Check('MethodPUT', LInterface.MethodPUT, LObject.MethodPUT);
    Check('MethodDELETE', LInterface.MethodDELETE, LObject.MethodDELETE);
    Check('MethodGETNextPacket', LInterface.MethodGETNextPacket,
                                 LObject.MethodGETNextPacket);
    Check('MethodGETNextPacketWhere', LInterface.MethodGETNextPacketWhere,
                                      LObject.MethodGETNextPacketWhere);
    Check('MethodToken', LInterface.MethodToken, LObject.MethodToken);
    Assert.AreEqual(LInterface.ServerUse, LObject.ServerUse,
      'property ServerUse of TRESTFactoryConnection is bound to a getter ' +
      'other than the one IRESTConnection declares for it');
  finally
    LInterface := nil;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRestFactoryMethodToken);

end.
