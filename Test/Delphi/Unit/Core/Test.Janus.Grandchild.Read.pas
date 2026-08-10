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

{ @abstract(Janus Framework - reading .Current must not destroy grandchild rows.)

  WHAT IS UNDER TEST - issue #276

  TDataSetBaseAdapter<M>.Current on a THREE level tree. Current is a READ: it
  binds the current row onto the entity and then walks every child dataset to
  materialise the object graph. On the way it moves the MIDDLE dataset's
  cursor, and that cursor belongs to a TDataSetAdapter<M> whose DoAfterScroll
  calls OpenDataSetChilds, which re-opens the GRANDCHILD dataset from the
  database - OpenSQLInternal starts with EmptyDataSet. So a single read of the
  grandparent's .Current threw away every grandchild row the operator had typed
  and not saved. No exception, no log, no return code.

  A SINGLE READ IS ENOUGH, AND THAT IS THE POINT

  ApplyUpdates is only the commonest caller: TFDMemTableAdapter<M>.ApplyInserter
  opens with FSession.Insert(Current). Any screen code that reads .Current of
  the grandparent - to display, to validate, to log - paid the same price.
  These tests therefore call .Current directly and assert on the rows, so the
  measurement cannot be confused with anything ApplyUpdates does afterwards.

  WHY THE ASSERTIONS NAME THE ROW AND NOT THE COUNT

  A count goes green for the wrong reason the moment a re-query hands back a
  row that is not the one the operator typed - which is exactly what the issue
  measured against a real database, where two typed grandchildren were REPLACED
  by three read back. Every assertion here is a signature carrying the row's
  own tag AND its foreign key, and the foreign key is seeded with a SENTINEL
  (-7) that no row in the middle level carries, so "the row survived" can never
  be read off a row that was rebuilt.

  WHAT THIS FIXTURE DELIBERATELY DOES NOT TOUCH

  The scroll contract. When the OPERATOR moves the master, the discard is a
  decision the house already took and pinned - Test.Janus.Scroll.PendingChilds,
  Premise_ScrollingTheMasterDiscardsTypedChildRows, whose master rows are
  PENDING INSERT exactly like the ones here. So "do not re-open the children of
  a master row that is not in the database yet" was measured and REFUSED as a
  fix: it would have reddened that premise. What separates the two cases is not
  the state of the row, it is WHO MOVED THE CURSOR - an operator keypress
  versus the framework's own read walk. AfterTheRead_AnOperatorScrollStillDiscards
  is the guard that keeps the two apart.

  THE TWO FAMILIES ARE NOT THE SAME, AND ONE SUPPRESSION SERVES BOTH

  TFDMemTableAdapter<M> and TClientDataSetAdapter<M> both descend from
  TDataSetAdapter<M>, whose OpenDataSetChilds really re-queries: both lost the
  grandchildren. TRESTDataSetAdapter<M>.OpenDataSetChilds has an EMPTY BODY, so
  the REST family never lost anything and needs no repair -
  Rest_ReadingCurrentOnTheGrandparent_NeverDestroyedTheGrandchildRow measures
  that claim instead of repeating it, and it was green before the fix as well.

  TWO BRANCHES, NOT ONE - AND THEY NEEDED DIFFERENT AMOUNTS OF REPAIR

  FillMastersClass routes an association to _ExecuteOneToMany or to
  _ExecuteOneToOne by multiplicity, and BOTH walk the child cursor the same way.
  The first version of this fix repaired only _ExecuteOneToMany, on the reading
  that the OneToOne branch could not be driven to level three - it raised an
  AccessViolation first. That reading was WRONG, and the counter-measurement is
  cheap: the AccessViolation comes from the association property being nil, and
  filling it costs one line, because with the root dataset still empty Current
  returns FCurrentInternal on its RecordCount = 0 exit without walking anything.
  With the property filled the OneToOne branch destroyed the grandchild in
  perfect silence - no exception at all. OneToOneTop_ReadingCurrentOnTheGrandparent
  is that measurement.

  What genuinely differs between the two is the SIZE of the hole:
  _ExecuteOneToMany exposes two scrolls, _ExecuteOneToOne exposes one, because
  the latter restores its bookmark while BlockReadSize is still MaxInt and the
  restore is therefore already turned away by DoAfterScroll's dsBrowse guard.
  Sibling code, different repair - which is why each was measured on its own.

  And the issue was never talking about only one of them: the two line anchors
  in its body point at _ExecuteOneToOne, not at _ExecuteOneToMany. Closing #276
  with the OneToOne branch untouched would have left the exact lines the issue
  names still destroying rows.

  THE MUTATIONS THAT WERE RUN, AND WHAT DIED IN EACH

  Every part of the repair is suppressed on its own and made to kill a
  DIFFERENT set - the two scrolls of _ExecuteOneToMany look alike and are not,
  and neither does the OTHER branch's single scroll. Baseline for all eight:
  529 found, 529 passed.

    m1. the suppression is never consulted (DoAfterScroll re-opens always)
        -> 5 red: ReadingCurrentOnTheGrandparent, ClientDataSet_ReadingCurrent,
           EachMidObjectInTheGraph, AfterTheRead_AnOperatorScrollStillDiscards,
           OneToOneTop_ReadingCurrentOnTheGrandparent.
    m2. the release deleted outright
        -> 2 red: AfterTheRead_AnOperatorScrollStillDiscards and
           AnExceptionInsideTheWalk. The operator's own scroll stops
           discarding, which is the contract this issue may not touch.
    m3. only the First of _ExecuteOneToMany protected, the restore exposed
        -> 3 red. EachMidObjectInTheGraph STAYS GREEN, and the difference is
           the measurement: the graph is built during the walk, and the restore
           destroys the leaf rows a moment AFTER it, so a fix that stopped at
           the First would have returned a correct object graph over a table it
           had just emptied.
    m4. only the restore of _ExecuteOneToMany protected, the First exposed
        -> 4 red, EachMidObjectInTheGraph among them: there the rows are gone
           BEFORE the walk reads them.
    y1. the release moved OUT of the `finally` and left a plain statement
        -> 1 red, and only one: AnExceptionInsideTheWalk. The happy path still
           releases, so nothing else notices - which is exactly why the
           `finally` needed a test of its own.
    y2. _InjectLazyProxiesOnScroll swallowed along with the re-open
        -> 1 red: TheSuppressedWalk_StillInjectsTheLazyProxiesOnScroll.
    y3. the `inherited` swallowed - consumer AfterScroll and the paging leg
        -> 2 red: TheSuppressedWalk_StillFiresTheConsumersOwnAfterScroll, and
           AnExceptionInsideTheWalk as collateral, because the exception that
           test relies on is raised BY the consumer's handler.
    z1. _ExecuteOneToOne back to no suppression at all
        -> 1 red, and only one: OneToOneTop_ReadingCurrentOnTheGrandparent. The
           two branches are pinned independently, in both directions.

  m3 and m4 are the reason the suppression spans the whole block of
  _ExecuteOneToMany: neither scroll is redundant, and they fail differently.
  y1, y2 and y3 exist because all three of those mutations once survived GREEN
  - the repair was correct and nothing held it up.

  A MUTATION THAT SURVIVES, DECLARED RATHER THAN HIDDEN

  y2b. the injection made to happen ONCE in the whole life of the adapter
       (an early exit on FLastPKValue <> '') -> 529 GREEN. Nothing here dies.

  So the FREQUENCY of _InjectLazyProxiesOnScroll is not pinned by this fixture,
  and must not be read into TheSuppressedWalk_StillInjectsTheLazyProxiesOnScroll:
  that test fixes that the suppression does not SWALLOW the call, and nothing
  more. "Once per row" would in fact be false. The call sits inside
  DoAfterScroll's dsBrowse guard while every intermediate move of the walk is in
  dsBlockRead - which is the suppression's own mechanism - so it is REACHED on
  two scrolls, the First and the bookmark restore, and does work on one of them
  because of the LCurrentPK = FLastPKValue early exit.

  Left as a declaration and not repaired with another test on purpose: how often
  the lazy proxies are injected belongs to the lazy contract
  (Test.Janus.Container.DataSet.AutoLazy and its neighbours), not to #276, and
  inventing a test for it here would widen this change past what it is for.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Grandchild.Read;

interface

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
  DataEngine.FactoryInterfaces,
  Janus.DataSet.Base.Adapter,
  Janus.DataSet.FDMemTable,
  Janus.DataSet.ClientDataSet,
  Janus.RestDataSet.FDMemTable,
  Janus.RestFactory.Interfaces,
  Test.Janus.Model.AutoIncTree,
  /// For TAsymTreeOneRoot, the only entity in the repository whose TOP level
  /// association is OneToOne - which is the branch _ExecuteOneToOne serves.
  Test.Janus.Model.AsymTree,
  Test.Janus.Cursor.Double,
  /// Only for TInertRestConnection, the IRESTConnection double that fixture
  /// already ships.
  Test.Janus.MasterDetail.Link;

type
  /// <summary> Classic protected-access descendant. FLastPKValue is protected
  ///  and it is the witness _InjectLazyProxiesOnScroll leaves behind - the only
  ///  one available on a fixture whose model declares no lazy association, and
  ///  the difference between "the suppression is surgical" as a claim and as a
  ///  measurement. </summary>
  TReadAccess<M: class, constructor> = class(TDataSetBaseAdapter<M>)
  public
    class function LastPK(const A: TDataSetBaseAdapter<M>): String;
  end;

  [TestFixture]
  TTestGrandchildRead = class
  private
    FConn: IDBConnection;
    FRest: IRESTConnection;
    FRootTable: TFDMemTable;
    FMidTable: TFDMemTable;
    FLeafTable: TFDMemTable;
    FRoot: TFDMemTableAdapter<TAitRoot>;
    FMid: TFDMemTableAdapter<TAitMid>;
    FLeaf: TFDMemTableAdapter<TAitLeaf>;
    FRootCds: TClientDataSet;
    FMidCds: TClientDataSet;
    FLeafCds: TClientDataSet;
    FCdsRoot: TClientDataSetAdapter<TAitRoot>;
    FCdsMid: TClientDataSetAdapter<TAitMid>;
    FCdsLeaf: TClientDataSetAdapter<TAitLeaf>;
    FRestRootTable: TFDMemTable;
    FRestMidTable: TFDMemTable;
    FRestLeafTable: TFDMemTable;
    FRestRoot: TRESTFDMemTableAdapter<TAitRoot>;
    FRestMid: TRESTFDMemTableAdapter<TAitMid>;
    FRestLeaf: TRESTFDMemTableAdapter<TAitLeaf>;
    FOneRootTable: TFDMemTable;
    FOneMidTable: TFDMemTable;
    FOneLeafTable: TFDMemTable;
    FOneRoot: TFDMemTableAdapter<TAsymTreeOneRoot>;
    FOneMid: TFDMemTableAdapter<TAsymTreeMid>;
    FOneLeaf: TFDMemTableAdapter<TAsymTreeLeaf>;
    /// What the CONSUMER's own AfterScroll saw, and whether it is to raise.
    FSeenByConsumer: String;
    FRaiseOnNextScroll: Boolean;
    procedure MidConsumerAfterScroll(DataSet: TDataSet);
    procedure BuildOneToOneTree;
    procedure BuildLocalTree(const AWithLeaf: Boolean = True;
      const AWithConsumerScroll: Boolean = False);
    procedure BuildCdsTree;
    procedure BuildRestTree;
    procedure AddRoot(const ADataSet: TDataSet; const ATag: String);
    procedure AddMid(const ADataSet: TDataSet; const ATag: String;
      const AOwnKey: Integer);
    procedure AddLeaf(const ADataSet: TDataSet; const ATag: String);
    procedure ParkOnFirst(const ADataSet: TDataSet);
    function SignatureOf(const ADataSet: TDataSet; const ATagColumn: String;
      const AForeignKey: String): String;
    function Signature(const ADataSet: TDataSet;
      const AForeignKey: String): String;
    function TagUnderCursor(const ADataSet: TDataSet): String;
    function GraphSignature(const ARoot: TAitRoot): String;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // -----------------------------------------------------------------------
    // The premise
    // -----------------------------------------------------------------------

    /// The operator really has a grandchild line on screen before anything is
    /// read. If this goes red the rest of the fixture measures nothing.
    [Test]
    procedure Premise_TheGrandchildRowIsThereBeforeAnythingIsRead;

    // -----------------------------------------------------------------------
    // The defect
    // -----------------------------------------------------------------------

    /// The whole issue in one line of consumer code. RED before the fix: the
    /// leaf table came back EMPTY from a read that promised nothing but a
    /// read.
    [Test]
    procedure ReadingCurrentOnTheGrandparent_KeepsTheGrandchildRowAndItsForeignKey;
    /// The control the issue insisted on: with only TWO levels the same read
    /// never cost anything, because the master's own cursor is not moved by
    /// Current - only the children's are. Green before AND after, which is
    /// what makes the test above a statement about depth three and not about
    /// Current in general.
    [Test]
    procedure Control_WithOnlyTwoLevels_TheSameReadKeepsTheChildRow;
    /// The other local family. TClientDataSetAdapter<M> descends from the same
    /// TDataSetAdapter<M> and lost the same row.
    [Test]
    procedure ClientDataSet_ReadingCurrentOnTheGrandparent_KeepsTheGrandchildRow;
    /// The REST family, which never had the defect: its OpenDataSetChilds has
    /// an empty body. Green before the fix too - it records that the two
    /// families differ, so nobody repairs a hole that is not there.
    [Test]
    procedure Rest_ReadingCurrentOnTheGrandparent_NeverDestroyedTheGrandchildRow;

    // -----------------------------------------------------------------------
    // What the repair must NOT cost
    // -----------------------------------------------------------------------

    /// The read walks the middle cursor from the first row to Eof and puts it
    /// back. A repair that muted the walk and forgot the bookmark would leave
    /// the operator's grid parked somewhere else.
    [Test]
    procedure TheReadLeavesTheMidCursorWhereItFoundIt;
    /// The reason the re-query cannot simply be deleted has to be measured,
    /// not assumed: this asks what the object graph Current returns actually
    /// carries. RED before the fix, and for the opposite reason to the one the
    /// re-query was there to serve - the re-open emptied the leaf dataset
    /// BEFORE the walk read it, so every middle object came back with an EMPTY
    /// leafs list.
    [Test]
    procedure EachMidObjectInTheGraphCarriesTheGrandchildRowsThatAreLoaded;
    /// The guard that keeps the repair from swallowing the scroll contract.
    /// Once the read is over, an operator keypress on the middle grid must
    /// still re-open the leaf from the database and still discard - that is
    /// Test.Janus.Scroll.PendingChilds' contract and it is not this issue's to
    /// change. A suppression that is switched on and never switched off
    /// reddens THIS test alone.
    [Test]
    procedure AfterTheRead_AnOperatorScrollStillDiscards;
    /// The OTHER branch of the same walk. FillMastersClass routes a OneToOne or
    /// ManyToOne association to _ExecuteOneToOne - this drives it through a
    /// OneToOne, so what is pinned is the BRANCH and not the ManyToOne label,
    /// which no test here carries. It opens with the same
    /// unprotected First over the same child cursor. Only the First is exposed
    /// there - unlike _ExecuteOneToMany, that method restores the bookmark
    /// while BlockReadSize is still MaxInt, so the restore happens in
    /// dsBlockRead and DoAfterScroll's dsBrowse guard turns it away. The two
    /// siblings therefore needed DIFFERENT amounts of repair, which is why
    /// neither was assumed from the other.
    [Test]
    procedure OneToOneTop_ReadingCurrentOnTheGrandparent_KeepsTheGrandchildRow;

    // -----------------------------------------------------------------------
    // What holds the repair itself up
    // -----------------------------------------------------------------------

    /// The `finally` around the release. An exception inside the walk is not
    /// hypothetical: the consumer's own AfterScroll runs there, and
    /// _ExecuteOneToMany itself raises 'Not in instance ...' on a property
    /// whose type is not a class. Without the finally the counter stays up
    /// FOREVER and the operator's scroll silently stops discarding - the
    /// contract this fixture guards, broken permanently and invisibly.
    [Test]
    procedure AnExceptionInsideTheWalk_StillReleasesTheSuppression;
    /// "It suppresses ONE call" is a claim about the two things that must
    /// SURVIVE the suppression, and both are measured. This one is the
    /// consumer's own AfterScroll, reached through the `inherited` at the end
    /// of DoAfterScroll - the same `inherited` the paging leg rides on.
    [Test]
    procedure TheSuppressedWalk_StillFiresTheConsumersOwnAfterScroll;
    /// And this one is _InjectLazyProxiesOnScroll, which sits beside the
    /// suppressed call inside the same guard and must not be taken down with
    /// it. FLastPKValue is what it leaves behind.
    [Test]
    procedure TheSuppressedWalk_StillInjectsTheLazyProxiesOnScroll;
  end;

implementation

const
  cROOTTAG  = 'R1';
  cMIDTAG   = 'M1';
  cMIDTAG2  = 'M2';
  cLEAFTAG  = 'L1';
  /// A foreign key value NO row of the middle level carries, so a leaf that
  /// came back from a re-query can never be mistaken for the leaf that was
  /// typed.
  cSENTINEL = -7;
  cNOROW    = '<no row>';
  cWALKCEIL = 50;
  cROOTKEY  = 'root_id';
  cMIDKEY   = 'mid_id';
  cTAG      = 'tag';
  /// The middle rows carry EXPLICIT own keys, and the reason is DETERMINISM,
  /// NOT DISCRIMINATION - measured, after an earlier version of this comment
  /// claimed the second. Left to the pending autoinc placeholder,
  /// _GetCurrentPKAsString - the witness
  /// TheSuppressedWalk_StillInjectsTheLazyProxiesOnScroll reads - would answer
  /// -1 instead of a value this fixture chose; the explicit keys give the
  /// assertion a known expected string, not a sharper discrimination - the
  /// witness moves either way, from '' to -1, and still parts the mutation
  /// (which reads '') from the HEAD.
  /// DISTINCT buys nothing at all here, and that is worth writing down so the
  /// next reader does not defend it: the two scrolls that reach the witness -
  /// the First and the bookmark restore - land on the SAME row, because the
  /// fixture parks on the first.
  cMIDKEY1   = 11;
  cMIDKEY2   = 12;
  cMIDKEY1AS = '11';
  /// AsymTree spells every column exactly once across the three levels, which
  /// is why its names share nothing with the ones above.
  cONEROOTTAG = 'ptag';
  cONEMIDTAG  = 'mtag';
  cONELEAFTAG = 'ltag';
  cONELEAFFK  = 'lparent';

type
  /// Saved BeforeScroll/AfterScroll pair, so a fixture helper can walk a
  /// dataset without TDataSetAdapter<M>.DoAfterScroll re-opening its children -
  /// the reading must not destroy what it is reading.
  TScrollMute = record
    Before: TDataSetNotifyEvent;
    After: TDataSetNotifyEvent;
  end;

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

{ TReadAccess<M> }

class function TReadAccess<M>.LastPK(const A: TDataSetBaseAdapter<M>): String;
begin
  Result := TReadAccess<M>(A).FLastPKValue;
end;

{ TTestGrandchildRead }

procedure TTestGrandchildRead.Setup;
begin
  // Zero rows on purpose, the same choice Test.Janus.Scroll.PendingChilds
  // makes: the re-query the read fires hands the child back EMPTY, which is
  // the sharpest possible statement of "the typed line is gone". Nothing here
  // opens a cursor for its content.
  FConn := TRowsConnection.Create(dnSQLite, 0,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add(cROOTKEY, ftInteger);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName(cROOTKEY).AsInteger := AIndex;
    end,
    'grandchild');
  FRest := TInertRestConnection.Create;
  FSeenByConsumer := '';
  FRaiseOnNextScroll := False;
end;

/// The CONSUMER's own AfterScroll - the one a screen assigns. It is captured
/// into FDataSetEvents by TDataSetBaseAdapter<M>.GetDataSetEvents, which runs
/// in the adapter's constructor, so it has to be on the dataset BEFORE the
/// adapter exists. Records only rows, never the Eof fire, so the string it
/// builds is a list of rows the walk passed through and not a count of events.
procedure TTestGrandchildRead.MidConsumerAfterScroll(DataSet: TDataSet);
begin
  if FRaiseOnNextScroll then
  begin
    // Once. The operator scroll that this test performs afterwards has to
    // reach the framework, not this handler.
    FRaiseOnNextScroll := False;
    raise Exception.Create('consumer AfterScroll blew up mid-walk');
  end;
  if DataSet.Eof then
    Exit;
  FSeenByConsumer := FSeenByConsumer + DataSet.FieldByName(cTAG).AsString + ';';
end;

procedure TTestGrandchildRead.TearDown;
begin
  FreeAndNil(FLeaf);
  FreeAndNil(FMid);
  FreeAndNil(FRoot);
  FreeAndNil(FLeafTable);
  FreeAndNil(FMidTable);
  FreeAndNil(FRootTable);
  FreeAndNil(FCdsLeaf);
  FreeAndNil(FCdsMid);
  FreeAndNil(FCdsRoot);
  FreeAndNil(FLeafCds);
  FreeAndNil(FMidCds);
  FreeAndNil(FRootCds);
  FreeAndNil(FRestLeaf);
  FreeAndNil(FRestMid);
  FreeAndNil(FRestRoot);
  FreeAndNil(FRestLeafTable);
  FreeAndNil(FRestMidTable);
  FreeAndNil(FRestRootTable);
  FreeAndNil(FOneLeaf);
  FreeAndNil(FOneMid);
  FreeAndNil(FOneRoot);
  FreeAndNil(FOneLeafTable);
  FreeAndNil(FOneMidTable);
  FreeAndNil(FOneRootTable);
  FRest := nil;
  FConn := nil;
end;

procedure TTestGrandchildRead.BuildLocalTree(const AWithLeaf: Boolean;
  const AWithConsumerScroll: Boolean);
begin
  FRootTable := TFDMemTable.Create(nil);
  FRoot := TFDMemTableAdapter<TAitRoot>.Create(FConn, FRootTable, -1, nil);
  FMidTable := TFDMemTable.Create(nil);
  // Assigned BEFORE the adapter exists on purpose - see MidConsumerAfterScroll.
  if AWithConsumerScroll then
    FMidTable.AfterScroll := MidConsumerAfterScroll;
  FMid := TFDMemTableAdapter<TAitMid>.Create(FConn, FMidTable, -1, FRoot);
  if not AWithLeaf then
    Exit;
  FLeafTable := TFDMemTable.Create(nil);
  FLeaf := TFDMemTableAdapter<TAitLeaf>.Create(FConn, FLeafTable, -1, FMid);
end;

procedure TTestGrandchildRead.BuildOneToOneTree;
begin
  FOneRootTable := TFDMemTable.Create(nil);
  FOneRoot := TFDMemTableAdapter<TAsymTreeOneRoot>.Create(FConn, FOneRootTable,
                -1, nil);
  FOneMidTable := TFDMemTable.Create(nil);
  FOneMid := TFDMemTableAdapter<TAsymTreeMid>.Create(FConn, FOneMidTable, -1,
               FOneRoot);
  FOneLeafTable := TFDMemTable.Create(nil);
  FOneLeaf := TFDMemTableAdapter<TAsymTreeLeaf>.Create(FConn, FOneLeafTable, -1,
                FOneMid);
end;

procedure TTestGrandchildRead.BuildCdsTree;
begin
  FRootCds := TClientDataSet.Create(nil);
  FCdsRoot := TClientDataSetAdapter<TAitRoot>.Create(FConn, FRootCds, -1, nil);
  FMidCds := TClientDataSet.Create(nil);
  FCdsMid := TClientDataSetAdapter<TAitMid>.Create(FConn, FMidCds, -1, FCdsRoot);
  FLeafCds := TClientDataSet.Create(nil);
  FCdsLeaf := TClientDataSetAdapter<TAitLeaf>.Create(FConn, FLeafCds, -1,
                FCdsMid);
end;

procedure TTestGrandchildRead.BuildRestTree;
begin
  FRestRootTable := TFDMemTable.Create(nil);
  FRestRoot := TRESTFDMemTableAdapter<TAitRoot>.Create(FRest, FRestRootTable,
                 -1, nil);
  FRestMidTable := TFDMemTable.Create(nil);
  FRestMid := TRESTFDMemTableAdapter<TAitMid>.Create(FRest, FRestMidTable, -1,
                FRestRoot);
  FRestLeafTable := TFDMemTable.Create(nil);
  FRestLeaf := TRESTFDMemTableAdapter<TAitLeaf>.Create(FRest, FRestLeafTable,
                 -1, FRestMid);
end;

procedure TTestGrandchildRead.AddRoot(const ADataSet: TDataSet;
  const ATag: String);
begin
  ADataSet.Append;
  ADataSet.FieldByName(cTAG).AsString := ATag;
  ADataSet.Post;
end;

/// The IsNull branch is NOT a convenience. DoNewRecord fetches the master's
/// values only when the row HAS children of its own - `if FMasterObject.Count
/// > 0` - so the middle level receives `root_id` from the framework in the
/// three level trees here and receives NOTHING in the two level control, where
/// no leaf adapter is registered under it. `root_id` is NotNull, so without
/// this the control would die on Post before it could measure anything. Both
/// paths end on the same value, 0, which is the grandparent's still pending
/// key - so the branch changes no assertion, it only keeps the control alive.
procedure TTestGrandchildRead.AddMid(const ADataSet: TDataSet;
  const ATag: String; const AOwnKey: Integer);
begin
  ADataSet.Append;
  ADataSet.FieldByName(cTAG).AsString := ATag;
  ADataSet.FieldByName(cMIDKEY).AsInteger := AOwnKey;
  if ADataSet.FieldByName(cROOTKEY).IsNull then
    ADataSet.FieldByName(cROOTKEY).AsInteger := 0;
  ADataSet.Post;
end;

/// `root_id` on the leaf is NotNull and NO association names it - it is the
/// negative control the AutoIncTree model documents - so it is typed by hand.
/// `mid_id` gets the sentinel: DoNewRecord only fetches the master's values
/// when the row HAS children, and the last level of a hierarchy never does.
procedure TTestGrandchildRead.AddLeaf(const ADataSet: TDataSet;
  const ATag: String);
begin
  ADataSet.Append;
  ADataSet.FieldByName(cTAG).AsString := ATag;
  ADataSet.FieldByName(cROOTKEY).AsInteger := 0;
  ADataSet.FieldByName(cMIDKEY).AsInteger := cSENTINEL;
  ADataSet.Post;
end;

procedure TTestGrandchildRead.ParkOnFirst(const ADataSet: TDataSet);
var
  LMute: TScrollMute;
begin
  LMute := MuteScroll(ADataSet);
  try
    ADataSet.First;
  finally
    UnmuteScroll(ADataSet, LMute);
  end;
end;

function TTestGrandchildRead.SignatureOf(const ADataSet: TDataSet;
  const ATagColumn: String; const AForeignKey: String): String;
var
  LMute: TScrollMute;
  LRows: Integer;
begin
  LMute := MuteScroll(ADataSet);
  try
    Result := '';
    LRows := 0;
    ADataSet.First;
    while (not ADataSet.Eof) and (LRows < cWALKCEIL) do
    begin
      Result := Result + ADataSet.FieldByName(ATagColumn).AsString + '/' +
                ADataSet.FieldByName(AForeignKey).AsString + ';';
      Inc(LRows);
      ADataSet.Next;
    end;
    if Result = '' then
      Result := cNOROW;
  finally
    UnmuteScroll(ADataSet, LMute);
  end;
end;

function TTestGrandchildRead.Signature(const ADataSet: TDataSet;
  const AForeignKey: String): String;
begin
  Result := SignatureOf(ADataSet, cTAG, AForeignKey);
end;

function TTestGrandchildRead.TagUnderCursor(const ADataSet: TDataSet): String;
begin
  if ADataSet.IsEmpty then
    Exit(cNOROW);
  Result := ADataSet.FieldByName(cTAG).AsString;
end;

function TTestGrandchildRead.GraphSignature(const ARoot: TAitRoot): String;
var
  LMid: TAitMid;
  LLeaf: TAitLeaf;
begin
  Result := '';
  for LMid in ARoot.mids do
  begin
    Result := Result + LMid.tag + '[';
    for LLeaf in LMid.leafs do
      Result := Result + LLeaf.tag + '/' + IntToStr(LLeaf.mid_id) + ';';
    Result := Result + ']';
  end;
  if Result = '' then
    Result := cNOROW;
end;

procedure TTestGrandchildRead.Premise_TheGrandchildRowIsThereBeforeAnythingIsRead;
begin
  BuildLocalTree;
  AddRoot(FRootTable, cROOTTAG);
  AddMid(FMidTable, cMIDTAG, cMIDKEY1);
  AddLeaf(FLeafTable, cLEAFTAG);

  Assert.AreEqual(cLEAFTAG + '/' + IntToStr(cSENTINEL) + ';',
    Signature(FLeafTable, cMIDKEY),
    'the operator must really have a grandchild line, carrying the sentinel ' +
    'foreign key, before anything is read - otherwise every other test here ' +
    'is vacuous');
end;

procedure TTestGrandchildRead.ReadingCurrentOnTheGrandparent_KeepsTheGrandchildRowAndItsForeignKey;
begin
  BuildLocalTree;
  AddRoot(FRootTable, cROOTTAG);
  AddMid(FMidTable, cMIDTAG, cMIDKEY1);
  AddLeaf(FLeafTable, cLEAFTAG);

  // ONE read. No ApplyUpdates, no scroll, no post - the smallest thing a
  // screen can do with the grandparent.
  FRoot.Current;

  Assert.AreEqual(cLEAFTAG + '/' + IntToStr(cSENTINEL) + ';',
    Signature(FLeafTable, cMIDKEY),
    'reading .Current of the grandparent walks the MIDDLE cursor, and that ' +
    'cursor fires TDataSetAdapter<M>.DoAfterScroll -> OpenDataSetChilds, ' +
    'which re-opened the leaf from the database and took the typed row with ' +
    'it. A read must not destroy rows');
  // Read off the grandparent row rather than written as a literal: the value
  // is the AutoInc pending placeholder the framework put there, and what this
  // clause says is "the middle row still carries its grandparent's key", not
  // "the key is minus one".
  Assert.AreEqual(cMIDTAG + '/' + FRootTable.FieldByName(cROOTKEY).AsString +
    ';', Signature(FMidTable, cROOTKEY),
    'and the middle row itself was never at risk - naming it here keeps the ' +
    'claim about the GRANDchild and not about children in general');
end;

procedure TTestGrandchildRead.Control_WithOnlyTwoLevels_TheSameReadKeepsTheChildRow;
begin
  BuildLocalTree(False);
  AddRoot(FRootTable, cROOTTAG);
  AddMid(FMidTable, cMIDTAG, cMIDKEY1);

  FRoot.Current;

  Assert.AreEqual(cMIDTAG + '/0;', Signature(FMidTable, cROOTKEY),
    'two levels never lost anything: Current moves the CHILD cursor, and a ' +
    'child with no children of its own has nothing for OpenDataSetChilds to ' +
    're-query');
end;

procedure TTestGrandchildRead.ClientDataSet_ReadingCurrentOnTheGrandparent_KeepsTheGrandchildRow;
begin
  BuildCdsTree;
  AddRoot(FRootCds, cROOTTAG);
  AddMid(FMidCds, cMIDTAG, cMIDKEY1);
  AddLeaf(FLeafCds, cLEAFTAG);

  FCdsRoot.Current;

  Assert.AreEqual(cLEAFTAG + '/' + IntToStr(cSENTINEL) + ';',
    Signature(FLeafCds, cMIDKEY),
    'TClientDataSetAdapter<M> descends from the same TDataSetAdapter<M>, so ' +
    'the family does not escape and the repair may not be family specific');
end;

procedure TTestGrandchildRead.Rest_ReadingCurrentOnTheGrandparent_NeverDestroyedTheGrandchildRow;
begin
  BuildRestTree;
  AddRoot(FRestRootTable, cROOTTAG);
  AddMid(FRestMidTable, cMIDTAG, cMIDKEY1);
  AddLeaf(FRestLeafTable, cLEAFTAG);

  FRestRoot.Current;

  Assert.AreEqual(cLEAFTAG + '/' + IntToStr(cSENTINEL) + ';',
    Signature(FRestLeafTable, cMIDKEY),
    'TRESTDataSetAdapter<M>.OpenDataSetChilds has an EMPTY BODY: the REST ' +
    'family never re-queried on scroll and therefore never had this defect. ' +
    'This was green before the repair as well, and it is here so that the ' +
    'difference between the families is measured rather than assumed');
end;

procedure TTestGrandchildRead.TheReadLeavesTheMidCursorWhereItFoundIt;
begin
  BuildLocalTree;
  AddRoot(FRootTable, cROOTTAG);
  AddMid(FMidTable, cMIDTAG, cMIDKEY1);
  AddMid(FMidTable, cMIDTAG2, cMIDKEY2);
  AddLeaf(FLeafTable, cLEAFTAG);
  ParkOnFirst(FMidTable);

  FRoot.Current;

  Assert.AreEqual(cMIDTAG, TagUnderCursor(FMidTable),
    'the walk runs First..Eof and restores the bookmark: the operator grid ' +
    'must be sitting where it was, whatever the repair does to the events');
end;

procedure TTestGrandchildRead.EachMidObjectInTheGraphCarriesTheGrandchildRowsThatAreLoaded;
var
  LRoot: TAitRoot;
begin
  BuildLocalTree;
  AddRoot(FRootTable, cROOTTAG);
  AddMid(FMidTable, cMIDTAG, cMIDKEY1);
  AddLeaf(FLeafTable, cLEAFTAG);

  // The adapter owns the instance Current hands back - it is FCurrentInternal,
  // not a copy, so it is not freed here.
  LRoot := FRoot.Current;

  Assert.AreEqual(cMIDTAG + '[' + cLEAFTAG + '/' + IntToStr(cSENTINEL) + ';]',
    GraphSignature(LRoot),
    'this is the question "who depends on the re-query happening here", ' +
    'answered with a measurement: NOBODY did. The re-open emptied the leaf ' +
    'dataset before the walk reached it, so the graph Current returned had ' +
    'every middle object carrying an EMPTY leafs list');
end;

procedure TTestGrandchildRead.AfterTheRead_AnOperatorScrollStillDiscards;
begin
  BuildLocalTree;
  AddRoot(FRootTable, cROOTTAG);
  AddMid(FMidTable, cMIDTAG, cMIDKEY1);
  AddMid(FMidTable, cMIDTAG2, cMIDKEY2);
  AddLeaf(FLeafTable, cLEAFTAG);
  ParkOnFirst(FMidTable);

  FRoot.Current;

  Assert.AreEqual(cLEAFTAG + '/' + IntToStr(cSENTINEL) + ';',
    Signature(FLeafTable, cMIDKEY),
    'premise: the read left the grandchild alone');

  // One keypress on the middle grid. This is the OPERATOR moving, which is the
  // case Test.Janus.Scroll.PendingChilds owns and this issue does not touch.
  FMidTable.Next;

  Assert.AreEqual(cMIDTAG2, TagUnderCursor(FMidTable),
    'the middle grid must really have moved, otherwise nothing was measured');
  Assert.AreEqual(cNOROW, Signature(FLeafTable, cMIDKEY),
    'and the historical discard is still there: the suppression the repair ' +
    'installs is scoped to the read walk and released when it ends. A ' +
    'suppression left switched on reddens exactly this line');
end;

procedure TTestGrandchildRead.OneToOneTop_ReadingCurrentOnTheGrandparent_KeepsTheGrandchildRow;
begin
  BuildOneToOneTree;
  // TAsymTreeOneRoot.mid starts nil BY DESIGN - its model header says so - and
  // a nil there is a DIFFERENT defect: _ExecuteOneToOne takes LValue.AsObject
  // and hands the nil straight to Bind.SetFieldToProperty, which dereferences
  // it. That AccessViolation is not what this test is about and it is not an
  // obstacle either: filling the property costs ONE line, and the line is safe
  // because with the root dataset still empty Current returns FCurrentInternal
  // on its RecordCount = 0 exit and walks nothing.
  FOneRoot.Current.mid := TAsymTreeMid.Create;

  FOneRootTable.Append;
  FOneRootTable.FieldByName(cONEROOTTAG).AsString := 'P1';
  FOneRootTable.Post;
  FOneMidTable.Append;
  FOneMidTable.FieldByName(cONEMIDTAG).AsString := 'AM1';
  FOneMidTable.Post;
  FOneLeafTable.Append;
  FOneLeafTable.FieldByName(cONELEAFTAG).AsString := 'AL1';
  FOneLeafTable.FieldByName(cONELEAFFK).AsInteger := cSENTINEL;
  FOneLeafTable.Post;

  Assert.AreEqual('AL1/' + IntToStr(cSENTINEL) + ';',
    SignatureOf(FOneLeafTable, cONELEAFTAG, cONELEAFFK),
    'premise: the grandchild line is on screen under a OneToOne top level too');

  FOneRoot.Current;

  Assert.AreEqual('AL1/' + IntToStr(cSENTINEL) + ';',
    SignatureOf(FOneLeafTable, cONELEAFTAG, cONELEAFFK),
    'a OneToOne top level reaches the SAME child cursor through ' +
    '_ExecuteOneToOne, whose First is exposed exactly like the one in ' +
    '_ExecuteOneToMany. Repairing one branch and not the other would close ' +
    'this issue with a read of .Current still destroying grandchildren in ' +
    'silence, in a shape the repository already ships a model for');
end;

procedure TTestGrandchildRead.AnExceptionInsideTheWalk_StillReleasesTheSuppression;
var
  LRaised: String;
begin
  BuildLocalTree(True, True);
  AddRoot(FRootTable, cROOTTAG);
  AddMid(FMidTable, cMIDTAG, cMIDKEY1);
  AddMid(FMidTable, cMIDTAG2, cMIDKEY2);
  AddLeaf(FLeafTable, cLEAFTAG);
  ParkOnFirst(FMidTable);

  LRaised := '';
  FRaiseOnNextScroll := True;
  try
    FRoot.Current;
  except
    on E: Exception do
      LRaised := E.Message;
  end;

  Assert.AreEqual('consumer AfterScroll blew up mid-walk', LRaised,
    'premise: the walk really was interrupted by an exception, and the ' +
    'exception really came from inside it');

  // One keypress on the middle grid, AFTER the failed read. The historical
  // discard has to be back.
  FMidTable.Next;

  Assert.AreEqual(cMIDTAG2, TagUnderCursor(FMidTable),
    'the middle grid must really have moved, otherwise nothing was measured');
  Assert.AreEqual(cNOROW, Signature(FLeafTable, cMIDKEY),
    'the release is in a `finally`, so an exception on the way out still ' +
    'lowers the counter. Without it the counter stays up for the life of the ' +
    'adapter and the operator scroll stops discarding FOREVER - a contract ' +
    'broken permanently, and invisibly to every other test in the suite');
end;

procedure TTestGrandchildRead.TheSuppressedWalk_StillFiresTheConsumersOwnAfterScroll;
begin
  BuildLocalTree(True, True);
  AddRoot(FRootTable, cROOTTAG);
  AddMid(FMidTable, cMIDTAG, cMIDKEY1);
  AddMid(FMidTable, cMIDTAG2, cMIDKEY2);
  AddLeaf(FLeafTable, cLEAFTAG);
  ParkOnFirst(FMidTable);
  FSeenByConsumer := '';

  FRoot.Current;

  Assert.AreEqual(cMIDTAG + ';' + cMIDTAG2 + ';' + cMIDTAG + ';',
    FSeenByConsumer,
    'the suppression takes down ONE call and not the event. The consumer''s ' +
    'own AfterScroll is reached through the `inherited` at the end of ' +
    'DoAfterScroll - the same `inherited` the paging leg rides on - and it ' +
    'still sees the walk pass through both rows and come back. A repair ' +
    'phrased as DisableDataSetEvents would have silenced all of this');
end;

procedure TTestGrandchildRead.TheSuppressedWalk_StillInjectsTheLazyProxiesOnScroll;
var
  LBefore: String;
begin
  BuildLocalTree;
  AddRoot(FRootTable, cROOTTAG);
  AddMid(FMidTable, cMIDTAG, cMIDKEY1);
  AddMid(FMidTable, cMIDTAG2, cMIDKEY2);
  AddLeaf(FLeafTable, cLEAFTAG);
  ParkOnFirst(FMidTable);

  LBefore := TReadAccess<TAitMid>.LastPK(FMid);
  Assert.AreNotEqual(cMIDKEY1AS, LBefore,
    'premise: the witness must not already hold the value the read is ' +
    'supposed to write, or the clause below would pass on a run where ' +
    '_InjectLazyProxiesOnScroll never ran at all');

  FRoot.Current;

  Assert.AreEqual(cMIDKEY1AS, TReadAccess<TAitMid>.LastPK(FMid),
    '_InjectLazyProxiesOnScroll sits beside the suppressed call inside the ' +
    'same guard, and the suppression must not SWALLOW it: it is still ' +
    'reached during the walk, and its last word is the row the cursor was ' +
    'put back on. Swallow it together with the re-open and a consumer''s ' +
    'lazy associations stop being injected, with nothing to say so. THIS ' +
    'CLAUSE SAYS NOTHING ABOUT HOW OFTEN IT RUNS, and it is not once per row ' +
    '- see the header');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestGrandchildRead);

end.
