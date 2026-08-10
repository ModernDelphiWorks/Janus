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

{ @abstract(Janus Framework - issue #262: the CascadeAutoInc recursion must not
  carry a key the generator has not produced.)

  WHAT #262 ASKED, AND WHAT WAS MEASURED

  TDataSetBaseAdapter<M>.SetAutoIncValueChilds recurses one level below the
  children it has just stamped, and the recursion is entered from
  _RecurseOverChildRows with the cursor parked on a child row that is still
  PENDING INSERT. At that instant the child's own key does not exist: every
  autoinc primary key carries DefaultExpression '-1', written by
  TBind.SetInternalInitFieldDefsObjectClass, so the pending row sits on the
  placeholder. The recursion then copies THAT into the grandchild's foreign
  key.

  The issue asked for four things to be measured rather than reasoned. Measured
  on a three-level AutoIncTree, level 3 driven through the SHIPPED ApplyInternal
  in both families, with the grandchild seeded on a SENTINEL - a value no row of
  the middle level carries - so that "nothing was written" can never be read as
  "the placeholder was written":

    1. Does the recursion write anything today? YES, IN BOTH FAMILIES. Local:
       LEAF.mid_id -7 -> -1 -> 201. REST: LEAF.mid_id -7 -> -1, and it stays.
    2. What is the value? The AUTOINC PLACEHOLDER of the middle level, whose own
       key has not been generated - mid.mid_id reads -1 at the instant of the
       write, and the middle row is still Integer(dsInsert).
    3. Does the result survive anywhere shipped? YES, in the REST family, and
       there only. TRESTFDMemTableAdapter<M>.ApplyInternal does not iterate
       FMasterObject, so the middle level is never applied on its own and
       nothing repairs the grandchild. The whole aggregate goes out in one POST.
    4. Is it dead? No. It is alive and it writes an invalid foreign key.

  THE LOCAL FAMILY CHANGED ITS ANSWER WHEN #276 LANDED, and that is why the
  order of attack was #276 -> #262. Before #276 the grandchild ROW was destroyed
  by the read of .Current on the grandparent before the cascade reached it, so
  the recursion had nothing to write on and the local family looked innocent.
  With the row surviving, the local family writes the placeholder too - it is
  merely repaired afterwards, by the middle level's own ApplyInserter.

  WHAT THE FIX IS, AND WHAT IT IS NOT

  It is NOT "stop recursing over pending rows". A pending row may hold a key its
  consumer typed - Test.Janus.AutoInc.Childs.Linked_EveryGrandchildRowReceives
  TheNewKey is exactly that shape, and its grandchildren must still be stamped.
  The defect is narrower and has the framework's own marker for it: propagating
  a key column that still reads the autoinc placeholder. So the guard is on the
  VALUE, not on the row state, and the third test below is what holds the fix to
  that narrower reading.

  ONE GUARD COVERS BOTH FAMILIES because SetAutoIncValueChilds is declared once,
  on TDataSetBaseAdapter<M>, and every call site reaches that one body:
  TFDMemTableAdapter<M>.ApplyInserter, TClientDataSetAdapter<M>.ApplyInserter and
  TRESTDataSetAdapter<M>.ApplyInserter. The two tests below drive two of the
  three; the ClientDataSet call site is NOT MEASURED here.

  WHY THE LOCAL TEST WATCHES THE WRITE INSTEAD OF THE ROW

  Locally the placeholder is overwritten a moment later by the middle level's own
  pass, so a test that reads the grandchild after the apply sees the right value
  either way and would be green over the defect. The local test therefore arms
  TField.OnChange on the grandchild's foreign key and asserts over the VALUES
  WRITTEN, in order. TField.OnChange survives both mutes the production path
  installs - DisableDataSetEvents only nils the DATASET's events - which is the
  same technique Test.Janus.AutoInc.Childs.NoPendingLeafRow_TheProbeRecordsNo
  WriteAtAll relies on.

  THE MUTATION LOG, AND THE THREE THAT SURVIVE

  Every line below was applied to the fix, built and run. The suite is
  Janus.Tests.Units, 533 tests, 0 failures unmutated.

    * REMOVING THE GUARD from SetAutoIncValueChilds reddens
      Local_TheGrandchildKeyIsNeverWrittenWithTheMidPlaceholder and
      Rest_TheGrandchildKeepsItsOwnValueInsteadOfTheMidPlaceholder - those two,
      and nothing else in the suite.

    * MAKING _AutoIncKeyIsGenerated ALWAYS REFUSE reddens 27, including
      Local_AMidRowThatAlreadyCarriesItsKey_StillStampsTheGrandchild and the
      whole Test.Janus.AutoInc.Childs recursion group. That is the over-broad
      reading of #262 - "do not recurse over pending rows" - and this is its
      price in one number.

    * REMOVING `if not LPrimaryKey.AutoIncrement` reddens
      NotIncKey_MinusOneIsAnOrdinaryKeyAndIsStillPropagated alone.

    * REMOVING THE GUARD **AND** weakening this file's local clause to a
      row-only reading - "the grandchild ends on its parent's key" instead of
      "the placeholder was never written" - leaves the LOCAL test GREEN over the
      live defect, and only the REST test red. That is the measurement that
      earns the TField.OnChange form, and it is also the proof that the two
      family tests are not each other's copy: they see different things.

    * SURVIVING, and declared rather than hidden: removing
      `if not (LField.DataType in cINTEGERKINDS)` changes nothing here. No
      entity in this test tree has a non-integral autoinc primary key, so
      nothing reaches the branch. The shape that would - an ftGuid key under
      CascadeAutoInc - is contradictory by construction, and is where issue #284
      lives; NOT MEASURED.

    * SURVIVING, likewise declared: removing
      `if LPrimaryKey.Columns.IndexOf(AAssociation.ColumnsName[LFor]) < 0`
      changes nothing here. Every association in this tree names the declaring
      entity's own primary key - Test.Janus.Model.AsymKey records that as eight
      of eight across the models Janus.Tests.Units compiles - so no association
      reaches the branch. An association propagating a NON-key column that reads
      -1 is NOT MEASURED.

  WHAT IS NOT MEASURED HERE

  No live database and no live REST server: the generator is TTreeConnection and
  the server is TSeqRestConnection, both from Test.Janus.AutoInc.Distribution.
  The ClientDataSet and RESTClientDataSet families are not driven. Four levels
  are not driven.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.AutoInc.UngeneratedKey;

interface

uses
  DB,
  Classes,
  SysUtils,
  Generics.Collections,
  DUnitX.TestFramework,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  DataEngine.FactoryInterfaces,
  Janus.DataSet.Fields,
  Janus.DataSet.Base.Adapter,
  Janus.DataSet.FDMemTable,
  Janus.RestDataSet.FDMemTable,
  Janus.RestFactory.Interfaces,
  Test.Janus.Model.AutoIncTree,
  Test.Janus.Model.NotIncKey,
  Test.Janus.AutoInc.Distribution;

type
  [TestFixture]
  TTestAutoIncUngeneratedKey = class
  private
    FTree: TTreeConnection;
    FConn: IDBConnection;
    FRootTable: TFDMemTable;
    FMidTable: TFDMemTable;
    FLeafTable: TFDMemTable;
    FRoot: TFDMemTableAdapter<TAitRoot>;
    FMid: TFDMemTableAdapter<TAitMid>;
    FLeaf: TFDMemTableAdapter<TAitLeaf>;
    /// Every value written into the grandchild's foreign key, in order.
    FLeafWrites: TList<Integer>;
    procedure LeafFKChanged(Sender: TField);
    /// Reads one column of the FIRST row with the dataset's scroll events
    /// muted. Scrolling a level re-opens the level below it, which is the very
    /// thing #276 corrected; an assertion helper must not undo it.
    function FirstRowValue(const ADataSet: TDataSet;
      const AColumn: String): Integer;
    function WrittenValues: String;
    procedure SeedLocalTree(const AMidOwnKey: Integer);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// The defect as the local family shows it: a write that happens and is
    /// then papered over. Asserted on the values written, not on the row.
    [Test]
    procedure Local_TheGrandchildKeyIsNeverWrittenWithTheMidPlaceholder;

    /// The defect where it SURVIVES: the REST family applies no level but the
    /// first, so the placeholder is what the grandchild is left holding.
    [Test]
    procedure Rest_TheGrandchildKeepsItsOwnValueInsteadOfTheMidPlaceholder;

    /// The other side of the fork. The guard is on the VALUE, so a middle row
    /// that already carries a real key must still stamp its grandchildren -
    /// a blanket "do not recurse over pending rows" would redden this alone.
    [Test]
    procedure Local_AMidRowThatAlreadyCarriesItsKey_StillStampsTheGrandchild;

    /// The third side, and the one that says WHERE the placeholder reading is
    /// allowed to apply at all: on a key declared NotInc no placeholder is ever
    /// written, so -1 there is an ordinary value and must still travel.
    [Test]
    procedure NotIncKey_MinusOneIsAnOrdinaryKeyAndIsStillPropagated;
  end;

implementation

const
  cROOTKEY   = 'root_id';
  cMIDKEY    = 'mid_id';
  cTAG       = 'tag';
  /// The generator hands out 100, 200, 300 ... so the root comes out on 101 and
  /// the middle level on 201 - see TTreeConnection.
  cSTEP      = 100;
  cRESTSTEP  = 300;
  /// A value NO row of the middle level carries, at any moment of the run. It
  /// is what makes "the recursion wrote nothing" impossible to confuse with
  /// "the recursion wrote the placeholder" or with "the recursion wrote zero".
  cLEAFSEED  = -7;
  /// What TBind.SetInternalInitFieldDefsObjectClass puts on every autoinc
  /// primary key as DefaultExpression, and therefore what a pending row of any
  /// level reads back before its own insert runs.
  cPLACEHOLDER = -1;
  /// A key the consumer typed on a row that is still pending - the shape
  /// Test.Janus.AutoInc.Childs.Linked_EveryGrandchildRowReceivesTheNewKey uses.
  cMIDTYPEDKEY = 777;
  cROOTTYPEDKEY = 555;

procedure TTestAutoIncUngeneratedKey.Setup;
begin
  FLeafWrites := TList<Integer>.Create;
  FTree := TTreeConnection.CreateTree(cSTEP);
  FConn := FTree;
  FRootTable := TFDMemTable.Create(nil);
  FMidTable := TFDMemTable.Create(nil);
  FLeafTable := TFDMemTable.Create(nil);
  FRoot := TFDMemTableAdapter<TAitRoot>.Create(FConn, FRootTable, -1, nil);
  FMid := TFDMemTableAdapter<TAitMid>.Create(FConn, FMidTable, -1, FRoot);
  FLeaf := TFDMemTableAdapter<TAitLeaf>.Create(FConn, FLeafTable, -1, FMid);
end;

procedure TTestAutoIncUngeneratedKey.TearDown;
begin
  FLeaf.Free;
  FMid.Free;
  FRoot.Free;
  FLeafTable.Free;
  FMidTable.Free;
  FRootTable.Free;
  FConn := nil;
  FTree := nil;
  FLeafWrites.Free;
end;

procedure TTestAutoIncUngeneratedKey.LeafFKChanged(Sender: TField);
begin
  FLeafWrites.Add(Sender.AsInteger);
end;

function TTestAutoIncUngeneratedKey.FirstRowValue(const ADataSet: TDataSet;
  const AColumn: String): Integer;
var
  LBefore: TDataSetNotifyEvent;
  LAfter: TDataSetNotifyEvent;
begin
  LBefore := ADataSet.BeforeScroll;
  LAfter := ADataSet.AfterScroll;
  ADataSet.BeforeScroll := nil;
  ADataSet.AfterScroll := nil;
  try
    ADataSet.First;
    Result := ADataSet.FieldByName(AColumn).AsInteger;
  finally
    ADataSet.BeforeScroll := LBefore;
    ADataSet.AfterScroll := LAfter;
  end;
end;

function TTestAutoIncUngeneratedKey.WrittenValues: String;
var
  LFor: Integer;
begin
  if FLeafWrites.Count = 0 then
    Exit('<no write>');
  Result := '';
  for LFor := 0 to FLeafWrites.Count - 1 do
    Result := Result + IntToStr(FLeafWrites[LFor]) + ' ';
end;

/// One row per level, every adapter event LIVE - the configuration Janus ships.
/// The leaf's own root_id is typed by hand because it is NotNull and NO
/// association names it: it is the fixture's negative control for ancestor
/// propagation, not a foreign key.
procedure TTestAutoIncUngeneratedKey.SeedLocalTree(const AMidOwnKey: Integer);
begin
  FRootTable.Append;
  FRootTable.FieldByName(cTAG).AsString := 'R1';
  FRootTable.Post;

  FMidTable.Append;
  FMidTable.FieldByName(cTAG).AsString := 'M1';
  if AMidOwnKey <> cPLACEHOLDER then
    FMidTable.FieldByName(cMIDKEY).AsInteger := AMidOwnKey;
  FMidTable.Post;

  FLeafTable.Append;
  FLeafTable.FieldByName(cTAG).AsString := 'L1';
  FLeafTable.FieldByName(cMIDKEY).AsInteger := cLEAFSEED;
  FLeafTable.FieldByName(cROOTKEY).AsInteger := 0;
  FLeafTable.Post;
end;

procedure TTestAutoIncUngeneratedKey.
  Local_TheGrandchildKeyIsNeverWrittenWithTheMidPlaceholder;
var
  LMidKey: Integer;
begin
  SeedLocalTree(cPLACEHOLDER);

  // PREMISE. Without these two the whole test could pass over a run in which
  // the middle level already had a key, or in which the seed never took.
  Assert.AreEqual(cPLACEHOLDER, FirstRowValue(FMidTable, cMIDKEY),
    'the middle row must start on the autoinc placeholder - if it does not, ' +
    'this fixture is not measuring an ungenerated key at all');
  Assert.AreEqual(cLEAFSEED, FirstRowValue(FLeafTable, cMIDKEY),
    'the grandchild must start on the sentinel');

  FLeafTable.FieldByName(cMIDKEY).OnChange := LeafFKChanged;
  try
    TCascadeAccess<TAitRoot>.ApplyAll(FRoot);
  finally
    FLeafTable.FieldByName(cMIDKEY).OnChange := nil;
  end;

  // PREMISE. Three rows, three generated keys: root, mid and leaf each went
  // through a real insert. Zero here would make every clause below vacuous.
  Assert.AreEqual(3, FTree.SequenceCalls,
    'the generator must have been asked once per pending row of the whole ' +
    'hierarchy - otherwise nothing was applied and nothing is being measured');

  Assert.IsFalse(FLeafWrites.Contains(cPLACEHOLDER),
    'the recursion must never write the autoinc placeholder into the ' +
    'grandchild foreign key: that key does not exist yet at the instant the ' +
    'recursion fires. Values written, in order: ' + WrittenValues);

  // And the cascade must still do its job: the grandchild ends on the key the
  // generator really produced for its own parent.
  LMidKey := FirstRowValue(FMidTable, cMIDKEY);
  Assert.AreNotEqual(cPLACEHOLDER, LMidKey,
    'the middle row must have been given a real key by its own insert');
  Assert.AreEqual(LMidKey, FirstRowValue(FLeafTable, cMIDKEY),
    'the grandchild must come out on the key its OWN parent generated');
end;

procedure TTestAutoIncUngeneratedKey.
  Rest_TheGrandchildKeepsItsOwnValueInsteadOfTheMidPlaceholder;
var
  LRest: IRESTConnection;
  LRootTable: TFDMemTable;
  LMidTable: TFDMemTable;
  LLeafTable: TFDMemTable;
  LRoot: TRESTFDMemTableAdapter<TAitRoot>;
  LMid: TRESTFDMemTableAdapter<TAitMid>;
  LLeaf: TRESTFDMemTableAdapter<TAitLeaf>;
begin
  LRest := TSeqRestConnection.CreateSeq(cROOTKEY, cRESTSTEP);
  LRootTable := TFDMemTable.Create(nil);
  LMidTable := TFDMemTable.Create(nil);
  LLeafTable := TFDMemTable.Create(nil);
  try
    LRoot := TRESTFDMemTableAdapter<TAitRoot>.Create(LRest, LRootTable, -1, nil);
    LMid := TRESTFDMemTableAdapter<TAitMid>.Create(LRest, LMidTable, -1, LRoot);
    LLeaf := TRESTFDMemTableAdapter<TAitLeaf>.Create(LRest, LLeafTable, -1,
               LMid);
    try
      LRootTable.Append;
      LRootTable.FieldByName(cTAG).AsString := 'R1';
      LRootTable.Post;
      LMidTable.Append;
      LMidTable.FieldByName(cTAG).AsString := 'M1';
      LMidTable.Post;
      LLeafTable.Append;
      LLeafTable.FieldByName(cTAG).AsString := 'L1';
      LLeafTable.FieldByName(cMIDKEY).AsInteger := cLEAFSEED;
      LLeafTable.FieldByName(cROOTKEY).AsInteger := 0;
      LLeafTable.Post;

      Assert.AreEqual(cPLACEHOLDER, FirstRowValue(LMidTable, cMIDKEY),
        'the middle row must start on the autoinc placeholder');

      TCascadeAccess<TAitRoot>.ApplyAll(LRoot);

      // PREMISE. The cascade really ran: the server answered a key for the
      // root, and level 2 really received it.
      Assert.AreEqual(cRESTSTEP, FirstRowValue(LRootTable, cROOTKEY),
        'the root must carry the key the REST server answered - otherwise ' +
        'ApplyInserter never reached SetAutoIncValueChilds');
      Assert.AreEqual(cRESTSTEP, FirstRowValue(LMidTable, cROOTKEY),
        'level 2 must have been stamped with the root new key: that write is ' +
        'legitimate and must not be lost with the one under test');
      // PREMISE, and the reason nothing repairs the grandchild here:
      // TRESTFDMemTableAdapter<M>.ApplyInternal does not iterate FMasterObject,
      // so the middle level is never applied on its own.
      Assert.AreEqual(Integer(dsInsert),
        FirstRowValue(LMidTable, cInternalField),
        'the middle level must still be pending after the apply - if it were ' +
        'applied, the REST family would repair the grandchild and this test ' +
        'would be measuring the local family by accident');

      Assert.AreNotEqual(cPLACEHOLDER, FirstRowValue(LLeafTable, cMIDKEY),
        'the grandchild must not be left holding the middle level autoinc ' +
        'placeholder: nothing in the REST family ever comes back to fix it');
      Assert.AreEqual(cLEAFSEED, FirstRowValue(LLeafTable, cMIDKEY),
        'with no key to propagate, the grandchild must come out exactly as ' +
        'it went in - which is also what the POST carried to the server');
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

procedure TTestAutoIncUngeneratedKey.
  Local_AMidRowThatAlreadyCarriesItsKey_StillStampsTheGrandchild;
begin
  SeedLocalTree(cMIDTYPEDKEY);

  // The master carries a key of its own, the way ApplyInserter leaves it just
  // before the propagation: in dsEdit, holding the generated key, not posted.
  FRootTable.Edit;
  FRootTable.FieldByName(cROOTKEY).AsInteger := cROOTTYPEDKEY;

  Assert.AreEqual(cMIDTYPEDKEY, FirstRowValue(FMidTable, cMIDKEY),
    'the middle row must really be carrying a key of its own');

  TCascadeAccess<TAitRoot>.Propagate(FRoot);

  Assert.AreEqual(cROOTTYPEDKEY, FirstRowValue(FMidTable, cROOTKEY),
    'level 2 must receive the master key');
  Assert.AreEqual(cMIDTYPEDKEY, FirstRowValue(FLeafTable, cMIDKEY),
    'level 3 must receive the middle level own key: the guard is on the ' +
    'VALUE of the key, not on the pending state of the row, and a middle row ' +
    'whose key already exists must still stamp its grandchildren');
end;

procedure TTestAutoIncUngeneratedKey.
  NotIncKey_MinusOneIsAnOrdinaryKeyAndIsStillPropagated;
var
  LRootTable: TFDMemTable;
  LChildTable: TFDMemTable;
  LRoot: TFDMemTableAdapter<TNikRoot>;
  LChild: TFDMemTableAdapter<TNikChild>;
begin
  // The one entity family in the tree whose primary key is TAutoIncType.NotInc.
  // TBind.SetInternalInitFieldDefsObjectClass writes the placeholder
  // DefaultExpression ONLY for an autoinc key, so -1 here was typed by whoever
  // owns the row and is a key like any other.
  LRootTable := TFDMemTable.Create(nil);
  LChildTable := TFDMemTable.Create(nil);
  try
    LRoot := TFDMemTableAdapter<TNikRoot>.Create(FConn, LRootTable, -1, nil);
    LChild := TFDMemTableAdapter<TNikChild>.Create(FConn, LChildTable, -1,
                LRoot);
    try
      LRootTable.Append;
      LRootTable.FieldByName('nik_id').AsInteger := cPLACEHOLDER;
      LRootTable.FieldByName(cTAG).AsString := 'R1';
      LRootTable.Post;
      LChildTable.Append;
      LChildTable.FieldByName('child_id').AsInteger := 1;
      LChildTable.FieldByName('nik_id').AsInteger := cLEAFSEED;
      LChildTable.FieldByName(cTAG).AsString := 'C1';
      LChildTable.Post;

      Assert.AreEqual(cPLACEHOLDER, FirstRowValue(LRootTable, 'nik_id'),
        'PREMISE: the master must really be sitting on -1');
      Assert.AreEqual(cLEAFSEED, FirstRowValue(LChildTable, 'nik_id'),
        'PREMISE: the child must start on the sentinel');

      TCascadeAccess<TNikRoot>.Propagate(LRoot);

      Assert.AreEqual(cPLACEHOLDER, FirstRowValue(LChildTable, 'nik_id'),
        'a -1 on a NotInc key is an ordinary value and must still be ' +
        'propagated: the placeholder reading belongs to autoinc keys alone, ' +
        'and reading it here would refuse a key the consumer typed');
    finally
      LChild.Free;
      LRoot.Free;
    end;
  finally
    LChildTable.Free;
    LRootTable.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestAutoIncUngeneratedKey);

end.
