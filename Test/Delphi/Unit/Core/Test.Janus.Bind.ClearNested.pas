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

{ @abstract(Janus Framework - clearing a nested dataset before rewriting it.)

  WHAT IS UNDER TEST

  TBind.SetPropertyToField - the writer that pushes an object into a dataset
  row. For a [Column(..., ftDataSet)] mapped over a list property it takes the
  TDataSetField's NestedDataSet, CLEARS it, and appends one row per object in
  the list. The clearing is the part measured here.

  THE DEFECT THIS SUITE PINS

  The clearing loop was `while not LDataSet.Eof do LDataSet.Delete` with no
  First before it, so the loop starts wherever the previous caller left the
  cursor. When that place is Eof the loop body never runs: nothing is cleared,
  the list is appended ON TOP of the rows already there, and the nested dataset
  ends up holding the stale rows plus the new ones. Nothing raises - the caller
  is told the write succeeded.

  This is the SILENT family. Because the loop is a `while` and not a `repeat`,
  it does not fail on an empty dataset the way the one in
  TDataSetAdapter<M>.DoBeforeDelete did (issue #212). It just clears nothing.

  WHAT THE DAMAGE IS NOT

  The reported diagnosis was that the rows BEHIND the cursor survive. Measured
  on the shipped RTL, they do not.
  Premise_TheLoopEmptiesFromAnyRowButStallsAtEof drives exactly the shipped
  loop over five rows starting on row 3 and records RecNo and RecordCount at
  every iteration. TClientDataSet and TFDMemTable answer identically:

      [rec=3 n=5][rec=3 n=4][rec=3 n=3][rec=2 n=2][rec=1 n=1] -> n=0

  Delete makes the FOLLOWING row current while one exists, and when the deleted
  row was the last it falls back onto the new last row with Eof still False. So
  the loop walks forward, turns round at the end, and empties the dataset from
  ANY position that is not already Eof. Eof on entry is the one state that
  loses data - and there it loses all of it, not part of it.

  WHY IT SURVIVED

  With the cursor anywhere inside the rows the buggy loop and the fixed loop
  leave the same (empty) dataset, so any test that writes rows and immediately
  rewrites them passes either way. The two Cursor_ tests below that are marked
  CONTROL are exactly those tests: green with and without the First. The one
  marked LOAD-BEARING is the only one the First moves.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Bind.ClearNested;

interface

uses
  DB,
  Classes,
  SysUtils,
  Variants,
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
  DataEngine.FactoryInterfaces,
  Janus.Bind,
  Janus.DataSet.ClientDataSet,
  Test.Janus.Model.Nested,
  Test.Janus.Cursor.Double;

type
  [TestFixture]
  TTestBindClearNested = class
  private
    FConn: IDBConnection;
    FCds: TClientDataSet;
    FAdapter: TClientDataSetAdapter<TNestedParent>;
    FParent: TNestedParent;
    procedure BuildAdapter;
    procedure AddOwnerRow;
    procedure AddNestedRows(const ACount: Integer);
    function Nested: TDataSet;
    /// Moves the nested cursor to the 0-based row AIndex. AIndex = row count
    /// parks it past the last row, which is the Eof case.
    procedure PositionNested(const AIndex: Integer);
    /// Builds the object the writer is asked to push, with ACount children
    /// tagged 'new1'..'newN'.
    function BuildParent(const ACount: Integer): TNestedParent;
    /// Runs the method under test over the object built by BuildParent.
    procedure WriteParent;
    /// The `ctag` of every row currently in the nested dataset, in order,
    /// joined by '|'. Restores the cursor it found.
    function NestedTags: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// The premise everything below rests on: the ftDataSet column really
    /// registers a nested dataset, it really holds the rows written into it,
    /// and its cursor really can be parked past the last row. Without this the
    /// measurements below would be measuring an empty dataset.
    [Test]
    procedure Premise_TheNestedDataSetHoldsItsRowsAndTheCursorMoves;

    /// The RTL behaviour behind the defect, measured on both dataset families
    /// the framework ships adapters for instead of quoted from a manual: the
    /// shipped loop empties the dataset from any row, and does nothing at all
    /// from Eof.
    [Test]
    procedure Premise_TheLoopEmptiesFromAnyRowButStallsAtEof;

    /// CONTROL. Cursor on the first row - buggy loop and fixed loop delete the
    /// same rows. Green either way; it documents how the defect stayed
    /// invisible, it does not protect the fix.
    [Test]
    procedure Cursor_OnFirstRow_NestedHoldsOnlyTheListRows;

    /// CONTROL. Cursor on row 3 of 5. Also green either way, and it is here to
    /// say so: this is the case the issue predicted would lose rows 1 and 2,
    /// and measured against the shipped RTL it loses nothing.
    [Test]
    procedure Cursor_InTheMiddle_NestedHoldsOnlyTheListRows;

    /// LOAD-BEARING. Cursor parked past the last row: the loop is Eof on entry,
    /// clears nothing, and the list is appended on top of all five stale rows.
    [Test]
    procedure Cursor_AtEof_NestedHoldsOnlyTheListRows;

    /// The degenerate end of the same axis: an EMPTY nested dataset is at Eof
    /// too. Adding the First must not turn that harmless case into a raise.
    [Test]
    procedure NestedEmpty_NestedHoldsOnlyTheListRows;
  end;

implementation

const
  cOWNERKEY   = 'pkey';
  cOWNERTAG   = 'ptag';
  cNESTED     = 'items';
  cNESTEDKEY  = 'citem';
  cNESTEDTAG  = 'ctag';
  cSTALEROWS  = 5;
  cNEWROWS    = 2;
  cNEWTAGS    = 'new1|new2';
  /// RecNo and RecordCount at every iteration of the shipped loop, started on
  /// row 3 of 5. Measured, not predicted - see the unit header.
  cWALK       = '[rec=3 n=5][rec=3 n=4][rec=3 n=3][rec=2 n=2][rec=1 n=1]end n=0;';

{ TTestBindClearNested }

procedure TTestBindClearNested.Setup;
begin
  // The connection only exists so the adapter can build its session; no test
  // here opens a cursor, so zero rows keeps the double inert.
  FConn := TRowsConnection.Create(dnSQLite, 0,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add(cOWNERKEY, ftInteger);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName(cOWNERKEY).AsInteger := AIndex;
    end,
    'bindnested');
end;

procedure TTestBindClearNested.TearDown;
begin
  // Detach the ORM handlers before the dataset closes: an adapter event firing
  // over freed memory is a crash, not a test result.
  if FCds <> nil then
  begin
    FCds.BeforeScroll := nil;
    FCds.AfterScroll := nil;
    FCds.BeforeClose := nil;
    FCds.BeforeOpen := nil;
    FCds.AfterOpen := nil;
    FCds.AfterClose := nil;
    FCds.BeforeDelete := nil;
    FCds.AfterDelete := nil;
    FCds.BeforeInsert := nil;
    FCds.AfterInsert := nil;
    FCds.BeforeEdit := nil;
    FCds.AfterEdit := nil;
    FCds.BeforePost := nil;
    FCds.AfterPost := nil;
    FCds.OnNewRecord := nil;
  end;
  FreeAndNil(FParent);
  FreeAndNil(FCds);
  FreeAndNil(FAdapter);
  FConn := nil;
end;

/// The adapter's constructor builds the field defs from the mapping and calls
/// CreateDataSet, so the nested dataset comes from the SHIPPED path
/// (TBind.SetInternalInitFieldDefsObjectClass -> _CreateFieldsNestedDataSet).
procedure TTestBindClearNested.BuildAdapter;
begin
  FCds := TClientDataSet.Create(nil);
  FAdapter := TClientDataSetAdapter<TNestedParent>.Create(FConn, FCds, -1, nil);
end;

procedure TTestBindClearNested.AddOwnerRow;
begin
  FCds.Append;
  FCds.FieldByName(cOWNERKEY).AsInteger := 1;
  FCds.FieldByName(cOWNERTAG).AsString := 'owner';
  FCds.Post;
end;

procedure TTestBindClearNested.AddNestedRows(const ACount: Integer);
var
  LNested: TDataSet;
  LFor: Integer;
begin
  LNested := Nested;
  for LFor := 1 to ACount do
  begin
    LNested.Append;
    LNested.FieldByName(cNESTEDKEY).AsInteger := LFor;
    LNested.FieldByName(cNESTEDTAG).AsString := 'old' + IntToStr(LFor);
    LNested.Post;
  end;
  // Writing into a nested dataset puts its owner into dsEdit
  // (TDataSet.CheckParentState). Leave the owner in dsBrowse so every test
  // starts from the same state.
  if FCds.State in [dsEdit, dsInsert] then
    FCds.Post;
end;

function TTestBindClearNested.Nested: TDataSet;
begin
  Result := (FCds.FieldByName(cNESTED) as TDataSetField).NestedDataSet;
end;

procedure TTestBindClearNested.PositionNested(const AIndex: Integer);
var
  LNested: TDataSet;
  LFor: Integer;
begin
  LNested := Nested;
  LNested.First;
  for LFor := 1 to AIndex do
    LNested.Next;
end;

function TTestBindClearNested.BuildParent(const ACount: Integer): TNestedParent;
var
  LChild: TNestedChild;
  LFor: Integer;
begin
  Result := TNestedParent.Create;
  Result.pkey := 1;
  Result.ptag := 'owner';
  for LFor := 1 to ACount do
  begin
    LChild := TNestedChild.Create;
    LChild.citem := 100 + LFor;
    LChild.ctag := 'new' + IntToStr(LFor);
    Result.items.Add(LChild);
  end;
end;

procedure TTestBindClearNested.WriteParent;
begin
  // SetPropertyToField writes scalar fields too, so the owner row has to be
  // open for edit exactly as it is on the production route.
  FCds.Edit;
  TBind.Instance.SetPropertyToField(FParent, FCds);
end;

function TTestBindClearNested.NestedTags: string;
var
  LNested: TDataSet;
  LMark: TBookmark;
begin
  Result := '';
  LNested := Nested;
  LNested.DisableControls;
  LMark := LNested.GetBookmark;
  try
    LNested.First;
    while not LNested.Eof do
    begin
      if Result <> '' then
        Result := Result + '|';
      Result := Result + LNested.FieldByName(cNESTEDTAG).AsString;
      LNested.Next;
    end;
  finally
    if LNested.BookmarkValid(LMark) then
      LNested.GotoBookmark(LMark);
    LNested.FreeBookmark(LMark);
    LNested.EnableControls;
  end;
end;

procedure TTestBindClearNested.Premise_TheNestedDataSetHoldsItsRowsAndTheCursorMoves;
var
  LNested: TDataSet;
begin
  BuildAdapter;
  AddOwnerRow;
  AddNestedRows(cSTALEROWS);
  LNested := Nested;
  Assert.IsTrue(LNested.Active,
    'the nested dataset must be open, otherwise every measurement below is ' +
    'measuring a closed cursor and not the clearing loop');
  Assert.AreEqual(cSTALEROWS, LNested.RecordCount,
    'the nested dataset must really carry the rows this fixture wrote');
  Assert.AreEqual('old1|old2|old3|old4|old5', NestedTags,
    'and carry them in the order they were written');
  PositionNested(2);
  Assert.AreEqual(3, LNested.RecNo,
    'the cursor must be movable off the first row');
  PositionNested(cSTALEROWS);
  Assert.IsTrue(LNested.Eof,
    'and it must be parkable past the last row while the rows are still ' +
    'there - that is the one state the defect lives in, so if this were ' +
    'unreachable the fixture would be decorative');
  Assert.AreEqual(cSTALEROWS, LNested.RecordCount,
    'Eof with rows present, not Eof because the dataset emptied itself');
end;

procedure TTestBindClearNested.Premise_TheLoopEmptiesFromAnyRowButStallsAtEof;
var
  LPlain: TClientDataSet;
  LMem: TFDMemTable;
  LFor: Integer;
  LWalk: string;
begin
  LPlain := TClientDataSet.Create(nil);
  LMem := TFDMemTable.Create(nil);
  try
    LPlain.FieldDefs.Add(cNESTEDKEY, ftInteger);
    LPlain.CreateDataSet;
    LMem.FieldDefs.Add(cNESTEDKEY, ftInteger);
    LMem.CreateDataSet;
    for LFor := 1 to cSTALEROWS do
    begin
      LPlain.Append;
      LPlain.FieldByName(cNESTEDKEY).AsInteger := LFor;
      LPlain.Post;
      LMem.Append;
      LMem.FieldByName(cNESTEDKEY).AsInteger := LFor;
      LMem.Post;
    end;

    // (a) started INSIDE the rows: the shipped loop empties everything.
    LPlain.First;
    LPlain.Next;
    LPlain.Next;
    Assert.AreEqual(3, LPlain.RecNo, 'premise: parked on the third row');
    LWalk := '';
    while not LPlain.Eof do
    begin
      LWalk := LWalk + Format('[rec=%d n=%d]',
                              [LPlain.RecNo, LPlain.RecordCount]);
      LPlain.Delete;
    end;
    LWalk := LWalk + Format('end n=%d;', [LPlain.RecordCount]);
    Assert.AreEqual(cWALK, LWalk,
      'Delete makes the FOLLOWING row current, and on the last row falls back ' +
      'onto the new last with Eof still False - so the loop turns round and ' +
      'empties the dataset. The rows behind the cursor do NOT survive');

    // ...and the other dataset family the framework ships adapters for
    // answers exactly the same, so the fix is not TClientDataSet-specific.
    LMem.First;
    LMem.Next;
    LMem.Next;
    LWalk := '';
    while not LMem.Eof do
    begin
      LWalk := LWalk + Format('[rec=%d n=%d]', [LMem.RecNo, LMem.RecordCount]);
      LMem.Delete;
    end;
    LWalk := LWalk + Format('end n=%d;', [LMem.RecordCount]);
    Assert.AreEqual(cWALK, LWalk,
      'TFDMemTable must answer identically - the REST adapter family clears ' +
      'FDMemTables with the same loop');

    // (b) started AT Eof: the loop body never runs.
    for LFor := 1 to cSTALEROWS do
    begin
      LPlain.Append;
      LPlain.FieldByName(cNESTEDKEY).AsInteger := LFor;
      LPlain.Post;
    end;
    LPlain.Last;
    LPlain.Next;
    Assert.IsTrue(LPlain.Eof, 'premise: parked past the last row');
    while not LPlain.Eof do
      LPlain.Delete;
    Assert.AreEqual(cSTALEROWS, LPlain.RecordCount,
      'nothing at all was deleted - this, and only this, is what the missing ' +
      'First costs');

    // (c) the OTHER way the framework clears a dataset, measured on the same
    // Eof state so the sweep that classified the clearing sites is not
    // classifying it by reading alone: the EmptyDataSet route that
    // TClientDataSetAdapter<M>.EmptyDataSetChilds and its REST twins use takes
    // no cursor and empties from Eof just the same.
    Assert.IsTrue(LPlain.Eof, 'premise: still parked past the last row');
    LPlain.EmptyDataSet;
    Assert.AreEqual(0, LPlain.RecordCount,
      'EmptyDataSet is cursor-independent, so the EmptyDataSetChilds family ' +
      'never needed a First and is not a site of this defect');
  finally
    LMem.Free;
    LPlain.Free;
  end;
end;

procedure TTestBindClearNested.Cursor_OnFirstRow_NestedHoldsOnlyTheListRows;
begin
  BuildAdapter;
  AddOwnerRow;
  AddNestedRows(cSTALEROWS);
  PositionNested(0);
  Assert.AreEqual(1, Nested.RecNo, 'premise: the cursor is on the first row');
  FParent := BuildParent(cNEWROWS);
  WriteParent;
  Assert.AreEqual(cNEWROWS, Nested.RecordCount,
    'the nested dataset must hold exactly the rows of the list');
  Assert.AreEqual(cNEWTAGS, NestedTags, 'and hold nothing but them');
end;

procedure TTestBindClearNested.Cursor_InTheMiddle_NestedHoldsOnlyTheListRows;
begin
  BuildAdapter;
  AddOwnerRow;
  AddNestedRows(cSTALEROWS);
  PositionNested(2);
  Assert.AreEqual(3, Nested.RecNo,
    'premise: the cursor is on row 3, so rows 1 and 2 are behind it');
  FParent := BuildParent(cNEWROWS);
  WriteParent;
  Assert.AreEqual(cNEWROWS, Nested.RecordCount,
    'the nested dataset must hold exactly the rows of the list');
  Assert.AreEqual(cNEWTAGS, NestedTags, 'and hold nothing but them');
end;

procedure TTestBindClearNested.Cursor_AtEof_NestedHoldsOnlyTheListRows;
begin
  BuildAdapter;
  AddOwnerRow;
  AddNestedRows(cSTALEROWS);
  PositionNested(cSTALEROWS);
  Assert.IsTrue(Nested.Eof, 'premise: the cursor is parked past the last row');
  Assert.AreEqual(cSTALEROWS, Nested.RecordCount,
    'premise: and the stale rows are still there');
  FParent := BuildParent(cNEWROWS);
  WriteParent;
  Assert.AreEqual(cNEWROWS, Nested.RecordCount,
    'the nested dataset must hold exactly the rows of the list - without the ' +
    'First the loop is Eof on entry, deletes nothing, and leaves 7 rows');
  Assert.AreEqual(cNEWTAGS, NestedTags,
    'and hold nothing but them - without the First it reads ' +
    'old1|old2|old3|old4|old5|new1|new2');
end;

procedure TTestBindClearNested.NestedEmpty_NestedHoldsOnlyTheListRows;
begin
  BuildAdapter;
  AddOwnerRow;
  Assert.IsTrue(Nested.IsEmpty, 'premise: no child row was written');
  Assert.IsTrue(Nested.Eof,
    'premise: and an empty dataset is at Eof, the same entry state as the ' +
    'test above - so the First runs here too and must stay harmless');
  FParent := BuildParent(cNEWROWS);
  WriteParent;
  Assert.AreEqual(cNEWROWS, Nested.RecordCount,
    'the list must have been written');
  Assert.AreEqual(cNEWTAGS, NestedTags, 'and nothing else');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestBindClearNested);

end.
