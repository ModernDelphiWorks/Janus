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

  THE TWO FAMILIES ARE NOT THE SAME, AND ONE FIX COVERS BOTH

  TFDMemTableAdapter<M> and TClientDataSetAdapter<M> both descend from
  TDataSetAdapter<M>, whose OpenDataSetChilds really re-queries: both lost the
  grandchildren. TRESTDataSetAdapter<M>.OpenDataSetChilds has an EMPTY BODY, so
  the REST family never lost anything and needs no repair -
  Rest_ReadingCurrentOnTheGrandparent_NeverDestroyedTheGrandchildRow measures
  that claim instead of repeating it, and it was green before the fix as well.

  THE MUTATIONS THAT WERE RUN, AND WHAT DIED IN EACH

  The repair has two halves that look alike and are not - the First and the
  GotoBookmark of the walk in _ExecuteOneToMany - so each was suppressed on its
  own and made to kill a DIFFERENT set. Baseline for all four: 514 found, 514
  passed.

    1. suppression removed altogether (DoAfterScroll re-opens unconditionally)
       -> 4 red: ReadingCurrentOnTheGrandparent, ClientDataSet_ReadingCurrent,
          EachMidObjectInTheGraph, AfterTheRead_AnOperatorScrollStillDiscards.
    2. suppression raised and NEVER released (the Dec deleted)
       -> 1 red, and only one: AfterTheRead_AnOperatorScrollStillDiscards. The
          operator's own scroll stopped discarding, which is the contract this
          issue may not touch.
    3. only the First protected, the bookmark restore left exposed
       -> 3 red. EachMidObjectInTheGraph STAYS GREEN, and the difference is the
          measurement: the graph is built during the walk, and the restore
          destroys the leaf rows a moment AFTER it, so a fix that stopped at
          the First would have returned a correct object graph over a table it
          had just emptied.
    4. only the bookmark restore protected, the First left exposed
       -> 4 red, EachMidObjectInTheGraph among them: there the leaf is gone
          BEFORE the walk reads it.

  Three and four are the reason the suppression spans the whole block: neither
  scroll is redundant, and they fail differently.

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
  Test.Janus.Cursor.Double,
  /// Only for TInertRestConnection, the IRESTConnection double that fixture
  /// already ships.
  Test.Janus.MasterDetail.Link;

type
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
    procedure BuildLocalTree(const AWithLeaf: Boolean = True);
    procedure BuildCdsTree;
    procedure BuildRestTree;
    procedure AddRoot(const ADataSet: TDataSet; const ATag: String);
    procedure AddMid(const ADataSet: TDataSet; const ATag: String);
    procedure AddLeaf(const ADataSet: TDataSet; const ATag: String);
    procedure ParkOnFirst(const ADataSet: TDataSet);
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
  FRest := nil;
  FConn := nil;
end;

procedure TTestGrandchildRead.BuildLocalTree(const AWithLeaf: Boolean);
begin
  FRootTable := TFDMemTable.Create(nil);
  FRoot := TFDMemTableAdapter<TAitRoot>.Create(FConn, FRootTable, -1, nil);
  FMidTable := TFDMemTable.Create(nil);
  FMid := TFDMemTableAdapter<TAitMid>.Create(FConn, FMidTable, -1, FRoot);
  if not AWithLeaf then
    Exit;
  FLeafTable := TFDMemTable.Create(nil);
  FLeaf := TFDMemTableAdapter<TAitLeaf>.Create(FConn, FLeafTable, -1, FMid);
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
  const ATag: String);
begin
  ADataSet.Append;
  ADataSet.FieldByName(cTAG).AsString := ATag;
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

function TTestGrandchildRead.Signature(const ADataSet: TDataSet;
  const AForeignKey: String): String;
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
      Result := Result + ADataSet.FieldByName(cTAG).AsString + '/' +
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
  AddMid(FMidTable, cMIDTAG);
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
  AddMid(FMidTable, cMIDTAG);
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
  AddMid(FMidTable, cMIDTAG);

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
  AddMid(FMidCds, cMIDTAG);
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
  AddMid(FRestMidTable, cMIDTAG);
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
  AddMid(FMidTable, cMIDTAG);
  AddMid(FMidTable, cMIDTAG2);
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
  AddMid(FMidTable, cMIDTAG);
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
  AddMid(FMidTable, cMIDTAG);
  AddMid(FMidTable, cMIDTAG2);
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

initialization
  TDUnitX.RegisterTestFixture(TTestGrandchildRead);

end.
