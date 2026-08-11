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

  Measured on this fixture BEFORE the fix, at 03595a6: both came out -1 while
  the answer said 555.

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

initialization
  TDUnitX.RegisterTestFixture(TTestRestObjectSetInsertKey);

end.
