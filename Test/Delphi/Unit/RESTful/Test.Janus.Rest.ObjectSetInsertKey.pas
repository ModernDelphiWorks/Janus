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

{ @abstract(Janus Framework - the REST ObjectSet family reads the key the server
  generated. Issue #301.)

  WHAT WAS WRONG

  TRESTObjectSetAdapter<M>.Insert POSTed the aggregate and then, inside
  `if FSession.ExistSequence`, went straight to SetAutoIncValueChilds. It never
  read FSession.ResultParams. So the answer - which under the shipped contract
  (Janus.Server.Resource.pas, cRESOURCEINSERT) names the ROOT's primary key -
  was parsed by TSessionRestFul<M>.Insert, stored in ResultParams, and thrown
  away. The client kept:

    aitroot.root_id  = the AutoInc PLACEHOLDER   (the answer was discarded)
    aitmid.root_id   = the SAME placeholder      (the cascade copied it down)

  MEASURED, and the anchor is reachable: at commit 16f3279 - the first nine of
  these clauses, with NO source change - Janus.Tests.RESTfulDriver came out
  total=96 failures=3, and the two lines above printed -1 while the answer said
  555. The basal one commit below it was total=87 failures=0.

  (The figure first carried the anchor ceebdbe, which is ORPHANED - do not go
  looking for it. A rebase dropped it the same afternoon it was written, and a
  dead anchor does not announce itself, it just quietly stops being checkable.
  16f3279 is the rebased twin and is the one to use.)

  READING THE ANSWER MUST NOT HAVE BOUGHT AN EXCEPTION

  Before #301 nothing read this answer, so no answer of any shape could make an
  insert fail. The first repair did buy one: it guarded with VarIsNull/VarIsEmpty
  and then handed the value to TParam.AsInteger, and since the parser forces
  every param to ftString the guard could not fire and the conversion raised.
  Measured at 9096e62 - this fixture over that reader - total=102 ERRORS=3, all
  three saying `Could not convert variant of type (UnicodeString) into type
  (Integer)`. Measured against the adapter as it SHIPPED, at 865370e:
  total=102 errors=0 failures=5 - five things wrong and nothing raised, which is
  the bar the repair had to clear and did not.

  So three clauses below drive documents that PARSE and still carry no usable
  key - a JSON null, an empty string, a quoted non-number - and require that the
  placeholder simply stands. They are not about the key arriving; they are about
  the save not ending in an exception. cMALFORMEDANSWER cannot stand in for
  them: that document does not parse, so the reader is never even reached.

  This is NOT issue #297. There the DataSet family DID stamp the root and the
  gap was levels two and three; here the root itself was never reconciled, so
  the cascade did not merely lag - it propagated a number that exists nowhere.

  WHY THE ROOT'S OWN KEY IS THE ONLY THING STAMPED

  Because it is the only thing the answer carries. The producer is a loop over
  the PRIMARY KEY COLUMNS of the inserted entity, naming each by
  ColumnProperty.Name; nothing below the root is named. So the reader is
  PK-scoped and name-matched on purpose, and
  AnswerThatNamesNoPrimaryKeyLeavesThePlaceholder is what holds it to that: an
  answer that names something else must change nothing at all.

  WHAT IS STILL NOT RECONCILED, AND IS NOT THIS ISSUE

  The mid's OWN key, and the leaf's. That is the ObjectSet counterpart of #297,
  and the DataSet repair for it (a re-read after the POST) has no counterpart
  here yet. Two tests below pin the CURRENT reading of that so a later change
  cannot move it silently:
  ChildOwnKeyIsNotReconciled and GrandchildIsNotReachedByThisCascade.

  WHY THE ASSERTIONS NAME NUMBERS AND NOT "NOTHING RAISED"

  Every clause below states the value of a key, on the root AND on the child.
  555 is a number only the answer could have supplied; -1 is what the client
  had. A test that only checked "no exception" would have been green throughout
  the whole life of the defect.

  WHAT THIS FIXTURE DOES NOT PIN - FIVE SURVIVING MUTATIONS, OF WHICH FOUR HAVE
  SINCE BEEN CLOSED

  Each was applied, compiled with a $MESSAGE WARN directive on the mutated line
  so the build proves the patch landed, and run. All five came out total=102
  errors=0 failures=0 at the time - green, meaning nothing anywhere noticed
  them:

    the IsWritable guard removed
    the whole string branch removed
    the empty-string check inside the string branch removed
    the TryStrToInt64 guard removed, back to TParam.AsLargeInt
    the whole tkInt64 branch removed

  ONE ENUMERATION EXPLAINED ALL FIVE, AND THE ENUMERATION HAS MOVED. What it
  said was that under Test/Delphi there were 39 entities carrying a
  [PrimaryKey], 40 key properties among them, no read-only key property, no
  Int64 key in the WHOLE repository, and exactly ONE non-numeric key -
  TStrMaster, which carries no [Sequence] so ExistSequence is False and the
  block is never entered for it. Two of those four facts were ALREADY FALSE
  before this paragraph was rewritten, having been falsified in place by issues
  that never touched this file: #311 added Test.Janus.Model.KeyTypes, which
  carries Int64, UInt64, textual, GUID-shaped, date, float and Nullable keys.
  They were false and nothing said so, which is exactly how a count goes stale.

  FOUR OF THE FIVE ARE NOW DEAD, and killed by clauses rather than by argument.
  Issue #317 had to supply the missing key shapes for this project anyway, and
  put them in Test.Janus.Model.NullableKey: TNbRoot is a bare String key WITH a
  [Sequence] and TNiRoot is a bare Int64 key with one. Four clauses in
  Test.Janus.Rest.NullableKeyReconciliation drive them through this very reader,
  and re-running the five mutations against the project as it now stands - each
  with the same $MESSAGE WARN proof, all at total=212 - gives:

    the IsWritable guard removed             SURVIVES, 212/0/0
    the whole string branch removed          DIES, Insert_ABareStringGeneratedKey...
    the empty-string check removed           DIES, Insert_AnEmptyBareStringKey...
    the TryStrToInt64 guard removed          DIES, Insert_ABareInt64KeyThatOverflows...
    the whole tkInt64 branch removed         DIES, Insert_ABareInt64GeneratedKey...

  THE ONE THAT SURVIVES SURVIVES FOR THE ORIGINAL REASON, RE-MEASURED: of the
  key properties reachable from an ObjectSet insert in this project, NONE is
  read-only. A key that cannot be written is a shape the test tree does not
  have and that a fixture would have to invent, and a fixture modelling
  something impossible teaches the next reader something false. That one stays
  open on purpose.

  THE SENTENCE THIS PARAGRAPH USED TO END WITH IS ALSO WITHDRAWN. It said
  closing these meant inventing a fixture for "a string key generated by a
  sequence" and that Examples/ carried no such thing. The second half was
  right about Examples/ and the first half was wrong about the framework:
  TKeyTypeGuid is a String key with TGeneratorType.Guid38Inc, so the shape was
  never impossible - only absent.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Rest.ObjectSetInsertKey;

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
  Test.Janus.RestConnection.Double,
  Test.Janus.Model.AutoIncTree,
  Test.Janus.Model.NotIncKey;

const
  /// The AutoInc placeholder. TBind.SetInternalInitFieldDefsObjectClass writes
  /// -1 as the DefaultExpression of an autoinc key, so this is the number a
  /// client row carries between "new" and "the server answered".
  cPLACEHOLDER = -1;

  /// The key only the answer can supply. Nothing in the fixture writes it.
  cSERVERKEY = 555;

  /// The shipped insert contract, verbatim in shape: a `result` string and a
  /// `params` array whose single object names the root's primary key BY
  /// PROPERTY NAME. Janus.Server.Resource.pas builds exactly this.
  cANSWERNAMINGTHEROOTKEY =
    '{"result":"Resource aitroot insert command executed successfully", ' +
    '"params":[{"root_id":555}]}';

  /// Well formed, same shape, but NOT ONE of the three names it carries is the
  /// primary key. Nothing may be stamped from any of them.
  ///
  /// THE THREE NAMES ARE GRADED, and that is the whole reason there are three.
  /// `tag` is an unrelated name and catches an implementation that matches
  /// NOTHING and takes whatever came first. `root` is a strict PREFIX of
  /// `root_id` and catches one that compares beginnings. `oot_id` is a strict
  /// SUFFIX and catches one that asks Pos() instead of asking for equality.
  /// With only `tag` here, the prefix and the substring readings both stayed
  /// green - measured, and that is exactly the false alibi this repository has
  /// been bitten by before.
  cANSWERNAMINGNOKEY =
    '{"result":"Resource aitroot insert command executed successfully", ' +
    '"params":[{"tag":"555"},{"root":"111"},{"oot_id":"222"}]}';

  /// WHAT THE SHIPPED SERVER ACTUALLY EMITS FOR A NON NUMERIC KEY.
  /// Janus.Server.Resource.pas builds the answer with VarToStr and NEVER quotes
  /// the value, so a key that is not a number leaves as `"root_id":ABC` - which
  /// is not JSON. The reader is driven with it here to state what the client
  /// does when the document does not parse.
  cMALFORMEDANSWER =
    '{"result":"Resource aitroot insert command executed successfully", ' +
    '"params":[{"root_id":ABC}]}';

  /// THE THREE DOCUMENTS THAT PARSE AND STILL CARRY NO USABLE KEY.
  ///
  /// These are the ones cMALFORMEDANSWER could never reach: that one does not
  /// parse, so TSessionRestFul<M>.Insert exits early and the reader is never
  /// called at all. These three DO parse, so a param really is built and the
  /// reader really does run - and what it is handed is TEXT, always.
  ///
  /// Janus.Session.RESTful.pas forces `DataType := ftString` on every param and
  /// assigns `JsonValue.Value`, so a JSON `null` arrives as the EMPTY STRING,
  /// never as a Null or Empty variant. That is why a guard written as
  /// VarIsNull/VarIsEmpty could not fire, and why these clauses exist.
  cANSWERWHOSEKEYISJSONNULL =
    '{"result":"Resource aitroot insert command executed successfully", ' +
    '"params":[{"root_id":null}]}';

  cANSWERWHOSEKEYISEMPTY =
    '{"result":"Resource aitroot insert command executed successfully", ' +
    '"params":[{"root_id":""}]}';

  /// A server that DOES quote its values, answering something that is not a
  /// number for a numeric key. Parses cleanly; converts to nothing.
  cANSWERWHOSEKEYISNOTANUMBER =
    '{"result":"Resource aitroot insert command executed successfully", ' +
    '"params":[{"root_id":"ABC"}]}';

  /// The contract's own name, spelled in another case. The reader is
  /// deliberately case-insensitive and this is what holds it to that.
  cANSWERSHOUTINGTHEKEYNAME =
    '{"result":"Resource aitroot insert command executed successfully", ' +
    '"params":[{"ROOT_ID":555}]}';

  /// Two objects naming the SAME key. The shipped producer emits one object per
  /// primary key column and so can never produce this, which is exactly why the
  /// reading has to be pinned rather than left to whichever loop shape survives
  /// the next edit.
  cANSWERNAMINGTHEKEYTWICE =
    '{"result":"Resource aitroot insert command executed successfully", ' +
    '"params":[{"root_id":555},{"root_id":999}]}';

  /// The value only a SECOND param object could put on the root.
  cSECONDKEY = 999;

  /// The same contract for the entity whose key is NOT generated - no
  /// [Sequence], so ExistSequence is False.
  cANSWERFORTHENOSEQUENCEENTITY =
    '{"result":"Resource nikroot insert command executed successfully", ' +
    '"params":[{"nik_id":555}]}';

type
  [TestFixture]
  TTestRestObjectSetInsertKey = class
  private
    FConn: IRESTConnection;
    FRecorder: TRecordingRestConnection;
    FRoot: TAitRoot;
    function BuildTree: TAitRoot;
    /// Insert the canonical tree against AAnswer and require that NOTHING
    /// moved - on the root and on the child both. Shared by the three answers
    /// that parse and still carry no usable key.
    procedure _InsertAndExpectThePlaceholder(const AAnswer, AWhy: String);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// The defect itself, on the root: after the POST the object must carry the
    /// key the answer named, not the placeholder it went in with.
    [Test]
    procedure Insert_TheRootCarriesTheKeyTheServerGenerated;

    /// The defect's consequence, on the child: the cascade runs off the root's
    /// key, so a root left at the placeholder hands the placeholder down.
    [Test]
    procedure Insert_TheChildForeignKeyCarriesTheKeyTheServerGenerated;

    /// ORDER. Stamping after the cascade would leave this clause red while the
    /// root clause stayed green.
    [Test]
    procedure Insert_TheChildIsStampedWithTheServerKeyAndNotWithThePlaceholder;

    /// The cascade filter must still filter: `others` is wired WITHOUT
    /// CascadeAutoInc and must come out untouched.
    [Test]
    procedure Insert_TheUncascadedAssociationIsLeftAlone;

    /// PERTINENCE. A well formed answer that names a column outside the primary
    /// key must change nothing - not the root, not the child.
    [Test]
    procedure Insert_AnAnswerThatNamesNoPrimaryKeyLeavesThePlaceholder;

    /// The gate. Without a [Sequence] the answer is not read at all, and the
    /// cascade does not run either. This is the CURRENT reading of
    /// `if FSession.ExistSequence`, pinned so it cannot move silently; whether
    /// the gate should be noisy is left open by the issue.
    [Test]
    procedure Insert_WithoutASequenceTheAnswerIsNotRead;

    /// CHARACTERISATION, not a claim of correctness: the mid's OWN key is not
    /// reconciled, because the answer never names it. The ObjectSet counterpart
    /// of #297.
    [Test]
    procedure Insert_TheChildOwnKeyIsNotReconciled;

    /// CHARACTERISATION: SetAutoIncValueChilds does not recurse here, and
    /// TRESTObjectSetAdapter<M>.Insert never calls CascadeActionsExecute - the
    /// whole graph travels in ONE POST and the server walks it. So the leaf is
    /// not reached by anything on the client.
    [Test]
    procedure Insert_TheGrandchildIsNotReachedByThisCascade;

    /// One POST for the whole aggregate. If this ever becomes N calls the two
    /// characterisation clauses above stop describing the same design.
    [Test]
    procedure Insert_TheWholeAggregateGoesOutInASinglePost;

    /// An answer that is not JSON must leave the client exactly as it was, and
    /// must not take the caller down with it. This is not hypothetical: the
    /// shipped server emits precisely this document whenever the key is not a
    /// number, because it never quotes the value.
    [Test]
    procedure Insert_AMalformedAnswerLeavesThePlaceholder;

    /// THE THREE THAT PARSE AND CARRY NO USABLE KEY. Before #301 no answer of
    /// any shape could reach the client, so none of these could do anything at
    /// all. The reader must not have made any of them worse than that: the
    /// placeholder stands, and nothing is raised.
    [Test]
    procedure Insert_AKeyThatIsJsonNullLeavesThePlaceholder;
    [Test]
    procedure Insert_AKeyThatIsAnEmptyStringLeavesThePlaceholder;
    [Test]
    procedure Insert_AKeyThatIsNotANumberLeavesThePlaceholder;

    /// The reader is case-insensitive ON PURPOSE, and until this clause existed
    /// nothing said so - the argument lived only in a comment.
    [Test]
    procedure Insert_TheKeyIsMatchedIgnoringTheCaseTheServerUsed;

    /// The scan stops at the FIRST param that names the key. Pinned because the
    /// contract cannot produce a second one, so nothing else would notice the
    /// day the loop stopped stopping.
    [Test]
    procedure Insert_TheFirstParamThatNamesTheKeyDecides;
  end;

implementation

{ TTestRestObjectSetInsertKey }

procedure TTestRestObjectSetInsertKey.Setup;
begin
  FRecorder := TRecordingRestConnection.Create;
  FConn := FRecorder;
  FRecorder.Response := cANSWERNAMINGTHEROOTKEY;
  FRoot := nil;
end;

procedure TTestRestObjectSetInsertKey.TearDown;
begin
  FreeAndNil(FRoot);
  FConn := nil;
  FRecorder := nil;
end;

function TTestRestObjectSetInsertKey.BuildTree: TAitRoot;
var
  LMid: TAitMid;
  LLeaf: TAitLeaf;
  LOther: TAitNoCascade;
begin
  Result := TAitRoot.Create;
  Result.root_id := cPLACEHOLDER;
  Result.tag := 'root';

  LMid := TAitMid.Create;
  LMid.mid_id := cPLACEHOLDER;
  LMid.root_id := cPLACEHOLDER;
  LMid.tag := 'mid';
  Result.mids.Add(LMid);

  LLeaf := TAitLeaf.Create;
  LLeaf.leaf_id := cPLACEHOLDER;
  LLeaf.mid_id := cPLACEHOLDER;
  LLeaf.root_id := cPLACEHOLDER;
  LLeaf.tag := 'leaf';
  LMid.leafs.Add(LLeaf);

  LOther := TAitNoCascade.Create;
  LOther.other_id := cPLACEHOLDER;
  LOther.root_id := cPLACEHOLDER;
  Result.others.Add(LOther);
end;

procedure TTestRestObjectSetInsertKey.Insert_TheRootCarriesTheKeyTheServerGenerated;
var
  LAdapter: TRESTObjectSetAdapter<TAitRoot>;
begin
  FRoot := BuildTree;
  LAdapter := TRESTObjectSetAdapter<TAitRoot>.Create(FConn);
  try
    LAdapter.Insert(FRoot);
  finally
    LAdapter.Free;
  end;
  Assert.AreEqual(cSERVERKEY, FRoot.root_id,
    'the root must carry the key the answer named. ' + IntToStr(cPLACEHOLDER) +
    ' here means TRESTObjectSetAdapter<M>.Insert never read ' +
    'FSession.ResultParams and the generated key was discarded - issue #301');
end;

procedure TTestRestObjectSetInsertKey.Insert_TheChildForeignKeyCarriesTheKeyTheServerGenerated;
var
  LAdapter: TRESTObjectSetAdapter<TAitRoot>;
begin
  FRoot := BuildTree;
  LAdapter := TRESTObjectSetAdapter<TAitRoot>.Create(FConn);
  try
    LAdapter.Insert(FRoot);
  finally
    LAdapter.Free;
  end;
  Assert.AreEqual(cSERVERKEY, FRoot.mids[0].root_id,
    'the child foreign key must point at the row the server actually wrote. ' +
    IntToStr(cPLACEHOLDER) + ' here is the placeholder cascaded down from a ' +
    'root that was never reconciled - issue #301');
end;

procedure TTestRestObjectSetInsertKey.Insert_TheChildIsStampedWithTheServerKeyAndNotWithThePlaceholder;
var
  LAdapter: TRESTObjectSetAdapter<TAitRoot>;
begin
  FRoot := BuildTree;
  LAdapter := TRESTObjectSetAdapter<TAitRoot>.Create(FConn);
  try
    LAdapter.Insert(FRoot);
  finally
    LAdapter.Free;
  end;
  // The pair is the point: reading the answer AFTER the cascade would leave the
  // root right and the child wrong, and only this clause would notice.
  Assert.AreEqual(cSERVERKEY, FRoot.root_id,
    'the root must have been reconciled BEFORE the cascade ran');
  Assert.AreNotEqual(cPLACEHOLDER, FRoot.mids[0].root_id,
    'the cascade must have read the RECONCILED root key. The placeholder here ' +
    'means the answer was read after SetAutoIncValueChilds instead of before');
end;

procedure TTestRestObjectSetInsertKey.Insert_TheUncascadedAssociationIsLeftAlone;
var
  LAdapter: TRESTObjectSetAdapter<TAitRoot>;
begin
  FRoot := BuildTree;
  LAdapter := TRESTObjectSetAdapter<TAitRoot>.Create(FConn);
  try
    LAdapter.Insert(FRoot);
  finally
    LAdapter.Free;
  end;
  Assert.AreEqual(cPLACEHOLDER, FRoot.others[0].root_id,
    '`others` is declared WITHOUT CascadeAutoInc, so nothing may write its ' +
    'foreign key. A fix that simply stamped every child would look green ' +
    'without this clause');
end;

procedure TTestRestObjectSetInsertKey.Insert_AnAnswerThatNamesNoPrimaryKeyLeavesThePlaceholder;
var
  LAdapter: TRESTObjectSetAdapter<TAitRoot>;
begin
  FRecorder.Response := cANSWERNAMINGNOKEY;
  FRoot := BuildTree;
  LAdapter := TRESTObjectSetAdapter<TAitRoot>.Create(FConn);
  try
    LAdapter.Insert(FRoot);
  finally
    LAdapter.Free;
  end;
  Assert.AreEqual(cPLACEHOLDER, FRoot.root_id,
    'not one of `tag`, `root`, `oot_id` IS `root_id`. 555 here means the ' +
    'reader took whatever came first; 111 means it compared prefixes; 222 ' +
    'means it asked Pos() instead of asking for equality');
  Assert.AreEqual('root', FRoot.tag, False,
    'and `tag` itself must not have been overwritten either - the reader is ' +
    'scoped to the primary key, which is the only thing the contract carries');
end;

procedure TTestRestObjectSetInsertKey.Insert_WithoutASequenceTheAnswerIsNotRead;
var
  LAdapter: TRESTObjectSetAdapter<TNikRoot>;
  LRoot: TNikRoot;
  LChild: TNikChild;
begin
  FRecorder.Response := cANSWERFORTHENOSEQUENCEENTITY;
  LRoot := TNikRoot.Create;
  try
    LRoot.nik_id := 7;
    LRoot.tag := 'typed';
    LChild := TNikChild.Create;
    LChild.child_id := 1;
    LChild.nik_id := 7;
    LRoot.childs.Add(LChild);

    LAdapter := TRESTObjectSetAdapter<TNikRoot>.Create(FConn);
    try
      LAdapter.Insert(LRoot);
    finally
      LAdapter.Free;
    end;
    // TNikRoot carries no [Sequence], so TSessionRestFul<M>.ExistSequence is
    // False and the whole block - the read AND the cascade - is skipped. The
    // answer named 555 and neither level moved.
    Assert.AreEqual(7, LRoot.nik_id,
      'no [Sequence] means no generated key to reconcile, so the client value ' +
      'must survive. 555 here means the read escaped the ExistSequence gate');
    Assert.AreEqual(7, LRoot.childs[0].nik_id,
      'and the child must be left alone for the same reason');
  finally
    LRoot.Free;
  end;
end;

procedure TTestRestObjectSetInsertKey.Insert_TheChildOwnKeyIsNotReconciled;
var
  LAdapter: TRESTObjectSetAdapter<TAitRoot>;
begin
  FRoot := BuildTree;
  LAdapter := TRESTObjectSetAdapter<TAitRoot>.Create(FConn);
  try
    LAdapter.Insert(FRoot);
  finally
    LAdapter.Free;
  end;
  Assert.AreEqual(cPLACEHOLDER, FRoot.mids[0].mid_id,
    'CHARACTERISATION, not approval: the answer names the ROOT key and nothing ' +
    'below it, so the mid keeps the placeholder as its OWN key. This is the ' +
    'ObjectSet counterpart of #297 and is NOT repaired by #301');
end;

procedure TTestRestObjectSetInsertKey.Insert_TheGrandchildIsNotReachedByThisCascade;
var
  LAdapter: TRESTObjectSetAdapter<TAitRoot>;
begin
  FRoot := BuildTree;
  LAdapter := TRESTObjectSetAdapter<TAitRoot>.Create(FConn);
  try
    LAdapter.Insert(FRoot);
  finally
    LAdapter.Free;
  end;
  Assert.AreEqual(cPLACEHOLDER, FRoot.mids[0].leafs[0].mid_id,
    'CHARACTERISATION: SetAutoIncValueChilds walks ONE level, and the REST ' +
    'ObjectSet adapter never calls CascadeActionsExecute - the graph is sent ' +
    'whole and the SERVER walks it. So nothing on the client reaches the leaf');
end;

procedure TTestRestObjectSetInsertKey.Insert_TheWholeAggregateGoesOutInASinglePost;
var
  LAdapter: TRESTObjectSetAdapter<TAitRoot>;
begin
  FRoot := BuildTree;
  LAdapter := TRESTObjectSetAdapter<TAitRoot>.Create(FConn);
  try
    LAdapter.Insert(FRoot);
  finally
    LAdapter.Free;
  end;
  Assert.AreEqual(1, FRecorder.CallCount,
    'the REST ObjectSet family POSTs the aggregate once and lets the server ' +
    'cascade. More calls than one would mean the client started walking the ' +
    'graph itself, and the two characterisation clauses would no longer hold');
  Assert.AreEqual(Ord(TRESTRequestMethodType.rtPOST),
    Ord(FRecorder.LastCall.RequestMethod), 'an Insert is a POST');
end;

procedure TTestRestObjectSetInsertKey.Insert_AMalformedAnswerLeavesThePlaceholder;
var
  LAdapter: TRESTObjectSetAdapter<TAitRoot>;
begin
  FRecorder.Response := cMALFORMEDANSWER;
  FRoot := BuildTree;
  LAdapter := TRESTObjectSetAdapter<TAitRoot>.Create(FConn);
  try
    LAdapter.Insert(FRoot);
  finally
    LAdapter.Free;
  end;
  Assert.AreEqual(cPLACEHOLDER, FRoot.root_id,
    'a document that does not parse carries no key, so nothing may be stamped');
  Assert.AreEqual(cPLACEHOLDER, FRoot.mids[0].root_id,
    'and the cascade must have handed down the unchanged value, not crashed ' +
    'half way');
end;

procedure TTestRestObjectSetInsertKey._InsertAndExpectThePlaceholder(
  const AAnswer, AWhy: String);
var
  LAdapter: TRESTObjectSetAdapter<TAitRoot>;
begin
  FRecorder.Response := AAnswer;
  FRoot := BuildTree;
  LAdapter := TRESTObjectSetAdapter<TAitRoot>.Create(FConn);
  try
    // An ERROR rather than a failure on the next line is the whole point of
    // these three: the reader must not RAISE on an answer it cannot use. Before
    // #301 nothing read the answer, so nothing could raise.
    LAdapter.Insert(FRoot);
  finally
    LAdapter.Free;
  end;
  Assert.AreEqual(cPLACEHOLDER, FRoot.root_id, AWhy);
  Assert.AreEqual(cPLACEHOLDER, FRoot.mids[0].root_id,
    AWhy + ' - and the cascade must have handed the unchanged value down');
end;

procedure TTestRestObjectSetInsertKey.Insert_AKeyThatIsJsonNullLeavesThePlaceholder;
begin
  _InsertAndExpectThePlaceholder(cANSWERWHOSEKEYISJSONNULL,
    'a JSON null carries no key. It reaches the reader as the EMPTY STRING - ' +
    'the parser forces ftString on every param - so a guard that asks ' +
    'VarIsNull or VarIsEmpty never fires and the empty text goes on to a ' +
    'numeric conversion that raises');
end;

procedure TTestRestObjectSetInsertKey.Insert_AKeyThatIsAnEmptyStringLeavesThePlaceholder;
begin
  _InsertAndExpectThePlaceholder(cANSWERWHOSEKEYISEMPTY,
    'an explicitly empty string carries no key either, and arrives at the ' +
    'reader indistinguishable from the JSON null above');
end;

procedure TTestRestObjectSetInsertKey.Insert_AKeyThatIsNotANumberLeavesThePlaceholder;
begin
  _InsertAndExpectThePlaceholder(cANSWERWHOSEKEYISNOTANUMBER,
    'a quoted non numeric value parses cleanly and converts to nothing. The ' +
    'key stays as it was rather than the save ending in an exception');
end;

procedure TTestRestObjectSetInsertKey.Insert_TheKeyIsMatchedIgnoringTheCaseTheServerUsed;
var
  LAdapter: TRESTObjectSetAdapter<TAitRoot>;
begin
  FRecorder.Response := cANSWERSHOUTINGTHEKEYNAME;
  FRoot := BuildTree;
  LAdapter := TRESTObjectSetAdapter<TAitRoot>.Create(FConn);
  try
    LAdapter.Insert(FRoot);
  finally
    LAdapter.Free;
  end;
  Assert.AreEqual(cSERVERKEY, FRoot.root_id,
    'the answer named ROOT_ID and the property is root_id. The reader matches ' +
    'without regard to case because a third party server is not obliged to ' +
    'echo the spelling back - and that argument is only worth making if ' +
    'something measures it');
  Assert.AreEqual(cSERVERKEY, FRoot.mids[0].root_id,
    'and the cascade carries that same key down');
end;

procedure TTestRestObjectSetInsertKey.Insert_TheFirstParamThatNamesTheKeyDecides;
var
  LAdapter: TRESTObjectSetAdapter<TAitRoot>;
begin
  FRecorder.Response := cANSWERNAMINGTHEKEYTWICE;
  FRoot := BuildTree;
  LAdapter := TRESTObjectSetAdapter<TAitRoot>.Create(FConn);
  try
    LAdapter.Insert(FRoot);
  finally
    LAdapter.Free;
  end;
  Assert.AreEqual(cSERVERKEY, FRoot.root_id,
    'the scan stops at the first param that names the key. ' +
    IntToStr(cSECONDKEY) + ' here means it kept scanning and the LAST one ' +
    'won instead');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRestObjectSetInsertKey);

end.
