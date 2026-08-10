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

{ @abstract(Janus Framework - the scroll contract for unsaved child rows.)

  WHAT IS UNDER TEST

  TDataSetBaseAdapter<M>.OnBeforeScrollPendingChilds, fired by
  TDataSetAdapter<M>.DoBeforeScroll, and the three answers a consumer can give
  it: pcaDiscard, pcaPost and pcaCancel.

  WHAT WAS HAPPENING BEFORE IT EXISTED

  TDataSetAdapter<M>.DoAfterScroll calls OpenDataSetChilds, which re-opens every
  child dataset from the database (OpenSQLInternal starts with EmptyDataSet). So
  the operator sitting on order #1, who typed three lines into the detail grid
  and did not save, loses all three the moment the master moves to order #2 - no
  error, no prompt, no trace. Measured by
  Premise_ScrollingTheMasterDiscardsTypedChildRows.

  THAT SENTENCE IS NOW SCOPED, BY ISSUE #276. DoAfterScroll re-opens the
  children on an OPERATOR scroll, which is every move this fixture makes and
  the only kind the contract below is about. It re-opens NOTHING while the
  framework's own read walk is moving the cursor - _ExecuteOneToMany AND
  _ExecuteOneToOne, both of them, so a read driven by a OneToOne or a ManyToOne
  association discards nothing either. A read of .Current used to destroy the
  grandchildren the same way, and there nobody had chosen anything. Measured by
  Test.Janus.Grandchild.Read.

  WHY THIS IS A CONTRACT AND NOT A FIX

  Four behaviours were on the table - discard, post, block the scroll, keep in
  memory - and none of them is the framework's policy, because an open-source
  framework does not change what existing consumers see. So the DEFAULT is
  byte-for-byte the old discard: with no handler assigned,
  DoBeforeScrollPendingChilds returns on its first line. What changed is that
  the discard is now somebody's decision instead of a side effect of a re-query.

  WHAT COUNTS AS "PENDING", MEASURED AND NOT DEDUCED

  Two different markers, and neither alone is enough - see the Marker_* tests:
    * a row being typed right now has not reached DoBeforePost, so the internal
      column still carries the default '-1' written by Bind.SetDataDictionary;
      only TDataSet.State says anything;
    * a row already posted into the in-memory table carries Integer(dsInsert) or
      Integer(dsEdit) in that column, and its State is dsBrowse.
  TFDMemTable.ChangeCount answers 0 either way, because
  TFDMemTableAdapter<M>.Create sets CachedUpdates := False and
  LogChanges := False.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`. A line anchor rots on the first
  commit that inserts a line above it.
}

unit Test.Janus.Scroll.PendingChilds;

interface

uses
  DB,
  Classes,
  SysUtils,
  Variants,
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
  Janus.DataSet.Events,
  Janus.DataSet.Base.Adapter,
  Janus.DataSet.ClientDataSet,
  Janus.RestFactory.Interfaces,
  Janus.RestDataSet.FDMemTable,
  Janus.Container.DataSet.Interfaces,
  Janus.Container.FDMemTable,
  Test.Janus.Model.AutoIncTree,
  Test.Janus.Cursor.Double,
  /// Only for TInertRestConnection, the IRESTConnection double that fixture
  /// already ships. Writing a second one would be a second thing to keep true.
  Test.Janus.MasterDetail.Link;

type
  /// <summary> Classic protected-access descendant. DoBeforeScrollPendingChilds
  ///  is protected and its production trigger is a real scroll - which also
  ///  re-opens the children a moment later, destroying the very thing a test
  ///  about DETECTION needs to look at. Calling it directly is what separates
  ///  "did asking the question cost anything" from "what happened after the
  ///  master moved". </summary>
  TScrollAccess<M: class, constructor> = class(TDataSetBaseAdapter<M>)
  public
    class procedure Ask(const AAdapter: TDataSetBaseAdapter<M>);
  end;

  [TestFixture]
  TTestScrollPendingChilds = class
  private
    FConn: IDBConnection;
    FRest: IRESTConnection;
    FRootTable: TFDMemTable;
    FMidTable: TFDMemTable;
    FLeafTable: TFDMemTable;
    FRoot: IContainerDataSet<TAitRoot>;
    FMid: IContainerDataSet<TAitMid>;
    FLeaf: IContainerDataSet<TAitLeaf>;
    FRootCds: TClientDataSet;
    FMidCds: TClientDataSet;
    FCdsRoot: TClientDataSetAdapter<TAitRoot>;
    FCdsMid: TClientDataSetAdapter<TAitMid>;
    FRestRootTable: TFDMemTable;
    FRestMidTable: TFDMemTable;
    FRestRoot: TRESTFDMemTableAdapter<TAitRoot>;
    FRestMid: TRESTFDMemTableAdapter<TAitMid>;
    // What the handler under test will answer, and what it saw.
    FAnswer: TPendingChildsAction;
    FCalls: Integer;
    FSeenChilds: Integer;
    FSeenSender: TObject;
    // What the child adapter's OWN ApplyUpdates events reported.
    FApplyBefore: Integer;
    FApplyAfter: Integer;
    FPersistedOnApply: Integer;
    procedure Decide(const ASender: TObject;
      const APendingChilds: TArray<TDataSet>;
      var AAction: TPendingChildsAction);
    procedure Ignore(const ASender: TObject;
      const APendingChilds: TArray<TDataSet>;
      var AAction: TPendingChildsAction);
    procedure MidBeforeApply(DataSet: TFDDataSet);
    procedure MidAfterApply(DataSet: TFDDataSet; AErrors: Integer);
    procedure BuildTree(const AWithLeaf: Boolean = False);
    procedure BuildCdsPair;
    procedure BuildRestPair;
    procedure AddRootRow(const AKey: Integer);
    procedure AddChildRow(const ADataSet: TDataSet; const AOwnKey: Integer;
      const ARootKey: Integer; const ATag: String);
    procedure MarkRowPersisted(const ADataSet: TDataSet);
    procedure ParkMasterOnFirst(const ADataSet: TDataSet);
    function RowCount(const ADataSet: TDataSet): Integer;
    function CountWithMarker(const ADataSet: TDataSet;
      const AMarker: Integer): Integer;
    function MasterKey(const ADataSet: TDataSet): Integer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // -----------------------------------------------------------------------
    // The premise, and what "pending" really is
    // -----------------------------------------------------------------------

    /// The defect in one measurement: three typed lines, one keypress, zero
    /// lines. If this ever goes green on its own the whole fixture is blind.
    [Test]
    procedure Premise_ScrollingTheMasterDiscardsTypedChildRows;
    /// A row posted into the in-memory table but never applied carries
    /// Integer(dsInsert) in the internal column, and its State is dsBrowse.
    [Test]
    procedure Marker_APostedButUnsavedRowCarriesTheInsertMarker;
    /// A row still being typed carries the DEFAULT -1: DoBeforePost has not run
    /// yet. Only State shows it. A detector that trusted the column alone would
    /// miss exactly the line the operator has under the cursor.
    [Test]
    procedure Marker_ARowBeingTypedIsInvisibleToTheInternalColumn;
    /// The reverse guard: a row already saved is NOT pending, so the handler is
    /// never called for it.
    [Test]
    procedure Marker_APersistedRowDoesNotTriggerTheHandler;
    /// Why FireDAC's own answer cannot be used: the adapter turns the change
    /// log off in its constructor, so ChangeCount is 0 with three rows pending.
    [Test]
    procedure Marker_ChangeCountIsBlindToPendingRows;

    // -----------------------------------------------------------------------
    // The default
    // -----------------------------------------------------------------------

    /// A handler that answers pcaDiscard reaches the same end state as having
    /// no handler at all. Note what this does NOT do: it assigns a handler and
    /// requires it to be called, so it goes red if the hook is removed. The
    /// test that proves the default survives, with no handler in play, is
    /// Premise_ScrollingTheMasterDiscardsTypedChildRows.
    [Test]
    procedure Choice_Discard_ReproducesTheNoHandlerEndState;
    /// A handler that never touches AAction gets the same, because the adapter
    /// pre-seeds it with pcaDiscard.
    [Test]
    procedure Default_AHandlerThatIgnoresTheParameterStillDiscards;
    /// Nothing pending, nothing to decide: the handler is not called at all.
    [Test]
    procedure NoPendingChilds_TheHandlerIsNeverCalled;

    // -----------------------------------------------------------------------
    // The other two choices
    // -----------------------------------------------------------------------

    /// pcaCancel: the master does not move and the typed rows are still there,
    /// still pending.
    [Test]
    procedure Choice_Cancel_TheMasterStaysAndTheRowsSurvive;
    /// pcaPost: the child's own ApplyUpdates runs before the master moves, and
    /// by the time it returns every typed row has been marked persisted.
    [Test]
    procedure Choice_Post_ThePendingRowsAreSavedBeforeTheMasterMoves;

    // -----------------------------------------------------------------------
    // The cost of asking
    // -----------------------------------------------------------------------

    /// Detecting pendency walks the child dataset. Walking it with its events
    /// live fires ITS AfterScroll, which re-reads the grandchildren - the very
    /// trap the autoinc fix ran into. The question must not destroy the answer.
    [Test]
    procedure Detecting_DoesNotDestroyTheGrandchildren;
    /// The handler is handed the child datasets that are actually at risk, and
    /// the adapter that is about to scroll.
    [Test]
    procedure Handler_ReceivesThePendingChildAndTheSender;

    // -----------------------------------------------------------------------
    // The other families
    // -----------------------------------------------------------------------

    /// TClientDataSetAdapter descends from the same TDataSetAdapter<M> and
    /// discards the same way, so it gets the same contract.
    [Test]
    procedure ClientDataSet_HonoursTheSameContract;
    /// TRESTDataSetAdapter does NOT: its OpenDataSetChilds has an empty body,
    /// so nothing is discarded there and firing would be a false alarm. This
    /// measures that claim instead of repeating it.
    [Test]
    procedure RestAdapter_NeverFiresIt;
  end;

implementation

const
  cROOTA     = 1;
  cROOTB     = 2;
  cCHILDS    = 3;
  cGRANDS    = 2;
  cMIDBASE   = 10;
  cLEAFBASE  = 90;
  cKEYFIELD  = 'root_id';
  cINTERNAL  = 'InternalField';
  cPERSISTED = -1;
  cWALKCEIL  = 50;

type
  /// Saved BeforeScroll/AfterScroll pair, so a fixture helper can walk a
  /// dataset without TDataSetAdapter<M>.DoAfterScroll re-opening its children.
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

{ TScrollAccess<M> }

class procedure TScrollAccess<M>.Ask(const AAdapter: TDataSetBaseAdapter<M>);
begin
  TScrollAccess<M>(AAdapter).DoBeforeScrollPendingChilds;
end;

{ TTestScrollPendingChilds }

procedure TTestScrollPendingChilds.Setup;
begin
  // Zero rows on purpose: the re-query the scroll fires must hand the child
  // back EMPTY, which is the sharpest possible statement of "the typed lines
  // are gone". Nothing here opens a cursor for its content.
  FConn := TRowsConnection.Create(dnSQLite, 0,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add(cKEYFIELD, ftInteger);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName(cKEYFIELD).AsInteger := AIndex;
    end,
    'scroll');
  FRest := TInertRestConnection.Create;
  FAnswer := pcaDiscard;
  FCalls := 0;
  FSeenChilds := 0;
  FSeenSender := nil;
  FApplyBefore := 0;
  FApplyAfter := 0;
  FPersistedOnApply := 0;
end;

procedure TTestScrollPendingChilds.TearDown;
begin
  FLeaf := nil;
  FMid := nil;
  FRoot := nil;
  FreeAndNil(FLeafTable);
  FreeAndNil(FMidTable);
  FreeAndNil(FRootTable);
  FreeAndNil(FCdsMid);
  FreeAndNil(FCdsRoot);
  FreeAndNil(FMidCds);
  FreeAndNil(FRootCds);
  FreeAndNil(FRestMid);
  FreeAndNil(FRestRoot);
  FreeAndNil(FRestMidTable);
  FreeAndNil(FRestRootTable);
  FRest := nil;
  FConn := nil;
end;

/// The handler under test. It answers whatever the test told it to answer, and
/// records what the framework handed it.
procedure TTestScrollPendingChilds.Decide(const ASender: TObject;
  const APendingChilds: TArray<TDataSet>; var AAction: TPendingChildsAction);
begin
  Inc(FCalls);
  FSeenChilds := Length(APendingChilds);
  FSeenSender := ASender;
  AAction := FAnswer;
end;

/// A handler that reads nothing and writes nothing - the laziest consumer
/// there is. It must get the historical behaviour.
procedure TTestScrollPendingChilds.Ignore(const ASender: TObject;
  const APendingChilds: TArray<TDataSet>; var AAction: TPendingChildsAction);
begin
  Inc(FCalls);
end;

/// Fired by TFDMemTableAdapter<M>.ApplyUpdates BEFORE ApplyInternal. Counting
/// it is what tells pcaPost apart from pcaDiscard: nothing else the consumer
/// can see survives the re-query that follows the scroll.
procedure TTestScrollPendingChilds.MidBeforeApply(DataSet: TFDDataSet);
begin
  Inc(FApplyBefore);
end;

/// Fired by TFDMemTableAdapter<M>.ApplyUpdates AFTER ApplyInternal, so the
/// markers read here are the ones ApplyInserter left behind.
procedure TTestScrollPendingChilds.MidAfterApply(DataSet: TFDDataSet;
  AErrors: Integer);
begin
  Inc(FApplyAfter);
  FPersistedOnApply := CountWithMarker(DataSet, cPERSISTED);
end;

procedure TTestScrollPendingChilds.BuildTree(const AWithLeaf: Boolean);
begin
  FRootTable := TFDMemTable.Create(nil);
  FRoot := TContainerFDMemTable<TAitRoot>.Create(FConn, FRootTable);

  FMidTable := TFDMemTable.Create(nil);
  // Assigned BEFORE the adapter exists on purpose: TFDMemTableAdapter<M>
  // .GetDataSetEvents runs in the constructor and is what moves a consumer
  // handler into FMemTableEvents, from where DoBeforeApplyUpdates fires it.
  FMidTable.BeforeApplyUpdates := MidBeforeApply;
  FMidTable.AfterApplyUpdates := MidAfterApply;
  FMid := TContainerFDMemTable<TAitMid>.Create(FConn, FMidTable, FRoot.This);

  if AWithLeaf then
  begin
    FLeafTable := TFDMemTable.Create(nil);
    FLeaf := TContainerFDMemTable<TAitLeaf>.Create(FConn, FLeafTable, FMid.This);
  end;
end;

procedure TTestScrollPendingChilds.BuildCdsPair;
begin
  FRootCds := TClientDataSet.Create(nil);
  FCdsRoot := TClientDataSetAdapter<TAitRoot>.Create(FConn, FRootCds, -1, nil);
  FMidCds := TClientDataSet.Create(nil);
  FCdsMid := TClientDataSetAdapter<TAitMid>.Create(FConn, FMidCds, -1, FCdsRoot);
end;

procedure TTestScrollPendingChilds.BuildRestPair;
begin
  FRestRootTable := TFDMemTable.Create(nil);
  FRestRoot := TRESTFDMemTableAdapter<TAitRoot>.Create(FRest, FRestRootTable,
                 -1, nil);
  FRestMidTable := TFDMemTable.Create(nil);
  FRestMid := TRESTFDMemTableAdapter<TAitMid>.Create(FRest, FRestMidTable, -1,
                FRestRoot);
end;

/// Every root row must exist BEFORE the first child row: Append on the master
/// runs TDataSetAdapter<M>.DoNewRecord, which calls EmptyDataSetChilds.
procedure TTestScrollPendingChilds.AddRootRow(const AKey: Integer);
begin
  FRootTable.Append;
  FRootTable.FieldByName(cKEYFIELD).AsInteger := AKey;
  FRootTable.FieldByName('tag').AsString := 'R' + IntToStr(AKey);
  FRootTable.Post;
end;

/// A child row exactly as the operator leaves it: typed and posted into the
/// in-memory table, never applied. The own key is given a positive value so
/// that TDMLCommandInserter does not reach for a sequence the double has no
/// way to answer - the pendency this fixture measures is unaffected by it.
procedure TTestScrollPendingChilds.AddChildRow(const ADataSet: TDataSet;
  const AOwnKey: Integer; const ARootKey: Integer; const ATag: String);
begin
  ADataSet.Append;
  if ADataSet.FindField('mid_id') <> nil then
    ADataSet.FieldByName('mid_id').AsInteger := AOwnKey;
  if ADataSet.FindField('leaf_id') <> nil then
    ADataSet.FieldByName('leaf_id').AsInteger := AOwnKey;
  ADataSet.FieldByName(cKEYFIELD).AsInteger := ARootKey;
  if ADataSet.FindField('tag') <> nil then
    ADataSet.FieldByName('tag').AsString := ATag;
  ADataSet.Post;
end;

/// Writes back exactly what ApplyInserter writes once a row has reached the
/// database. The adapter's own BeforePost would flip the marker straight back,
/// so it is muted for this one write.
procedure TTestScrollPendingChilds.MarkRowPersisted(const ADataSet: TDataSet);
var
  LSaved: TDataSetNotifyEvent;
begin
  LSaved := ADataSet.BeforePost;
  ADataSet.BeforePost := nil;
  try
    ADataSet.Edit;
    ADataSet.FieldByName(cINTERNAL).AsInteger := cPERSISTED;
    ADataSet.Post;
  finally
    ADataSet.BeforePost := LSaved;
  end;
end;

/// Puts the master on its first row WITHOUT firing the contract - the fixture
/// is setting up, not acting.
procedure TTestScrollPendingChilds.ParkMasterOnFirst(const ADataSet: TDataSet);
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

function TTestScrollPendingChilds.RowCount(const ADataSet: TDataSet): Integer;
var
  LMute: TScrollMute;
begin
  LMute := MuteScroll(ADataSet);
  try
    Result := 0;
    ADataSet.First;
    while (not ADataSet.Eof) and (Result < cWALKCEIL) do
    begin
      Inc(Result);
      ADataSet.Next;
    end;
  finally
    UnmuteScroll(ADataSet, LMute);
  end;
end;

function TTestScrollPendingChilds.CountWithMarker(const ADataSet: TDataSet;
  const AMarker: Integer): Integer;
var
  LMute: TScrollMute;
begin
  LMute := MuteScroll(ADataSet);
  try
    Result := 0;
    ADataSet.First;
    while (not ADataSet.Eof) and (Result <= cWALKCEIL) do
    begin
      if ADataSet.FieldByName(cINTERNAL).AsInteger = AMarker then
        Inc(Result);
      ADataSet.Next;
    end;
  finally
    UnmuteScroll(ADataSet, LMute);
  end;
end;

function TTestScrollPendingChilds.MasterKey(const ADataSet: TDataSet): Integer;
begin
  Result := ADataSet.FieldByName(cKEYFIELD).AsInteger;
end;

// ---------------------------------------------------------------------------
// The premise, and what "pending" really is
// ---------------------------------------------------------------------------

procedure TTestScrollPendingChilds.Premise_ScrollingTheMasterDiscardsTypedChildRows;
var
  LFor: Integer;
begin
  BuildTree;
  AddRootRow(cROOTA);
  AddRootRow(cROOTB);
  ParkMasterOnFirst(FRootTable);
  for LFor := 0 to cCHILDS - 1 do
    AddChildRow(FMidTable, cMIDBASE + LFor, cROOTA, 'M' + IntToStr(LFor));

  Assert.AreEqual(cCHILDS, RowCount(FMidTable),
    'the operator must really have three lines on screen - if this is already ' +
    '0 the fixture is broken, not the framework');

  // One keypress on the master grid.
  FRootTable.Next;

  Assert.AreEqual(cROOTB, MasterKey(FRootTable),
    'the master must really have moved, otherwise nothing was measured');
  Assert.AreEqual(0, RowCount(FMidTable),
    'the three typed lines are gone: DoAfterScroll re-opened the child from ' +
    'the database and EmptyDataSet took everything that was not saved');
end;

procedure TTestScrollPendingChilds.Marker_APostedButUnsavedRowCarriesTheInsertMarker;
begin
  BuildTree;
  AddRootRow(cROOTA);
  ParkMasterOnFirst(FRootTable);
  AddChildRow(FMidTable, cMIDBASE, cROOTA, 'M0');

  Assert.IsTrue(FMidTable.State = dsBrowse,
    'a posted row leaves the dataset in dsBrowse - State alone cannot see it');
  Assert.AreEqual(Integer(dsInsert),
    FMidTable.FieldByName(cINTERNAL).AsInteger,
    'DoBeforePost stamps Integer(dsInsert) on a row that has not been applied');
  Assert.AreEqual(1, CountWithMarker(FMidTable, Integer(dsInsert)),
    'exactly one pending row was typed');
  Assert.IsFalse(FMidTable.Modified,
    'and Modified is already False - Post clears it - so the third candidate ' +
    'marker is blind to a row that is posted but unsaved');
end;

procedure TTestScrollPendingChilds.Marker_ARowBeingTypedIsInvisibleToTheInternalColumn;
begin
  BuildTree;
  AddRootRow(cROOTA);
  AddRootRow(cROOTB);
  ParkMasterOnFirst(FRootTable);
  // The line under the cursor: appended, being filled in, NOT posted.
  FMidTable.Append;
  FMidTable.FieldByName(cKEYFIELD).AsInteger := cROOTA;

  Assert.IsTrue(FMidTable.State = dsInsert, 'the row is still being typed');
  Assert.AreEqual(cPERSISTED, FMidTable.FieldByName(cINTERNAL).AsInteger,
    'DoBeforePost has not run, so the internal column still holds the -1 that ' +
    'Bind.SetDataDictionary set as DefaultExpression - a detector that read ' +
    'only this column would call the row clean');

  FAnswer := pcaDiscard;
  FRoot.This.OnBeforeScrollPendingChilds := Decide;
  FRootTable.Next;

  Assert.AreEqual(1, FCalls,
    'State is the second marker and the detector must use it: the row the ' +
    'operator has under the cursor is exactly the one at risk');
end;

procedure TTestScrollPendingChilds.Marker_APersistedRowDoesNotTriggerTheHandler;
begin
  BuildTree;
  AddRootRow(cROOTA);
  AddRootRow(cROOTB);
  ParkMasterOnFirst(FRootTable);
  AddChildRow(FMidTable, cMIDBASE, cROOTA, 'M0');
  MarkRowPersisted(FMidTable);
  Assert.AreEqual(1, CountWithMarker(FMidTable, cPERSISTED),
    'the fixture must really be able to mark a row as saved');

  FRoot.This.OnBeforeScrollPendingChilds := Decide;
  FRootTable.Next;

  Assert.AreEqual(0, FCalls,
    'a row that is already in the database is not at risk; asking the ' +
    'consumer about it would be noise');
end;

procedure TTestScrollPendingChilds.Marker_ChangeCountIsBlindToPendingRows;
var
  LFor: Integer;
begin
  BuildTree;
  AddRootRow(cROOTA);
  ParkMasterOnFirst(FRootTable);
  for LFor := 0 to cCHILDS - 1 do
    AddChildRow(FMidTable, cMIDBASE + LFor, cROOTA, 'M' + IntToStr(LFor));

  Assert.IsFalse(FMidTable.CachedUpdates,
    'TFDMemTableAdapter<M>.Create turns cached updates off');
  Assert.IsFalse(FMidTable.LogChanges,
    'and the change log with it');
  Assert.AreEqual(0, FMidTable.ChangeCount,
    'so FireDAC counts ZERO changes while three typed rows sit in the table - ' +
    'ChangeCount cannot be the marker, and this is measured, not assumed');
  Assert.AreEqual(cCHILDS, CountWithMarker(FMidTable, Integer(dsInsert)),
    'the internal column, on the same three rows, sees all of them');
end;

// ---------------------------------------------------------------------------
// The default
// ---------------------------------------------------------------------------

procedure TTestScrollPendingChilds.Choice_Discard_ReproducesTheNoHandlerEndState;
var
  LFor: Integer;
begin
  BuildTree;
  AddRootRow(cROOTA);
  AddRootRow(cROOTB);
  ParkMasterOnFirst(FRootTable);
  for LFor := 0 to cCHILDS - 1 do
    AddChildRow(FMidTable, cMIDBASE + LFor, cROOTA, 'M' + IntToStr(LFor));

  FAnswer := pcaDiscard;
  FRoot.This.OnBeforeScrollPendingChilds := Decide;

  FRootTable.Next;

  Assert.AreEqual(1, FCalls, 'the consumer was asked');
  Assert.AreEqual(cROOTB, MasterKey(FRootTable),
    'answering discard does not stop the master');
  Assert.AreEqual(0, RowCount(FMidTable),
    'and the rows go exactly where they always went - this is the same end ' +
    'state as Premise_ScrollingTheMasterDiscardsTypedChildRows, which runs ' +
    'with no handler at all');
  Assert.AreEqual(0, FApplyBefore,
    'discard must not save anything behind the consumer back');
end;

procedure TTestScrollPendingChilds.Default_AHandlerThatIgnoresTheParameterStillDiscards;
var
  LFor: Integer;
begin
  BuildTree;
  AddRootRow(cROOTA);
  AddRootRow(cROOTB);
  ParkMasterOnFirst(FRootTable);
  for LFor := 0 to cCHILDS - 1 do
    AddChildRow(FMidTable, cMIDBASE + LFor, cROOTA, 'M' + IntToStr(LFor));

  // Ignore reads nothing and writes nothing - it never touches AAction.
  FRoot.This.OnBeforeScrollPendingChilds := Ignore;

  FRootTable.Next;

  Assert.AreEqual(1, FCalls, 'the handler really ran');
  Assert.AreEqual(cROOTB, MasterKey(FRootTable),
    'AAction arrives pre-seeded with pcaDiscard, so a handler that leaves it ' +
    'alone gets the historical behaviour and cannot fall into pcaPost or ' +
    'pcaCancel by accident');
  Assert.AreEqual(0, RowCount(FMidTable), 'and the rows are discarded');
end;

procedure TTestScrollPendingChilds.NoPendingChilds_TheHandlerIsNeverCalled;
begin
  BuildTree;
  AddRootRow(cROOTA);
  AddRootRow(cROOTB);
  ParkMasterOnFirst(FRootTable);
  // No child rows at all: the degenerate case, and the common one.

  FRoot.This.OnBeforeScrollPendingChilds := Decide;
  FRootTable.Next;

  Assert.AreEqual(0, FCalls,
    'with nothing to lose there is nothing to decide - the contract must not ' +
    'turn every scroll of every screen into a question');
  Assert.AreEqual(cROOTB, MasterKey(FRootTable), 'and the master still moves');
end;

// ---------------------------------------------------------------------------
// The other two choices
// ---------------------------------------------------------------------------

procedure TTestScrollPendingChilds.Choice_Cancel_TheMasterStaysAndTheRowsSurvive;
var
  LFor: Integer;
begin
  BuildTree;
  AddRootRow(cROOTA);
  AddRootRow(cROOTB);
  ParkMasterOnFirst(FRootTable);
  for LFor := 0 to cCHILDS - 1 do
    AddChildRow(FMidTable, cMIDBASE + LFor, cROOTA, 'M' + IntToStr(LFor));

  FAnswer := pcaCancel;
  FRoot.This.OnBeforeScrollPendingChilds := Decide;

  Assert.WillRaise(
    procedure
    begin
      FRootTable.Next;
    end,
    EAbort,
    'cancelling a scroll is EAbort: it unwinds MoveBy before the cursor moves ' +
    'and a VCL application swallows it without a dialog');

  Assert.AreEqual(1, FCalls, 'the consumer was asked exactly once');
  Assert.AreEqual(cROOTA, MasterKey(FRootTable),
    'the master never left order #1');
  Assert.AreEqual(cCHILDS, RowCount(FMidTable),
    'and every typed line is still on screen');
  Assert.AreEqual(cCHILDS, CountWithMarker(FMidTable, Integer(dsInsert)),
    'still pending, still unsaved - cancel protects the rows, it does not ' +
    'quietly save them');
end;

procedure TTestScrollPendingChilds.Choice_Post_ThePendingRowsAreSavedBeforeTheMasterMoves;
var
  LFor: Integer;
begin
  BuildTree;
  AddRootRow(cROOTA);
  AddRootRow(cROOTB);
  ParkMasterOnFirst(FRootTable);
  for LFor := 0 to cCHILDS - 1 do
    AddChildRow(FMidTable, cMIDBASE + LFor, cROOTA, 'M' + IntToStr(LFor));

  FAnswer := pcaPost;
  FRoot.This.OnBeforeScrollPendingChilds := Decide;

  FRootTable.Next;

  Assert.AreEqual(1, FCalls, 'the consumer was asked');
  Assert.AreEqual(1, FApplyBefore,
    'the child adapter own ApplyUpdates ran, and it ran on the CHILD - these ' +
    'counters are fed by TFDMemTableAdapter<M>.DoBeforeApplyUpdates, not by ' +
    'the fixture');
  Assert.AreEqual(1, FApplyAfter, 'and it finished');
  Assert.AreEqual(cCHILDS, FPersistedOnApply,
    'by the time ApplyUpdates returned, ApplyInserter had walked ALL THREE ' +
    'rows and flipped each marker to -1. What is measured is that the shipped ' +
    'insert path processed every pending row, not that a server acknowledged ' +
    'them: the connection here is a double whose ExecuteDirect is inert. That ' +
    'boundary is the doubles, not this contract');
  Assert.AreEqual(cROOTB, MasterKey(FRootTable),
    'and the master moved on, which is the whole point of choosing post over ' +
    'cancel');
end;

// ---------------------------------------------------------------------------
// The cost of asking
// ---------------------------------------------------------------------------

procedure TTestScrollPendingChilds.Detecting_DoesNotDestroyTheGrandchildren;
var
  LFor: Integer;
begin
  BuildTree(True);
  AddRootRow(cROOTA);
  AddRootRow(cROOTB);
  ParkMasterOnFirst(FRootTable);
  for LFor := 0 to cCHILDS - 1 do
    AddChildRow(FMidTable, cMIDBASE + LFor, cROOTA, 'M' + IntToStr(LFor));
  for LFor := 0 to cGRANDS - 1 do
    AddChildRow(FLeafTable, cLEAFBASE + LFor, cROOTA, 'L' + IntToStr(LFor));
  Assert.AreEqual(cGRANDS, RowCount(FLeafTable),
    'the grandchildren must really be there before the question is asked');

  FAnswer := pcaDiscard;
  FRoot.This.OnBeforeScrollPendingChilds := Decide;

  // Asks the question WITHOUT the scroll that follows it in production: what
  // is being measured is the price of the detection walk alone.
  TScrollAccess<TAitRoot>.Ask(FRoot.This);

  Assert.AreEqual(1, FCalls, 'the walk did find the pending child');
  Assert.AreEqual(cGRANDS, RowCount(FLeafTable),
    'and it did not cost the grandchildren: advancing the child with its ' +
    'events live fires ITS AfterScroll, which re-reads the leaf from the ' +
    'database - the detector mutes them, the same way SetAutoIncValueChilds ' +
    'has to');
  Assert.AreEqual(cCHILDS, RowCount(FMidTable),
    'nor the children themselves');
end;

procedure TTestScrollPendingChilds.Handler_ReceivesThePendingChildAndTheSender;
var
  LFor: Integer;
begin
  BuildTree(True);
  AddRootRow(cROOTA);
  AddRootRow(cROOTB);
  ParkMasterOnFirst(FRootTable);
  for LFor := 0 to cCHILDS - 1 do
    AddChildRow(FMidTable, cMIDBASE + LFor, cROOTA, 'M' + IntToStr(LFor));
  // The leaf hangs off the MID adapter, not off the root, so the root has
  // exactly one child at risk even though the tree has three levels.

  FAnswer := pcaDiscard;
  FRoot.This.OnBeforeScrollPendingChilds := Decide;
  TScrollAccess<TAitRoot>.Ask(FRoot.This);

  Assert.AreEqual(1, FCalls, 'asked once');
  Assert.AreEqual(1, FSeenChilds,
    'the handler is handed the child datasets that are actually at risk, not ' +
    'every child the master has');
  Assert.AreSame(TObject(FRoot.This), FSeenSender,
    'and the adapter that is about to scroll, so one handler can serve many');
end;

// ---------------------------------------------------------------------------
// The other families
// ---------------------------------------------------------------------------

procedure TTestScrollPendingChilds.ClientDataSet_HonoursTheSameContract;
var
  LFor: Integer;
begin
  BuildCdsPair;
  FRootCds.Append;
  FRootCds.FieldByName(cKEYFIELD).AsInteger := cROOTA;
  FRootCds.Post;
  FRootCds.Append;
  FRootCds.FieldByName(cKEYFIELD).AsInteger := cROOTB;
  FRootCds.Post;
  ParkMasterOnFirst(FRootCds);
  for LFor := 0 to cCHILDS - 1 do
    AddChildRow(FMidCds, cMIDBASE + LFor, cROOTA, 'M' + IntToStr(LFor));
  Assert.AreEqual(cCHILDS, RowCount(FMidCds),
    'the ClientDataSet child must really hold the typed rows');

  FAnswer := pcaCancel;
  FCdsRoot.OnBeforeScrollPendingChilds := Decide;

  Assert.WillRaise(
    procedure
    begin
      FRootCds.Next;
    end,
    EAbort,
    'TClientDataSetAdapter descends from TDataSetAdapter<M> and therefore ' +
    'inherits the same DoBeforeScroll');

  Assert.AreEqual(1, FCalls, 'the consumer was asked here too');
  Assert.AreEqual(cROOTA, MasterKey(FRootCds), 'the master stayed');
  Assert.AreEqual(cCHILDS, RowCount(FMidCds), 'and the rows survived');
end;

procedure TTestScrollPendingChilds.RestAdapter_NeverFiresIt;
var
  LFor: Integer;
begin
  BuildRestPair;
  FRestRootTable.Append;
  FRestRootTable.FieldByName(cKEYFIELD).AsInteger := cROOTA;
  FRestRootTable.FieldByName('tag').AsString := 'RA';
  FRestRootTable.Post;
  FRestRootTable.Append;
  FRestRootTable.FieldByName(cKEYFIELD).AsInteger := cROOTB;
  FRestRootTable.FieldByName('tag').AsString := 'RB';
  FRestRootTable.Post;
  ParkMasterOnFirst(FRestRootTable);
  for LFor := 0 to cCHILDS - 1 do
    AddChildRow(FRestMidTable, cMIDBASE + LFor, cROOTA, 'M' + IntToStr(LFor));
  Assert.AreEqual(cCHILDS, RowCount(FRestMidTable),
    'the REST child must really hold the typed rows, otherwise the silence ' +
    'below proves nothing');

  FAnswer := pcaCancel;
  FRestRoot.OnBeforeScrollPendingChilds := Decide;

  FRestRootTable.Next;

  Assert.AreEqual(0, FCalls,
    'TRESTDataSetAdapter<M>.OpenDataSetChilds has an EMPTY BODY, so scrolling ' +
    'the master there discards nothing and there is no loss to decide about; ' +
    'firing the contract would be a false alarm');
  Assert.AreEqual(cROOTB, MasterKey(FRestRootTable),
    'the master moved - pcaCancel was never read');
  Assert.AreEqual(cCHILDS, RowCount(FRestMidTable),
    'and the rows are still there, which is why nobody had to be asked');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestScrollPendingChilds);

end.
