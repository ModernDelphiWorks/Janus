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

{ @abstract(Janus Framework - TManagerObjectSet under DRIVERRESTFUL.)

  WHAT IS UNDER TEST

  The object-set half of the same conditional. Five sites in
  Janus.Manager.ObjectSet plus the three methods they call into:

    * the uses clause              - Janus.RestObjectSet.Adapter instead of
                                     Janus.ObjectSet.Adapter
    * the IMOConnection alias      - IRESTConnection instead of IDBConnection
    * TManagerObjectSet.AddRepository<T>
                                   - builds TRESTObjectSetAdapter<T>
    * TManagerObjectSet.Find<T>(AMethodName, AParams)
                                   - an overload that EXISTS ONLY under this
                                     directive
    * TRESTObjectSetAdapter<M>.Find(AMethodName, AParams) and
      TSessionRestFul<M>.Find(AMethodName, AParams)
                                   - the two bodies it delegates to, both
                                     wrapped in IFDEF DRIVERRESTFUL

  WHY THE LAST THREE MATTER MOST

  Measured on the base this was written against: Janus.Manager.ObjectSet
  produced no .dcu from any test binary, and neither did
  Janus.RestObjectSet.Adapter. The bodies of the three Find(AMethodName,
  AParams) overloads are therefore code that NOTHING in the repository
  compiles - not the four test projects, not the CI job. They are only built
  by the Examples, which are not part of any gate.

  WHAT THE ASSERTIONS ACTUALLY PIN

  The named-method Find has one job: put the method name in the SUB-RESOURCE
  slot of the request and the parameters in the BODY, as a JSON array. Both are
  observable without a server, and both are observed here through
  Test.Janus.RestConnection.Double. A double that only counted calls could not
  tell the correct placement from a swapped one, which is why the double in
  Test.Janus.MasterDetail.Link was not reused.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Driver.ManagerObjectSet;

interface

{$IFNDEF DRIVERRESTFUL}
  {$MESSAGE FATAL 'This unit only makes sense with DRIVERRESTFUL defined. It belongs to Janus.Tests.RESTfulDriver, whose .dproj carries the directive. If this fires, the configuration this suite exists to protect has been switched off.'}
{$ENDIF}

uses
  Rtti,
  Classes,
  SysUtils,
  StrUtils,
  Generics.Collections,
  DUnitX.TestFramework,
  Janus.Client.Methods,
  Janus.RestFactory.Interfaces,
  Janus.RestObjectSet.Adapter,
  Janus.Manager.ObjectSet,
  Test.Janus.RestConnection.Double,
  Test.Janus.Model.AsymKey;

type
  [TestFixture]
  TTestDriverManagerObjectSet = class
  private
    FConn: IRESTConnection;
    FRecorder: TRecordingRestConnection;
    FManager: TManagerObjectSet;
    function RepositoryClassNames: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// The alias. Under the other branch this same declaration takes an
    /// IDBConnection and the assignment does not compile.
    [Test]
    procedure Alias_TheManagerTakesARestConnection;

    /// The class AddRepository<T> actually stored, read back through RTTI.
    [Test]
    procedure Selection_TheRepositoryHoldsTheRestObjectSetAdapterClass;

    /// The ordinary Find goes out over the REST connection as a GET.
    [Test]
    procedure Find_GoesOutOverTheRestConnection;

    /// The DRIVERRESTFUL-only overload: the method name must land in the
    /// SUB-RESOURCE slot, not the resource slot.
    [Test]
    procedure FindByMethodName_PutsTheMethodNameInTheSubResource;

    /// ...and the parameters must land in the BODY, as a JSON array, in the
    /// order given.
    [Test]
    procedure FindByMethodName_PutsTheParametersInTheBodyAsAJsonArray;

    /// An empty parameter list is still a JSON array, not an empty body.
    [Test]
    procedure FindByMethodName_WithNoParametersStillSendsAnEmptyJsonArray;
  end;

implementation

{ TTestDriverManagerObjectSet }

procedure TTestDriverManagerObjectSet.Setup;
begin
  FRecorder := TRecordingRestConnection.Create;
  FConn := FRecorder;
  FManager := TManagerObjectSet.Create(FConn);
end;

procedure TTestDriverManagerObjectSet.TearDown;
begin
  FreeAndNil(FManager);
  FConn := nil;
  FRecorder := nil;
end;

function TTestDriverManagerObjectSet.RepositoryClassNames: string;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LField: TRttiField;
  LRepository: TObjectDictionary<string, TRepository>;
  LPair: TPair<string, TRepository>;
begin
  Result := '';
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(TManagerObjectSet);
    Assert.IsNotNull(LType, 'TManagerObjectSet must be visible to RTTI');
    LField := LType.GetField('FRepository');
    Assert.IsNotNull(LField,
      'FRepository must be readable through RTTI, otherwise this check is ' +
      'blind and would pass on any adapter class whatsoever');
    LRepository := TObjectDictionary<string, TRepository>(
                     LField.GetValue(FManager).AsObject);
    Assert.IsNotNull(LRepository, 'the manager must own a repository');
    for LPair in LRepository do
      Result := Result + LPair.Value.ObjectSet.ClassName + ' ';
  finally
    LContext.Free;
  end;
end;

procedure TTestDriverManagerObjectSet.Alias_TheManagerTakesARestConnection;
var
  LLocal: TManagerObjectSet;
begin
  LLocal := TManagerObjectSet.Create(FConn);
  try
    Assert.IsNotNull(LLocal,
      'TManagerObjectSet.Create(IRESTConnection) must produce a manager');
  finally
    LLocal.Free;
  end;
end;

procedure TTestDriverManagerObjectSet.Selection_TheRepositoryHoldsTheRestObjectSetAdapterClass;
var
  LNames: string;
begin
  FManager.AddRepository<TAsymMaster>;
  LNames := RepositoryClassNames;
  // TObjectSetAdapter is a SUFFIX of TRESTObjectSetAdapter, so the position
  // matters: a Pos() > 0 on the shorter name would match both branches.
  Assert.IsTrue(Pos('TRESTObjectSetAdapter', LNames) = 1,
    'AddRepository<T> must build TRESTObjectSetAdapter under DRIVERRESTFUL; ' +
    'the other branch would leave TObjectSetAdapter here. Found: ' + LNames);
end;

procedure TTestDriverManagerObjectSet.Find_GoesOutOverTheRestConnection;
var
  LList: TObjectList<TAsymMaster>;
begin
  FManager.AddRepository<TAsymMaster>;
  Assert.AreEqual(0, FRecorder.CallCount,
    'registering the repository must not talk to the server by itself');
  LList := FManager.Find<TAsymMaster>;
  try
    Assert.AreEqual(1, FRecorder.CallCount,
      'Find must reach IRESTConnection.Execute exactly once');
    Assert.AreEqual(Ord(TRESTRequestMethodType.rtGET),
      Ord(FRecorder.LastCall.RequestMethod), 'a Find is a GET');
  finally
    LList.Free;
  end;
end;

procedure TTestDriverManagerObjectSet.FindByMethodName_PutsTheMethodNameInTheSubResource;
var
  LList: TObjectList<TAsymMaster>;
begin
  FManager.AddRepository<TAsymMaster>;
  LList := FManager.Find<TAsymMaster>('byTagAndKey', ['abc', '7']);
  try
    Assert.AreEqual(1, FRecorder.CallCount,
      'the named-method Find must reach IRESTConnection.Execute exactly once');
    Assert.AreEqual('byTagAndKey', FRecorder.LastCall.SubResource,
      'the method name belongs in the SUB-RESOURCE slot');
    Assert.AreNotEqual('byTagAndKey', FRecorder.LastCall.Resource,
      'and it must NOT have been sent as the resource - that is the entity, ' +
      'not the method');
    Assert.AreEqual(Ord(TRESTRequestMethodType.rtGET),
      Ord(FRecorder.LastCall.RequestMethod), 'the named-method Find is a GET');
  finally
    LList.Free;
  end;
end;

procedure TTestDriverManagerObjectSet.FindByMethodName_PutsTheParametersInTheBodyAsAJsonArray;
var
  LList: TObjectList<TAsymMaster>;
  LBody: string;
begin
  FManager.AddRepository<TAsymMaster>;
  LList := FManager.Find<TAsymMaster>('byTagAndKey', ['abc', '7']);
  try
    LBody := FRecorder.LastCall.BodyParams;
    Assert.AreNotEqual('', LBody,
      'the parameters must reach the body - an empty body means the callback ' +
      'that pushes them never ran');
    Assert.IsTrue(StartsStr('[', LBody) and EndsStr(']', LBody),
      'the body must be a JSON ARRAY. Found: ' + LBody);
    Assert.IsTrue(Pos('abc', LBody) < Pos('7', LBody),
      'the parameters must keep the order they were given in. Found: ' + LBody);
  finally
    LList.Free;
  end;
end;

procedure TTestDriverManagerObjectSet.FindByMethodName_WithNoParametersStillSendsAnEmptyJsonArray;
var
  LList: TObjectList<TAsymMaster>;
  LEmpty: TArray<string>;
  LBody: string;
begin
  FManager.AddRepository<TAsymMaster>;
  // A dynamic array left nil, passed to the open-array parameter. Written this
  // way rather than as a literal so the call is unambiguously the
  // array-of-string overload.
  LEmpty := nil;
  LList := FManager.Find<TAsymMaster>('noArgs', LEmpty);
  try
    LBody := FRecorder.LastCall.BodyParams;
    Assert.AreEqual('[]', LBody,
      'no parameters still means a JSON array, not an absent body. Found: ' +
      LBody);
  finally
    LList.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDriverManagerObjectSet);

end.
