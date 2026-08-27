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
  Variants,
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
  ///  TDMLGeneratorAbstract._GetGuidValue refuses a ftGuid column declared
  ///  over a String property and names TGUID (or Nullable&lt;TGUID&gt;) as the
  ///  contract - BY SYMBOL, because the ":702-709" this line used to carry
  ///  rotted when issue #326 grew Janus.DML.Generator.pas;
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

  /// <summary> As tres formas de data NULAVEL, numa classe so - ao contrario do
  ///  par de GUID acima, que precisou se separar porque um deles LEVANTAVA
  ///  excecao e contaminava as assercoes do outro. Aqui nenhuma levanta: as
  ///  tres caem no mesmo arm de SetValueNullable e falham do MESMO jeito
  ///  (gravando 30/12/1899), entao uma classe basta e o teste fica legivel. </summary>
  TNullableDateJsonEntity = class
  private
    Fndid: Integer;
    Fndt: Nullable<TDateTime>;
    Fnd: Nullable<TDate>;
    Fnt: Nullable<TTime>;
    Fnnum: Nullable<Integer>;
    Fncur: Nullable<Currency>;
  public
    property ndid: Integer read Fndid write Fndid;
    property ndt: Nullable<TDateTime> read Fndt write Fndt;
    property nd: Nullable<TDate> read Fnd write Fnd;
    property nt: Nullable<TTime> read Fnt write Fnt;
    property nnum: Nullable<Integer> read Fnnum write Fnnum;
    property ncur: Nullable<Currency> read Fncur write Fncur;
  end;

  [TestFixture]
  TTestJanusJson = class
  private
    function CreateEntity: TSampleJsonEntity;
    function CreateGuidEntity: TGuidJsonEntity;
    function CreateNullableGuidEntity: TNullableGuidJsonEntity;
    function CreateNullableDateEntity: TNullableDateJsonEntity;
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
    procedure TestJsonToObject_TreatsJsonNullAsEmptyGuid;
    [Test]
    procedure TestSetValueNullable_FillsBareGuidTheWayBindCallsIt;
    [Test]
    procedure TestSetValueNullable_FillsNullableGuidTheWayBindCallsIt;
    [Test]
    procedure TestSetValueNullable_TreatsBlankTextAsEmptyGuid;
    [Test]
    procedure TestSetValueNullable_TreatsBlankTextAsClearedNullableGuid;
    [Test]
    procedure TestSetValueNullable_BlankTextClearsNullableDateTime;
    [Test]
    procedure TestSetValueNullable_BlankTextClearsNullableDate;
    [Test]
    procedure TestSetValueNullable_BlankTextClearsNullableTime;
    [Test]
    procedure TestSetValueNullable_RealTextStillFillsNullableDateTime;
    [Test]
    procedure TestSetValueNullable_BlankTextClearsNullableInteger;
    [Test]
    procedure TestSetValueNullable_BlankTextClearsNullableCurrency;
    [Test]
    procedure TestSetValueNullable_RealTextStillFillsNullableInteger;
    [Test]
    procedure TestSetValueNullable_ClearsBareGuidWhenNullRendersAsText;
    [Test]
    procedure TestSetValueNullable_ClearsNullableGuidWhenNullRendersAsText;
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
// WHY BRACES. This is a contract visible to the consumer, and it was not
// decided here - the repo had already written it down. The doc comment over
// TDMLGeneratorAbstract.GuidLiteral states that a ftGuid column MEANS TGUID and
// that the Guid32Inc/36/38 generators belong to the ftString world (which is
// what dissolves the apparent conflict between issues #284 and #311), and the
// same comment names the canonical form. THREE ANCHORS IN THIS PARAGRAPH WERE
// BY LINE - :115-120, :124-136 and :766-768 - and all three rotted at once when
// issue #326 inserted lines into that unit; they are by symbol now.
// FOUR sites render it, all TGUID.ToString:
//   TCommandInserter._GetParamValue     (INSERT value, by symbol)
//   Janus.Command.Updater.pas:118-119    (UPDATE parameter)
//   Janus.Command.Deleter.pas:97-98      (DELETE WHERE)
//   TDMLGeneratorAbstract.CanonicalGuidLiteral, Janus.DML.Generator.pas
// StrToGUID agrees on the shape and only on the shape:
// System.SysUtils.pas:6025-6028 rejects any length but 38 and any misplaced
// brace or hyphen.
//
// THE UPPER CASE, THOUGH, IS CONVENTION AND NOT PARSER LAW.
// System.SysUtils.pas:6036-6037 accepts 'a'..'f' too. It is pinned here because
// it is what the four sites above put in the column, so a consumer comparing
// the JSON text to the stored text gets a match - not because a round trip
// would break without it.
//
// AND THE ignoreCase ARGUMENT IS SPELLED OUT, because Assert.Contains defaults
// it to TRUE (DUnitX.Assert.pas:1349-1352 forwards fIgnoreCaseDefault). It was
// not spelled out at first, and it cost a survivor: wrapping the emitted text
// in LowerCase changed what every consumer reads and no test moved. The case
// is part of the contract - TGUID.ToString is upper-case hex, and that is the
// text already sitting in the database column - so the probe has to see it.

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
    Assert.Contains(LJson, '"gjkey":"' + cGuidKeyText + '"', False);
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
    Assert.Contains(LJson, '"ngopt":"' + cGuidOptText + '"', False);
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
    Assert.Contains(LJson, '"ngopt":null', False);
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
// goes through TBind._SetFieldToPropertyRecord, which calls SetValueNullable
// from TWO of its arms - the IsNullable arm, which passes the RTTI type's
// handle, and the FINAL else, the arm for a record property that is neither a
// Nullable nor a TBlob, which passes the property's OWN handle. The two tests
// below make exactly those two calls.
//
// ANCHORED BY METHOD AND BY ARM, AND THAT IS A REPAIR AND NOT A STYLE CHOICE.
// This paragraph used to name two line numbers in Janus.Bind.pas. Issue #324's
// repair inserted a comment ABOVE them and both citations silently retargeted -
// one of them onto a sentence about tkSet. A citation a later insertion moves
// is worse than no citation, because it still reads as verified.
//
// Measured against the tree BEFORE this fix: both left the property untouched
// and raised nothing - the bare TGUID stayed all-zeroes and the Nullable
// stayed empty. So the local path did suffer, in its own way: not the REST
// path's loud refusal but a silent loss, which is the harder one to notice.
// A bare TGUID is not nullable, so a JSON null has to land SOMEWHERE. It lands
// on TGUID.Empty - the value a freshly constructed object already carries -
// and it must not raise, because StringToGUID would. This is also the test that
// tells the varNull half of the guard in SetValueNullable apart from the trim:
// with only the trim, it still passes, which is the measurement that decided
// whether that half was a guard or dead weight.
procedure TTestJanusJson.TestJsonToObject_TreatsJsonNullAsEmptyGuid;
var
  LEntity: TGuidJsonEntity;
begin
  LEntity := TJanusJson.JsonToObject<TGuidJsonEntity>('{"gjid":3,"gjkey":null}');
  try
    Assert.AreEqual(GUIDToString(TGUID.Empty), GUIDToString(LEntity.gjkey));
  finally
    LEntity.Free;
  end;
end;

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

// A GUID COLUMN THAT WAS NEVER WRITTEN.
//
// The house means to store a GUID key in a FIXED-WIDTH text column, and a
// fixed-width text column pads: a row whose key was never filled hands Bind a
// string of SPACES, not a null, and StringToGUID raises on it.
//
// MEASURED, AND AGAINST A NAMED REF, because the answer differs by ref. On
// MetaDbDiff origin/main (8d8d59d, four commits ahead of the shared checkout),
// MetaDbDiff.Metadata.Extract.pas:429-451 writes CHAR(%l) for PostgreSQL,
// Firebird, InterBase and MySQL and NCHAR(%l) for Oracle, and
// MetaDbDiff.DDL.Generator.pas:484 substitutes %l with AColumn.Size - so the
// width is whatever the mapping declares, and this repo's own ftGuid model,
// Test.Janus.Model.RestLazyKeys.pas:159, declares 38. On the checkout this
// build actually compiles against (3a366e4) those same lines still write '%1',
// which nothing substitutes - a defect of that repo, fixed there by its PR #21.
// Either way the column is fixed-width text, which is all these tests rest on.
//
// These two tests are why the guard in SetValueNullable trims instead of
// comparing to the empty string: without them, dropping the text half of that
// guard changed nothing any test could see, while the change it makes in the
// field is turning today's silent loss into an EConvertError.
procedure TTestJanusJson.TestSetValueNullable_TreatsBlankTextAsEmptyGuid;
var
  LEntity: TGuidJsonEntity;
  LContext: TRttiContext;
  LProperty: TRttiProperty;
begin
  LEntity := CreateGuidEntity;
  try
    LProperty := LContext.GetType(LEntity.ClassType).GetProperty('gjkey');
    LProperty.SetValueNullable(LEntity, LProperty.PropertyType.Handle,
                               StringOfChar(' ', 38), False);
    Assert.AreEqual(GUIDToString(TGUID.Empty), GUIDToString(LEntity.gjkey));
  finally
    LEntity.Free;
  end;
end;

function TTestJanusJson.CreateNullableDateEntity: TNullableDateJsonEntity;
begin
  Result := TNullableDateJsonEntity.Create;
  Result.ndid := 5;
  // Ja NASCE preenchida de proposito: se o objeto viesse limpo, um SetValue que
  // nao fizesse NADA passaria nos tres testes abaixo. O valor tem de ser
  // APAGADO, e so da para ver isso apagando algo que estava la.
  Result.ndt := EncodeDate(2026, 8, 27) + EncodeTime(14, 30, 0, 0);
  Result.nd  := TDate(EncodeDate(2026, 8, 27));
  Result.nt  := TTime(EncodeTime(14, 30, 0, 0));
  Result.nnum := 777;
  Result.ncur := 12.34;
end;

// TEXTO EM BRANCO NUMA DATA NULAVEL E NULL, NAO 30/12/1899.
//
// MEDIDO ao vivo antes do conserto (backend Axial sobre Firebird 2.5, coluna
// A04_FON.A04_DATAGARANTIA, lendo a LINHA por isql e nao o eco do POST):
//   ""  -> 1899-12-30      null -> <NULL>      ausente -> <NULL>      data -> ok
// Ou seja: das quatro entradas, so a string vazia errava, e errava em 216
// colunas Nullable<TDateTime> do schema daquele produto.
//
// A causa nao esta no parser. Iso8601ToDateTime devolve TDateTime, um tipo que
// NAO TEM COMO dizer NULL - JsonFlow.Utils.pas:92 transforma falha de parse em
// `Result := 0`, e 0 e 30/12/1899. So o arm do Nullable consegue expressar
// ausencia, e e por isso que o conserto (e o teste) moram aqui.
//
// A guarda e literalmente a mesma dos dois arms de TGUID, cujos testes vizinhos
// ja prendem os DOIS termos (VType <= varNull e o Trim) pelo motivo do
// NullAsStringValue documentado acima.
procedure TTestJanusJson.TestSetValueNullable_BlankTextClearsNullableDateTime;
var
  LEntity: TNullableDateJsonEntity;
  LContext: TRttiContext;
  LProperty: TRttiProperty;
begin
  LEntity := CreateNullableDateEntity;
  try
    Assert.IsTrue(LEntity.ndt.HasValue, 'pre-condicao: tem de comecar preenchida');
    LProperty := LContext.GetType(LEntity.ClassType).GetProperty('ndt');
    LProperty.SetValueNullable(LEntity, LProperty.PropertyType.Handle, '', True);
    Assert.IsFalse(LEntity.ndt.HasValue);
  finally
    LEntity.Free;
  end;
end;

procedure TTestJanusJson.TestSetValueNullable_BlankTextClearsNullableDate;
var
  LEntity: TNullableDateJsonEntity;
  LContext: TRttiContext;
  LProperty: TRttiProperty;
begin
  LEntity := CreateNullableDateEntity;
  try
    LProperty := LContext.GetType(LEntity.ClassType).GetProperty('nd');
    // ESPACOS, nao string vazia: e o que uma coluna CHAR de largura fixa
    // devolve, e e o caso que o Trim da guarda existe para pegar.
    LProperty.SetValueNullable(LEntity, LProperty.PropertyType.Handle, '   ', True);
    Assert.IsFalse(LEntity.nd.HasValue);
  finally
    LEntity.Free;
  end;
end;

procedure TTestJanusJson.TestSetValueNullable_BlankTextClearsNullableTime;
var
  LEntity: TNullableDateJsonEntity;
  LContext: TRttiContext;
  LProperty: TRttiProperty;
begin
  LEntity := CreateNullableDateEntity;
  try
    LProperty := LContext.GetType(LEntity.ClassType).GetProperty('nt');
    LProperty.SetValueNullable(LEntity, LProperty.PropertyType.Handle, '', True);
    Assert.IsFalse(LEntity.nt.HasValue);
  finally
    LEntity.Free;
  end;
end;

// O CONTRA-CASO. Sem ele, uma guarda que limpasse SEMPRE passaria nos tres
// testes acima - e seria um estrago muito maior que o defeito original.
procedure TTestJanusJson.TestSetValueNullable_RealTextStillFillsNullableDateTime;
var
  LEntity: TNullableDateJsonEntity;
  LContext: TRttiContext;
  LProperty: TRttiProperty;
begin
  LEntity := TNullableDateJsonEntity.Create;
  try
    LProperty := LContext.GetType(LEntity.ClassType).GetProperty('ndt');
    LProperty.SetValueNullable(LEntity, LProperty.PropertyType.Handle,
                               '2026-08-27T14:30:00', True);
    Assert.IsTrue(LEntity.ndt.HasValue);
    Assert.AreEqual(EncodeDate(2026, 8, 27) + EncodeTime(14, 30, 0, 0),
                    TDateTime(LEntity.ndt.Value), 1 / (24 * 60 * 60));
  finally
    LEntity.Free;
  end;
end;

// O LADO NUMERICO DO MESMO DEFEITO, COM SINTOMA DIFERENTE.
//
// Sem a guarda, Integer('') levanta EConvertError e a requisicao inteira cai:
// medido no backend Axial como HTTP 500 com NENHUMA linha gravada, contra o
// silencioso 30/12/1899 do lado das datas. Mesma causa (campo em branco chega
// como ""), remedio identico.
procedure TTestJanusJson.TestSetValueNullable_BlankTextClearsNullableInteger;
var
  LEntity: TNullableDateJsonEntity;
  LContext: TRttiContext;
  LProperty: TRttiProperty;
begin
  LEntity := CreateNullableDateEntity;
  try
    Assert.IsTrue(LEntity.nnum.HasValue, 'pre-condicao: tem de comecar preenchida');
    LProperty := LContext.GetType(LEntity.ClassType).GetProperty('nnum');
    LProperty.SetValueNullable(LEntity, LProperty.PropertyType.Handle, '', True);
    Assert.IsFalse(LEntity.nnum.HasValue);
  finally
    LEntity.Free;
  end;
end;

procedure TTestJanusJson.TestSetValueNullable_BlankTextClearsNullableCurrency;
var
  LEntity: TNullableDateJsonEntity;
  LContext: TRttiContext;
  LProperty: TRttiProperty;
begin
  LEntity := CreateNullableDateEntity;
  try
    LProperty := LContext.GetType(LEntity.ClassType).GetProperty('ncur');
    LProperty.SetValueNullable(LEntity, LProperty.PropertyType.Handle, '  ', True);
    Assert.IsFalse(LEntity.ncur.HasValue);
  finally
    LEntity.Free;
  end;
end;

// O contra-caso do lado numerico. Note o valor vindo como TEXTO: e assim que
// chega de um JSON com aspas, que e o caso que a guarda podia ter estragado.
procedure TTestJanusJson.TestSetValueNullable_RealTextStillFillsNullableInteger;
var
  LEntity: TNullableDateJsonEntity;
  LContext: TRttiContext;
  LProperty: TRttiProperty;
begin
  LEntity := TNullableDateJsonEntity.Create;
  try
    LProperty := LContext.GetType(LEntity.ClassType).GetProperty('nnum');
    LProperty.SetValueNullable(LEntity, LProperty.PropertyType.Handle, '4321', True);
    Assert.IsTrue(LEntity.nnum.HasValue);
    Assert.AreEqual(4321, LEntity.nnum.Value);
  finally
    LEntity.Free;
  end;
end;

procedure TTestJanusJson.TestSetValueNullable_TreatsBlankTextAsClearedNullableGuid;
var
  LEntity: TNullableGuidJsonEntity;
  LContext: TRttiContext;
  LProperty: TRttiProperty;
begin
  LEntity := CreateNullableGuidEntity;
  try
    LProperty := LContext.GetType(LEntity.ClassType).GetProperty('ngopt');
    LProperty.SetValueNullable(LEntity, LProperty.PropertyType.Handle,
                               StringOfChar(' ', 38), False);
    Assert.IsFalse(LEntity.ngopt.HasValue);
  finally
    LEntity.Free;
  end;
end;

// A NULL THAT DOES NOT RENDER AS THE EMPTY STRING.
//
// VarToStr is not a function of the variant alone. System.Variants.pas:5401-
// 5403 defines it as VarToStrDef(V, NullAsStringValue), and
// System.Variants.pas:322-344 declares NullAsStringValue in a var block -
// a MUTABLE GLOBAL, documented there as the knob other environments set to
// 'NULL'. Delphi's default is '', which is the only reason a guard written
// as a bare Trim(VarToStr(...)) = '' appears to answer a real null.
//
// These two tests move that global, which is what makes the suite able to
// SEE the varNull term at all. Without them, deleting that term killed
// nothing - a survival that measured the probe's blindness, not the code's
// redundancy. With NullAsStringValue set, deleting it turns the silent
// clearing of a genuine NULL into EConvertError, which is precisely the
// disaster the text half of the same guard exists to prevent.
procedure TTestJanusJson.TestSetValueNullable_ClearsBareGuidWhenNullRendersAsText;
var
  LEntity: TGuidJsonEntity;
  LContext: TRttiContext;
  LProperty: TRttiProperty;
  LSavedNullText: String;
begin
  LSavedNullText := NullAsStringValue;
  NullAsStringValue := 'NULL';
  try
    LEntity := CreateGuidEntity;
    try
      LProperty := LContext.GetType(LEntity.ClassType).GetProperty('gjkey');
      LProperty.SetValueNullable(LEntity, LProperty.PropertyType.Handle,
                                 Null, False);
      Assert.AreEqual(GUIDToString(TGUID.Empty), GUIDToString(LEntity.gjkey));
    finally
      LEntity.Free;
    end;
  finally
    NullAsStringValue := LSavedNullText;
  end;
end;

procedure TTestJanusJson.TestSetValueNullable_ClearsNullableGuidWhenNullRendersAsText;
var
  LEntity: TNullableGuidJsonEntity;
  LContext: TRttiContext;
  LProperty: TRttiProperty;
  LSavedNullText: String;
begin
  LSavedNullText := NullAsStringValue;
  NullAsStringValue := 'NULL';
  try
    LEntity := CreateNullableGuidEntity;
    try
      LProperty := LContext.GetType(LEntity.ClassType).GetProperty('ngopt');
      LProperty.SetValueNullable(LEntity, LProperty.PropertyType.Handle,
                                 Null, False);
      Assert.IsFalse(LEntity.ngopt.HasValue);
    finally
      LEntity.Free;
    end;
  finally
    NullAsStringValue := LSavedNullText;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestJanusJson);

end.