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

{ @abstract(Janus Framework - CascadeAutoInc must reach the children of the
  parent row they were typed under, and no other.)

  WHAT IS UNDER TEST - issue #261

  TDataSetBaseAdapter<M>._AutoIncToChildRows writes the master's key into EVERY
  pending child row, and TDataSetBaseAdapter<M>.SetAutoIncValueChilds recurses
  into each child ADAPTER once, riding whatever row that child's cursor happens
  to sit on. Neither step asks which parent row a pending child belongs to.

  With more than one pending parent that produces two different wrongs, and
  this file measures both:

    * level 2 - TFDMemTableAdapter<M>.ApplyInserter loops over every pending
      MASTER row calling SetAutoIncValueChilds once per row, and each pass
      re-stamps the same child rows, so the LAST pending master wins;
    * level 3 - the recursion enters the mid level exactly once, with the mid
      cursor wherever _AutoIncToChildRows' own `finally` left it, so every leaf
      is parented on THAT mid row whichever mid row it was typed under.

  THE ORDERING THAT MAKES THE STATE REACHABLE

  Two pending masters each able to hold pending children is not reachable in
  the local family by typing the children first: TDataSetAdapter<M>.DoNewRecord
  calls EmptyDataSetChilds BEFORE the inherited call, so appending the second
  master wipes them. It IS reachable the other way round - append both masters
  while the child table is still empty, scroll back to the first, and only then
  type the children. Nothing is lost at either step because there is nothing to
  lose yet, and ApplyInternal disables events before it walks, so the typed
  children arrive at ApplyInserter intact.

  THREE tests use that ordering, through
  SeedTwoMastersThenChildrenUnderTheFirst:
  Premise_OrderBReachesTwoPendingMastersAndTwoPendingChildren,
  FDMemTable_ChildrenTypedUnderTheFirstMaster_StayOnIt and
  ClientDataSet_ChildrenTypedUnderTheFirstMaster_StayOnIt. The two REST
  fixtures interleave master and children instead - they can, and the next
  section says why - and the two recursion fixtures build a three level tree
  under ONE root, so neither shape applies to them.

  WHAT IS MUTED, AND WHERE - THREE EXCEPTIONS, NOT ONE

  Most of the file runs the configuration Janus ships: no adapter muted in the
  set-up, no marker written by hand, no handler installed. THREE tests are
  exceptions, and each says why in its own body:

    * UntokenisedRows_KeepTheHistoricalBehaviour mutes BOTH adapters for the
      whole set-up and writes the pending marker by hand - having no row
      provenance at all is the very thing it measures;
    * ChildRowWithNoRecordedParentage_IsStillWrittenByItsMaster mutes the
      CHILD adapter only, and writes that child's pending marker by hand, so
      that the master identifies itself and the child does not;
    * Recursion_WithNoPendingChildRow_StillReachesTheGrandchildren unhooks the
      mid table's BeforePost for one write, to set the ALREADY SAVED marker
      that the adapter's own BeforePost would otherwise flip straight back.

  Separately, and in every test, the MEASUREMENT helpers - RowCount,
  CountWithColumn, DumpColumn, KeyOfMasterRow - unhook BeforeScroll and
  AfterScroll while they walk, through MuteScroll. That is not set-up: walking
  with the adapter's AfterScroll live re-opens, and therefore empties, the
  children of the row the walk lands on, so measuring would change what is
  being measured.

  THE REST FAMILY REACHES A STRONGER STATE

  TRESTDataSetAdapter<M>.OpenDataSetChilds has an EMPTY BODY, so a REST master
  scroll discards nothing. There both masters can hold their OWN children at
  the same time - four pending child rows under two parents - which is the
  shape where a collapse is unambiguous.

  WHY THE FIELD LAYOUT IS MEASURED HERE

  TBind._FillADTField and TBind._FillDataSetField copy the source's field N
  into ATarget.Fields[N + 1], hard-coding the assumption that exactly ONE
  internal column precedes the mapped ones. Nothing else in this suite asserts
  that offset, so any internal column added by a later change could displace it
  in silence. MappedColumnsKeepTheOffsetTheNestedFillReliesOn is that guard,
  and it is written over the mapping list rather than over hand-copied indices
  so that it cannot rot into agreement with whatever the code does.

  THE RED THAT CAME FIRST

  Every one of the five distribution tests was written and RUN against the
  untouched framework before a line of Source changed, and every one failed
  there: the children typed under the first master came out on the second
  master's key in both local families; all four REST children came out on the
  second master's key in both REST families; and the two leaves typed under the
  middle mid row came out on the FIRST mid row's key, not the middle one and
  not the last one. A fix whose tests were never red is a fix nobody can grade.

  FOUR OF THOSE FIVE GO THROUGH THE SHIPPED APPLY, NOT FIVE

  The two local and the two REST fixtures drive ApplyInternal, which is the
  whole path: ApplyInserter -> the session's Insert -> SetAutoIncValueChilds.
  Recursion_LeavesTypedUnderTheMiddleMidRow_CarryThatMidRowKey does NOT. It
  calls SetAutoIncValueChilds directly, through TCascadeAccess.Propagate, and
  FORGES the state ApplyInserter would have left the master in - Edit plus the
  new key, not yet posted. That is a real gap and it is stated rather than
  hidden: the level 3 walk is measured over a hand-made master state, so what
  that test pins is the walk, not the walk's caller. NOTHING in this file - and
  nothing in Test.Janus.AutoInc.Childs, whose recursion tests call Propagate
  the same way - drives level 3 through a real ApplyInternal. Level 2 is
  covered end to end four times over; level 3 is covered from
  SetAutoIncValueChilds down. Say so rather than let the count of five stand
  in for it.

  HOW EACH CLAUSE WAS SHOWN TO BIND

  Each Source change was reverted one at a time and the suite re-run:

    * dropping the parentage clause from _AutoIncToChildRows, or dropping the
      _StampRowTokens call from DoNewRecord, reddens the same SEVEN tests -
      the five here plus the two distinct-key tests in
      Test.Janus.AutoInc.Childs;
    * putting the recursion back to ONE call per child adapter reddens FOUR,
      including Test.Janus.AutoInc.Childs
      .Linked_EveryGrandchildRowReceivesTheNewKey, which was green before any
      of this work - so the row identity WITHOUT the walk is not half a fix,
      it is a regression;
    * never creating the two columns reddens seven and errors an eighth;
    * removing their exclusion from TBind.SetFieldToField errors THIRTY-FIVE
      tests across this project, none of them in this file;
    * moving the row-identity column in front of the mapped ones reddens the
      offset guard here and InternalFieldIsFieldZero_WithCalcAndAggregateFields
      in Test.Janus.Apply.Loops;
    * dropping the fallback that recurses once when the child has no pending
      row reddens Recursion_WithNoPendingChildRow_StillReachesTheGrandchildren
      alone, and dropping the child-side benefit of the doubt in
      _IsOwnedByMasterRow reddens
      ChildRowWithNoRecordedParentage_IsStillWrittenByItsMaster alone.

  Every assertion added here was then inverted on its own, and each inversion
  reddened its own test and no other.

  ISSUE #265 - THE MASTER THAT CAME OUT OF THE STORE

  #264 gave every row an identity and every child a parentage, both stamped in
  DoNewRecord, and let a child with NO recorded parentage be written by
  whichever master was passing. #265 is who ends up in that escape hatch:
  loading rows appends them with the adapter's events DISABLED - see
  TSessionDataSet<M>._PopularDataSet, reached from
  TFDMemTableAdapter<M>.OpenSQLInternal - so EVERY master row that came from
  the database is untokenised, and every child typed under one of them was
  claimable by any other pending master.

  Seven tests were written for #265 and RUN against the untouched framework,
  and
  this is what they did THERE - re-measured against the file exactly as it is
  committed, not against an earlier draft of it:

    * ChildTypedUnderAnUnidentifiedMaster_MakesThatMasterIdentifyItself - RED.
      It reports all three of its numbers in one run: a child typed under a
      muted master recorded 0 whether that master key was real or the
      placeholder, while a child typed under a live master already recorded a
      positive identity. 0 is the value _IsOwnedByMasterRow waves through for
      EVERYBODY, so the first two children belonged to whoever asked;

    * LoadedMaster_ChildTypedUnderIt_KeepsTheLoadedMastersKey - RED ON THE
      RESULT: the child typed under a master LOADED FROM THE STORE, key 17,
      came out on 101, the brand new master's generated key. Every premise
      passed, so the run also established that the loaded master really carries
      a real key, really is NOT pending, really has no row identity, and that
      the shipped _GetMasterValues really had written 17 into the child at
      creation time;

    * MutedMasterAppend_WithARealKey_ItsChildKeepsThatKey - RED ON THE RESULT,
      the same 101, with the same untokenised master reached by muting the
      adapter by hand instead of by loading;

    * TwoUnidentifiedPendingMasters_ChildOfTheFirstIsNotClaimedByTheSecond -
      RED ON THE RESULT: the child typed under the FIRST of two untokenised
      masters came out on 201, the second one's key;

    * MutedMasterAppend_WithThePendingPlaceholder_ItsChildIsRepaired - GREEN,
      and it had to stay green. There the muted master's key is still the
      autoinc placeholder and the master IS pending, so it generates a key and
      the cascade REPAIRS its own child. A parentage rule that simply refused
      every child of an unidentified master turns this one red, leaving a -1
      foreign key where the framework used to put a real one;

    * ChildTypedBeforeItsMasterRowIsPosted_StillReceivesTheKey - GREEN, and it
      had to stay green too. Nothing is muted there at all: the master row is
      simply not POSTED yet, which is what a master-detail form looks like while
      the operator fills the header and starts adding items.

    * ChildTypedWhileTheMasterRowIsBeingEdited_DoesNotCommitThatEdit - RED, on
      its last clause: the child of a LOADED master in dsEdit came out naming
      nobody. Its two state clauses - the master is still in dsEdit and the
      value being typed is still in the buffer - pass on origin/develop, which
      is the point: they are there to say that the fix does not disturb an edit
      in progress, and they can only prove that if they also held before.

  A SEVENTH RED SITS IN THE NEIGHBOURING UNIT.
  Test.Janus.AutoInc.Childs
  .TwoPendingMasterRows_WithNoRecordedParentage_EveryPendingChildEndsOnTheLastMasterKey
  is red against origin/develop because #265 rewrote what its write-count clause
  measures. Its own body says why, and its write log is the sharpest single
  piece of evidence in this series: against untouched develop it reads FOUR
  writes - [mid C0 <- 101 while the master sat on R1/101] twice, then the same
  two rows again on R2 - which is the first master writing the second master's
  children, in the shipped ApplyInserter, spelled out.

  THE DESIGN THAT WAS MEASURED AND REJECTED

  The first answer to this issue marked the CHILD instead: a sentinel meaning
  "recorded, and my master had no identity", refused to any master that DOES
  identify itself. It passed everything above except the fourth, and the fourth
  is the point. A sentinel can separate an identified master from an
  unidentified one; it cannot separate two unidentified masters from each other,
  so the first of them still wrote the children of the second. That narrows the
  hole instead of closing it, and the test that catches it -
  TwoUnidentifiedPendingMasters_ChildOfTheFirstIsNotClaimedByTheSecond - was
  written to make the difference measurable rather than arguable.

  What ships instead removes the state rather than labelling it:
  _EnsureMasterRowToken gives the master ROW an identity at the instant a child
  is stamped under it, so the child names a concrete parent and
  _IsOwnedByMasterRow keeps the two answers #264 gave it. The one thing that
  had to be checked is that writing on the master row does not disturb it: the
  write is made with the MASTER's adapter muted, so DoBeforePost cannot promote
  the row to dsEdit, and both the loaded-master and the pending-master tests
  assert the marker on THAT row afterwards.

  WHY THE #265 FIXTURES BUILD THREE LEVELS FOR A TWO LEVEL QUESTION

  BuildTree creates a leaf adapter that never receives a row. It is there
  because TDataSetBaseAdapter<M>.DoNewRecord calls _GetMasterValues only
  `if FMasterObject.Count > 0` - only when the level being typed HAS CHILDREN
  OF ITS OWN. Without the leaf adapter the mid rows would never receive the
  master's key at creation time and the fixtures would have to type the foreign
  key by hand, which is precisely the value under test. With it, the foreign
  key is written BY THE SHIPPED PATH and the assertion is about the framework
  rather than about the fixture. Stated rather than hidden: in a two level
  configuration _GetMasterValues does not run, and what a detail row carries in
  its foreign key before the cascade is then whatever the consumer put there.

  HOW THE NEW SOURCE CLAUSES WERE SHOWN TO BIND - issue #265

  Each was reverted on its own and the whole project re-run:

    * never minting - _EnsureMasterRowToken reading and never writing - reddens
      all five tests that are red against origin/develop, and nothing else;
    * minting UNCONDITIONALLY, over an identity a row already had, reddens
      NINETEEN tests across Test.Janus.AutoInc.Childs, Test.Janus.Apply.Loops
      and this unit. The identity is load bearing far beyond #265 and
      overwriting one breaks #261;
    * minting WITHOUT muting the master's adapter reddens six, among them the
      two clauses that read the pending marker back off the master ROW - which
      is what says the mute is there for a reason and not for tidiness;
    * posting the master even when the caller was mid-edit reddens
      ChildTypedWhileTheMasterRowIsBeingEdited_DoesNotCommitThatEdit alone;
    * dropping the child-side benefit of the doubt from _IsOwnedByMasterRow
      reddens ChildRowWithNoRecordedParentage_IsStillWrittenByItsMaster alone,
      exactly as it did before this issue.

  ONE CLAUSE IS NOT DEFENDED AND SAYS SO. Removing the IsEmpty guard from
  _EnsureMasterRowToken reddens NOTHING. It stays because it mirrors the guard
  in _MasterRowToken and because minting needs a row to write on, but it is
  recorded as an unmeasured guard rather than left to look earned. A second
  candidate did NOT survive that rule: an exception to the same guard for
  dsInsert was written on the theory that a dataset on its first unposted row
  answers IsEmpty; removing it reddened nothing - including
  ChildTypedBeforeItsMasterRowIsPosted_StillReceivesTheKey, which reaches that
  exact state - so the theory was wrong and the clause came out.

  HOW MANY ASSERTIONS, COUNTED HONESTLY

  Every assertion this issue added or changed was inverted on its own and each
  inversion reddened its own test and no other. Four of them, however, cannot
  fail INDEPENDENTLY of a sibling, and saying only "each was inverted" would
  hide that: LoadedMaster..., MutedMasterAppend_WithARealKey...,
  TwoUnidentifiedPendingMasters... and
  MutedMasterAppend_WithThePendingPlaceholder... each have exactly ONE child
  row, so the "and none on the other key" clause is the arithmetic complement
  of the "one on this key" clause plus the premise that the two keys differ.
  They are kept because they make the failure message say WHERE the row went,
  not because they are independent evidence. Two child rows under two different
  masters would make them independent, and that is not reachable in the local
  family - appending the second master runs TDataSetAdapter<M>.DoNewRecord,
  which empties the children first. The REST family is where it is reachable,
  and the two REST tests earlier in this file are the ones that exercise it.

  WHAT IS NOT MEASURED HERE

  No live database and no live REST server. NO REST FIXTURE FOR #265 EITHER:
  the loaded-master shape is measured in the LOCAL family only, through the
  local load path, and the claim that the REST family reaches a stronger form of
  the same state - both masters holding their own children at once - rests on
  the two RestFDMemTable/RestClientDataSet tests above rather than on a run of
  its own. The generator is a double that
  answers the one SQLITE_SEQUENCE query the SQLite dialect sends, and the REST
  server is a double that answers the one `params` element
  TSessionRestFul<M>.Insert parses. Whether a row identity survives a REST
  round trip or a Close/Open against a real store is NOT established: nothing
  writes these columns to a database, but nothing here proves a real driver
  would leave them alone either.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.AutoInc.Distribution;

interface

uses
  DB,
  Classes,
  SysUtils,
  Variants,
  Generics.Collections,
  DUnitX.TestFramework,
  Datasnap.DBClient,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Param,
  FireDAC.Stan.Error,
  FireDAC.DatS,
  FireDAC.Phys.Intf,
  FireDAC.DApt.Intf,
  FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Explorer,
  Janus.DataSet.Fields,
  Janus.DataSet.Base.Adapter,
  Janus.DataSet.FDMemTable,
  Janus.DataSet.ClientDataSet,
  Janus.RestDataSet.FDMemTable,
  Janus.RestDataSet.ClientDataSet,
  Janus.RestFactory.Interfaces,
  Janus.Client.Methods,
  Test.Janus.Model.Nested,
  Test.Janus.Model.ReservedColumn,
  Test.Janus.Model.AutoIncTree,
  Test.Janus.Cursor.Double,
  Test.Janus.MasterDetail.Link;

type
  /// <summary> A cursor double that tells the two questions the ORM asks it
  ///  apart. The sequence question - the only SQL the SQLite generator sends,
  ///  recognised by its SQLITE_SEQUENCE table - is answered with ONE row whose
  ///  first column is the number to hand out, and the answer CHANGES on every
  ///  call so two master rows cannot end up on the same key. Every other query
  ///  is the re-open of a child dataset that TDataSetAdapter<M>.DoAfterScroll
  ///  fires when the master scrolls, and is answered with ZERO rows - which is
  ///  the truth here, since nothing in these fixtures was ever saved. </summary>
  TTreeConnection = class(TRowsConnection)
  private
    FNext: Integer;
    FStep: Integer;
    FHeld: IDBDataSet;
    FSequenceCalls: Integer;
    function _Make(const ARows: Integer; const AValue: Integer): IDBDataSet;
  public
    constructor CreateTree(const AStep: Integer);
    function CreateDataSet(const ASQL: String = ''): IDBDataSet; override;
    /// How many times the generator was asked. READ by the two local-family
    /// tests, and the number they assert is one call per PENDING ROW OF THE
    /// WHOLE HIERARCHY - not one per master. ApplyInternal runs its own three
    /// Apply* loops and then calls ApplyInternal on every child adapter, so
    /// the two master rows and the two child rows are four inserts and four
    /// generated keys. Zero would make every key clause in those tests
    /// vacuous. The REST fixtures answer from TSeqRestConnection instead, and
    /// the two recursion fixtures call Propagate without ever inserting, so
    /// none of the four reads this.
    property SequenceCalls: Integer read FSequenceCalls;
  end;

  /// <summary> The cursor double for the LOADED MASTER fixtures - issue #265.
  ///  It answers THREE questions where TTreeConnection answers two:
  ///
  ///    * the sequence query, recognised by SQLITE_SEQUENCE, with ONE row and a
  ///      NEW number every call, so no two masters land on the same key;
  ///    * ONE NOMINATED SELECT, cLOADSQL, with one row that is an `aitroot` row
  ///      exactly as a database hands it back - key ALREADY REAL, no
  ///      placeholder;
  ///    * everything else with ZERO rows, which is the truth for the child
  ///      re-open TDataSetAdapter<M>.DoAfterScroll fires in a fixture where
  ///      nothing was ever saved.
  ///
  ///  The load answer is keyed on a SQL STRING THE FIXTURE CHOOSES, because
  ///  TDMLCommandFactory.GeneratorSelect passes ASQL to CreateDataSet untouched
  ///  - so OpenSQLInternal(cLOADSQL) reaches this double verbatim and nothing
  ///  here has to guess what the SQLite generator would have produced. What is
  ///  under test is the LOAD PATH, not the SELECT text. </summary>
  TStoreConnection = class(TRowsConnection)
  private
    FNext: Integer;
    FStep: Integer;
    FLoadedKey: Integer;
    FHeld: IDBDataSet;
    FSequenceCalls: Integer;
    FLoadCalls: Integer;
    function _MakeSequence: IDBDataSet;
    function _MakeLoadedRoot: IDBDataSet;
    function _MakeEmpty: IDBDataSet;
  public
    constructor CreateStore(const AStep: Integer; const ALoadedKey: Integer);
    function CreateDataSet(const ASQL: String = ''): IDBDataSet; override;
    /// How many times the generator was asked - read as a PREMISE, so that a
    /// key clause can never pass on a run where nothing was generated.
    property SequenceCalls: Integer read FSequenceCalls;
    /// How many times the nominated SELECT was answered. One means the fixture
    /// really went through the shipped load path; zero would make the whole
    /// test vacuous.
    property LoadCalls: Integer read FLoadCalls;
  end;

  /// <summary> An IRESTConnection whose POST answers the `params` element
  ///  TSessionRestFul<M>.Insert parses, so that TRESTDataSetAdapter<M>
  ///  .ApplyInserter reaches SetAutoIncValueChilds at all - it only does so
  ///  when ResultParams came back non-empty. The key changes per call for the
  ///  same reason as above. </summary>
  TSeqRestConnection = class(TInertRestConnection, IRESTConnection)
  private
    FNext: Integer;
    FStep: Integer;
    FColumn: String;
    function _Answer: String;
  public
    constructor CreateSeq(const AColumn: String; const AStep: Integer);
    function Execute(const AResource, ASubResource: String;
      const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): String; overload;
    function Execute(const AResource: String;
      const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): String; overload;
  end;

  /// <summary> Classic protected-access descendant: ApplyInternal,
  ///  SetAutoIncValueChilds, DisableDataSetEvents and EnableDataSetEvents are
  ///  protected, and driving the SHIPPED methods is the whole point. </summary>
  TCascadeAccess<M: class, constructor> = class(TDataSetBaseAdapter<M>)
  public
    class procedure ApplyAll(const A: TDataSetBaseAdapter<M>);
    class procedure Propagate(const A: TDataSetBaseAdapter<M>);
    class procedure Mute(const A: TDataSetBaseAdapter<M>);
    class procedure Unmute(const A: TDataSetBaseAdapter<M>);
  end;

  [TestFixture]
  TTestAutoIncDistribution = class
  private
    FConn: IDBConnection;
    FTree: TTreeConnection;
    FRest: IRESTConnection;
    procedure SeedTwoMastersThenChildrenUnderTheFirst(const AMaster,
      AChild: TDataSet; const AChildRows: Integer);
    function KeyOfMasterRow(const AMaster: TDataSet;
      const ALast: Boolean): Integer;
    function KeyOfTaggedRow(const ADataSet: TDataSet;
      const ATag: String): Integer;
    function TokenOfTaggedRow(const ADataSet: TDataSet; const ATag: String;
      const AColumn: String): Integer;
    procedure BuildTree(const AConnection: IDBConnection;
      out ARootTable, AMidTable, ALeafTable: TFDMemTable;
      out ARoot: TFDMemTableAdapter<TAitRoot>;
      out AMid: TFDMemTableAdapter<TAitMid>;
      out ALeaf: TFDMemTableAdapter<TAitLeaf>);
    function OwnerTokenOfAChildUnderAMutedMaster(
      const ARealKey: Boolean): Integer;
    function OwnerTokenOfAChildUnderALiveMaster: Integer;
    procedure DropTree(var ARootTable, AMidTable, ALeafTable: TFDMemTable;
      var ARoot: TFDMemTableAdapter<TAitRoot>;
      var AMid: TFDMemTableAdapter<TAitMid>;
      var ALeaf: TFDMemTableAdapter<TAitLeaf>);
    function CountWithColumn(const ADataSet: TDataSet; const AColumn: String;
      const AValue: Integer): Integer;
    function RowCount(const ADataSet: TDataSet): Integer;
    function DumpColumn(const ADataSet: TDataSet;
      const AColumn: String): String;
    procedure AssertColumnsFollowTheMapping(const ADataSet: TDataSet;
      const AClass: TClass; const AWhere: String);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // --- level 2: two pending masters, the children of ONE of them ---------
    [Test]
    procedure Premise_OrderBReachesTwoPendingMastersAndTwoPendingChildren;
    [Test]
    procedure FDMemTable_ChildrenTypedUnderTheFirstMaster_StayOnIt;
    [Test]
    procedure ClientDataSet_ChildrenTypedUnderTheFirstMaster_StayOnIt;
    [Test]
    procedure RestFDMemTable_EachMasterKeepsItsOwnChildren;
    [Test]
    procedure RestClientDataSet_EachMasterKeepsItsOwnChildren;

    // --- level 3: the recursion into the children of a child ---------------
    [Test]
    procedure Recursion_LeavesTypedUnderTheMiddleMidRow_CarryThatMidRowKey;

    [Test]
    procedure Recursion_WithNoPendingChildRow_StillReachesTheGrandchildren;

    // --- issue #265: the master that came out of the store ------------------
    [Test]
    procedure ChildTypedUnderAnUnidentifiedMaster_MakesThatMasterIdentifyItself;
    [Test]
    procedure TwoUnidentifiedPendingMasters_ChildOfTheFirstIsNotClaimedByTheSecond;
    [Test]
    procedure ChildTypedBeforeItsMasterRowIsPosted_StillReceivesTheKey;
    [Test]
    procedure ChildTypedWhileTheMasterRowIsBeingEdited_DoesNotCommitThatEdit;
    [Test]
    procedure LoadedMaster_ChildTypedUnderIt_KeepsTheLoadedMastersKey;
    [Test]
    procedure MutedMasterAppend_WithARealKey_ItsChildKeepsThatKey;
    [Test]
    procedure MutedMasterAppend_WithThePendingPlaceholder_ItsChildIsRepaired;

    // --- the boundary of the fix -------------------------------------------
    [Test]
    procedure UntokenisedRows_KeepTheHistoricalBehaviour;
    [Test]
    procedure ChildRowWithNoRecordedParentage_IsStillWrittenByItsMaster;

    // --- the latent position site the new column must not disturb ----------
    [Test]
    procedure MappedColumnsKeepTheOffsetTheNestedFillReliesOn;

    // --- the two names the new columns took out of circulation -------------
    [Test]
    [TestCase('RowToken', 'RowToken')]
    [TestCase('OwnerToken', 'OwnerToken')]
    procedure EntityColumnNamedLikeAReservedOne_SaysWhichNameIsReserved(
      const AReserved: String);
  end;

implementation

const
  cKEY        = 'root_id';
  cOWNKEY     = 'mid_id';
  cTAG        = 'tag';
  cCHILDROWS  = 2;
  cMIDROWS    = 3;
  cSTEP       = 100;
  cRESTSTEP   = 300;
  cSEQCOLUMN  = 'SEQUENCE';
  cSEQTABLE   = 'SQLITE_SEQUENCE';
  cROOTOLD    = 0;
  cROOTNEW    = 500;
  /// Three mid rows carrying three DIFFERENT own keys. The leaves are typed
  /// under the MIDDLE one on purpose: with the first one the collapse and the
  /// correct answer are the same number, and with the last one the correct
  /// answer cannot be told from a last-writer-wins walk.
  cMIDFIRST   = 91;
  cMIDMIDDLE  = 92;
  cMIDLAST    = 93;
  /// The leaves start on a value NO mid row carries, so "nothing was written"
  /// can never be read as "the right thing was written".
  cLEAFSTART  = -7;
  cWALKCEILING = 50;
  /// Spelled out rather than imported from Janus.DataSet.Fields, so a rename
  /// of the shipped constant shows up as a red instead of as silent agreement.
  cOWNERTOKEN = 'OwnerToken';
  cROWTOKEN   = 'RowToken';
  /// issue #265. The SQL the loaded-master fixture hands to the shipped
  /// OpenSQLInternal, and which TStoreConnection answers with one row.
  cLOADSQL    = 'JANUS-TEST-LOAD-AITROOT';
  /// The key that row arrives with. REAL - it came from the store - and
  /// different from every number the sequence double hands out (cSTEP, 2*cSTEP,
  /// ...), so "the child kept its own key" and "the child was re-parented" can
  /// never be the same number.
  cLOADEDKEY  = 17;
  cLOADEDTAG  = 'LOADED';
  cNEWTAG     = 'NEW';
  /// The value TBind.SetInternalInitFieldDefsObjectClass puts in an autoinc
  /// primary key as DefaultExpression - the PENDING PLACEHOLDER. Spelled out
  /// here rather than read off the field, because fixture B exists precisely to
  /// tell a placeholder key apart from a real one.
  cPLACEHOLDER = -1;
  /// The value cOwnerTokenField carries when nobody ever recorded the row.
  /// Spelled out here for the same reason as the two names above: Janus
  /// declares it in the IMPLEMENTATION section of Janus.DataSet.Base.Adapter,
  /// so a test cannot import it and must not pretend to.
  cNOTOKEN = 0;
  cEDITEDTAG  = 'EDITING';

type
  TScrollMute = record
    Before: TDataSetNotifyEvent;
    After: TDataSetNotifyEvent;
  end;

/// A fixture helper that walks a dataset must not fire the adapter's own
/// AfterScroll, which re-opens - and therefore empties - the children of the
/// row it lands on. Measuring must not change what is being measured.
function MuteScroll(const ADataSet: TDataSet): TScrollMute;
begin
  Result.Before := ADataSet.BeforeScroll;
  Result.After := ADataSet.AfterScroll;
  ADataSet.BeforeScroll := nil;
  ADataSet.AfterScroll := nil;
end;

procedure UnmuteScroll(const ADataSet: TDataSet; const AMute: TScrollMute);
begin
  ADataSet.BeforeScroll := AMute.Before;
  ADataSet.AfterScroll := AMute.After;
end;

{ TTreeConnection }

constructor TTreeConnection.CreateTree(const AStep: Integer);
begin
  inherited Create(TDriverName.dnSQLite, 0,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add(cSEQCOLUMN, ftInteger);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName(cSEQCOLUMN).AsInteger := 0;
    end,
    'tree');
  FNext := 0;
  FStep := AStep;
  FSequenceCalls := 0;
end;

function TTreeConnection._Make(const ARows: Integer;
  const AValue: Integer): IDBDataSet;
var
  LTable: TFDMemTable;
  LFor: Integer;
begin
  LTable := TFDMemTable.Create(nil);
  try
    LTable.ResourceOptions.SilentMode := True;
    LTable.FieldDefs.Add(cSEQCOLUMN, ftInteger);
    LTable.CreateDataSet;
    for LFor := 0 to ARows - 1 do
    begin
      LTable.Append;
      LTable.FieldByName(cSEQCOLUMN).AsInteger := AValue;
      LTable.Post;
    end;
    LTable.First;
  except
    LTable.Free;
    raise;
  end;
  // TDriverDataSet<T> takes ownership of LTable and frees it on destruction.
  FHeld := TSpyResultSet.CreateSpy(LTable, ARows, 'tree');
  Result := FHeld;
end;

function TTreeConnection.CreateDataSet(const ASQL: String): IDBDataSet;
begin
  if Pos(cSEQTABLE, UpperCase(ASQL)) > 0 then
  begin
    Inc(FSequenceCalls);
    Inc(FNext, FStep);
    Result := _Make(1, FNext);
  end
  else
    Result := _Make(0, 0);
end;

{ TStoreConnection }

constructor TStoreConnection.CreateStore(const AStep: Integer;
  const ALoadedKey: Integer);
begin
  inherited Create(TDriverName.dnSQLite, 0,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add(cSEQCOLUMN, ftInteger);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName(cSEQCOLUMN).AsInteger := 0;
    end,
    'store');
  FNext := 0;
  FStep := AStep;
  FLoadedKey := ALoadedKey;
  FSequenceCalls := 0;
  FLoadCalls := 0;
end;

function TStoreConnection._MakeSequence: IDBDataSet;
var
  LTable: TFDMemTable;
begin
  LTable := TFDMemTable.Create(nil);
  try
    LTable.ResourceOptions.SilentMode := True;
    LTable.FieldDefs.Add(cSEQCOLUMN, ftInteger);
    LTable.CreateDataSet;
    LTable.Append;
    LTable.FieldByName(cSEQCOLUMN).AsInteger := FNext;
    LTable.Post;
    LTable.First;
  except
    LTable.Free;
    raise;
  end;
  // TDriverDataSet<T> takes ownership of LTable and frees it on destruction.
  FHeld := TSpyResultSet.CreateSpy(LTable, 1, 'store-seq');
  Result := FHeld;
end;

/// One `aitroot` row as the database hands it back. TBind.SetFieldToField walks
/// the TARGET dataset and asks the source for every MAPPED column by name, so
/// the schema here has to carry all of them - and only them: the internal and
/// the two provenance columns are excluded by name on the target side, which is
/// the very reason the loaded row ends up with no identity.
function TStoreConnection._MakeLoadedRoot: IDBDataSet;
var
  LTable: TFDMemTable;
begin
  LTable := TFDMemTable.Create(nil);
  try
    LTable.ResourceOptions.SilentMode := True;
    LTable.FieldDefs.Add(cKEY, ftInteger);
    LTable.FieldDefs.Add(cTAG, ftString, 20);
    LTable.CreateDataSet;
    LTable.Append;
    LTable.FieldByName(cKEY).AsInteger := FLoadedKey;
    LTable.FieldByName(cTAG).AsString := cLOADEDTAG;
    LTable.Post;
    LTable.First;
  except
    LTable.Free;
    raise;
  end;
  FHeld := TSpyResultSet.CreateSpy(LTable, 1, 'store-load');
  Result := FHeld;
end;

function TStoreConnection._MakeEmpty: IDBDataSet;
var
  LTable: TFDMemTable;
begin
  LTable := TFDMemTable.Create(nil);
  try
    LTable.ResourceOptions.SilentMode := True;
    LTable.FieldDefs.Add(cSEQCOLUMN, ftInteger);
    LTable.CreateDataSet;
  except
    LTable.Free;
    raise;
  end;
  FHeld := TSpyResultSet.CreateSpy(LTable, 0, 'store-empty');
  Result := FHeld;
end;

function TStoreConnection.CreateDataSet(const ASQL: String): IDBDataSet;
begin
  if Pos(cSEQTABLE, UpperCase(ASQL)) > 0 then
  begin
    Inc(FSequenceCalls);
    Inc(FNext, FStep);
    Result := _MakeSequence;
  end
  else
  if Pos(cLOADSQL, UpperCase(ASQL)) > 0 then
  begin
    Inc(FLoadCalls);
    Result := _MakeLoadedRoot;
  end
  else
    Result := _MakeEmpty;
end;

{ TSeqRestConnection }

constructor TSeqRestConnection.CreateSeq(const AColumn: String;
  const AStep: Integer);
begin
  inherited Create;
  FColumn := AColumn;
  FStep := AStep;
  FNext := 0;
end;

function TSeqRestConnection._Answer: String;
begin
  Inc(FNext, FStep);
  Result := '{"params":[{"' + FColumn + '":"' + IntToStr(FNext) + '"}]}';
end;

function TSeqRestConnection.Execute(const AResource, ASubResource: String;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): String;
begin
  if Assigned(AParams) then
    AParams();
  Result := _Answer;
end;

function TSeqRestConnection.Execute(const AResource: String;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): String;
begin
  if Assigned(AParams) then
    AParams();
  Result := _Answer;
end;

{ TCascadeAccess<M> }

class procedure TCascadeAccess<M>.ApplyAll(const A: TDataSetBaseAdapter<M>);
begin
  TCascadeAccess<M>(A).ApplyInternal(0);
end;

class procedure TCascadeAccess<M>.Propagate(const A: TDataSetBaseAdapter<M>);
begin
  TCascadeAccess<M>(A).SetAutoIncValueChilds;
end;

class procedure TCascadeAccess<M>.Mute(const A: TDataSetBaseAdapter<M>);
begin
  TCascadeAccess<M>(A).DisableDataSetEvents;
end;

class procedure TCascadeAccess<M>.Unmute(const A: TDataSetBaseAdapter<M>);
begin
  TCascadeAccess<M>(A).EnableDataSetEvents;
end;

{ TTestAutoIncDistribution }

procedure TTestAutoIncDistribution.Setup;
begin
  FTree := TTreeConnection.CreateTree(cSTEP);
  FConn := FTree;
  FRest := TSeqRestConnection.CreateSeq(cKEY, cRESTSTEP);
end;

procedure TTestAutoIncDistribution.TearDown;
begin
  FRest := nil;
  FTree := nil;
  FConn := nil;
end;

/// ORDERING B, and the whole reason nothing here is muted: both master rows go
/// in while the child table is still empty, the cursor goes back to the FIRST
/// of them, and only then are the children typed. See the unit header.
procedure TTestAutoIncDistribution.SeedTwoMastersThenChildrenUnderTheFirst(
  const AMaster, AChild: TDataSet; const AChildRows: Integer);
var
  LFor: Integer;
begin
  AMaster.Append;
  AMaster.FieldByName(cKEY).AsInteger := cROOTOLD;
  AMaster.FieldByName(cTAG).AsString := 'R1';
  AMaster.Post;
  AMaster.Append;
  AMaster.FieldByName(cKEY).AsInteger := cROOTOLD;
  AMaster.FieldByName(cTAG).AsString := 'R2';
  AMaster.Post;
  // Back to the first master, with the child table still empty so the re-open
  // this scroll fires has nothing to discard.
  AMaster.First;
  for LFor := 0 to AChildRows - 1 do
  begin
    AChild.Append;
    AChild.FieldByName(cOWNKEY).AsInteger := 0;
    AChild.FieldByName(cKEY).AsInteger := cROOTOLD;
    AChild.FieldByName(cTAG).AsString := 'C' + IntToStr(LFor);
    AChild.Post;
  end;
end;

function TTestAutoIncDistribution.KeyOfMasterRow(const AMaster: TDataSet;
  const ALast: Boolean): Integer;
var
  LMute: TScrollMute;
begin
  LMute := MuteScroll(AMaster);
  try
    if ALast then
      AMaster.Last
    else
      AMaster.First;
    Result := AMaster.FieldByName(cKEY).AsInteger;
  finally
    UnmuteScroll(AMaster, LMute);
  end;
end;

/// Reads a column of the row carrying a given `tag`, instead of the row at a
/// given POSITION. The loaded-master fixtures need it: KeyOfMasterRow(First) and
/// KeyOfMasterRow(Last) name POSITIONS, and a fixture whose two masters arrive
/// by two DIFFERENT routes - one from the store, one appended - must not have
/// its assertions depend on which route lands where.
function TTestAutoIncDistribution.TokenOfTaggedRow(const ADataSet: TDataSet;
  const ATag: String; const AColumn: String): Integer;
var
  LMute: TScrollMute;
begin
  Result := MaxInt;
  LMute := MuteScroll(ADataSet);
  try
    ADataSet.First;
    while not ADataSet.Eof do
    begin
      if ADataSet.FieldByName(cTAG).AsString = ATag then
      begin
        Result := ADataSet.FieldByName(AColumn).AsInteger;
        Break;
      end;
      ADataSet.Next;
    end;
  finally
    UnmuteScroll(ADataSet, LMute);
  end;
end;

function TTestAutoIncDistribution.KeyOfTaggedRow(const ADataSet: TDataSet;
  const ATag: String): Integer;
begin
  Result := TokenOfTaggedRow(ADataSet, ATag, cKEY);
end;

/// The THREE level tree the issue #265 fixtures share, and three levels rather
/// than two ON PURPOSE. TDataSetBaseAdapter<M>.DoNewRecord calls
/// _GetMasterValues only `if FMasterObject.Count > 0` - that is, only when the
/// level being typed HAS CHILDREN OF ITS OWN. With root and mid alone the mid
/// rows never receive the master's key at creation time and the fixture would
/// have to type the foreign key by hand, which is exactly the state under test.
/// With the leaf adapter present the mid level has children, _GetMasterValues
/// fires, and the child's foreign key is written BY THE SHIPPED PATH. No leaf
/// ROW is ever typed - the leaf adapter is there for that gate alone.
procedure TTestAutoIncDistribution.BuildTree(const AConnection: IDBConnection;
  out ARootTable, AMidTable, ALeafTable: TFDMemTable;
  out ARoot: TFDMemTableAdapter<TAitRoot>;
  out AMid: TFDMemTableAdapter<TAitMid>;
  out ALeaf: TFDMemTableAdapter<TAitLeaf>);
begin
  ARootTable := TFDMemTable.Create(nil);
  AMidTable := TFDMemTable.Create(nil);
  ALeafTable := TFDMemTable.Create(nil);
  ARoot := TFDMemTableAdapter<TAitRoot>.Create(AConnection, ARootTable, -1, nil);
  AMid := TFDMemTableAdapter<TAitMid>.Create(AConnection, AMidTable, -1, ARoot);
  ALeaf := TFDMemTableAdapter<TAitLeaf>.Create(AConnection, ALeafTable, -1,
             AMid);
end;

procedure TTestAutoIncDistribution.DropTree(var ARootTable, AMidTable,
  ALeafTable: TFDMemTable; var ARoot: TFDMemTableAdapter<TAitRoot>;
  var AMid: TFDMemTableAdapter<TAitMid>;
  var ALeaf: TFDMemTableAdapter<TAitLeaf>);
begin
  ALeaf.Free;
  AMid.Free;
  ARoot.Free;
  ALeafTable.Free;
  AMidTable.Free;
  ARootTable.Free;
end;

function TTestAutoIncDistribution.CountWithColumn(const ADataSet: TDataSet;
  const AColumn: String; const AValue: Integer): Integer;
var
  LMute: TScrollMute;
begin
  LMute := MuteScroll(ADataSet);
  try
    Result := 0;
    ADataSet.First;
    while (not ADataSet.Eof) and (Result <= cWALKCEILING) do
    begin
      if ADataSet.FieldByName(AColumn).AsInteger = AValue then
        Inc(Result);
      ADataSet.Next;
    end;
  finally
    UnmuteScroll(ADataSet, LMute);
  end;
end;

function TTestAutoIncDistribution.RowCount(const ADataSet: TDataSet): Integer;
var
  LMute: TScrollMute;
begin
  LMute := MuteScroll(ADataSet);
  try
    Result := 0;
    ADataSet.First;
    while (not ADataSet.Eof) and (Result < cWALKCEILING) do
    begin
      Inc(Result);
      ADataSet.Next;
    end;
  finally
    UnmuteScroll(ADataSet, LMute);
  end;
end;

/// Quoted by every assertion below, so a red never asks anyone to guess what
/// the run actually produced.
function TTestAutoIncDistribution.DumpColumn(const ADataSet: TDataSet;
  const AColumn: String): String;
var
  LMute: TScrollMute;
begin
  LMute := MuteScroll(ADataSet);
  try
    Result := '';
    ADataSet.First;
    while not ADataSet.Eof do
    begin
      Result := Result + '[' + ADataSet.FieldByName(cTAG).AsString + ' ' +
                AColumn + '=' + ADataSet.FieldByName(AColumn).AsString + ']';
      ADataSet.Next;
    end;
  finally
    UnmuteScroll(ADataSet, LMute);
  end;
end;

// ---------------------------------------------------------------------------
// Level 2 - two pending master rows
// ---------------------------------------------------------------------------

procedure TTestAutoIncDistribution.Premise_OrderBReachesTwoPendingMastersAndTwoPendingChildren;
var
  LMasterTable: TFDMemTable;
  LChildTable: TFDMemTable;
  LMaster: TFDMemTableAdapter<TAitRoot>;
  LChild: TFDMemTableAdapter<TAitMid>;
  LPending: Integer;
  LMute: TScrollMute;
begin
  // Without this the four tests below could all pass on an empty table. It
  // also states the ordering claim in the unit header as a number: the child
  // rows are STILL THERE after the second master went in, because they went in
  // afterwards.
  LMasterTable := TFDMemTable.Create(nil);
  LChildTable := TFDMemTable.Create(nil);
  try
    LMaster := TFDMemTableAdapter<TAitRoot>.Create(FConn, LMasterTable, -1, nil);
    LChild := TFDMemTableAdapter<TAitMid>.Create(FConn, LChildTable, -1,
                LMaster);
    try
      SeedTwoMastersThenChildrenUnderTheFirst(LMasterTable, LChildTable,
                                              cCHILDROWS);
      Assert.AreEqual(2, RowCount(LMasterTable),
        'both master rows must survive the set-up');
      Assert.AreEqual(cCHILDROWS, RowCount(LChildTable),
        'and so must the children - if this is 0 the ordering claim in the ' +
        'unit header is wrong and every test below is vacuous');
      LPending := 0;
      LMute := MuteScroll(LChildTable);
      try
        LChildTable.First;
        while not LChildTable.Eof do
        begin
          if LChildTable.FieldByName(cInternalField).AsInteger =
             Integer(dsInsert) then
            Inc(LPending);
          LChildTable.Next;
        end;
      finally
        UnmuteScroll(LChildTable, LMute);
      end;
      Assert.AreEqual(cCHILDROWS, LPending,
        'every child row must carry the PENDING marker written by the shipped ' +
        'TDataSetBaseAdapter<M>.DoBeforePost - nothing here writes it by hand, ' +
        'and _IsPendingInsertRow is what gates the write under test');
    finally
      LChild.Free;
      LMaster.Free;
    end;
  finally
    LChildTable.Free;
    LMasterTable.Free;
  end;
end;

procedure TTestAutoIncDistribution.FDMemTable_ChildrenTypedUnderTheFirstMaster_StayOnIt;
var
  LMasterTable: TFDMemTable;
  LChildTable: TFDMemTable;
  LMaster: TFDMemTableAdapter<TAitRoot>;
  LChild: TFDMemTableAdapter<TAitMid>;
  LKeyA: Integer;
  LKeyB: Integer;
begin
  // THE SHIPPED APPLY, not a mirror of it: ApplyInternal -> ApplyInserter ->
  // FSession.Insert -> SetAutoIncValueChilds, over the real generator command.
  LMasterTable := TFDMemTable.Create(nil);
  LChildTable := TFDMemTable.Create(nil);
  try
    LMaster := TFDMemTableAdapter<TAitRoot>.Create(FConn, LMasterTable, -1, nil);
    LChild := TFDMemTableAdapter<TAitMid>.Create(FConn, LChildTable, -1,
                LMaster);
    try
      SeedTwoMastersThenChildrenUnderTheFirst(LMasterTable, LChildTable,
                                              cCHILDROWS);

      TCascadeAccess<TAitRoot>.ApplyAll(LMaster);

      LKeyA := KeyOfMasterRow(LMasterTable, False);
      LKeyB := KeyOfMasterRow(LMasterTable, True);
      Assert.IsTrue(LKeyA > 0,
        'PREMISE: the first master must have received a generated key, or ' +
        'the cascade had nothing to propagate');
      Assert.AreNotEqual(LKeyA, LKeyB,
        'PREMISE: the two masters must carry DIFFERENT keys, or this test ' +
        'cannot tell which one the children ended on');
      Assert.AreEqual(2 + cCHILDROWS, FTree.SequenceCalls,
        'PREMISE: the generator double must have been asked ONCE PER PENDING ' +
        'ROW that ApplyInternal inserted - the two master rows, and then the ' +
        'child rows, because ApplyInternal calls ApplyInternal on every child ' +
        'adapter after its own loops. Zero would make every key clause here ' +
        'vacuous');

      Assert.AreEqual(cCHILDROWS, CountWithColumn(LChildTable, cKEY, LKeyA),
        'every child row was typed with the cursor on the FIRST master, so ' +
        'every one of them must come out on that row key - ' +
        DumpColumn(LChildTable, cKEY));
      Assert.AreEqual(0, CountWithColumn(LChildTable, cKEY, LKeyB),
        'not one may be re-parented onto the second pending master, which is ' +
        'what a walk that stamps every pending child once per master row ' +
        'produces - ' + DumpColumn(LChildTable, cKEY));
    finally
      LChild.Free;
      LMaster.Free;
    end;
  finally
    LChildTable.Free;
    LMasterTable.Free;
  end;
end;

procedure TTestAutoIncDistribution.ClientDataSet_ChildrenTypedUnderTheFirstMaster_StayOnIt;
var
  LMasterCds: TClientDataSet;
  LChildCds: TClientDataSet;
  LMaster: TClientDataSetAdapter<TAitRoot>;
  LChild: TClientDataSetAdapter<TAitMid>;
  LKeyA: Integer;
  LKeyB: Integer;
begin
  // The SECOND local family. TClientDataSetAdapter<M>.ApplyInserter carries the
  // same per-pending-master loop; measured here rather than inferred from the
  // FDMemTable one.
  LMasterCds := TClientDataSet.Create(nil);
  LChildCds := TClientDataSet.Create(nil);
  try
    LMaster := TClientDataSetAdapter<TAitRoot>.Create(FConn, LMasterCds, -1,
                 nil);
    LChild := TClientDataSetAdapter<TAitMid>.Create(FConn, LChildCds, -1,
                LMaster);
    try
      SeedTwoMastersThenChildrenUnderTheFirst(LMasterCds, LChildCds,
                                              cCHILDROWS);

      TCascadeAccess<TAitRoot>.ApplyAll(LMaster);

      LKeyA := KeyOfMasterRow(LMasterCds, False);
      LKeyB := KeyOfMasterRow(LMasterCds, True);
      Assert.IsTrue(LKeyA > 0,
        'PREMISE: the first master must have received a generated key');
      Assert.AreNotEqual(LKeyA, LKeyB,
        'PREMISE: the two masters must carry DIFFERENT keys');
      Assert.AreEqual(2 + cCHILDROWS, FTree.SequenceCalls,
        'PREMISE: and the same count in this family - TClientDataSetAdapter<M> ' +
        'carries its own ApplyInserter and its own ApplyInternal, so the ' +
        'number is measured here rather than inferred from the FDMemTable one');

      Assert.AreEqual(cCHILDROWS, CountWithColumn(LChildCds, cKEY, LKeyA),
        'the ClientDataSet family must keep the children on the master they ' +
        'were typed under - ' + DumpColumn(LChildCds, cKEY));
      Assert.AreEqual(0, CountWithColumn(LChildCds, cKEY, LKeyB),
        'and re-parent none of them onto the second - ' +
        DumpColumn(LChildCds, cKEY));
    finally
      LChild.Free;
      LMaster.Free;
    end;
  finally
    LChildCds.Free;
    LMasterCds.Free;
  end;
end;

procedure TTestAutoIncDistribution.RestFDMemTable_EachMasterKeepsItsOwnChildren;
var
  LMasterTable: TFDMemTable;
  LChildTable: TFDMemTable;
  LMaster: TRESTFDMemTableAdapter<TAitRoot>;
  LChild: TRESTFDMemTableAdapter<TAitMid>;
  LKeyA: Integer;
  LKeyB: Integer;
  LFor: Integer;
begin
  // THE STRONGER STATE. TRESTDataSetAdapter<M>.OpenDataSetChilds has an empty
  // body, so appending the second master discards nothing and BOTH masters can
  // hold their own pending children at the same time. A cascade that collapses
  // has four rows to collapse here, not two.
  LMasterTable := TFDMemTable.Create(nil);
  LChildTable := TFDMemTable.Create(nil);
  try
    LMaster := TRESTFDMemTableAdapter<TAitRoot>.Create(FRest, LMasterTable, -1,
                 nil);
    LChild := TRESTFDMemTableAdapter<TAitMid>.Create(FRest, LChildTable, -1,
                LMaster);
    try
      LMasterTable.Append;
      LMasterTable.FieldByName(cKEY).AsInteger := cROOTOLD;
      LMasterTable.FieldByName(cTAG).AsString := 'R1';
      LMasterTable.Post;
      for LFor := 0 to cCHILDROWS - 1 do
      begin
        LChildTable.Append;
        LChildTable.FieldByName(cOWNKEY).AsInteger := 0;
        LChildTable.FieldByName(cKEY).AsInteger := cROOTOLD;
        LChildTable.FieldByName(cTAG).AsString := 'A' + IntToStr(LFor);
        LChildTable.Post;
      end;
      LMasterTable.Append;
      LMasterTable.FieldByName(cKEY).AsInteger := cROOTOLD;
      LMasterTable.FieldByName(cTAG).AsString := 'R2';
      LMasterTable.Post;
      for LFor := 0 to cCHILDROWS - 1 do
      begin
        LChildTable.Append;
        LChildTable.FieldByName(cOWNKEY).AsInteger := 0;
        LChildTable.FieldByName(cKEY).AsInteger := cROOTOLD;
        LChildTable.FieldByName(cTAG).AsString := 'B' + IntToStr(LFor);
        LChildTable.Post;
      end;
      Assert.AreEqual(cCHILDROWS * 2, RowCount(LChildTable),
        'PREMISE: the REST family must hold the children of BOTH masters at ' +
        'once - that is what makes this the stronger shape');

      TCascadeAccess<TAitRoot>.ApplyAll(LMaster);

      LKeyA := KeyOfMasterRow(LMasterTable, False);
      LKeyB := KeyOfMasterRow(LMasterTable, True);
      Assert.IsTrue(LKeyA > 0,
        'PREMISE: the first master must have received a key from the server ' +
        'answer, or ApplyInserter never reached SetAutoIncValueChilds');
      Assert.AreNotEqual(LKeyA, LKeyB,
        'PREMISE: the two masters must carry DIFFERENT keys');

      Assert.AreEqual(cCHILDROWS, CountWithColumn(LChildTable, cKEY, LKeyA),
        'the two children typed under the FIRST master must come out on its ' +
        'key - ' + DumpColumn(LChildTable, cKEY));
      Assert.AreEqual(cCHILDROWS, CountWithColumn(LChildTable, cKEY, LKeyB),
        'and the two typed under the SECOND on its own - a cascade that ' +
        'ignores parentage puts all four on the last one - ' +
        DumpColumn(LChildTable, cKEY));
    finally
      LChild.Free;
      LMaster.Free;
    end;
  finally
    LChildTable.Free;
    LMasterTable.Free;
  end;
end;

procedure TTestAutoIncDistribution.RestClientDataSet_EachMasterKeepsItsOwnChildren;
var
  LMasterCds: TClientDataSet;
  LChildCds: TClientDataSet;
  LMaster: TRESTClientDataSetAdapter<TAitRoot>;
  LChild: TRESTClientDataSetAdapter<TAitMid>;
  LKeyA: Integer;
  LKeyB: Integer;
  LFor: Integer;
begin
  // The FOURTH family, and the one the #261 spike explicitly made no claim
  // about. It inherits ApplyInserter from TRESTDataSetAdapter<M> and carries
  // its own ApplyInternal, so it is run rather than read.
  LMasterCds := TClientDataSet.Create(nil);
  LChildCds := TClientDataSet.Create(nil);
  try
    LMaster := TRESTClientDataSetAdapter<TAitRoot>.Create(FRest, LMasterCds, -1,
                 nil);
    LChild := TRESTClientDataSetAdapter<TAitMid>.Create(FRest, LChildCds, -1,
                LMaster);
    try
      LMasterCds.Append;
      LMasterCds.FieldByName(cKEY).AsInteger := cROOTOLD;
      LMasterCds.FieldByName(cTAG).AsString := 'R1';
      LMasterCds.Post;
      for LFor := 0 to cCHILDROWS - 1 do
      begin
        LChildCds.Append;
        LChildCds.FieldByName(cOWNKEY).AsInteger := 0;
        LChildCds.FieldByName(cKEY).AsInteger := cROOTOLD;
        LChildCds.FieldByName(cTAG).AsString := 'A' + IntToStr(LFor);
        LChildCds.Post;
      end;
      LMasterCds.Append;
      LMasterCds.FieldByName(cKEY).AsInteger := cROOTOLD;
      LMasterCds.FieldByName(cTAG).AsString := 'R2';
      LMasterCds.Post;
      for LFor := 0 to cCHILDROWS - 1 do
      begin
        LChildCds.Append;
        LChildCds.FieldByName(cOWNKEY).AsInteger := 0;
        LChildCds.FieldByName(cKEY).AsInteger := cROOTOLD;
        LChildCds.FieldByName(cTAG).AsString := 'B' + IntToStr(LFor);
        LChildCds.Post;
      end;
      Assert.AreEqual(cCHILDROWS * 2, RowCount(LChildCds),
        'PREMISE: this family must hold the children of BOTH masters at once');

      TCascadeAccess<TAitRoot>.ApplyAll(LMaster);

      LKeyA := KeyOfMasterRow(LMasterCds, False);
      LKeyB := KeyOfMasterRow(LMasterCds, True);
      Assert.IsTrue(LKeyA > 0,
        'PREMISE: the first master must have received a key from the server ' +
        'answer');
      Assert.AreNotEqual(LKeyA, LKeyB,
        'PREMISE: the two masters must carry DIFFERENT keys');

      Assert.AreEqual(cCHILDROWS, CountWithColumn(LChildCds, cKEY, LKeyA),
        'the children of the FIRST master must stay on its key - ' +
        DumpColumn(LChildCds, cKEY));
      Assert.AreEqual(cCHILDROWS, CountWithColumn(LChildCds, cKEY, LKeyB),
        'and the children of the SECOND on its own - ' +
        DumpColumn(LChildCds, cKEY));
    finally
      LChild.Free;
      LMaster.Free;
    end;
  finally
    LChildCds.Free;
    LMasterCds.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Level 3 - the recursion into the children of a child
// ---------------------------------------------------------------------------

procedure TTestAutoIncDistribution.Recursion_LeavesTypedUnderTheMiddleMidRow_CarryThatMidRowKey;
var
  LRootTable: TFDMemTable;
  LMidTable: TFDMemTable;
  LLeafTable: TFDMemTable;
  LRoot: TFDMemTableAdapter<TAitRoot>;
  LMid: TFDMemTableAdapter<TAitMid>;
  LLeaf: TFDMemTableAdapter<TAitLeaf>;
  LFor: Integer;
begin
  // THREE hypotheses, THREE different numbers, so this run tells them apart:
  //   91 - the recursion rides whichever mid row the cursor ended on, which
  //        _AutoIncToChildRows' own `finally` pins to the FIRST one;
  //   93 - a last-writer-wins walk over the mid rows;
  //   92 - the leaves reach the mid row they were actually typed under.
  // Nothing is muted: the mid cursor is moved to the middle row while the leaf
  // table is still empty, so the re-open that scroll fires discards nothing.
  LRootTable := TFDMemTable.Create(nil);
  LMidTable := TFDMemTable.Create(nil);
  LLeafTable := TFDMemTable.Create(nil);
  try
    LRoot := TFDMemTableAdapter<TAitRoot>.Create(FConn, LRootTable, -1, nil);
    LMid := TFDMemTableAdapter<TAitMid>.Create(FConn, LMidTable, -1, LRoot);
    LLeaf := TFDMemTableAdapter<TAitLeaf>.Create(FConn, LLeafTable, -1, LMid);
    try
      LRootTable.Append;
      LRootTable.FieldByName(cKEY).AsInteger := cROOTOLD;
      LRootTable.FieldByName(cTAG).AsString := 'ROOT';
      LRootTable.Post;
      for LFor := 0 to cMIDROWS - 1 do
      begin
        LMidTable.Append;
        LMidTable.FieldByName(cKEY).AsInteger := cROOTOLD;
        LMidTable.FieldByName(cOWNKEY).AsInteger := cMIDFIRST + LFor;
        LMidTable.FieldByName(cTAG).AsString := 'M' + IntToStr(LFor);
        LMidTable.Post;
      end;
      // To the MIDDLE mid row, leaf table still empty.
      LMidTable.First;
      LMidTable.Next;
      Assert.AreEqual(cMIDMIDDLE, LMidTable.FieldByName(cOWNKEY).AsInteger,
        'PREMISE: the fixture must really be parked on the middle mid row, ' +
        'otherwise the three hypotheses above are not three numbers');
      for LFor := 0 to 1 do
      begin
        LLeafTable.Append;
        LLeafTable.FieldByName(cKEY).AsInteger := cROOTOLD;
        LLeafTable.FieldByName(cOWNKEY).AsInteger := cLEAFSTART;
        LLeafTable.FieldByName(cTAG).AsString := 'L' + IntToStr(LFor);
        LLeafTable.Post;
      end;
      Assert.AreEqual(2, RowCount(LLeafTable),
        'PREMISE: both leaves must still be there when the cascade runs');
      Assert.AreEqual(cMIDROWS, RowCount(LMidTable),
        'PREMISE: and all three mid rows as well');

      // The state ApplyInserter leaves the master in: dsEdit, carrying the key
      // the database has just generated, not yet posted.
      LRootTable.Edit;
      LRootTable.FieldByName(cKEY).AsInteger := cROOTNEW;

      TCascadeAccess<TAitRoot>.Propagate(LRoot);

      Assert.AreEqual(2, CountWithColumn(LLeafTable, cOWNKEY, cMIDMIDDLE),
        'both leaves were typed under the MIDDLE mid row and must carry its ' +
        'key - ' + DumpColumn(LLeafTable, cOWNKEY));
      Assert.AreEqual(0, CountWithColumn(LLeafTable, cOWNKEY, cMIDFIRST),
        'none may come out on the FIRST mid row - that is the row the ' +
        'recursion lands on when it rides the cursor instead of the ' +
        'parentage - ' + DumpColumn(LLeafTable, cOWNKEY));
      Assert.AreEqual(0, CountWithColumn(LLeafTable, cOWNKEY, cMIDLAST),
        'and none on the LAST - that is what a last-writer-wins walk over ' +
        'the mid rows would produce - ' + DumpColumn(LLeafTable, cOWNKEY));
      Assert.AreEqual(0, CountWithColumn(LLeafTable, cOWNKEY, cLEAFSTART),
        'and no leaf may be left untouched, which is the other way a walk ' +
        'that reaches nobody can look right - ' +
        DumpColumn(LLeafTable, cOWNKEY));
      Assert.AreEqual(cMIDROWS, CountWithColumn(LMidTable, cKEY, cROOTNEW),
        'level 2 must still be updated in full - all three mid rows belong ' +
        'to the one root row, so all three take the new root key');
    finally
      LLeaf.Free;
      LMid.Free;
      LRoot.Free;
    end;
  finally
    LLeafTable.Free;
    LMidTable.Free;
    LRootTable.Free;
  end;
end;

procedure TTestAutoIncDistribution.Recursion_WithNoPendingChildRow_StillReachesTheGrandchildren;
var
  LRootTable: TFDMemTable;
  LMidTable: TFDMemTable;
  LLeafTable: TFDMemTable;
  LRoot: TFDMemTableAdapter<TAitRoot>;
  LMid: TFDMemTableAdapter<TAitMid>;
  LLeaf: TFDMemTableAdapter<TAitLeaf>;
  LSaved: TDataSetNotifyEvent;
  LFor: Integer;
begin
  // WHAT THIS HOLDS IN PLACE. _RecurseOverChildRows walks the child's PENDING
  // rows and fires the next level once per row - but a child that has no
  // pending row at all still has to reach its own children, because a mid row
  // that is already saved has a key and the leaves typed under it never
  // received it: TDataSetBaseAdapter<M>.DoNewRecord only calls
  // _GetMasterValues when the level has children of its own, and the leaf
  // level does not. So the walk falls back to ONE recursion from wherever the
  // cursor is, which is exactly what the code did before the walk existed.
  // Drop that fallback and this test is the only thing that notices.
  LRootTable := TFDMemTable.Create(nil);
  LMidTable := TFDMemTable.Create(nil);
  LLeafTable := TFDMemTable.Create(nil);
  try
    LRoot := TFDMemTableAdapter<TAitRoot>.Create(FConn, LRootTable, -1, nil);
    LMid := TFDMemTableAdapter<TAitMid>.Create(FConn, LMidTable, -1, LRoot);
    LLeaf := TFDMemTableAdapter<TAitLeaf>.Create(FConn, LLeafTable, -1, LMid);
    try
      LRootTable.Append;
      LRootTable.FieldByName(cKEY).AsInteger := cROOTOLD;
      LRootTable.FieldByName(cTAG).AsString := 'ROOT';
      LRootTable.Post;
      LMidTable.Append;
      LMidTable.FieldByName(cKEY).AsInteger := cROOTOLD;
      LMidTable.FieldByName(cOWNKEY).AsInteger := cMIDFIRST;
      LMidTable.FieldByName(cTAG).AsString := 'M0';
      LMidTable.Post;
      // ALREADY SAVED - the marker ApplyInserter writes back once a row has
      // reached the database. Only this one write is muted, because the
      // adapter's own BeforePost would flip the marker straight back.
      LSaved := LMidTable.BeforePost;
      LMidTable.BeforePost := nil;
      try
        LMidTable.Edit;
        LMidTable.FieldByName(cInternalField).AsInteger := -1;
        LMidTable.Post;
      finally
        LMidTable.BeforePost := LSaved;
      end;
      for LFor := 0 to 1 do
      begin
        LLeafTable.Append;
        LLeafTable.FieldByName(cKEY).AsInteger := cROOTOLD;
        LLeafTable.FieldByName(cOWNKEY).AsInteger := cLEAFSTART;
        LLeafTable.FieldByName(cTAG).AsString := 'L' + IntToStr(LFor);
        LLeafTable.Post;
      end;
      Assert.AreEqual(0,
        CountWithColumn(LMidTable, cInternalField, Integer(dsInsert)),
        'PREMISE: no mid row may be pending - if one is, this test measures ' +
        'the walk instead of the fallback');
      Assert.AreEqual(2, RowCount(LLeafTable),
        'PREMISE: both leaves must be there');

      LRootTable.Edit;
      LRootTable.FieldByName(cKEY).AsInteger := cROOTNEW;

      TCascadeAccess<TAitRoot>.Propagate(LRoot);

      Assert.AreEqual(2, CountWithColumn(LLeafTable, cOWNKEY, cMIDFIRST),
        'the leaves must still receive the key of the mid row they belong ' +
        'to, even though that row had nothing to iterate - ' +
        DumpColumn(LLeafTable, cOWNKEY));
    finally
      LLeaf.Free;
      LMid.Free;
      LRoot.Free;
    end;
  finally
    LLeafTable.Free;
    LMidTable.Free;
    LRootTable.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Issue #265 - the master that came out of the store
// ---------------------------------------------------------------------------

/// Builds a tree, appends ONE master with the master adapter MUTED - so
/// DoNewRecord never runs on it and it records no identity - then types a child
/// with the CHILD adapter live, and hands back what the child recorded as its
/// parentage. ARealKey chooses the ONLY thing that differs between the two arms
/// of the #265 fork: a key the store would have sent, or the autoinc
/// placeholder plus the pending marker.
function TTestAutoIncDistribution.OwnerTokenOfAChildUnderAMutedMaster(
  const ARealKey: Boolean): Integer;
var
  LRootTable: TFDMemTable;
  LMidTable: TFDMemTable;
  LLeafTable: TFDMemTable;
  LRoot: TFDMemTableAdapter<TAitRoot>;
  LMid: TFDMemTableAdapter<TAitMid>;
  LLeaf: TFDMemTableAdapter<TAitLeaf>;
begin
  BuildTree(FConn, LRootTable, LMidTable, LLeafTable, LRoot, LMid, LLeaf);
  try
    TCascadeAccess<TAitRoot>.Mute(LRoot);
    try
      LRootTable.Append;
      if ARealKey then
        LRootTable.FieldByName(cKEY).AsInteger := cLOADEDKEY;
      LRootTable.FieldByName(cTAG).AsString := cLOADEDTAG;
      LRootTable.Post;
      if not ARealKey then
      begin
        LRootTable.Edit;
        LRootTable.FieldByName(cInternalField).AsInteger := Integer(dsInsert);
        LRootTable.Post;
      end;
    finally
      TCascadeAccess<TAitRoot>.Unmute(LRoot);
    end;
    LMidTable.Append;
    LMidTable.FieldByName(cOWNKEY).AsInteger := 0;
    LMidTable.FieldByName(cTAG).AsString := 'C0';
    LMidTable.Post;
    Result := TokenOfTaggedRow(LMidTable, 'C0', cOWNERTOKEN);
  finally
    DropTree(LRootTable, LMidTable, LLeafTable, LRoot, LMid, LLeaf);
  end;
end;

/// The CONTROL. Nothing muted anywhere: the master identifies itself, so the
/// child must record THAT identity and not the orphan value. Without it a
/// framework that wrote the sentinel unconditionally would look right.
function TTestAutoIncDistribution.OwnerTokenOfAChildUnderALiveMaster: Integer;
var
  LRootTable: TFDMemTable;
  LMidTable: TFDMemTable;
  LLeafTable: TFDMemTable;
  LRoot: TFDMemTableAdapter<TAitRoot>;
  LMid: TFDMemTableAdapter<TAitMid>;
  LLeaf: TFDMemTableAdapter<TAitLeaf>;
begin
  BuildTree(FConn, LRootTable, LMidTable, LLeafTable, LRoot, LMid, LLeaf);
  try
    LRootTable.Append;
    LRootTable.FieldByName(cKEY).AsInteger := cROOTOLD;
    LRootTable.FieldByName(cTAG).AsString := cNEWTAG;
    LRootTable.Post;
    LMidTable.Append;
    LMidTable.FieldByName(cOWNKEY).AsInteger := 0;
    LMidTable.FieldByName(cTAG).AsString := 'C0';
    LMidTable.Post;
    Result := TokenOfTaggedRow(LMidTable, 'C0', cOWNERTOKEN);
  finally
    DropTree(LRootTable, LMidTable, LLeafTable, LRoot, LMid, LLeaf);
  end;
end;

procedure TTestAutoIncDistribution.ChildTypedUnderAnUnidentifiedMaster_MakesThatMasterIdentifyItself;
var
  LMutedRealKey: Integer;
  LMutedPlaceholder: Integer;
  LLiveMaster: Integer;
  LDump: String;
begin
  // THIS TEST OWNS THE MECHANISM, and it is separate from the cascade tests on
  // purpose. Those measure where a CHILD KEY ends up and have to be able to
  // reach their result clause against the untouched framework; a clause about
  // a value only the fix produces would stop them on a premise and hide it.
  // Here the value IS the subject.
  //
  // WHAT IT MEASURED AGAINST THE UNTOUCHED FRAMEWORK: 0, 0, and a positive
  // identity. A master with no identity of its own left the child with none
  // either, and "none" is the value _IsOwnedByMasterRow waves through for
  // everybody - so the child belonged to whoever asked. The fix is that asking
  // the question CREATES the answer: the master row acquires an identity at
  // that instant and the child names it.
  //
  // THE THREE ARMS ARE READ BEFORE ANY OF THEM IS ASSERTED, so one run reports
  // all three numbers even though DUnitX stops at the first failing clause.
  LMutedRealKey := OwnerTokenOfAChildUnderAMutedMaster(True);
  LMutedPlaceholder := OwnerTokenOfAChildUnderAMutedMaster(False);
  LLiveMaster := OwnerTokenOfAChildUnderALiveMaster;
  LDump := ' - measured: [muted master, real key=' + IntToStr(LMutedRealKey) +
           '] [muted master, placeholder=' + IntToStr(LMutedPlaceholder) +
           '] [live master=' + IntToStr(LLiveMaster) + ']';

  Assert.IsTrue(LMutedRealKey > cNOTOKEN,
    'a child typed under a master that recorded NO identity must still come ' +
    'out naming a CONCRETE parent: the master row acquires one at that ' +
    'instant. Against the untouched framework this read 0, which is the ' +
    'value every master accepts, and that is issue #265' + LDump);
  Assert.IsTrue(LMutedPlaceholder > cNOTOKEN,
    'and the same when that master key is still the autoinc placeholder - ' +
    'the identity is minted from the ROW, so what the key happens to hold ' +
    'does not enter into it' + LDump);
  Assert.IsTrue(LLiveMaster > cNOTOKEN,
    'THE CONTROL: a master that identified itself on its own was already ' +
    'right, and must stay right' + LDump);
  Assert.AreNotEqual(LMutedRealKey, LMutedPlaceholder,
    'and the three identities must be DISTINCT. They are minted from one ' +
    'monotonic counter, so a fix that handed out a single shared value would ' +
    'satisfy the three clauses above and still let any untokenised master ' +
    'claim any untokenised master child' + LDump);
  Assert.AreNotEqual(LMutedPlaceholder, LLiveMaster,
    'and the third differs from the second for the same reason' + LDump);
end;

procedure TTestAutoIncDistribution.TwoUnidentifiedPendingMasters_ChildOfTheFirstIsNotClaimedByTheSecond;
var
  LRootTable: TFDMemTable;
  LMidTable: TFDMemTable;
  LLeafTable: TFDMemTable;
  LRoot: TFDMemTableAdapter<TAitRoot>;
  LMid: TFDMemTableAdapter<TAitMid>;
  LLeaf: TFDMemTableAdapter<TAitLeaf>;
  LKeyA: Integer;
  LKeyB: Integer;
begin
  // THE ORPHAN-TO-ORPHAN CROSS CLAIM. Both masters are muted-appended, so
  // NEITHER records an identity, and the child is typed with its own events
  // live under the FIRST of them. Typed under the FIRST on purpose: with the
  // last one, "the child stayed where it was typed" and "the last pending
  // master won" are the same number and the run tells them apart from nothing.
  //
  // That is what makes this the complement of Test.Janus.AutoInc.Childs
  // .TwoPendingMasterRows_WithNoRecordedParentage_EveryPendingChildEndsOnTheLastMasterKey
  // rather than a contradiction of it: there the children are typed under the
  // LAST master, so both readings agree and that test stays green either way.
  BuildTree(FConn, LRootTable, LMidTable, LLeafTable, LRoot, LMid, LLeaf);
  try
    TCascadeAccess<TAitRoot>.Mute(LRoot);
    try
      LRootTable.Append;
      LRootTable.FieldByName(cTAG).AsString := cLOADEDTAG;
      LRootTable.Post;
      LRootTable.Edit;
      LRootTable.FieldByName(cInternalField).AsInteger := Integer(dsInsert);
      LRootTable.Post;
      LRootTable.Append;
      LRootTable.FieldByName(cTAG).AsString := cNEWTAG;
      LRootTable.Post;
      LRootTable.Edit;
      LRootTable.FieldByName(cInternalField).AsInteger := Integer(dsInsert);
      LRootTable.Post;
    finally
      TCascadeAccess<TAitRoot>.Unmute(LRoot);
    end;
    Assert.AreEqual(2,
      CountWithColumn(LRootTable, cInternalField, Integer(dsInsert)),
      'PREMISE: BOTH masters must be pending, or only one of them ever walks ' +
      'ApplyInserter and there is no second claimant');

    LRootTable.First;
    LMidTable.Append;
    LMidTable.FieldByName(cOWNKEY).AsInteger := 0;
    LMidTable.FieldByName(cTAG).AsString := 'C0';
    LMidTable.Post;

    TCascadeAccess<TAitRoot>.ApplyAll(LRoot);

    LKeyA := KeyOfTaggedRow(LRootTable, cLOADEDTAG);
    LKeyB := KeyOfTaggedRow(LRootTable, cNEWTAG);
    Assert.IsTrue(LKeyA > 0,
      'PREMISE: the first master must have received a generated key');
    Assert.AreNotEqual(LKeyA, LKeyB,
      'PREMISE: the two masters must carry DIFFERENT keys, or this test ' +
      'cannot tell which one the child ended on');
    Assert.AreEqual(1, CountWithColumn(LMidTable, cKEY, LKeyA),
      'the child was typed under the FIRST master and must come out on its ' +
      'key - ' + DumpColumn(LMidTable, cKEY));
    Assert.AreEqual(0, CountWithColumn(LMidTable, cKEY, LKeyB),
      'and must not be claimed by the SECOND. Both masters are untokenised, ' +
      'so a parentage rule phrased as "any master with no identity may claim ' +
      'an orphaned child" lets this happen - ' + DumpColumn(LMidTable, cKEY));
  finally
    DropTree(LRootTable, LMidTable, LLeafTable, LRoot, LMid, LLeaf);
  end;
end;

procedure TTestAutoIncDistribution.ChildTypedBeforeItsMasterRowIsPosted_StillReceivesTheKey;
var
  LRootTable: TFDMemTable;
  LMidTable: TFDMemTable;
  LLeafTable: TFDMemTable;
  LRoot: TFDMemTableAdapter<TAitRoot>;
  LMid: TFDMemTableAdapter<TAitMid>;
  LLeaf: TFDMemTableAdapter<TAitLeaf>;
  LKey: Integer;
begin
  // NOTHING IS MUTED HERE AT ALL, and that is the point. The master adapter is
  // live, so DoNewRecord ran on the master row and stamped it - the row simply
  // has not been POSTED yet, which is what a master-detail form looks like
  // while the operator fills the header and starts adding items before
  // committing the header.
  //
  // WHAT IT GUARDS. _MasterRowToken answers cNoRowToken for FOUR different
  // reasons - no dataset, closed, IsEmpty, no column - and a dataset sitting on
  // its FIRST unposted insert answers IsEmpty. Promoting every one of those
  // zeros to the orphan sentinel would make this child unclaimable by the very
  // master it was typed under, which on origin/develop received the key
  // normally.
  BuildTree(FConn, LRootTable, LMidTable, LLeafTable, LRoot, LMid, LLeaf);
  try
    LRootTable.Append;
    LRootTable.FieldByName(cKEY).AsInteger := cROOTOLD;
    LRootTable.FieldByName(cTAG).AsString := cNEWTAG;
    // NOT posted.
    Assert.IsTrue(LRootTable.State = dsInsert,
      'PREMISE: the master row must still be an uncommitted insert when the ' +
      'child is typed, or this test measures the ordinary path');

    LMidTable.Append;
    LMidTable.FieldByName(cOWNKEY).AsInteger := 0;
    LMidTable.FieldByName(cTAG).AsString := 'C0';
    LMidTable.Post;

    LRootTable.Post;
    Assert.AreEqual(1, RowCount(LMidTable),
      'PREMISE: the child must have survived the master Post - if the master ' +
      'AfterPost re-opened the children this test measures nothing');

    TCascadeAccess<TAitRoot>.ApplyAll(LRoot);

    LKey := KeyOfTaggedRow(LRootTable, cNEWTAG);
    Assert.IsTrue(LKey > 0,
      'PREMISE: the master must have received a generated key');
    Assert.AreEqual(1, CountWithColumn(LMidTable, cKEY, LKey),
      'the child must receive the key of the master it was typed under, ' +
      'exactly as it did before issue #265 - ' + DumpColumn(LMidTable, cKEY));
  finally
    DropTree(LRootTable, LMidTable, LLeafTable, LRoot, LMid, LLeaf);
  end;
end;

procedure TTestAutoIncDistribution.ChildTypedWhileTheMasterRowIsBeingEdited_DoesNotCommitThatEdit;
var
  LRootTable: TFDMemTable;
  LMidTable: TFDMemTable;
  LLeafTable: TFDMemTable;
  LRoot: TFDMemTableAdapter<TAitRoot>;
  LMid: TFDMemTableAdapter<TAitMid>;
  LLeaf: TFDMemTableAdapter<TAitLeaf>;
  LStore: TStoreConnection;
  LConn: IDBConnection;
begin
  // THE PRICE OF MINTING AN IDENTITY ON SOMEBODY ELSE ROW, measured rather than
  // argued. _EnsureMasterRowToken has to write a column on the MASTER row while
  // the operator is typing a CHILD, and the master row may well be in the
  // middle of an edit the operator has not finished. Committing it for them -
  // an unconditional Post - would take a half-typed header to the database on
  // the next ApplyUpdates and put the row back in browse under a form that
  // still thinks it is editing.
  //
  // So the Edit/Post pair fires ONLY from dsBrowse. This test is the only thing
  // that says so: make the Post unconditional and it is the single red.
  //
  // The master is LOADED, so it arrives in browse with no identity - the exact
  // state that forces the mint - and then put into dsEdit by hand, which is
  // what a bound control does on the first keystroke.
  LStore := TStoreConnection.CreateStore(cSTEP, cLOADEDKEY);
  LConn := LStore;
  BuildTree(LConn, LRootTable, LMidTable, LLeafTable, LRoot, LMid, LLeaf);
  try
    LRoot.OpenSQLInternal(cLOADSQL);
    Assert.AreEqual(1, LStore.LoadCalls,
      'PREMISE: the load must really have happened');
    Assert.AreEqual(cNOTOKEN, TokenOfTaggedRow(LRootTable, cLOADEDTAG,
                                               cROWTOKEN),
      'PREMISE: and the loaded master must have no identity, or nothing is ' +
      'minted here and this test measures the wrong branch');

    LRootTable.Edit;
    LRootTable.FieldByName(cTAG).AsString := cEDITEDTAG;
    Assert.IsTrue(LRootTable.State = dsEdit,
      'PREMISE: the master must be in dsEdit when the child is typed');

    LMidTable.Append;
    LMidTable.FieldByName(cOWNKEY).AsInteger := 0;
    LMidTable.FieldByName(cTAG).AsString := 'C0';
    LMidTable.Post;

    Assert.IsTrue(LRootTable.State = dsEdit,
      'the master must STILL be in dsEdit. Minting an identity on its row may ' +
      'not commit an edit the operator has not finished - the value rides ' +
      'along in the current buffer and goes out with THEIR Post');
    Assert.AreEqual(cEDITEDTAG, LRootTable.FieldByName(cTAG).AsString,
      'and the value they were typing must still be in the buffer, ' +
      'untouched');
    Assert.IsTrue(TokenOfTaggedRow(LMidTable, 'C0', cOWNERTOKEN) > cNOTOKEN,
      'while the child still comes out naming a concrete parent - the ' +
      'identity is written into the open buffer, so refusing to Post costs ' +
      'nothing');
  finally
    DropTree(LRootTable, LMidTable, LLeafTable, LRoot, LMid, LLeaf);
  end;
end;

procedure TTestAutoIncDistribution.LoadedMaster_ChildTypedUnderIt_KeepsTheLoadedMastersKey;
var
  LRootTable: TFDMemTable;
  LMidTable: TFDMemTable;
  LLeafTable: TFDMemTable;
  LRoot: TFDMemTableAdapter<TAitRoot>;
  LMid: TFDMemTableAdapter<TAitMid>;
  LLeaf: TFDMemTableAdapter<TAitLeaf>;
  LStore: TStoreConnection;
  LConn: IDBConnection;
  LNewKey: Integer;
begin
  // THE DOMINANT SHAPE, and NOTHING IS MUTED BY THIS TEST. The master row is
  // put on the table by the SHIPPED LOAD - TFDMemTableAdapter<M>.OpenSQLInternal
  // -> TSessionDataSet<M>.OpenSQL -> _PopularDataSet - which mutes the adapter
  // events itself, on its own second line. That is the whole point: the muting
  // is the framework, not the fixture, so what is measured is a state a
  // consumer reaches by listing rows and typing under one of them.
  //
  // ORDERING. The second master goes in while the child table is still empty,
  // then the cursor goes back to the LOADED master, and only then is the child
  // typed - see the unit header. TDataSetAdapter<M>.DoNewRecord empties the
  // children before it does anything else, so the other order loses them.
  LStore := TStoreConnection.CreateStore(cSTEP, cLOADEDKEY);
  LConn := LStore;
  BuildTree(LConn, LRootTable, LMidTable, LLeafTable, LRoot, LMid, LLeaf);
  try
    LRoot.OpenSQLInternal(cLOADSQL);

    Assert.AreEqual(1, LStore.LoadCalls,
      'PREMISE: the nominated SELECT must really have been answered - zero ' +
      'means the fixture never went through the load path and everything ' +
      'below is vacuous');
    Assert.AreEqual(1, RowCount(LRootTable),
      'PREMISE: the load must have put exactly one master row on the table');
    Assert.AreEqual(cLOADEDKEY, KeyOfTaggedRow(LRootTable, cLOADEDTAG),
      'PREMISE: and that row must carry the REAL key the store sent, not a ' +
      'placeholder - ' + DumpColumn(LRootTable, cKEY));
    Assert.AreEqual(0,
      CountWithColumn(LRootTable, cInternalField, Integer(dsInsert)),
      'PREMISE: a row read from the store is NOT pending - _PopularDataSet ' +
      'writes -1 into the internal column - so ApplyInserter will never walk ' +
      'it and it will never generate a key');
    Assert.AreEqual(0, TokenOfTaggedRow(LRootTable, cLOADEDTAG, cROWTOKEN),
      'PREMISE - AND THIS IS THE DEFECT ITSELF: the loaded master carries NO ' +
      'row identity. DoNewRecord never ran because the load muted the events, ' +
      'and TBind.SetFieldToField skips the column by name, so it stays NULL ' +
      'and reads back as cNoRowToken');

    LRootTable.Append;
    LRootTable.FieldByName(cKEY).AsInteger := cROOTOLD;
    LRootTable.FieldByName(cTAG).AsString := cNEWTAG;
    LRootTable.Post;
    Assert.AreNotEqual(0, TokenOfTaggedRow(LRootTable, cNEWTAG, cROWTOKEN),
      'PREMISE: the master appended with the events LIVE must identify ' +
      'itself - otherwise the two masters are indistinguishable and this test ' +
      'measures nothing');

    // Back to the LOADED master, child table still empty.
    LRootTable.First;
    Assert.AreEqual(cLOADEDKEY, LRootTable.FieldByName(cKEY).AsInteger,
      'PREMISE: the cursor must be back on the loaded master before the ' +
      'child is typed');

    LMidTable.Append;
    LMidTable.FieldByName(cOWNKEY).AsInteger := 0;
    LMidTable.FieldByName(cTAG).AsString := 'C0';
    LMidTable.Post;

    Assert.AreEqual(1, CountWithColumn(LMidTable, cKEY, cLOADEDKEY),
      'PREMISE: the SHIPPED _GetMasterValues must have written the loaded ' +
      'master REAL key into the child foreign key at creation time - nothing ' +
      'in this test types it - ' + DumpColumn(LMidTable, cKEY));
    Assert.AreEqual(-1,
      TokenOfTaggedRow(LRootTable, cLOADEDTAG, cInternalField),
      'AND THE LOADED MASTER ROW MUST STILL NOT BE PENDING - read on THAT ' +
      'row by tag, not counted over the table, because the other master is ' +
      'legitimately pending and a count cannot tell them apart. ' +
      '_EnsureMasterRowToken ' +
      'wrote a column on that row to give it an identity, and it did so with ' +
      'the master adapter MUTED precisely so DoBeforePost could not promote ' +
      'the row to dsEdit. Let that promotion through and a row nobody touched ' +
      'becomes a phantom UPDATE against the database');
    Assert.AreEqual(cLOADEDKEY, KeyOfTaggedRow(LRootTable, cLOADEDTAG),
      'and its key must be untouched by that write - ' +
      DumpColumn(LRootTable, cKEY));
    // WHAT THIS TEST DELIBERATELY DOES NOT ASSERT: the VALUE the child now
    // records for that master. That is a clause about the fix, not about the
    // defect, and putting it here would make this test stop on a premise
    // against the untouched framework - hiding the RESULT it exists to
    // measure, which is the whole red-first claim. It is owned by
    // ChildTypedUnderAnUnidentifiedMaster_MakesThatMasterIdentifyItself.

    TCascadeAccess<TAitRoot>.ApplyAll(LRoot);

    LNewKey := KeyOfTaggedRow(LRootTable, cNEWTAG);
    Assert.IsTrue(LNewKey > 0,
      'PREMISE: the pending master must have received a generated key, or ' +
      'the cascade had nothing to propagate');
    Assert.AreNotEqual(cLOADEDKEY, LNewKey,
      'PREMISE: the two masters must carry DIFFERENT keys, or this test ' +
      'cannot tell which one the child ended on');

    Assert.AreEqual(1, CountWithColumn(LMidTable, cKEY, cLOADEDKEY),
      'the child was typed under the master that came from the STORE and ' +
      'must still carry that master key - ' + DumpColumn(LMidTable, cKEY));
    Assert.AreEqual(0, CountWithColumn(LMidTable, cKEY, LNewKey),
      'and must NOT have been re-parented onto the brand new master, which ' +
      'is what a parentage check that waves through every untokenised child ' +
      'produces - ' + DumpColumn(LMidTable, cKEY));
  finally
    DropTree(LRootTable, LMidTable, LLeafTable, LRoot, LMid, LLeaf);
  end;
end;

procedure TTestAutoIncDistribution.MutedMasterAppend_WithARealKey_ItsChildKeepsThatKey;
var
  LRootTable: TFDMemTable;
  LMidTable: TFDMemTable;
  LLeafTable: TFDMemTable;
  LRoot: TFDMemTableAdapter<TAitRoot>;
  LMid: TFDMemTableAdapter<TAitMid>;
  LLeaf: TFDMemTableAdapter<TAitLeaf>;
  LNewKey: Integer;
begin
  // FIXTURE B1 - the FIRST arm of the fork nothing in this suite told apart.
  // Same untokenised master as the test above, reached by MUTING the adapter by
  // hand instead of by loading, and with the key set to a REAL one and the row
  // left NOT PENDING - which is precisely the state _PopularDataSet leaves a
  // loaded row in, as the test above measures. Written separately because the
  // fork the sentinel decision turns on is "was the muted master key real or a
  // placeholder", and that question has to be asked WITHOUT the load machinery
  // in the way.
  BuildTree(FConn, LRootTable, LMidTable, LLeafTable, LRoot, LMid, LLeaf);
  try
    TCascadeAccess<TAitRoot>.Mute(LRoot);
    try
      LRootTable.Append;
      LRootTable.FieldByName(cKEY).AsInteger := cLOADEDKEY;
      LRootTable.FieldByName(cTAG).AsString := cLOADEDTAG;
      LRootTable.Post;
    finally
      TCascadeAccess<TAitRoot>.Unmute(LRoot);
    end;
    Assert.AreEqual(0, TokenOfTaggedRow(LRootTable, cLOADEDTAG, cROWTOKEN),
      'PREMISE: the muted append must have left the master with NO identity');
    Assert.AreEqual(0,
      CountWithColumn(LRootTable, cInternalField, Integer(dsInsert)),
      'PREMISE: and NOT pending - the muted append never reached ' +
      'DoBeforePost, so the internal column kept its -1 default, exactly ' +
      'like a loaded row');

    LRootTable.Append;
    LRootTable.FieldByName(cKEY).AsInteger := cROOTOLD;
    LRootTable.FieldByName(cTAG).AsString := cNEWTAG;
    LRootTable.Post;
    LRootTable.First;

    LMidTable.Append;
    LMidTable.FieldByName(cOWNKEY).AsInteger := 0;
    LMidTable.FieldByName(cTAG).AsString := 'C0';
    LMidTable.Post;
    Assert.AreEqual(1, CountWithColumn(LMidTable, cKEY, cLOADEDKEY),
      'PREMISE: the shipped _GetMasterValues must have copied the master ' +
      'REAL key into the child at creation time - ' +
      DumpColumn(LMidTable, cKEY));
    // The value the child records is asserted by
    // ChildTypedUnderAnUnidentifiedMaster_MakesThatMasterIdentifyItself and not here, for
    // the reason given in the test above.

    TCascadeAccess<TAitRoot>.ApplyAll(LRoot);

    LNewKey := KeyOfTaggedRow(LRootTable, cNEWTAG);
    Assert.IsTrue(LNewKey > 0,
      'PREMISE: the pending master must have received a generated key');
    Assert.AreEqual(1, CountWithColumn(LMidTable, cKEY, cLOADEDKEY),
      'THE FORK, ARM ONE: the master key was already REAL and the child ' +
      'already carries it, so there is nothing for any cascade to repair - ' +
      'the child must keep it - ' + DumpColumn(LMidTable, cKEY));
    Assert.AreEqual(0, CountWithColumn(LMidTable, cKEY, LNewKey),
      'and must not be claimed by the other, pending master - ' +
      DumpColumn(LMidTable, cKEY));
  finally
    DropTree(LRootTable, LMidTable, LLeafTable, LRoot, LMid, LLeaf);
  end;
end;

procedure TTestAutoIncDistribution.MutedMasterAppend_WithThePendingPlaceholder_ItsChildIsRepaired;
var
  LRootTable: TFDMemTable;
  LMidTable: TFDMemTable;
  LLeafTable: TFDMemTable;
  LRoot: TFDMemTableAdapter<TAitRoot>;
  LMid: TFDMemTableAdapter<TAitMid>;
  LLeaf: TFDMemTableAdapter<TAitLeaf>;
  LKey: Integer;
begin
  // FIXTURE B2 - the SECOND arm, and the one that says what the fix may NOT do.
  // The master is muted-appended too, so it has no identity either - but its
  // key is still the PENDING PLACEHOLDER that
  // TBind.SetInternalInitFieldDefsObjectClass puts in an autoinc primary key as
  // DefaultExpression, and the row IS pending, so ApplyInserter walks it and
  // generates a real key. The child was typed under it with the events LIVE, so
  // it carries the placeholder in its foreign key and must be REPAIRED by the
  // cascade.
  //
  // ONE MASTER, not two, and that is the difference from B1 rather than an
  // omission: the question here is whether a master REPAIRS ITS OWN child, and
  // a second pending master would only re-ask B1.
  //
  // The pending marker is written BY HAND, with the adapter still muted, for
  // the same reason UntokenisedRows_KeepTheHistoricalBehaviour writes it: the
  // muted append never reaches DoBeforePost. That is the one thing forged here,
  // and it is forged on the MASTER, never on the child.
  BuildTree(FConn, LRootTable, LMidTable, LLeafTable, LRoot, LMid, LLeaf);
  try
    TCascadeAccess<TAitRoot>.Mute(LRoot);
    try
      LRootTable.Append;
      LRootTable.FieldByName(cTAG).AsString := cLOADEDTAG;
      LRootTable.Post;
      LRootTable.Edit;
      LRootTable.FieldByName(cInternalField).AsInteger := Integer(dsInsert);
      LRootTable.Post;
    finally
      TCascadeAccess<TAitRoot>.Unmute(LRoot);
    end;
    Assert.AreEqual(cPLACEHOLDER, KeyOfTaggedRow(LRootTable, cLOADEDTAG),
      'PREMISE: the master key must still be the autoinc PLACEHOLDER - this ' +
      'test is the arm of the fork where there IS something to repair - ' +
      DumpColumn(LRootTable, cKEY));
    Assert.AreEqual(0, TokenOfTaggedRow(LRootTable, cLOADEDTAG, cROWTOKEN),
      'PREMISE: and the master must have NO identity, same as in B1 - the ' +
      'key is the only thing that differs between the two arms');
    Assert.AreEqual(1,
      CountWithColumn(LRootTable, cInternalField, Integer(dsInsert)),
      'PREMISE: the master must be PENDING, or ApplyInserter never walks it ' +
      'and no key is ever generated to repair anything with');

    LMidTable.Append;
    LMidTable.FieldByName(cOWNKEY).AsInteger := 0;
    LMidTable.FieldByName(cTAG).AsString := 'C0';
    LMidTable.Post;
    Assert.AreEqual(cPLACEHOLDER, KeyOfTaggedRow(LMidTable, 'C0'),
      'PREMISE: the shipped _GetMasterValues copied the PLACEHOLDER into the ' +
      'child foreign key, because that is all the master had - ' +
      DumpColumn(LMidTable, cKEY));
    Assert.AreEqual(1,
      CountWithColumn(LRootTable, cInternalField, Integer(dsInsert)),
      'AND THE MASTER MUST STILL BE PENDING after the identity was minted on ' +
      'its row - the mute around that write is what keeps DoBeforePost from ' +
      'rewriting the marker, and a master that stopped being pending would ' +
      'never reach ApplyInserter and never generate the key this test needs');
    // NOT ASSERTED HERE, AND HERE IT MATTERS MOST. This test has to be GREEN
    // against the untouched framework - that is its entire evidential value -
    // so it may not carry a clause that only the fix can satisfy. That the two
    // arms of the fork record the SAME orphan value, and therefore differ only
    // in the master key, is measured by
    // ChildTypedUnderAnUnidentifiedMaster_MakesThatMasterIdentifyItself, which asserts both
    // arms in one run.

    TCascadeAccess<TAitRoot>.ApplyAll(LRoot);

    LKey := KeyOfTaggedRow(LRootTable, cLOADEDTAG);
    Assert.IsTrue(LKey > 0,
      'PREMISE: the pending master must have received a generated key');
    Assert.AreEqual(1, CountWithColumn(LMidTable, cKEY, LKey),
      'THE FORK, ARM TWO: the child was still on the placeholder and its own ' +
      'master is the one being inserted, so the cascade must REPAIR it. A ' +
      'parentage check that refuses this child leaves the placeholder ' +
      'standing, which is worse than what shipped - ' +
      DumpColumn(LMidTable, cKEY));
    Assert.AreEqual(0, CountWithColumn(LMidTable, cKEY, cPLACEHOLDER),
      'and no child row may be left on the placeholder - ' +
      DumpColumn(LMidTable, cKEY));
  finally
    DropTree(LRootTable, LMidTable, LLeafTable, LRoot, LMid, LLeaf);
  end;
end;

// ---------------------------------------------------------------------------
// The boundary of the fix
// ---------------------------------------------------------------------------

procedure TTestAutoIncDistribution.UntokenisedRows_KeepTheHistoricalBehaviour;
var
  LMasterTable: TFDMemTable;
  LChildTable: TFDMemTable;
  LMaster: TFDMemTableAdapter<TAitRoot>;
  LChild: TFDMemTableAdapter<TAitMid>;
  LInternal: TField;
  LKeyB: Integer;
begin
  // WHICH OF THE TWO UNTOKENISED CLASSES THIS PINS - rewritten for issue #265,
  // because that issue split the class this test used to name in one.
  //
  // Until #265 there was ONE untokenised state and this test was its whole
  // boundary. There are TWO now, and they are told apart by whether
  // DoNewRecord ever ran on the CHILD:
  //
  //   * NOBODY RECORDED THE ROW - cOwnerTokenField never written, reads back
  //     as the 0 a TField answers for NULL. THIS test, and only this one:
  //     BOTH adapters are muted for the whole set-up, so the child row was
  //     appended without the child adapter ever seeing it. Such a row is
  //     still written by whichever pending master is passing, last one wins,
  //     because refusing it would regress everything that shipped;
  //
  //   * THE ROW WAS RECORDED AND ITS MASTER HAD NO IDENTITY - the child
  //     adapter was LIVE and the MASTER was the muted one, which is what every
  //     master read from the store is. That row carries cOrphanOwnerToken and
  //     is NOT claimable by a different, identified master. Measured by
  //     LoadedMaster_ChildTypedUnderIt_KeepsTheLoadedMastersKey and
  //     MutedMasterAppend_WithARealKey_ItsChildKeepsThatKey, and its own
  //     boundary - the master that DOES repair its own child - by
  //     MutedMasterAppend_WithThePendingPlaceholder_ItsChildIsRepaired.
  //
  // WHAT DID NOT CHANGE. This test was GREEN before #265 and is green after,
  // unedited in its set-up and in its result. That is not luck: the sentinel
  // is written by DoNewRecord, and DoNewRecord is exactly what this set-up
  // prevents from running. The premise clause added below is what says so out
  // loud, so the day someone makes the muted append record something this test
  // reddens instead of quietly changing meaning again.
  //
  // It is still the ONLY test in this file that mutes BOTH adapters, and it
  // still writes the pending marker by hand, for the reason it always did: a
  // muted append never reaches DoBeforePost.
  LMasterTable := TFDMemTable.Create(nil);
  LChildTable := TFDMemTable.Create(nil);
  try
    LMaster := TFDMemTableAdapter<TAitRoot>.Create(FConn, LMasterTable, -1, nil);
    LChild := TFDMemTableAdapter<TAitMid>.Create(FConn, LChildTable, -1,
                LMaster);
    try
      TCascadeAccess<TAitRoot>.Mute(LMaster);
      TCascadeAccess<TAitMid>.Mute(LChild);
      try
        LMasterTable.Append;
        LMasterTable.FieldByName(cKEY).AsInteger := cROOTOLD;
        LMasterTable.FieldByName(cTAG).AsString := 'R1';
        LMasterTable.Post;
        LInternal := LMasterTable.FieldByName(cInternalField);
        LMasterTable.Edit;
        LInternal.AsInteger := Integer(dsInsert);
        LMasterTable.Post;
        LMasterTable.Append;
        LMasterTable.FieldByName(cKEY).AsInteger := cROOTOLD;
        LMasterTable.FieldByName(cTAG).AsString := 'R2';
        LMasterTable.Post;
        LMasterTable.Edit;
        LInternal.AsInteger := Integer(dsInsert);
        LMasterTable.Post;
        LChildTable.Append;
        LChildTable.FieldByName(cOWNKEY).AsInteger := 0;
        LChildTable.FieldByName(cKEY).AsInteger := cROOTOLD;
        LChildTable.FieldByName(cTAG).AsString := 'C0';
        LChildTable.Post;
        LChildTable.Edit;
        LChildTable.FieldByName(cInternalField).AsInteger := Integer(dsInsert);
        LChildTable.Post;
      finally
        TCascadeAccess<TAitMid>.Unmute(LChild);
        TCascadeAccess<TAitRoot>.Unmute(LMaster);
      end;
      Assert.AreEqual(1, CountWithColumn(LChildTable, cOWNERTOKEN, cNOTOKEN),
        'PREMISE - AND THE CLAUSE THAT KEEPS THIS TEST HONEST AFTER #265: the ' +
        'child must carry the NEVER RECORDED value. Its own adapter was muted, ' +
        'so DoNewRecord never ran on it and nothing was written at all. Take ' +
        'the mute off the CHILD and _EnsureMasterRowToken mints an identity ' +
        'for the master and this row names it, which is a different boundary ' +
        'measured by four other tests in this file - ' +
        DumpColumn(LChildTable, cOWNERTOKEN));

      TCascadeAccess<TAitRoot>.ApplyAll(LMaster);

      LKeyB := KeyOfMasterRow(LMasterTable, True);
      Assert.IsTrue(LKeyB > 0,
        'PREMISE: the second master must have received a generated key');
      Assert.AreEqual(1, CountWithColumn(LChildTable, cKEY, LKeyB),
        'a child row with no recorded parentage keeps the historical ' +
        'behaviour and ends on the LAST pending master - ' +
        DumpColumn(LChildTable, cKEY));
    finally
      LChild.Free;
      LMaster.Free;
    end;
  finally
    LChildTable.Free;
    LMasterTable.Free;
  end;
end;

procedure TTestAutoIncDistribution.ChildRowWithNoRecordedParentage_IsStillWrittenByItsMaster;
var
  LMasterTable: TFDMemTable;
  LChildTable: TFDMemTable;
  LMaster: TFDMemTableAdapter<TAitRoot>;
  LChild: TFDMemTableAdapter<TAitMid>;
  LKey: Integer;
begin
  // THE ASYMMETRY, measured. _IsOwnedByMasterRow gives the CHILD the benefit of
  // the doubt and the MASTER none. Here only the child's adapter is muted, so
  // the master row identifies itself and the child row does not - and the child
  // must still be written, because a row created by code that unhooks the
  // events is not a row that belongs to somebody else, it is a row nobody
  // recorded. Take that clause out and this child silently stops receiving its
  // master's key, which is a regression against everything that shipped before
  // issue #261.
  LMasterTable := TFDMemTable.Create(nil);
  LChildTable := TFDMemTable.Create(nil);
  try
    LMaster := TFDMemTableAdapter<TAitRoot>.Create(FConn, LMasterTable, -1, nil);
    LChild := TFDMemTableAdapter<TAitMid>.Create(FConn, LChildTable, -1,
                LMaster);
    try
      LMasterTable.Append;
      LMasterTable.FieldByName(cKEY).AsInteger := cROOTOLD;
      LMasterTable.FieldByName(cTAG).AsString := 'R1';
      LMasterTable.Post;
      TCascadeAccess<TAitMid>.Mute(LChild);
      try
        LChildTable.Append;
        LChildTable.FieldByName(cOWNKEY).AsInteger := 0;
        LChildTable.FieldByName(cKEY).AsInteger := cROOTOLD;
        LChildTable.FieldByName(cTAG).AsString := 'C0';
        LChildTable.Post;
        LChildTable.Edit;
        LChildTable.FieldByName(cInternalField).AsInteger := Integer(dsInsert);
        LChildTable.Post;
      finally
        TCascadeAccess<TAitMid>.Unmute(LChild);
      end;
      Assert.AreEqual(1, CountWithColumn(LChildTable, cOWNERTOKEN, 0),
        'PREMISE: the muted append must have left the child row without a ' +
        'recorded parent, otherwise this test measures the ordinary path');

      TCascadeAccess<TAitRoot>.ApplyAll(LMaster);

      LKey := KeyOfMasterRow(LMasterTable, False);
      Assert.IsTrue(LKey > 0,
        'PREMISE: the master must have received a generated key');
      Assert.AreEqual(1, CountWithColumn(LChildTable, cKEY, LKey),
        'a child row with no recorded parent must still receive the key of ' +
        'the master it is sitting under - ' + DumpColumn(LChildTable, cKEY));
    finally
      LChild.Free;
      LMaster.Free;
    end;
  finally
    LChildTable.Free;
    LMasterTable.Free;
  end;
end;

// ---------------------------------------------------------------------------
// The latent position site
// ---------------------------------------------------------------------------

procedure TTestAutoIncDistribution.AssertColumnsFollowTheMapping(
  const ADataSet: TDataSet; const AClass: TClass; const AWhere: String);
var
  LColumns: TColumnMappingList;
  LColumn: TColumnMapping;
  LIndex: Integer;
begin
  Assert.AreEqual(cInternalField, ADataSet.Fields[0].FieldName,
    AWhere + ': the internal column must be the ONLY one before the mapped ' +
    'ones - the six Apply* loops filter by name and write by index 0');
  LColumns := TMappingExplorer.GetMappingColumn(AClass);
  Assert.IsNotNull(LColumns,
    AWhere + ': the fixture must really have a column mapping');
  Assert.IsTrue(LColumns.Count > 0,
    AWhere + ': and that mapping must have columns in it - the loop below is ' +
    'the whole guard, and an empty list would walk it zero times and pass ' +
    'in silence');
  LIndex := 1;
  for LColumn in LColumns do
  begin
    Assert.AreEqual(LColumn.ColumnName, ADataSet.Fields[LIndex].FieldName,
      AWhere + ': mapped column ' + IntToStr(LIndex - 1) + ' must sit at ' +
      'field index ' + IntToStr(LIndex) + '. The three nested-fill loops do ' +
      'NOT agree on an offset: TBind._FillADTField and the ADT/Mongo branch ' +
      'of TBind._FillDataSetField copy source field N into ' +
      'ATarget.Fields[N + 1], while the ordinary branch of ' +
      'TBind._FillDataSetField copies N into N. What all THREE share is that ' +
      'each is bounded by the SOURCE FieldCount, which is why a column added ' +
      'at the END of the target is inert - and why a second internal column ' +
      'placed BEFORE the mapped ones is not: it would break the + 1 the ' +
      'first two rely on and misalign the N-into-N of the third, silently');
    Inc(LIndex);
  end;
end;

procedure TTestAutoIncDistribution.MappedColumnsKeepTheOffsetTheNestedFillReliesOn;
var
  LLeafTable: TFDMemTable;
  LLeaf: TFDMemTableAdapter<TAitLeaf>;
  LParentTable: TFDMemTable;
  LParent: TFDMemTableAdapter<TNestedParent>;
  LNested: TDataSet;
begin
  // The two _Fill* methods above are reached only through a nested dataset, and
  // no test in this suite drives them with a source wide enough to notice a
  // one-column shift. So the guard is on the LAYOUT they assume, over the
  // mapping itself, in the plain shape and in the nested one.
  LLeafTable := TFDMemTable.Create(nil);
  try
    LLeaf := TFDMemTableAdapter<TAitLeaf>.Create(FConn, LLeafTable, -1, nil);
    try
      AssertColumnsFollowTheMapping(LLeafTable, TAitLeaf, 'plain entity');
    finally
      LLeaf.Free;
    end;
  finally
    LLeafTable.Free;
  end;

  LParentTable := TFDMemTable.Create(nil);
  try
    LParent := TFDMemTableAdapter<TNestedParent>.Create(FConn, LParentTable, -1,
                 nil);
    try
      AssertColumnsFollowTheMapping(LParentTable, TNestedParent,
                                    'owner of a nested dataset');
      LNested := (LParentTable.FieldByName('items') as TDataSetField).NestedDataSet;
      Assert.IsNotNull(LNested,
        'the fixture must really produce a nested dataset, otherwise the ' +
        'clause below proves nothing');
      AssertColumnsFollowTheMapping(LNested, TNestedChild, 'nested dataset');
    finally
      LParent.Free;
    end;
  finally
    LParentTable.Free;
  end;
end;

// ---------------------------------------------------------------------------
// The two names the new columns took out of circulation
// ---------------------------------------------------------------------------

procedure TTestAutoIncDistribution.EntityColumnNamedLikeAReservedOne_SaysWhichNameIsReserved(
  const AReserved: String);
var
  LTable: TFDMemTable;
  LMessage: String;
begin
  // WHAT THIS DEFENDS. Creating the two provenance columns on EVERY dataset
  // the framework opens turned their names into RESERVED ones, and an entity
  // that has been mapping a column called ROWTOKEN or OWNERTOKEN since before
  // issue #261 now collides with them inside an adapter constructor. The
  // MAPPED column is the one created first, under the FindField in
  // TBind.SetInternalInitFieldDefsObjectClass, so it is always the internal
  // creation that fails. Without a guard it fails with the message MEASURED by
  // taking the guard out and running this very test: 'A component named
  // RowToken already exists'. That one is TComponent's rather than TDataSet's;
  // it says nothing about a reservation, nothing about which entity, and
  // nothing about what to do next.
  //
  // The fixture entities spell their columns in LOWER CASE. FindField is
  // case-insensitive, so they collide exactly as hard, and a guard that
  // compared names itself instead of asking the dataset would miss them.
  LMessage := '';
  LTable := TFDMemTable.Create(nil);
  try
    try
      if AReserved = cROWTOKEN then
        TFDMemTableAdapter<TResRowToken>.Create(FConn, LTable, -1, nil).Free
      else
        TFDMemTableAdapter<TResOwnerToken>.Create(FConn, LTable, -1, nil).Free;
    except
      on E: Exception do
        LMessage := E.Message;
    end;
    Assert.AreNotEqual('', LMessage,
      'building an adapter over an entity that maps ' + AReserved + ' must ' +
      'FAIL - the framework is about to create a column of that very name ' +
      'on the same dataset, and silently reusing the entity''s column would ' +
      'let the cascade write over mapped data');
    Assert.IsTrue(Pos('"' + AReserved + '" is RESERVED', LMessage) > 0,
      'and the message must name the colliding column and call it reserved, ' +
      'rather than leave the reader with the component-name clash quoted ' +
      'above - got: ' + LMessage);
    Assert.IsTrue(Pos('Rename', LMessage) > 0,
      'and it must say what to do about it, since the only fix is on the ' +
      'model side - got: ' + LMessage);
  finally
    LTable.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestAutoIncDistribution);

end.
