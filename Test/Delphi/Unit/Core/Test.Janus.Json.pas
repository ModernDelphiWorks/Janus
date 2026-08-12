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

unit Test.Janus.Json;

interface

uses
  SysUtils,
  Rtti,
  Janus.RTTI.Helper,
  Generics.Collections,
  DUnitX.TestFramework,
  JSON,
  Janus.Json,
  Janus.Types.Nullable;

type
  TSampleJsonEntity = class
  private
    FId: Integer;
    FName: String;
    FAmount: Nullable<Integer>;
    FCreatedAt: TDateTime;
    FIsActive: Boolean;
  public
    property Id: Integer read FId write FId;
    property Name: String read FName write FName;
    property Amount: Nullable<Integer> read FAmount write FAmount;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property IsActive: Boolean read FIsActive write FIsActive;
  end;

  /// <summary> The shape issue #314 is about: a mapped column whose property
  ///  is a TGUID.
  ///
  ///  It is not an exotic shape - it is the one this framework PRESCRIBES.
  ///  Janus.DML.Generator.pas:702-709 refuses a ftGuid column declared over a
  ///  String property and names TGUID (or Nullable<TGUID>) as the contract;
  ///  Test.Janus.Model.RestLazyKeys.pas:155-160 says the same in prose and
  ///  declares cck3 that way.
  ///
  ///  TWO ENTITIES AND NOT ONE, because the two shapes the message names take
  ///  DIFFERENT branches of TJanusJson.DoGetValue - a bare TGUID falls to the
  ///  final else (:145-146 at ea0208f), a Nullable<TGUID> goes through
  ///  IsNullable (:130) - and they failed DIFFERENTLY. Put in one class, the
  ///  bare TGUID raised first and every Nullable assertion inherited that
  ///  exception, hiding what the Nullable branch actually does. Measured: a
  ///  single class made all six tests report the SAME message, about the
  ///  OTHER property. </summary>
  TGuidJsonEntity = class
  private
    Fgjid: Integer;
    Fgjkey: TGUID;
  public
    property gjid: Integer read Fgjid write Fgjid;
    property gjkey: TGUID read Fgjkey write Fgjkey;
  end;

  /// <summary> The Nullable twin, alone in its own class - see above. </summary>
  TNullableGuidJsonEntity = class
  private
    Fngid: Integer;
    Fngopt: Nullable<TGUID>;
  public
    property ngid: Integer read Fngid write Fngid;
    property ngopt: Nullable<TGUID> read Fngopt write Fngopt;
  end;

  [TestFixture]
  TTestJanusJson = class
  private
    function CreateEntity: TSampleJsonEntity;
    function CreateGuidEntity: TGuidJsonEntity;
    function CreateNullableGuidEntity: TNullableGuidJsonEntity;
  public
    [Test]
    procedure TestObjectToJsonString_SerializesScalarProperties;
    [Test]
    procedure TestObjectToJsonString_SerializesNullableWithValue;
    [Test]
    procedure TestObjectToJsonString_SerializesNullableWithoutValueAsNull;
    [Test]
    procedure TestObjectToJsonString_SerializesDateAsIso8601;
    [Test]
    procedure TestJsonToObject_CreatesNewInstance;
    [Test]
    procedure TestJsonToObject_PopulatesExistingInstance;
    [Test]
    procedure TestObjectListToJsonString_GenericBuildsArray;
    [Test]
    procedure TestJsonToObjectList_RestoresListCount;
    [Test]
    procedure TestJsonToObjectList_RestoresNames;
    [Test]
    procedure TestJsonToObjectList_RestoresNullableValues;
    [Test]
    procedure TestJSONStringToJSONObject_ParsesObject;
    [Test]
    procedure TestJSONStringToJSONArray_ParsesArray;
    [Test]
    procedure TestJSONObjectToJSONValue_ReturnsObject;
    [Test]
    procedure TestJSONObjectListToJSONArray_PreservesCount;
    [Test]
    procedure TestConfigurationProperties_CanBeChanged;
    // --- issue #314: a TGUID property, and its Nullable twin ---
    [Test]
    procedure TestObjectToJsonString_SerializesGuidAsCanonicalText;
    [Test]
    procedure TestJsonToObject_RestoresGuidFromCanonicalText;
    [Test]
    procedure TestObjectToJsonString_SerializesNullableGuidWithValue;
    [Test]
    procedure TestObjectToJsonString_SerializesNullableGuidWithoutValueAsNull;
    [Test]
    procedure TestJsonToObject_RestoresNullableGuid;
    [Test]
    procedure TestJsonToObject_RestoresNullableGuidFromJsonNull;
    [Test]
    procedure TestSetValueNullable_FillsBareGuidTheWayBindCallsIt;
    [Test]
    procedure TestSetValueNullable_FillsNullableGuidTheWayBindCallsIt;
  end;

implementation

uses
  DateUtils;

function TTestJanusJson.CreateEntity: TSampleJsonEntity;
begin
  Result := TSampleJsonEntity.Create;
  Result.Id := 10;
  Result.Name := 'Janus';
  Result.Amount := 42;
  Result.CreatedAt := EncodeDateTime(2024, 1, 2, 3, 4, 5, 0);
  Result.IsActive := True;
end;

procedure TTestJanusJson.TestObjectToJsonString_SerializesScalarProperties;
var
  LEntity: TSampleJsonEntity;
  LJson: String;
begin
  LEntity := CreateEntity;
  try
    LJson := TJanusJson.ObjectToJsonString(LEntity);
    Assert.Contains(LJson, '"Id"');
    Assert.Contains(LJson, '"Name"');
    Assert.Contains(LJson, 'Janus');
    Assert.Contains(LJson, '"IsActive"');
  finally
    LEntity.Free;
  end;
end;

procedure TTestJanusJson.TestObjectToJsonString_SerializesNullableWithValue;
var
  LEntity: TSampleJsonEntity;
  LJson: String;
begin
  LEntity := CreateEntity;
  try
    LJson := TJanusJson.ObjectToJsonString(LEntity);
    Assert.Contains(LJson, '"Amount"');
    Assert.Contains(LJson, '42');
  finally
    LEntity.Free;
  end;
end;

procedure TTestJanusJson.TestObjectToJsonString_SerializesNullableWithoutValueAsNull;
var
  LEntity: TSampleJsonEntity;
  LJson: String;
begin
  LEntity := CreateEntity;
  try
    LEntity.Amount := nil;
    LJson := TJanusJson.ObjectToJsonString(LEntity);
    Assert.Contains(LJson, '"Amount"');
    Assert.Contains(LowerCase(LJson), 'null');
  finally
    LEntity.Free;
  end;
end;

procedure TTestJanusJson.TestObjectToJsonString_SerializesDateAsIso8601;
var
  LEntity: TSampleJsonEntity;
  LJson: String;
begin
  LEntity := CreateEntity;
  try
    LJson := TJanusJson.ObjectToJsonString(LEntity);
    Assert.Contains(LJson, '2024-01-02');
    Assert.Contains(LJson, '03:04:05');
  finally
    LEntity.Free;
  end;
end;

procedure TTestJanusJson.TestJsonToObject_CreatesNewInstance;
var
  LEntity: TSampleJsonEntity;
begin
  LEntity := TJanusJson.JsonToObject<TSampleJsonEntity>('{"Id":7,"Name":"Neo","Amount":9,"IsActive":true}');
  try
    Assert.AreEqual(7, LEntity.Id);
    Assert.AreEqual('Neo', LEntity.Name);
    Assert.IsTrue(LEntity.Amount.HasValue);
    Assert.AreEqual(9, LEntity.Amount.Value);
    Assert.IsTrue(LEntity.IsActive);
  finally
    LEntity.Free;
  end;
end;

procedure TTestJanusJson.TestJsonToObject_PopulatesExistingInstance;
var
  LEntity: TSampleJsonEntity;
begin
  LEntity := TSampleJsonEntity.Create;
  try
    TJanusJson.JsonToObject('{"Id":15,"Name":"Matrix","Amount":11,"IsActive":false}', LEntity);
    Assert.AreEqual(15, LEntity.Id);
    Assert.AreEqual('Matrix', LEntity.Name);
    Assert.IsTrue(LEntity.Amount.HasValue);
    Assert.AreEqual(11, LEntity.Amount.Value);
    Assert.IsFalse(LEntity.IsActive);
  finally
    LEntity.Free;
  end;
end;

procedure TTestJanusJson.TestObjectListToJsonString_GenericBuildsArray;
var
  LList: TObjectList<TSampleJsonEntity>;
  LJson: String;
begin
  LList := TObjectList<TSampleJsonEntity>.Create(True);
  try
    LList.Add(CreateEntity);
    LList.Add(CreateEntity);
    LJson := TJanusJson.ObjectListToJsonString<TSampleJsonEntity>(LList);
    Assert.StartsWith('[', Trim(LJson));
    Assert.Contains(LJson, '"Id"');
  finally
    LList.Free;
  end;
end;

procedure TTestJanusJson.TestJsonToObjectList_RestoresListCount;
var
  LList: TObjectList<TSampleJsonEntity>;
begin
  LList := TJanusJson.JsonToObjectList<TSampleJsonEntity>('[{"Id":1,"Name":"A"},{"Id":2,"Name":"B"}]');
  try
    Assert.AreEqual(2, LList.Count);
  finally
    LList.Free;
  end;
end;

procedure TTestJanusJson.TestJsonToObjectList_RestoresNames;
var
  LList: TObjectList<TSampleJsonEntity>;
begin
  LList := TJanusJson.JsonToObjectList<TSampleJsonEntity>('[{"Id":1,"Name":"Alpha"},{"Id":2,"Name":"Beta"}]');
  try
    Assert.AreEqual('Alpha', LList[0].Name);
    Assert.AreEqual('Beta', LList[1].Name);
  finally
    LList.Free;
  end;
end;

procedure TTestJanusJson.TestJsonToObjectList_RestoresNullableValues;
var
  LList: TObjectList<TSampleJsonEntity>;
begin
  LList := TJanusJson.JsonToObjectList<TSampleJsonEntity>('[{"Id":1,"Amount":null},{"Id":2,"Amount":21}]');
  try
    Assert.IsFalse(LList[0].Amount.HasValue);
    Assert.IsTrue(LList[1].Amount.HasValue);
    Assert.AreEqual(21, LList[1].Amount.Value);
  finally
    LList.Free;
  end;
end;

procedure TTestJanusJson.TestJSONStringToJSONObject_ParsesObject;
var
  LJsonObject: TJSONObject;
begin
  LJsonObject := TJanusJson.JSONStringToJSONObject('{"name":"janus"}');
  try
    Assert.AreEqual('janus', LJsonObject.GetValue('name').Value);
  finally
    LJsonObject.Free;
  end;
end;

procedure TTestJanusJson.TestJSONStringToJSONArray_ParsesArray;
var
  LJsonArray: TJSONArray;
begin
  LJsonArray := TJanusJson.JSONStringToJSONArray('[{"id":1},{"id":2}]');
  try
    Assert.AreEqual(2, LJsonArray.Count);
  finally
    LJsonArray.Free;
  end;
end;

procedure TTestJanusJson.TestJSONObjectToJSONValue_ReturnsObject;
var
  LEntity: TSampleJsonEntity;
  LJsonValue: TJSONValue;
begin
  LEntity := CreateEntity;
  try
    LJsonValue := TJanusJson.JSONObjectToJSONValue(LEntity);
    try
      Assert.IsTrue(LJsonValue is TJSONObject);
      Assert.Contains(LJsonValue.ToJSON, 'Janus');
    finally
      LJsonValue.Free;
    end;
  finally
    LEntity.Free;
  end;
end;

procedure TTestJanusJson.TestJSONObjectListToJSONArray_PreservesCount;
var
  LList: TObjectList<TSampleJsonEntity>;
  LJsonArray: TJSONArray;
begin
  LList := TObjectList<TSampleJsonEntity>.Create(True);
  try
    LList.Add(CreateEntity);
    LList.Add(CreateEntity);
    LJsonArray := TJanusJson.JSONObjectListToJSONArray<TSampleJsonEntity>(LList);
    try
      Assert.AreEqual(2, LJsonArray.Count);
    finally
      LJsonArray.Free;
    end;
  finally
    LList.Free;
  end;
end;

procedure TTestJanusJson.TestConfigurationProperties_CanBeChanged;
var
  LOldFormat: TFormatSettings;
  LNewFormat: TFormatSettings;
  LOldIso: Boolean;
begin
  LOldFormat := TJanusJson.FormatSettings;
  LOldIso := TJanusJson.UseISO8601DateFormat;
  try
    LNewFormat := LOldFormat;
    LNewFormat.DecimalSeparator := ',';
    TJanusJson.FormatSettings := LNewFormat;
    TJanusJson.UseISO8601DateFormat := False;
    Assert.AreEqual(',', TJanusJson.FormatSettings.DecimalSeparator);
    Assert.IsFalse(TJanusJson.UseISO8601DateFormat);
  finally
    TJanusJson.FormatSettings := LOldFormat;
    TJanusJson.UseISO8601DateFormat := LOldIso;
  end;
end;

// --- issue #314 -------------------------------------------------------------
//
// THE EXPECTED TEXT IS A LITERAL, NOT A RENDERING. Every assertion below
// compares against cGuidKeyText / cGuidOptText spelled out by hand, never
// against LGuid.ToString. Asserting Contains(LJson, LEntity.gjkey.ToString)
// would pass for ANY format the production code chose, as long as the probe
// chose it too - the probe would be blind to exactly the thing under test.
//
// WHY BRACES AND UPPERCASE. This is a contract visible to the consumer, so it
// is not a free choice; the house already answered it in three places, all
// reading TGUID.ToString - braced, 38 characters, uppercase hex:
//   Janus.Command.Inserter.pas:213-217   (INSERT value)
//   Janus.Command.Updater.pas:118-119    (UPDATE parameter)
//   Janus.Command.Deleter.pas:97-98      (DELETE WHERE)
// and Janus.DML.Generator.pas:707 tells the user a GUID key is stored as text
// 38 characters wide. The read-back agrees by construction: StringToGUID, the
// only parse the RTL offers, REQUIRES the braces.

const
  cGuidKeyText = '{2A1B0C3D-4E5F-6071-8293-A4B5C6D7E8F9}';
  cGuidOptText = '{0F1E2D3C-4B5A-6978-8796-A5B4C3D2E1F0}';

function TTestJanusJson.CreateGuidEntity: TGuidJsonEntity;
begin
  Result := TGuidJsonEntity.Create;
  Result.gjid := 3;
  Result.gjkey := StringToGUID(cGuidKeyText);
end;

function TTestJanusJson.CreateNullableGuidEntity: TNullableGuidJsonEntity;
begin
  Result := TNullableGuidJsonEntity.Create;
  Result.ngid := 4;
  Result.ngopt := StringToGUID(cGuidOptText);
end;

procedure TTestJanusJson.TestObjectToJsonString_SerializesGuidAsCanonicalText;
var
  LEntity: TGuidJsonEntity;
  LJson: String;
begin
  LEntity := CreateGuidEntity;
  try
    LJson := TJanusJson.ObjectToJsonString(LEntity);
    Assert.Contains(LJson, '"gjkey":"' + cGuidKeyText + '"');
  finally
    LEntity.Free;
  end;
end;

procedure TTestJanusJson.TestJsonToObject_RestoresGuidFromCanonicalText;
var
  LEntity: TGuidJsonEntity;
begin
  LEntity := TJanusJson.JsonToObject<TGuidJsonEntity>(
    '{"gjid":3,"gjkey":"' + cGuidKeyText + '"}');
  try
    Assert.AreEqual(cGuidKeyText, GUIDToString(LEntity.gjkey));
  finally
    LEntity.Free;
  end;
end;

procedure TTestJanusJson.TestObjectToJsonString_SerializesNullableGuidWithValue;
var
  LEntity: TNullableGuidJsonEntity;
  LJson: String;
begin
  LEntity := CreateNullableGuidEntity;
  try
    LJson := TJanusJson.ObjectToJsonString(LEntity);
    Assert.Contains(LJson, '"ngopt":"' + cGuidOptText + '"');
  finally
    LEntity.Free;
  end;
end;

procedure TTestJanusJson.TestObjectToJsonString_SerializesNullableGuidWithoutValueAsNull;
var
  LEntity: TNullableGuidJsonEntity;
  LJson: String;
begin
  LEntity := CreateNullableGuidEntity;
  try
    LEntity.ngopt := nil;
    LJson := TJanusJson.ObjectToJsonString(LEntity);
    Assert.Contains(LJson, '"ngopt":null');
  finally
    LEntity.Free;
  end;
end;

procedure TTestJanusJson.TestJsonToObject_RestoresNullableGuid;
var
  LEntity: TNullableGuidJsonEntity;
begin
  LEntity := TJanusJson.JsonToObject<TNullableGuidJsonEntity>(
    '{"ngid":4,"ngopt":"' + cGuidOptText + '"}');
  try
    Assert.IsTrue(LEntity.ngopt.HasValue, 'Nullable<TGUID> must come back with a value');
    Assert.AreEqual(cGuidOptText, GUIDToString(LEntity.ngopt.Value));
  finally
    LEntity.Free;
  end;
end;

procedure TTestJanusJson.TestJsonToObject_RestoresNullableGuidFromJsonNull;
var
  LEntity: TNullableGuidJsonEntity;
begin
  LEntity := TJanusJson.JsonToObject<TNullableGuidJsonEntity>(
    '{"ngid":4,"ngopt":null}');
  try
    Assert.IsFalse(LEntity.ngopt.HasValue, 'A JSON null must leave the Nullable empty');
  finally
    LEntity.Free;
  end;
end;

// THE LOCAL PATH, WHICH ISSUE #314 LEFT UNMEASURED.
//
// Reading a ftGuid column back out of a dataset never goes through JSON: it
// goes through TBind._SetFieldToPropertyRecord, which for a record property
// that is neither Nullable nor TBlob calls SetValueNullable with the
// property's OWN handle (Janus.Bind.pas:892 for the Nullable arm, :909 for the
// bare one). The two tests below make exactly those two calls.
//
// Measured against the tree BEFORE this fix: both left the property untouched
// and raised nothing - the bare TGUID stayed all-zeroes and the Nullable
// stayed empty. So the local path did suffer, in its own way: not the REST
// path's loud refusal but a silent loss, which is the harder one to notice.
procedure TTestJanusJson.TestSetValueNullable_FillsBareGuidTheWayBindCallsIt;
var
  LEntity: TGuidJsonEntity;
  LContext: TRttiContext;
  LProperty: TRttiProperty;
begin
  LEntity := TGuidJsonEntity.Create;
  try
    LProperty := LContext.GetType(LEntity.ClassType).GetProperty('gjkey');
    LProperty.SetValueNullable(LEntity, LProperty.PropertyType.Handle,
                               cGuidKeyText, False);
    Assert.AreEqual(cGuidKeyText, GUIDToString(LEntity.gjkey));
  finally
    LEntity.Free;
  end;
end;

procedure TTestJanusJson.TestSetValueNullable_FillsNullableGuidTheWayBindCallsIt;
var
  LEntity: TNullableGuidJsonEntity;
  LContext: TRttiContext;
  LProperty: TRttiProperty;
begin
  LEntity := TNullableGuidJsonEntity.Create;
  try
    LProperty := LContext.GetType(LEntity.ClassType).GetProperty('ngopt');
    LProperty.SetValueNullable(LEntity, LProperty.PropertyType.Handle,
                               cGuidOptText, False);
    Assert.IsTrue(LEntity.ngopt.HasValue);
    Assert.AreEqual(cGuidOptText, GUIDToString(LEntity.ngopt.Value));
  finally
    LEntity.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestJanusJson);

end.