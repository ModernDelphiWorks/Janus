unit TestJanusJson;

interface

uses
  SysUtils,
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

  [TestFixture]
  TTestJanusJson = class
  private
    function CreateEntity: TSampleJsonEntity;
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
  end;

implementation

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

initialization
  TDUnitX.RegisterTestFixture(TTestJanusJson);

end.