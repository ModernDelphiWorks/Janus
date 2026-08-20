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

  EVERY BRANCH THE REPAIR ADDS DIES UNDER MUTATION

  Nine mutations, each applied with a MESSAGE WARN directive on the mutated line
  that the build echoed back as W1054 - a run whose patch cannot be shown to
  have landed measures nothing - and each run over the whole project at
  total=212. (The directive is named here WITHOUT its braces on purpose: this
  header is itself a brace comment, and writing the directive out closes the
  comment at its first closing brace. Measured the hard way, one build.)

    the whole `tkRecord` arm removed           6 red
    the `Nullable<Integer>` arm removed        4 red
    the `Nullable<Int64>` arm removed          1 red
    the `Nullable<String>` arm removed         1 red
    the `TryStrToInt` guard dropped            3 ERRORS, and the message is the
                                               one #301 feared verbatim: `Could
                                               not convert variant of type
                                               (UnicodeString) into type
                                               (Integer)`
    the `TryStrToInt64` guard dropped          1 red
    the empty-text guard on the string arm     1 red
    the 64-bit arm narrowed to 32 bits         1 red
    a `Nullable<Double>` arm ADDED             1 red - the negative control,
                                               which is how it is shown not to
                                               be decorative

  THE FIFTH OF THOSE IS THE WHOLE ARGUMENT FOR THE DESIGN, RUN RATHER THAN
  ASSERTED. Removing the parse and handing the text straight to
  `SetValueNullable` reproduces exactly the exception under which #301 deleted
  its own Nullable arm. The arm as written cannot reach it, because the value
  `SetValueNullable` receives has already been proved to be of the element type
  by the same comparison that chose the element type.

  FOUR CLAUSES HERE ARE NOT ABOUT NULLABLE AT ALL

  `Insert_ABareStringGeneratedKey...`, `Insert_AnEmptyBareStringKey...`,
  `Insert_ABareInt64GeneratedKey...` and `Insert_ABareInt64KeyThatOverflows...`
  drive the ORDINAL arms #301 wrote. They are here because #301 listed FIVE
  mutations of its own reader as surviving, all for one reason - the project had
  no entity of the right key shape reachable from an ObjectSet insert - and
  because supplying exactly those shapes is what this branch had to do anyway.
  Four of the five now die. The fifth, the IsWritable guard, still survives and
  still should: no key property in this project is read-only. The re-measurement
  is written out in `Test.Janus.Rest.ObjectSetInsertKey`'s header, where the
  original claim lives.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Rest.NullableKeyReconciliation;

interface

{$IFNDEF DRIVERRESTFUL}
  {$MESSAGE FATAL 'This unit only makes sense with DRIVERRESTFUL defined. It belongs to Janus.Tests.RESTfulDriver, whose .dproj carries the directive. TRESTObjectSetAdapter is selected by that directive and by nothing else.'}
{$ENDIF}

uses
  DB,
  Classes,
  SysUtils,
  DBClient,
  Generics.Collections,
  DUnitX.TestFramework,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Param,
  FireDAC.Stan.Error,
  FireDAC.DatS,
  FireDAC.Phys.Intf,
  FireDAC.DApt.Intf,
  FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  Janus.Client.Methods,
  Janus.RestFactory.Interfaces,
  Janus.RestObjectSet.Adapter,
  Janus.RestDataSet.FDMemTable,
  Janus.RestDataSet.ClientDataSet,
  Janus.Types.Nullable,
  Test.Janus.RestConnection.Double,
  /// TReplayRestConnection and the TMemApply cracker, both declared in that
  /// unit's INTERFACE. Reused rather than copied for the reason its own header
  /// gives about doubles: the DataSet family answers a POST and may then answer
  /// a GET, which TRecordingRestConnection cannot express - and a fourth double
  /// saying the same thing is how doubles grow apart.
  Test.Janus.Rest.ReReadAfterInsert,
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

  /// The same for the DataSet family, INTEGRAL on purpose. That side writes the
  /// answer text onto a TFloatField, so whether a fractional part survives
  /// depends on the machine's decimal separator - a question about the wire
  /// format of #311, not about this issue. Kept out of the measurement.
  cANSWERNDINTEGRAL =
    '{"result":"Resource ndroot insert command executed successfully", ' +
    '"params":[{"nd_id":555}]}';

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

  /// The two BARE-typed roots that exist to close mutations the #301 fixture
  /// lists as surviving - see the header note THE FOUR CLAUSES THAT ARE NOT
  /// ABOUT NULLABLE AT ALL.
  cANSWERNBSTRING =
    '{"result":"Resource nbroot insert command executed successfully", ' +
    '"params":[{"nb_id":"NB-000555"}]}';

  cANSWERNBISEMPTY =
    '{"result":"Resource nbroot insert command executed successfully", ' +
    '"params":[{"nb_id":""}]}';

  cSERVERKEYBARETEXT = 'NB-000555';
  cBARETEXTPLACEHOLDER = 'PENDING-BARE';

  cANSWERNIINT64 =
    '{"result":"Resource niroot insert command executed successfully", ' +
    '"params":[{"ni_id":4294967851}]}';

  cANSWERNIOVERFLOWS =
    '{"result":"Resource niroot insert command executed successfully", ' +
    '"params":[{"ni_id":9223372036854775808}]}';

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

    /// THE FOUR CLAUSES THAT ARE NOT ABOUT NULLABLE AT ALL. They drive the
    /// ORDINAL arms #301 wrote and could not hold honest, and they exist
    /// because this branch had to supply the missing key shapes anyway. Each is
    /// paired with one of the FIVE MUTATIONS Test.Janus.Rest.ObjectSetInsertKey
    /// lists as surviving; four of the five die here. See that unit's header.
    [Test]
    procedure Insert_ABareStringGeneratedKeyCarriesTheKeyTheServerGenerated;
    [Test]
    procedure Insert_AnEmptyBareStringKeyLeavesThePlaceholder;
    [Test]
    procedure Insert_ABareInt64GeneratedKeyCarriesTheKeyTheServerGenerated;
    [Test]
    procedure Insert_ABareInt64KeyThatOverflowsLeavesThePlaceholder;
  end;

  /// <summary> THE OTHER OPEN QUESTION OF ISSUE #317: does the DataSet half of
  ///  the REST client have the same gap? The issue records it as NOT MEASURED.
  ///  It is measured here, and the answer is NO - for a reason worth writing
  ///  down, because it is what decides that the repair does NOT belong on that
  ///  side.
  ///
  ///  THE TWO FAMILIES DO NOT SHARE THE MECHANISM. The ObjectSet reader,
  ///  TRESTObjectSetAdapter<M>._SetGeneratedKeyValue, writes a typed PROPERTY
  ///  through RTTI, so the property's declared type is the thing it has to
  ///  dispatch on and a Nullable is a record it had no arm for. The DataSet
  ///  reader, TRESTDataSetAdapter<M>.ApplyInserter, does
  ///  `LField.Value := LParam.Value` onto the row under the cursor: it writes a
  ///  FIELD, whose DataType came from the [Column] attribute, and the property
  ///  behind that column is never consulted at that moment at all. So the
  ///  Nullable is INVISIBLE to it, and there is nothing there to repair.
  ///
  ///  A CLAIM SHAPED LIKE THAT IS EXACTLY THE ONE THIS REPOSITORY HAS BEEN
  ///  BITTEN BY - "it is the same as the sibling", asserted and not run. So the
  ///  clauses below drive the DataSet family over the same entities, AND THE
  ///  MEASUREMENT WAS TAKEN TWICE: once with the ObjectSet repair in place, and
  ///  once with Janus.RestObjectSet.Adapter.pas checked out at its 7e5e51d text
  ///  and the project rebuilt. Both runs, this fixture: 5 tests, 0 failures,
  ///  0 errors. In the second run the OTHER fixture in this unit went 13/6/0 -
  ///  so the probe was not blind, and "the DataSet family never had this gap"
  ///  is a measurement with a positive control rather than an argument.
  ///
  ///  AND ONE OF THEM REACHES A SHAPE THE OBJECTSET SIDE DOES NOT.
  ///  Nullable&lt;Double&gt; is the negative control of the fixture above - the
  ///  ObjectSet reader leaves it on the placeholder. Here it is stamped. The
  ///  two families therefore disagree about a fractional key today, and that is
  ///  recorded rather than repaired: closing it means giving the ObjectSet
  ///  reader a float arm, which the issue does not ask for and which no
  ///  Examples model with a [Sequence] motivates.
  ///
  ///  SO THE ANSWER TO THE ISSUE'S QUESTION IS PARTIAL, AND THE PART THAT IS
  ///  MISSING IS MISSING FOR A MEASURED REASON. Nullable&lt;Integer&gt; and
  ///  Nullable&lt;Double&gt; are measured and arrive. A generated TEXTUAL key -
  ///  Nullable or not - IS NOT MEASURED HERE AT ALL, because the adapter for it
  ///  CANNOT BE CONSTRUCTED: TBind.SetInternalInitFieldDefsObjectClass writes
  ///  `DefaultExpression := '-1'` onto EVERY column of an AutoIncrement primary
  ///  key without looking at the column's type, and both concrete adapters of
  ///  the family refuse it on a string field -
  ///  `[FireDAC][Stan][Eval]-104. Type mismatch in expression` from the
  ///  FDMemTable one, `Preparation of default expression failed with error
  ///  "Type mismatch in expression"` from the ClientDataSet one. Three clauses
  ///  below pin that, and TWO of them are controls: `TNbRoot` is a BARE String
  ///  key with no Nullable anywhere and fails identically, and the second
  ///  adapter fails identically too. So the finding is about a GENERATED
  ///  TEXTUAL key in the DataSet family; it is neither a Nullable question nor
  ///  one adapter being fussy.
  ///
  ///  IT IS NOT REPAIRED HERE, on purpose. The write is in Janus.Bind, which
  ///  every family and all five test projects compile, and the mechanism is
  ///  field-def construction rather than answer reading - a different piece of
  ///  work from the one #317 asks for. `TKeyTypeGuid` shows the shape is
  ///  supported elsewhere in the framework: a String key with
  ///  TGeneratorType.Guid38Inc.
  ///
  ///  NOT MEASURED: a fractional key with a FRACTIONAL PART. The float value
  ///  below is integral on purpose. `LField.Value := LParam.Value` hands TEXT to
  ///  a TFloatField, and whether '555.5' converts depends on the machine's
  ///  decimal separator, which is a question about #311's wire format and not
  ///  about this issue. </summary>
  [TestFixture]
  TTestRestNullableKeyDataSetFamily = class
  private
    FRep: TReplayRestConnection;
    FConn: IRESTConnection;
    FMem: TFDMemTable;
    FNkAdapter: TRESTFDMemTableAdapter<TNkRoot>;
    FNsAdapter: TRESTFDMemTableAdapter<TNsRoot>;
    FNbAdapter: TRESTFDMemTableAdapter<TNbRoot>;
    FCds: TClientDataSet;
    FNsCdsAdapter: TRESTClientDataSetAdapter<TNsRoot>;
    FNdAdapter: TRESTFDMemTableAdapter<TNdRoot>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure DataSet_NullableIntegerKeyIsStampedOnTheRow;

    /// THE NEIGHBOURING DEFECT, characterised and not repaired - see the
    /// header. A generated TEXTUAL key cannot reach the reader at all.
    [Test]
    procedure DataSet_ATextualGeneratedKeyCannotEvenBeAppended;
    /// The POSITIVE CONTROL for it: a BARE String key fails identically, so the
    /// defect is not about Nullable.
    [Test]
    procedure Control_ABareStringGeneratedKeyCannotBeAppendedEither;
    /// The SECOND positive control: the same wall stands on the OTHER concrete
    /// adapter of the family, so the shape is unreachable on this side full
    /// stop - not an FDMemTable quirk.
    [Test]
    procedure Control_TheSameWallStandsOnTheClientDataSetAdapter;

    /// The divergence, stated as a clause: the shape the ObjectSet reader
    /// leaves alone is one this family already writes.
    [Test]
    procedure DataSet_NullableDoubleKeyIsStampedOnTheRow;
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

procedure TTestRestNullableKeyReconciliation.Insert_ABareStringGeneratedKeyCarriesTheKeyTheServerGenerated;
var
  LAdapter: TRESTObjectSetAdapter<TNbRoot>;
  LRoot: TNbRoot;
begin
  FRecorder.Response := cANSWERNBSTRING;
  LRoot := TNbRoot.Create;
  try
    LRoot.nb_id := cBARETEXTPLACEHOLDER;
    LRoot.tag := 'bare';
    LAdapter := TRESTObjectSetAdapter<TNbRoot>.Create(FConn);
    try
      LAdapter.Insert(LRoot);
    finally
      LAdapter.Free;
    end;
    Assert.AreEqual(cSERVERKEYBARETEXT, LRoot.nb_id, False,
      'THE ORDINAL STRING ARM, which #301 wrote and listed as unheld: "the ' +
      'whole string branch removed" survived there because the only textual ' +
      'key reachable from an ObjectSet insert in this project was TStrMaster, ' +
      'which carries no [Sequence] so the block is never entered for it. ' +
      'TNbRoot is a bare String key WITH a [Sequence] - the shape #301 said ' +
      'would have to be invented - and this clause is what kills that mutation');
  finally
    LRoot.Free;
  end;
end;

procedure TTestRestNullableKeyReconciliation.Insert_AnEmptyBareStringKeyLeavesThePlaceholder;
var
  LAdapter: TRESTObjectSetAdapter<TNbRoot>;
  LRoot: TNbRoot;
begin
  FRecorder.Response := cANSWERNBISEMPTY;
  LRoot := TNbRoot.Create;
  try
    LRoot.nb_id := cBARETEXTPLACEHOLDER;
    LRoot.tag := 'bare';
    LAdapter := TRESTObjectSetAdapter<TNbRoot>.Create(FConn);
    try
      LAdapter.Insert(LRoot);
    finally
      LAdapter.Free;
    end;
    Assert.AreEqual(cBARETEXTPLACEHOLDER, LRoot.nb_id, False,
      'and the `if LText <> ''''` INSIDE that arm - #301 listed its removal as ' +
      'a second surviving mutation. An empty answer must leave the key, not ' +
      'blank it: a JSON null and an empty string are indistinguishable here ' +
      'because the parser forces ftString on every param');
  finally
    LRoot.Free;
  end;
end;

procedure TTestRestNullableKeyReconciliation.Insert_ABareInt64GeneratedKeyCarriesTheKeyTheServerGenerated;
var
  LAdapter: TRESTObjectSetAdapter<TNiRoot>;
  LRoot: TNiRoot;
begin
  FRecorder.Response := cANSWERNIINT64;
  LRoot := TNiRoot.Create;
  try
    LRoot.ni_id := cPLACEHOLDER;
    LRoot.tag := 'wide';
    LAdapter := TRESTObjectSetAdapter<TNiRoot>.Create(FConn);
    try
      LAdapter.Insert(LRoot);
    finally
      LAdapter.Free;
    end;
    Assert.AreEqual(cSERVERKEY64, LRoot.ni_id,
      'THE ORDINAL tkInt64 ARM, the third of #301''s five surviving ' +
      'mutations. It survived because no entity reachable from an ObjectSet ' +
      'insert in this project had a 64-bit key; TNiRoot is one. The value is ' +
      'above High(Integer) so a 32-bit conversion would be visible as a ' +
      'different number rather than as no number');
  finally
    LRoot.Free;
  end;
end;

procedure TTestRestNullableKeyReconciliation.Insert_ABareInt64KeyThatOverflowsLeavesThePlaceholder;
var
  LAdapter: TRESTObjectSetAdapter<TNiRoot>;
  LRoot: TNiRoot;
begin
  FRecorder.Response := cANSWERNIOVERFLOWS;
  LRoot := TNiRoot.Create;
  try
    LRoot.ni_id := cPLACEHOLDER;
    LRoot.tag := 'wide';
    LAdapter := TRESTObjectSetAdapter<TNiRoot>.Create(FConn);
    try
      LAdapter.Insert(LRoot);
    finally
      LAdapter.Free;
    end;
    Assert.AreEqual(Int64(cPLACEHOLDER), LRoot.ni_id,
      'and its TryStrToInt64 guard, the fourth. #301 measured that dropping ' +
      'it back to TParam.AsLargeInt changed nothing; with a 64-bit key in the ' +
      'project it does - High(Int64) plus one is a number the target cannot ' +
      'hold, and the guard is what leaves the key alone instead');
  finally
    LRoot.Free;
  end;
end;

{ TTestRestNullableKeyDataSetFamily }

procedure TTestRestNullableKeyDataSetFamily.Setup;
begin
  FRep := TReplayRestConnection.Create;
  FConn := FRep;
  FMem := nil;
  FNkAdapter := nil;
  FNsAdapter := nil;
  FNbAdapter := nil;
  FCds := nil;
  FNsCdsAdapter := nil;
  FNdAdapter := nil;
end;

procedure TTestRestNullableKeyDataSetFamily.TearDown;
begin
  FreeAndNil(FNdAdapter);
  FreeAndNil(FNsCdsAdapter);
  FreeAndNil(FCds);
  FreeAndNil(FNbAdapter);
  FreeAndNil(FNsAdapter);
  FreeAndNil(FNkAdapter);
  FreeAndNil(FMem);
  FConn := nil;
  FRep := nil;
end;

procedure TTestRestNullableKeyDataSetFamily.DataSet_NullableIntegerKeyIsStampedOnTheRow;
begin
  FRep.PostAnswer := cANSWERNKINTEGER;
  FMem := TFDMemTable.Create(nil);
  FNkAdapter := TRESTFDMemTableAdapter<TNkRoot>.Create(FConn, FMem, -1, nil);
  FMem.Append;
  FMem.FieldByName('nk_id').AsInteger := cPLACEHOLDER;
  FMem.FieldByName('tag').AsString := 'root';
  FMem.Post;
  TMemApply<TNkRoot>.Apply(FNkAdapter);
  FMem.First;
  Assert.AreEqual(cSERVERKEY, FMem.FieldByName('nk_id').AsInteger,
    'the DataSet family writes the answer onto the FIELD, whose DataType came ' +
    'from [Column(''nk_id'', ftInteger)]. The Nullable on the property is not ' +
    'consulted at that moment, so this side never had the #317 gap - and this ' +
    'clause is what makes that a measurement instead of an assertion');
end;

procedure TTestRestNullableKeyDataSetFamily.DataSet_ATextualGeneratedKeyCannotEvenBeAppended;
begin
  FMem := TFDMemTable.Create(nil);
  Assert.WillRaise(
    procedure
    begin
      FNsAdapter := TRESTFDMemTableAdapter<TNsRoot>.Create(FConn, FMem, -1, nil);
      FMem.Append;
    end,
    nil,
    'CHARACTERISATION of a defect this branch measured and did NOT repair. ' +
    'TBind.SetInternalInitFieldDefsObjectClass writes DefaultExpression ' +
    '''-1'' onto every column of an AutoIncrement primary key without ' +
    'looking at the column''s type, and FireDAC evaluating that on a string ' +
    'field raises [Stan][Eval]-104 Type mismatch in expression - on the ' +
    'APPEND, before any answer is read. If this clause ever goes green the ' +
    'defect was fixed somewhere and the three clauses around it should be ' +
    'revisited, starting with the one that clears the expression by hand');
end;

procedure TTestRestNullableKeyDataSetFamily.Control_ABareStringGeneratedKeyCannotBeAppendedEither;
begin
  FMem := TFDMemTable.Create(nil);
  Assert.WillRaise(
    procedure
    begin
      FNbAdapter := TRESTFDMemTableAdapter<TNbRoot>.Create(FConn, FMem, -1, nil);
      FMem.Append;
    end,
    nil,
    'THE POSITIVE CONTROL. TNbRoot carries a BARE String key - no Nullable ' +
    'anywhere in it - and fails the same way. Without this clause the finding ' +
    'above would read as "a Nullable textual key is broken", which is not what ' +
    'was measured: what is broken is a GENERATED TEXTUAL key on this side of ' +
    'the family, Nullable or not');
end;

procedure TTestRestNullableKeyDataSetFamily.Control_TheSameWallStandsOnTheClientDataSetAdapter;
begin
  Assert.WillRaise(
    procedure
    begin
      FCds := TClientDataSet.Create(nil);
      FNsCdsAdapter := TRESTClientDataSetAdapter<TNsRoot>.Create(FConn, FCds,
                         -1, nil);
      FCds.Append;
    end,
    nil,
    'THE SECOND POSITIVE CONTROL, and it is what turns the finding from "the ' +
    'FDMemTable adapter is fussy" into "this shape is unreachable on the ' +
    'DataSet side". TClientDataSet refuses the same DefaultExpression with a ' +
    'message of its own - `Preparation of default expression failed with ' +
    'error "Type mismatch in expression"` - so BOTH concrete adapters of the ' +
    'family are shut. The consequence for issue #317 is stated plainly: the ' +
    'DataSet reader''s behaviour for a generated TEXTUAL key is NOT MEASURED ' +
    'by this branch, because there is no door into it that does not first ' +
    'repair Janus.Bind');
end;

procedure TTestRestNullableKeyDataSetFamily.DataSet_NullableDoubleKeyIsStampedOnTheRow;
begin
  FRep.PostAnswer := cANSWERNDINTEGRAL;
  FMem := TFDMemTable.Create(nil);
  FNdAdapter := TRESTFDMemTableAdapter<TNdRoot>.Create(FConn, FMem, -1, nil);
  FMem.Append;
  FMem.FieldByName('nd_id').AsFloat := cDOUBLEPLACEHOLDER;
  FMem.FieldByName('tag').AsString := 'frac';
  FMem.Post;
  TMemApply<TNdRoot>.Apply(FNdAdapter);
  FMem.First;
  Assert.AreEqual(Double(cSERVERKEY), FMem.FieldByName('nd_id').AsFloat,
    0.000001,
    'THE DIVERGENCE, stated rather than repaired: this is the very shape ' +
    'NullableDoubleKeyIsNotReconciled requires the ObjectSet reader to leave ' +
    'alone. The two families disagree about a fractional key today, because ' +
    'one dispatches on the property type and the other does not dispatch at all');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRestNullableKeyReconciliation);
  TDUnitX.RegisterTestFixture(TTestRestNullableKeyDataSetFamily);

end.
