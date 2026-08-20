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

{ @abstract(Janus Framework - the REST client re-reads the aggregate it just
  inserted. Issue #297.)

  WHAT WAS WRONG

  TRESTDataSetAdapter<M>.ApplyInserter POSTs the whole aggregate in ONE call and
  then stamps the client from the answer. The answer - the shipped contract in
  Janus.Server.Resource.pas, cRESOURCEINSERT - names the ROOT's primary key and
  NOTHING ELSE. So after a save the client holds:

    aitroot.root_id  = the key the server generated          (stamped)
    aitmid.root_id   = the same key                          (cascade)
    aitmid.mid_id    = the AutoInc PLACEHOLDER               (never reconciled)
    aitleaf.mid_id   = the AutoInc PLACEHOLDER               (never reconciled)
    aitleaf.leaf_id  = the AutoInc PLACEHOLDER               (never reconciled)

  The SERVER is not wrong: Janus.Server.RestObjectSet repairs the placeholders it
  receives, level by level, before writing. What is wrong is the CLIENT, at
  levels two and three - the operator saves, sees keys that do not exist, and any
  UPDATE or DELETE issued from that screen aims at a row nobody has.

  WHAT THE REPAIR IS

  Re-read. After the POST the root DOES carry the server's key, and a GET on the
  route that already exists brings the whole graph back - the server's
  FillAssociation recurses and only skips Lazy associations. So the client asks
  once more and rewrites its own datasets from the answer. One extra GET per
  inserted root, no contract change, no new endpoint, and all THREE levels are
  reconciled instead of only the second.

  WHY THE FIXTURE ASSERTS ON THE CLIENT AND NOT ON "NOTHING RAISED"

  The double keeps every body it was handed and answers the POST and the GET
  DIFFERENTLY, so each clause can name the number that must appear on the client
  and where that number came from. `-1` is what the client had; 555 and 333 are
  what only the GET could have supplied.

  ONE COMMENT ELSEWHERE WAS MADE FALSE BY THIS FIX, AND IS CORRECTED WITH IT

  The doc comment over TDataSetBaseAdapter<M>._AutoIncKeyIsGenerated, in
  Janus.DataSet.Base.Adapter, said of the REST family "nao ha nada depois ... e
  o neto FICA com o placeholder como chave estrangeira". After this issue there
  IS something after - ApplyInserter re-reads the aggregate - and
  ReRead_TheLeafForeignKeyPointsAtTheMidTheServerWrote is the measurement:
  leaf.mid_id comes out 555 where it used to come out -1.
  That file was held by another branch while the first half of this work was
  written, so the correction was reported and deferred; #296 has since merged
  and the sentence is now corrected in place. What that comment says about the
  guard refusing to PROPAGATE a placeholder was never affected: the re-read is a
  LATER repair that depends on an answer, while the write that guard refuses
  happens before any answer exists.

  AND SINCE ISSUE #305 THIS FIXTURE ALSO MEASURES THE VOICE

  #297 left SEVEN doors out of a save that end with the client's graph stale,
  and they collapse into SIX cases because two of them are the same silence.
  Enumerated, and enumerated because an earlier version of this paragraph said
  FIVE and was made false by the review of #305:

    ApplyInserter, the root HAS a sequence
      1. the answer carried no `params`                  -> sgcNoKeyToAskBy
      2. `params` named no column of this row            -> sgcNoKeyToAskBy
    ApplyInserter, the root has NO sequence
      3. the re-read was never attempted                 -> sgcReReadNeverAttempted
    _ReReadStaleRoots
      4. more than one root in this save                 -> sgcMultiRootNotReRead
    the re-read was issued and refused
      5. no row came back                                -> sgcAnswerHadNoRow
      6. the row that came back was another one          -> sgcAnswerWasAnotherRow
      7. the answer was shallower than the client        -> sgcAnswerWasShallower

  #305 named four of those seven. Door 3 and door 7 it did not: door 7 is the
  depth guard, which a Lazy sibling branch produces on the SHIPPED server, and
  door 3 needs a root with no [Sequence], which no model in this repository
  pointed at a REST adapter until Test.Janus.Model.ClientKeyRoot was written for
  it.

  Every door except 3 already had a clause here pinning WHAT THE CLIENT DID; the
  Voice_ block at the bottom pins WHAT THE CLIENT WAS TOLD, over the same doubles
  and the same seeds. The two halves are kept apart on purpose: not one of the
  twenty-five clauses that predate the voice was edited, so if the voice had cost
  behaviour they would be the red ones.

  RAISING WAS REFUSED BY MEASUREMENT AND STAYS REFUSED - see
  Detector_AllThreePhasesRunInsideTheSameCall, which pins that all three phases
  run inside one call, so an exception at the end of the insert phase costs the
  operator the update AND the delete of that same save.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Rest.ReReadAfterInsert;

interface

uses
  DB,
  Classes,
  SysUtils,
  Generics.Collections,
  DBClient,
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
  Janus.DataSet.Base.Adapter,
  Janus.DataSet.Fields,
  Janus.RestDataSet.Adapter,
  Janus.RestDataSet.ClientDataSet,
  Janus.RestDataSet.FDMemTable,
  Test.Janus.Model.AutoIncTree,
  Test.Janus.Model.ClientKeyRoot;

type
  /// <summary> An ICommandMonitor that keeps every line it is handed - issue
  ///  #305. TReplayRestConnection answered nil to CommandMonitor and every
  ///  monitor branch in the family is guarded by `<> nil`, so before this class
  ///  existed not one of those branches was reached by this fixture at all.
  ///
  ///  IT IS HANDED IN PER CLAUSE AND NEVER BY DEFAULT. Attaching it in Setup
  ///  would switch on the monitor branch of every verb of TSessionRestFul<M> for
  ///  the twenty-five clauses that predate #305, which is a change none of them
  ///  asked for. </summary>
  TMonitorSpy = class(TInterfacedObject, ICommandMonitor)
  private
    FLines: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Command(const ASQL: String; AParams: TParams);
    procedure Show;
    function Text: String;
    property Lines: TStringList read FLines;
  end;
  /// <summary> An IRESTConnection that answers the POST and the GET with
  ///  DIFFERENT documents, and remembers both what it was handed and how many
  ///  times each verb was used.
  ///
  ///  WHY A THIRD DOUBLE. TRecordingRestConnection (Common\) has ONE canned
  ///  answer for every verb, which cannot express the thing under test here:
  ///  the POST answers the shipped insert contract - the root key and nothing
  ///  else - and the GET answers the graph. TCapturingRestConnection, in
  ///  Test.Janus.Grandchild.Read, answers '{}' to everything and belongs to
  ///  another fixture. This one is declared here for the same reason that one
  ///  was declared there: two fixtures editing one double is how doubles grow
  ///  answers nobody asked for. </summary>
  TReplayRestConnection = class(TInterfacedObject, IRESTConnection)
  private
    FBodies: TStringList;
    FQueries: TStringList;
    FPending: String;
    FPendingQuery: String;
    FPostCount: Integer;
    FGetCount: Integer;
    FPutCount: Integer;
    FDeleteCount: Integer;
    FPostAnswer: String;
    FPostAnswers: TStringList;
    FGetAnswer: String;
    FGetAnswers: TStringList;
    /// nil unless a clause hands one in - see TMonitorSpy.
    FMonitor: ICommandMonitor;
    function DoExecute(const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc): String;
  public
    constructor Create;
    destructor Destroy; override;
    function GetBaseURL: String;
    function GetFullURL: String;
    function GetUsername: String;
    function GetPassword: String;
    function GetMethodGET: String;
    function GetMethodGETId: String;
    function GetMethodGETWhere: String;
    function GetMethodPOST: String;
    function GetMethodPUT: String;
    function GetMethodDELETE: String;
    function GetMethodGETNextPacket: String;
    function GetMethodGETNextPacketWhere: String;
    function GetMethodToken: String;
    function GetServerUse: Boolean;
    procedure SetCommandMonitor(AMonitor: ICommandMonitor);
    procedure SetClassNotServerUse(const Value: Boolean);
    function CommandMonitor: ICommandMonitor;
    function Execute(const AResource, ASubResource: String;
      const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): String; overload;
    function Execute(const AResource: String;
      const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): String; overload;
    procedure AddParam(AValue: String);
    procedure AddQueryParam(AValue: String);
    procedure AddBodyParam(AValue: String);
    property Bodies: TStringList read FBodies;
    property Queries: TStringList read FQueries;
    property PostCount: Integer read FPostCount;
    property GetCount: Integer read FGetCount;
    property PutCount: Integer read FPutCount;
    property DeleteCount: Integer read FDeleteCount;
    /// One answer per POST, consumed in order. Empty means "the same answer
    ///  every time" - which is fine for one root and a LIE for two, because two
    ///  roots that come back on the SAME primary key are not two roots.
    procedure QueuePostAnswer(const AAnswer: String);
    /// The same, per GET.
    procedure QueueGetAnswer(const AAnswer: String);
    property PostAnswer: String read FPostAnswer write FPostAnswer;
    property GetAnswer: String read FGetAnswer write FGetAnswer;
  end;

  /// <summary> Classic cracker descendants: ApplyUpdates is protected in both
  ///  concrete REST adapters, and the writing path is the only place the defect
  ///  lives. Same technique Test.Janus.Rest.CascadeGuard uses. </summary>
  TMemApply<M: class, constructor> = class(TRESTFDMemTableAdapter<M>)
  public
    class procedure Apply(const A: TRESTFDMemTableAdapter<M>);
  end;

  TCdsApply<M: class, constructor> = class(TRESTClientDataSetAdapter<M>)
  public
    class procedure Apply(const A: TRESTClientDataSetAdapter<M>);
  end;

  /// <summary> Reaches the event swap of the base adapter, which is what
  ///  decides HOW the re-read may be issued. See
  ///  Design_TheEventSwitchIsASwapAndNotACounter. </summary>
  TEventCrack<M: class, constructor> = class(TDataSetBaseAdapter<M>)
  public
    class procedure Off(const A: TDataSetBaseAdapter<M>);
    class procedure On_(const A: TDataSetBaseAdapter<M>);
  end;

  [TestFixture]
  TTestRestReReadAfterInsert = class
  private
    FRep: TReplayRestConnection;
    FConn: IRESTConnection;
    FRootMem: TFDMemTable;
    FMidMem: TFDMemTable;
    FLeafMem: TFDMemTable;
    FMemRoot: TRESTFDMemTableAdapter<TAitRoot>;
    FMemMid: TRESTFDMemTableAdapter<TAitMid>;
    FMemLeaf: TRESTFDMemTableAdapter<TAitLeaf>;
    FRootCds: TClientDataSet;
    FMidCds: TClientDataSet;
    FLeafCds: TClientDataSet;
    FCdsRoot: TRESTClientDataSetAdapter<TAitRoot>;
    FCdsMid: TRESTClientDataSetAdapter<TAitMid>;
    FCdsLeaf: TRESTClientDataSetAdapter<TAitLeaf>;
    FLoneMem: TFDMemTable;
    FLone: TRESTFDMemTableAdapter<TAitLeaf>;
    FOtherMem: TFDMemTable;
    FOther: TRESTFDMemTableAdapter<TAitNoCascade>;
    /// The client-key tree - issue #305, the third door. A root with NO
    /// [Sequence] over a child that HAS one: the only shape in the repository
    /// where FSession.ExistSequence answers False on a REST adapter.
    FCkRootMem: TFDMemTable;
    FCkChildMem: TFDMemTable;
    FCkRoot: TRESTFDMemTableAdapter<TCkrRoot>;
    FCkChild: TRESTFDMemTableAdapter<TCkrChild>;
    // -- issue #305, the voice ------------------------------------------------
    FSpy: TMonitorSpy;
    /// The spy is a TInterfacedObject: something has to hold the interface or it
    /// is freed the moment the connection lets go of it.
    FSpyRef: ICommandMonitor;
    FHeard: TList<TStaleGraphCase>;
    FHeardEntity: String;
    FHeardSender: TObject;
    /// The handler a clause assigns to OnStaleGraph. Writes down what it was
    /// told, and nothing else - the voice is not allowed to depend on what the
    /// consumer does with it.
    procedure OnStale(const ASender: TObject; const ACase: TStaleGraphCase;
      const AEntity: String);
    procedure AttachMonitor;
    function StaleLines: String;
    procedure BuildClientKeyTree;
    procedure SeedClientKeyTree;
    procedure BuildMemTree;
    procedure BuildCdsTree;
    procedure SeedRoot(const ADataSet: TDataSet; const ATag: String);
    procedure SeedMid(const ADataSet: TDataSet; const ATag: String);
    procedure SeedLeaf(const ADataSet: TDataSet; const ATag: String);
    procedure SeedTree(const ARoot, AMid, ALeaf: TDataSet);
    procedure RunMem;
    procedure RunCds;
    function KeyOf(const ADataSet: TDataSet; const AColumn: String): Integer;
    function AllQueries: String;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // -----------------------------------------------------------------------
    // Premises. If any of these is red every clause under it measures nothing.
    // -----------------------------------------------------------------------

    /// The aggregate really does leave in ONE POST, and the root really does
    /// take the key the answer named. Green before AND after the repair - it is
    /// the half that already worked.
    [Test]
    procedure Premise_OnePostCarriesTheWholeGraphAndTheRootTakesTheAnsweredKey;
    /// And what left on the wire really did carry the placeholder below the
    /// root - otherwise there would be nothing to reconcile.
    [Test]
    procedure Premise_ThePayloadCarriedThePlaceholderBelowTheRoot;

    // -----------------------------------------------------------------------
    // The defect, in the family that ships it. RED before the repair.
    // -----------------------------------------------------------------------

    /// The middle row's OWN key. Before: -1, the placeholder it was typed with.
    /// After: 555, a number that exists nowhere but in the GET answer.
    [Test]
    procedure ReRead_TheMidRowTakesTheKeyOnlyTheServerKnew;
    /// The grandchild's own key. Level three is the one the reorder option
    /// could never reach.
    [Test]
    procedure ReRead_TheLeafRowTakesTheKeyOnlyTheServerKnew;
    /// And the grandchild's FOREIGN key now points at the middle row the server
    /// actually wrote, instead of at the placeholder.
    [Test]
    procedure ReRead_TheLeafForeignKeyPointsAtTheMidTheServerWrote;
    /// The re-read asks for the row by the key the SERVER returned. Asking by
    /// the placeholder would answer nothing and reconcile nothing.
    [Test]
    procedure ReRead_TheGetAsksByTheKeyTheServerReturned;

    // -----------------------------------------------------------------------
    // The other REST family. Measured, not assumed, before and after.
    // -----------------------------------------------------------------------

    [Test]
    procedure Cds_TheMidRowTakesTheKeyOnlyTheServerKnew;
    [Test]
    procedure Cds_TheLeafRowTakesTheKeyOnlyTheServerKnew;
    [Test]
    procedure Cds_TheLeafForeignKeyPointsAtTheMidTheServerWrote;

    // -----------------------------------------------------------------------
    // What the extra GET costs, and where it must NOT happen.
    // -----------------------------------------------------------------------

    /// A root with no child adapter registered has nothing to reconcile, and
    /// pays nothing.
    [Test]
    procedure Cost_AnAggregateWithNoChildrenCostsNoGet;
    /// Exactly ONE GET for one inserted root - not one per level and not one
    /// per child row.
    [Test]
    procedure Cost_OneInsertedRootCostsExactlyOneGet;
    /// No `params` in the answer means the root's own key is unknown, so there
    /// is nothing to ask BY. The re-read must not fire on a placeholder.
    [Test]
    procedure Cost_WithoutResultParamsNoGetIsIssued;
    /// A child under an association the model did NOT mark CascadeAutoInc had
    /// no key generated for it by this insert, so a placeholder there is the
    /// consumer's own value and reconciles nothing. TAitRoot.others is the only
    /// association in the repository shaped to ask this.
    [Test]
    procedure Cost_APlaceholderUnderANonCascadeAssociationBuysNoGet;
    /// The middle row already carries a key the operator typed, and ONLY the
    /// grandchild is still on the placeholder. Level two answers "nothing wrong
    /// here" and the re-read must fire anyway - which is what makes the walk
    /// recursive instead of one level deep.
    [Test]
    procedure Cost_AStaleGrandchildAloneStillBuysTheGet;
    /// Every level already carries a key of its own. Nothing is stale, so there
    /// is nothing to ask about - the last of the Cost_ shapes that pay nothing,
    /// and the only one that had no clause of its own.
    /// COUNTED BY NAME AND NOT BY ORDINAL ANY MORE. This line used to call it
    /// "the fifth", which #305 made false without touching it: the no-sequence
    /// root of Voice_TheNoSequenceRootReallyReachesThatDoor is one more shape
    /// that buys no GET. An ordinal in a comment is a claim about a population,
    /// and populations grow.
    [Test]
    procedure Cost_AGraphThatAlreadyCarriesEveryKeyBuysNoGet;
    /// `params` came back, but named no column this row has - so the stamp
    /// wrote nothing and the root is STILL on the placeholder. Gating on
    /// "params arrived" instead of "the key arrived" sent the GET out as
    /// $filter=root_id=-1, a round trip that can only answer somebody else's
    /// row or nothing at all - and it contradicted the message of the clause
    /// right above it, which says the re-read must not fire on a placeholder.
    [Test]
    procedure Cost_ParamsThatNameNoColumnOfThisRowBuyNoGet;

    // -----------------------------------------------------------------------
    // An answer SHALLOWER than the graph the client is holding.
    // -----------------------------------------------------------------------

    /// The answer carries the middle level but not the grandchild - which is
    /// what the shipped server does whenever the association is Lazy, because
    /// TRESTObjectManager.FillAssociation skips exactly those. Applying it
    /// would empty a grandchild dataset the server had JUST written from the
    /// POST, and nothing would ever put those rows back.
    [Test]
    procedure Shallow_AnAnswerMissingTheGrandchildBranchIsRefused;
    /// The same one level up: the answer carries no children at all, while the
    /// client holds children that went out in that very POST.
    [Test]
    procedure Shallow_AnAnswerWithNoChildBranchAtAllIsRefused;
    /// The control that keeps the two above from being a blanket refusal: where
    /// the CLIENT holds nothing, an answer that carries nothing is not shallow -
    /// it agrees, and the levels that ARE there must still be reconciled.
    [Test]
    procedure Shallow_AnAnswerIsNotRefusedForALevelTheClientDoesNotHold;
    /// ONE object of a list reaching the level below is enough. Two middle rows
    /// where only the first has grandchildren is an ordinary aggregate, and
    /// demanding that EVERY object reach deeper would refuse the correct answer
    /// to it.
    [Test]
    procedure Shallow_OneObjectOfTheListReachingDeeperIsEnough;

    // -----------------------------------------------------------------------
    // The design constraint the repair had to obey.
    // -----------------------------------------------------------------------

    /// TWO roots saved in ONE ApplyUpdates are left alone, and that is a
    /// measurement and not a preference. RefreshRecordInternal empties the
    /// child datasets WHOLE, and deleting a middle row still fires its own
    /// CascadeDelete, which empties the grandchild dataset whole as well.
    /// Measured at f7f8e76, already on top of #296, with this guard removed and
    /// every other guard in place, over this same tree and with the double
    /// answering a DIFFERENT key per root - 777 and 888 - and a graph of its own
    /// per root: `roots=2 mids=1 leafs=1 posts=2 gets=2`. The second root's
    /// re-read took the first root's already reconciled children with it.
    /// The distinct keys are part of the measurement: with both roots answering
    /// the SAME key, the loss could have been an artefact of two roots the
    /// fixture cannot tell apart. It is not. That is WORSE than the defect, so
    /// in this case the client is
    /// left exactly as it was before this fix: placeholders below the root, and
    /// not one row lost.
    [Test]
    procedure MultiRoot_TwoRootsSavedTogetherAreLeftAloneAndKeepEveryRow;
    /// The server answers the re-read with NO row - the aggregate was deleted
    /// by somebody else between the POST and the GET, or the resource does not
    /// serve it. Before the guard this raised EArgumentOutOfRange out of
    /// TSessionRestFul<M>.RefreshRecord and aborted the save AFTER the server
    /// had already written.
    [Test]
    procedure Empty_AGetThatFindsNothingLeavesTheClientAsItWas;
    /// The answer is a document that is NOT this row. Rewriting the client from
    /// it would be silent data loss, and it stopped being hypothetical when the
    /// re-read started firing on its own after every insert.
    [Test]
    procedure Foreign_AnAnswerThatIsNotThisRowIsDiscarded;

    /// What a "shout at the end of ApplyInserter" would cost, measured instead
    /// of assumed. ApplyInserter is the FIRST of the three phases
    /// ApplyInternal runs inside one try, and ApplyUpdates clears
    /// FSession.DeleteList in its own finally whatever happened. So an
    /// exception raised at the end of the insert phase does not merely report -
    /// it drops the update and the delete the operator asked for in the same
    /// save, and the delete list is emptied on the way out, so nothing will
    /// re-send them. This clause pins that all three phases really do run in
    /// one call, which is the premise that makes the cost real.
    [Test]
    procedure Detector_AllThreePhasesRunInsideTheSameCall;

    /// TDataSetBaseAdapter<M>.RefreshRecord brackets its work with
    /// DisableDataSetEvents/EnableDataSetEvents, and that pair is a SWAP and
    /// not a counter: a second Disable finds the handlers already nil and
    /// stashes nothing, so the matching Enable puts the ORIGINAL handlers back
    /// while the outer caller still believes they are off. Inside ApplyInternal
    /// that would re-arm DoBeforePost before ApplyUpdater runs, and ApplyUpdater
    /// does not terminate with it armed - the load-bearing note on
    /// DisableDataSetEvents in both REST ApplyInternal overrides. This is why
    /// the re-read calls the SESSION entry point directly instead of the
    /// adapter's RefreshRecord wrapper.
    [Test]
    procedure Design_TheEventSwitchIsASwapAndNotACounter;

    // -----------------------------------------------------------------------
    // ISSUE #305 - THE VOICE. Every clause below drives one of the exits above
    // and asks what the client was TOLD, never what it did. The exits
    // themselves are already pinned by the clauses above, and none of them was
    // edited: if the voice had changed behaviour, those would be the red ones.
    // -----------------------------------------------------------------------

    /// Case (1), the grave one. No `params` came back, so no key came back, so
    /// no re-read is possible - and the aggregate the server WROTE is now
    /// reachable by a key this client will never learn. The clause right above
    /// this block, Cost_WithoutResultParamsNoGetIsIssued, pins that no GET is
    /// bought; this one pins that the client is no longer silent about it.
    [Test]
    procedure Voice_NoKeyToAskByIsAnnounced;
    /// The same case reached through the OTHER door: `params` did come back but
    /// named no column of this row, so the stamp wrote nothing and the root is
    /// still on the placeholder. Same silence, same consequence, so the same
    /// case - and this clause is what says so out loud rather than leaving it
    /// to be inferred from the code.
    [Test]
    procedure Voice_ParamsThatNameNoColumnAnnounceTheSameCase;
    /// Case (2). Two roots in one save: the re-read is off ON PURPOSE and every
    /// row the operator typed survives, so this must NOT be announced as the
    /// orphan case.
    [Test]
    procedure Voice_MultiRootIsAnnouncedAsItsOwnCase;
    /// Case (3). The GET found nothing. The client's own data is intact, which
    /// is precisely why it must be distinguishable from case (1).
    [Test]
    procedure Voice_AnEmptyAnswerIsAnnouncedAndIsNotTheOrphanCase;
    /// Case (4). The GET answered somebody else's row and the identity guard
    /// refused it. Again intact, again not case (1).
    [Test]
    procedure Voice_AForeignAnswerIsAnnouncedAndIsNotTheOrphanCase;
    /// The FIFTH exit, which #305 did not name: the depth guard refused an
    /// answer shallower than the graph the client holds. It is the exit a Lazy
    /// branch produces on the shipped server, so it is the one a consumer meets
    /// most often. Its own case, not folded into any of the four.
    [Test]
    procedure Voice_AShallowAnswerIsAnnouncedUnderItsOwnCase;
    /// THE CONTROL. A save whose graph really was reconciled announces NOTHING.
    /// Without this, a voice wired to fire unconditionally would pass every
    /// clause above.
    [Test]
    procedure Voice_ACleanSaveAnnouncesNothingAtAll;
    /// And the state is of THIS save, not of the last one: a stale save
    /// followed by a clean one comes out empty.
    [Test]
    procedure Voice_TheStateIsClearedAtTheStartOfTheNextSave;
    /// The handler hears the same case the property records, and hears WHICH
    /// entity and from WHICH adapter - a screen with several aggregates open
    /// cannot act on "something went stale".
    [Test]
    procedure Voice_TheHandlerHearsTheCaseTheEntityAndTheSender;
    /// The handler is nil until a consumer assigns one. This is the half that
    /// makes "additive" a measurement rather than a claim: the clauses above
    /// that assign nothing drive the very same exits and see the very same
    /// client state.
    [Test]
    procedure Voice_NoHandlerIsAssignedByDefault;
    /// The monitor gets a line, in the format the rest of the family already
    /// writes - and the line names the CASE, not merely that something is
    /// stale.
    [Test]
    procedure Voice_TheMonitorGetsALineNamingTheCase;
    /// And the monitor stays quiet when the save was clean. The monitor is
    /// attached in both clauses, so the difference is the save and not the
    /// wiring.
    [Test]
    procedure Voice_TheMonitorIsSilentOnACleanSave;
    /// The two families converge here too - neither overrides ApplyInserter -
    /// and this clause is what keeps that a measurement instead of the
    /// "identical to its sibling" argument.
    [Test]
    procedure Voice_Cds_TheOrphanCaseIsAnnouncedThereToo;

    /// THE THIRD DOOR of ApplyInserter, and the one that had no fixture at all
    /// until Test.Janus.Model.ClientKeyRoot was written for it. The root's key
    /// came from the OPERATOR - TAutoIncType.NotInc, no [Sequence] - so
    /// FSession.ExistSequence answers False, the stamping block is skipped
    /// whole, no bookmark is taken and the re-read is never attempted. The
    /// child, which DOES have a sequence, is left on its placeholder.
    /// WHY IT IS ITS OWN CASE. A GET on the key the operator typed would work,
    /// so nothing is orphaned and nothing is lost - the exact opposite of what
    /// the sgcNoKeyToAskBy sentence tells the reader. This clause pins the case
    /// AND the sentence, because a case that carried a false sentence would be
    /// the same defect wearing a nicer name.
    [Test]
    procedure Voice_ARootWithNoSequenceIsItsOwnCaseAndNotTheOrphanOne;
    /// And the premise the clause above rests on, measured separately so a
    /// green result there can never be an accident of a save that did nothing:
    /// the aggregate really was POSTed, no GET was bought, and the child really
    /// is sitting on the placeholder.
    [Test]
    procedure Voice_TheNoSequenceRootReallyReachesThatDoor;
  end;

implementation

const
  cROOTKEY = 'root_id';
  cMIDKEY  = 'mid_id';
  cLEAFKEY = 'leaf_id';
  cOTHERKEY = 'other_id';
  cTAG     = 'tag';
  cPLACEHOLDER = -1;
  /// The client-key pair - issue #305, the third door.
  cCKROOTKEY  = 'ckrroot_id';
  cCKCHILDKEY = 'ckrchild_id';
  /// The key the OPERATOR typed into the root. Distinct from every server key
  /// below and from the placeholder, so "the client already knew this" can
  /// never be confused with "the answer supplied it" - no answer in this
  /// fixture ever names it.
  cTYPEDKEY = 4242;
  /// The three numbers the server generated. They are DIFFERENT from each other
  /// and from the placeholder on purpose: a repair that copied the root's key
  /// downwards would look green if they were equal.
  cSRVROOT = 777;
  cSRVMID  = 555;
  cSRVLEAF = 333;
  /// Distinct from every key above AND from the placeholder, so "the row is not
  /// there at all" can never be read as "the row is there with the wrong key".
  cNOROWATALL = -99;

  /// Verbatim shape of Janus.Server.Resource.pas cRESOURCEINSERT, filled the way
  /// TAppResourceBase.ParseInsert fills it: the ROOT primary key and nothing
  /// else.
  cPOSTANSWER =
    '{"result":"Resource aitroot insert command executed successfully",' +
    '"params":[{"root_id":777}]}';
  /// The same answer with the element the client gates on removed.
  cPOSTNOPARAMS =
    '{"result":"Resource aitroot insert command executed successfully"}';
  /// What the GET route already answers: the whole graph, because the server's
  /// FillAssociation recurses and only skips Lazy associations.
  cGETANSWER =
    '[{"root_id":777,"tag":"root","others":[],"mids":[' +
      '{"mid_id":555,"root_id":777,"tag":"mid","leafs":[' +
        '{"leaf_id":333,"mid_id":555,"root_id":777,"tag":"leaf"}]}]}]';

{ TReplayRestConnection }

constructor TReplayRestConnection.Create;
begin
  inherited Create;
  FBodies := TStringList.Create;
  FQueries := TStringList.Create;
  FPostAnswers := TStringList.Create;
  FGetAnswers := TStringList.Create;
  FPostAnswer := cPOSTANSWER;
  FGetAnswer := cGETANSWER;
end;

destructor TReplayRestConnection.Destroy;
begin
  FGetAnswers.Free;
  FPostAnswers.Free;
  FQueries.Free;
  FBodies.Free;
  inherited;
end;

/// The framework pushes body and query from INSIDE the callback, so the
/// transcript can only be closed after it has run. Running it is also what makes
/// the body observable at all.
function TReplayRestConnection.DoExecute(
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): String;
begin
  FPending := '';
  FPendingQuery := '';
  if Assigned(AParams) then
    AParams();
  if FPending <> '' then
    FBodies.Add(FPending);
  if FPendingQuery <> '' then
    FQueries.Add(FPendingQuery);
  case ARequestMethod of
    TRESTRequestMethodType.rtPOST:
      begin
        Inc(FPostCount);
        if FPostCount <= FPostAnswers.Count then
          Result := FPostAnswers[FPostCount - 1]
        else
          Result := FPostAnswer;
      end;
    TRESTRequestMethodType.rtGET:
      begin
        Inc(FGetCount);
        if FGetCount <= FGetAnswers.Count then
          Result := FGetAnswers[FGetCount - 1]
        else
          Result := FGetAnswer;
      end;
    TRESTRequestMethodType.rtPUT:
      begin
        Inc(FPutCount);
        Result := '{}';
      end;
    TRESTRequestMethodType.rtDELETE:
      begin
        Inc(FDeleteCount);
        Result := '{}';
      end;
  else
    // An empty JSON OBJECT and never '': TSessionRestFul<M> indexes the answer
    // before parsing it and these projects compile with range checking on.
    Result := '{}';
  end;
end;

function TReplayRestConnection.Execute(const AResource, ASubResource: String;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): String;
begin
  Result := DoExecute(ARequestMethod, AParams);
end;

function TReplayRestConnection.Execute(const AResource: String;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): String;
begin
  Result := DoExecute(ARequestMethod, AParams);
end;

procedure TReplayRestConnection.QueuePostAnswer(const AAnswer: String);
begin
  FPostAnswers.Add(AAnswer);
end;

procedure TReplayRestConnection.QueueGetAnswer(const AAnswer: String);
begin
  FGetAnswers.Add(AAnswer);
end;

procedure TReplayRestConnection.AddBodyParam(AValue: String);
begin
  FPending := FPending + AValue;
end;

procedure TReplayRestConnection.AddQueryParam(AValue: String);
begin
  FPendingQuery := FPendingQuery + AValue;
end;

procedure TReplayRestConnection.AddParam(AValue: String);
begin
end;

function TReplayRestConnection.CommandMonitor: ICommandMonitor;
begin
  Result := FMonitor;
end;

procedure TReplayRestConnection.SetCommandMonitor(AMonitor: ICommandMonitor);
begin
  FMonitor := AMonitor;
end;

{ TMonitorSpy }

constructor TMonitorSpy.Create;
begin
  inherited Create;
  FLines := TStringList.Create;
end;

destructor TMonitorSpy.Destroy;
begin
  FLines.Free;
  inherited;
end;

procedure TMonitorSpy.Command(const ASQL: String; AParams: TParams);
begin
  FLines.Add(ASQL);
end;

procedure TMonitorSpy.Show;
begin
end;

function TMonitorSpy.Text: String;
begin
  Result := FLines.Text;
end;

procedure TReplayRestConnection.SetClassNotServerUse(const Value: Boolean);
begin
end;

function TReplayRestConnection.GetBaseURL: String;
begin
  Result := 'http://replayed.local';
end;

function TReplayRestConnection.GetFullURL: String;
begin
  Result := 'http://replayed.local';
end;

function TReplayRestConnection.GetUsername: String;
begin
  Result := '';
end;

function TReplayRestConnection.GetPassword: String;
begin
  Result := '';
end;

function TReplayRestConnection.GetMethodGET: String;
begin
  Result := '';
end;

function TReplayRestConnection.GetMethodGETId: String;
begin
  Result := '';
end;

function TReplayRestConnection.GetMethodGETWhere: String;
begin
  Result := '';
end;

function TReplayRestConnection.GetMethodPOST: String;
begin
  Result := '';
end;

function TReplayRestConnection.GetMethodPUT: String;
begin
  Result := '';
end;

function TReplayRestConnection.GetMethodDELETE: String;
begin
  Result := '';
end;

function TReplayRestConnection.GetMethodGETNextPacket: String;
begin
  Result := '';
end;

function TReplayRestConnection.GetMethodGETNextPacketWhere: String;
begin
  Result := '';
end;

function TReplayRestConnection.GetMethodToken: String;
begin
  Result := '';
end;

function TReplayRestConnection.GetServerUse: Boolean;
begin
  Result := False;
end;

{ TMemApply<M> }

class procedure TMemApply<M>.Apply(const A: TRESTFDMemTableAdapter<M>);
begin
  TMemApply<M>(A).ApplyUpdates(0);
end;

{ TCdsApply<M> }

class procedure TCdsApply<M>.Apply(const A: TRESTClientDataSetAdapter<M>);
begin
  TCdsApply<M>(A).ApplyUpdates(0);
end;

{ TEventCrack<M> }

class procedure TEventCrack<M>.Off(const A: TDataSetBaseAdapter<M>);
begin
  TEventCrack<M>(A).DisableDataSetEvents;
end;

class procedure TEventCrack<M>.On_(const A: TDataSetBaseAdapter<M>);
begin
  TEventCrack<M>(A).EnableDataSetEvents;
end;

{ TTestRestReReadAfterInsert }

procedure TTestRestReReadAfterInsert.Setup;
begin
  FRep := TReplayRestConnection.Create;
  FConn := FRep;
  FHeard := TList<TStaleGraphCase>.Create;
  FHeardEntity := '';
  FHeardSender := nil;
  FSpy := nil;
  FSpyRef := nil;
end;

procedure TTestRestReReadAfterInsert.OnStale(const ASender: TObject;
  const ACase: TStaleGraphCase; const AEntity: String);
begin
  FHeard.Add(ACase);
  FHeardEntity := AEntity;
  FHeardSender := ASender;
end;

procedure TTestRestReReadAfterInsert.AttachMonitor;
begin
  FSpy := TMonitorSpy.Create;
  FSpyRef := FSpy;
  FRep.SetCommandMonitor(FSpyRef);
end;

/// Only the lines the VOICE wrote. The session writes a line per verb onto the
/// same monitor, so counting everything would measure the traffic and not the
/// warning.
function TTestRestReReadAfterInsert.StaleLines: String;
var
  LFor: Integer;
begin
  Result := '';
  if FSpy = nil then
    Exit;
  for LFor := 0 to FSpy.Lines.Count -1 do
    if Pos(cSTALEGRAPHWARNING, FSpy.Lines[LFor]) > 0 then
      Result := Result + FSpy.Lines[LFor] + sLineBreak;
end;

procedure TTestRestReReadAfterInsert.TearDown;
begin
  FreeAndNil(FOther);
  FreeAndNil(FOtherMem);
  FreeAndNil(FLone);
  FreeAndNil(FLoneMem);
  FreeAndNil(FCdsLeaf);
  FreeAndNil(FCdsMid);
  FreeAndNil(FCdsRoot);
  FreeAndNil(FLeafCds);
  FreeAndNil(FMidCds);
  FreeAndNil(FRootCds);
  FreeAndNil(FMemLeaf);
  FreeAndNil(FMemMid);
  FreeAndNil(FMemRoot);
  FreeAndNil(FLeafMem);
  FreeAndNil(FMidMem);
  FreeAndNil(FRootMem);
  FreeAndNil(FCkChild);
  FreeAndNil(FCkChildMem);
  FreeAndNil(FCkRoot);
  FreeAndNil(FCkRootMem);
  FConn := nil;
  FRep := nil;
  FSpy := nil;
  FSpyRef := nil;
  FreeAndNil(FHeard);
end;

procedure TTestRestReReadAfterInsert.BuildMemTree;
begin
  FRootMem := TFDMemTable.Create(nil);
  FMemRoot := TRESTFDMemTableAdapter<TAitRoot>.Create(FConn, FRootMem, -1, nil);
  FMidMem := TFDMemTable.Create(nil);
  FMemMid := TRESTFDMemTableAdapter<TAitMid>.Create(FConn, FMidMem, -1, FMemRoot);
  FLeafMem := TFDMemTable.Create(nil);
  FMemLeaf := TRESTFDMemTableAdapter<TAitLeaf>.Create(FConn, FLeafMem, -1, FMemMid);
end;

/// The same two-adapter wiring BuildMemTree uses, over the client-key pair -
/// issue #305. REST fixtures need no central registration: the adapter is
/// instantiated directly, exactly as Cost_AnAggregateWithNoChildrenCostsNoGet
/// stands one up for TAitLeaf.
procedure TTestRestReReadAfterInsert.BuildClientKeyTree;
begin
  FCkRootMem := TFDMemTable.Create(nil);
  FCkRoot := TRESTFDMemTableAdapter<TCkrRoot>.Create(FConn, FCkRootMem, -1, nil);
  FCkChildMem := TFDMemTable.Create(nil);
  FCkChild := TRESTFDMemTableAdapter<TCkrChild>.Create(FConn, FCkChildMem, -1,
                FCkRoot);
end;

/// The root carries a key the OPERATOR typed - that is the whole difference
/// from SeedTree - and the child carries the AutoInc placeholder, which is what
/// makes the graph below stale.
procedure TTestRestReReadAfterInsert.SeedClientKeyTree;
begin
  FCkRootMem.Append;
  FCkRootMem.FieldByName(cCKROOTKEY).AsInteger := cTYPEDKEY;
  FCkRootMem.FieldByName(cTAG).AsString := 'typed by the operator';
  FCkRootMem.Post;
  FCkChildMem.Append;
  FCkChildMem.FieldByName(cCKCHILDKEY).AsInteger := cPLACEHOLDER;
  FCkChildMem.FieldByName(cCKROOTKEY).AsInteger := cTYPEDKEY;
  FCkChildMem.FieldByName(cTAG).AsString := 'child';
  FCkChildMem.Post;
end;

procedure TTestRestReReadAfterInsert.BuildCdsTree;
begin
  FRootCds := TClientDataSet.Create(nil);
  FCdsRoot := TRESTClientDataSetAdapter<TAitRoot>.Create(FConn, FRootCds, -1, nil);
  FMidCds := TClientDataSet.Create(nil);
  FCdsMid := TRESTClientDataSetAdapter<TAitMid>.Create(FConn, FMidCds, -1, FCdsRoot);
  FLeafCds := TClientDataSet.Create(nil);
  FCdsLeaf := TRESTClientDataSetAdapter<TAitLeaf>.Create(FConn, FLeafCds, -1, FCdsMid);
end;

procedure TTestRestReReadAfterInsert.SeedRoot(const ADataSet: TDataSet;
  const ATag: String);
begin
  ADataSet.Append;
  ADataSet.FieldByName(cROOTKEY).AsInteger := cPLACEHOLDER;
  ADataSet.FieldByName(cTAG).AsString := ATag;
  ADataSet.Post;
end;

procedure TTestRestReReadAfterInsert.SeedMid(const ADataSet: TDataSet;
  const ATag: String);
begin
  ADataSet.Append;
  ADataSet.FieldByName(cMIDKEY).AsInteger := cPLACEHOLDER;
  ADataSet.FieldByName(cROOTKEY).AsInteger := cPLACEHOLDER;
  ADataSet.FieldByName(cTAG).AsString := ATag;
  ADataSet.Post;
end;

procedure TTestRestReReadAfterInsert.SeedLeaf(const ADataSet: TDataSet;
  const ATag: String);
begin
  ADataSet.Append;
  ADataSet.FieldByName(cLEAFKEY).AsInteger := cPLACEHOLDER;
  ADataSet.FieldByName(cMIDKEY).AsInteger := cPLACEHOLDER;
  ADataSet.FieldByName(cROOTKEY).AsInteger := cPLACEHOLDER;
  ADataSet.FieldByName(cTAG).AsString := ATag;
  ADataSet.Post;
end;

/// Every key at the AutoInc placeholder - the state a screen is in when the
/// operator typed a root, a middle row under it and a leaf under that, and
/// pressed save once.
procedure TTestRestReReadAfterInsert.SeedTree(const ARoot, AMid, ALeaf: TDataSet);
begin
  SeedRoot(ARoot, 'root');
  SeedMid(AMid, 'mid');
  SeedLeaf(ALeaf, 'leaf');
end;

procedure TTestRestReReadAfterInsert.RunMem;
begin
  BuildMemTree;
  SeedTree(FRootMem, FMidMem, FLeafMem);
  TMemApply<TAitRoot>.Apply(FMemRoot);
end;

procedure TTestRestReReadAfterInsert.RunCds;
begin
  BuildCdsTree;
  SeedTree(FRootCds, FMidCds, FLeafCds);
  TCdsApply<TAitRoot>.Apply(FCdsRoot);
end;

/// The value of ONE column on the FIRST row, read without moving anybody's
/// cursor by hand.
function TTestRestReReadAfterInsert.KeyOf(const ADataSet: TDataSet;
  const AColumn: String): Integer;
begin
  Result := MaxInt;
  if not ADataSet.Active then
    Exit;
  if ADataSet.IsEmpty then
    Exit(cNOROWATALL);
  ADataSet.First;
  Result := ADataSet.FieldByName(AColumn).AsInteger;
end;

function TTestRestReReadAfterInsert.AllQueries: String;
begin
  Result := FRep.Queries.Text;
end;

procedure TTestRestReReadAfterInsert
  .Premise_OnePostCarriesTheWholeGraphAndTheRootTakesTheAnsweredKey;
begin
  RunMem;
  Assert.AreEqual(1, FRep.PostCount,
    'the whole aggregate must leave in ONE POST - anything else and the ' +
    'clauses below are measuring a different path');
  Assert.IsTrue(Pos('"leafs"', FRep.Bodies.Text) > 0,
    'the POST body must carry all three levels: ' + FRep.Bodies.Text);
  Assert.AreEqual(cSRVROOT, KeyOf(FRootMem, cROOTKEY),
    'the root row takes the key the answer named - this half already worked');
end;

procedure TTestRestReReadAfterInsert
  .Premise_ThePayloadCarriedThePlaceholderBelowTheRoot;
begin
  RunMem;
  Assert.IsTrue(Pos('"mid_id":-1', FRep.Bodies.Text) > 0,
    'the middle row went out on the placeholder, which is what the server ' +
    'repairs on its side and the client never hears about: ' +
    FRep.Bodies.Text);
end;

procedure TTestRestReReadAfterInsert.ReRead_TheMidRowTakesTheKeyOnlyTheServerKnew;
begin
  RunMem;
  Assert.AreEqual(cSRVMID, KeyOf(FMidMem, cMIDKEY),
    'aitmid.mid_id must be the key the server generated. -1 means the client ' +
    'kept the placeholder it typed and the screen is showing a row that does ' +
    'not exist');
end;

procedure TTestRestReReadAfterInsert.ReRead_TheLeafRowTakesTheKeyOnlyTheServerKnew;
begin
  RunMem;
  Assert.AreEqual(cSRVLEAF, KeyOf(FLeafMem, cLEAFKEY),
    'aitleaf.leaf_id must be the key the server generated - level THREE, the ' +
    'one no reordering could ever reach');
end;

procedure TTestRestReReadAfterInsert
  .ReRead_TheLeafForeignKeyPointsAtTheMidTheServerWrote;
begin
  RunMem;
  Assert.AreEqual(cSRVMID, KeyOf(FLeafMem, cMIDKEY),
    'aitleaf.mid_id must name the middle row the server actually wrote');
end;

procedure TTestRestReReadAfterInsert.ReRead_TheGetAsksByTheKeyTheServerReturned;
begin
  RunMem;
  // THE WHOLE QUERY, AND NOT A SUBSTRING OF IT. `Pos('root_id=777', ...)` was
  // what this clause used to do, and a prefix walks straight through it: with
  // the column named 'zzroot_id' the filter that goes to the server is
  // `$filter=zzroot_id=777`, the substring is still in there, and the clause
  // stayed green over a name the server cannot resolve. Measured. Comparing the
  // whole thing is what makes the COLUMN NAME on the wire measured at all - no
  // other clause in this fixture reads it.
  // CASE MATTERS HERE, so AreEqual is told so: Assert.AreEqual over strings
  // ignores case by default in this DUnitX (issue #293), and a column name is
  // not case noise on the way to a server.
  Assert.AreEqual('$filter=root_id=777', Trim(AllQueries), False,
    'the re-read must ask for the row by the key the SERVER returned, under ' +
    'the column name the MAPPING spells. Queries seen: ' + AllQueries);
end;

procedure TTestRestReReadAfterInsert.Cds_TheMidRowTakesTheKeyOnlyTheServerKnew;
begin
  RunCds;
  Assert.AreEqual(cSRVMID, KeyOf(FMidCds, cMIDKEY),
    'the two REST families converge - neither overrides ApplyInserter - and ' +
    'this clause is what keeps that a measurement');
end;

procedure TTestRestReReadAfterInsert.Cds_TheLeafRowTakesTheKeyOnlyTheServerKnew;
begin
  RunCds;
  Assert.AreEqual(cSRVLEAF, KeyOf(FLeafCds, cLEAFKEY),
    'the ClientDataSet family reaches level three too');
end;

procedure TTestRestReReadAfterInsert
  .Cds_TheLeafForeignKeyPointsAtTheMidTheServerWrote;
begin
  RunCds;
  Assert.AreEqual(cSRVMID, KeyOf(FLeafCds, cMIDKEY),
    'the ClientDataSet family reconciles the grandchild foreign key too');
end;

procedure TTestRestReReadAfterInsert.Cost_AnAggregateWithNoChildrenCostsNoGet;
begin
  FRep.PostAnswer :=
    '{"result":"ok","params":[{"leaf_id":333}]}';
  FLoneMem := TFDMemTable.Create(nil);
  FLone := TRESTFDMemTableAdapter<TAitLeaf>.Create(FConn, FLoneMem, -1, nil);
  SeedLeaf(FLoneMem, 'lone');
  TMemApply<TAitLeaf>.Apply(FLone);
  Assert.AreEqual(1, FRep.PostCount, 'the row was still inserted');
  Assert.AreEqual(0, FRep.GetCount,
    'an aggregate with no child adapter has nothing to reconcile and must ' +
    'not pay for a round trip');
end;

procedure TTestRestReReadAfterInsert.Cost_OneInsertedRootCostsExactlyOneGet;
begin
  RunMem;
  Assert.AreEqual(1, FRep.GetCount,
    'ONE extra GET per inserted root - not one per level and not one per ' +
    'child row');
end;

procedure TTestRestReReadAfterInsert.Cost_WithoutResultParamsNoGetIsIssued;
begin
  FRep.PostAnswer := cPOSTNOPARAMS;
  RunMem;
  Assert.AreEqual(cPLACEHOLDER, KeyOf(FRootMem, cROOTKEY),
    'premise of this clause: without params the root is not stamped either');
  Assert.AreEqual(0, FRep.GetCount,
    'with the root key unknown there is nothing to ask BY, so the re-read ' +
    'must not fire on a placeholder');
end;

procedure TTestRestReReadAfterInsert
  .Cost_APlaceholderUnderANonCascadeAssociationBuysNoGet;
begin
  FRootMem := TFDMemTable.Create(nil);
  FMemRoot := TRESTFDMemTableAdapter<TAitRoot>.Create(FConn, FRootMem, -1, nil);
  FOtherMem := TFDMemTable.Create(nil);
  FOther := TRESTFDMemTableAdapter<TAitNoCascade>.Create(FConn, FOtherMem, -1,
              FMemRoot);
  SeedRoot(FRootMem, 'root');
  FOtherMem.Append;
  FOtherMem.FieldByName(cOTHERKEY).AsInteger := cPLACEHOLDER;
  FOtherMem.FieldByName(cROOTKEY).AsInteger := cPLACEHOLDER;
  FOtherMem.Post;
  TMemApply<TAitRoot>.Apply(FMemRoot);
  Assert.AreEqual(1, FRep.PostCount, 'premise: the aggregate was sent');
  Assert.AreEqual(cPLACEHOLDER, KeyOf(FOtherMem, cOTHERKEY),
    'premise: the child really is sitting on the placeholder');
  Assert.AreEqual(0, FRep.GetCount,
    'TAitRoot.others carries CascadeInsert and CascadeUpdate but NOT ' +
    'CascadeAutoInc, so this insert generated no key for it and there is ' +
    'nothing to reconcile - paying for a round trip here would be paying for ' +
    'a value the consumer typed');
end;

procedure TTestRestReReadAfterInsert.Cost_AStaleGrandchildAloneStillBuysTheGet;
begin
  BuildMemTree;
  SeedRoot(FRootMem, 'root');
  // The middle row carries a key the OPERATOR typed. Level two is not stale.
  FMidMem.Append;
  FMidMem.FieldByName(cMIDKEY).AsInteger := cSRVMID;
  FMidMem.FieldByName(cROOTKEY).AsInteger := cPLACEHOLDER;
  FMidMem.FieldByName(cTAG).AsString := 'typed';
  FMidMem.Post;
  SeedLeaf(FLeafMem, 'leaf');
  TMemApply<TAitRoot>.Apply(FMemRoot);
  Assert.AreEqual(1, FRep.GetCount,
    'only the GRANDCHILD is on the placeholder here, so a walk that stopped ' +
    'at the first level would answer "nothing to do" and leave level three ' +
    'wrong forever');
  Assert.AreEqual(cSRVLEAF, KeyOf(FLeafMem, cLEAFKEY),
    'and the grandchild really was reconciled');
end;

procedure TTestRestReReadAfterInsert.Cost_AGraphThatAlreadyCarriesEveryKeyBuysNoGet;
begin
  BuildMemTree;
  SeedRoot(FRootMem, 'root');
  FMidMem.Append;
  FMidMem.FieldByName(cMIDKEY).AsInteger := cSRVMID;
  FMidMem.FieldByName(cROOTKEY).AsInteger := cPLACEHOLDER;
  FMidMem.FieldByName(cTAG).AsString := 'typed';
  FMidMem.Post;
  FLeafMem.Append;
  FLeafMem.FieldByName(cLEAFKEY).AsInteger := cSRVLEAF;
  FLeafMem.FieldByName(cMIDKEY).AsInteger := cSRVMID;
  FLeafMem.FieldByName(cROOTKEY).AsInteger := cPLACEHOLDER;
  FLeafMem.FieldByName(cTAG).AsString := 'typed';
  FLeafMem.Post;
  TMemApply<TAitRoot>.Apply(FMemRoot);
  Assert.AreEqual(1, FRep.PostCount, 'premise: the aggregate was sent');
  Assert.AreEqual(0, FRep.GetCount,
    'both levels below the root already carry a key of their own, so there is ' +
    'no divergence to reconcile and no round trip to pay for');
end;

procedure TTestRestReReadAfterInsert.Cost_ParamsThatNameNoColumnOfThisRowBuyNoGet;
begin
  // A well-formed answer that names a column this entity does not have. The
  // stamp loop skips it - FindField answers nil - so nothing is written and the
  // root comes out of ApplyInserter still on the placeholder.
  FRep.PostAnswer := '{"result":"ok","params":[{"nosuchcolumn":"9"}]}';
  RunMem;
  Assert.AreEqual(cPLACEHOLDER, KeyOf(FRootMem, cROOTKEY),
    'premise of this clause: nothing was stamped, so the root is still on the ' +
    'placeholder even though params did come back');
  Assert.AreEqual(0, FRep.GetCount,
    'the gate has to be "the root key arrived", not "an answer arrived": with ' +
    'the root still at -1 the only filter the re-read could build is ' +
    'root_id=-1');
end;

procedure TTestRestReReadAfterInsert
  .Shallow_AnAnswerMissingTheGrandchildBranchIsRefused;
begin
  // Exactly what the shipped server answers when `leafs` is Lazy: the middle
  // level is there, the grandchild branch is not.
  FRep.GetAnswer :=
    '[{"root_id":777,"tag":"root","others":[],"mids":[' +
      '{"mid_id":555,"root_id":777,"tag":"mid"}]}]';
  RunMem;
  Assert.AreEqual(1, FRep.GetCount, 'premise: the re-read really was issued');
  Assert.AreEqual(1, FLeafMem.RecordCount,
    'the grandchild row went out in the POST and the server wrote it. An ' +
    'answer that does not mention that level is not permission to delete it');
  Assert.AreEqual(1, FMidMem.RecordCount,
    'and the middle row is still there too');
  Assert.AreEqual(cPLACEHOLDER, KeyOf(FMidMem, cMIDKEY),
    'the answer was refused WHOLE rather than applied in part: a half-applied ' +
    'graph is a third state nobody can reason about');
end;

procedure TTestRestReReadAfterInsert
  .Shallow_AnAnswerWithNoChildBranchAtAllIsRefused;
begin
  FRep.GetAnswer := '[{"root_id":777,"tag":"root","others":[],"mids":[]}]';
  RunMem;
  Assert.AreEqual(1, FRep.GetCount, 'premise: the re-read really was issued');
  Assert.AreEqual(1, FMidMem.RecordCount,
    'the middle row went out in the POST and the server wrote it');
  Assert.AreEqual(1, FLeafMem.RecordCount,
    'and so did the grandchild - emptying the middle level takes it along ' +
    'through its own CascadeDelete, so this clause loses two rows if the ' +
    'refusal is missing');
end;

procedure TTestRestReReadAfterInsert
  .Shallow_AnAnswerIsNotRefusedForALevelTheClientDoesNotHold;
begin
  // Root and one middle row, no grandchild anywhere - not in the client, not
  // in the answer.
  BuildMemTree;
  SeedRoot(FRootMem, 'root');
  SeedMid(FMidMem, 'mid');
  FRep.GetAnswer :=
    '[{"root_id":777,"tag":"root","others":[],"mids":[' +
      '{"mid_id":555,"root_id":777,"tag":"mid"}]}]';
  TMemApply<TAitRoot>.Apply(FMemRoot);
  Assert.AreEqual(1, FRep.GetCount, 'premise: the re-read really was issued');
  Assert.AreEqual(cSRVMID, KeyOf(FMidMem, cMIDKEY),
    'the client holds no grandchild, so an answer with no grandchild branch ' +
    'agrees with it and must be applied - a refusal that fired here would ' +
    'turn the whole repair off for every two-level aggregate');
end;

procedure TTestRestReReadAfterInsert
  .Shallow_OneObjectOfTheListReachingDeeperIsEnough;
begin
  BuildMemTree;
  SeedRoot(FRootMem, 'root');
  SeedMid(FMidMem, 'midA');
  SeedMid(FMidMem, 'midB');
  SeedLeaf(FLeafMem, 'leaf');
  // Two middle objects come back and only the FIRST carries grandchildren -
  // which is what an aggregate looks like when one middle row has children and
  // the other does not.
  FRep.GetAnswer :=
    '[{"root_id":777,"tag":"root","others":[],"mids":[' +
      '{"mid_id":555,"root_id":777,"tag":"midA","leafs":[' +
        '{"leaf_id":333,"mid_id":555,"root_id":777,"tag":"leaf"}]},' +
      '{"mid_id":556,"root_id":777,"tag":"midB","leafs":[]}]}]';
  TMemApply<TAitRoot>.Apply(FMemRoot);
  Assert.AreEqual(1, FRep.GetCount, 'premise: the re-read really was issued');
  Assert.AreEqual(cSRVMID, KeyOf(FMidMem, cMIDKEY),
    'the answer must be applied: demanding that EVERY object of the list ' +
    'reach the level below refuses a perfectly correct answer whenever one ' +
    'middle row happens to have no children');
  Assert.AreEqual(cSRVLEAF, KeyOf(FLeafMem, cLEAFKEY),
    'and the grandchild that DOES exist was reconciled');
end;

procedure TTestRestReReadAfterInsert
  .MultiRoot_TwoRootsSavedTogetherAreLeftAloneAndKeepEveryRow;
begin
  // TWO ROOTS MEANS TWO KEYS. Answering both POSTs with the same primary key
  // would make the two roots indistinguishable, and any row loss measured over
  // that could be blamed on the double instead of on the code.
  FRep.QueuePostAnswer('{"result":"ok","params":[{"root_id":777}]}');
  FRep.QueuePostAnswer('{"result":"ok","params":[{"root_id":888}]}');
  FRep.QueueGetAnswer(
    '[{"root_id":777,"tag":"rootA","others":[],"mids":[' +
      '{"mid_id":555,"root_id":777,"tag":"midA","leafs":[' +
        '{"leaf_id":333,"mid_id":555,"root_id":777,"tag":"leafA"}]}]}]');
  FRep.QueueGetAnswer(
    '[{"root_id":888,"tag":"rootB","others":[],"mids":[' +
      '{"mid_id":666,"root_id":888,"tag":"midB","leafs":[' +
        '{"leaf_id":444,"mid_id":666,"root_id":888,"tag":"leafB"}]}]}]');
  BuildMemTree;
  SeedRoot(FRootMem, 'rootA');
  SeedMid(FMidMem, 'midA');
  SeedLeaf(FLeafMem, 'leafA');
  SeedRoot(FRootMem, 'rootB');
  SeedMid(FMidMem, 'midB');
  SeedLeaf(FLeafMem, 'leafB');
  TMemApply<TAitRoot>.Apply(FMemRoot);
  Assert.AreEqual(2, FRep.PostCount,
    'premise: both roots really were sent');
  Assert.AreEqual(0, FRep.GetCount,
    'no re-read fires when more than one root was saved in the same call - ' +
    'the second one would empty the first one child datasets');
  Assert.AreEqual(2, FMidMem.RecordCount,
    'both middle rows must survive. Allowing the re-read here measured ' +
    'mids=1 at f7f8e76, with a distinct key per root: rows the operator ' +
    'typed simply disappeared');
  Assert.AreEqual(2, FLeafMem.RecordCount,
    'and both grandchild rows with them');
end;

procedure TTestRestReReadAfterInsert
  .Empty_AGetThatFindsNothingLeavesTheClientAsItWas;
begin
  FRep.GetAnswer := '[]';
  RunMem;
  Assert.AreEqual(1, FRep.GetCount, 'premise: the re-read really was issued');
  Assert.AreEqual(cSRVROOT, KeyOf(FRootMem, cROOTKEY),
    'the root keeps the key the POST answered');
  Assert.AreEqual(1, FMidMem.RecordCount,
    'and the child row the operator typed is still there - an answer with no ' +
    'row must not cost the client its own data, and must not raise: the ' +
    'server has already written by this point');
end;

procedure TTestRestReReadAfterInsert.Foreign_AnAnswerThatIsNotThisRowIsDiscarded;
begin
  // A well-formed aggregate, but for ANOTHER root - and carrying every level
  // this client holds, so that the DEPTH guard has nothing to object to and
  // only the identity of the row can refuse it. With a shallower stranger the
  // two guards overlap and neither one is measured on its own.
  FRep.GetAnswer :=
    '[{"root_id":901,"tag":"someone else","others":[],"mids":[' +
      '{"mid_id":902,"root_id":901,"tag":"theirs","leafs":[' +
        '{"leaf_id":903,"mid_id":902,"root_id":901,"tag":"theirs"}]}]}]';
  RunMem;
  Assert.AreEqual(1, FRep.GetCount, 'premise: the re-read really was issued');
  Assert.AreEqual(cSRVROOT, KeyOf(FRootMem, cROOTKEY),
    'the client keeps ITS row - 901 would mean the answer overwrote a row it ' +
    'was never about');
  Assert.AreEqual(cPLACEHOLDER, KeyOf(FMidMem, cMIDKEY),
    'and its own child, still on the placeholder, rather than the stranger ' +
    'row 902');
end;

procedure TTestRestReReadAfterInsert.Detector_AllThreePhasesRunInsideTheSameCall;
begin
  BuildMemTree;
  // A row the operator DELETED. First, so that the cascade its removal fires
  // cannot take the rows the clauses below need.
  SeedRoot(FRootMem, 'gone');
  FRootMem.Delete;
  // A row the operator EDITED. Clearing the internal marker by hand is what
  // turns a row that was typed into a row that was LOADED and then changed -
  // DoBeforePost promotes -1 to dsEdit and leaves anything else alone.
  SeedRoot(FRootMem, 'kept');
  FRootMem.Edit;
  FRootMem.FieldByName(cInternalField).AsInteger := -1;
  FRootMem.FieldByName(cTAG).AsString := 'changed';
  FRootMem.Post;
  // And the row the operator INSERTED, with a child under it so that its graph
  // is the stale one this issue is about.
  SeedRoot(FRootMem, 'new');
  SeedMid(FMidMem, 'mid');
  TMemApply<TAitRoot>.Apply(FMemRoot);
  Assert.AreEqual(1, FRep.PostCount, 'the insert phase ran');
  Assert.AreEqual(1, FRep.PutCount,
    'the UPDATE phase ran in the same call - it is the first thing an ' +
    'exception raised at the end of the insert phase would take away');
  Assert.AreEqual(1, FRep.DeleteCount,
    'and so did the DELETE phase. Worse than skipped: ApplyUpdates clears ' +
    'FSession.DeleteList in its own finally whatever happened, so a row ' +
    'dropped here is gone from the client AND was never sent');
end;

procedure TTestRestReReadAfterInsert.Design_TheEventSwitchIsASwapAndNotACounter;
var
  LWasOff: Boolean;
begin
  BuildMemTree;
  TEventCrack<TAitRoot>.Off(FMemRoot);
  LWasOff := not Assigned(FRootMem.BeforePost);
  // The nested pair a call to RefreshRecord would add from inside ApplyInternal
  TEventCrack<TAitRoot>.Off(FMemRoot);
  TEventCrack<TAitRoot>.On_(FMemRoot);
  Assert.IsTrue(LWasOff,
    'premise: the first Disable really did unhook DoBeforePost');
  Assert.IsTrue(Assigned(FRootMem.BeforePost),
    'a nested Disable/Enable pair puts the ORIGINAL handler back while the ' +
    'outer caller still believes events are off. That is why the re-read may ' +
    'not go through the adapter RefreshRecord wrapper: inside ApplyInternal ' +
    'it would re-arm DoBeforePost and ApplyUpdater would not terminate');
end;

// ---------------------------------------------------------------------------
// ISSUE #305 - THE VOICE
// ---------------------------------------------------------------------------

/// Renders a set so a failure message can say what was heard instead of
/// `[True/False]`. Named by ENUM MEMBER and not by ordinal: an ordinal in a
/// message goes stale the first time a case is inserted in the middle.
function CasesToText(const ACases: TStaleGraphCases): String;
const
  cNAME: array[TStaleGraphCase] of String = ('sgcNoKeyToAskBy',
    'sgcMultiRootNotReRead', 'sgcReReadNeverAttempted', 'sgcAnswerHadNoRow',
    'sgcAnswerWasAnotherRow', 'sgcAnswerWasShallower');
var
  LCase: TStaleGraphCase;
begin
  Result := '[';
  for LCase := Low(TStaleGraphCase) to High(TStaleGraphCase) do
    if LCase in ACases then
    begin
      if Length(Result) > 1 then
        Result := Result + ', ';
      Result := Result + cNAME[LCase];
    end;
  Result := Result + ']';
end;

procedure TTestRestReReadAfterInsert.Voice_NoKeyToAskByIsAnnounced;
begin
  FRep.PostAnswer := cPOSTNOPARAMS;
  RunMem;
  Assert.AreEqual(cPLACEHOLDER, KeyOf(FRootMem, cROOTKEY),
    'premise: without params the root was not stamped, so there is no key to ' +
    'ask by');
  Assert.AreEqual(0, FRep.GetCount,
    'premise: and no re-read was issued - this is the mute gate itself');
  Assert.IsTrue(sgcNoKeyToAskBy in FMemRoot.StaleGraphCases,
    'the aggregate is on the server under a key this client will never know, ' +
    'and until #305 nothing said so. Heard: ' +
    CasesToText(FMemRoot.StaleGraphCases));
end;

procedure TTestRestReReadAfterInsert
  .Voice_ParamsThatNameNoColumnAnnounceTheSameCase;
begin
  FRep.PostAnswer := '{"result":"ok","params":[{"nosuchcolumn":"9"}]}';
  RunMem;
  Assert.AreEqual(cPLACEHOLDER, KeyOf(FRootMem, cROOTKEY),
    'premise: params came back and stamped nothing, so the root is still on ' +
    'the placeholder');
  Assert.AreEqual(0, FRep.GetCount, 'premise: and no re-read was issued');
  Assert.IsTrue(sgcNoKeyToAskBy in FMemRoot.StaleGraphCases,
    'an answer that names no column of this row leaves the client in exactly ' +
    'the state an answer with no params does, so it is the same case and not ' +
    'a milder one. Heard: ' + CasesToText(FMemRoot.StaleGraphCases));
end;

procedure TTestRestReReadAfterInsert.Voice_MultiRootIsAnnouncedAsItsOwnCase;
begin
  FRep.QueuePostAnswer('{"result":"ok","params":[{"root_id":777}]}');
  FRep.QueuePostAnswer('{"result":"ok","params":[{"root_id":888}]}');
  BuildMemTree;
  SeedRoot(FRootMem, 'rootA');
  SeedMid(FMidMem, 'midA');
  SeedRoot(FRootMem, 'rootB');
  SeedMid(FMidMem, 'midB');
  TMemApply<TAitRoot>.Apply(FMemRoot);
  Assert.AreEqual(2, FRep.PostCount, 'premise: both roots really were sent');
  Assert.AreEqual(0, FRep.GetCount,
    'premise: the re-read is off for more than one root, and stays off');
  Assert.IsTrue(sgcMultiRootNotReRead in FMemRoot.StaleGraphCases,
    'a deliberate skip is still a stale graph the operator is looking at. ' +
    'Heard: ' + CasesToText(FMemRoot.StaleGraphCases));
  Assert.IsFalse(sgcNoKeyToAskBy in FMemRoot.StaleGraphCases,
    'and it is NOT the orphan case: both keys came back, both roots are ' +
    'reachable, and nothing was lost on either side. Heard: ' +
    CasesToText(FMemRoot.StaleGraphCases));
end;

procedure TTestRestReReadAfterInsert
  .Voice_AnEmptyAnswerIsAnnouncedAndIsNotTheOrphanCase;
begin
  FRep.GetAnswer := '[]';
  RunMem;
  Assert.AreEqual(1, FRep.GetCount, 'premise: the re-read really was issued');
  Assert.IsTrue(sgcAnswerHadNoRow in FMemRoot.StaleGraphCases,
    'the GET found nothing, so the graph stayed on its placeholders and the ' +
    'operator has to be able to find that out before reopening the screen. ' +
    'Heard: ' + CasesToText(FMemRoot.StaleGraphCases));
  Assert.IsFalse(sgcNoKeyToAskBy in FMemRoot.StaleGraphCases,
    'and NOT as the orphan case: the key is known, the client data is intact, ' +
    'and a screen that shouts the same way at both is a screen nobody will ' +
    'believe. Heard: ' + CasesToText(FMemRoot.StaleGraphCases));
end;

procedure TTestRestReReadAfterInsert
  .Voice_AForeignAnswerIsAnnouncedAndIsNotTheOrphanCase;
begin
  // The same stranger the guard clause above uses: complete to every level the
  // client holds, so the DEPTH guard has nothing to object to and only identity
  // can refuse it. Anything shallower and this clause would be measuring
  // sgcAnswerWasShallower instead of sgcAnswerWasAnotherRow - named, because
  // this line used to say "the fifth case instead of the fourth" and #305 put a
  // sixth member in the middle of the enum.
  FRep.GetAnswer :=
    '[{"root_id":901,"tag":"someone else","others":[],"mids":[' +
      '{"mid_id":902,"root_id":901,"tag":"theirs","leafs":[' +
        '{"leaf_id":903,"mid_id":902,"root_id":901,"tag":"theirs"}]}]}]';
  RunMem;
  Assert.AreEqual(1, FRep.GetCount, 'premise: the re-read really was issued');
  Assert.IsTrue(sgcAnswerWasAnotherRow in FMemRoot.StaleGraphCases,
    'the identity guard refused the answer and the graph stayed stale. Heard: ' +
    CasesToText(FMemRoot.StaleGraphCases));
  Assert.IsFalse(sgcAnswerWasShallower in FMemRoot.StaleGraphCases,
    'and it was refused by IDENTITY and not by depth - the stranger reaches ' +
    'every level, so a voice that read the two guards as one would announce ' +
    'the wrong one here. Heard: ' + CasesToText(FMemRoot.StaleGraphCases));
end;

procedure TTestRestReReadAfterInsert
  .Voice_AShallowAnswerIsAnnouncedUnderItsOwnCase;
begin
  // Exactly what the shipped server answers when `leafs` is Lazy.
  FRep.GetAnswer :=
    '[{"root_id":777,"tag":"root","others":[],"mids":[' +
      '{"mid_id":555,"root_id":777,"tag":"mid"}]}]';
  RunMem;
  Assert.AreEqual(1, FRep.GetCount, 'premise: the re-read really was issued');
  Assert.AreEqual(cPLACEHOLDER, KeyOf(FMidMem, cMIDKEY),
    'premise: the answer was refused whole, so the graph really did stay stale');
  Assert.IsTrue(sgcAnswerWasShallower in FMemRoot.StaleGraphCases,
    'a Lazy sibling branch produces this on the SHIPPED server, so it is the ' +
    'exit a consumer meets most often and the one #305 did not name. Heard: ' +
    CasesToText(FMemRoot.StaleGraphCases));
  Assert.IsFalse(sgcAnswerWasAnotherRow in FMemRoot.StaleGraphCases,
    'and it is the DEPTH guard and not the identity guard: this answer IS ' +
    'this row. Heard: ' + CasesToText(FMemRoot.StaleGraphCases));
end;

procedure TTestRestReReadAfterInsert.Voice_ACleanSaveAnnouncesNothingAtAll;
begin
  RunMem;
  Assert.AreEqual(cSRVMID, KeyOf(FMidMem, cMIDKEY),
    'premise: this is the ordinary save, and it really was reconciled');
  Assert.IsTrue(FMemRoot.StaleGraphCases = [],
    'a save that reconciled the graph has nothing to announce. This is the ' +
    'control every clause above depends on: a voice wired to fire ' +
    'unconditionally passes all of them and dies here. Heard: ' +
    CasesToText(FMemRoot.StaleGraphCases));
end;

procedure TTestRestReReadAfterInsert
  .Voice_TheStateIsClearedAtTheStartOfTheNextSave;
begin
  FRep.PostAnswer := cPOSTNOPARAMS;
  RunMem;
  Assert.IsTrue(sgcNoKeyToAskBy in FMemRoot.StaleGraphCases,
    'premise: the first save really did go stale');
  // A second save over the same adapter. Every row is marked saved by now, so
  // this one inserts nothing - which is the point: the state must describe THIS
  // save, and a save that did nothing has nothing to say.
  TMemApply<TAitRoot>.Apply(FMemRoot);
  Assert.AreEqual(1, FRep.PostCount,
    'premise: the second save really had nothing to send');
  Assert.IsTrue(FMemRoot.StaleGraphCases = [],
    'the state is of the LAST save, not an accumulation. Left to accumulate, ' +
    'a screen that once went stale would keep shouting forever. Heard: ' +
    CasesToText(FMemRoot.StaleGraphCases));
end;

procedure TTestRestReReadAfterInsert
  .Voice_TheHandlerHearsTheCaseTheEntityAndTheSender;
begin
  FRep.PostAnswer := cPOSTNOPARAMS;
  BuildMemTree;
  FMemRoot.OnStaleGraph := OnStale;
  SeedTree(FRootMem, FMidMem, FLeafMem);
  TMemApply<TAitRoot>.Apply(FMemRoot);
  Assert.AreEqual(1, FHeard.Count,
    'the handler is called ONCE for the one root that went stale - not once ' +
    'per level and not once per child row');
  Assert.IsTrue(FHeard[0] = sgcNoKeyToAskBy,
    'and it hears the same case the property records');
  Assert.AreEqual('TAitRoot', FHeardEntity, False,
    'it hears WHICH aggregate. A screen with several open cannot act on ' +
    '"something went stale"');
  Assert.IsTrue(FHeardSender = TObject(FMemRoot),
    'and from which adapter, so a handler shared by several can tell them ' +
    'apart');
end;

procedure TTestRestReReadAfterInsert.Voice_NoHandlerIsAssignedByDefault;
begin
  FRep.PostAnswer := cPOSTNOPARAMS;
  RunMem;
  Assert.IsTrue(sgcNoKeyToAskBy in FMemRoot.StaleGraphCases,
    'premise: the case really did happen on this save');
  Assert.IsFalse(Assigned(FMemRoot.OnStaleGraph),
    'nothing assigns a handler but the consumer - the voice is additive, and ' +
    'this is the half that makes that a measurement');
  Assert.AreEqual(0, FHeard.Count,
    'and with none assigned nothing of this fixture was called');
end;

procedure TTestRestReReadAfterInsert.Voice_TheMonitorGetsALineNamingTheCase;
begin
  AttachMonitor;
  FRep.PostAnswer := cPOSTNOPARAMS;
  RunMem;
  Assert.IsTrue(Pos(cSTALEGRAPHCASE[sgcNoKeyToAskBy], StaleLines) > 0,
    'the monitor line has to name WHICH silence this was. A line that only ' +
    'said "stale" would leave the reader to guess between an orphan on the ' +
    'server and a refusal that cost nothing. Stale lines seen: ' + StaleLines);
  Assert.IsTrue(Pos('TAitRoot', StaleLines) > 0,
    'and which class it was about, in the labelled format the rest of the ' +
    'family already writes. Stale lines seen: ' + StaleLines);
end;

procedure TTestRestReReadAfterInsert.Voice_TheMonitorIsSilentOnACleanSave;
begin
  AttachMonitor;
  RunMem;
  Assert.AreEqual(1, FRep.GetCount,
    'premise: the ordinary save, re-read issued and applied');
  Assert.IsTrue(FSpy.Lines.Count > 0,
    'premise: the monitor really is attached - TSessionRestFul<M> writes a ' +
    'line per verb onto it, so an empty spy would mean the wiring failed and ' +
    'the clause below would pass for the wrong reason');
  Assert.AreEqual('', Trim(StaleLines),
    'and not one of those lines is a stale-graph warning. Stale lines seen: ' +
    StaleLines);
end;

procedure TTestRestReReadAfterInsert.Voice_Cds_TheOrphanCaseIsAnnouncedThereToo;
begin
  FRep.PostAnswer := cPOSTNOPARAMS;
  RunCds;
  Assert.AreEqual(cPLACEHOLDER, KeyOf(FRootCds, cROOTKEY),
    'premise: the ClientDataSet family reaches the same mute gate');
  Assert.IsTrue(sgcNoKeyToAskBy in FCdsRoot.StaleGraphCases,
    'both families inherit ApplyInserter from TRESTDataSetAdapter<M> and ' +
    'neither overrides it - and this clause is what keeps that a measurement ' +
    'rather than the "identical to its sibling" argument. Heard: ' +
    CasesToText(FCdsRoot.StaleGraphCases));
end;

procedure TTestRestReReadAfterInsert
  .Voice_TheNoSequenceRootReallyReachesThatDoor;
begin
  AttachMonitor;
  BuildClientKeyTree;
  SeedClientKeyTree;
  TMemApply<TCkrRoot>.Apply(FCkRoot);
  Assert.AreEqual(1, FRep.PostCount,
    'the aggregate really was sent - a clause about what a save announced is ' +
    'worth nothing if the save did not happen');
  Assert.AreEqual(0, FRep.GetCount,
    'and NO re-read was bought: this door never reaches the block that takes ' +
    'the bookmark, which is exactly why the graph below stays stale');
  Assert.AreEqual(cTYPEDKEY, KeyOf(FCkRootMem, cCKROOTKEY),
    'the root still carries the key the OPERATOR typed - nothing stamped it, ' +
    'and nothing had to');
  Assert.AreEqual(cPLACEHOLDER, KeyOf(FCkChildMem, cCKCHILDKEY),
    'while the child, which DOES have a sequence, is still on the AutoInc ' +
    'placeholder - the server generated a key for it and the client never ' +
    'heard which');
end;

procedure TTestRestReReadAfterInsert
  .Voice_ARootWithNoSequenceIsItsOwnCaseAndNotTheOrphanOne;
begin
  AttachMonitor;
  BuildClientKeyTree;
  SeedClientKeyTree;
  TMemApply<TCkrRoot>.Apply(FCkRoot);
  Assert.IsTrue(sgcReReadNeverAttempted in FCkRoot.StaleGraphCases,
    'the third door has to speak, and to speak as ITSELF. Heard: ' +
    CasesToText(FCkRoot.StaleGraphCases));
  Assert.IsFalse(sgcNoKeyToAskBy in FCkRoot.StaleGraphCases,
    'and it must NOT come out as the orphan case, which is where it went ' +
    'before this member existed: nothing here is orphaned - a GET on ' +
    'ckrroot_id=4242 would work, because the operator typed that key. Heard: ' +
    CasesToText(FCkRoot.StaleGraphCases));
  // THE SENTENCE, AND NOT ONLY THE CASE. A case relabelled while the monitor
  // kept telling the reader the key was lost forever would be the same defect
  // with a nicer name on it.
  Assert.IsTrue(Pos(cSTALEGRAPHCASE[sgcReReadNeverAttempted], StaleLines) > 0,
    'the monitor line has to carry the sentence of THIS case. Stale lines ' +
    'seen: ' + StaleLines);
  Assert.IsTrue(Pos('nunca vai saber', StaleLines) = 0,
    'and must NOT carry the orphan sentence: the client knows this key, it ' +
    'typed it. Stale lines seen: ' + StaleLines);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRestReReadAfterInsert);

end.
