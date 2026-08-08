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

{ @abstract(Janus Framework - the MARS server resource, under a compiler.)

  WHAT IS UNDER TEST

  Two units that no test project in this repository referenced, and that no
  .dproj under Test\Delphi ever turned into a .dcu:

    Janus.Server.Resource.MARS   TAppResource - the MARS resource class, its
                                 attribute contract, and its initialization
                                 section
    Janus.Server.MARS            TRESTServerMARS.MARSEngine - the setter that
                                 publishes the resource into every application
                                 the engine owns

  WHY A UNIT NOBODY COMPILES IS WORSE THAN A UNIT NOBODY TESTS

  These two shipped for months while naming an identifier that a rename had
  already deleted, and while calling TMARSEngine.Applications after MARS had
  commented that property out. Neither is a subtle logic slip: both are plain
  E2003, the kind any compiler catches in a second. They survived only because
  no compiler was ever pointed at them. A green suite that never touches a unit
  says nothing about it; the first job of this fixture is simply to EXIST in a
  project that compiles the unit.

  WHY THE ASSERTIONS ARE NOT DECORATIVE

  Compiling is the floor, not the ceiling. MARS does not call TAppResource
  through an interface or a base class - it finds it by STRING, in a global
  registry, and it derives every route from ATTRIBUTES via RTTI. That makes the
  whole contract invisible to the compiler:

    - Janus.Server.MARS hard-codes 'Janus.Server.Resource.MARS.TAppResource'.
      MARS keys its registry on QualifiedClassName.ToLower. Rename the unit or
      the class and this string silently stops matching - the build stays
      green, and every Janus route answers 404. Registry_* and
      Application_AcceptsTheNameJanusHardCodes pin that string down.

    - MARS builds endpoints from PathAttribute / GETAttribute / ... . Drop one
      attribute and the verb quietly disappears from the API. Endpoints_* walks
      the endpoint table MARS itself derives and asserts the full verb set.

    - The five OData query parameters are matched by their literal names
      ('$filter', '$orderby', '$top', '$skip', '$count'). A typo in any of them
      compiles perfectly and produces an endpoint that ignores the option.
      Select_* asserts each name.

  Nothing here opens a socket, and nothing here needs a database. The two
  behavioural tests deliberately drive the resource with a resource name that
  is not in the mapping repository, so the call returns through the documented
  error contract before any connection is touched.

  NOT FIXED HERE - two defects this fixture uncovered on its first two runs

  Both live in Janus.Server.RestQuery.Parse, the query parser that Horse, DMVC,
  DataSnap and WiRL route through exactly as MARS does. Neither is a MARS
  defect and neither is this project's to repair; they are recorded because the
  only reason nobody had met them is that nobody had ever run this code.

  1. An empty resource name is a range check error, not a rejection.

     ParseResourceNameAndID does
         repeat Inc(LFor); LChar := AValue[LFor]; ... until (LFor >= LLength)

     A `repeat` runs its body before it tests its condition, so on an empty
     argument it reads AValue[1] of a zero-length string. These test projects
     build with range checking ON, so it surfaces as a range check error. With
     range checking OFF - which is what Release does - it reads out of bounds
     instead, silently. That is why the tests below drive the resource with
     '/', a URI the parser consumes safely, and never with ''.

  2. The `else raise` in select and delete is dead code.

     Both methods are written as
         if LQuery.ResourceName <> '' then ... else raise Exception...

     but GetResourceName returns 'T' + FResourceName, so ResourceName is never
     empty and the else can never run. The same shape appears in the DMVC and
     WiRL resource units. Select_TheEmptyResourceGuard_IsUnreachable pins that
     premise, so the branch cannot be mistaken for covered code, and it says so
     out loud if the premise ever flips.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Server.Resource.MARS;

interface

uses
  Classes,
  SysUtils,
  Rtti,
  Generics.Collections,
  DUnitX.TestFramework,
  // MARS
  MARS.Core.Engine,
  MARS.Core.Registry,
  MARS.Core.Registry.Utils,
  MARS.Core.Attributes,
  MARS.Core.MediaType,
  MARS.Core.Engine.Interfaces,
  MARS.Core.Application.Interfaces,
  // Janus - the units this project exists to compile
  Janus.Server.RestQuery.Parse,
  Janus.Server.MARS,
  Janus.Server.Resource.MARS;

type
  [TestFixture]
  TTestServerResourceMARS = class
  private
    /// <summary> The exact literal Janus.Server.MARS.AddResource passes to
    ///  IMARSApplication.AddResource. Every test that pins the name down must
    ///  read it from here, so a rename cannot be papered over in one place
    ///  and left broken in the other. </summary>
    const cJANUS_RESOURCE_NAME = 'Janus.Server.Resource.MARS.TAppResource';
    const cJANUS_RESOURCE_PATH = '/Janus';
    /// The same path without the leading separator MARS strips when it builds
    /// an endpoint path out of the class-level and method-level attributes.
    const cJANUS_SEGMENT = 'Janus';
  private
    FContext: TRttiContext;
    function ResourceType: TRttiType;
    function MethodOf(const AName: string): TRttiMethod;
    function MethodHasAttribute(const AMethodName: string;
      const AAttributeClass: TCustomAttributeClass): Boolean;
    function MethodProduces(const AMethodName, AMediaType: string): Boolean;
    function MethodQueryParamNames(const AMethodName: string): TArray<string>;
    function Contains(const AValues: TArray<string>; const AValue: string): Boolean;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// The initialization section of Janus.Server.Resource.MARS must have run
    /// and registered the class. If the unit is dropped from a project, or the
    /// registration is deleted, this is the first thing to go red.
    [Test]
    procedure Registry_HasRegisteredTheResource;

    /// MARS keys the registry on QualifiedClassName.ToLower. Janus looks the
    /// resource up by a hard-coded string. This asserts the two agree.
    [Test]
    procedure Registry_KeyIsTheNameJanusHardCodes;

    /// The registry entry must carry the resource Path MARS mounts it under.
    /// Without a PathAttribute the class registers but can never be added to
    /// an application.
    [Test]
    procedure Registry_EntryCarriesTheJanusPath;

    /// The end of the string lookup: a real MARS application must accept the
    /// literal Janus passes. Returns False - not an exception - when the name
    /// does not resolve, which is exactly why a rename is silent in production.
    [Test]
    procedure Application_AcceptsTheNameJanusHardCodes;

    /// A name that is deliberately wrong must be REFUSED. Without this, the
    /// test above could pass against an AddResource that accepts anything.
    [Test]
    procedure Application_RefusesAnUnknownName;

    /// TRESTServerMARS.MARSEngine is the only wiring Janus offers: assigning
    /// the engine must publish the resource into every application it owns.
    /// This is the loop that called the removed TMARSEngine.Applications.
    [Test]
    procedure ServerWiring_PublishesResourceIntoEveryApplication;

    /// The engine setter must survive an engine that owns no application at
    /// all, which is the state right after TMARSEngine.Create.
    [Test]
    procedure ServerWiring_ToleratesAnEngineWithNoApplications;

    /// Walk the endpoint table MARS itself derives from the attributes and
    /// assert the four verbs are all there.
    [Test]
    procedure Endpoints_ExposeTheFourCrudVerbs;

    /// Every endpoint must hang off the Janus resource path.
    [Test]
    procedure Endpoints_AllHangOffTheJanusPath;

    /// The five OData options are matched by literal name. A typo compiles.
    [Test]
    procedure Select_DeclaresTheFiveODataQueryParams;

    /// delete filters by '$filter' and by nothing else.
    [Test]
    procedure Delete_DeclaresTheFilterQueryParam;

    /// insert and update take their payload from the request body.
    [Test]
    procedure InsertAndUpdate_TakeTheirPayloadFromTheBody;

    /// Every verb must offer the JSON representation; a REST resource that
    /// only produces text/plain is not usable by the Janus client.
    [Test]
    procedure EveryVerb_ProducesJson;

    /// Behaviour, not shape: driving select with a resource the mapping
    /// repository does not know must come back through the documented
    /// 'not registered' contract, without touching a connection.
    [Test]
    procedure Select_UnmappedResource_ReportsNotRegistered;

    /// Characterisation, not aspiration. Both select and delete guard with
    /// `if LQuery.ResourceName <> '' then ... else raise`, and that else can
    /// never run, because GetResourceName returns 'T' + the parsed name and is
    /// therefore never empty. This pins the premise so the dead branch cannot
    /// be mistaken for live cover. See NOT FIXED HERE in the unit header.
    [Test]
    procedure Select_TheEmptyResourceGuard_IsUnreachable;
  end;

implementation

const
  cUNKNOWN_RESOURCE_NAME = 'Janus.Server.Resource.MARS.TNoSuchResource';
  cUNMAPPED_ENTITY       = 'ThisEntityIsDeliberatelyNotMapped';
  /// A URI whose every character is consumed by the parser without producing
  /// a resource name. NOT '' - see the unit header.
  cRESOURCE_PARSING_TO_NOTHING = '/';

{ TTestServerResourceMARS }

procedure TTestServerResourceMARS.Setup;
begin
  FContext := TRttiContext.Create;
end;

procedure TTestServerResourceMARS.TearDown;
begin
  FContext.Free;
end;

function TTestServerResourceMARS.ResourceType: TRttiType;
begin
  Result := FContext.GetType(TAppResource);
  Assert.IsNotNull(Result, 'RTTI for TAppResource is not available.');
end;

function TTestServerResourceMARS.MethodOf(const AName: string): TRttiMethod;
begin
  Result := ResourceType.GetMethod(AName);
  Assert.IsNotNull(Result,
    Format('TAppResource no longer declares a method named "%s".', [AName]));
end;

function TTestServerResourceMARS.MethodHasAttribute(const AMethodName: string;
  const AAttributeClass: TCustomAttributeClass): Boolean;
var
  LAttribute: TCustomAttribute;
begin
  Result := False;
  for LAttribute in MethodOf(AMethodName).GetAttributes do
    if LAttribute is AAttributeClass then
      Exit(True);
end;

function TTestServerResourceMARS.MethodProduces(const AMethodName,
  AMediaType: string): Boolean;
var
  LAttribute: TCustomAttribute;
begin
  Result := False;
  for LAttribute in MethodOf(AMethodName).GetAttributes do
    if (LAttribute is ProducesAttribute) and
       SameText(ProducesAttribute(LAttribute).Value, AMediaType) then
      Exit(True);
end;

function TTestServerResourceMARS.MethodQueryParamNames(
  const AMethodName: string): TArray<string>;
var
  LParameter: TRttiParameter;
  LAttribute: TCustomAttribute;
begin
  Result := [];
  for LParameter in MethodOf(AMethodName).GetParameters do
    for LAttribute in LParameter.GetAttributes do
      if LAttribute is QueryParamAttribute then
        Result := Result + [QueryParamAttribute(LAttribute).Name];
end;

function TTestServerResourceMARS.Contains(const AValues: TArray<string>;
  const AValue: string): Boolean;
var
  LValue: string;
begin
  Result := False;
  for LValue in AValues do
    if SameText(LValue, AValue) then
      Exit(True);
end;

procedure TTestServerResourceMARS.Registry_HasRegisteredTheResource;
var
  LClass: TClass;
begin
  Assert.IsTrue(
    TMARSResourceRegistry.Instance.GetResourceClass(
      LowerCase(cJANUS_RESOURCE_NAME), LClass),
    'Janus.Server.Resource.MARS did not register TAppResource. Either the ' +
    'unit was dropped from the project or its initialization section is gone.');
  Assert.AreEqual(TClass(TAppResource), LClass,
    'The registry resolved the Janus resource name to a different class.');
end;

procedure TTestServerResourceMARS.Registry_KeyIsTheNameJanusHardCodes;
begin
  Assert.AreEqual(LowerCase(cJANUS_RESOURCE_NAME),
    LowerCase(TAppResource.QualifiedClassName),
    'The qualified name of TAppResource drifted away from the literal ' +
    'Janus.Server.MARS.AddResource passes to IMARSApplication.AddResource. ' +
    'The build stays green and every Janus route stops resolving.');
end;

procedure TTestServerResourceMARS.Registry_EntryCarriesTheJanusPath;
var
  LInfo: TMARSConstructorInfo;
begin
  Assert.IsTrue(
    TMARSResourceRegistry.Instance.TryGetValue(
      LowerCase(cJANUS_RESOURCE_NAME), LInfo),
    'The Janus resource is not in the MARS registry.');
  Assert.AreEqual(cJANUS_RESOURCE_PATH, LInfo.Path,
    'TAppResource lost the PathAttribute that mounts it. A resource with no ' +
    'path registers, but no application will ever accept it.');
end;

procedure TTestServerResourceMARS.Application_AcceptsTheNameJanusHardCodes;
var
  LEngine: IMARSEngine;
  LApplication: IMARSApplication;
begin
  LEngine := TMARSEngine.Create('TestEngineAccepts');
  LApplication := LEngine.AddApplication('DefaultApp', '/rest', []);
  Assert.IsTrue(LApplication.AddResource(cJANUS_RESOURCE_NAME),
    'A MARS application refused the very name Janus.Server.MARS passes it. ' +
    'AddResource answers False - never an exception - so in production this ' +
    'is a silent 404 on every Janus route.');
  Assert.IsTrue(LApplication.Resources.ContainsKey(cJANUS_RESOURCE_PATH),
    'The resource was accepted but did not land under its Janus path.');
end;

procedure TTestServerResourceMARS.Application_RefusesAnUnknownName;
var
  LEngine: IMARSEngine;
  LApplication: IMARSApplication;
begin
  LEngine := TMARSEngine.Create('TestEngineRefuses');
  LApplication := LEngine.AddApplication('DefaultApp', '/rest', []);
  Assert.IsFalse(LApplication.AddResource(cUNKNOWN_RESOURCE_NAME),
    'AddResource accepted a name that was never registered, so the test that ' +
    'asserts it accepts the Janus name proves nothing.');
end;

procedure TTestServerResourceMARS.ServerWiring_PublishesResourceIntoEveryApplication;
var
  LEngine: IMARSEngine;
  LFirst: IMARSApplication;
  LSecond: IMARSApplication;
  LServer: TRESTServerMARS;
begin
  LEngine := TMARSEngine.Create('TestEngineWiring');
  LFirst := LEngine.AddApplication('FirstApp', '/first', []);
  LSecond := LEngine.AddApplication('SecondApp', '/second', []);

  Assert.IsFalse(LFirst.Resources.ContainsKey(cJANUS_RESOURCE_PATH),
    'Premise broken: the application already carried the Janus resource ' +
    'before the engine was handed to TRESTServerMARS.');

  LServer := TRESTServerMARS.Create(nil);
  try
    LServer.MARSEngine := LEngine as TMARSEngine;

    Assert.IsTrue(LFirst.Resources.ContainsKey(cJANUS_RESOURCE_PATH),
      'Assigning the engine did not publish the Janus resource into the ' +
      'first application.');
    Assert.IsTrue(LSecond.Resources.ContainsKey(cJANUS_RESOURCE_PATH),
      'The wiring stopped at the first application - EVERY application the ' +
      'engine owns must receive the resource.');
  finally
    LServer.Free;
  end;
end;

procedure TTestServerResourceMARS.ServerWiring_ToleratesAnEngineWithNoApplications;
var
  LEngine: IMARSEngine;
  LServer: TRESTServerMARS;
begin
  LEngine := TMARSEngine.Create('TestEngineEmpty');
  LServer := TRESTServerMARS.Create(nil);
  try
    LServer.MARSEngine := LEngine as TMARSEngine;
    Assert.Pass('The engine setter survived an engine with no applications.');
  finally
    LServer.Free;
  end;
end;

procedure TTestServerResourceMARS.Endpoints_ExposeTheFourCrudVerbs;
var
  LEngine: IMARSEngine;
  LApplication: IMARSApplication;
  LVerbs: TArray<string>;
begin
  LEngine := TMARSEngine.Create('TestEngineVerbs');
  LApplication := LEngine.AddApplication('DefaultApp', '/rest', []);
  Assert.IsTrue(LApplication.AddResource(cJANUS_RESOURCE_NAME),
    'The Janus resource could not be added, so no endpoint can be inspected.');

  LVerbs := [];
  LApplication.EnumerateEndpoints(
    procedure (AName: string; AInfo: TMARSConstructorInfo;
      AMethodPath: string; AHttpMethod: string)
    begin
      LVerbs := LVerbs + [AHttpMethod];
    end);

  Assert.AreEqual(4, Length(LVerbs),
    'MARS derived a different number of endpoints from TAppResource than the ' +
    'four CRUD verbs the resource is supposed to publish.');
  Assert.IsTrue(Contains(LVerbs, 'GET'), 'The GET endpoint is gone.');
  Assert.IsTrue(Contains(LVerbs, 'POST'), 'The POST endpoint is gone.');
  Assert.IsTrue(Contains(LVerbs, 'PUT'), 'The PUT endpoint is gone.');
  Assert.IsTrue(Contains(LVerbs, 'DELETE'), 'The DELETE endpoint is gone.');
end;

procedure TTestServerResourceMARS.Endpoints_AllHangOffTheJanusPath;
var
  LEngine: IMARSEngine;
  LApplication: IMARSApplication;
  LStray: string;
  LSeen: Integer;
begin
  LEngine := TMARSEngine.Create('TestEnginePaths');
  LApplication := LEngine.AddApplication('DefaultApp', '/rest', []);
  Assert.IsTrue(LApplication.AddResource(cJANUS_RESOURCE_NAME),
    'The Janus resource could not be added, so no endpoint can be inspected.');

  LStray := '';
  LSeen := 0;
  LApplication.EnumerateEndpoints(
    procedure (AName: string; AInfo: TMARSConstructorInfo;
      AMethodPath: string; AHttpMethod: string)
    var
      LPath: string;
    begin
      Inc(LSeen);
      /// MARS normalises the combined path: it drops the leading separator and
      /// the trailing '?' of the method-level Path. Compare on the normalised
      /// form so this asserts the Janus contract and not MARS's punctuation.
      LPath := AMethodPath;
      while LPath.StartsWith('/') do
        LPath := LPath.Substring(1);
      if not LPath.StartsWith(cJANUS_SEGMENT + '/', True) then
        LStray := AHttpMethod + ' ' + AMethodPath;
      if Pos('{resource}', LPath) = 0 then
        LStray := AHttpMethod + ' ' + AMethodPath;
    end);

  Assert.IsTrue(LSeen > 0, 'No endpoint was enumerated at all.');
  Assert.AreEqual('', LStray,
    'An endpoint no longer sits under the Janus path with a {resource} ' +
    'segment: ' + LStray);
end;

procedure TTestServerResourceMARS.Select_DeclaresTheFiveODataQueryParams;
var
  LNames: TArray<string>;
begin
  Assert.IsTrue(MethodHasAttribute('select', GETAttribute),
    'select is no longer a GET endpoint.');

  LNames := MethodQueryParamNames('select');
  Assert.AreEqual(5, Length(LNames),
    'select declares a different number of query parameters than the five ' +
    'OData options.');
  Assert.IsTrue(Contains(LNames, '$filter'), 'select lost the $filter option.');
  Assert.IsTrue(Contains(LNames, '$orderby'), 'select lost the $orderby option.');
  Assert.IsTrue(Contains(LNames, '$top'), 'select lost the $top option.');
  Assert.IsTrue(Contains(LNames, '$skip'), 'select lost the $skip option.');
  Assert.IsTrue(Contains(LNames, '$count'), 'select lost the $count option.');
end;

procedure TTestServerResourceMARS.Delete_DeclaresTheFilterQueryParam;
var
  LNames: TArray<string>;
begin
  Assert.IsTrue(MethodHasAttribute('delete', DELETEAttribute),
    'delete is no longer a DELETE endpoint.');

  LNames := MethodQueryParamNames('delete');
  Assert.AreEqual(1, Length(LNames),
    'delete declares a different number of query parameters than the single ' +
    '$filter it selects rows with.');
  Assert.IsTrue(Contains(LNames, '$filter'), 'delete lost the $filter option.');
end;

procedure TTestServerResourceMARS.InsertAndUpdate_TakeTheirPayloadFromTheBody;
var
  LMethodName: string;
  LParameter: TRttiParameter;
  LAttribute: TCustomAttribute;
  LFound: Boolean;
begin
  Assert.IsTrue(MethodHasAttribute('insert', POSTAttribute),
    'insert is no longer a POST endpoint.');
  Assert.IsTrue(MethodHasAttribute('update', PUTAttribute),
    'update is no longer a PUT endpoint.');

  for LMethodName in TArray<string>.Create('insert', 'update') do
  begin
    LFound := False;
    for LParameter in MethodOf(LMethodName).GetParameters do
      for LAttribute in LParameter.GetAttributes do
        if LAttribute is BodyParamAttribute then
          LFound := True;
    Assert.IsTrue(LFound,
      Format('%s no longer reads its payload from the request body.',
        [LMethodName]));
  end;
end;

procedure TTestServerResourceMARS.EveryVerb_ProducesJson;
var
  LMethodName: string;
begin
  for LMethodName in TArray<string>.Create('select', 'insert', 'update', 'delete') do
    Assert.IsTrue(MethodProduces(LMethodName, TMediaType.APPLICATION_JSON),
      Format('%s no longer produces %s, so the Janus client cannot read it.',
        [LMethodName, TMediaType.APPLICATION_JSON]));
end;

procedure TTestServerResourceMARS.Select_UnmappedResource_ReportsNotRegistered;
var
  LResource: TAppResource;
  LMessage: string;
begin
  LResource := TAppResource.Create;
  try
    LMessage := '';
    try
      LResource.select(cUNMAPPED_ENTITY, '', '', '', '', '').Free;
    except
      on E: Exception do
        LMessage := E.Message;
    end;
    Assert.IsTrue(Pos('not registered on the server', LMessage) > 0,
      'select on an unmapped resource did not come back through the ' +
      'documented "not registered" contract. Got: ' + LMessage);
    Assert.IsTrue(Pos(cUNMAPPED_ENTITY, LMessage) > 0,
      'The error does not name the resource that was asked for. Got: ' +
      LMessage);
  finally
    LResource.Free;
  end;
end;

procedure TTestServerResourceMARS.Select_TheEmptyResourceGuard_IsUnreachable;
var
  LQuery: TRESTQueryParse;
  LResource: TAppResource;
  LMessage: string;
begin
  /// The premise: a URI that carries no resource name at all still yields a
  /// non-empty ResourceName, because the getter prefixes 'T'.
  LQuery := TRESTQueryParse.Create;
  try
    LQuery.ParseQuery(cRESOURCE_PARSING_TO_NOTHING);
    Assert.AreNotEqual('', LQuery.ResourceName,
      'TRESTQueryParse.ResourceName came back empty. The `else raise` branch ' +
      'in TAppResource.select and TAppResource.delete just became reachable ' +
      'for the first time - go read it, it has never run.');
  finally
    LQuery.Free;
  end;

  /// The consequence: select cannot take the guard, so it always walks on to
  /// the mapping repository and fails there instead.
  LResource := TAppResource.Create;
  try
    LMessage := '';
    try
      LResource.select(cRESOURCE_PARSING_TO_NOTHING, '', '', '', '', '').Free;
    except
      on E: Exception do
        LMessage := E.Message;
    end;
    Assert.IsTrue(Pos('not registered on the server', LMessage) > 0,
      'select on a resource-less URI no longer reports through the mapping ' +
      'repository. Got: ' + LMessage);
  finally
    LResource.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestServerResourceMARS);

end.
