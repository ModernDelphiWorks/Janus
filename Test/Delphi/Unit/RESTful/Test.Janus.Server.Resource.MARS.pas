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
      ('$filter', '$orderby', '$top', '$skip', '$count') AND each name must
      stay on the parameter that carries it. A typo compiles; so does trading
      $top and $skip between the `top` and `skip` parameters, and that trade
      survives any assertion phrased as "all five names are present" - the set
      is unchanged. MARS would then inject the caller's skip into top and the
      caller's top into skip, inverting pagination in production against a
      green suite. Select_BindsEachODataOptionToItsOwnParameter asserts the
      whole binding table in declaration order, which is what catches it.

  SHAPE IS ONLY HALF OF IT

  Everything described above inspects declarations. No declaration can tell you
  whether an option the caller supplied actually REACHES the query that gets
  built: delete `LQuery.SetFilter(filter)` from select and every attribute is
  still exactly where it was. TTestServerResourceMARSOverARealQuery closes that
  half by running the resource against a real SQLite file - the same DataEngine
  factory the green RESTHorse suite uses - with a real table and real rows.
  Still no socket: MARS is the routing layer, and those tests call the resource
  method directly.

  NOT COVERED HERE - $count, and exactly why

  Four of the five OData options are asserted end to end. $count is not, and it
  cannot be through this resource. The plumbing stops short:

    TRESTQueryParse.SetCount stores the flag; ResolverFindAll and its siblings
    read AQuery.Count and write TAppResourceBase.FResultCount; the value is
    then only reachable through TAppResourceBase.ResultCount.

    Janus.Server.Horse.pas:107-109 reads exactly that and emits a ResultCount
    HTTP header.

    Janus.Server.Resource.MARS has no equivalent. TAppResource keeps its
    TAppResourceBase in a PRIVATE field with no accessor, and select returns
    only the TJSONValue. The count is computed and discarded.

  So on the MARS driver $count is declared on the endpoint and inert in the
  response - measured, not assumed: deleting LQuery.SetCount(count) from
  select changes nothing any caller can see, and the whole suite stays green.
  Closing it means giving the MARS adapter a way to surface the count, which is
  a product decision about the response contract, not a test change. It is left
  alone and pinned by
  Select_TheCountOption_ChangesNothingTheAdapterReturns, which will go red the
  day someone closes it.

  KNOWN DEBT, NOT AN OVERSIGHT

  TRESTServerMARS.AddResource reads the engine's applications through
  GetApplications, which hands back the raw dictionary. The idiomatic successor
  in current MARS is EnumerateApplications, which takes the engine's critical
  section for the duration of the walk. GetApplications takes no lock. This is
  not a regression - the code it replaced did not lock either, and the setter
  runs at wiring time - but it is a deliberate choice recorded here rather than
  an accident.

  NOT FIXED HERE - two defects this fixture uncovered on its first two runs

  Both live in Janus.Server.RestQuery.Parse, the query parser that Horse, DMVC,
  DataSnap and WiRL route through exactly as MARS does. Neither is a MARS
  defect and neither is this project's to repair; they are recorded because the
  only reason nobody had met them is that nobody had ever run this code.

  1. An empty resource name crashes the parser instead of being rejected.

     ParseResourceNameAndID does
         repeat Inc(LFor); LChar := AValue[LFor]; ... until (LFor >= LLength)

     A `repeat` runs its body before it tests its condition, so on an empty
     argument it reads AValue[1] of a zero-length string. Measured on both
     builds with a standalone probe of that exact loop:

         range checks ON   ERangeError      'Range check error'
         range checks OFF  EAccessViolation 'Read of address 00000000'

     So it is NOT a debug-only nicety and NOT a silent out-of-bounds read in
     Release: an empty Delphi string is a nil pointer, and dereferencing it is
     a hard AV either way. The difference between the two builds is only which
     exception class arrives. That is why the tests below drive the resource
     with '/', a URI the parser consumes safely, and never with ''.

  2. The `else raise` in select and delete is dead code.

     Both methods are written as
         if LQuery.ResourceName <> '' then ... else raise Exception...

     but ResourceName is never empty, so the else can never run. The
     MECHANISM behind that changed with issue #364 and the CONCLUSION did
     not: the getter used to answer 'T' + FResourceName unconditionally, and
     now it RESOLVES the segment against the mapping registry - ClassName
     first, [Table] name second - and falls back to 'T' + the segment when
     nothing claims it. All three of those answers are non-empty, including
     for the empty segment, where the answer is the single character 'T'.
     The one new way out of the getter is an EXCEPTION, raised when two
     registered entities claim the segment by [Table]; that leaves the guard
     just as unreachable, by not reaching it at all.

     The same shape appears in the DMVC and WiRL resource units.
     Select_TheEmptyResourceGuard_IsUnreachable pins that premise, so the
     branch cannot be mistaken for covered code, and it says so out loud if
     the premise ever flips.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Server.Resource.MARS;

interface

uses
  Classes,
  SysUtils,
  Rtti,
  JSON,
  IOUtils,
  Generics.Collections,
  DUnitX.TestFramework,
  // DataEngine - the headless SQLite connection the behavioural tests need
  DataEngine.FactoryInterfaces,
  DataEngine.FactoryConnection,
  DataEngine.FactoryFireDac,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Async,
  FireDAC.Phys.Intf,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  // Models, reused from the RESTHorse support tree
  MetaDbDiff.Mapping.Register,
  RestHorseTest.Models,
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
    function MethodQueryParamBindings(const AMethodName: string): string;
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

    /// The method-level Path attributes, verbatim. MARS normalises the
    /// combined endpoint path - it strips the leading separator and the
    /// trailing '?' - so the endpoint table CANNOT see the difference between
    /// '/{resource}?' and '/{resource}'. Only the raw attribute can, and that
    /// '?' is what makes the segment optional on select.
    [Test]
    procedure Methods_DeclareTheirPathsVerbatim;

    /// The five OData options are matched by literal name AND must each stay
    /// bound to the parameter that carries them. A typo compiles; so does a
    /// swap, and the swap is the one that survives a set-membership test.
    [Test]
    procedure Select_BindsEachODataOptionToItsOwnParameter;

    /// delete filters by '$filter', bound to `filter`, and by nothing else.
    [Test]
    procedure Delete_BindsFilterToItsOwnParameter;

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
    /// never run, because GetResourceName is never empty: since issue #364 it
    /// RESOLVES the segment against the mapping registry instead of decorating
    /// it, and every answer it can give - a registered ClassName, or the
    /// 'T' + segment fallback - has at least one character. This pins the
    /// premise so the dead branch cannot be mistaken for live cover. See NOT
    /// FIXED HERE in the unit header.
    [Test]
    procedure Select_TheEmptyResourceGuard_IsUnreachable;
  end;

  { Everything above inspects SHAPE - attributes, registry entries, endpoint
    tables. Shape cannot answer the other half of the threat model: whether an
    option the caller supplied actually REACHES the query that is built. Delete
    `LQuery.SetFilter(filter)` from TAppResource.select and every shape
    assertion still passes, because the attribute it is named after is still
    there.

    So this fixture runs the resource for real, against a real SQLite file
    through the same DataEngine factory the green RESTHorse suite uses, with a
    real table and real rows. No socket: MARS is only the routing layer, and
    these tests call the resource method directly. The models are reused from
    RESTHorse rather than duplicated. }
  [TestFixture]
  TTestServerResourceMARSOverARealQuery = class
  private
    FDConnection: TFDConnection;
    FConnection: IDBConnection;
    /// Drives TAppResource.select and returns the row set it produced.
    function SelectCustomers(const AFilter, AOrderBy, ATop,
      ASkip: string): TJSONArray;
    function NamesIn(const ARows: TJSONArray): string;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;
    [Setup]
    procedure Setup;

    /// The premise every test below rests on: with no option at all, the
    /// resource returns the whole seeded table. If this is not three rows,
    /// none of the filtering assertions mean anything.
    [Test]
    procedure Select_WithNoOption_ReturnsEveryRow;

    /// $filter must reach the query. This is the test that fails when the
    /// SetFilter call is deleted from select - the shape assertions cannot.
    [Test]
    procedure Select_TheFilterOptionReachesTheQuery;

    /// $top and $skip must reach the query as themselves. Deliberately
    /// asymmetric (top=1, skip=2), so swapping the two inside the method body
    /// changes both the row count and the row returned.
    [Test]
    procedure Select_TopAndSkipReachTheQueryUncrossed;

    /// $orderby must reach the query: the same rows in a decided order.
    [Test]
    procedure Select_TheOrderByOptionReachesTheQuery;

    /// The body of delete had no execution cover at all. $filter is the ONLY
    /// way a MARS caller can name the row to remove - the endpoint declares no
    /// id parameter - so when the filter does not reach the query, ParseDelete
    /// finds nothing by filter, falls through to its id branch and raises
    /// 'The delete method needs the ID parameter!'. The verb then fails loudly
    /// and completely. It does NOT quietly delete the wrong rows; this test
    /// asserts both halves - Bob goes, Alice and Carol stay.
    [Test]
    procedure Delete_TheFilterOptionReachesTheQuery;

    /// Characterisation of a DECLARED GAP, and it does not close it. $count is
    /// the one option this fixture cannot verify reaches the query, because
    /// the MARS adapter throws the answer away - see NOT COVERED HERE in the
    /// unit header. Deleting LQuery.SetCount(count) from select leaves this
    /// green, and every other test green too. It is here so the gap is a
    /// recorded fact with a tripwire on it, not an oversight.
    [Test]
    procedure Select_TheCountOption_ChangesNothingTheAdapterReturns;
  end;

implementation

const
  cUNKNOWN_RESOURCE_NAME = 'Janus.Server.Resource.MARS.TNoSuchResource';
  cUNMAPPED_ENTITY       = 'ThisEntityIsDeliberatelyNotMapped';
  /// A URI whose every character is consumed by the parser without producing
  /// a resource name. NOT '' - see the unit header.
  cRESOURCE_PARSING_TO_NOTHING = '/';
  /// TCustomerTest, addressed the way a caller addresses it over the wire.
  /// TRESTQueryParse.GetResourceName puts the 'T' back on.
  cSEEDED_RESOURCE = 'CustomerTest';
  cTEST_DB_PATH    = 'janus_rest_mars_test.db';

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

function TTestServerResourceMARS.MethodQueryParamBindings(
  const AMethodName: string): string;
var
  LParameter: TRttiParameter;
  LAttribute: TCustomAttribute;
  LPairs: TArray<string>;
begin
  /// Each entry is `<formal parameter name>-><query option name>`, in
  /// declaration order. The pairing is the point: asserting only the SET of
  /// option names cannot see two attributes swapped between two parameters,
  /// and that swap is silent in every other way.
  LPairs := [];
  for LParameter in MethodOf(AMethodName).GetParameters do
    for LAttribute in LParameter.GetAttributes do
      if LAttribute is QueryParamAttribute then
        LPairs := LPairs +
          [LParameter.Name + '->' + QueryParamAttribute(LAttribute).Name];
  Result := string.Join(', ', LPairs);
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

procedure TTestServerResourceMARS.Methods_DeclareTheirPathsVerbatim;

  function PathOf(const AMethodName: string): string;
  var
    LAttribute: TCustomAttribute;
  begin
    Result := '';
    for LAttribute in MethodOf(AMethodName).GetAttributes do
      if LAttribute is PathAttribute then
        Exit(PathAttribute(LAttribute).Value);
  end;

begin
  Assert.AreEqual(cJANUS_RESOURCE_PATH,
    PathAttribute(ResourceType.GetAttribute<PathAttribute>).Value,
    'The class-level Path of TAppResource changed.');

  /// select and delete accept the segment as OPTIONAL - that is the '?'.
  /// Dropping it makes the segment mandatory and quietly changes which URLs
  /// route, while every endpoint-table assertion keeps passing.
  Assert.AreEqual('/{resource}?', PathOf('select'),
    'select no longer accepts an optional {resource} segment.');
  Assert.AreEqual('/{resource}', PathOf('insert'),
    'The insert path changed.');
  Assert.AreEqual('/{resource}', PathOf('update'),
    'The update path changed.');
  Assert.AreEqual('/{resource}', PathOf('delete'),
    'The delete path changed.');
end;

procedure TTestServerResourceMARS.Select_BindsEachODataOptionToItsOwnParameter;
begin
  Assert.IsTrue(MethodHasAttribute('select', GETAttribute),
    'select is no longer a GET endpoint.');

  /// One assertion on the whole binding table, in declaration order. A set
  /// membership test cannot see $top and $skip traded between the `top` and
  /// `skip` parameters - it still finds five names, all spelled correctly -
  /// and MARS would then inject the caller's skip into top and vice versa,
  /// inverting pagination against a green suite.
  Assert.AreEqual(
    'filter->$filter, orderby->$orderby, top->$top, skip->$skip, count->$count',
    MethodQueryParamBindings('select'),
    'The query options of select are no longer bound one-to-one to the ' +
    'parameters that carry them. Two swapped attributes compile, keep the ' +
    'option names spelled right, and silently cross the values.');
end;

procedure TTestServerResourceMARS.Delete_BindsFilterToItsOwnParameter;
begin
  Assert.IsTrue(MethodHasAttribute('delete', DELETEAttribute),
    'delete is no longer a DELETE endpoint.');

  Assert.AreEqual('filter->$filter', MethodQueryParamBindings('delete'),
    'delete no longer selects rows by exactly one option, $filter, bound to ' +
    'its own parameter.');
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

{ TTestServerResourceMARSOverARealQuery }

procedure TTestServerResourceMARSOverARealQuery.SetupFixture;
var
  LServer: TRESTServerMARS;
begin
  FDConnection := TFDConnection.Create(nil);
  FDConnection.Params.DriverID := 'SQLite';
  FDConnection.Params.Database := cTEST_DB_PATH;
  FDConnection.Params.Values['OpenMode'] := 'CreateUTF8';
  FDConnection.ResourceOptions.SilentMode := True;
  FDConnection.Connected := True;
  FConnection := TFactoryFireDAC.Create(FDConnection, dnSQLite);

  /// TCustomerTest is registered in this unit's initialization, NOT here.
  /// TMappingExplorer.GetRepositoryMapping builds its repository ONCE, lazily,
  /// from whatever TRegisterClass holds at the moment of the first lookup, and
  /// caches it forever. The shape fixture above performs lookups, so by the
  /// time this SetupFixture runs the snapshot is already sealed and a
  /// registration here would never be seen.
  FConnection.ExecuteDirect('DROP TABLE IF EXISTS customer_test');
  FConnection.ExecuteDirect(
    'CREATE TABLE customer_test (' +
    '  id     INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  name   VARCHAR(100) NOT NULL,' +
    '  email  VARCHAR(200),' +
    '  active INTEGER DEFAULT 1)');

  /// TRESTServerMARS keeps the connection in a class var, so one assignment
  /// serves every TAppResource this fixture builds.
  LServer := TRESTServerMARS.Create(nil);
  try
    LServer.Connection := FConnection;
  finally
    LServer.Free;
  end;
end;

procedure TTestServerResourceMARSOverARealQuery.TearDownFixture;
begin
  if Assigned(FConnection) then
    FConnection.ExecuteDirect('DROP TABLE IF EXISTS customer_test');
  FConnection := nil;
  if Assigned(FDConnection) then
  begin
    FDConnection.Connected := False;
    FreeAndNil(FDConnection);
  end;
  if TFile.Exists(cTEST_DB_PATH) then
    TFile.Delete(cTEST_DB_PATH);
end;

procedure TTestServerResourceMARSOverARealQuery.Setup;
begin
  /// Three rows, distinct names, deliberately NOT inserted in name order, so
  /// an $orderby that never reaches the query cannot pass by accident.
  FConnection.ExecuteDirect('DELETE FROM customer_test');
  FConnection.ExecuteDirect(
    'INSERT INTO customer_test (id, name, active) VALUES (1, ''Carol'', 1)');
  FConnection.ExecuteDirect(
    'INSERT INTO customer_test (id, name, active) VALUES (2, ''Alice'', 1)');
  FConnection.ExecuteDirect(
    'INSERT INTO customer_test (id, name, active) VALUES (3, ''Bob'', 0)');
end;

function TTestServerResourceMARSOverARealQuery.SelectCustomers(const AFilter,
  AOrderBy, ATop, ASkip: string): TJSONArray;
var
  LResource: TAppResource;
  LValue: TJSONValue;
begin
  LResource := TAppResource.Create;
  try
    LValue := LResource.select(cSEEDED_RESOURCE, AFilter, AOrderBy, ATop,
      ASkip, '');
  finally
    LResource.Free;
  end;
  Assert.IsNotNull(LValue, 'select returned no JSON at all.');
  Assert.IsTrue(LValue is TJSONArray,
    'select no longer answers a JSON array for a row set. Got: ' +
    LValue.ToJSON);
  Result := TJSONArray(LValue);
end;

function TTestServerResourceMARSOverARealQuery.NamesIn(
  const ARows: TJSONArray): string;
var
  LIndex: Integer;
  LNames: TArray<string>;
begin
  LNames := [];
  for LIndex := 0 to ARows.Count - 1 do
    LNames := LNames + [ARows.Items[LIndex].GetValue<string>('Name', '?')];
  Result := string.Join(',', LNames);
end;

procedure TTestServerResourceMARSOverARealQuery.Select_WithNoOption_ReturnsEveryRow;
var
  LRows: TJSONArray;
begin
  LRows := SelectCustomers('', '', '', '');
  try
    Assert.AreEqual(3, LRows.Count,
      'The seeded table did not come back whole, so no filtering assertion ' +
      'in this fixture can be trusted. Got: ' + LRows.ToJSON);
  finally
    LRows.Free;
  end;
end;

procedure TTestServerResourceMARSOverARealQuery.Select_TheFilterOptionReachesTheQuery;
var
  LRows: TJSONArray;
begin
  LRows := SelectCustomers('name eq ''Bob''', '', '', '');
  try
    Assert.AreEqual(1, LRows.Count,
      'The $filter the caller supplied did not reach the query - all three ' +
      'seeded rows came back. Every attribute-shape assertion in this unit ' +
      'still passes when that happens; only this one does not. Got: ' +
      LRows.ToJSON);
    Assert.AreEqual('Bob', NamesIn(LRows),
      'The $filter reached the query but selected the wrong row.');
  finally
    LRows.Free;
  end;
end;

procedure TTestServerResourceMARSOverARealQuery.Select_TopAndSkipReachTheQueryUncrossed;
var
  LRows: TJSONArray;
begin
  /// Ordered by id: Carol(1), Alice(2), Bob(3). Skipping two and taking one
  /// leaves Bob. Crossing the two options takes two and skips one, which
  /// answers Alice AND Bob - a different count and a different row.
  LRows := SelectCustomers('', 'id', '1', '2');
  try
    Assert.AreEqual(1, LRows.Count,
      'The page size did not reach the query as $top. Got: ' + LRows.ToJSON);
    Assert.AreEqual('Bob', NamesIn(LRows),
      'The page landed on the wrong row: $top and $skip did not reach the ' +
      'query as themselves. Got: ' + LRows.ToJSON);
  finally
    LRows.Free;
  end;
end;

procedure TTestServerResourceMARSOverARealQuery.Select_TheOrderByOptionReachesTheQuery;
var
  LRows: TJSONArray;
begin
  /// Insertion order is Carol, Alice, Bob. Ordering by name is a different
  /// sequence, so an $orderby that never arrives cannot pass by luck.
  LRows := SelectCustomers('name ne ''''', 'name', '', '');
  try
    Assert.AreEqual(3, LRows.Count,
      'Expected the whole table back, ordered. Got: ' + LRows.ToJSON);
    Assert.AreEqual('Alice,Bob,Carol', NamesIn(LRows),
      'The $orderby the caller supplied did not reach the query - the rows ' +
      'came back in insertion order. Got: ' + LRows.ToJSON);
  finally
    LRows.Free;
  end;
end;

procedure TTestServerResourceMARSOverARealQuery.Delete_TheFilterOptionReachesTheQuery;
var
  LResource: TAppResource;
  LAnswer: TJSONValue;
  LReply: string;
  LFailure: string;
  LRemaining: TJSONArray;
begin
  LResource := TAppResource.Create;
  try
    LReply := '';
    LFailure := '';
    try
      LAnswer := LResource.delete(cSEEDED_RESOURCE, 'name eq ''Bob''');
      try
        LReply := LAnswer.ToJSON;
      finally
        LAnswer.Free;
      end;
    except
      on E: Exception do
        LFailure := E.Message;
    end;
  finally
    LResource.Free;
  end;

  Assert.AreEqual('', LFailure,
    'delete refused the request outright. $filter is the only way its ' +
    'endpoint can name a row - there is no id parameter - so a filter that ' +
    'never reaches the query leaves ParseDelete demanding an id. Got: ' +
    LFailure);
  Assert.IsTrue(Pos('successfully', LReply) > 0,
    'delete did not report success. Got: ' + LReply);

  LRemaining := SelectCustomers('name ne ''''', 'name', '', '');
  try
    Assert.AreEqual('Alice,Carol', NamesIn(LRemaining),
      'The row set after delete is wrong: the filtered row must be gone and ' +
      'the other two must survive. Got: ' + LRemaining.ToJSON);
  finally
    LRemaining.Free;
  end;
end;

procedure TTestServerResourceMARSOverARealQuery.Select_TheCountOption_ChangesNothingTheAdapterReturns;
var
  LWithout: string;
  LWith: string;
  LResource: TAppResource;
  LAnswer: TJSONValue;
begin
  LWithout := '';
  LWith := '';

  LResource := TAppResource.Create;
  try
    LAnswer := LResource.select(cSEEDED_RESOURCE, '', 'name', '', '', '');
    try
      LWithout := LAnswer.ToJSON;
    finally
      LAnswer.Free;
    end;
  finally
    LResource.Free;
  end;

  LResource := TAppResource.Create;
  try
    LAnswer := LResource.select(cSEEDED_RESOURCE, '', 'name', '', '', 'true');
    try
      LWith := LAnswer.ToJSON;
    finally
      LAnswer.Free;
    end;
  finally
    LResource.Free;
  end;

  Assert.AreEqual(LWithout, LWith,
    'The MARS adapter has started reflecting $count in what it returns. That ' +
    'is a real improvement and it INVALIDATES this test: $count is now ' +
    'observable, so replace this characterisation with an assertion that the ' +
    'option actually reaches the query, the way $filter and $orderby are ' +
    'asserted above.');
end;

initialization
  /// Must run before the FIRST mapping lookup anywhere in the binary - see the
  /// comment in TTestServerResourceMARSOverARealQuery.SetupFixture.
  TRegisterClass.RegisterEntity(TCustomerTest);
  TDUnitX.RegisterTestFixture(TTestServerResourceMARS);
  TDUnitX.RegisterTestFixture(TTestServerResourceMARSOverARealQuery);

end.
