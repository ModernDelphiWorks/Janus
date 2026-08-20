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

{ @abstract(Janus Framework - the REST ObjectSet family reconciles a GENERATED
  key whose property is a Nullable. Issue #317.)

  WHAT WAS WRONG

  `TRESTObjectSetAdapter<M>._SetGeneratedKeyValue` dispatched on
  `LProperty.PropertyType.TypeKind` over three labels - `tkInteger`, `tkInt64`
  and the four string kinds. A `Nullable<T>` property is `tkRecord`, so it
  matched nothing and the object came out of an insert still holding the
  AutoInc placeholder, with the cascade handing that placeholder down to every
  child's foreign key.

  NOT A REGRESSION, and #301 says so itself: before that issue the answer was
  not read at all, so no key of any shape was reconciled. This is the part of it
  that a Nullable key never reached.

  AND THE SHAPE IS THE ONE THE REPOSITORY TEACHES. All eight models under
  `Examples\Delphi\Data\Varios Niveis de Dados` declare their key as a Nullable;
  `Tcontato` spells it `[Column('id', ftInteger)]` over
  `property id: Nullable<Integer>`. `TNkRoot` reproduces that pair.

  MEASURED, on this fixture over the unchanged reader - THE COMMIT THAT ADDS
  THIS UNIT, which is the PARENT of the one that repairs
  Janus.RestObjectSet.Adapter, and is named that way rather than by a sha
  because a sha written into the commit it names cannot survive its own amend,
  and a dead anchor does not announce itself. Janus.Tests.RESTfulDriver came out
  total=203 failures=6 errors=0 over 17 fixtures, and the six are exactly the six
  clauses below that require a key to have ARRIVED. The other seven are the
  guards and the negative control, which already hold there because that state
  writes nothing at all. The basal one commit under it, 7e5e51d, was total=190
  failures=0 errors=0 over 16 fixtures.

  WHY THE ARM DISPATCHES ON `TypeInfo(Nullable<X>)` AND NOT ON THE COLUMN

  The alternative the issue leaves open is to decide the conversion HIGHER UP,
  from `TColumnMapping.FieldType` - the type of the DATABASE column, which the
  caller already has in hand. It was rejected by measurement, not by taste.

  The value that must be written goes through
  `TRttiPropertyHelper_.SetValueNullable`, whose arms are selected by comparing
  the PROPERTY's `TypeInfo` against `TypeInfo(Nullable<Integer>)`,
  `TypeInfo(Nullable<Int64>)` and so on. Its `Nullable<Integer>` arm performs
  `Integer(AValue)` on the variant it is handed. So a reader that decides WHAT
  TO PARSE from the column while `SetValueNullable` decides WHERE TO WRITE from
  the property raises `Could not convert variant` the moment the two disagree -
  which is precisely the failure mode the #301 rule forbids.

  AND THE TWO DO DISAGREE IN SHIPPED CODE. Enumerated at 7e5e51d over every
  `[PrimaryKey]` under `Test\` and `Examples\` resolved to its `[Column]`:

    Test\Delphi\Common\Test.Janus.Model.KeyTypes.pas   `[Column('ktut', ftString, 60)]`
                                                       over `property ktut: UInt64`
    Examples\...\Quatro Niveis de Dados\Model.Setor.pas `[Column('SETOR', ftInteger)]`
                                                       over `property SETOR: Double`
    Examples\...\Object Lazy\Model.Setor.pas            `[Column('SETOR', ftBCD)]`
                                                       over `property SETOR: Double`

  Three primary keys the repository ships whose column type is not the property
  type. A `FieldType` table would send text at the first and a number at the
  other two, into arms chosen by something else.

  There is a second reason and it is structural rather than accidental:
  `TFieldType` has some forty labels and `SetValueNullable` has eleven arms, so
  the mapping cannot be one to one in the direction that matters - `ftFloat`
  alone has to choose between `Nullable<Double>` and `Nullable<Currency>`, and
  the column cannot tell you which. To choose correctly the higher-up reader
  would have to consult the property anyway, at which point it IS the arm below,
  written twice.

  Asking the SAME question `SetValueNullable` asks - the property's own
  `TypeInfo` - is what makes the guard and the write agree BY CONSTRUCTION. The
  arm parses the text first and only calls `SetValueNullable` with a variant
  already of the element's type, so the cast inside it cannot fail. That is how
  the #301 rule is honoured rather than merely restated: not "this probably will
  not raise", but "the arm that receives it was selected by the same comparison
  that selected the parse".

  THE THREE ARMS AND THE ONE FALL-THROUGH

  `Nullable<Integer>`, `Nullable<Int64>` and `Nullable<String>` are written;
  every other element type falls through untouched, exactly as before.
  `TNdRoot` - `Nullable<Double>` - is the negative control that keeps that scope
  honest, and `NullableDoubleKeyIsNotReconciled` is a CHARACTERISATION, not an
  approval.

  WHY A TEXTUAL GENERATED KEY IS MEASURED HERE AT ALL

  The issue lists it as open, on the ground that it interacts with #311 - "the
  server emits a textual value without quotes", which would make the answer
  invalid JSON that never reaches the reader. RE-READ AT 7e5e51d, THAT IS NO
  LONGER TRUE: #311 is closed, and `Janus.Server.Resource._PrimaryKeyValueToJson`
  now builds a `TJSONString` for a value that is neither ordinal nor float, so a
  textual key leaves the server correctly quoted. The question is therefore not
  blocked on anything and is answered here: `TNsRoot` is a `Nullable<String>`
  key WITH a `[Sequence]` - a combination that exists nowhere else in this
  repository - and it is reconciled by the same arm as the rest.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Rest.NullableKeyReconciliation;

interface

{$IFNDEF DRIVERRESTFUL}
  {$MESSAGE FATAL 'This unit only makes sense with DRIVERRESTFUL defined. It belongs to Janus.Tests.RESTfulDriver, whose .dproj carries the directive. TRESTObjectSetAdapter is selected by that directive and by nothing else.'}
{$ENDIF}

uses
  Classes,
  SysUtils,
  Generics.Collections,
  DUnitX.TestFramework,
  Janus.Client.Methods,
  Janus.RestFactory.Interfaces,
  Janus.RestObjectSet.Adapter,
  Janus.Types.Nullable,
  Test.Janus.RestConnection.Double,
  Test.Janus.Model.NullableKey;

const
  /// The AutoInc placeholder, the same number
  /// TBind.SetInternalInitFieldDefsObjectClass writes as the DefaultExpression
  /// of an autoinc key.
  cPLACEHOLDER = -1;

  /// The key only the answer can supply. Nothing in this fixture writes it.
  cSERVERKEY = 555;

  /// The 64-bit key. ABOVE High(Integer) on purpose: an arm that quietly did
  /// the 32-bit conversion would come out with a different number rather than
  /// with no number, and only a value outside the 32-bit range says which.
  cSERVERKEY64 = Int64(4294967296) + 555;

  /// The textual key. Not digits - a textual key that happened to be numeric
  /// would also be reconciled by the integer arm of a reader that never looked
  /// at the property, so it would prove nothing about the string arm.
  cSERVERKEYTEXT = 'NS-000555';

  /// The textual placeholder. A Nullable<String> key has no AutoInc
  /// placeholder of its own - nothing writes -1 into a string - so the fixture
  /// supplies a value of its own to be overwritten, which is also what makes
  /// "the answer arrived" distinguishable from "the property was cleared".
  cTEXTPLACEHOLDER = 'PENDING';

  /// The fractional placeholder, for the negative control.
  cDOUBLEPLACEHOLDER = -1.0;

  /// The shipped insert contract for each root: a `result` string and a
  /// `params` array whose single object names the primary key BY PROPERTY NAME.
  /// Janus.Server.Resource.ParseInsert builds exactly this.
  cANSWERNKINTEGER =
    '{"result":"Resource nkroot insert command executed successfully", ' +
    '"params":[{"nk_id":555}]}';

  cANSWERNLINT64 =
    '{"result":"Resource nlroot insert command executed successfully", ' +
    '"params":[{"nl_id":4294967851}]}';

  /// QUOTED, which is what the server emits since #311 -
  /// _PrimaryKeyValueToJson builds a TJSONString for a non-numeric value.
  cANSWERNSSTRING =
    '{"result":"Resource nsroot insert command executed successfully", ' +
    '"params":[{"ns_id":"NS-000555"}]}';

  cANSWERNDDOUBLE =
    '{"result":"Resource ndroot insert command executed successfully", ' +
    '"params":[{"nd_id":555.5}]}';

  /// The three documents that PARSE and still carry no usable key, for the
  /// Nullable integer root. Every param reaches the reader as TEXT -
  /// Janus.Session.RESTful.pas forces `DataType := ftString` on all of them -
  /// so a JSON null arrives as the EMPTY STRING. These are the answers on which
  /// the removed #301 arm would have raised: `SetValueNullable` casts with
  /// `Integer(AValue)`, and none of these three is an Integer.
  cANSWERNKISJSONNULL =
    '{"result":"Resource nkroot insert command executed successfully", ' +
    '"params":[{"nk_id":null}]}';

  cANSWERNKISEMPTY =
    '{"result":"Resource nkroot insert command executed successfully", ' +
    '"params":[{"nk_id":""}]}';

  cANSWERNKISNOTANUMBER =
    '{"result":"Resource nkroot insert command executed successfully", ' +
    '"params":[{"nk_id":"ABC"}]}';

  /// The same three for the 64-bit arm. `9223372036854775808` is High(Int64)
  /// plus one, so it is a NUMBER the target type cannot hold - the one shape
  /// TryStrToInt64 refuses that TryStrToInt would also refuse for a different
  /// reason.
  cANSWERNLOVERFLOWS =
    '{"result":"Resource nlroot insert command executed successfully", ' +
    '"params":[{"nl_id":9223372036854775808}]}';

  /// And for the string arm: an explicitly empty textual key. It must leave the
  /// property alone rather than clear it, which is what `SetValueNullable`
  /// would do on its own - `Nullable<String>.Create(Variant)` treats an empty
  /// variant as "no value".
  cANSWERNSISEMPTY =
    '{"result":"Resource nsroot insert command executed successfully", ' +
    '"params":[{"ns_id":""}]}';

  /// Well formed, right shape, wrong name. Nothing may be stamped from it.
  cANSWERNKNAMINGNOKEY =
    '{"result":"Resource nkroot insert command executed successfully", ' +
    '"params":[{"tag":"555"},{"nk":"111"},{"k_id":"222"}]}';

type
  [TestFixture]
  TTestRestNullableKeyReconciliation = class
  private
    FConn: IRESTConnection;
    FRecorder: TRecordingRestConnection;
    FRoot: TNkRoot;
    function BuildTree: TNkRoot;
    /// Insert the Nullable-integer tree against AAnswer and require that
    /// NOTHING moved, on the root and on the child both. An ERROR rather than a
    /// failure here is the point: the arm must not be able to raise.
    procedure _InsertNkAndExpectThePlaceholder(const AAnswer, AWhy: String);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// THE DEFECT, on the shape `Tcontato` teaches: an INTEGER column carrying
    /// a NULLABLE property.
    [Test]
    procedure Insert_NullableIntegerKeyCarriesTheKeyTheServerGenerated;

    /// And it must have a value, not merely the right number. A Nullable that
    /// was written through some path that left FHasValue clear would answer 555
    /// from `.Value` and still be "absent" to everything that asks properly -
    /// the JSON writer among them.
    [Test]
    procedure Insert_NullableIntegerKeyIsPresentAndNotMerelyEqual;

    /// The cascade runs off the root's key, so a root left at the placeholder
    /// hands the placeholder down. This is the half a consumer sees.
    [Test]
    procedure Insert_NullableChildForeignKeyCarriesTheServerKey;

    /// ORDER. Reading the answer AFTER the cascade would leave the root right
    /// and the child wrong, and only this clause would notice.
    [Test]
    procedure Insert_TheNullableChildIsStampedAfterTheRootWasReconciled;

    /// The 64-bit arm, on a value outside the 32-bit range.
    [Test]
    procedure Insert_NullableInt64KeyCarriesTheKeyTheServerGenerated;

    /// THE OPEN QUESTION THE ISSUE ASKS BY NAME: a TEXTUAL key that IS
    /// generated by a sequence. Nothing else in this repository has that shape.
    [Test]
    procedure Insert_NullableStringKeyCarriesTheKeyTheServerGenerated;

    /// THE NEGATIVE CONTROL, and a CHARACTERISATION rather than an approval:
    /// a Nullable whose element type this reader does not write must come out
    /// untouched. Without it, "handles Nullable" could not be told apart from
    /// "handles every Nullable".
    [Test]
    procedure Insert_NullableDoubleKeyIsNotReconciled;

    /// PERTINENCE. A well formed answer naming something that is not the key
    /// must change nothing at all.
    [Test]
    procedure Insert_AnAnswerThatNamesNoPrimaryKeyLeavesTheNullableAlone;

    /// THE FOUR THAT PARSE AND CARRY NO USABLE KEY. Before #301 no answer of
    /// any shape could reach the client; the repair must not have made any of
    /// these worse than that. These are the clauses the REMOVED arm would have
    /// failed with an ERROR.
    [Test]
    procedure Insert_ANullableKeyThatIsJsonNullLeavesThePlaceholder;
    [Test]
    procedure Insert_ANullableKeyThatIsAnEmptyStringLeavesThePlaceholder;
    [Test]
    procedure Insert_ANullableKeyThatIsNotANumberLeavesThePlaceholder;
    [Test]
    procedure Insert_ANullableInt64KeyThatOverflowsLeavesThePlaceholder;

    /// And the string arm's own version of it: an empty textual key must leave
    /// the property as it was rather than CLEAR it.
    [Test]
    procedure Insert_AnEmptyNullableStringKeyLeavesThePlaceholder;
  end;

implementation

{ TTestRestNullableKeyReconciliation }

procedure TTestRestNullableKeyReconciliation.Setup;
begin
  FRecorder := TRecordingRestConnection.Create;
  FConn := FRecorder;
  FRecorder.Response := cANSWERNKINTEGER;
  FRoot := nil;
end;

procedure TTestRestNullableKeyReconciliation.TearDown;
begin
  FreeAndNil(FRoot);
  FConn := nil;
  FRecorder := nil;
end;

function TTestRestNullableKeyReconciliation.BuildTree: TNkRoot;
var
  LChild: TNkChild;
begin
  Result := TNkRoot.Create;
  Result.nk_id := cPLACEHOLDER;
  Result.tag := 'root';

  LChild := TNkChild.Create;
  LChild.child_id := cPLACEHOLDER;
  LChild.nk_id := cPLACEHOLDER;
  LChild.tag := 'child';
  Result.childs.Add(LChild);
end;

procedure TTestRestNullableKeyReconciliation.Insert_NullableIntegerKeyCarriesTheKeyTheServerGenerated;
var
  LAdapter: TRESTObjectSetAdapter<TNkRoot>;
begin
  FRoot := BuildTree;
  LAdapter := TRESTObjectSetAdapter<TNkRoot>.Create(FConn);
  try
    LAdapter.Insert(FRoot);
  finally
    LAdapter.Free;
  end;
  Assert.AreEqual(cSERVERKEY, FRoot.nk_id.Value,
    'the root must carry the key the answer named. ' + IntToStr(cPLACEHOLDER) +
    ' here means _SetGeneratedKeyValue fell off the end of its case: a ' +
    'Nullable property is tkRecord and the case had no arm for it - issue #317');
end;

procedure TTestRestNullableKeyReconciliation.Insert_NullableIntegerKeyIsPresentAndNotMerelyEqual;
var
  LAdapter: TRESTObjectSetAdapter<TNkRoot>;
begin
  FRoot := BuildTree;
  LAdapter := TRESTObjectSetAdapter<TNkRoot>.Create(FConn);
  try
    LAdapter.Insert(FRoot);
  finally
    LAdapter.Free;
  end;
  Assert.IsTrue(FRoot.nk_id.HasValue,
    'the key must be PRESENT. Nullable<T>.GetValue does not raise when ' +
    'FHasValue is clear - it returns the raw field - so a write that left the ' +
    'flag alone would satisfy the value clause and still render as null in ' +
    'every JSON this object goes into');
  Assert.AreEqual(cSERVERKEY, FRoot.nk_id.Value, 'and it must be the key');
end;

procedure TTestRestNullableKeyReconciliation.Insert_NullableChildForeignKeyCarriesTheServerKey;
var
  LAdapter: TRESTObjectSetAdapter<TNkRoot>;
begin
  FRoot := BuildTree;
  LAdapter := TRESTObjectSetAdapter<TNkRoot>.Create(FConn);
  try
    LAdapter.Insert(FRoot);
  finally
    LAdapter.Free;
  end;
  Assert.AreEqual(cSERVERKEY, FRoot.childs[0].nk_id.Value,
    'the child foreign key must point at the row the server actually wrote. ' +
    IntToStr(cPLACEHOLDER) + ' here is the placeholder cascaded down from a ' +
    'root that was never reconciled');
end;

procedure TTestRestNullableKeyReconciliation.Insert_TheNullableChildIsStampedAfterTheRootWasReconciled;
var
  LAdapter: TRESTObjectSetAdapter<TNkRoot>;
begin
  FRoot := BuildTree;
  LAdapter := TRESTObjectSetAdapter<TNkRoot>.Create(FConn);
  try
    LAdapter.Insert(FRoot);
  finally
    LAdapter.Free;
  end;
  Assert.AreEqual(cSERVERKEY, FRoot.nk_id.Value,
    'the root must have been reconciled BEFORE the cascade ran');
  Assert.AreNotEqual(cPLACEHOLDER, FRoot.childs[0].nk_id.Value,
    'the cascade must have read the RECONCILED root key. The placeholder here ' +
    'means the answer was read after SetAutoIncValueChilds instead of before');
end;

procedure TTestRestNullableKeyReconciliation.Insert_NullableInt64KeyCarriesTheKeyTheServerGenerated;
var
  LAdapter: TRESTObjectSetAdapter<TNlRoot>;
  LRoot: TNlRoot;
begin
  FRecorder.Response := cANSWERNLINT64;
  LRoot := TNlRoot.Create;
  try
    LRoot.nl_id := Int64(cPLACEHOLDER);
    LRoot.tag := 'wide';
    LAdapter := TRESTObjectSetAdapter<TNlRoot>.Create(FConn);
    try
      LAdapter.Insert(LRoot);
    finally
      LAdapter.Free;
    end;
    Assert.AreEqual(cSERVERKEY64, LRoot.nl_id.Value,
      'a 64-bit Nullable key must arrive whole. A value that came back as ' +
      '555 would mean the text went through a 32-bit conversion and the high ' +
      'word was dropped');
  finally
    LRoot.Free;
  end;
end;

procedure TTestRestNullableKeyReconciliation.Insert_NullableStringKeyCarriesTheKeyTheServerGenerated;
var
  LAdapter: TRESTObjectSetAdapter<TNsRoot>;
  LRoot: TNsRoot;
begin
  FRecorder.Response := cANSWERNSSTRING;
  LRoot := TNsRoot.Create;
  try
    LRoot.ns_id := cTEXTPLACEHOLDER;
    LRoot.tag := 'text';
    LAdapter := TRESTObjectSetAdapter<TNsRoot>.Create(FConn);
    try
      LAdapter.Insert(LRoot);
    finally
      LAdapter.Free;
    end;
    Assert.AreEqual(cSERVERKEYTEXT, LRoot.ns_id.Value, False,
      'a TEXTUAL key generated by a sequence is the shape issue #317 leaves ' +
      'open. It is not blocked on #311 any more: that issue is closed and ' +
      '_PrimaryKeyValueToJson now emits a quoted JSON string, so the answer ' +
      'parses and the key reaches the reader');
    Assert.IsTrue(LRoot.ns_id.HasValue, 'and it must be present');
  finally
    LRoot.Free;
  end;
end;

procedure TTestRestNullableKeyReconciliation.Insert_NullableDoubleKeyIsNotReconciled;
var
  LAdapter: TRESTObjectSetAdapter<TNdRoot>;
  LRoot: TNdRoot;
begin
  FRecorder.Response := cANSWERNDDOUBLE;
  LRoot := TNdRoot.Create;
  try
    LRoot.nd_id := cDOUBLEPLACEHOLDER;
    LRoot.tag := 'frac';
    LAdapter := TRESTObjectSetAdapter<TNdRoot>.Create(FConn);
    try
      LAdapter.Insert(LRoot);
    finally
      LAdapter.Free;
    end;
    Assert.AreEqual(cDOUBLEPLACEHOLDER, LRoot.nd_id.Value, 0.000001,
      'CHARACTERISATION, not approval: the reader writes Nullable<Integer>, ' +
      'Nullable<Int64> and Nullable<String> and nothing else, so a fractional ' +
      'Nullable key keeps the placeholder. This clause is what keeps that ' +
      'SCOPE measured instead of merely asserted in a comment - a reader that ' +
      'grew a float arm without a fixture for it would redden here');
  finally
    LRoot.Free;
  end;
end;

procedure TTestRestNullableKeyReconciliation.Insert_AnAnswerThatNamesNoPrimaryKeyLeavesTheNullableAlone;
var
  LAdapter: TRESTObjectSetAdapter<TNkRoot>;
begin
  FRecorder.Response := cANSWERNKNAMINGNOKEY;
  FRoot := BuildTree;
  LAdapter := TRESTObjectSetAdapter<TNkRoot>.Create(FConn);
  try
    LAdapter.Insert(FRoot);
  finally
    LAdapter.Free;
  end;
  Assert.AreEqual(cPLACEHOLDER, FRoot.nk_id.Value,
    'not one of `tag`, `nk`, `k_id` IS `nk_id`. 555 here means the reader ' +
    'took whatever came first; 111 means it compared prefixes; 222 means it ' +
    'asked Pos() instead of asking for equality. The three names are graded ' +
    'for exactly that reason, the way the #301 fixture grades its own');
  Assert.AreEqual('root', FRoot.tag, False,
    'and `tag` itself must not have been overwritten either');
end;

procedure TTestRestNullableKeyReconciliation._InsertNkAndExpectThePlaceholder(
  const AAnswer, AWhy: String);
var
  LAdapter: TRESTObjectSetAdapter<TNkRoot>;
begin
  FRecorder.Response := AAnswer;
  FRoot := BuildTree;
  LAdapter := TRESTObjectSetAdapter<TNkRoot>.Create(FConn);
  try
    // An ERROR rather than a failure on the next line is the whole point of
    // these clauses: the arm must not be able to raise on an answer it cannot
    // use. That is the rule under which #301 removed its own Nullable arm.
    LAdapter.Insert(FRoot);
  finally
    LAdapter.Free;
  end;
  Assert.AreEqual(cPLACEHOLDER, FRoot.nk_id.Value, AWhy);
  Assert.AreEqual(cPLACEHOLDER, FRoot.childs[0].nk_id.Value,
    AWhy + ' - and the cascade must have handed the unchanged value down');
end;

procedure TTestRestNullableKeyReconciliation.Insert_ANullableKeyThatIsJsonNullLeavesThePlaceholder;
begin
  _InsertNkAndExpectThePlaceholder(cANSWERNKISJSONNULL,
    'a JSON null carries no key, and reaches the reader as the EMPTY STRING ' +
    'because the parser forces ftString on every param. Handed straight to ' +
    'SetValueNullable it would reach `Integer(AValue)` and raise');
end;

procedure TTestRestNullableKeyReconciliation.Insert_ANullableKeyThatIsAnEmptyStringLeavesThePlaceholder;
begin
  _InsertNkAndExpectThePlaceholder(cANSWERNKISEMPTY,
    'an explicitly empty string carries no key either, and arrives ' +
    'indistinguishable from the JSON null above');
end;

procedure TTestRestNullableKeyReconciliation.Insert_ANullableKeyThatIsNotANumberLeavesThePlaceholder;
begin
  _InsertNkAndExpectThePlaceholder(cANSWERNKISNOTANUMBER,
    'a quoted non numeric value parses cleanly and converts to nothing. This ' +
    'is the exact document on which the arm #301 removed would have raised ' +
    '`Could not convert variant of type (UnicodeString) into type (Integer)`');
end;

procedure TTestRestNullableKeyReconciliation.Insert_ANullableInt64KeyThatOverflowsLeavesThePlaceholder;
var
  LAdapter: TRESTObjectSetAdapter<TNlRoot>;
  LRoot: TNlRoot;
begin
  FRecorder.Response := cANSWERNLOVERFLOWS;
  LRoot := TNlRoot.Create;
  try
    LRoot.nl_id := Int64(cPLACEHOLDER);
    LRoot.tag := 'wide';
    LAdapter := TRESTObjectSetAdapter<TNlRoot>.Create(FConn);
    try
      LAdapter.Insert(LRoot);
    finally
      LAdapter.Free;
    end;
    Assert.AreEqual(Int64(cPLACEHOLDER), LRoot.nl_id.Value,
      'High(Int64) plus one is a NUMBER the target cannot hold. TryStrToInt64 ' +
      'refuses it, so the property is left alone rather than the save ending ' +
      'in an exception');
  finally
    LRoot.Free;
  end;
end;

procedure TTestRestNullableKeyReconciliation.Insert_AnEmptyNullableStringKeyLeavesThePlaceholder;
var
  LAdapter: TRESTObjectSetAdapter<TNsRoot>;
  LRoot: TNsRoot;
begin
  FRecorder.Response := cANSWERNSISEMPTY;
  LRoot := TNsRoot.Create;
  try
    LRoot.ns_id := cTEXTPLACEHOLDER;
    LRoot.tag := 'text';
    LAdapter := TRESTObjectSetAdapter<TNsRoot>.Create(FConn);
    try
      LAdapter.Insert(LRoot);
    finally
      LAdapter.Free;
    end;
    Assert.AreEqual(cTEXTPLACEHOLDER, LRoot.ns_id.Value, False,
      'an empty textual key must LEAVE the property, not clear it. Handed ' +
      'straight to SetValueNullable the empty variant would go through ' +
      'Nullable<String>.Create(Variant), whose VarIsNullOrEmpty test clears ' +
      'the record - so the object would come out of the insert holding LESS ' +
      'than it went in with');
    Assert.IsTrue(LRoot.ns_id.HasValue,
      'and it must still be present, which is the half a value comparison ' +
      'alone cannot see');
  finally
    LRoot.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRestNullableKeyReconciliation);

end.
