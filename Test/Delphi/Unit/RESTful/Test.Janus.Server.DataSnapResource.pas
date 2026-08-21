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

{ @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @abstract(Website : http://www.Janus.com.br)
  @abstract(Telagram : https://t.me/Janus)
}

{ THE DataSnap SERVER SIDE - issue #341, Level 2.

  ISSUE #338 IS ARGUED AGAINST A UNIT NOTHING COMPILED. The note above
  TRESTClientDataSnap.DoPOST explains why an INSERT must travel as HTTP PUT:
  DataSnap dispatches by METHOD NAME PREFIX (Studio 37.0,
  Datasnap.DSService.pas, TDSRESTService.SetMethodNameWithPrefix) mapping
  'PUT' -> 'accept', 'POST' -> 'update', 'DELETE' -> 'cancel', and it names
  "acceptapp, which is the method that inserts - see
  Janus.Server.Resource.DataSnap". The compile-coverage census then measured
  that unit at 0 of 7 test projects. The whole crossed-verb argument rested on
  a method table no compiler in this repository had ever read.

  So the clauses here are about the SHAPE THE PREFIX TABLE NEEDS:

    - the four method names really are app / acceptapp / updateapp / cancelapp,
      i.e. the base name 'app' under exactly the prefixes DataSnap prepends.
      Rename any one and the client's verb still leaves, DataSnap still
      dispatches, and the call lands on nothing.
    - the METHODINFO directive is still ON. Without it the methods carry no
      invocation RTTI, TDSClass exposes an empty surface, and every request
      404s - with no compiler diagnostic anywhere.
    - the two body-carrying operations are exactly acceptapp and updateapp -
      the two the crossed verbs reach. That is #338's premise stated as arity.

  And the class-var handoff between the two units: the resource reads its
  connection back out of TRESTServerDataSnap by class method, which is the only
  thing joining a component dropped on a form to a resource DataSnap
  instantiates on its own. }

unit Test.Janus.Server.DataSnapResource;

interface

uses
  Classes,
  SysUtils,
  Rtti,
  TypInfo,
  DUnitX.TestFramework,
  DataEngine.FactoryInterfaces,
  // The two units under test
  Janus.Server.DataSnap,
  Janus.Server.Resource.DataSnap;

type
  /// The resource class is literally named `Janus`, which collides with every
  /// unit prefix in this repository. The alias keeps the clauses readable and
  /// is how Janus.Server.DataSnap.AddResource has to spell it too.
  TDataSnapResource = Janus.Server.Resource.DataSnap.Janus;

  [TestFixture]
  TTestJanusServerDataSnapResource = class
  private
    /// The base name every DataSnap prefix is prepended to.
    const CBaseOperation = 'app';
  private
    function MethodOf(const AName: String): TRttiMethod;
    function ParameterCountOf(const AName: String): Integer;
  public
    [Test]
    procedure Names_TheFourPrefixedOperationsExist;
    [Test]
    procedure Names_NoOperationIsMissingItsPrefix;
    [Test]
    procedure MethodInfo_TheOperationsCarryInvocationRtti;
    [Test]
    procedure Arity_OnlyTheTwoWriteOperationsTakeABody;
    [Test]
    procedure Shape_EveryOperationAnswersJson;
    [Test]
    procedure Server_ConnectionReachesTheResourceThroughTheClassVar;
    [Test]
    procedure Server_PublishesTheDSServerPropertyForDesignTime;
  end;

implementation

uses
  JSON,
  /// TFakeConnection: the existing IDBConnection double, reused rather than
  /// duplicated.
  Test.Janus.DML.Generator.SQLite;

{ TTestJanusServerDataSnapResource }

function TTestJanusServerDataSnapResource.MethodOf(
  const AName: String): TRttiMethod;
var
  LContext: TRttiContext;
begin
  LContext := TRttiContext.Create;
  try
    Result := LContext.GetType(TDataSnapResource).GetMethod(AName);
  finally
    LContext.Free;
  end;
end;

function TTestJanusServerDataSnapResource.ParameterCountOf(
  const AName: String): Integer;
var
  LMethod: TRttiMethod;
begin
  LMethod := MethodOf(AName);
  Assert.IsNotNull(LMethod, 'No such operation: ' + AName);
  Result := Length(LMethod.GetParameters);
end;

{ DataSnap builds the dispatched name as prefix + method name. These four are
  the whole public surface of the Janus DataSnap server. }
procedure TTestJanusServerDataSnapResource.Names_TheFourPrefixedOperationsExist;
begin
  Assert.IsNotNull(MethodOf(CBaseOperation),
    'GET dispatches with NO prefix, straight to "app"');
  Assert.IsNotNull(MethodOf('accept' + CBaseOperation),
    'HTTP PUT dispatches to "accept" + app - the INSERT, per issue #338');
  Assert.IsNotNull(MethodOf('update' + CBaseOperation),
    'HTTP POST dispatches to "update" + app - the UPDATE, per issue #338');
  Assert.IsNotNull(MethodOf('cancel' + CBaseOperation),
    'HTTP DELETE dispatches to "cancel" + app');
end;

{ PERTINENCE TRIPWIRE for the clause above: it only means something if the
  reader can also answer NO. Positive control - a prefix DataSnap does not use,
  and a base name this resource does not have. }
procedure TTestJanusServerDataSnapResource.Names_NoOperationIsMissingItsPrefix;
begin
  Assert.IsNull(MethodOf('patch' + CBaseOperation),
    'Positive control: "patchapp" is not a name DataSnap builds and must not ' +
    'resolve - if the reader answered non-nil here it would answer non-nil ' +
    'for anything and the four clauses above would measure nothing');
  Assert.IsNull(MethodOf('accept'),
    'Positive control: the prefix alone is not an operation');
end;

{ The METHODINFO directive is what puts these methods in the invocation RTTI
  DataSnap reads. Turn it off and the class still compiles, still mounts, and answers
  nothing. }
procedure TTestJanusServerDataSnapResource.MethodInfo_TheOperationsCarryInvocationRtti;
begin
  Assert.IsNotNull(TDataSnapResource.MethodAddress('accept' + CBaseOperation),
    'acceptapp must be reachable by NAME at runtime - that is what ' +
    'the METHODINFO directive buys and what DataSnap''s dispatcher uses. A nil ' +
    'here ' +
    'means every PUT to this server 404s with nothing to diagnose');
  Assert.IsNotNull(TDataSnapResource.MethodAddress('update' + CBaseOperation),
    'updateapp must be reachable by name');
  Assert.IsNotNull(TDataSnapResource.MethodAddress(CBaseOperation),
    'app must be reachable by name');
  Assert.IsNotNull(TDataSnapResource.MethodAddress('cancel' + CBaseOperation),
    'cancelapp must be reachable by name');
end;

{ #338's PREMISE AS ARITY. The crossed verbs exist because the two operations
  that CARRY A BODY are the ones behind 'accept' and 'update'. If the body
  moved to a third operation - or if one of these two lost it - the crossing
  would be arguing about a shape that no longer exists. }
procedure TTestJanusServerDataSnapResource.Arity_OnlyTheTwoWriteOperationsTakeABody;
begin
  Assert.AreEqual(2, ParameterCountOf('accept' + CBaseOperation),
    'acceptapp(resource, value) - the INSERT, reached by HTTP PUT');
  Assert.AreEqual(2, ParameterCountOf('update' + CBaseOperation),
    'updateapp(resource, value) - the UPDATE, reached by HTTP POST');
  Assert.AreEqual(1, ParameterCountOf(CBaseOperation),
    'app(resource) carries no body: a GET has none');
  Assert.AreEqual(1, ParameterCountOf('cancel' + CBaseOperation),
    'cancelapp(resource) carries no body: the filter travels in the query');
end;

procedure TTestJanusServerDataSnapResource.Shape_EveryOperationAnswersJson;
var
  LName: String;
begin
  for LName in TArray<String>.Create(CBaseOperation, 'accept' + CBaseOperation,
                                     'update' + CBaseOperation,
                                     'cancel' + CBaseOperation) do
    Assert.AreEqual('TJSONValue', MethodOf(LName).ReturnType.Name,
      Format('%s must answer a TJSONValue - DataSnap marshals the result by ' +
             'its declared type, and a String return would reach the client ' +
             'double-encoded', [LName]));
end;

{ THE HANDOFF BETWEEN THE TWO UNITS. DataSnap instantiates the resource itself,
  so it can hand it nothing; the resource constructor reads the connection back
  out of the component through a CLASS var. Empty TRESTServerDataSnap.
  SetConnection and every request on a working server dies on a nil connection,
  with no compiler and no other test noticing. }
procedure TTestJanusServerDataSnapResource.Server_ConnectionReachesTheResourceThroughTheClassVar;
var
  LSaved: IDBConnection;
  LProbe: IDBConnection;
  LServer: TRESTServerDataSnap;
begin
  LSaved := TRESTServerDataSnap.GetConnection;
  LProbe := TFakeConnection.Create(dnSQLite);
  LServer := TRESTServerDataSnap.Create(nil);
  try
    LServer.Connection := LProbe;

    Assert.IsNotNull(TRESTServerDataSnap.GetConnection,
      'A connection assigned to the component must be visible to the class ' +
      'method the resource reads it back with - they are joined by nothing else');
    Assert.AreSame(LProbe as TObject, TRESTServerDataSnap.GetConnection as TObject,
      'and it must be the SAME connection, not merely some connection');
  finally
    // The class var outlives every instance; leaving a test double in it would
    // poison whatever runs next.
    LServer.Connection := LSaved;
    LServer.Free;
  end;
end;

procedure TTestJanusServerDataSnapResource.Server_PublishesTheDSServerPropertyForDesignTime;
var
  LContext: TRttiContext;
  LProperty: TRttiProperty;
begin
  LContext := TRttiContext.Create;
  try
    LProperty := LContext.GetType(TRESTServerDataSnap).GetProperty('DSServer');

    Assert.IsNotNull(LProperty,
      'TRESTServerDataSnap exposes DSServer; assigning it is what calls ' +
      'AddResource and mounts the resource class on the server');
    Assert.AreEqual(mvPublished, LProperty.Visibility,
      'DSServer must be PUBLISHED: the component is dropped on a form and the ' +
      'value is streamed from the .dfm by name. A merely public property is ' +
      'silently not persisted, and the server comes up with no resource');
  finally
    LContext.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestJanusServerDataSnapResource);

end.
