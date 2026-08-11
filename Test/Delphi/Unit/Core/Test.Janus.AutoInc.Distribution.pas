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

  WHAT IS MUTED, AND WHERE

  The distribution and recursion fixtures run the configuration Janus ships: no
  adapter muted in the set-up, no marker written by hand, no handler installed.
  These are the exceptions among them, and each says why in its own body:

    * UntokenisedRow_WithTwoPendingMasters_IsClaimedByNeither and its
      ClientDataSet twin mute BOTH adapters for the whole set-up and write the
      pending markers by hand - having no row provenance at all is the very
      thing they measure;
    * RestUntokenisedRow_WithTwoPendingMasters_IsClaimedByNeither mutes the
      CHILD adapter for ONE of its three child rows and writes that row's
      pending marker by hand - the other two are typed live, which is what lets
      it measure the unparented row beside two parented ones in one run;
    * Recursion_UntokenisedLeaf_WithTwoPendingMidRows_IsClaimedByNeither mutes
      the LEAF adapter for its one leaf row, same reason, one level down;
    * ChildRowWithNoRecordedParentage_IsStillWrittenByItsMaster mutes the
      CHILD adapter only, and writes that child's pending marker by hand, so
      that the master identifies itself and the child does not;
    * Recursion_WithNoPendingChildRow_StillReachesTheGrandchildren unhooks the
      mid table's BeforePost for one write, to set the ALREADY SAVED marker
      that the adapter's own BeforePost would otherwise flip straight back.

  THAT LIST IS NOT A CENSUS OF THE FILE, and an earlier revision of this
  paragraph carried a total - "THREE exceptions" - that had stopped being one.
  The issue #265 fixtures further down mute the master adapter as a matter of
  course, because a master with no recorded identity is what they are about, and
  they say so in their own bodies and in their shared helpers. No number is
  given here because nobody re-counted the file.

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

  THAT GAP IS NO LONGER THE WHOLE REPOSITORY'S - issue #262. It is still true of
  THIS file and of Test.Janus.AutoInc.Childs, and the sentence above stands for
  both. What closed it elsewhere is Test.Janus.AutoInc.UngeneratedKey, which
  drives level 3 through the shipped ApplyInternal in the local family and in
  the REST family, and which found what only that path could show: the recursion
  was propagating the middle level's autoinc PLACEHOLDER, because at the instant
  it fires the middle row has no key. A reader arriving here for level 3 should
  go there rather than conclude it is unmeasured.

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

  Nine tests were written for #265 and RUN against the untouched framework or,
  where they measure a hazard the fix itself could introduce, against the
  candidate that had it. All numbers below were re-measured against the file
  exactly as it is committed.

  RED AGAINST origin/develop:

    * ChildTypedUnderAnUnidentifiedMaster_MakesThatMasterIdentifyItself -
      the three arms in one message: [muted master, real key=0] [muted master,
      placeholder=0] [live master=positive]. 0 is what _IsOwnedByMasterRow
      waves through for EVERYBODY, so the first two children belonged to
      whoever asked;
    * LoadedMaster_ChildTypedUnderIt_KeepsTheLoadedMastersKey - RESULT: the
      child of the master LOADED FROM THE STORE on key 17 came out on 101;
    * MutedMasterAppend_WithARealKey_ItsChildKeepsThatKey - RESULT: the same;
    * TwoUnidentifiedPendingMasters_ChildOfTheFirstIsNotClaimedByTheSecond -
      RESULT: the child of the FIRST of two untokenised masters came out on the
      SECOND's key;
    * MintedMasterIdentity_ComesFromTheMasterOwnSequence - vacuously, since
      nothing is minted there at all;
    * and, in the neighbouring unit, Test.Janus.AutoInc.Childs
      .TwoPendingMasterRows_WithNoRecordedParentage_EveryPendingChildEndsOnTheLastMasterKey,
      whose write log is the sharpest evidence in the series: FOUR writes,
      [mid C0 <- 101 while the master sat on R1/101] twice and then the same two
      rows again on R2 - the first master writing the second master's children,
      inside the shipped ApplyInserter.

  GREEN AGAINST origin/develop, and required to stay green:
  MutedMasterAppend_WithThePendingPlaceholder_ItsChildIsRepaired,
  ChildTypedBeforeItsMasterRowIsPosted_StillReceivesTheKey,
  ChildTypedUnderAnEmptyMaster_MintsNothingAndFabricatesNoRow,
  ChildTypedWhileTheMasterRowIsBeingEdited_DoesNotCommitThatEdit,
  the two link fixtures, UntokenisedRows_KeepTheHistoricalBehaviour and
  ChildRowWithNoRecordedParentage_IsStillWrittenByItsMaster. The dsEdit one is
  green there because it now asserts the SAME answer develop gives - no
  parentage recorded - which is the trade this issue chose over writing into an
  edit the operator has not finished; what it pins is that the fix does not
  change it. The two link fixtures are green there for the plain reason that
  nothing is minted on develop at all; they exist to catch the fix, not the
  defect, and the mutation table below is where they earn their place.

  ONE NAME IN THAT LIST NO LONGER RESOLVES, and it is left standing rather than
  rewritten because the list is a record of what #265 measured, not a
  description of the file as it is now. UntokenisedRows_KeepTheHistoricalBehaviour
  was RENAMED and its result INVERTED by issue #261 - see the section below -
  and it is UntokenisedRow_WithTwoPendingMasters_IsClaimedByNeither today.
  Everything else in the list still resolves and is still green.

  THREE TESTS MEASURE THE FIX AGAINST ITSELF, and they exist because two
  candidate designs were shipped-and-withdrawn before this one:

    * MintedMasterIdentity_ComesFromTheMasterOwnSequence catches minting the
      master's identity out of the CHILD's counter. FRowTokenSeq is a class var
      of a GENERIC class, so there is one per instantiation, and the mint runs
      with Self being the child adapter. Measured on the second candidate:
      [live M1=27] [minted M2=125] [live M3=28] - the master row was handed 125
      out of the mid entity's sequence while its own sat at 27, so a later
      master would eventually be handed 125 too and issue #261 would come back
      through a collision instead of through a zero;

    * ClientDataSetLinkedAsTheRestClientDoes_MintingDoesNotPostTheChild catches
      the same candidate writing on the master row from inside the CHILD's
      OnNewRecord. Writing on the master row reaches every detail through
      deDataSetChange -> TDataLink.DataSetChanged -> RecordChanged(nil) ->
      TMasterDataLink.RecordChanged -> FOnMasterChange ->
      TCustomClientDataSet.MasterChanged, whose FIRST statement is
      CheckBrowseMode - so a detail sitting in dsInsert and Modified is POSTED
      half typed. Moving the call to DoBeforeInsert, where the child is still
      in dsBrowse, is what fixes it: put it back in DoNewRecord and this
      fixture is the ONLY red, with "Dataset not in edit or insert mode".
      THE FAMILY MATTERS AND THE FIREDAC TWIN DOES NOT DISCRIMINATE, but NOT
      for the reason an earlier revision of this header gave. That revision
      claimed TFDMasterDataLink.DataEvent captures deCheckBrowseMode in its
      delayed-scroll branch and returns before the guard. THAT WAS WRONG, and
      it is recorded here rather than quietly deleted: the branch tests
      `Event in [deDataSetScroll, deDataSetChange]`, which does not contain
      deCheckBrowseMode, and it would not fire anyway because it needs
      FetchOptions.DetailDelay > 0, whose default is 0. The real asymmetry is
      one level down: TFDDataSet.MasterChanged calls CheckMasterRange and NOT
      CheckBrowseMode, while TCustomClientDataSet.MasterChanged calls
      CheckBrowseMode first. The FireDAC twin is kept as the record of that
      measurement.
      AND THAT ASYMMETRY IS ABOUT ONE LEG, NOT ABOUT THE FAMILY. It closes the
      deDataSetChange leg for FireDAC and says nothing about the other one.
      TFDMasterDataLink.DataEvent forwards deCheckBrowseMode unless the detail
      AND its own master are BOTH in dsEditModes, so an Edit on the root walks
      down a FireDAC tree exactly as it walks down a ClientDataSet one - see
      FDMemTable_MintingWithAGrandchildRowOpen_DoesNotPostThatGrandchild, which
      exists because the un-narrowed sentence was an invitation to make the
      guard ClientDataSet-only.
      AND IT NEEDS NO LEVEL IN BETWEEN, which is a correction of the wording
      this paragraph used to carry: "as soon as there is a level in dsBrowse in
      between". ONE hop is enough. The state that would earn the early return
      is the MASTER's, and Data.DB.pas, TDataSet.Edit, runs CheckBrowseMode
      BEFORE SetState(dsEdit) - so the master is in dsBrowse at exactly that
      instant and a DIRECT sibling is reached with no mid level at all.
      Measured by
      FDMemTable_MintingWithASiblingChildMidInsert_DoesNotPostThatSibling;

    * MintingWithASiblingChildMidInsert_DoesNotPostThatSibling catches the leg
      that survives the fix above. The child being typed is safe in dsBrowse,
      but a DIFFERENT child of the same master - another grid the operator left
      half typed - is not, and it is reached by the same MasterChanged path.
      Measured with a sibling in dsInsert and Modified: it was POSTED, with AND
      without DisableControls around the write, because DisableControls
      suppresses the deCheckBrowseMode leg while EnableControls is itself what
      re-emits deDataSetChange, and the master's Post emits it regardless. No
      guard silences both legs and still lets the write happen, so the write is
      REFUSED instead: if any sibling has a row open, nothing is minted and the
      child falls back to the historical behaviour. That is why there is no
      DisableControls in the shipped method - adding it back today reddens
      nothing at all, measured;

    * ChildTypedUnderAnEmptyMaster_MintsNothingAndFabricatesNoRow catches the
      IsEmpty guard. Data.DB.pas turns Edit on a rowless dataset into Insert, so
      minting there would FABRICATE a master row;

    * FDMemTable_MintingWithAGrandchildRowOpen_DoesNotPostThatGrandchild is the
      FireDAC twin of the ClientDataSet three level fixture, and it exists
      because a sentence in this file said the FireDAC family could not reach
      the post at all. It can: the deDataSetChange leg dies at
      TFDDataSet.MasterChanged, and the deCheckBrowseMode leg does not, because
      TFDMasterDataLink.DataEvent only steps aside when the detail AND its own
      master are both in dsEditModes. Measured: drop the recursive descent and
      BOTH three level fixtures report the grandchild in dsBrowse;

    * FDMemTable_MintingWithASiblingChildMidInsert_DoesNotPostThatSibling is
      the FireDAC twin of the ONE level fixture, and it closes the last shape
      of this guard that was a reading rather than a measurement. The order the
      work happened in is why it mattered: the sibling clause shipped FIRST and
      the recursive descent came after, so every piece of FireDAC evidence in
      this file was evidence about the DESCENT, and narrowing the SIBLING
      clause to the ClientDataSet family would have reddened nothing. Measured:
      drop the open-row test from _AnyDetailRowOpen and this fixture reports
      "Measured state: dsBrowse" - the half typed sibling was POSTED, one hop
      down, in the family once said to be out of reach. Green against 30d139f,
      where nothing is minted and so nothing reaches the sibling, which is what
      says it measures the mint and not the wiring;

    * MintingWithAnUntouchedGrandchildInEdit_IsRefusedAndThatIsThePrice pins a
      DECISION rather than a defect. The guard asks `State in dsEditModes` and
      never asks `Modified`, so it refuses the mint even for a saved row put
      into dsEdit and never touched - one that CheckBrowseMode would Cancel, not
      Post. Measured: narrowing the predicate with `and Modified` gives the
      child of the other branch a real OwnerToken where it now records zero. It
      is NOT narrowed, and the fixture says why with a measurement rather than
      an argument: Data.DB.pas runs UpdateRecord BEFORE it reads Modified, and
      UpdateRecord is exactly when a data-aware control writes the operator's
      text into the field - so the fixture installs a TDataSource.OnUpdateData
      where the control would be, and under the narrowed predicate the untouched
      row comes back carrying what that handler wrote, which means it was
      POSTED. dsSetKey is the second reason: it is in dsEditModes and
      CheckBrowseMode posts it unconditionally, where Modified says nothing.

  THE TWO DESIGNS THAT WERE MEASURED AND WITHDRAWN

  FIRST: mark the CHILD with a sentinel meaning "recorded, and my master had no
  identity", and refuse it to any master that DOES identify itself. It passed
  everything except TwoUnidentifiedPendingMasters..., and that is the point: a
  sentinel separates an identified master from an unidentified one, but not two
  unidentified masters from each other, so the first still wrote the second's
  children. It narrowed the hole instead of closing it.

  SECOND: mint the master's identity, but from inside the child's DoNewRecord
  and with AtomicIncrement written there. Two independent defects, both now
  pinned: the counter belonged to the child's instantiation, and the write
  reached the detail through the master-detail link and posted it.

  WHAT SHIPS removes the state rather than labelling it, and does the writing
  where it is safe: TDataSetBaseAdapter<M>.DoBeforeInsert calls
  _EnsureMasterRowToken while the child row is still in dsBrowse and not yet
  Modified, the value comes from the MASTER's own sequence through the virtual
  _MintRowToken, and the write happens only on a dsBrowse master row that has a
  row at all, with the master's controls disabled. _IsOwnedByMasterRow keeps the
  two answers #264 gave it.

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

  Each was reverted on its own and the whole project re-run. EVERY clause in
  _EnsureMasterRowToken binds, and the list is the whole method:

    * never minting -> the six tests that are red against origin/develop;
    * taking the value from AtomicIncrement(FRowTokenSeq) instead of the
      virtual _MintRowToken -> MintedMasterIdentity_ComesFromTheMasterOwnSequence
      alone;
    * dropping the open-row test on the child itself, which is the only clause
      of _AnyDetailRowOpen that ever answers True ->
      MintingWithASiblingChildMidInsert_DoesNotPostThatSibling,
      MintingWithAGrandchildRowOpen_DoesNotPostThatGrandchild,
      FDMemTable_MintingWithASiblingChildMidInsert_DoesNotPostThatSibling,
      FDMemTable_MintingWithAGrandchildRowOpen_DoesNotPostThatGrandchild and
      MintingWithAnUntouchedGrandchildInEdit_IsRefusedAndThatIsThePrice, FIVE,
      and so does dropping the call to it from _EnsureMasterRowToken - removing
      that single test disarms the walk at every depth at once. Both families
      at both depths, and the count was FOUR until the one level FireDAC shape
      was measured. FOUR of the five say the state out loud - the two grandchild
      ones and BOTH siblings all report "Measured state: dsBrowse" - and the
      fifth, the untouched-dsEdit one, reports the value the control wrote
      because that is the stronger finding there. The ClientDataSet sibling used
      to be the exception, asserting its price FIRST and so failing on
      "Expected [0] but got [33]" without ever printing a state; its two clauses
      were swapped into the convention the rest of the file follows;
    * NARROWING THE DIRECT CHILD TEST TO THE ClientDataSet FAMILY, with the
      recursive descent left whole -> ONE red in 499, and it is
      FDMemTable_MintingWithASiblingChildMidInsert_DoesNotPostThatSibling. This
      is the sharpest row in this table, and it is why that fixture exists. The
      mutation above DELETES the open-row test outright, which disarms the
      sibling clause and the descent together and cannot tell the two apart;
      this one separates them. It keeps the descent, so both grandchild fixtures
      and the untouched-dsEdit one stay green - their open row is caught one
      level further down by the walk, which is left unnarrowed - and it narrows
      ONLY the test applied to a DIRECT child, to datasets of the
      TCustomClientDataSet family. That is literally the regression this shape
      exists to prevent: a later change accepting the old "the FireDAC family
      never reaches the post" sentence and scoping the sibling clause to match.
      Measured, full rebuild: Tests Found 499, Tests Passed 498, Tests Failed 1,
      on "Condition is False when True expected. [the SIBLING must still be
      sitting in dsInsert, in the FIREDAC family too and at ONE level ...
      Measured state: dsBrowse]". ONE red, and it is the new fixture - nothing
      else in this project answers that question;
    * dropping the RECURSIVE DESCENT alone -> 496 of 499, three reds, and they
      are the three fixtures whose open row is more than one level down: the two
      grandchild ones, both reporting "Measured state: dsBrowse", and the
      untouched-dsEdit one, reporting "Expected [KEEP] but got [CTRL]" - the
      untouched row was POSTED carrying what the control wrote. BOTH SIBLING
      FIXTURES STAY GREEN under it, which is the complement of the row above and
      what makes the pair a partition rather than two views of one thing: the
      narrowing reddens the one level FireDAC shape and nothing else, this one
      reddens everything BUT the one level shapes;
    * narrowing the open-row test to `and Modified` ->
      MintingWithAnUntouchedGrandchildInEdit_IsRefusedAndThatIsThePrice ALONE,
      on that same KEEP/CTRL clause. Remove the OnUpdateData handler as well and
      the mutation still reddens that one fixture, but on the PRICE clause
      instead, "Expected [0] but got [33]", with the KEEP clause now GREEN
      because an untouched row really is Cancelled when no control writes into
      it. That pair is the whole argument: the handler does not change which
      test is red, it changes whether the finding is "a row was committed
      behind the operator's back" or only "a child lost its parentage";
    * dropping the IsEmpty guard ->
      ChildTypedUnderAnEmptyMaster_MintsNothingAndFabricatesNoRow alone;
    * minting from any state instead of only dsBrowse ->
      ChildTypedWhileTheMasterRowIsBeingEdited_DoesNotCommitThatEdit and
      ChildTypedUnderAMutedMasterStillInserting_RecordsNoParentage;
    * minting over an identity a row already had -> NINETEEN tests across
      Test.Janus.AutoInc.Childs, Test.Janus.Apply.Loops and this unit;
    * not muting the master's adapter around the write ->
      LoadedMaster_ChildTypedUnderIt_KeepsTheLoadedMastersKey, on the clause
      that reads the pending marker back off the loaded row: without the mute
      the master's own DoBeforePost promotes it to dsEdit and a row nobody
      touched becomes an UPDATE;
    * moving the call from DoBeforeInsert back to DoNewRecord ->
      ClientDataSetLinkedAsTheRestClientDoes_MintingDoesNotPostTheChild alone;
    * dropping the child-side benefit of the doubt in _IsOwnedByMasterRow ->
      ChildRowWithNoRecordedParentage_IsStillWrittenByItsMaster alone.

  NO CLAUSE IS LEFT UNDEFENDED. An earlier revision of this header carried a
  paragraph saying the IsEmpty guard reddened nothing; that paragraph described
  a state of the work that no longer existed when it shipped, and it is deleted
  rather than adjusted. The guard is now pinned by
  ChildTypedUnderAnEmptyMaster_MintsNothingAndFabricatesNoRow, and the clause
  that WAS inert - DisableControls around the write - was removed rather than
  labelled, after measuring that it changes nothing in either direction.

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

  ISSUE #261, THE LAST ARM - THE CHILD ROW NOBODY RECORDED

  #264 and #265 gave every row an identity and closed the two ways a child could
  end up naming nobody. ONE way was left open on purpose, as the documented
  escape hatch: a child row appended with its own adapter's events unhooked, or
  read back from a store that has no such column, records nothing, and
  _IsOwnedByMasterRow answers True for it to whoever asks. With ONE pending
  master that is right, and it is why the hatch exists.

  With TWO it was not a decision, it was an ordering. Both masters asked, both
  were answered True, the row was written twice and kept what the SECOND one
  wrote. RED FIRST, measured against 8e1a5c6: two of these four fixtures - the
  local FDMemTable one and the REST one - were written and RUN before a line of
  Source changed, one at each end of the two families. Total 545, TWO reds, the
  unparented child on the second master's key in
  both families: "Expected [-31] but got [201]" with the dump reading
  [C0 root_id=201], and "Expected [-31] but got [600]" with the dump reading
  [A0 root_id=300][B0 root_id=600][C0 root_id=600] - the orphan sitting on B0's
  key, indistinguishable from a row that really was typed under R2. The same
  tree with the fix in place is 545 and zero.

  WHAT SHIPS ADDS NO STATE TO THE TOKEN. The column still carries exactly the
  two values #264 gave it, and the third state #265 measured and rejected is
  still rejected. What gained a second input is the QUESTION: the answer True
  for an unrecorded row is now weighed against the number of master rows doing
  the asking, which TDataSetBaseAdapter<M>.FCascadeMasterRows carries. The hatch
  survives where there is one master and closes where there is a real ambiguity.

  AND WHAT BECOMES OF THE ROW NOBODY CLAIMS - measured, and NOT what an earlier
  revision of this header asserted. That revision said the row "stays PENDING
  carrying the key it came in with", which was reasoning, not a reading, and it
  is only half true. The answer differs BY FAMILY and both halves are now
  pinned:

    * the LOCAL families INSERT it. ApplyInternal reaches the child adapter's
      own ApplyInternal after the master loop ends, and that loop inserts every
      pending row it finds without asking about parentage - so what the consumer
      ends up with is a row IN THE DATABASE carrying an unresolved foreign key.
      Measured on both: cInternalField comes back at cAPPLIED;
    * the REST family leaves it PENDING. TRESTFDMemTableAdapter<M>.ApplyInternal
      does not iterate FMasterObject, the child level is never applied in that
      run, and the marker is still Integer(dsInsert) when the apply is over.

  Neither is asserted as the desirable one, and this issue did not choose
  between them - the difference predates it and belongs to how each family
  cascades ApplyInternal. What the three clauses do is stop anyone writing "the
  framework leaves it pending" again without a fixture contradicting them.
  WHAT IS STILL BETTER THAN THE DEFECT, and this part is not weakened by the
  above: an unresolved foreign key is a row a consumer can find by querying for
  it, and it is the key the consumer put there. A row silently re-parented onto
  another master's key is indistinguishable from correct data.

  THE FOUR FIXTURES, AND WHY FOUR

  UntokenisedRow_WithTwoPendingMasters_IsClaimedByNeither is the rewrite of
  UntokenisedRows_KeepTheHistoricalBehaviour. Its set-up is unchanged line for
  line except for ONE value - the child's foreign key starts on cUNCLAIMEDSEED
  instead of on cROOTOLD, because 0 is what an unwritten integer column reads as
  anyway and a clause asserting 0 would pass on a run that populated nothing.
  Its result is inverted, and two PREMISE clauses were added that state the
  shape as numbers: two pending masters, one pending child. It was renamed
  rather than deleted because it builds the only ambiguous shape in the file.

  RestUntokenisedRow_WithTwoPendingMasters_IsClaimedByNeither is the other half
  of the red, and it is not a translation of the local one: the REST family
  discards nothing when the master scrolls, so it holds THREE child rows at once
  - one under each master, plus the orphan - and reads all three back in a
  single run.

  THE OTHER TWO WERE WRITTEN AFTER THE FIX, and the order they were written in
  is the reason they exist rather than a tidying-up. The count cannot be taken
  from inside the cascade and is therefore read at the top of ApplyInserter, and
  there are THREE ApplyInserter implementations, near enough identical to invite
  the argument that measuring one measures the rest.
  ClientDataSetUntokenisedRow_... covers the third of them, which no fixture
  reached. Recursion_UntokenisedLeaf_WithTwoPendingMidRows_IsClaimedByNeither
  covers the level BELOW the top, where there is no ApplyInserter at all and
  _RecurseOverChildRows is the only thing that knows how many masters the next
  level faces - and it was written because that mutation was RUN and SURVIVED:
  at ff096e2, with the assignment deleted, 546 tests and zero reds. It goes
  through
  TCascadeAccess.Propagate for isolation, and pays the same price
  Recursion_LeavesTypedUnderTheMiddleMidRow... pays: the master state is forged,
  so it pins the walk and not the walk's caller.

  HOW THE #261 CLAUSES WERE SHOWN TO BIND

  Every figure below was measured at d01d4f3, full rebuild, Janus.Tests.Units,
  where the untouched tree is 547 tests and zero failures. Each mutation was
  applied ALONE and reverted before the next:

    * restoring the unconditional slack - `Exit(FCascadeMasterRows <= 1)` back
      to a bare `Exit` -> FOUR reds, and they are the four fixtures above and
      nothing else;
    * refusing every unparented child instead - `Exit(False)`, which is the
      design that was proposed and rejected -> ONE red, and it is
      ChildRowWithNoRecordedParentage_IsStillWrittenByItsMaster. That single
      number is the whole argument for conditioning the slack rather than
      removing it: refusing outright leaves that child on its old key with
      nobody ever repairing it;
    * deleting the count read from TFDMemTableAdapter<M>.ApplyInserter alone ->
      ONE red, UntokenisedRow_WithTwoPendingMasters_IsClaimedByNeither;
    * from TClientDataSetAdapter<M>.ApplyInserter alone -> ONE red, the
      ClientDataSet twin;
    * from TRESTDataSetAdapter<M>.ApplyInserter alone -> ONE red, the REST one.
      Three mutations, three reds, three different fixtures: the three reads are
      not each other's evidence;
    * deleting `AChildAdapter.FCascadeMasterRows := LMarks.Count` from
      _RecurseOverChildRows -> ONE red,
      Recursion_UntokenisedLeaf_WithTwoPendingMidRows_IsClaimedByNeither, and
      the three top-level fixtures stay green, which is what says the two kinds
      of caller are measured separately;
    * MOVING the read from before the ApplyInserter loop to inside it - that is,
      counting the pending masters on demand instead of capturing the number
      once -> ONE red, the local FDMemTable fixture. This is the mutation that
      earns the design: the filtered RecordCount DECAYS as the loop clears each
      marker, so the last master row sees 1, decides there is no ambiguity and
      claims the orphan - last-one-wins restored under a new name.

  THE TWO MUTATIONS THAT SURVIVE, declared rather than left to be found, and
  BOTH of them, because two survivors in one method with only one confessed
  would be choosing which to admit to. Both are in _RecurseOverChildRows:

    * deleting `AChildAdapter.FCascadeMasterRows := 1` from the no-pending-row
      branch reddens NOTHING - 547 green at d01d4f3. 0 and 1 give the same
      answer to the only reader, and the field arrives at that branch holding 0
      on every path this suite reaches. Kept because the two values do not MEAN
      the same thing;
    * deleting the `finally` restore, `:= LOuterRows`, reddens NOTHING either -
      547 green at 0c5de92. LOuterRows is 0 on every path the suite reaches, and
      whatever runs next establishes its own number before reading. Kept because
      the method writes into ANOTHER object's field and what is borrowed is put
      back.

  Neither justification is that a cycle in the adapter tree could carry a stale
  count in. An earlier revision of the comment at the first site said so, and it
  was WRONG in a way this repository had already measured: a cycle cannot be
  built, because TManagerDataSet.AddAdapter<T, M> exits early in both
  directions - the argument is written out in the header of _AnyDetailRowOpen.
  It is recorded here rather than quietly deleted.

  WHAT THE #261 ASSERTIONS DO NOT CLAIM. The "and not the other master's key"
  clauses are arithmetic complements of the clause above them plus the premise
  that the two keys differ, because those fixtures have exactly ONE unparented
  child row - exactly as the #265 paragraph further up says of its own. That
  applies to the two LOCAL top-level fixtures and to the level 3 one; they were
  not inverted one at a time, and they are there to make the failure message say
  WHERE the row went. In all three, the clause that carries the measurement is
  the one that reads the row back BY TAG.

  THE REST FIXTURE IS THE EXCEPTION AND THAT IS ITS POINT. Its three child rows
  are three different rows, so "A0 is on the first master's key", "B0 is on the
  second's" and "C0 is on neither" are three independent readings taken in one
  run. The first two are what say the count of pending masters does not touch a
  row whose parentage IS recorded - a claim no complement clause can make.

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

  NOT MEASURED, ADDED BY #261 AND LISTED RATHER THAN LEFT TO BE DISCOVERED:

    * A MID ROW WITH NO TOKEN THAT HAS CHILDREN OF ITS OWN, under two pending
      roots. No fixture builds it. The guard excludes that row from LMarks in
      _RecurseOverChildRows, and LMarks is what the recursion rides - so it is
      not one row that goes unwritten but the WHOLE SUBTREE under it that goes
      unvisited. That is consistent with what the guard is for, and consistency
      is not a measurement. The four fixtures all put the unrecorded row at the
      BOTTOM of their tree, where it has nothing below it to skip;
    * THE ObjectSet AND RESTObjectSet FAMILIES are outside this entirely. They
      have no provenance column at all - TObjectSetBaseAdapter<M> and
      TRESTObjectSet carry their own SetAutoIncValueChilds over object graphs,
      not over datasets - so neither the token nor the count exists there.
      Whether the same ambiguity is reachable through an object graph was not
      looked into and is not claimed either way;
    * A THIRD LEVEL DRIVEN THROUGH A REAL ApplyInternal, which the paragraph
      near the top of this header already says of #261's predecessors and is
      still true of the level 3 fixture added here: it goes through Propagate.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.AutoInc.Distribution;

interface

uses
  DB,
  Classes,
  SysUtils,
  Variants,
  TypInfo,
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
    class function SourceOf(const A: TDataSetBaseAdapter<M>): TDataSource;
    class procedure Mute(const A: TDataSetBaseAdapter<M>);
    class procedure Unmute(const A: TDataSetBaseAdapter<M>);
  end;

  [TestFixture]
  TTestAutoIncDistribution = class
  private
    FConn: IDBConnection;
    FTree: TTreeConnection;
    FRest: IRESTConnection;
    /// The dataset ControlWritesDuringUpdateRecord writes into. A field rather
    /// than a closure because TDataSource.OnUpdateData is a plain TNotifyEvent
    /// and hands back the SOURCE, not the dataset.
    FControlDataSet: TDataSet;
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
    procedure ControlWritesDuringUpdateRecord(ASender: TObject);
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

    [Test]
    procedure Recursion_UntokenisedLeaf_WithTwoPendingMidRows_IsClaimedByNeither;

    // --- issue #265: the master that came out of the store ------------------
    [Test]
    procedure ChildTypedUnderAnEmptyMaster_MintsNothingAndFabricatesNoRow;
    [Test]
    procedure MintedMasterIdentity_ComesFromTheMasterOwnSequence;
    [Test]
    procedure LinkedAsTheRestClientDoes_MintingDoesNotPostTheChild;
    [Test]
    procedure ClientDataSetLinkedAsTheRestClientDoes_MintingDoesNotPostTheChild;
    [Test]
    procedure MintingWithASiblingChildMidInsert_DoesNotPostThatSibling;
    [Test]
    procedure MintingWithAGrandchildRowOpen_DoesNotPostThatGrandchild;
    [Test]
    procedure FDMemTable_MintingWithASiblingChildMidInsert_DoesNotPostThatSibling;
    [Test]
    procedure FDMemTable_MintingWithAGrandchildRowOpen_DoesNotPostThatGrandchild;
    [Test]
    procedure MintingWithAnUntouchedGrandchildInEdit_IsRefusedAndThatIsThePrice;
    [Test]
    procedure ChildTypedUnderAMutedMasterStillInserting_RecordsNoParentage;
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
    procedure UntokenisedRow_WithTwoPendingMasters_IsClaimedByNeither;
    [Test]
    procedure ClientDataSetUntokenisedRow_WithTwoPendingMasters_IsClaimedByNeither;
    [Test]
    procedure RestUntokenisedRow_WithTwoPendingMasters_IsClaimedByNeither;
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
  /// issue #261, the ambiguity arm. The foreign key an UNTOKENISED child row is
  /// seeded with when the question is "was it written at all", so that "nobody
  /// claimed it" can never be read as "somebody claimed it and happened to
  /// write the same number". NEGATIVE, so no generated key can reach it -
  /// TTreeConnection hands out cSTEP, 2*cSTEP, ... and TSeqRestConnection
  /// cRESTSTEP, 2*cRESTSTEP, ... - and NOT cPLACEHOLDER, because -1 is the one
  /// negative the framework itself writes and _AutoIncKeyIsGenerated reads.
  cUNCLAIMEDSEED = -31;
  /// The value ApplyInserter and ApplyUpdater write back into cInternalField
  /// once a row has reached the database - "not pending any more". It happens
  /// to be the same number as cPLACEHOLDER and is a DIFFERENT concept: that one
  /// is an autoinc primary KEY the generator has not answered for yet, this one
  /// is a row STATE marker. Spelled separately so a reader of the clauses below
  /// does not have to work out which of the two a -1 means.
  cAPPLIED = -1;
  cEDITEDTAG  = 'EDITING';
  /// The two tags the UNTOUCHED-dsEdit fixture tells apart: what a grandchild
  /// row was COMMITTED with, and what a data-aware control writes into it
  /// during deUpdateRecord. Both a Post and a Cancel leave the dataset in
  /// dsBrowse, so reading the tag back is the only way to say which happened.
  cKEEPTAG    = 'KEEP';
  cCTRLTAG    = 'CTRL';

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

class function TCascadeAccess<M>.SourceOf(
  const A: TDataSetBaseAdapter<M>): TDataSource;
begin
  Result := TCascadeAccess<M>(A).FOrmDataSource;
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

procedure TTestAutoIncDistribution.Recursion_UntokenisedLeaf_WithTwoPendingMidRows_IsClaimedByNeither;
var
  LRootTable: TFDMemTable;
  LMidTable: TFDMemTable;
  LLeafTable: TFDMemTable;
  LRoot: TFDMemTableAdapter<TAitRoot>;
  LMid: TFDMemTableAdapter<TAitMid>;
  LLeaf: TFDMemTableAdapter<TAitLeaf>;
begin
  // THE SAME AMBIGUITY ONE FLOOR DOWN, and the fixture that says the count is
  // established in TWO kinds of place rather than one.
  //
  // At the top of a cascade the number of pending masters comes from
  // ApplyInserter, which is where the loop lives. Below the top there is no
  // ApplyInserter: _RecurseOverChildRows rides the mid rows itself, so IT is
  // the only place where the number of masters the leaf level is about to face
  // exists at all. Take that one assignment out and the top-level reads still
  // stand, the three fixtures above stay green, and an unparented LEAF goes
  // back to being written once per mid row and keeping the last.
  //
  // WHY Propagate AND NOT ApplyAll, which is the whole isolation. Driving this
  // through ApplyInternal would set FCascadeMasterRows on the ROOT adapter from
  // ApplyInserter, and later on the MID adapter from the mid level's own
  // ApplyInserter, so a red could be either of those doing the work.
  // TCascadeAccess.Propagate calls SetAutoIncValueChilds directly: no
  // ApplyInserter runs anywhere in this test, every FCascadeMasterRows starts
  // at zero, and the only thing that can set the mid level's is the recursion.
  // The price is the same one Recursion_LeavesTypedUnderTheMiddleMidRow...
  // pays and states: the master state is FORGED - Edit plus the new key, not
  // yet posted - so what is pinned here is the walk, not the walk's caller.
  //
  // THE MID ROWS CARRY REAL KEYS ON PURPOSE. _AutoIncKeyIsGenerated - issue
  // #262 - refuses to propagate from a row still sitting on the autoinc
  // placeholder, and with the placeholder in place the recursion would write
  // nothing at all and this test would pass without measuring anything.
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
      LMidTable.Append;
      LMidTable.FieldByName(cKEY).AsInteger := cROOTOLD;
      LMidTable.FieldByName(cOWNKEY).AsInteger := cMIDLAST;
      LMidTable.FieldByName(cTAG).AsString := 'M1';
      LMidTable.Post;
      // The leaf nobody recorded. Its own adapter is muted for the append, so
      // DoNewRecord never runs on it and cOwnerTokenField stays at the zero a
      // TField answers for NULL; the pending marker is written by hand because
      // a muted append never reaches DoBeforePost.
      TCascadeAccess<TAitLeaf>.Mute(LLeaf);
      try
        LLeafTable.Append;
        LLeafTable.FieldByName(cKEY).AsInteger := cROOTOLD;
        LLeafTable.FieldByName(cOWNKEY).AsInteger := cUNCLAIMEDSEED;
        LLeafTable.FieldByName(cTAG).AsString := 'L0';
        LLeafTable.Post;
        LLeafTable.Edit;
        LLeafTable.FieldByName(cInternalField).AsInteger := Integer(dsInsert);
        LLeafTable.Post;
      finally
        TCascadeAccess<TAitLeaf>.Unmute(LLeaf);
      end;
      Assert.AreEqual(2,
        CountWithColumn(LMidTable, cInternalField, Integer(dsInsert)),
        'PREMISE: TWO mid rows must be pending - they are the masters of the ' +
        'leaf level and two of them is the ambiguity');
      Assert.AreEqual(1, CountWithColumn(LLeafTable, cOWNERTOKEN, cNOTOKEN),
        'PREMISE: the leaf must carry the NEVER RECORDED value - ' +
        DumpColumn(LLeafTable, cOWNERTOKEN));
      Assert.AreEqual(1,
        CountWithColumn(LLeafTable, cInternalField, Integer(dsInsert)),
        'PREMISE: and it must be PENDING, or nothing would look at it at all');

      // The state ApplyInserter leaves the master in: dsEdit, carrying the key
      // the database has just generated, not yet posted.
      LRootTable.Edit;
      LRootTable.FieldByName(cKEY).AsInteger := cROOTNEW;

      TCascadeAccess<TAitRoot>.Propagate(LRoot);

      Assert.AreEqual(2, CountWithColumn(LMidTable, cKEY, cROOTNEW),
        'PREMISE: level 2 must still have been written in full - both mid ' +
        'rows belong to the one root row. If this is 0 the recursion was ' +
        'never reached and the leaf clauses below are vacuous - ' +
        DumpColumn(LMidTable, cKEY));
      Assert.AreEqual(cUNCLAIMEDSEED, TokenOfTaggedRow(LLeafTable, 'L0',
                                                       cOWNKEY),
        'THE ROW L0 recorded no parent, and there are TWO mid rows that could ' +
        'claim it, so neither does - ' + DumpColumn(LLeafTable, cOWNKEY));
      Assert.AreEqual(0, CountWithColumn(LLeafTable, cOWNKEY, cMIDLAST),
        'and specifically NOT the LAST mid row, which is where a recursion ' +
        'that waves every unparented leaf through leaves it - ' +
        DumpColumn(LLeafTable, cOWNKEY));
      Assert.AreEqual(0, CountWithColumn(LLeafTable, cOWNKEY, cMIDFIRST),
        'nor the FIRST - ' + DumpColumn(LLeafTable, cOWNKEY));
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
/// child must record THAT identity, and it must be a DIFFERENT one from the
/// identities minted in the other two arms. Without it a framework that handed
/// out one shared number would look right.
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

procedure TTestAutoIncDistribution.ChildTypedUnderAnEmptyMaster_MintsNothingAndFabricatesNoRow;
var
  LRootTable: TFDMemTable;
  LMidTable: TFDMemTable;
  LLeafTable: TFDMemTable;
  LRoot: TFDMemTableAdapter<TAitRoot>;
  LMid: TFDMemTableAdapter<TAitMid>;
  LLeaf: TFDMemTableAdapter<TAitLeaf>;
begin
  // THE GUARD THE RTL DEFENDS ON ITS OWN, and the one whose absence no test
  // used to notice. Data.DB.pas, TDataSet.Edit, first line of the body:
  // "if not (State in [dsEdit, dsInsert]) then if FRecordCount = 0 then Insert"
  // - Edit on a dataset with no rows is not an error, it is an INSERT. So
  // minting an identity on an EMPTY master would write into an insertion
  // buffer and the Post that follows would FABRICATE a master row that nobody
  // asked for, which then walks ApplyInserter and reaches the database.
  //
  // Removing the IsEmpty guard reddened NOTHING before this test existed. That
  // was not evidence the guard was redundant; it was a hole - no fixture had
  // ever typed a child with the master table empty. Here is one.
  BuildTree(FConn, LRootTable, LMidTable, LLeafTable, LRoot, LMid, LLeaf);
  try
    Assert.AreEqual(0, RowCount(LRootTable),
      'PREMISE: the master table must be EMPTY, which is the whole condition ' +
      'under test');

    LMidTable.Append;
    LMidTable.FieldByName(cOWNKEY).AsInteger := 0;
    LMidTable.FieldByName(cKEY).AsInteger := cROOTOLD;
    LMidTable.FieldByName(cTAG).AsString := 'C0';
    LMidTable.Post;

    Assert.AreEqual(0, RowCount(LRootTable),
      'the master table must STILL be empty. A row appearing here is one the ' +
      'framework invented while trying to give a master an identity, and it ' +
      'would be inserted for real on the next ApplyUpdates - ' +
      DumpColumn(LRootTable, cKEY));
    Assert.AreEqual(1, RowCount(LMidTable),
      'and the child must have been typed normally');
    Assert.AreEqual(cNOTOKEN, TokenOfTaggedRow(LMidTable, 'C0', cOWNERTOKEN),
      'while recording NO parentage: there was no master row to name, so the ' +
      'row falls back to the historical behaviour instead of naming an ' +
      'identity that belongs to nothing');
  finally
    DropTree(LRootTable, LMidTable, LLeafTable, LRoot, LMid, LLeaf);
  end;
end;

procedure TTestAutoIncDistribution.MintedMasterIdentity_ComesFromTheMasterOwnSequence;
var
  LRootTable: TFDMemTable;
  LMidTable: TFDMemTable;
  LLeafTable: TFDMemTable;
  LRoot: TFDMemTableAdapter<TAitRoot>;
  LMid: TFDMemTableAdapter<TAitMid>;
  LLeaf: TFDMemTableAdapter<TAitLeaf>;
  LFirst: Integer;
  LMinted: Integer;
  LThird: Integer;
  LDump: String;
begin
  // WHICH COUNTER MINTED IT. FRowTokenSeq is a `class var` of a GENERIC class,
  // so there is one counter PER INSTANTIATION: TDataSetBaseAdapter<TAitRoot>
  // and TDataSetBaseAdapter<TAitMid> each have their own. The comment on that
  // field states the invariant the whole parentage check rests on - both sides
  // of every comparison are minted by the SAME counter - and minting the
  // MASTER identity from inside the CHILD DoNewRecord is the one place where
  // that can quietly stop being true, because Self there is the child adapter.
  //
  // WHY THE ARITHMETIC BELOW IS DECISIVE AND NOT A COINCIDENCE. Exactly three
  // things in this test can consume the ROOT counter: the live append of the
  // first master, the mint, and the live append of the third. If the mint
  // consumes it, the three values are consecutive and BOTH clauses hold. If the
  // mint consumes some OTHER counter, then the first and third master are
  // consecutive to EACH OTHER - LThird = LFirst + 1 - and the two clauses below
  // become mutually unsatisfiable: LMinted = LFirst + 1 and
  // LThird = LMinted + 1 would need LThird = LFirst + 2. So at least one of
  // them MUST fail, whatever the counters happened to hold when this test
  // started. No fixture ordering can make it pass by luck.
  //
  // The middle master is muted-appended so that it arrives WITHOUT an identity,
  // which is the only state that reaches the mint at all.
  BuildTree(FConn, LRootTable, LMidTable, LLeafTable, LRoot, LMid, LLeaf);
  try
    LRootTable.Append;
    LRootTable.FieldByName(cKEY).AsInteger := cROOTOLD;
    LRootTable.FieldByName(cTAG).AsString := 'M1';
    LRootTable.Post;
    LFirst := TokenOfTaggedRow(LRootTable, 'M1', cROWTOKEN);
    Assert.IsTrue(LFirst > cNOTOKEN,
      'PREMISE: a master appended with the events LIVE must identify itself');

    TCascadeAccess<TAitRoot>.Mute(LRoot);
    try
      LRootTable.Append;
      LRootTable.FieldByName(cKEY).AsInteger := cROOTOLD;
      LRootTable.FieldByName(cTAG).AsString := 'M2';
      LRootTable.Post;
    finally
      TCascadeAccess<TAitRoot>.Unmute(LRoot);
    end;
    Assert.AreEqual(cNOTOKEN, TokenOfTaggedRow(LRootTable, 'M2', cROWTOKEN),
      'PREMISE: the muted append must have left the middle master WITHOUT an ' +
      'identity, or nothing is minted and this test measures nothing');

    LMidTable.Append;
    LMidTable.FieldByName(cOWNKEY).AsInteger := 0;
    LMidTable.FieldByName(cTAG).AsString := 'C0';
    LMidTable.Post;
    LMinted := TokenOfTaggedRow(LRootTable, 'M2', cROWTOKEN);

    LRootTable.Append;
    LRootTable.FieldByName(cKEY).AsInteger := cROOTOLD;
    LRootTable.FieldByName(cTAG).AsString := 'M3';
    LRootTable.Post;
    LThird := TokenOfTaggedRow(LRootTable, 'M3', cROWTOKEN);

    LDump := ' - measured: [live M1=' + IntToStr(LFirst) + '] [minted M2=' +
             IntToStr(LMinted) + '] [live M3=' + IntToStr(LThird) + ']';
    Assert.AreEqual(LFirst + 1, LMinted,
      'the identity minted for the middle master must be the NEXT value of ' +
      'the MASTER sequence. Taking it from the child adapter sequence instead ' +
      'hands the master a number another master row can later be handed too, ' +
      'and issue #261 comes back through a collision rather than a zero' +
      LDump);
    Assert.AreEqual(LMinted + 1, LThird,
      'and the next live master must follow it, which is the same statement ' +
      'read from the other side: the mint has to CONSUME the master sequence, ' +
      'not merely produce a number that looks like one of its values' + LDump);
  finally
    DropTree(LRootTable, LMidTable, LLeafTable, LRoot, LMid, LLeaf);
  end;
end;

procedure TTestAutoIncDistribution.LinkedAsTheRestClientDoes_MintingDoesNotPostTheChild;
var
  LRootTable: TFDMemTable;
  LMidTable: TFDMemTable;
  LLeafTable: TFDMemTable;
  LRoot: TFDMemTableAdapter<TAitRoot>;
  LMid: TFDMemTableAdapter<TAitMid>;
  LLeaf: TFDMemTableAdapter<TAitLeaf>;
  LMute: TScrollMute;
  LState: TDataSetState;
begin
  // THE MASTER-DETAIL LINK, which the REST client installs on every child by
  // construction - TRESTFDMemTableAdapter<M> sets MasterSource, MasterFields
  // and IndexFieldNames on each child dataset, and TRESTClientDataSetAdapter<M>
  // does the same. No fixture in this suite had ever combined that link with a
  // master row carrying no identity, which is exactly the pair the mint needs.
  //
  // WHAT GOES WRONG WITHOUT THE FIX, out of the RTL of Studio 37.0. Writing on
  // the master row emits deDataSetChange - from the Post, and from
  // EnableControls when a control pair is used - which descends
  // TDataLink.DataEvent -> DataSetChanged -> RecordChanged(nil) ->
  // TMasterDataLink.RecordChanged -> FOnMasterChange -> the detail's
  // MasterChanged. A detail reached there in dsInsert and already Modified -
  // and it IS already Modified, because _StampRowTokens writes the child's own
  // RowToken before anything else - gets POSTED half typed.
  //
  // THIS FIXTURE DOES NOT DEMONSTRATE THAT, AND SAYS SO. TFDDataSet
  // .MasterChanged calls CheckMasterRange and NOT CheckBrowseMode, so the
  // FireDAC family never reaches the post THROUGH THIS LEG. It passes with the
  // mint in DoBeforeInsert and with the mint in DoNewRecord alike - measured.
  // It is kept as the record of that measurement and as a guard that the
  // FireDAC wiring itself stays harmless; the fixture that DOES discriminate is
  // ClientDataSetLinkedAsTheRestClientDoes_MintingDoesNotPostTheChild.
  //
  // THE THREE WORDS "THROUGH THIS LEG" ARE A CORRECTION, and it is left visible
  // like the one below it. This comment used to end at "never reaches the
  // post", full stop, and that generalisation is FALSE: it disposes of the
  // deDataSetChange leg only. The OTHER leg - Edit -> CheckBrowseMode ->
  // deCheckBrowseMode - reaches the FireDAC family too, because
  // TFDMasterDataLink.DataEvent steps aside on that event only when the detail
  // AND its own master are both in dsEditModes, which a level sitting in
  // dsBrowse is not. Measured with a three level FDMemTable tree in
  // FDMemTable_MintingWithAGrandchildRowOpen_DoesNotPostThatGrandchild: remove
  // the recursive descent from the guard and the FireDAC grandchild comes back
  // dsBrowse, posted half typed, exactly like the ClientDataSet one. Without
  // that fixture nothing would stop a later change from narrowing the guard to
  // the ClientDataSet family on the strength of the sentence above.
  //
  // An earlier revision of this comment blamed TFDMasterDataLink.DataEvent's
  // delayed-scroll branch for swallowing deCheckBrowseMode. That was wrong -
  // the branch tests Event in [deDataSetScroll, deDataSetChange], and needs
  // FetchOptions.DetailDelay > 0, default 0 - and the correction is left
  // visible rather than deleted.
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
    Assert.AreEqual(cNOTOKEN, TokenOfTaggedRow(LRootTable, cLOADEDTAG,
                                               cROWTOKEN),
      'PREMISE: the master must have no identity, or no mint happens and the ' +
      'link below is never exercised');
    Assert.IsTrue(LRootTable.State = dsBrowse,
      'PREMISE: and it must be in dsBrowse, which is the state the mint acts on');

    // Exactly the wiring TRESTFDMemTableAdapter<M> installs. Muted while it is
    // installed because setting the link re-ranges and therefore scrolls.
    LMute := MuteScroll(LMidTable);
    try
      LMidTable.MasterSource := TCascadeAccess<TAitRoot>.SourceOf(LRoot);
      LMidTable.IndexFieldNames := cKEY;
      LMidTable.MasterFields := cKEY;
    finally
      UnmuteScroll(LMidTable, LMute);
    end;
    Assert.IsNotNull(LMidTable.MasterSource,
      'PREMISE: the link must really be installed');

    LMidTable.Append;
    // CAPTURED, NOT ASSERTED HERE. The teardown of a linked pair is noisy
    // enough to raise on its own, and an exception there would be reported as
    // an ERROR and bury the measurement. The state is read the instant Append
    // returns and the clause that reads it sits after the cleanup.
    LState := LMidTable.State;
  finally
    // Teardown, and every line of it is an artefact of this fixture rather
    // than of anything under test. The half-typed row is abandoned first; then
    // the link comes down BEFORE the adapters are freed, because the
    // TDataSource it points at belongs to the master ADAPTER and DropTree
    // frees adapters first. Measured: with the mint disabled entirely this
    // fixture faulted on teardown just the same, which is how the fault was
    // told apart from the behaviour being measured.
    if LMidTable.State in [dsInsert, dsEdit] then
      LMidTable.Cancel;
    LMidTable.MasterFields := '';
    LMidTable.IndexFieldNames := '';
    LMidTable.MasterSource := nil;
    DropTree(LRootTable, LMidTable, LLeafTable, LRoot, LMid, LLeaf);
  end;

  Assert.IsTrue(LState = dsInsert,
    'the child must STILL be in dsInsert when Append returns. Anything the ' +
    'framework does to the MASTER row while the child sits half typed must ' +
    'not travel down the master-detail link and post it - the operator has ' +
    'not finished the row, and what reaches the database is whatever happened ' +
    'to be in the buffer at that instant. Measured state: ' +
    GetEnumName(TypeInfo(TDataSetState), Ord(LState)));
end;

procedure TTestAutoIncDistribution.ClientDataSetLinkedAsTheRestClientDoes_MintingDoesNotPostTheChild;
var
  LRootCds: TClientDataSet;
  LMidCds: TClientDataSet;
  LRoot: TClientDataSetAdapter<TAitRoot>;
  LMid: TClientDataSetAdapter<TAitMid>;
  LState: TDataSetState;
  LMute: TScrollMute;
begin
  // THE SAME SHAPE IN THE OTHER FAMILY, and it is not a spare copy - it is the
  // one that actually discriminates. TFDDataSet.MasterChanged calls
  // CheckMasterRange and NOT CheckBrowseMode, so the FireDAC twin above passes
  // under both placements of the mint and cannot tell them apart.
  // TCustomClientDataSet.MasterChanged calls CheckBrowseMode as its FIRST
  // statement, so this is where writing on the master row while a detail sits
  // half typed commits that detail.
  //
  // Move the _EnsureMasterRowToken call from DoBeforeInsert back to
  // DoNewRecord - which is where the child row is already dsInsert and already
  // Modified - and THIS fixture is the only red in the project, with
  // "Dataset not in edit or insert mode": the child was posted from inside its
  // own insert and the Cancel below then had nothing to cancel.
  LRootCds := TClientDataSet.Create(nil);
  LMidCds := TClientDataSet.Create(nil);
  try
    LRoot := TClientDataSetAdapter<TAitRoot>.Create(FConn, LRootCds, -1, nil);
    LMid := TClientDataSetAdapter<TAitMid>.Create(FConn, LMidCds, -1, LRoot);
    try
      TCascadeAccess<TAitRoot>.Mute(LRoot);
      try
        LRootCds.Append;
        LRootCds.FieldByName(cKEY).AsInteger := cLOADEDKEY;
        LRootCds.FieldByName(cTAG).AsString := cLOADEDTAG;
        LRootCds.Post;
      finally
        TCascadeAccess<TAitRoot>.Unmute(LRoot);
      end;
      Assert.AreEqual(cNOTOKEN, TokenOfTaggedRow(LRootCds, cLOADEDTAG,
                                                 cROWTOKEN),
        'PREMISE: the master must have no identity, or nothing is minted and ' +
        'the link below is never exercised');
      Assert.IsTrue(LRootCds.State = dsBrowse,
        'PREMISE: and it must be in dsBrowse, the state the mint acts on');

      LMute := MuteScroll(LMidCds);
      try
        LMidCds.MasterSource := TCascadeAccess<TAitRoot>.SourceOf(LRoot);
        LMidCds.IndexFieldNames := cKEY;
        LMidCds.MasterFields := cKEY;
      finally
        UnmuteScroll(LMidCds, LMute);
      end;
      Assert.IsNotNull(LMidCds.MasterSource,
        'PREMISE: the link must really be installed');

      LMidCds.Append;
      LState := LMidCds.State;
    finally
      // In the FINALLY, not in the body: on the red path the clause above
      // raises and everything after it is skipped, which would free the
      // master's TDataSource while the child still points at it and turn a
      // clean red into a teardown fault. The FireDAC twin already does this.
      if LMidCds.State in [dsInsert, dsEdit] then
        LMidCds.Cancel;
      LMidCds.MasterFields := '';
      LMidCds.IndexFieldNames := '';
      LMidCds.MasterSource := nil;
      LMid.Free;
      LRoot.Free;
    end;
  finally
    LMidCds.Free;
    LRootCds.Free;
  end;

  Assert.IsTrue(LState = dsInsert,
    'the child must STILL be in dsInsert when Append returns. Giving the ' +
    'master row an identity while a child sits half typed must not travel ' +
    'down the master-detail link and post it. Measured state: ' +
    GetEnumName(TypeInfo(TDataSetState), Ord(LState)));
end;

procedure TTestAutoIncDistribution.MintingWithASiblingChildMidInsert_DoesNotPostThatSibling;
var
  LRootCds: TClientDataSet;
  LMidCds: TClientDataSet;
  LOtherCds: TClientDataSet;
  LRoot: TClientDataSetAdapter<TAitRoot>;
  LMid: TClientDataSetAdapter<TAitMid>;
  LOther: TClientDataSetAdapter<TAitNoCascade>;
  LState: TDataSetState;
  LOtherToken: Integer;
  LMute: TScrollMute;

  procedure Wire(const AChild: TClientDataSet);
  var
    LM: TScrollMute;
  begin
    LM := MuteScroll(AChild);
    try
      AChild.MasterSource := TCascadeAccess<TAitRoot>.SourceOf(LRoot);
      AChild.IndexFieldNames := cKEY;
      AChild.MasterFields := cKEY;
    finally
      UnmuteScroll(AChild, LM);
    end;
  end;

begin
  // WHAT DEFENDS THE DisableControls PAIR, and it took a second child to build
  // it. With the mint called from DoBeforeInsert the child being typed is in
  // dsBrowse, so nothing the master emits can hurt IT - which is why removing
  // DisableControls reddened nothing and was briefly, and wrongly, labelled an
  // unmeasured guard. The row that CAN be hurt is a DIFFERENT child of the same
  // master, left half typed while the operator moves to another grid.
  //
  // THE TWO RTL LEGS THE PAIR SUPPRESSES, both reachable only from here:
  //   the Post on the master emits deDataSetChange -> TDataLink.DataEvent ->
  //   DataSetChanged -> RecordChanged(nil) -> TMasterDataLink.RecordChanged ->
  //   FOnMasterChange -> TCustomClientDataSet.MasterChanged, whose FIRST
  //   statement is CheckBrowseMode -> "if Modified then Post".
  // DisableControls does NOT close that: it suppresses the deCheckBrowseMode
  // leg of Edit, but EnableControls is itself what re-emits deDataSetChange,
  // and the Post emits it either way. Measured: the sibling was posted WITH
  // and WITHOUT the pair. So the shipped answer is not to blind the write but
  // to refuse it - see the sibling loop in _EnsureMasterRowToken - and there is
  // no DisableControls in the shipped method at all.
  //
  // The sibling is appended with ITS adapter muted so that its own
  // DoBeforeInsert does not mint first - the mint fires once per untokenised
  // master row, and this test needs it to fire while the sibling is already
  // sitting in dsInsert.
  LRootCds := TClientDataSet.Create(nil);
  LMidCds := TClientDataSet.Create(nil);
  LOtherCds := TClientDataSet.Create(nil);
  try
    LRoot := TClientDataSetAdapter<TAitRoot>.Create(FConn, LRootCds, -1, nil);
    LMid := TClientDataSetAdapter<TAitMid>.Create(FConn, LMidCds, -1, LRoot);
    LOther := TClientDataSetAdapter<TAitNoCascade>.Create(FConn, LOtherCds, -1,
                LRoot);
    try
      TCascadeAccess<TAitRoot>.Mute(LRoot);
      try
        LRootCds.Append;
        LRootCds.FieldByName(cKEY).AsInteger := cLOADEDKEY;
        LRootCds.FieldByName(cTAG).AsString := cLOADEDTAG;
        LRootCds.Post;
      finally
        TCascadeAccess<TAitRoot>.Unmute(LRoot);
      end;
      Assert.AreEqual(cNOTOKEN, TokenOfTaggedRow(LRootCds, cLOADEDTAG,
                                                 cROWTOKEN),
        'PREMISE: the master must be untokenised, or no mint fires at all');

      Wire(LMidCds);
      Wire(LOtherCds);

      // The SIBLING, left open and Modified. Muted so it does not mint.
      TCascadeAccess<TAitMid>.Mute(LMid);
      try
        LMidCds.Append;
        LMidCds.FieldByName(cTAG).AsString := 'HALF';
      finally
        TCascadeAccess<TAitMid>.Unmute(LMid);
      end;
      Assert.IsTrue(LMidCds.State = dsInsert,
        'PREMISE: the sibling must be sitting in dsInsert');
      Assert.IsTrue(LMidCds.Modified,
        'PREMISE: and Modified, or CheckBrowseMode would Cancel it rather ' +
        'than Post it and this test would measure the wrong branch');

      // Now the mint fires, from the OTHER child.
      LOtherCds.Append;
      LState := LMidCds.State;
      LOtherToken := LOtherCds.FieldByName(cOWNERTOKEN).AsInteger;
      if LOtherCds.State in [dsInsert, dsEdit] then
        LOtherCds.Cancel;
      if LMidCds.State in [dsInsert, dsEdit] then
        LMidCds.Cancel;
    finally
      LMidCds.MasterFields := '';
      LMidCds.IndexFieldNames := '';
      LMidCds.MasterSource := nil;
      LOtherCds.MasterFields := '';
      LOtherCds.IndexFieldNames := '';
      LOtherCds.MasterSource := nil;
      LOther.Free;
      LMid.Free;
      LRoot.Free;
    end;
  finally
    LOtherCds.Free;
    LMidCds.Free;
    LRootCds.Free;
  end;

  Assert.IsTrue(LState = dsInsert,
    'the sibling must STILL be sitting in dsInsert. Writing an identity on ' +
    'the master row may not reach a half typed row in another detail and ' +
    'commit it - what would go to the database is whatever the operator had ' +
    'got to. Measured state: ' +
    GetEnumName(TypeInfo(TDataSetState), Ord(LState)));
  // STATE FIRST, PRICE SECOND, which is the convention this file already
  // legislates and this fixture was the only one outside it. The sentence is in
  // MintingWithAGrandchildRowOpen_DoesNotPostThatGrandchild, on its own price
  // clause: "It is asserted SECOND on purpose - the state clause carries the
  // measured state in its message and DUnitX stops at the first failing one".
  // With the price asserted first this fixture failed on
  // "Expected [0] but got [33]" and never printed a state at all. Worse than
  // terse: 33 asserts THE MINT FIRED, which is not the same proposition as THE
  // SIBLING WAS POSTED. In a regression where the mint fires and the sibling
  // survives for some other reason, that message would send the reader to the
  // wrong place. The state clause names what this fixture is about.
  Assert.AreEqual(cNOTOKEN, LOtherToken,
    'and the child that was being typed records NO parentage - refusing to ' +
    'write is how the sibling is protected, so the price is paid here and is ' +
    'stated rather than hidden: that child falls back to the historical ' +
    'behaviour');
end;

procedure TTestAutoIncDistribution.ChildTypedUnderAMutedMasterStillInserting_RecordsNoParentage;
var
  LRootTable: TFDMemTable;
  LMidTable: TFDMemTable;
  LLeafTable: TFDMemTable;
  LRoot: TFDMemTableAdapter<TAitRoot>;
  LMid: TFDMemTableAdapter<TAitMid>;
  LLeaf: TFDMemTableAdapter<TAitLeaf>;
  LRows: Integer;
begin
  // THE LAST PRODUCER OF A ZERO PARENTAGE, and the one the enumeration in
  // _EnsureMasterRowToken kept implicit. The state guard there is
  // "State <> dsBrowse", which is not a synonym for dsEdit: it also covers a
  // master row that is STILL BEING INSERTED. Reached by combining the two
  // things the other fixtures reach separately - a muted append, so there is no
  // identity to read, and NO Post, so the row is not in dsBrowse either.
  //
  // WHY MINTING IS REFUSED HERE RATHER THAN DONE. Writing into an insertion
  // buffer that the caller has not committed is the same hazard as the empty
  // master one level down: the value would ride out on somebody else's Post, or
  // vanish on their Cancel, and either way the child would be naming an
  // identity the master no longer carries. So the answer is cNoRowToken and the
  // child falls back to the behaviour that shipped.
  //
  // ITS LIVE TWIN IS NOT THIS. ChildTypedBeforeItsMasterRowIsPosted_StillReceivesTheKey
  // has the master mid-insert too, but with the adapter LIVE - so DoNewRecord
  // already stamped that row and _EnsureMasterRowToken returns the identity it
  // finds without writing anything. The two together are what say that the
  // refusal is about the MISSING identity plus the state, not about the state
  // alone.
  BuildTree(FConn, LRootTable, LMidTable, LLeafTable, LRoot, LMid, LLeaf);
  try
    TCascadeAccess<TAitRoot>.Mute(LRoot);
    try
      LRootTable.Append;
      LRootTable.FieldByName(cKEY).AsInteger := cLOADEDKEY;
      LRootTable.FieldByName(cTAG).AsString := cLOADEDTAG;
      // NOT posted, and the adapter stays muted for the child append below so
      // that nothing re-enters and quietly commits it.
      Assert.IsTrue(LRootTable.State = dsInsert,
        'PREMISE: the master must be mid-insert');
      LRows := LRootTable.RecordCount;

      LMidTable.Append;
      LMidTable.FieldByName(cOWNKEY).AsInteger := 0;
      LMidTable.FieldByName(cTAG).AsString := 'C0';
      LMidTable.Post;
    finally
      TCascadeAccess<TAitRoot>.Unmute(LRoot);
    end;

    Assert.IsTrue(LRootTable.State = dsInsert,
      'the master must STILL be mid-insert - nothing may have committed it on ' +
      'the operator behalf');
    Assert.AreEqual(LRows, LRootTable.RecordCount,
      'and no row may have been added to the master table');
    Assert.AreEqual(cNOTOKEN, TokenOfTaggedRow(LMidTable, 'C0', cOWNERTOKEN),
      'while the child records NO parentage: there was no identity to read ' +
      'and the row was in no state to receive one, so this falls back to the ' +
      'historical behaviour. THIS IS A DECLARED LIMIT, not a fix - a child ' +
      'typed here is still claimable by THE pending master when there is one, ' +
      'as it was before issue #265, and by NONE when there is more than one, ' +
      'which is the boundary issue #261 put on that fallback');
    if LRootTable.State in [dsInsert, dsEdit] then
      LRootTable.Cancel;
  finally
    DropTree(LRootTable, LMidTable, LLeafTable, LRoot, LMid, LLeaf);
  end;
end;

procedure TTestAutoIncDistribution.MintingWithAGrandchildRowOpen_DoesNotPostThatGrandchild;
var
  LRootCds: TClientDataSet;
  LMidCds: TClientDataSet;
  LLeafCds: TClientDataSet;
  LOtherCds: TClientDataSet;
  LRoot: TClientDataSetAdapter<TAitRoot>;
  LMid: TClientDataSetAdapter<TAitMid>;
  LLeaf: TClientDataSetAdapter<TAitLeaf>;
  LOther: TClientDataSetAdapter<TAitNoCascade>;
  LState: TDataSetState;
  LOtherToken: Integer;

  procedure Wire(const AChild: TClientDataSet; const ASource: TDataSource;
    const AField: String);
  var
    LM: TScrollMute;
  begin
    LM := MuteScroll(AChild);
    try
      AChild.MasterSource := ASource;
      AChild.IndexFieldNames := AField;
      AChild.MasterFields := AField;
    finally
      UnmuteScroll(AChild, LM);
    end;
  end;

begin
  // THE CASCADE IS RECURSIVE AND THE REFUSAL HAS TO BE TOO. Data.DB.pas,
  // TDataSet.CheckBrowseMode, emits deCheckBrowseMode and THEN inspects its own
  // state - so the mid level being in dsBrowse stops nothing: its
  // CheckBrowseMode still emits the event to ITS data sources, reaching
  // TMasterDataLink.CheckBrowseMode of the leaf, and there
  // "if Modified then Post" commits a grandchild row the operator had open.
  //
  // WHY THIS IS OURS TO FIX AND NOT A LIMIT TO DECLARE. Against origin/develop
  // nothing writes on the master row at all, so nothing cascades: this is a
  // defect the mint INTRODUCES. Three-level trees are first class here -
  // BuildTree makes one - and the REST client installs MasterSource at every
  // level by construction.
  //
  // ClientDataSet family, because that is the one where MasterChanged reaches
  // CheckBrowseMode - see the twin fixtures above.
  LRootCds := TClientDataSet.Create(nil);
  LMidCds := TClientDataSet.Create(nil);
  LLeafCds := TClientDataSet.Create(nil);
  LOtherCds := TClientDataSet.Create(nil);
  try
    LRoot := TClientDataSetAdapter<TAitRoot>.Create(FConn, LRootCds, -1, nil);
    LMid := TClientDataSetAdapter<TAitMid>.Create(FConn, LMidCds, -1, LRoot);
    LLeaf := TClientDataSetAdapter<TAitLeaf>.Create(FConn, LLeafCds, -1, LMid);
    LOther := TClientDataSetAdapter<TAitNoCascade>.Create(FConn, LOtherCds, -1,
                LRoot);
    try
      TCascadeAccess<TAitRoot>.Mute(LRoot);
      try
        LRootCds.Append;
        LRootCds.FieldByName(cKEY).AsInteger := cLOADEDKEY;
        LRootCds.FieldByName(cTAG).AsString := cLOADEDTAG;
        LRootCds.Post;
      finally
        TCascadeAccess<TAitRoot>.Unmute(LRoot);
      end;
      Assert.AreEqual(cNOTOKEN, TokenOfTaggedRow(LRootCds, cLOADEDTAG,
                                                 cROWTOKEN),
        'PREMISE: the root must be untokenised, or no mint fires at all');

      Wire(LMidCds, TCascadeAccess<TAitRoot>.SourceOf(LRoot), cKEY);
      Wire(LLeafCds, TCascadeAccess<TAitMid>.SourceOf(LMid), cOWNKEY);
      Wire(LOtherCds, TCascadeAccess<TAitRoot>.SourceOf(LRoot), cKEY);
      // ASSERTED, not merely installed. Three links carry this fixture, and a
      // link that quietly failed to establish would leave it green measuring
      // nothing - the grandchild would survive because nothing could reach it,
      // which is the reading this fixture exists to exclude.
      Assert.IsNotNull(LMidCds.MasterSource,
        'PREMISE: the root -> mid link must really be installed');
      Assert.IsNotNull(LLeafCds.MasterSource,
        'PREMISE: the mid -> leaf link must really be installed - it carries ' +
        'the second hop, which is the whole subject here');
      Assert.IsNotNull(LOtherCds.MasterSource,
        'PREMISE: and the root -> other link, which is what lets the mint fire ' +
        'from a branch with no details of its own');

      // A mid row for the leaf to hang under. Muted so it does not mint.
      TCascadeAccess<TAitMid>.Mute(LMid);
      try
        LMidCds.Append;
        LMidCds.FieldByName(cKEY).AsInteger := cLOADEDKEY;
        LMidCds.FieldByName(cOWNKEY).AsInteger := cMIDFIRST;
        LMidCds.FieldByName(cTAG).AsString := 'M0';
        LMidCds.Post;
      finally
        TCascadeAccess<TAitMid>.Unmute(LMid);
      end;

      // THE GRANDCHILD, left open and Modified. Muted so it does not mint.
      TCascadeAccess<TAitLeaf>.Mute(LLeaf);
      try
        LLeafCds.Append;
        // Every NotNull column filled, so that a Post which SHOULD NOT happen
        // fails this test on its state clause instead of erroring on
        // validation. The first run of this fixture did error that way, which
        // is the same finding read through a worse message.
        LLeafCds.FieldByName(cKEY).AsInteger := cLOADEDKEY;
        LLeafCds.FieldByName(cOWNKEY).AsInteger := cMIDFIRST;
        LLeafCds.FieldByName(cTAG).AsString := 'HALF';
      finally
        TCascadeAccess<TAitLeaf>.Unmute(LLeaf);
      end;
      Assert.IsTrue(LLeafCds.State = dsInsert,
        'PREMISE: the grandchild must be sitting in dsInsert');
      Assert.IsTrue(LLeafCds.Modified,
        'PREMISE: and Modified, or CheckBrowseMode would Cancel it instead of ' +
        'Posting it and this test would measure the wrong branch');
      Assert.IsTrue(LMidCds.State = dsBrowse,
        'PREMISE: and the MID level must be in dsBrowse - that is the whole ' +
        'point, a one level refusal looks at the mid, sees nothing open, and ' +
        'lets the write through');

      // THE MINT FIRES FROM THE OTHER BRANCH, and it has to. Appending to the
      // MID would post the grandchild all by itself, with or without any mint:
      // BeginInsertAppend runs CheckBrowseMode on the mid BEFORE DoBeforeInsert,
      // and that CheckBrowseMode is already the top of the cascade. Measured -
      // the first version of this fixture did exactly that and was red against
      // origin/develop too, which would have made it evidence of nothing.
      // TAitNoCascade is the root's OTHER child and has no details of its own,
      // so its own Append cascades nowhere and the ONLY thing that can reach
      // the open grandchild is the write the mint makes on the root row.
      LOtherCds.Append;
      LState := LLeafCds.State;
      LOtherToken := LOtherCds.FieldByName(cOWNERTOKEN).AsInteger;
    finally
      // Links down BEFORE anything else, deepest first. Cancelling a row while
      // its dataset is still ranged against a master re-enters the ranging and
      // raises on its own, which would mask the state clause below with a
      // teardown error - measured, twice.
      LLeafCds.MasterFields := '';
      LLeafCds.IndexFieldNames := '';
      LLeafCds.MasterSource := nil;
      LMidCds.MasterFields := '';
      LMidCds.IndexFieldNames := '';
      LMidCds.MasterSource := nil;
      LOtherCds.MasterFields := '';
      LOtherCds.IndexFieldNames := '';
      LOtherCds.MasterSource := nil;
      if LOtherCds.State in [dsInsert, dsEdit] then
        LOtherCds.Cancel;
      if LLeafCds.State in [dsInsert, dsEdit] then
        LLeafCds.Cancel;
      if LMidCds.State in [dsInsert, dsEdit] then
        LMidCds.Cancel;
      LOther.Free;
      LLeaf.Free;
      LMid.Free;
      LRoot.Free;
    end;
  finally
    LOtherCds.Free;
    LLeafCds.Free;
    LMidCds.Free;
    LRootCds.Free;
  end;

  Assert.IsTrue(LState = dsInsert,
    'the GRANDCHILD must still be sitting in dsInsert. deCheckBrowseMode does ' +
    'not stop at the level below the master - every CheckBrowseMode it ' +
    'triggers emits it again - so a refusal that only inspects the direct ' +
    'children lets the write through and the row two levels down is committed ' +
    'half typed. Measured state: ' +
    GetEnumName(TypeInfo(TDataSetState), Ord(LState)));
  Assert.AreEqual(cNOTOKEN, LOtherToken,
    'and the child being typed records NO parentage. Without this clause the ' +
    'fixture cannot tell "the grandchild survived because we refused" from ' +
    '"the grandchild survived because nothing reached it": the refusal is ' +
    'what has to be visible, and its price is paid right here. It is asserted ' +
    'SECOND on purpose - the state clause carries the measured state in its ' +
    'message and DUnitX stops at the first failing one');
end;

procedure TTestAutoIncDistribution.FDMemTable_MintingWithASiblingChildMidInsert_DoesNotPostThatSibling;
var
  LRootTable: TFDMemTable;
  LMidTable: TFDMemTable;
  LOtherTable: TFDMemTable;
  LRoot: TFDMemTableAdapter<TAitRoot>;
  LMid: TFDMemTableAdapter<TAitMid>;
  LOther: TFDMemTableAdapter<TAitNoCascade>;
  LState: TDataSetState;
  LOtherToken: Integer;
  LRootToken: Integer;
  LRows: Integer;
  LTag: String;

  procedure Wire(const AChild: TFDMemTable);
  var
    LM: TScrollMute;
  begin
    LM := MuteScroll(AChild);
    try
      AChild.MasterSource := TCascadeAccess<TAitRoot>.SourceOf(LRoot);
      AChild.IndexFieldNames := cKEY;
      AChild.MasterFields := cKEY;
    finally
      UnmuteScroll(AChild, LM);
    end;
  end;

begin
  // THE ONE LEVEL SHAPE IN THE FIREDAC FAMILY, which was the last shape of this
  // guard carrying no measurement of its own. The three level twin,
  // FDMemTable_MintingWithAGrandchildRowOpen_DoesNotPostThatGrandchild, showed
  // the deCheckBrowseMode leg reaches FireDAC through a mid level sitting in
  // dsBrowse, and that left the SIBLING shape as a reading rather than a
  // result. The gap is not academic: the sibling clause of the refusal shipped
  // FIRST and the recursive descent was added after it, so the only FireDAC
  // evidence in the file was evidence about the descent, and a later change
  // could have narrowed the sibling clause to the ClientDataSet family with
  // nothing going red.
  //
  // THE READING, out of the RTL of Studio 37.0, and it holds - anchored by
  // method, as everything here is:
  //
  //   Data.DB.pas, TDataSet.Edit, calls CheckBrowseMode BEFORE SetState(dsEdit),
  //   so the master is still in dsBrowse at that instant. TDataSet
  //   .CheckBrowseMode emits deCheckBrowseMode, TDataSet.DataEvent hands it to
  //   every TDataSource of the master, and it arrives at
  //   FireDAC.Comp.DataSet.pas, TFDMasterDataLink.DataEvent. That method
  //   returns early on this event ONLY when DetailDataSet.State and
  //   DataSet.State are BOTH in dsEditModes - DataSet being the link's own
  //   DataSource dataset, that is, the MASTER. Here the sibling is in dsInsert
  //   and the master is in dsBrowse, so the early return does NOT fire: it
  //   calls inherited, TDataLink.DataEvent maps deCheckBrowseMode onto
  //   CheckBrowseMode, TMasterDataLink.CheckBrowseMode runs the SIBLING's own
  //   CheckBrowseMode, and "if Modified then Post" commits the row the operator
  //   had open.
  //
  // THE FIREDAC FAMILY HAS TWO MITIGATIONS OF ITS OWN, NOT ONE, and an earlier
  // wording of this comment named only the first. It said the isolation that
  // family gets is "exactly ONE leg wide", meaning the deDataSetChange leg,
  // which dies at TFDDataSet.MasterChanged because that method calls
  // CheckMasterRange and not CheckBrowseMode - see
  // LinkedAsTheRestClientDoes_MintingDoesNotPostTheChild. That is true, and it
  // is not the whole count.
  //
  // THE SECOND ONE IS THE EXEMPTION ITSELF, ON THE OTHER HALF OF THE MINT. The
  // write is Edit, assign, Post. Data.DB.pas, TDataSet.Post, runs UpdateRecord
  // and then emits deCheckBrowseMode from INSIDE its dsEdit/dsInsert branch,
  // before SetState(dsBrowse) - so at that instant the MASTER is in dsEdit.
  // Both halves of the test in TFDMasterDataLink.DataEvent are then satisfied
  // for any detail still sitting in dsEditModes, the early return DOES fire,
  // and that detail is spared. The ClientDataSet family has no counterpart:
  // TMasterDataLink in Data.DB.pas does not override DataEvent at all, so the
  // event reaches TDataLink.DataEvent and is mapped onto CheckBrowseMode with
  // no exception of any kind.
  //
  // AND IT SAVES NOTHING HERE, which is why the correction changes no verdict.
  // The damage has already entered through the Edit one line earlier:
  // TDataSet.Edit runs CheckBrowseMode BEFORE SetState(dsEdit), so on THAT
  // emission the master is still in dsBrowse, the exemption does not fire, and
  // the sibling is posted. By the time the Post leg comes round with its
  // exemption armed, there is no open row left for it to spare. The claim this
  // fixture measures is therefore correctly scoped to TDataSet.Edit, and it
  // does not need a mid level to get through: one hop is enough, because the
  // ONLY state that would earn the early return is the master's own, and the
  // master cannot be mid-edit at the instant it is about to enter dsEdit.
  //
  // MEASURED BY MUTATION AND NOT BY VERSION, because the clause it defends is
  // already shipped and this fixture is therefore green as it stands. Remove
  // the "State in dsEditModes" test from _AnyDetailRowOpen and it reports
  // "Measured state: dsBrowse": the half typed sibling was POSTED by a write
  // nobody asked for. It is green against the commit before issue #265 as well,
  // where nothing is minted at all and so nothing can reach the sibling - which
  // is what says it measures the mint and not the wiring.
  //
  // THE MINT FIRES FROM THE OTHER BRANCH, for the reason both twins give:
  // appending to the MID would post its own open row through the
  // CheckBrowseMode that BeginInsertAppend runs before DoBeforeInsert, with or
  // without any mint, and the fixture would be red against every version and
  // evidence of nothing. TAitNoCascade has no details of its own.
  LRootTable := TFDMemTable.Create(nil);
  LMidTable := TFDMemTable.Create(nil);
  LOtherTable := TFDMemTable.Create(nil);
  try
    LRoot := TFDMemTableAdapter<TAitRoot>.Create(FConn, LRootTable, -1, nil);
    LMid := TFDMemTableAdapter<TAitMid>.Create(FConn, LMidTable, -1, LRoot);
    LOther := TFDMemTableAdapter<TAitNoCascade>.Create(FConn, LOtherTable, -1,
                LRoot);
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
      Assert.AreEqual(cNOTOKEN, TokenOfTaggedRow(LRootTable, cLOADEDTAG,
                                                 cROWTOKEN),
        'PREMISE: the master must be untokenised, or no mint fires at all');

      Wire(LMidTable);
      Wire(LOtherTable);
      // ASSERTED, not merely installed. Two links carry this fixture and each
      // carries a different half: without the first one nothing can reach the
      // sibling and the whole thing would be green measuring nothing, and
      // without the second the mint never fires and there is no write to
      // survive.
      Assert.IsNotNull(LMidTable.MasterSource,
        'PREMISE: the root -> sibling link must really be installed - it is ' +
        'the only thing that can carry deCheckBrowseMode to the open row');
      Assert.IsNotNull(LOtherTable.MasterSource,
        'PREMISE: and the root -> other link, which is what lets the mint ' +
        'fire from a branch with no details of its own');

      // THE SIBLING, left open and Modified. Muted so it does not mint first -
      // the mint fires once per untokenised master row, and this fixture needs
      // it to fire while the sibling is ALREADY sitting in dsInsert.
      TCascadeAccess<TAitMid>.Mute(LMid);
      try
        LMidTable.Append;
        // Every NotNull column filled, so a Post that SHOULD NOT happen fails
        // this test on its state clause instead of erroring on validation.
        LMidTable.FieldByName(cKEY).AsInteger := cLOADEDKEY;
        LMidTable.FieldByName(cOWNKEY).AsInteger := cMIDFIRST;
        LMidTable.FieldByName(cTAG).AsString := 'HALF';
      finally
        TCascadeAccess<TAitMid>.Unmute(LMid);
      end;
      Assert.IsTrue(LMidTable.State = dsInsert,
        'PREMISE: the sibling must be sitting in dsInsert');
      Assert.IsTrue(LMidTable.Modified,
        'PREMISE: and Modified, or CheckBrowseMode would Cancel it rather ' +
        'than Post it and this test would measure the wrong branch');
      Assert.IsTrue(LRootTable.State = dsBrowse,
        'PREMISE: and the MASTER must be in dsBrowse - that is the level that ' +
        'would have to be mid-edit for TFDMasterDataLink.DataEvent to step ' +
        'aside on deCheckBrowseMode, and it never is at the instant Edit runs ' +
        'CheckBrowseMode');

      LOtherTable.Append;
      LState := LMidTable.State;
      // POST OR CANCEL, and the state alone does not say which. dsBrowse is
      // where BOTH exits land, so "Measured state: dsBrowse" on its own is
      // consistent with the row having been thrown away as well as with it
      // having been written out. These two go into the MESSAGE of the state
      // clause rather than into a clause of their own, and the reason is that a
      // clause of their own could not earn its place: State = dsInsert already
      // entails that no Post happened, so a row-count assertion can never be
      // the first to fail, and asserted after the state clause DUnitX would
      // never reach it. In the message they cost no assertion and they land
      // exactly where the question gets asked - in the red. Measured under the
      // mutation that narrows the direct-child test to the ClientDataSet
      // family: rows 1, tag HALF. The row was WRITTEN, not discarded.
      LRows := LMidTable.RecordCount;
      if LMidTable.IsEmpty then
        LTag := '<empty>'
      else
        LTag := LMidTable.FieldByName(cTAG).AsString;
      LOtherToken := LOtherTable.FieldByName(cOWNERTOKEN).AsInteger;
      LRootToken := LRootTable.FieldByName(cROWTOKEN).AsInteger;
    finally
      // Links down BEFORE anything else - cancelling a row while its dataset is
      // still ranged against a master re-enters the ranging and raises on its
      // own, which would mask the state clause below with a teardown error.
      LMidTable.MasterFields := '';
      LMidTable.IndexFieldNames := '';
      LMidTable.MasterSource := nil;
      LOtherTable.MasterFields := '';
      LOtherTable.IndexFieldNames := '';
      LOtherTable.MasterSource := nil;
      if LOtherTable.State in [dsInsert, dsEdit] then
        LOtherTable.Cancel;
      if LMidTable.State in [dsInsert, dsEdit] then
        LMidTable.Cancel;
      LOther.Free;
      LMid.Free;
      LRoot.Free;
    end;
  finally
    LOtherTable.Free;
    LMidTable.Free;
    LRootTable.Free;
  end;

  Assert.IsTrue(LState = dsInsert,
    'the SIBLING must still be sitting in dsInsert, in the FIREDAC family too ' +
    'and at ONE level, not only at three. TFDMasterDataLink only steps out of ' +
    'the way of deCheckBrowseMode when the detail AND its own master are both ' +
    'mid-edit, and a master about to enter dsEdit is in dsBrowse - so writing ' +
    'an identity on the master row reaches a half typed row in another detail ' +
    'and commits whatever the operator had got to. Measured state: ' +
    GetEnumName(TypeInfo(TDataSetState), Ord(LState)) +
    ', saved rows in the sibling table: ' + IntToStr(LRows) +
    ', tag on its current row: ' + LTag +
    ' - which is what tells a POST from a CANCEL, since both of them land in ' +
    'dsBrowse and only one of them writes the half typed row out');
  Assert.AreEqual(cNOTOKEN, LOtherToken,
    'and the child being typed records NO parentage - the price of refusing ' +
    'the write, stated rather than hidden: that child falls back to the ' +
    'historical behaviour');
  Assert.AreEqual(cNOTOKEN, LRootToken,
    'and the MASTER ROW still carries no identity, which is the refusal read ' +
    'at its source. Without these two clauses, "the sibling survived because ' +
    'we refused to write" and "the sibling survived because nothing could ' +
    'reach it" are the same green');
end;

procedure TTestAutoIncDistribution.FDMemTable_MintingWithAGrandchildRowOpen_DoesNotPostThatGrandchild;
var
  LRootTable: TFDMemTable;
  LMidTable: TFDMemTable;
  LLeafTable: TFDMemTable;
  LOtherTable: TFDMemTable;
  LRoot: TFDMemTableAdapter<TAitRoot>;
  LMid: TFDMemTableAdapter<TAitMid>;
  LLeaf: TFDMemTableAdapter<TAitLeaf>;
  LOther: TFDMemTableAdapter<TAitNoCascade>;
  LState: TDataSetState;
  LOtherToken: Integer;
  LRows: Integer;
  LTag: String;

  procedure Wire(const AChild: TFDMemTable; const ASource: TDataSource;
    const AField: String);
  var
    LM: TScrollMute;
  begin
    LM := MuteScroll(AChild);
    try
      AChild.MasterSource := ASource;
      AChild.IndexFieldNames := AField;
      AChild.MasterFields := AField;
    finally
      UnmuteScroll(AChild, LM);
    end;
  end;

begin
  // THE FIREDAC FAMILY IS AFFECTED TOO, AND THE SENTENCE THAT SAID OTHERWISE
  // WAS TOO BROAD. LinkedAsTheRestClientDoes_MintingDoesNotPostTheChild says
  // TFDDataSet.MasterChanged calls CheckMasterRange and not CheckBrowseMode,
  // "so the FireDAC family never reaches the post". The premise is right and
  // the conclusion is not: it disposes of ONE of the two legs. The other leg
  // reaches the FireDAC family exactly as it reaches the ClientDataSet one, and
  // a three level tree is where it shows:
  //
  //   Data.DB.pas, TDataSet.Edit -> CheckBrowseMode ->
  //   DataEvent(deCheckBrowseMode) -> FireDAC.Comp.DataSet.pas,
  //   TFDMasterDataLink.DataEvent, which returns early on that event ONLY when
  //   the detail AND its own master are BOTH in dsEditModes. Here the mid is in
  //   dsBrowse, so it does not: it calls inherited, TMasterDataLink
  //   .CheckBrowseMode runs the MID's CheckBrowseMode, that one emits
  //   deCheckBrowseMode onwards, and the LEAF's link is reached with the leaf
  //   in dsInsert and ITS master - the mid - in dsBrowse, so it does not return
  //   early either. "if Modified then Post" then commits a grandchild row the
  //   operator had open.
  //
  // WHY IT IS PERMANENT AND NOT A PROBE. The sentence it corrects is an
  // invitation to narrow the guard to the ClientDataSet family, and nothing
  // else in this project would go red if someone accepted it. This is the twin
  // of MintingWithAGrandchildRowOpen_DoesNotPostThatGrandchild, in the family
  // that was claimed to be out of reach.
  LRootTable := TFDMemTable.Create(nil);
  LMidTable := TFDMemTable.Create(nil);
  LLeafTable := TFDMemTable.Create(nil);
  LOtherTable := TFDMemTable.Create(nil);
  try
    LRoot := TFDMemTableAdapter<TAitRoot>.Create(FConn, LRootTable, -1, nil);
    LMid := TFDMemTableAdapter<TAitMid>.Create(FConn, LMidTable, -1, LRoot);
    LLeaf := TFDMemTableAdapter<TAitLeaf>.Create(FConn, LLeafTable, -1, LMid);
    LOther := TFDMemTableAdapter<TAitNoCascade>.Create(FConn, LOtherTable, -1,
                LRoot);
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
      Assert.AreEqual(cNOTOKEN, TokenOfTaggedRow(LRootTable, cLOADEDTAG,
                                                 cROWTOKEN),
        'PREMISE: the root must be untokenised, or no mint fires at all');

      Wire(LMidTable, TCascadeAccess<TAitRoot>.SourceOf(LRoot), cKEY);
      Wire(LLeafTable, TCascadeAccess<TAitMid>.SourceOf(LMid), cOWNKEY);
      Wire(LOtherTable, TCascadeAccess<TAitRoot>.SourceOf(LRoot), cKEY);
      // ASSERTED, not merely installed. Three links carry this fixture, and a
      // link that quietly failed to establish would leave it green measuring
      // nothing - the grandchild would survive because nothing could reach it.
      Assert.IsNotNull(LMidTable.MasterSource,
        'PREMISE: the root -> mid link must really be installed');
      Assert.IsNotNull(LLeafTable.MasterSource,
        'PREMISE: the mid -> leaf link must really be installed - it carries ' +
        'the second hop this fixture exists for');
      Assert.IsNotNull(LOtherTable.MasterSource,
        'PREMISE: and the root -> other link, which is what lets the mint fire ' +
        'from a branch with no details of its own');

      // A mid row for the leaf to hang under. Muted so it does not mint.
      TCascadeAccess<TAitMid>.Mute(LMid);
      try
        LMidTable.Append;
        LMidTable.FieldByName(cKEY).AsInteger := cLOADEDKEY;
        LMidTable.FieldByName(cOWNKEY).AsInteger := cMIDFIRST;
        LMidTable.FieldByName(cTAG).AsString := 'M0';
        LMidTable.Post;
      finally
        TCascadeAccess<TAitMid>.Unmute(LMid);
      end;

      // THE GRANDCHILD, left open and Modified. Muted so it does not mint.
      TCascadeAccess<TAitLeaf>.Mute(LLeaf);
      try
        LLeafTable.Append;
        // Every NotNull column filled, so a Post that SHOULD NOT happen fails
        // this test on its state clause instead of erroring on validation.
        LLeafTable.FieldByName(cKEY).AsInteger := cLOADEDKEY;
        LLeafTable.FieldByName(cOWNKEY).AsInteger := cMIDFIRST;
        LLeafTable.FieldByName(cTAG).AsString := 'HALF';
      finally
        TCascadeAccess<TAitLeaf>.Unmute(LLeaf);
      end;
      Assert.IsTrue(LLeafTable.State = dsInsert,
        'PREMISE: the grandchild must be sitting in dsInsert');
      Assert.IsTrue(LLeafTable.Modified,
        'PREMISE: and Modified, or CheckBrowseMode would Cancel it instead of ' +
        'Posting it and this test would measure the wrong branch');
      Assert.IsTrue(LMidTable.State = dsBrowse,
        'PREMISE: and the MID level must be in dsBrowse - which is also what ' +
        'keeps TFDMasterDataLink.DataEvent from returning early, since that ' +
        'early return needs the detail AND its master both in dsEditModes');

      // THE MINT FIRES FROM THE OTHER BRANCH, for the same reason as in the
      // ClientDataSet twin: appending to the MID would post the grandchild all
      // by itself, since BeginInsertAppend runs CheckBrowseMode on the mid
      // before DoBeforeInsert. TAitNoCascade has no details of its own.
      LOtherTable.Append;
      LState := LLeafTable.State;
      // POST OR CANCEL - see the note in the one level twin. dsBrowse is where
      // both exits land, so the count and the tag ride in the MESSAGE of the
      // state clause instead of in a clause that could never fail first.
      LRows := LLeafTable.RecordCount;
      if LLeafTable.IsEmpty then
        LTag := '<empty>'
      else
        LTag := LLeafTable.FieldByName(cTAG).AsString;
      LOtherToken := LOtherTable.FieldByName(cOWNERTOKEN).AsInteger;
    finally
      // Links down BEFORE anything else, deepest first - cancelling a row while
      // its dataset is still ranged re-enters the ranging and raises on its own.
      LLeafTable.MasterFields := '';
      LLeafTable.IndexFieldNames := '';
      LLeafTable.MasterSource := nil;
      LMidTable.MasterFields := '';
      LMidTable.IndexFieldNames := '';
      LMidTable.MasterSource := nil;
      LOtherTable.MasterFields := '';
      LOtherTable.IndexFieldNames := '';
      LOtherTable.MasterSource := nil;
      if LOtherTable.State in [dsInsert, dsEdit] then
        LOtherTable.Cancel;
      if LLeafTable.State in [dsInsert, dsEdit] then
        LLeafTable.Cancel;
      if LMidTable.State in [dsInsert, dsEdit] then
        LMidTable.Cancel;
      LOther.Free;
      LLeaf.Free;
      LMid.Free;
      LRoot.Free;
    end;
  finally
    LOtherTable.Free;
    LLeafTable.Free;
    LMidTable.Free;
    LRootTable.Free;
  end;

  Assert.IsTrue(LState = dsInsert,
    'the GRANDCHILD must still be sitting in dsInsert, in the FIREDAC family ' +
    'too. deCheckBrowseMode does not stop at the level below the master, and ' +
    'TFDMasterDataLink only steps out of its way when the detail AND its own ' +
    'master are both mid-edit - which a mid level in dsBrowse is not. ' +
    'Measured state: ' + GetEnumName(TypeInfo(TDataSetState), Ord(LState)) +
    ', saved rows in the grandchild table: ' + IntToStr(LRows) +
    ', tag on its current row: ' + LTag +
    ' - which is what tells a POST from a CANCEL, since both land in dsBrowse');
  Assert.AreEqual(cNOTOKEN, LOtherToken,
    'and the child being typed records NO parentage: the refusal is what ' +
    'protected the grandchild, and the price is asserted here so that "the ' +
    'grandchild survived because we refused" cannot be read as "the ' +
    'grandchild survived because nothing reached it". SECOND, so that the ' +
    'clause above gets to report the measured state first');
end;

/// The handler a fixture installs where a data-aware control would sit. VCL
/// controls do not write the value the operator typed into the FIELD as it is
/// typed - TFieldDataLink holds it and writes it when the dataset fires
/// deUpdateRecord, which Data.DB.pas, TDataSet.CheckBrowseMode does through
/// UpdateRecord IMMEDIATELY BEFORE it reads Modified. TDataSource.OnUpdateData
/// is fired from the same event, in the same instant, and is the hook a fixture
/// can install without a windowed control. See
/// MintingWithAnUntouchedGrandchildInEdit_IsRefusedAndThatIsThePrice.
procedure TTestAutoIncDistribution.ControlWritesDuringUpdateRecord(
  ASender: TObject);
begin
  if FControlDataSet = nil then
    Exit;
  if not (FControlDataSet.State in dsEditModes) then
    Exit;
  FControlDataSet.FieldByName(cTAG).AsString := cCTRLTAG;
end;

procedure TTestAutoIncDistribution.MintingWithAnUntouchedGrandchildInEdit_IsRefusedAndThatIsThePrice;
var
  LRootCds: TClientDataSet;
  LMidCds: TClientDataSet;
  LLeafCds: TClientDataSet;
  LOtherCds: TClientDataSet;
  LRoot: TClientDataSetAdapter<TAitRoot>;
  LMid: TClientDataSetAdapter<TAitMid>;
  LLeaf: TClientDataSetAdapter<TAitLeaf>;
  LOther: TClientDataSetAdapter<TAitNoCascade>;
  LControl: TDataSource;
  LState: TDataSetState;
  LTag: String;
  LOtherToken: Integer;

  procedure Wire(const AChild: TClientDataSet; const ASource: TDataSource;
    const AField: String);
  var
    LM: TScrollMute;
  begin
    LM := MuteScroll(AChild);
    try
      AChild.MasterSource := ASource;
      AChild.IndexFieldNames := AField;
      AChild.MasterFields := AField;
    finally
      UnmuteScroll(AChild, LM);
    end;
  end;

begin
  // WHERE THE REFUSAL IS WIDER THAN THE HAZARD, AND WHY IT STAYS THAT WAY.
  // _AnyDetailRowOpen asks `State in dsEditModes` and never asks `Modified`,
  // while the RTL step it defends against - Data.DB.pas, TDataSet
  // .CheckBrowseMode - runs `UpdateRecord; if Modified then Post else Cancel`.
  // So a detail sitting in dsEdit that the operator never touched would be
  // CANCELLED, not posted, and refusing the mint for it costs the child being
  // typed its parentage for nothing visible. Measured, with this shape: the
  // OwnerToken is a real identity under the one level refusal that shipped in
  // the previous revision, and cNOTOKEN as shipped now.
  //
  // IT IS STILL NOT NARROWED TO `Modified`, and the reason is in the RTL line
  // ABOVE the one everybody quotes: `UpdateRecord` comes FIRST, and it fires
  // deUpdateRecord at every attached link and data source - Data.DB.pas,
  // TDataSet.UpdateRecord and TDataSource.DataEvent. That is exactly when a
  // data-aware control writes what the operator typed into the field, and that
  // write makes the row Modified. The `Modified` an outsider could read BEFORE
  // CheckBrowseMode runs is therefore not the `Modified` CheckBrowseMode
  // decides on, and this fixture installs a TDataSource.OnUpdateData that does
  // what a control does, so the difference is measured rather than argued.
  // Second reason, arithmetic rather than temporal: dsSetKey is in dsEditModes
  // (Data.DB.pas) and CheckBrowseMode POSTS a dsSetKey dataset unconditionally,
  // where `Modified` says nothing at all - so the narrowing would need its own
  // exception anyway.
  //
  // THIS FIXTURE PINS THE DECISION, NOT A DEFECT. Its clauses are what go red
  // if the predicate is narrowed, and the price clause is what goes red if the
  // refusal ever stops being paid for.
  LRootCds := TClientDataSet.Create(nil);
  LMidCds := TClientDataSet.Create(nil);
  LLeafCds := TClientDataSet.Create(nil);
  LOtherCds := TClientDataSet.Create(nil);
  LControl := TDataSource.Create(nil);
  try
    LRoot := TClientDataSetAdapter<TAitRoot>.Create(FConn, LRootCds, -1, nil);
    LMid := TClientDataSetAdapter<TAitMid>.Create(FConn, LMidCds, -1, LRoot);
    LLeaf := TClientDataSetAdapter<TAitLeaf>.Create(FConn, LLeafCds, -1, LMid);
    LOther := TClientDataSetAdapter<TAitNoCascade>.Create(FConn, LOtherCds, -1,
                LRoot);
    try
      TCascadeAccess<TAitRoot>.Mute(LRoot);
      try
        LRootCds.Append;
        LRootCds.FieldByName(cKEY).AsInteger := cLOADEDKEY;
        LRootCds.FieldByName(cTAG).AsString := cLOADEDTAG;
        LRootCds.Post;
      finally
        TCascadeAccess<TAitRoot>.Unmute(LRoot);
      end;
      Assert.AreEqual(cNOTOKEN, TokenOfTaggedRow(LRootCds, cLOADEDTAG,
                                                 cROWTOKEN),
        'PREMISE: the root must be untokenised, or no mint fires at all');

      Wire(LMidCds, TCascadeAccess<TAitRoot>.SourceOf(LRoot), cKEY);
      Wire(LLeafCds, TCascadeAccess<TAitMid>.SourceOf(LMid), cOWNKEY);
      Wire(LOtherCds, TCascadeAccess<TAitRoot>.SourceOf(LRoot), cKEY);
      Assert.IsNotNull(LMidCds.MasterSource,
        'PREMISE: the root -> mid link must really be installed');
      Assert.IsNotNull(LLeafCds.MasterSource,
        'PREMISE: the mid -> leaf link must really be installed - it is what ' +
        'would carry the post down to the grandchild');
      Assert.IsNotNull(LOtherCds.MasterSource,
        'PREMISE: and the root -> other link, which is what lets the mint fire ' +
        'from a branch with no details of its own');

      TCascadeAccess<TAitMid>.Mute(LMid);
      try
        LMidCds.Append;
        LMidCds.FieldByName(cKEY).AsInteger := cLOADEDKEY;
        LMidCds.FieldByName(cOWNKEY).AsInteger := cMIDFIRST;
        LMidCds.FieldByName(cTAG).AsString := 'M0';
        LMidCds.Post;
      finally
        TCascadeAccess<TAitMid>.Unmute(LMid);
      end;

      // THE GRANDCHILD IS COMMITTED FIRST, and then only OPENED. That is what
      // separates this fixture from the one above it: there the open row is
      // half typed and would be POSTED, here it is a saved row put into dsEdit
      // and never touched, which CheckBrowseMode would CANCEL. Nothing is at
      // risk, and the refusal happens anyway.
      TCascadeAccess<TAitLeaf>.Mute(LLeaf);
      try
        LLeafCds.Append;
        LLeafCds.FieldByName(cKEY).AsInteger := cLOADEDKEY;
        LLeafCds.FieldByName(cOWNKEY).AsInteger := cMIDFIRST;
        LLeafCds.FieldByName(cTAG).AsString := cKEEPTAG;
        LLeafCds.Post;
        LLeafCds.Edit;
      finally
        TCascadeAccess<TAitLeaf>.Unmute(LLeaf);
      end;
      Assert.IsTrue(LLeafCds.State = dsEdit,
        'PREMISE: the grandchild must be sitting in dsEdit');
      Assert.IsFalse(LLeafCds.Modified,
        'PREMISE: and NOT Modified - that is the whole point. A Modified row ' +
        'is the case the fixture above already measures');
      Assert.IsTrue(LMidCds.State = dsBrowse,
        'PREMISE: and the MID level must be in dsBrowse, so that the only open ' +
        'row anywhere in the tree is the untouched one two levels down');

      // The control goes on LAST, so that none of the writes above runs through
      // it. From here on the leaf is wired the way a grid wires it.
      FControlDataSet := LLeafCds;
      LControl.DataSet := LLeafCds;
      LControl.OnUpdateData := ControlWritesDuringUpdateRecord;

      LOtherCds.Append;
      LState := LLeafCds.State;
      // Read from the FIELD, not from a saved copy: under a narrowed predicate
      // the leaf is POSTED carrying what the control wrote, and under a
      // narrowed predicate WITHOUT the control it is CANCELLED back to what it
      // was committed with. Both end in dsBrowse, so the state clause alone
      // cannot tell them apart and this one is what makes the control
      // load-bearing.
      LTag := LLeafCds.FieldByName(cTAG).AsString;
      LOtherToken := LOtherCds.FieldByName(cOWNERTOKEN).AsInteger;
    finally
      LControl.OnUpdateData := nil;
      LControl.DataSet := nil;
      FControlDataSet := nil;
      LLeafCds.MasterFields := '';
      LLeafCds.IndexFieldNames := '';
      LLeafCds.MasterSource := nil;
      LMidCds.MasterFields := '';
      LMidCds.IndexFieldNames := '';
      LMidCds.MasterSource := nil;
      LOtherCds.MasterFields := '';
      LOtherCds.IndexFieldNames := '';
      LOtherCds.MasterSource := nil;
      if LOtherCds.State in [dsInsert, dsEdit] then
        LOtherCds.Cancel;
      if LLeafCds.State in [dsInsert, dsEdit] then
        LLeafCds.Cancel;
      if LMidCds.State in [dsInsert, dsEdit] then
        LMidCds.Cancel;
      LOther.Free;
      LLeaf.Free;
      LMid.Free;
      LRoot.Free;
    end;
  finally
    LControl.Free;
    LOtherCds.Free;
    LLeafCds.Free;
    LMidCds.Free;
    LRootCds.Free;
  end;

  Assert.AreEqual(cKEEPTAG, LTag,
    'the grandchild must still carry the value it was COMMITTED with. ' +
    'ASSERTED FIRST because it is the strongest of the three: an untouched ' +
    'dsEdit row that comes back carrying what the CONTROL wrote was POSTED, ' +
    'not Cancelled, which is what Data.DB.pas produces when UpdateRecord runs ' +
    'BEFORE Modified is read. That is the whole answer to "why not just ask ' +
    'Modified" - the Modified an outsider reads is not the one that decides');
  Assert.AreEqual(cNOTOKEN, LOtherToken,
    'THE PRICE, ASSERTED RATHER THAN DESCRIBED. The mint was refused even ' +
    'though the only open row in the whole tree was an UNTOUCHED dsEdit two ' +
    'levels down, which CheckBrowseMode would have Cancelled and not Posted ' +
    'had no control been attached - so the child being typed records no ' +
    'parentage and falls back to the behaviour that shipped before issue ' +
    '#265 - claimable by THE pending master where there is one, and by none ' +
    'where there is more than one, since issue #261. THIS IS A DECLARED ' +
    'LIMIT, not a defect');
  Assert.IsTrue(LState = dsEdit,
    'and it must still be open. Measured state: ' +
    GetEnumName(TypeInfo(TDataSetState), Ord(LState)));
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
  // minting on every one of those zeros - rather than only where there IS a
  // row to write on and it is safe to write - would reach a master row that
  // cannot take the write, and this child would stop receiving the key it
  // received on origin/develop.
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
    Assert.AreEqual(cNOTOKEN, TokenOfTaggedRow(LMidTable, 'C0', cOWNERTOKEN),
      'AND THE PRICE OF THAT, STATED RATHER THAN HIDDEN: the child comes out ' +
      'naming NOBODY, and falls back to the pre-#265 behaviour of being ' +
      'claimable by whichever pending master is passing - bounded since issue ' +
      '#261 to the case where exactly ONE is passing. Writing the token ' +
      'into the open buffer instead would leave Modified=True on an edit the ' +
      'operator has not finished - which the local family would swallow but ' +
      'TRESTDataSetAdapter<M>.ApplyUpdater turns into a PUT, and which a ' +
      'Cancel would undo, putting the master back on 0 while this child still ' +
      'named a number and making _IsOwnedByMasterRow refuse its own parent. ' +
      'The narrower loss was chosen over the silent write');
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
  // fork this issue turned on is "was the muted master key real or a
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
  // the same reason UntokenisedRow_WithTwoPendingMasters_IsClaimedByNeither
  // writes it: the
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
    // arms of the fork both end up naming a concrete parent, and therefore
    // differ only in the master key, is measured by
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

procedure TTestAutoIncDistribution.UntokenisedRow_WithTwoPendingMasters_IsClaimedByNeither;
var
  LMasterTable: TFDMemTable;
  LChildTable: TFDMemTable;
  LMaster: TFDMemTableAdapter<TAitRoot>;
  LChild: TFDMemTableAdapter<TAitMid>;
  LInternal: TField;
  LKeyA: Integer;
  LKeyB: Integer;
begin
  // WHAT THIS PINS AFTER #261 - rewritten, and the NAME changed with it. Until
  // this issue it was called UntokenisedRows_KeepTheHistoricalBehaviour and it
  // asserted the opposite of the clause at the bottom: that the child ended on
  // the key of the LAST pending master. That is the behaviour #261 is about, so
  // the fixture that fixed it had to say something else; deleting it instead
  // would have removed the only place in the suite where the ambiguous shape is
  // built at all.
  //
  // THE HISTORICAL BEHAVIOUR DID NOT GO AWAY, IT GOT A BOUNDARY. An untokenised
  // child under ONE pending master is still written by that master, unchanged
  // and for the reason it always was - measured next door by
  // ChildRowWithNoRecordedParentage_IsStillWrittenByItsMaster, which was green
  // before this issue and is green after it, untouched. What changed is only
  // the case where the answer was never a decision: with TWO pending masters
  // the row was claimed by both, in order, and kept whatever the second one
  // wrote. Two masters cannot both be right, so neither writes.
  //
  // This test mutes BOTH adapters, so the child row is appended without its own
  // adapter ever seeing it: DoNewRecord never runs on it, cOwnerTokenField is
  // never written and reads back as the 0 a TField answers for NULL.
  //
  // THE OTHER STATE NO LONGER EXISTS. Until #265, a child typed with its own
  // events LIVE under a master that had no identity - which every master read
  // from the store is - also recorded 0, and was therefore claimable by any
  // pending master. That is not a state any more:
  // TDataSetBaseAdapter<M>._EnsureMasterRowToken gives the master ROW an
  // identity before the child row is even opened, so the child names a concrete
  // parent. Measured by
  // LoadedMaster_ChildTypedUnderIt_KeepsTheLoadedMastersKey,
  // MutedMasterAppend_WithARealKey_ItsChildKeepsThatKey and
  // TwoUnidentifiedPendingMasters_ChildOfTheFirstIsNotClaimedByTheSecond.
  //
  // WHAT DID NOT CHANGE IN THE SET-UP. Not one line of it moved for #261 except
  // the foreign key the child is seeded with, which went from cROOTOLD to
  // cUNCLAIMEDSEED: 0 is what an unwritten integer column reads as anyway, so
  // asserting the child still carries 0 would pass on a run where the column
  // was never populated at all. A number nothing else in the fixture can
  // produce is what makes "nobody wrote it" a measurement.
  //
  // The premise clause below still says out loud that the muted append recorded
  // nothing, so the day someone makes a muted append record something, this
  // test reddens instead of quietly changing meaning again.
  //
  // TWO STATES STILL REACH 0 and both arrive here: this one, and a child
  // typed while the master table has no row at all - measured by
  // ChildTypedUnderAnEmptyMaster_MintsNothingAndFabricatesNoRow - plus a child
  // typed while the master row is being edited, measured by
  // ChildTypedWhileTheMasterRowIsBeingEdited_DoesNotCommitThatEdit.
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
        LChildTable.FieldByName(cKEY).AsInteger := cUNCLAIMEDSEED;
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
        'so neither DoBeforeInsert nor DoNewRecord ran on it and nothing was ' +
        'written at all. Take the mute off the CHILD and _EnsureMasterRowToken ' +
        'gives the master an identity and this row names it, which is a ' +
        'different boundary measured by five other tests in this file - ' +
        DumpColumn(LChildTable, cOWNERTOKEN));
      Assert.AreEqual(2,
        CountWithColumn(LMasterTable, cInternalField, Integer(dsInsert)),
        'PREMISE - AND THE WHOLE REASON THIS FIXTURE DIFFERS FROM ' +
        'ChildRowWithNoRecordedParentage_IsStillWrittenByItsMaster: TWO master ' +
        'rows must be pending. One is not an ambiguity and is still written; ' +
        'if this ever reads 1 the test stops measuring what it is named after');
      Assert.AreEqual(1,
        CountWithColumn(LChildTable, cInternalField, Integer(dsInsert)),
        'PREMISE: and the child row must be PENDING, or _IsPendingInsertRow ' +
        'refuses it before parentage is ever asked about and every clause ' +
        'below passes for the wrong reason');

      TCascadeAccess<TAitRoot>.ApplyAll(LMaster);

      LKeyA := KeyOfMasterRow(LMasterTable, False);
      LKeyB := KeyOfMasterRow(LMasterTable, True);
      Assert.IsTrue(LKeyA > 0,
        'PREMISE: the first master must have received a generated key');
      Assert.IsTrue(LKeyB > 0,
        'PREMISE: the second master must have received a generated key');
      Assert.AreNotEqual(LKeyA, LKeyB,
        'PREMISE: the two masters must carry DIFFERENT keys, or "claimed by ' +
        'neither" and "claimed by both" are the same number');
      Assert.AreEqual(cUNCLAIMEDSEED, KeyOfTaggedRow(LChildTable, 'C0'),
        'THE ROW C0 - by tag, not by count - must still carry the foreign key ' +
        'it was seeded with. With TWO pending masters and no recorded ' +
        'parentage there is no answer, and the framework writes no answer ' +
        'rather than the last one asked - ' + DumpColumn(LChildTable, cKEY));
      Assert.AreEqual(0, CountWithColumn(LChildTable, cKEY, LKeyB),
        'and specifically NOT the key of the LAST pending master, which is ' +
        'what a walk that waves every untokenised row through leaves behind - ' +
        DumpColumn(LChildTable, cKEY));
      Assert.AreEqual(0, CountWithColumn(LChildTable, cKEY, LKeyA),
        'nor the key of the FIRST - refusing the second claim while keeping ' +
        'the first would be first-one-wins, which is the same coin flip with ' +
        'the other face up - ' + DumpColumn(LChildTable, cKEY));
      // AND WHAT BECOMES OF THE ROW, which is the question a consumer asks
      // next and which no clause used to answer. In the LOCAL families it is
      // INSERTED: ApplyInternal reaches the child adapter's own ApplyInternal
      // after the master loop ends, and that loop does not ask about
      // parentage - it inserts every pending row it finds, this one included,
      // carrying the foreign key it came in with. The clause above already
      // says which key that is; this one says the row did not merely sit
      // there. The REST family answers DIFFERENTLY and its own fixture
      // measures it.
      Assert.AreEqual(cAPPLIED,
        TokenOfTaggedRow(LChildTable, 'C0', cInternalField),
        'the unclaimed row is not left pending in this family - the child ' +
        'level applies it, so what the consumer ends up with is an INSERTED ' +
        'row carrying an unresolved foreign key, not a row still waiting');
    finally
      LChild.Free;
      LMaster.Free;
    end;
  finally
    LChildTable.Free;
    LMasterTable.Free;
  end;
end;

procedure TTestAutoIncDistribution.ClientDataSetUntokenisedRow_WithTwoPendingMasters_IsClaimedByNeither;
var
  LMasterCds: TClientDataSet;
  LChildCds: TClientDataSet;
  LMaster: TClientDataSetAdapter<TAitRoot>;
  LChild: TClientDataSetAdapter<TAitMid>;
  LInternal: TField;
  LKeyA: Integer;
  LKeyB: Integer;
begin
  // THE SECOND LOCAL FAMILY, and it is here for a mutation rather than for
  // symmetry. The number of pending masters cannot be taken from inside the
  // cascade - see TDataSetBaseAdapter<M>.FCascadeMasterRows - so it is read at
  // the top of each ApplyInserter, and there are THREE of those:
  // TFDMemTableAdapter<M>, TClientDataSetAdapter<M> and TRESTDataSetAdapter<M>.
  // The three reads are near enough identical to invite the argument that
  // measuring one measures the others. It does not: delete the read from THIS
  // family alone and only THIS fixture reddens, which is the whole reason it
  // was written rather than inferred from the FDMemTable twin.
  //
  // Everything else - what is muted, why the pending markers are written by
  // hand, why the child foreign key starts on cUNCLAIMEDSEED - is the same as
  // in UntokenisedRow_WithTwoPendingMasters_IsClaimedByNeither and is explained
  // there rather than repeated here.
  LMasterCds := TClientDataSet.Create(nil);
  LChildCds := TClientDataSet.Create(nil);
  try
    LMaster := TClientDataSetAdapter<TAitRoot>.Create(FConn, LMasterCds, -1,
                 nil);
    LChild := TClientDataSetAdapter<TAitMid>.Create(FConn, LChildCds, -1,
                LMaster);
    try
      TCascadeAccess<TAitRoot>.Mute(LMaster);
      TCascadeAccess<TAitMid>.Mute(LChild);
      try
        LMasterCds.Append;
        LMasterCds.FieldByName(cKEY).AsInteger := cROOTOLD;
        LMasterCds.FieldByName(cTAG).AsString := 'R1';
        LMasterCds.Post;
        LInternal := LMasterCds.FieldByName(cInternalField);
        LMasterCds.Edit;
        LInternal.AsInteger := Integer(dsInsert);
        LMasterCds.Post;
        LMasterCds.Append;
        LMasterCds.FieldByName(cKEY).AsInteger := cROOTOLD;
        LMasterCds.FieldByName(cTAG).AsString := 'R2';
        LMasterCds.Post;
        LMasterCds.Edit;
        LInternal.AsInteger := Integer(dsInsert);
        LMasterCds.Post;
        LChildCds.Append;
        LChildCds.FieldByName(cOWNKEY).AsInteger := 0;
        LChildCds.FieldByName(cKEY).AsInteger := cUNCLAIMEDSEED;
        LChildCds.FieldByName(cTAG).AsString := 'C0';
        LChildCds.Post;
        LChildCds.Edit;
        LChildCds.FieldByName(cInternalField).AsInteger := Integer(dsInsert);
        LChildCds.Post;
      finally
        TCascadeAccess<TAitMid>.Unmute(LChild);
        TCascadeAccess<TAitRoot>.Unmute(LMaster);
      end;
      Assert.AreEqual(1, CountWithColumn(LChildCds, cOWNERTOKEN, cNOTOKEN),
        'PREMISE: the child must carry the NEVER RECORDED value in this ' +
        'family too - ' + DumpColumn(LChildCds, cOWNERTOKEN));
      Assert.AreEqual(2,
        CountWithColumn(LMasterCds, cInternalField, Integer(dsInsert)),
        'PREMISE: TWO master rows must be pending - that is the ambiguity');
      Assert.AreEqual(1,
        CountWithColumn(LChildCds, cInternalField, Integer(dsInsert)),
        'PREMISE: and the child row must be PENDING, or _IsPendingInsertRow ' +
        'refuses it before parentage is ever asked about');

      TCascadeAccess<TAitRoot>.ApplyAll(LMaster);

      LKeyA := KeyOfMasterRow(LMasterCds, False);
      LKeyB := KeyOfMasterRow(LMasterCds, True);
      Assert.IsTrue(LKeyA > 0,
        'PREMISE: the first master must have received a generated key');
      Assert.AreNotEqual(LKeyA, LKeyB,
        'PREMISE: the two masters must carry DIFFERENT keys');
      Assert.AreEqual(cUNCLAIMEDSEED, KeyOfTaggedRow(LChildCds, 'C0'),
        'THE ROW C0 must still carry the foreign key it was seeded with in ' +
        'the ClientDataSet family as well - ' + DumpColumn(LChildCds, cKEY));
      Assert.AreEqual(0, CountWithColumn(LChildCds, cKEY, LKeyB),
        'and specifically NOT the key of the LAST pending master - ' +
        DumpColumn(LChildCds, cKEY));
      Assert.AreEqual(cAPPLIED,
        TokenOfTaggedRow(LChildCds, 'C0', cInternalField),
        'and this family INSERTS it too, same as the FDMemTable twin - ' +
        'measured here rather than inferred, because TClientDataSetAdapter<M> ' +
        'carries its own ApplyInternal');
    finally
      LChild.Free;
      LMaster.Free;
    end;
  finally
    LChildCds.Free;
    LMasterCds.Free;
  end;
end;

procedure TTestAutoIncDistribution.RestUntokenisedRow_WithTwoPendingMasters_IsClaimedByNeither;
var
  LMasterTable: TFDMemTable;
  LChildTable: TFDMemTable;
  LMaster: TRESTFDMemTableAdapter<TAitRoot>;
  LChild: TRESTFDMemTableAdapter<TAitMid>;
  LKeyA: Integer;
  LKeyB: Integer;
begin
  // THE SAME AMBIGUITY IN THE OTHER FAMILY, and it is run rather than inferred.
  // The two families share _IsOwnedByMasterRow, but they do NOT share the loop
  // that establishes how many masters are pending: TRESTDataSetAdapter<M> has
  // its own ApplyInserter, so a fix applied to one ApplyInserter and not the
  // other would leave this red and the local twin green.
  //
  // THE SET-UP IS THE REST ONE, NOT A COPY OF THE LOCAL SET-UP.
  // TRESTDataSetAdapter<M>.OpenDataSetChilds has an empty body, so a master
  // scroll discards nothing and the master adapter needs no mute: both masters
  // go in LIVE, each carrying its own recorded identity, and each keeps its own
  // tokenised child. Only the child adapter is muted, and only for the one row
  // that is supposed to have no parentage - so this fixture measures the
  // untokenised row NEXT TO two properly parented ones, in one run, which the
  // local shape cannot do.
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
      LChildTable.Append;
      LChildTable.FieldByName(cOWNKEY).AsInteger := 0;
      LChildTable.FieldByName(cKEY).AsInteger := cROOTOLD;
      LChildTable.FieldByName(cTAG).AsString := 'A0';
      LChildTable.Post;
      LMasterTable.Append;
      LMasterTable.FieldByName(cKEY).AsInteger := cROOTOLD;
      LMasterTable.FieldByName(cTAG).AsString := 'R2';
      LMasterTable.Post;
      LChildTable.Append;
      LChildTable.FieldByName(cOWNKEY).AsInteger := 0;
      LChildTable.FieldByName(cKEY).AsInteger := cROOTOLD;
      LChildTable.FieldByName(cTAG).AsString := 'B0';
      LChildTable.Post;
      // The one row nobody recorded. Muted for its own append only, and its
      // pending marker written by hand for the reason the local twin does it:
      // a muted append never reaches DoBeforePost.
      TCascadeAccess<TAitMid>.Mute(LChild);
      try
        LChildTable.Append;
        LChildTable.FieldByName(cOWNKEY).AsInteger := 0;
        LChildTable.FieldByName(cKEY).AsInteger := cUNCLAIMEDSEED;
        LChildTable.FieldByName(cTAG).AsString := 'C0';
        LChildTable.Post;
        LChildTable.Edit;
        LChildTable.FieldByName(cInternalField).AsInteger := Integer(dsInsert);
        LChildTable.Post;
      finally
        TCascadeAccess<TAitMid>.Unmute(LChild);
      end;
      Assert.AreEqual(3, RowCount(LChildTable),
        'PREMISE: the REST family must hold all three child rows at once - ' +
        'two parented and one orphaned - or this fixture is not the shape it ' +
        'claims to be');
      Assert.AreEqual(1, CountWithColumn(LChildTable, cOWNERTOKEN, cNOTOKEN),
        'PREMISE: EXACTLY ONE of them must be the unrecorded one. Two would ' +
        'mean the live appends recorded nothing either and the two clauses ' +
        'about A0 and B0 below would be measuring the same escape hatch - ' +
        DumpColumn(LChildTable, cOWNERTOKEN));
      Assert.AreEqual(2,
        CountWithColumn(LMasterTable, cInternalField, Integer(dsInsert)),
        'PREMISE: TWO master rows must be pending - that is the ambiguity');

      TCascadeAccess<TAitRoot>.ApplyAll(LMaster);

      LKeyA := KeyOfMasterRow(LMasterTable, False);
      LKeyB := KeyOfMasterRow(LMasterTable, True);
      Assert.IsTrue(LKeyA > 0,
        'PREMISE: the first master must have received a key from the server ' +
        'answer, or ApplyInserter never reached SetAutoIncValueChilds');
      Assert.AreNotEqual(LKeyA, LKeyB,
        'PREMISE: the two masters must carry DIFFERENT keys');

      Assert.AreEqual(LKeyA, KeyOfTaggedRow(LChildTable, 'A0'),
        'THE ROW A0 recorded its parent and must still be written by it - the ' +
        'count of pending masters may not touch a row that is not ambiguous - ' +
        DumpColumn(LChildTable, cKEY));
      Assert.AreEqual(LKeyB, KeyOfTaggedRow(LChildTable, 'B0'),
        'and B0 likewise, on the OTHER master - ' +
        DumpColumn(LChildTable, cKEY));
      Assert.AreEqual(cUNCLAIMEDSEED, KeyOfTaggedRow(LChildTable, 'C0'),
        'THE ROW C0 recorded nothing, and with two pending masters there is ' +
        'no answer to give it, so it keeps the key it came in with - ' +
        DumpColumn(LChildTable, cKEY));
      // AND HERE THE ROW REALLY IS LEFT PENDING, which is where this family
      // parts company with the local ones. TRESTFDMemTableAdapter<M>
      // .ApplyInternal does not iterate FMasterObject, so the child level is
      // never applied in this run and the unclaimed row is still sitting on
      // the pending marker when the apply is over. The local twins measure
      // cAPPLIED at this same point. Neither answer is asserted as the
      // desirable one - what is asserted is that they DIFFER, so that a
      // sentence claiming one of them for "the framework" cannot be written
      // again without this fixture contradicting it.
      Assert.AreEqual(Integer(dsInsert),
        TokenOfTaggedRow(LChildTable, 'C0', cInternalField),
        'the unclaimed row is still PENDING in the REST family - this level ' +
        'never applies its own children, so nothing wrote it to the server ' +
        'and nothing cleared its marker');
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
