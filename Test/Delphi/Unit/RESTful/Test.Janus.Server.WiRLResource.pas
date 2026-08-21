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

{ THE WiRL SERVER SIDE - issue #341, Level 2.

  Janus.Tests.RESTWiRL was created by #213 to compile the WiRL CLIENT path, and
  its own header says so. The compile-coverage census read that literally:
  Janus.Server.WiRL and Janus.Server.Resource.WiRL were compiled by NONE of the
  seven test projects - the identical hole that let #213's three empty method
  bodies ship on the client side.

  THE CLAUSE THAT TIES THE TWO UNITS TOGETHER IS A STRING.
  TRESTServerWiRL.AddResource mounts the resource by NAME:

      .SetResources('Janus.Server.Resource.WiRL.TAppResource')

  and the registry TAppResource registers itself in is keyed by
  AClass.QualifiedClassName (WiRL.Core.Registry.pas, TWiRLResourceRegistry.
  RegisterResource). Rename the class, move it to another unit, or drop the
  initialization section, and the two halves stop agreeing IN SILENCE: the
  engine mounts an application with no resources and every request 404s. No
  compiler diagnoses it. Resource_TheNameTheServerMountsIsTheNameTheRegistry-
  Knows is that agreement, asserted.

  The verb map is the second clause. #338 was a DataSnap verb swap - the same
  shape of defect this resource is wide open to, since each verb is a bare
  attribute above a method and nothing but a test can tell GET from POST. }

unit Test.Janus.Server.WiRLResource;

interface

uses
  SysUtils,
  Rtti,
  DUnitX.TestFramework,
  // WiRL
  WiRL.Core.Registry,
  WiRL.Core.Attributes,
  WiRL.Core.MessageBodyWriter,
  // Janus - the two units under test
  Janus.Server.WiRL,
  Janus.Server.Resource.WiRL;

type
  [TestFixture]
  TTestJanusServerWiRLResource = class
  private
    /// The literal TRESTServerWiRL.AddResource hands to SetResources. Written
    /// out here rather than referenced, on purpose: the point of the clause is
    /// that the two sides are TYPED SEPARATELY and must still agree.
    const CMountedResourceName = 'Janus.Server.Resource.WiRL.TAppResource';
    /// The base path of [Path] on TAppResource.
    const CResourceBasePath = '/Janus';
  private
    function PathOfType(const AClass: TClass): String;
    function VerbOfMethod(const AClass: TClass; const AMethod: String): String;
    function PathOfMethod(const AClass: TClass; const AMethod: String): String;
  public
    [Test]
    procedure Resource_RegistersItselfOnLink;
    [Test]
    procedure Resource_TheNameTheServerMountsIsTheNameTheRegistryKnows;
    [Test]
    procedure Resource_CarriesItsBasePath;

    [Test]
    procedure Verbs_SelectIsGet;
    [Test]
    procedure Verbs_InsertIsPost;
    [Test]
    procedure Verbs_UpdateIsPut;
    [Test]
    procedure Verbs_DeleteIsDelete;
    [Test]
    procedure Verbs_NoTwoOperationsShareAVerb;

    [Test]
    procedure Server_LinkingSeedsTheGlobalWriterRegistry;
    [Test]
    procedure Server_IsAComponentWithAnEngineProperty;
  end;

implementation

{ TTestJanusServerWiRLResource }

function TTestJanusServerWiRLResource.PathOfType(const AClass: TClass): String;
var
  LContext: TRttiContext;
  LAttribute: TCustomAttribute;
begin
  Result := '';
  LContext := TRttiContext.Create;
  try
    for LAttribute in LContext.GetType(AClass).GetAttributes do
      if LAttribute is PathAttribute then
        Exit(PathAttribute(LAttribute).Value);
  finally
    LContext.Free;
  end;
end;

{ HttpMethodAttribute.ToString answers the verb WiRL itself matches on
  (WiRL.Core.Attributes.pas, GETAttribute.ToString and its siblings), so this
  reads the SAME thing the dispatcher reads, not a parallel opinion of it. }
function TTestJanusServerWiRLResource.VerbOfMethod(const AClass: TClass;
  const AMethod: String): String;
var
  LContext: TRttiContext;
  LMethod: TRttiMethod;
  LAttribute: TCustomAttribute;
begin
  Result := '';
  LContext := TRttiContext.Create;
  try
    LMethod := LContext.GetType(AClass).GetMethod(AMethod);
    Assert.IsNotNull(LMethod,
      Format('%s.%s must exist for its verb to mean anything',
             [AClass.ClassName, AMethod]));
    for LAttribute in LMethod.GetAttributes do
      if LAttribute is HttpMethodAttribute then
        Exit(HttpMethodAttribute(LAttribute).ToString);
  finally
    LContext.Free;
  end;
end;

function TTestJanusServerWiRLResource.PathOfMethod(const AClass: TClass;
  const AMethod: String): String;
var
  LContext: TRttiContext;
  LMethod: TRttiMethod;
  LAttribute: TCustomAttribute;
begin
  Result := '';
  LContext := TRttiContext.Create;
  try
    LMethod := LContext.GetType(AClass).GetMethod(AMethod);
    if LMethod = nil then
      Exit;
    for LAttribute in LMethod.GetAttributes do
      if LAttribute is PathAttribute then
        Exit(PathAttribute(LAttribute).Value);
  finally
    LContext.Free;
  end;
end;

{ Janus.Server.Resource.WiRL registers TAppResource in its initialization
  section. Drop that line and the whole server answers 404. }
procedure TTestJanusServerWiRLResource.Resource_RegistersItselfOnLink;
begin
  Assert.IsTrue(TWiRLResourceRegistry.Instance.ResourceExists(TAppResource),
    'Linking Janus.Server.Resource.WiRL must put TAppResource in the WiRL ' +
    'resource registry - its initialization section is the only thing that ' +
    'does it, and nothing else in the framework would notice its absence');
end;

{ THE STRING AGREEMENT. TRESTServerWiRL.AddResource mounts by qualified name;
  TWiRLResourceRegistry keys by AClass.QualifiedClassName. Both sides are typed
  out independently and neither compiler-checks the other. }
procedure TTestJanusServerWiRLResource.Resource_TheNameTheServerMountsIsTheNameTheRegistryKnows;
var
  LClass: TClass;
begin
  Assert.AreEqual(CMountedResourceName, TAppResource.QualifiedClassName,
    'TRESTServerWiRL.AddResource mounts the resource by this exact literal; ' +
    'if the class moved or was renamed, the server now mounts nothing');

  Assert.IsTrue(
    TWiRLResourceRegistry.Instance.GetResourceClass(CMountedResourceName, LClass),
    'The name the server mounts must be a key the WiRL registry answers to');
  Assert.AreEqual(TAppResource.ClassName, LClass.ClassName,
    'and it must resolve to TAppResource, not to some other registered resource');
end;

procedure TTestJanusServerWiRLResource.Resource_CarriesItsBasePath;
begin
  Assert.AreEqual(CResourceBasePath, PathOfType(TAppResource),
    'TAppResource is published under [Path(''/Janus'')]; changing it moves ' +
    'every route of the Janus WiRL server at once');
end;

procedure TTestJanusServerWiRLResource.Verbs_SelectIsGet;
begin
  Assert.AreEqual('GET', VerbOfMethod(TAppResource, 'select'),
    'A read must not be reachable by anything but GET');
  Assert.AreEqual('/{resource}?', PathOfMethod(TAppResource, 'select'),
    'select answers on the optional-resource path');
end;

procedure TTestJanusServerWiRLResource.Verbs_InsertIsPost;
begin
  Assert.AreEqual('POST', VerbOfMethod(TAppResource, 'insert'),
    'insert must be POST - #338 was exactly this attribute swapped on the ' +
    'DataSnap side, and nothing but an assertion tells the two apart');
  Assert.AreEqual('/{resource}', PathOfMethod(TAppResource, 'insert'),
    'insert takes a mandatory resource segment');
end;

procedure TTestJanusServerWiRLResource.Verbs_UpdateIsPut;
begin
  Assert.AreEqual('PUT', VerbOfMethod(TAppResource, 'update'),
    'update must be PUT');
  Assert.AreEqual('/{resource}', PathOfMethod(TAppResource, 'update'),
    'update takes a mandatory resource segment');
end;

procedure TTestJanusServerWiRLResource.Verbs_DeleteIsDelete;
begin
  Assert.AreEqual('DELETE', VerbOfMethod(TAppResource, 'delete'),
    'delete must be DELETE');
end;

{ PERTINENCE TRIPWIRE for the four clauses above. Each names ONE verb; that is
  only meaningful if the four verbs are four DIFFERENT strings. If the reader
  ever started answering the same thing for every method - a plausible way for
  VerbOfMethod to be silently broken - the four would all still pass and this
  is what dies. }
procedure TTestJanusServerWiRLResource.Verbs_NoTwoOperationsShareAVerb;
var
  LSelect: String;
  LInsert: String;
  LUpdate: String;
  LDelete: String;
begin
  LSelect := VerbOfMethod(TAppResource, 'select');
  LInsert := VerbOfMethod(TAppResource, 'insert');
  LUpdate := VerbOfMethod(TAppResource, 'update');
  LDelete := VerbOfMethod(TAppResource, 'delete');

  Assert.IsTrue(LSelect <> '', 'The verb reader must answer something at all');
  Assert.AreNotEqual(LSelect, LInsert, 'select and insert are different verbs');
  Assert.AreNotEqual(LSelect, LUpdate, 'select and update are different verbs');
  Assert.AreNotEqual(LSelect, LDelete, 'select and delete are different verbs');
  Assert.AreNotEqual(LInsert, LUpdate, 'insert and update are different verbs');
  Assert.AreNotEqual(LInsert, LDelete, 'insert and delete are different verbs');
  Assert.AreNotEqual(LUpdate, LDelete, 'update and delete are different verbs');
end;

{ THE CLAIM THE SOURCE ALREADY MAKES, TURNED INTO A CLAUSE.
  Janus.Server.WiRL names WiRL.Core.MessageBody.Default in its implementation
  uses exactly so the GLOBAL writer registry is seeded - its own comment
  records "0/0 writers without the unit, 9/6 with it", and without it every
  response, error responses included, dies as EWiRLServerException
  'MessageBodyWriters registry is empty'. Drop that unit reference and this
  clause is what says so, instead of a developer discovering it over HTTP. }
procedure TTestJanusServerWiRLResource.Server_LinkingSeedsTheGlobalWriterRegistry;
begin
  Assert.IsTrue(TMessageBodyWriterRegistry.Instance.Count > 0,
    'Linking Janus.Server.WiRL must leave the GLOBAL MessageBodyWriter ' +
    'registry non-empty: TWiRLApplication.Startup seeds every application''s ' +
    'registry from this singleton, and an empty one turns every response - ' +
    'including the serialisation of the error itself - into HTTP 500');
end;

procedure TTestJanusServerWiRLResource.Server_IsAComponentWithAnEngineProperty;
var
  LContext: TRttiContext;
  LType: TRttiType;
begin
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(TRESTServerWiRL);

    Assert.IsNotNull(LType,
      'TRESTServerWiRL must carry RTTI: it is dropped on a form at design ' +
      'time and the streaming system reads it by name');
    Assert.IsNotNull(LType.GetProperty('WiRLEngine'),
      'The published surface of the component is WiRLEngine - assigning it is ' +
      'what calls AddResource and mounts the resource on the running engine');
    Assert.IsNotNull(LType.GetProperty('Connection'),
      'and Connection, which the resource reads back through ' +
      'TRESTServerWiRL.GetConnection');
  finally
    LContext.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestJanusServerWiRLResource);

end.
