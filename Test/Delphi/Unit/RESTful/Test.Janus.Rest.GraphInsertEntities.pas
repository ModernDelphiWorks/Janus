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

{ @abstract(Janus Framework - the REST ObjectSet family reconciles the key of
  EVERY row the insert wrote, not only the root's. Issue #312. CONSUMER side.)

  WHAT WAS WRONG

  The server writes the whole aggregate - one POST, and TRESTObjectSet.Insert
  cascades - and the database generates a key for every row. The answer named
  the primary key of ONE class, the root. So on the client:

    root  : reconciled          (#301 closed that)
    mid   : the PLACEHOLDER, as its own key
    leaf  : the PLACEHOLDER, as its own key
    leaf  : and the placeholder as its PARENT too

  The last line is the part that is easy to miss and is the reason the repair
  is two writes and not one. TObjectSetBaseAdapter<M>.SetAutoIncValueChilds
  walks exactly ONE level, TRESTObjectSetAdapter<M>.Insert calls it on the root
  alone, and this family never calls CascadeActionsExecute for an insert - so
  nothing on the client ever reached the third level at all. A grandchild came
  out of a save with neither a key of its own nor a valid parent.

  Two clauses in Test.Janus.Rest.ObjectSetInsertKey have documented that state
  since #301 - ChildOwnKeyIsNotReconciled and GrandchildIsNotReachedByThisCascade.
  They are NOT deleted by this issue and they are NOT contradicted by it: they
  drive an answer with no `entities` key, which is what every server produced
  before this issue and what the four hand written servers under
  Examples\Delphi\RESTful still produce. Their subject is the OLD contract and
  it has not moved.

  HOW A CHILD IS IDENTIFIED, AND WHAT THAT BINDS

  By its PATH from the root: the association PROPERTY name, plus a bracketed
  ordinal when the association is to-many. `mids[0].leafs[1]`.

  The three alternatives and why they lose are argued at length over
  _CollectInsertedEntities in Janus.Server.Resource.pas. The short of it: a
  class name cannot tell two siblings of one list apart, the child's own key is
  the placeholder and every child carries the same one, and a flat ordinal
  writes a real key onto the wrong object SILENTLY when the two ends disagree.
  A path is CHECKABLE, and three clauses below are the check:
  AnEntryWhosePathNamesNoAssociationWritesNothing,
  AnEntryWhoseOrdinalIsPastTheEndOfTheListWritesNothing and
  AnEntryWhoseClassDisagreesWithTheObjectWritesNothing.

  What it binds is that the client's graph must still have the SHAPE it POSTed,
  in the same list ORDER. It does: this family sends the aggregate in ONE POST
  and never cascades an insert of its own - Janus.RestObjectSet.Adapter.pas has
  exactly one CascadeActionsExecute call and it is CascadeDelete - so nothing
  adds, removes or reorders a list between the POST and the read. That premise
  is asserted, not assumed: see Premise_TheWholeAggregateStillGoesOutInOnePost.

  WHY `params` DID NOT GAIN ENTRIES, AND THE CLAUSE THAT PROVES IT

  ResultParams is a flat list of name/value pairs with NO owner, and its two
  readers disagree about a repeated name: _SetGeneratedKeyValue matches by
  PROPERTY name and the FIRST match decides, while
  TRESTDataSetAdapter<M>.ApplyInserter writes ANY field the row has and the
  answer names, with the LAST one winning. A child's key placed in `params`
  could therefore overwrite the ROOT's key whenever the two spell the same
  name. AChildKeyNamedLikeTheRootsDoesNotTouchTheRoot drives exactly that
  document here, and the DataSet family's half of the same proof lives in
  Test.Janus.Rest.CompositeKeyReReadGate.

  THE GATE IS PER ENTITY, AND THE FIRST DELIVERY OF THIS ISSUE GOT IT WRONG

  That delivery put the reader inside `if FSession.ExistSequence` - #301's gate
  for the ROOT's key, which answers `GetMappingSequence(TClass(M)) <> nil`. It
  asks ONE class. So a MIXED aggregate - a root whose key the CLIENT supplies
  over a child carrying its own [Sequence] - answered False, and the client
  discarded an `entities` array reporting a key the database really had
  generated. The defect of this very issue, one level up: asking ONE CLASS a
  question that is per ROW.

  The gate did not go away, it moved to where the question belongs: each entry
  is asked about the entity its path RESOLVED TO. Removing it instead of moving
  it is not an option and that is measured too - it reddens
  Insert_AnEntryWhoseEntityHasNoSequenceOfItsOwnIsNotRead, the symmetric shape
  where root and child are both NotInc and the client's own values must survive.

  THE ANSWERS ARE CANNED. Nothing here speaks to a server. The PRODUCER half -
  that the document really comes out of TAppResourceBase.insert with these
  paths and these keys - is measured in Janus.Tests.RESTHorse by
  Test.Janus.Server.Resource.InsertEntities, against a live SQLite database.
  NO FIXTURE ANYWHERE MEASURES THE TWO HALVES IN ONE PROCESS.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Rest.GraphInsertEntities;

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
  MetaDbDiff.Mapping.Explorer,
  Test.Janus.RestConnection.Double,
  Test.Janus.Model.AutoIncTree,
  Test.Janus.Model.AsymTree,
  /// The MIXED graph - a root whose key the CLIENT supplies over a child whose
  /// key the SERVER generates. Written by #305 for that asymmetry; #312 needs
  /// it because the gate this reader used to sit behind asked only about the
  /// ROOT, so this whole shape never read the answer at all.
  Test.Janus.Model.ClientKeyRoot,
  Test.Janus.Model.NotIncKey;

const
  /// The AutoInc placeholder. TBind.SetInternalInitFieldDefsObjectClass writes
  /// -1 as the DefaultExpression of an autoinc key.
  cPLACEHOLDER = -1;

  /// Seven numbers, all different from each other and from the placeholder, so
  /// that a repair which wrote the RIGHT key onto the WRONG object cannot look
  /// green.
  cROOTKEY  = 555;
  cMID0KEY  = 601;
  cMID1KEY  = 602;
  cLEAF00KEY = 701;
  cLEAF01KEY = 702;
  cLEAF10KEY = 703;
  cOTHERKEY  = 801;

  /// The answer AS IT WAS BEFORE THIS ISSUE: `params` and nothing else. Every
  /// clause that says "unchanged" is measured against this one.
  cOLDANSWER =
    '{"result":"Resource aitroot insert command executed successfully", ' +
    '"params":[{"root_id":555}]}';

  /// THE SHIPPED ANSWER AFTER THIS ISSUE, verbatim in shape. `params` is byte
  /// for byte what it was above; `entities` is the new sibling. The root has an
  /// entry too, at the EMPTY path - the reader skips it, because the root
  /// already has a reader.
  cANSWERWITHENTITIES =
    '{"result":"Resource aitroot insert command executed successfully", ' +
    '"params":[{"root_id":555}], ' +
    '"entities":[' +
      '{"path":"","class":"TAitRoot","keys":{"root_id":555}},' +
      '{"path":"mids[0]","class":"TAitMid","keys":{"mid_id":601}},' +
      '{"path":"mids[0].leafs[0]","class":"TAitLeaf","keys":{"leaf_id":701}},' +
      '{"path":"mids[0].leafs[1]","class":"TAitLeaf","keys":{"leaf_id":702}},' +
      '{"path":"mids[1]","class":"TAitMid","keys":{"mid_id":602}},' +
      '{"path":"mids[1].leafs[0]","class":"TAitLeaf","keys":{"leaf_id":703}},' +
      '{"path":"others[0]","class":"TAitNoCascade","keys":{"other_id":801}}]}';

  /// THE SAME INFORMATION IN THE OPPOSITE ORDER. Each entry names its own
  /// target and carries its own keys, and the one-level walk reads the key off
  /// the object it has just written - so no entry depends on another having
  /// been applied first. This is the property a flat traversal ordinal would
  /// NOT have had, and it is worth a clause of its own.
  cANSWERREVERSED =
    '{"result":"Resource aitroot insert command executed successfully", ' +
    '"params":[{"root_id":555}], ' +
    '"entities":[' +
      '{"path":"others[0]","class":"TAitNoCascade","keys":{"other_id":801}},' +
      '{"path":"mids[1].leafs[0]","class":"TAitLeaf","keys":{"leaf_id":703}},' +
      '{"path":"mids[1]","class":"TAitMid","keys":{"mid_id":602}},' +
      '{"path":"mids[0].leafs[1]","class":"TAitLeaf","keys":{"leaf_id":702}},' +
      '{"path":"mids[0].leafs[0]","class":"TAitLeaf","keys":{"leaf_id":701}},' +
      '{"path":"mids[0]","class":"TAitMid","keys":{"mid_id":601}},' +
      '{"path":"","class":"TAitRoot","keys":{"root_id":555}}]}';

  /// THE RISK THE DESIGN WAS BUILT AROUND. A child entry whose `keys` object
  /// names the ROOT's key property, with a number the root must never take.
  cROOTSKEYNAMEUNDERACHILD = 999;
  cANSWERNAMINGTHEROOTKEYUNDERACHILD =
    '{"result":"Resource aitroot insert command executed successfully", ' +
    '"params":[{"root_id":555}], ' +
    '"entities":[' +
      '{"path":"mids[0]","class":"TAitMid","keys":{"root_id":999}}]}';

  /// A path whose first segment names no association of TAitRoot.
  cANSWERWITHANUNKNOWNPATH =
    '{"result":"Resource aitroot insert command executed successfully", ' +
    '"params":[{"root_id":555}], ' +
    '"entities":[' +
      '{"path":"tag","class":"TAitMid","keys":{"mid_id":601}},' +
      '{"path":"nosuchthing[0]","class":"TAitMid","keys":{"mid_id":601}}]}';

  /// An ordinal past the end of the list the client is holding.
  cANSWERWITHANOUTOFRANGEORDINAL =
    '{"result":"Resource aitroot insert command executed successfully", ' +
    '"params":[{"root_id":555}], ' +
    '"entities":[' +
      '{"path":"mids[7]","class":"TAitMid","keys":{"mid_id":601}}]}';

  /// A to-MANY association addressed WITHOUT an ordinal. The multiplicity is
  /// what decides the shape of the segment, on both ends.
  cANSWERWITHNOORDINALONATOMANY =
    '{"result":"Resource aitroot insert command executed successfully", ' +
    '"params":[{"root_id":555}], ' +
    '"entities":[' +
      '{"path":"mids","class":"TAitMid","keys":{"mid_id":601}}]}';

  /// The path resolves, and the class the producer names is NOT the class of
  /// what it resolved to.
  cANSWERWITHTHEWRONGCLASS =
    '{"result":"Resource aitroot insert command executed successfully", ' +
    '"params":[{"root_id":555}], ' +
    '"entities":[' +
      '{"path":"mids[0]","class":"TAitLeaf","keys":{"mid_id":601}}]}';

  /// `class` omitted altogether - a third party server that does not send it.
  cANSWERWITHNOCLASS =
    '{"result":"Resource aitroot insert command executed successfully", ' +
    '"params":[{"root_id":555}], ' +
    '"entities":[' +
      '{"path":"mids[0]","keys":{"mid_id":601}}]}';

  /// FOUR MALFORMED SHAPES OF THE KEY ITSELF. None may raise, and none may
  /// disturb what `params` already did.
  cENTITIESISANOBJECT =
    '{"result":"ok","params":[{"root_id":555}],"entities":{"path":""}}';
  cENTITIESISASTRING =
    '{"result":"ok","params":[{"root_id":555}],"entities":"x"}';
  cENTITIESISANUMBER =
    '{"result":"ok","params":[{"root_id":555}],"entities":7}';
  cENTITIESISNULL =
    '{"result":"ok","params":[{"root_id":555}],"entities":null}';

  /// A ruined element between two good ones, plus elements missing each of the
  /// two fields an entry NEEDS.
  cANSWERWITHONERUINEDELEMENT =
    '{"result":"Resource aitroot insert command executed successfully", ' +
    '"params":[{"root_id":555}], ' +
    '"entities":[' +
      '7,' +
      '{"path":"mids[0]","class":"TAitMid","keys":{"mid_id":601}},' +
      '{"class":"TAitMid","keys":{"mid_id":111}},' +
      '{"path":"mids[1]"},' +
      'null,' +
      '{"path":"mids[1]","class":"TAitMid","keys":{"mid_id":602}}]}';

  /// WHAT THE FOUR HAND WRITTEN EXAMPLE SERVERS EMIT, in shape: a `message`
  /// key instead of `result`, one params object, and no `entities` at all.
  /// Examples\Delphi\RESTful\RESTFul via Driver\{WiRL,MARS,DelphiMVC,Datasnap}
  /// all write this string by concatenation.
  cEXAMPLESERVERANSWER =
    '{"message":"registro inserido com sucesso!", "params":[{"root_id":555}]}';

  /// THE MIXED GRAPH - the shape the ROOT-SCOPED gate could not see.
  ///
  /// TCkrRoot is TAutoIncType.NotInc with NO [Sequence]: its key comes from the
  /// CLIENT. TCkrChild is AutoInc + SequenceInc + [Sequence]: its key comes
  /// from the SERVER. So this aggregate has nothing to reconcile at level one
  /// and something real to reconcile at level two - and
  /// TSessionRestFul<M>.ExistSequence answers
  /// `GetMappingSequence(TClass(M)) <> nil`, about the ROOT and only the root.
  cCLIENTROOTKEY = 42;
  cCKRCHILDKEY   = 601;
  cANSWERFORTHEMIXEDGRAPH =
    '{"result":"Resource ckrroot insert command executed successfully", ' +
    '"params":[{"ckrroot_id":42}], ' +
    '"entities":[' +
      '{"path":"","class":"TCkrRoot","keys":{"ckrroot_id":42}},' +
      '{"path":"childs[0]","class":"TCkrChild","keys":{"ckrchild_id":601}}]}';

  /// The same contract for the entity with no [Sequence].
  cANSWERFORTHENOSEQUENCEENTITY =
    '{"result":"Resource nikroot insert command executed successfully", ' +
    '"params":[{"nik_id":555}], ' +
    '"entities":[' +
      '{"path":"childs[0]","class":"TNikChild","keys":{"child_id":601}}]}';

  /// The to-ONE shape, which no body can reach on the producer side because
  /// TJanusJson.JsonToObject does not instantiate a nil class-typed property.
  /// Built in memory here, so the to-one arm of the resolver really runs.
  cPAIRKEY = 901;
  cPAIRMIDKEY = 902;
  cPAIRLEAFKEY = 903;
  cANSWERFORTHETOONEROOT =
    '{"result":"Resource atpair insert command executed successfully", ' +
    '"params":[{"pkey":901}], ' +
    '"entities":[' +
      '{"path":"","class":"TAsymTreeOneRoot","keys":{"pkey":901}},' +
      '{"path":"mid","class":"TAsymTreeMid","keys":{"mkey":902}},' +
      '{"path":"mid.leafs[0]","class":"TAsymTreeLeaf","keys":{"lkey":903}}]}';

  /// A to-ONE association addressed WITH an ordinal - the mirror of
  /// cANSWERWITHNOORDINALONATOMANY.
  cANSWERWITHANORDINALONATOONE =
    '{"result":"Resource atpair insert command executed successfully", ' +
    '"params":[{"pkey":901}], ' +
    '"entities":[' +
      '{"path":"mid[0]","class":"TAsymTreeMid","keys":{"mkey":902}}]}';

type
  [TestFixture]
  TTestRestGraphInsertEntities = class
  private
    FConn: IRESTConnection;
    FRecorder: TRecordingRestConnection;
    FRoot: TAitRoot;
    FPair: TAsymTreeOneRoot;
    FMixed: TCkrRoot;
    function BuildTree: TAitRoot;
    function BuildPair: TAsymTreeOneRoot;
    function BuildMixed: TCkrRoot;
    /// Insert the canonical tree against AAnswer.
    procedure InsertWith(const AAnswer: String);
    procedure InsertPairWith(const AAnswer: String);
    procedure InsertMixedWith(const AAnswer: String);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// PREMISE. The path is an address into the graph the client POSTed, so it
    /// only means anything while the client still holds that graph unchanged.
    [Test]
    procedure Premise_TheWholeAggregateStillGoesOutInOnePost;

    /// PREMISE, and the state this issue was opened against: with the OLD
    /// answer, every level below the root keeps the placeholder - its own key
    /// AND, one level further down, its parent.
    [Test]
    procedure Premise_TheOldAnswerLeavesEveryLevelBelowTheRootOnThePlaceholder;

    /// THE DEFECT, level two: the child's own key.
    [Test]
    procedure TheChildOwnKeyIsReconciledFromEntities;

    /// THE DEFECT, level three: the grandchild's own key.
    [Test]
    procedure TheGrandchildOwnKeyIsReconciledFromEntities;

    /// THE DEFECT, the half that is easy to miss: the grandchild's PARENT. The
    /// key alone is not enough - a leaf whose mid_id is still the placeholder
    /// belongs to nothing.
    [Test]
    procedure TheGrandchildForeignKeyPointsAtItsRealParent;

    /// CORRESPONDENCE. Two siblings of ONE list get their OWN keys, and so do
    /// their children. A reader that matched by class, or that took the first
    /// entry that fitted, gives both the same number.
    [Test]
    procedure EachSiblingGetsItsOwnKeyAndNotItsBrothers;

    /// And the root itself must still come out of `params`, unchanged.
    [Test]
    procedure TheRootIsStillReconciledFromParams;

    /// ORDER INDEPENDENCE. The same information in the opposite order lands in
    /// exactly the same place.
    [Test]
    procedure TheOrderOfTheEntriesDoesNotMatter;

    /// THE RISK CLAUSE. A child entry naming the ROOT's key property must not
    /// reach the root - in this family the isolation is structural, because no
    /// entry of `entities` is ever added to ResultParams.
    [Test]
    procedure AChildKeyNamedLikeTheRootsDoesNotTouchTheRoot;

    /// PERTINENCE. The reader is scoped to the target's OWN primary key, so a
    /// name that is not one of its key columns writes nothing at all.
    [Test]
    procedure AnEntryNamingSomethingOtherThanTheTargetsKeyWritesNothing;

    /// THE THREE REFUSALS THAT MAKE A PATH SAFER THAN AN ORDINAL.
    [Test]
    procedure AnEntryWhosePathNamesNoAssociationWritesNothing;
    [Test]
    procedure AnEntryWhoseOrdinalIsPastTheEndOfTheListWritesNothing;
    [Test]
    procedure AnEntryWhoseClassDisagreesWithTheObjectWritesNothing;

    /// The multiplicity decides the shape of the segment, in BOTH directions.
    [Test]
    procedure AToManyAddressedWithoutAnOrdinalWritesNothing;
    [Test]
    procedure AToOneAddressedWithAnOrdinalWritesNothing;

    /// `class` is OPTIONAL. A server that omits it is still read.
    [Test]
    procedure AnEntryWithNoClassIsStillRead;

    /// THE OTHER MULTIPLICITY, reachable only from here.
    [Test]
    procedure AToOneBranchIsResolvedAndDescended;

    /// CASCADE FILTER. `others` is declared WITHOUT CascadeAutoInc. Its own key
    /// is reconciled - the server did write that row - but nothing may stamp
    /// its foreign key, which is the mapping's decision and not the answer's.
    [Test]
    procedure TheUncascadedAssociationGetsItsKeyButNoForeignKeyStamp;

    /// COMPATIBILITY. The document the four hand written example servers emit
    /// is read exactly as it was before this issue.
    [Test]
    procedure TheAnswerTheExampleServersEmitIsReadExactlyAsBefore;

    /// FOUR MALFORMED SHAPES OF `entities`. None may raise, and none may
    /// disturb what `params` already did.
    [Test]
    procedure AnEntitiesKeyOfTheWrongTypeLeavesTheGraphAlone;

    /// One ruined element must not cost the good ones - the same reading #315
    /// settled for `params`.
    [Test]
    procedure ARuinedElementIsSkippedAndItsSiblingsAreStillRead;

    /// THE GATE, AND IT IS PER ENTITY - NOT PER AGGREGATE.
    ///
    /// The first delivery of #312 put this reader inside
    /// `if FSession.ExistSequence`, the gate #301 wrote for the ROOT's key.
    /// That gate answers `GetMappingSequence(TClass(M)) <> nil`: it asks ONE
    /// class, the root. The reason written beside it - "with no [Sequence]
    /// there is no generated key to reconcile" - is true of a SYMMETRIC
    /// aggregate and FALSE of a mixed one, and asking one class a question that
    /// is per ROW is precisely the defect #312 was opened against, one level up.
    ///
    /// The three clauses below are the mixed shape. The fourth is the
    /// symmetric one, which used to be the ONLY thing measured here and which
    /// is the case where the old reason really did hold.
    [Test]
    procedure Premise_TheMixedGraphRootHasNoSequenceAndItsChildDoes;
    [Test]
    procedure MixedGraph_TheChildWithItsOwnSequenceIsStillReconciled;
    [Test]
    procedure MixedGraph_TheClientSuppliedRootKeyIsNotTouched;
    [Test]
    procedure Insert_AnEntryWhoseEntityHasNoSequenceOfItsOwnIsNotRead;
  end;

implementation

{ TTestRestGraphInsertEntities }

procedure TTestRestGraphInsertEntities.Setup;
begin
  FRecorder := TRecordingRestConnection.Create;
  FConn := FRecorder;
  FRecorder.Response := cANSWERWITHENTITIES;
  FRoot := nil;
  FPair := nil;
  FMixed := nil;
end;

procedure TTestRestGraphInsertEntities.TearDown;
begin
  FreeAndNil(FRoot);
  FreeAndNil(FPair);
  FreeAndNil(FMixed);
  FConn := nil;
  FRecorder := nil;
end;

function TTestRestGraphInsertEntities.BuildTree: TAitRoot;

  function _Leaf(const ATag: String): TAitLeaf;
  begin
    Result := TAitLeaf.Create;
    Result.leaf_id := cPLACEHOLDER;
    Result.mid_id := cPLACEHOLDER;
    Result.root_id := cPLACEHOLDER;
    Result.tag := ATag;
  end;

  function _Mid(const ATag: String): TAitMid;
  begin
    Result := TAitMid.Create;
    Result.mid_id := cPLACEHOLDER;
    Result.root_id := cPLACEHOLDER;
    Result.tag := ATag;
  end;

var
  LMid: TAitMid;
  LOther: TAitNoCascade;
begin
  Result := TAitRoot.Create;
  Result.root_id := cPLACEHOLDER;
  Result.tag := 'root';

  // TWO mids, and TWO leaves under the FIRST. Both numbers are load-bearing:
  // with one mid nothing tells an ordinal from a class name, and with one leaf
  // per mid nothing tells the second level's ordinal from the third's.
  LMid := _Mid('mid0');
  LMid.leafs.Add(_Leaf('leaf00'));
  LMid.leafs.Add(_Leaf('leaf01'));
  Result.mids.Add(LMid);

  LMid := _Mid('mid1');
  LMid.leafs.Add(_Leaf('leaf10'));
  Result.mids.Add(LMid);

  LOther := TAitNoCascade.Create;
  LOther.other_id := cPLACEHOLDER;
  LOther.root_id := cPLACEHOLDER;
  Result.others.Add(LOther);
end;

function TTestRestGraphInsertEntities.BuildPair: TAsymTreeOneRoot;
var
  LLeaf: TAsymTreeLeaf;
begin
  Result := TAsymTreeOneRoot.Create;
  Result.pkey := cPLACEHOLDER;
  Result.ptag := 'pair';
  // Filled HERE and not from a body: TAsymTreeOneRoot.mid starts nil on
  // purpose and TJanusJson.JsonToObject does not instantiate it, which is what
  // puts this shape out of reach of the producer side fixture.
  Result.mid := TAsymTreeMid.Create;
  Result.mid.mkey := cPLACEHOLDER;
  Result.mid.mparent := cPLACEHOLDER;
  Result.mid.mtag := 'pairmid';
  LLeaf := TAsymTreeLeaf.Create;
  LLeaf.lkey := cPLACEHOLDER;
  LLeaf.lparent := cPLACEHOLDER;
  LLeaf.ltag := 'pairleaf';
  Result.mid.leafs.Add(LLeaf);
end;

function TTestRestGraphInsertEntities.BuildMixed: TCkrRoot;
var
  LChild: TCkrChild;
begin
  Result := TCkrRoot.Create;
  // The root's key comes from the CLIENT and is a real number from the start -
  // it is NOT a placeholder, and nothing may change it.
  Result.ckrroot_id := cCLIENTROOTKEY;
  Result.tag := 'mixedroot';
  LChild := TCkrChild.Create;
  // The child's OWN key is the placeholder: the server generates it.
  LChild.ckrchild_id := cPLACEHOLDER;
  // Its foreign key is already right, because the root's key was never in
  // doubt. This is what makes the clause below about the child's OWN key and
  // nothing else.
  LChild.ckrroot_id := cCLIENTROOTKEY;
  LChild.tag := 'mixedchild';
  Result.childs.Add(LChild);
end;

procedure TTestRestGraphInsertEntities.InsertMixedWith(const AAnswer: String);
var
  LAdapter: TRESTObjectSetAdapter<TCkrRoot>;
begin
  FRecorder.Response := AAnswer;
  FMixed := BuildMixed;
  LAdapter := TRESTObjectSetAdapter<TCkrRoot>.Create(FConn);
  try
    LAdapter.Insert(FMixed);
  finally
    LAdapter.Free;
  end;
end;

procedure TTestRestGraphInsertEntities.InsertWith(const AAnswer: String);
var
  LAdapter: TRESTObjectSetAdapter<TAitRoot>;
begin
  FRecorder.Response := AAnswer;
  FRoot := BuildTree;
  LAdapter := TRESTObjectSetAdapter<TAitRoot>.Create(FConn);
  try
    // An ERROR rather than a failure on the next line is a result in itself:
    // before this issue no answer of any shape could make an insert fail, and
    // reading a new key must not have bought that.
    LAdapter.Insert(FRoot);
  finally
    LAdapter.Free;
  end;
end;

procedure TTestRestGraphInsertEntities.InsertPairWith(const AAnswer: String);
var
  LAdapter: TRESTObjectSetAdapter<TAsymTreeOneRoot>;
begin
  FRecorder.Response := AAnswer;
  FPair := BuildPair;
  LAdapter := TRESTObjectSetAdapter<TAsymTreeOneRoot>.Create(FConn);
  try
    LAdapter.Insert(FPair);
  finally
    LAdapter.Free;
  end;
end;

procedure TTestRestGraphInsertEntities
  .Premise_TheWholeAggregateStillGoesOutInOnePost;
begin
  InsertWith(cANSWERWITHENTITIES);
  Assert.AreEqual(1, FRecorder.CallCount,
    'PREMISE OF THE WHOLE DESIGN. A path is an address into the graph the ' +
    'client POSTed. If this family ever started walking the graph itself, the ' +
    'shape the server measured and the shape the client is holding would stop ' +
    'being the same one and every path here would address the wrong object');
end;

procedure TTestRestGraphInsertEntities
  .Premise_TheOldAnswerLeavesEveryLevelBelowTheRootOnThePlaceholder;
begin
  InsertWith(cOLDANSWER);
  Assert.AreEqual(cROOTKEY, FRoot.root_id,
    'premise: the root IS reconciled by the old answer - #301 closed that');
  Assert.AreEqual(cPLACEHOLDER, FRoot.mids[0].mid_id,
    'the child keeps the placeholder as its OWN key: the old answer names the ' +
    'root and nothing under it');
  Assert.AreEqual(cPLACEHOLDER, FRoot.mids[0].leafs[0].leaf_id,
    'and so does the grandchild');
  Assert.AreEqual(cPLACEHOLDER, FRoot.mids[0].leafs[0].mid_id,
    'AND THE GRANDCHILD HAS NO VALID PARENT EITHER. SetAutoIncValueChilds ' +
    'walks ONE level and Insert calls it on the root alone, so nothing on the ' +
    'client ever reached the third level - this is why the repair is two ' +
    'writes per entry and not one');
end;

procedure TTestRestGraphInsertEntities.TheChildOwnKeyIsReconciledFromEntities;
begin
  InsertWith(cANSWERWITHENTITIES);
  Assert.AreEqual(cMID0KEY, FRoot.mids[0].mid_id,
    'the child must carry the key the answer said was ITS OWN. ' +
    IntToStr(cPLACEHOLDER) + ' here means `entities` was not read at all');
end;

procedure TTestRestGraphInsertEntities
  .TheGrandchildOwnKeyIsReconciledFromEntities;
begin
  InsertWith(cANSWERWITHENTITIES);
  Assert.AreEqual(cLEAF00KEY, FRoot.mids[0].leafs[0].leaf_id,
    'the THIRD level, which nothing on the client could reach before');
  Assert.AreEqual(cLEAF01KEY, FRoot.mids[0].leafs[1].leaf_id,
    'and its brother, which is what makes the ordinal load-bearing');
end;

procedure TTestRestGraphInsertEntities
  .TheGrandchildForeignKeyPointsAtItsRealParent;
begin
  InsertWith(cANSWERWITHENTITIES);
  Assert.AreEqual(cMID0KEY, FRoot.mids[0].leafs[0].mid_id,
    'the leaf must point at the row its parent actually became. The answer ' +
    'names no FOREIGN key anywhere - this value can only come from walking ' +
    'one level down from the mid AFTER the mid was reconciled, which is the ' +
    'second write in the reader');
  Assert.AreEqual(cMID0KEY, FRoot.mids[0].leafs[1].mid_id,
    'and so must its brother');
  Assert.AreEqual(cROOTKEY, FRoot.mids[0].root_id,
    'while the mid keeps pointing at the root, as #301 already arranged');
end;

procedure TTestRestGraphInsertEntities.EachSiblingGetsItsOwnKeyAndNotItsBrothers;
begin
  InsertWith(cANSWERWITHENTITIES);
  Assert.AreEqual(cMID0KEY, FRoot.mids[0].mid_id,
    'THE CORRESPONDENCE, second level. Equal numbers on the two mids mean the ' +
    'reader matched by CLASS and took the first entry that fitted');
  Assert.AreEqual(cMID1KEY, FRoot.mids[1].mid_id,
    'and the second mid must get the SECOND number');
  Assert.AreEqual(cLEAF10KEY, FRoot.mids[1].leafs[0].leaf_id,
    'THE CORRESPONDENCE, third level. This leaf is `leafs[0]` of a DIFFERENT ' +
    'mid, so a resolver that ignored the ordinal of the FIRST segment would ' +
    'write ' + IntToStr(cLEAF00KEY) + ' here');
  Assert.AreEqual(cMID1KEY, FRoot.mids[1].leafs[0].mid_id,
    'and it must point at ITS own parent');
end;

procedure TTestRestGraphInsertEntities.TheRootIsStillReconciledFromParams;
begin
  InsertWith(cANSWERWITHENTITIES);
  Assert.AreEqual(cROOTKEY, FRoot.root_id,
    'the root comes out of `params` exactly as it did before this issue. Its ' +
    'entry in `entities` is skipped on purpose - two readers for one question ' +
    'is how two ends of a contract drift apart');
end;

procedure TTestRestGraphInsertEntities.TheOrderOfTheEntriesDoesNotMatter;
begin
  InsertWith(cANSWERREVERSED);
  Assert.AreEqual(cMID0KEY, FRoot.mids[0].mid_id,
    'the entries arrived deepest-first and the outcome is identical');
  Assert.AreEqual(cLEAF00KEY, FRoot.mids[0].leafs[0].leaf_id,
    'including the third level');
  Assert.AreEqual(cMID0KEY, FRoot.mids[0].leafs[0].mid_id,
    'AND the foreign key, which is the one that could have depended on order: ' +
    'the leaf''s entry was applied BEFORE the mid''s, and the mid''s own ' +
    'one-level walk is what writes this, so it still lands');
end;

procedure TTestRestGraphInsertEntities.AChildKeyNamedLikeTheRootsDoesNotTouchTheRoot;
begin
  InsertWith(cANSWERNAMINGTHEROOTKEYUNDERACHILD);
  Assert.AreEqual(cROOTKEY, FRoot.root_id,
    'THE RISK THIS DESIGN WAS BUILT AROUND. ' +
    IntToStr(cROOTSKEYNAMEUNDERACHILD) + ' here would mean a CHILD''s answer ' +
    'reached the ROOT''s key. It cannot: no entry of `entities` is ever added ' +
    'to ResultParams, and the reader for an entry is scoped to the primary ' +
    'key of the object the PATH resolved to');
  Assert.AreEqual(cPLACEHOLDER, FRoot.mids[0].mid_id,
    'and the child itself is untouched too - `root_id` is not one of ' +
    'TAitMid''s key columns, so the entry names nothing this object can take');
  Assert.AreEqual(cROOTKEY, FRoot.mids[0].root_id,
    'while the child''s FOREIGN key still holds what the root''s cascade put ' +
    'there - the entry did not overwrite that either');
end;

procedure TTestRestGraphInsertEntities
  .AnEntryNamingSomethingOtherThanTheTargetsKeyWritesNothing;
begin
  InsertWith(cANSWERNAMINGTHEROOTKEYUNDERACHILD);
  Assert.AreEqual('mid0', FRoot.mids[0].tag, False,
    'the reader is scoped to the target''s PRIMARY KEY. A non-key column of ' +
    'the child must be left alone even when the entry names it - and this is ' +
    'exactly where this family differs from the DataSet one, which writes any ' +
    'field the answer names');
end;

procedure TTestRestGraphInsertEntities
  .AnEntryWhosePathNamesNoAssociationWritesNothing;
begin
  InsertWith(cANSWERWITHANUNKNOWNPATH);
  Assert.AreEqual(cPLACEHOLDER, FRoot.mids[0].mid_id,
    'neither `tag` - a real property that is NOT a mapped association - nor ' +
    '`nosuchthing[0]` may resolve to anything. Navigation goes through the ' +
    'association mapping, so `entities` cannot reach into an arbitrary part ' +
    'of the object graph');
  Assert.AreEqual('root', FRoot.tag, False,
    'and the property the first path named must be untouched');
end;

procedure TTestRestGraphInsertEntities
  .AnEntryWhoseOrdinalIsPastTheEndOfTheListWritesNothing;
begin
  InsertWith(cANSWERWITHANOUTOFRANGEORDINAL);
  Assert.AreEqual(cPLACEHOLDER, FRoot.mids[0].mid_id,
    'the client holds two mids and the answer named the eighth. Nothing is ' +
    'written and nothing is raised - which is the whole reason the path is ' +
    'CHECKED rather than trusted the way a flat ordinal would have to be');
  Assert.AreEqual(cPLACEHOLDER, FRoot.mids[1].mid_id,
    'and it must not fall back to the last element either');
end;

procedure TTestRestGraphInsertEntities
  .AnEntryWhoseClassDisagreesWithTheObjectWritesNothing;
begin
  InsertWith(cANSWERWITHTHEWRONGCLASS);
  Assert.AreEqual(cPLACEHOLDER, FRoot.mids[0].mid_id,
    'the path resolved, and the producer says it measured a TAitLeaf. Writing ' +
    'that key here would be writing a real number onto the wrong object - ' +
    'the silent failure a bare ordinal could never have been checked against');
end;

procedure TTestRestGraphInsertEntities.AToManyAddressedWithoutAnOrdinalWritesNothing;
begin
  InsertWith(cANSWERWITHNOORDINALONATOMANY);
  Assert.AreEqual(cPLACEHOLDER, FRoot.mids[0].mid_id,
    '`mids` is to-MANY, so a segment without an ordinal names no single ' +
    'object. The multiplicity is asked on BOTH ends - the producer to write ' +
    'the segment, the reader to read it - so the two cannot disagree');
end;

procedure TTestRestGraphInsertEntities.AToOneAddressedWithAnOrdinalWritesNothing;
begin
  InsertPairWith(cANSWERWITHANORDINALONATOONE);
  Assert.AreEqual(cPLACEHOLDER, FPair.mid.mkey,
    '`mid` is to-ONE, so `mid[0]` is not an address into this graph. Without ' +
    'this half of the check the list branch would have to cast whatever the ' +
    'property holds to TObjectList<TObject> and read Count off it - an ' +
    'unchecked cast on a value that came off the wire');
end;

procedure TTestRestGraphInsertEntities.AnEntryWithNoClassIsStillRead;
begin
  InsertWith(cANSWERWITHNOCLASS);
  Assert.AreEqual(cMID0KEY, FRoot.mids[0].mid_id,
    '`class` is a CONFIRMATION and not a requirement. A third party server ' +
    'that sends only `path` and `keys` is still read');
end;

procedure TTestRestGraphInsertEntities.AToOneBranchIsResolvedAndDescended;
begin
  InsertPairWith(cANSWERFORTHETOONEROOT);
  Assert.AreEqual(cPAIRKEY, FPair.pkey,
    'premise: the root came out of `params` as usual');
  Assert.AreEqual(cPAIRMIDKEY, FPair.mid.mkey,
    'a to-ONE segment is the bare property name with NO ordinal. This shape ' +
    'is unreachable from the producer side fixture, because a body cannot ' +
    'put an object into a nil class-typed property');
  Assert.AreEqual(cPAIRLEAFKEY, FPair.mid.leafs[0].lkey,
    'and the resolver goes on descending underneath it, mixing the two ' +
    'segment shapes in one path');
  Assert.AreEqual(cPAIRMIDKEY, FPair.mid.leafs[0].lparent,
    'and the leaf under a to-one branch gets its parent stamped too');
end;

procedure TTestRestGraphInsertEntities
  .TheUncascadedAssociationGetsItsKeyButNoForeignKeyStamp;
begin
  InsertWith(cANSWERWITHENTITIES);
  Assert.AreEqual(cOTHERKEY, FRoot.others[0].other_id,
    '`others` carries CascadeInsert, so the server DID write that row and ' +
    'the answer reports its key. Reconciling it is right');
  Assert.AreEqual(cPLACEHOLDER, FRoot.others[0].root_id,
    'but `others` is declared WITHOUT CascadeAutoInc, so nothing may stamp ' +
    'its foreign key. That is the MAPPING''s decision and reading a new key ' +
    'must not have overruled it');
end;

procedure TTestRestGraphInsertEntities
  .TheAnswerTheExampleServersEmitIsReadExactlyAsBefore;
begin
  InsertWith(cEXAMPLESERVERANSWER);
  Assert.AreEqual(cROOTKEY, FRoot.root_id,
    'the four hand written servers under Examples\Delphi\RESTful write a ' +
    '`message` key and no `entities`. `nil is TJSONArray` is False, so the ' +
    'missing key leaves through the type guard and the client behaves ' +
    'exactly as it did');
  Assert.AreEqual(cROOTKEY, FRoot.mids[0].root_id,
    'including the cascade');
  Assert.AreEqual(cPLACEHOLDER, FRoot.mids[0].mid_id,
    'and including what it does NOT do: an answer with no `entities` still ' +
    'leaves the child on the placeholder. Nothing was invented for it');
end;

procedure TTestRestGraphInsertEntities.AnEntitiesKeyOfTheWrongTypeLeavesTheGraphAlone;
type
  TCase = record Doc: String; Why: String; end;
const
  cCASES: array[0..3] of TCase = (
    (Doc: cENTITIESISANOBJECT; Why: 'entities as an OBJECT'),
    (Doc: cENTITIESISASTRING;  Why: 'entities as a STRING'),
    (Doc: cENTITIESISANUMBER;  Why: 'entities as a NUMBER'),
    (Doc: cENTITIESISNULL;     Why: 'entities as JSON NULL - the most likely ' +
                                    'of the four in the field, because a ' +
                                    'server with nothing to say writes null ' +
                                    'rather than omitting the key'));
var
  LFor: Integer;
begin
  for LFor := Low(cCASES) to High(cCASES) do
  begin
    FreeAndNil(FRoot);
    InsertWith(cCASES[LFor].Doc);
    Assert.AreEqual(cROOTKEY, FRoot.root_id,
      cCASES[LFor].Why + ': `params` must still have been read. A guard ' +
      'written as a cast would have raised here and taken the root''s key ' +
      'with it');
    Assert.AreEqual(cPLACEHOLDER, FRoot.mids[0].mid_id,
      cCASES[LFor].Why + ': and nothing below the root may move');
  end;
end;

procedure TTestRestGraphInsertEntities
  .ARuinedElementIsSkippedAndItsSiblingsAreStillRead;
begin
  InsertWith(cANSWERWITHONERUINEDELEMENT);
  Assert.AreEqual(cMID0KEY, FRoot.mids[0].mid_id,
    'a bare number, an element with no `path`, an element with no `keys` and ' +
    'a null all sit in this array. The elements are INDEPENDENT - the same ' +
    'reading #315 settled for `params` - so the good ones are still read');
  Assert.AreEqual(cMID1KEY, FRoot.mids[1].mid_id,
    'including the one AFTER the ruined ones, which is what tells a `Continue` ' +
    'from an `Exit`');
end;

procedure TTestRestGraphInsertEntities
  .Premise_TheMixedGraphRootHasNoSequenceAndItsChildDoes;
begin
  // Without this the two clauses below could be green for the wrong reason -
  // if TCkrRoot ever gained a [Sequence] the ROOT-scoped gate would let the
  // read through and nothing would be measuring the mixed shape any more.
  Assert.IsNull(TMappingExplorer.GetMappingSequence(TCkrRoot),
    'premise: the ROOT has no [Sequence], so TSessionRestFul<M>.ExistSequence ' +
    'answers False for this aggregate. That is the whole point of the shape');
  Assert.IsNotNull(TMappingExplorer.GetMappingSequence(TCkrChild),
    'premise: and the CHILD does have one, so the server really does generate ' +
    'a key for it and really does have something to report');
end;

procedure TTestRestGraphInsertEntities
  .MixedGraph_TheChildWithItsOwnSequenceIsStillReconciled;
begin
  InsertMixedWith(cANSWERFORTHEMIXEDGRAPH);
  Assert.AreEqual(cCKRCHILDKEY, FMixed.childs[0].ckrchild_id,
    'THE BLOCKER THE FIRST DELIVERY OF #312 SHIPPED, and it is this issue''s ' +
    'own defect one level up. ' + IntToStr(cPLACEHOLDER) + ' here means the ' +
    'reader sat behind `if FSession.ExistSequence`, which asks ' +
    'GetMappingSequence of ONE class - the ROOT - and answers False for a ' +
    'root whose key the client supplies. The server generated this child''s ' +
    'key, reported it, and the client threw the whole array away. The gate ' +
    'has to be asked PER ENTITY, of the object the path resolved to');
end;

procedure TTestRestGraphInsertEntities
  .MixedGraph_TheClientSuppliedRootKeyIsNotTouched;
begin
  InsertMixedWith(cANSWERFORTHEMIXEDGRAPH);
  Assert.AreEqual(cCLIENTROOTKEY, FMixed.ckrroot_id,
    'the root has no [Sequence], so #301''s reading of `params` must stay ' +
    'skipped for it and the client''s own key must survive. Moving the graph ' +
    'reader out of that gate must NOT have moved the root''s reader with it');
  Assert.AreEqual(cCLIENTROOTKEY, FMixed.childs[0].ckrroot_id,
    'and the child''s foreign key was already right before the POST - nothing ' +
    'here may disturb it');
end;

procedure TTestRestGraphInsertEntities
  .Insert_AnEntryWhoseEntityHasNoSequenceOfItsOwnIsNotRead;
var
  LAdapter: TRESTObjectSetAdapter<TNikRoot>;
  LRoot: TNikRoot;
  LChild: TNikChild;
begin
  // THE SYMMETRIC SHAPE, and the one where the old root-scoped reason really
  // did hold: TNikRoot and TNikChild are BOTH NotInc with no [Sequence]. This
  // clause used to be the only thing measuring the gate, which is exactly how
  // the mixed case above went unmeasured - the doubtful case was not the one
  // on the bench.
  //
  // It stays green under the per-entity gate for a DIFFERENT reason than
  // before: not because the root has no sequence, but because the ENTITY the
  // entry resolves to has none.
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
    Assert.IsNull(TMappingExplorer.GetMappingSequence(TNikChild),
      'premise: the CHILD has no [Sequence] either - that is what makes this ' +
      'the symmetric shape rather than the mixed one');
    Assert.AreEqual(7, LRoot.nik_id,
      'the root: no [Sequence] means #301''s reading of `params` is skipped, ' +
      'and the client''s own value survives');
    Assert.AreEqual(1, LRoot.childs[0].child_id,
      'the child: with no sequence of ITS OWN there is no generated key to ' +
      'reconcile, so the entry naming it must be refused');
  finally
    LRoot.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRestGraphInsertEntities);

end.
