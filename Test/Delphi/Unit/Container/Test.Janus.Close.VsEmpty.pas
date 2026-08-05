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

{ @abstract(Janus Framework - what CLOSING really costs, measured against what
  EMPTYING costs.)

  WHAT IS UNDER TEST

  TContainerDataSet<M>.Close and the protected TDataSetBaseAdapter<M>.Close.
  This fixture runs the same scenarios through each of them and records the
  difference.

  WHAT THIS FIXTURE MEASURED FIRST, AND WHY IT NOW MEASURES SOMETHING ELSE

  It was written for #246, when TContainerDataSet<M>.Close called
  FDataSetAdapter.EmptyDataSet and closed nothing, and the protected Close was
  the only real one. The question it answered was what a genuine close cost, and
  the answer was: nothing except the way back. Every Open path began with an
  EmptyDataSet that goes through CheckBrowseMode, so a closed dataset could not
  be filled again.

  #248 acted on that. TDataSetBaseAdapter<M>.EnsureOpen now reopens ahead of
  each of those EmptyDataSet calls, and the container Close was changed to call
  the adapter Close. The two legs of this fixture therefore CONVERGE now, and
  the tests that used to record the divergence were rewritten to record the
  convergence - by name, not only by assertion, so a stale name cannot claim the
  old world. What each one used to measure is written in its own comment, and
  the cursor accounting that justified the change lives in
  Test.Janus.Reopen.Lazy.

  THIS FIXTURE MEASURES. IT DOES NOT ARGUE.

  Two explanations for the pre-#248 behaviour had been offered before anything
  was measured, and the first one was false: it claimed that closing would
  destroy the TField objects the adapter creates at runtime. It does not - see
  Fields_SurviveARealClose. The second explanation - that a repeated FindWhere,
  or a bound control, would meet a CLOSED dataset and fail - is what
  FindWhere_* and BoundControl_* below put on the scale. Both answers survived
  #248 unchanged; only the state the container Close leaves behind moved.

  NOTHING HERE CHANGES BEHAVIOUR. Every test drives the shipped code exactly as
  it ships; the "real close" leg reaches the protected TDataSetBaseAdapter<M>
  .Close through a same-unit descendant, which is the very method the framework
  itself calls from DoBeforeClose and from TDataSetAdapter<M>.LoadLazy.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Close.VsEmpty;

interface

uses
  DB,
  Classes,
  SysUtils,
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
  Janus.Container.DataSet.Interfaces,
  Janus.Container.FDMemTable,
  Janus.DML.Generator.SQLite,
  Test.Janus.Model.KeyOnly,
  Test.Janus.Model.AutoIncTree,
  Test.Janus.Cursor.Double;

type
  /// <summary> Same-unit descendant, the classic way to reach a protected
  ///  method. TDataSetBaseAdapter<M>.Close is NOT exposed by
  ///  IContainerDataSet<M> - the interface's Close is the container's, which
  ///  empties. This is the only way a test can ask "and if it really closed?"
  ///  without touching Source\. </summary>
  TCloseAccess<M: class, constructor> = class(TDataSetBaseAdapter<M>)
  public
    class procedure RealClose(const AAdapter: TDataSetBaseAdapter<M>);
  end;

  /// <summary> A stand-in for a data-aware control. A TDBGrid is a TDataLink
  ///  plus painting; what it does to the dataset is what a TDataLink does -
  ///  it is notified, and it reads fields. This probe reads UNCONDITIONALLY,
  ///  the way a control that assumed the dataset was open would, and records
  ///  whether the read raised. </summary>
  TProbeLink = class(TDataLink)
  private
    FFieldName: string;
    FActiveChangedCount: Integer;
    FDataSetChangedCount: Integer;
    FReads: Integer;
    FReadErrors: Integer;
    FLastError: string;
    FLastValue: string;
    FSawActive: string;
    procedure _Read;
  protected
    procedure ActiveChanged; override;
    procedure DataSetChanged; override;
  public
    constructor CreateProbe(const AFieldName: string);
    property FieldName: string read FFieldName;
    property ActiveChangedCount: Integer read FActiveChangedCount;
    property DataSetChangedCount: Integer read FDataSetChangedCount;
    property Reads: Integer read FReads;
    property ReadErrors: Integer read FReadErrors;
    property LastError: string read FLastError;
    property LastValue: string read FLastValue;
    /// 'T'/'F' per notification, in order - what the control was told.
    property SawActive: string read FSawActive;
  end;

  [TestFixture]
  TTestCloseVsEmpty = class
  private
    FRows: TRowsConnection;
    FConn: IDBConnection;
    FTable: TFDMemTable;
    FCont: IContainerDataSet<TKeyOnly>;
    FRootTable: TFDMemTable;
    FMidTable: TFDMemTable;
    FRoot: IContainerDataSet<TAitRoot>;
    FMid: IContainerDataSet<TAitMid>;
    FSource: TDataSource;
    FLink: TProbeLink;
    procedure BuildFlat(const ARows: Integer);
    procedure BuildTree(const ARows: Integer; const ALinked: Boolean);
    procedure AttachControl(const ADataSet: TDataSet; const AFieldName: string);
    function Capture(const AProc: TProc): string;
    function FieldHandles(const ADataSet: TDataSet): TArray<TField>;
    function SameHandles(const A, B: TArray<TField>): Boolean;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // -----------------------------------------------------------------------
    // The premise: what the two Closes actually do
    // -----------------------------------------------------------------------

    /// The container Close leaves the dataset CLOSED. Until #248 it left it
    /// OPEN and EMPTY, because it called FDataSetAdapter.EmptyDataSet.
    [Test]
    procedure Premise_TheContainerCloseNowClosesForReal;
    /// And the protected adapter Close - the one the framework itself calls,
    /// and the one the container now routes to - really closes.
    [Test]
    procedure Premise_TheAdapterCloseReallyCloses;

    // -----------------------------------------------------------------------
    // The FIRST explanation, the one that was false
    // -----------------------------------------------------------------------

    /// The TField objects are built by TDataSetBaseAdapter<M>.Create, through
    /// Bind.SetInternalInitFieldDefsObjectClass - before anything is opened.
    [Test]
    procedure Fields_AreBuiltByTheAdapterConstructor;
    /// They are persistent, so TDataSet.DestroyFields (which only calls
    /// TFields.ClearAutomatic) cannot take them. Closing does not destroy one
    /// single field: the first explanation offered for the current behaviour
    /// is measurably false.
    [Test]
    procedure Fields_SurviveARealClose;
    /// And Open does not rebuild them either, so "closing would force the
    /// fields to be created again" costs nothing that Open would pay back.
    [Test]
    procedure Fields_AreNotRebuiltByOpen;

    // -----------------------------------------------------------------------
    // The SECOND explanation, leg 1: a repeated FindWhere
    // -----------------------------------------------------------------------

    /// FindWhere after the container Close: works.
    [Test]
    procedure FindWhere_RepeatsAfterTheContainerClose;
    /// FindWhere after a REAL close: measured, not deduced.
    [Test]
    procedure FindWhere_RepeatsAfterARealClose;
    /// WHY it survives: FindWhere never touches the container's own dataset.
    /// It goes to the session and builds objects out of a fresh cursor. This
    /// measures that claim instead of repeating it.
    [Test]
    procedure FindWhere_DoesNotTouchTheContainerDataSet;

    // -----------------------------------------------------------------------
    // The SECOND explanation, leg 2: a bound control
    // -----------------------------------------------------------------------

    /// With a TDataSource attached, the container Close is now seen as
    /// INACTIVE. Until #248 the control was never told the dataset went away,
    /// because it never did - it saw an OPEN, EMPTY dataset. THIS IS THE ONE
    /// PLACE WHERE THE BEHAVIOUR CHANGE IS VISIBLE TO A UI.
    [Test]
    procedure BoundControl_NowSeesTheContainerCloseAsInactive;
    /// A real close is seen as INACTIVE. What a control's read does then is
    /// what this measures.
    [Test]
    procedure BoundControl_SeesARealCloseAsInactive;

    // -----------------------------------------------------------------------
    // What actually happens next: reopening
    // -----------------------------------------------------------------------

    /// After the container Close, Open works. IT ALWAYS DID, FOR TWO DIFFERENT
    /// REASONS: before #248 because that Close never closed anything, and now
    /// because TDataSetBaseAdapter<M>.EnsureOpen reopens what it did close.
    /// A test that stayed green across a behaviour change is worth saying out
    /// loud about, not worth trusting silently.
    [Test]
    procedure Reopen_AfterTheContainerClose_Works;
    /// After a real close, Open is measured. This is the test that recorded the
    /// one-way door in #246 - it expected
    /// `Cannot perform this operation on a closed dataset` - and it is the test
    /// #248 exists to turn around.
    [Test]
    procedure Reopen_AfterARealClose_NowWorks;
    /// And WHY it used to break, narrowed to one missing call: put a raw
    /// TDataSet.Open in front of it - which is exactly what
    /// TDataSetBaseAdapter<M>.AddLookupField already did around its own close,
    /// and exactly what EnsureOpen now does on every Open path - and the
    /// container works. The cost of closing was never that something got
    /// destroyed.
    [Test]
    procedure Reopen_ARawDataSetOpenWasTheOnlyThingMissing;

    // -----------------------------------------------------------------------
    // The lazy, which is the owner's only reservation
    // -----------------------------------------------------------------------

    /// TDataSetAdapter<M>.LoadLazy uses FOrmDataSet.Active as its "already
    /// loaded" flag: it exits on the spot when the dataset is open. Since
    /// TFDMemTableAdapter<M>.Create opens the dataset, that gate is shut from
    /// birth - and until #248 the container Close could not open it, which is
    /// what made the lazy path unreachable. The cursor count on either side of
    /// the change is measured in Test.Janus.Reopen.Lazy.
    [Test]
    procedure Lazy_TheGateIsShutWhileOpenAndTheContainerCloseNowOpensIt;
    /// A REAL close flips that gate. This measures what LoadLazy then does -
    /// in #246 it walked into the reopen wall and raised.
    [Test]
    procedure Lazy_ARealCloseFlipsTheGateAndTheLoadNowCompletes;
    /// And the shipped code DOES perform a real close on that path:
    /// LoadLazy(nil) calls the protected Close. So "the framework never really
    /// closes" is false, and the lazy is where it is false.
    [Test]
    procedure Lazy_TheUnloadPathPerformsARealClose;

    // -----------------------------------------------------------------------
    // Master-detail: the two Closes cascade differently
    // -----------------------------------------------------------------------

    /// Both Closes reach the child and both now leave it CLOSED. Until #248
    /// the container Close reached it through EmptyDataSetChilds and left it
    /// OPEN and empty, which is the divergence this test was written for.
    [Test]
    procedure Cascade_BothReachTheChildAndNowLeaveItClosed;
  end;

implementation

const
  cROWS      = 3;
  cTREEROWS  = 2;
  cFIRSTK1   = 100;
  cCLOSEDMSG = 'Cannot perform this operation on a closed dataset';

{ TCloseAccess<M> }

class procedure TCloseAccess<M>.RealClose(
  const AAdapter: TDataSetBaseAdapter<M>);
begin
  TCloseAccess<M>(AAdapter).Close;
end;

{ TProbeLink }

constructor TProbeLink.CreateProbe(const AFieldName: string);
begin
  inherited Create;
  FFieldName := AFieldName;
  FActiveChangedCount := 0;
  FDataSetChangedCount := 0;
  FReads := 0;
  FReadErrors := 0;
  FLastError := '';
  FLastValue := '';
  FSawActive := '';
end;

procedure TProbeLink._Read;
begin
  if DataSet = nil then
    Exit;
  Inc(FReads);
  try
    FLastValue := DataSet.FieldByName(FFieldName).AsString;
  except
    on E: Exception do
    begin
      Inc(FReadErrors);
      FLastError := E.ClassName + ' | ' + E.Message;
      FLastValue := '';
    end;
  end;
end;

procedure TProbeLink.ActiveChanged;
begin
  inherited;
  Inc(FActiveChangedCount);
  if (DataSet <> nil) and DataSet.Active then
    FSawActive := FSawActive + 'T'
  else
    FSawActive := FSawActive + 'F';
  _Read;
end;

procedure TProbeLink.DataSetChanged;
begin
  inherited;
  Inc(FDataSetChangedCount);
  _Read;
end;

{ TTestCloseVsEmpty }

procedure TTestCloseVsEmpty.Setup;
begin
  FRows := nil;
  FConn := nil;
  FTable := nil;
  FCont := nil;
  FRootTable := nil;
  FMidTable := nil;
  FRoot := nil;
  FMid := nil;
  FSource := nil;
  FLink := nil;
end;

procedure TTestCloseVsEmpty.TearDown;
begin
  if FLink <> nil then
    FLink.DataSource := nil;
  FreeAndNil(FLink);
  FreeAndNil(FSource);
  FMid := nil;
  FRoot := nil;
  FCont := nil;
  FreeAndNil(FMidTable);
  FreeAndNil(FRootTable);
  FreeAndNil(FTable);
  FConn := nil;
  FRows := nil;
end;

/// A container over TKeyOnly: two integer columns, no association, so the only
/// thing moving is the container itself.
procedure TTestCloseVsEmpty.BuildFlat(const ARows: Integer);
begin
  FRows := TRowsConnection.Create(dnSQLite, ARows, KeyOnlySchema(),
             KeyOnlyRow(), 'close');
  FConn := FRows;
  FTable := TFDMemTable.Create(nil);
  FCont := TContainerFDMemTable<TKeyOnly>.Create(FConn, FTable);
end;

/// Root plus mid. ALinked = False builds the mid WITHOUT a master, which is
/// what TDataSetAdapter<M>.LoadLazy requires (it exits when FOwnerMasterObject
/// is already set).
procedure TTestCloseVsEmpty.BuildTree(const ARows: Integer;
  const ALinked: Boolean);
begin
  FRows := TRowsConnection.Create(dnSQLite, ARows,
    // Every column of BOTH entities: Bind.SetFieldToField walks the TARGET
    // dataset's fields and reads each one out of the cursor by name, so a
    // column the cursor does not have is 'Field <name> not found' - measured.
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add('root_id', ftInteger);
      ADataSet.FieldDefs.Add('mid_id', ftInteger);
      ADataSet.FieldDefs.Add('tag', ftString, 20);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName('root_id').AsInteger := 1 + AIndex;
      ADataSet.FieldByName('mid_id').AsInteger := 10 + AIndex;
      ADataSet.FieldByName('tag').AsString := 'T' + IntToStr(AIndex);
    end,
    'tree');
  FConn := FRows;
  FRootTable := TFDMemTable.Create(nil);
  FRoot := TContainerFDMemTable<TAitRoot>.Create(FConn, FRootTable);
  FMidTable := TFDMemTable.Create(nil);
  if ALinked then
    FMid := TContainerFDMemTable<TAitMid>.Create(FConn, FMidTable, FRoot.This)
  else
    FMid := TContainerFDMemTable<TAitMid>.Create(FConn, FMidTable);
end;

procedure TTestCloseVsEmpty.AttachControl(const ADataSet: TDataSet;
  const AFieldName: string);
begin
  FSource := TDataSource.Create(nil);
  FSource.DataSet := ADataSet;
  FLink := TProbeLink.CreateProbe(AFieldName);
  FLink.DataSource := FSource;
end;

function TTestCloseVsEmpty.Capture(const AProc: TProc): string;
begin
  Result := '';
  try
    AProc();
  except
    on E: Exception do
      Result := E.ClassName + ' | ' + E.Message;
  end;
end;

function TTestCloseVsEmpty.FieldHandles(const ADataSet: TDataSet): TArray<TField>;
var
  LFor: Integer;
begin
  SetLength(Result, ADataSet.Fields.Count);
  for LFor := 0 to ADataSet.Fields.Count - 1 do
    Result[LFor] := ADataSet.Fields[LFor];
end;

function TTestCloseVsEmpty.SameHandles(const A, B: TArray<TField>): Boolean;
var
  LFor: Integer;
begin
  Result := Length(A) = Length(B);
  if not Result then
    Exit;
  for LFor := 0 to High(A) do
    if A[LFor] <> B[LFor] then
      Exit(False);
end;

// ---------------------------------------------------------------------------
// The premise
// ---------------------------------------------------------------------------

procedure TTestCloseVsEmpty.Premise_TheContainerCloseNowClosesForReal;
begin
  BuildFlat(cROWS);
  FCont.Open;
  Assert.AreEqual(cROWS, FTable.RecordCount,
    'the container must really be holding rows, otherwise nothing is measured');

  FCont.Close;

  Assert.IsFalse(FTable.Active,
    'TContainerDataSet<M>.Close calls FDataSetAdapter.Close, so the dataset ' +
    'is CLOSED after it and the name finally describes the body. Until #248 ' +
    'it called EmptyDataSet and this assertion was the other way round');
  Assert.AreEqual(0, FTable.RecordCount,
    'and a closed dataset counts no rows');
end;

procedure TTestCloseVsEmpty.Premise_TheAdapterCloseReallyCloses;
begin
  BuildFlat(cROWS);
  FCont.Open;
  Assert.AreEqual(cROWS, FTable.RecordCount);

  TCloseAccess<TKeyOnly>.RealClose(FCont.This);

  Assert.IsFalse(FTable.Active,
    'TDataSetBaseAdapter<M>.Close is FOrmDataSet.Close - a real close. It is ' +
    'protected, and the framework calls it from DoBeforeClose and from ' +
    'TDataSetAdapter<M>.LoadLazy');
end;

// ---------------------------------------------------------------------------
// The first explanation, the one that was false
// ---------------------------------------------------------------------------

procedure TTestCloseVsEmpty.Fields_AreBuiltByTheAdapterConstructor;
var
  LFor: Integer;
  LAutomatic: Integer;
begin
  // Nothing has been opened: the container has only been constructed.
  BuildFlat(cROWS);

  Assert.IsTrue(FTable.Fields.Count > 0,
    'Bind.SetInternalInitFieldDefsObjectClass runs inside ' +
    'TDataSetBaseAdapter<M>.Create, so the fields exist before any Open');
  Assert.IsNotNull(FTable.FindField('k1'), 'k1 must be there');
  Assert.IsNotNull(FTable.FindField('k2'), 'k2 must be there');

  LAutomatic := 0;
  for LFor := 0 to FTable.Fields.Count - 1 do
    if FTable.Fields[LFor].LifeCycle = lcAutomatic then
      Inc(LAutomatic);
  Assert.AreEqual(0, LAutomatic,
    'every field the adapter creates is lcPersistent - TField.SetDataSet ' +
    'stamps lcAutomatic only while the dataset is opening/active, and ' +
    'SetInternalInitFieldDefsObjectClass closes it first. That is why ' +
    'TDataSet.DestroyFields, which only calls TFields.ClearAutomatic, cannot ' +
    'take any of them');
end;

procedure TTestCloseVsEmpty.Fields_SurviveARealClose;
var
  LBefore: TArray<TField>;
  LAfter: TArray<TField>;
begin
  BuildFlat(cROWS);
  FCont.Open;
  LBefore := FieldHandles(FTable);
  Assert.IsTrue(Length(LBefore) > 0);

  TCloseAccess<TKeyOnly>.RealClose(FCont.This);
  LAfter := FieldHandles(FTable);

  Assert.IsFalse(FTable.Active, 'the dataset really closed');
  Assert.AreEqual(Length(LBefore), Length(LAfter),
    'CLOSING DESTROYS NO FIELD. The first explanation ever offered for ' +
    'TContainerDataSet<M>.Close emptying instead of closing said it would - ' +
    'and it is false, measured here on TFDMemTable');
  Assert.IsTrue(SameHandles(LBefore, LAfter),
    'and they are the SAME TField objects, not equally named replacements');
end;

procedure TTestCloseVsEmpty.Fields_AreNotRebuiltByOpen;
var
  LAtBirth: TArray<TField>;
  LAfterOpen: TArray<TField>;
  LAfterSecond: TArray<TField>;
begin
  BuildFlat(cROWS);
  LAtBirth := FieldHandles(FTable);

  FCont.Open;
  LAfterOpen := FieldHandles(FTable);
  Assert.IsTrue(SameHandles(LAtBirth, LAfterOpen),
    'Open does not create fields: TFDMemTableAdapter<M>.OpenSQLInternal only ' +
    'reopens (EnsureOpen), empties and appends rows. So "closing would make ' +
    'Open rebuild the fields" has no cost to point at');

  FCont.Close;
  FCont.Open;
  LAfterSecond := FieldHandles(FTable);
  Assert.IsTrue(SameHandles(LAtBirth, LAfterSecond),
    'and a second Open does not either');
end;

// ---------------------------------------------------------------------------
// A repeated FindWhere
// ---------------------------------------------------------------------------

procedure TTestCloseVsEmpty.FindWhere_RepeatsAfterTheContainerClose;
var
  LFirst: TObjectList<TKeyOnly>;
  LSecond: TObjectList<TKeyOnly>;
  LError: string;
begin
  BuildFlat(cROWS);
  FCont.Open;

  LFirst := FCont.FindWhere('k1 > 0');
  try
    Assert.AreEqual(cROWS, LFirst.Count, 'the first FindWhere must find rows');
  finally
    LFirst.Free;
  end;

  FCont.Close;

  LSecond := nil;
  LError := Capture(
    procedure
    begin
      LSecond := FCont.FindWhere('k1 > 0');
    end);
  try
    Assert.AreEqual('', LError,
      'a second FindWhere after the CONTAINER Close must not raise');
    Assert.IsNotNull(LSecond);
    Assert.AreEqual(cROWS, LSecond.Count,
      'and it must find the same rows');
  finally
    LSecond.Free;
  end;
end;

procedure TTestCloseVsEmpty.FindWhere_RepeatsAfterARealClose;
var
  LFirst: TObjectList<TKeyOnly>;
  LSecond: TObjectList<TKeyOnly>;
  LError: string;
begin
  BuildFlat(cROWS);
  FCont.Open;

  LFirst := FCont.FindWhere('k1 > 0');
  try
    Assert.AreEqual(cROWS, LFirst.Count);
  finally
    LFirst.Free;
  end;

  TCloseAccess<TKeyOnly>.RealClose(FCont.This);
  Assert.IsFalse(FTable.Active, 'the dataset really is closed for this leg');

  LSecond := nil;
  LError := Capture(
    procedure
    begin
      LSecond := FCont.FindWhere('k1 > 0');
    end);
  try
    Assert.AreEqual('', LError,
      'MEASURED: a repeated FindWhere over a CLOSED container does not ' +
      'raise. This is the hypothesis the issue asked about, and the answer ' +
      'is that FindWhere is not where the harm is');
    Assert.IsNotNull(LSecond);
    Assert.AreEqual(cROWS, LSecond.Count,
      'and it still returns every row');
  finally
    LSecond.Free;
  end;
end;

procedure TTestCloseVsEmpty.FindWhere_DoesNotTouchTheContainerDataSet;
var
  LList: TObjectList<TKeyOnly>;
begin
  BuildFlat(cROWS);
  FCont.Open;
  Assert.AreEqual(cROWS, FTable.RecordCount);
  FCont.Close;
  Assert.AreEqual(0, FTable.RecordCount,
    'the container dataset holds nothing - since #248 because it is CLOSED, ' +
    'before it because it had been emptied');

  LList := FCont.FindWhere('k1 > 0');
  try
    Assert.AreEqual(cROWS, LList.Count,
      'FindWhere returned objects...');
    Assert.AreEqual(0, FTable.RecordCount,
      '...and put NOT ONE of them into the container dataset. The route is ' +
      'TContainerDataSet<M>.FindWhere -> TDataSetBaseAdapter<M>.FindWhere -> ' +
      'FSession.FindWhere -> PopularObjectSet, and FOrmDataSet is not on it. ' +
      'That is why closing cannot break it');
  finally
    LList.Free;
  end;
end;

// ---------------------------------------------------------------------------
// A bound control
// ---------------------------------------------------------------------------

procedure TTestCloseVsEmpty.BoundControl_NowSeesTheContainerCloseAsInactive;
var
  LErrorsBefore: Integer;
begin
  BuildFlat(cROWS);
  FCont.Open;
  AttachControl(FTable, 'k1');
  LErrorsBefore := FLink.ReadErrors;

  FCont.Close;

  Assert.IsFalse(FLink.Active,
    'THE ONE PLACE THE #248 BEHAVIOUR CHANGE IS VISIBLE TO A UI. The container ' +
    'Close now reaches TDataLink.ActiveChanged and the link goes inactive. ' +
    'Before it, the control was never told anything, because nothing had ' +
    'happened to the dataset except losing its rows');
  Assert.AreEqual(LErrorsBefore, FLink.ReadErrors,
    'and STILL no read raised - the control is told, not broken. Measured: ' +
    FLink.LastError);
  Assert.AreEqual('', FLink.LastValue,
    'it reads blank, exactly as it did off an empty open dataset');
end;

procedure TTestCloseVsEmpty.BoundControl_SeesARealCloseAsInactive;
var
  LOutcome: string;
begin
  BuildFlat(cROWS);
  FCont.Open;
  AttachControl(FTable, 'k1');
  Assert.IsTrue(FLink.Active, 'the control starts bound to an OPEN dataset');

  TCloseAccess<TKeyOnly>.RealClose(FCont.This);

  Assert.IsFalse(FLink.Active,
    'a real close DOES reach the control: TDataLink.ActiveChanged fires and ' +
    'the link goes inactive. Since #248 the container Close arrives here too - ' +
    'see BoundControl_NowSeesTheContainerCloseAsInactive - and before it, it ' +
    'was the only one of the two the control ever heard about');
  // errors seen | last error text
  LOutcome := IntToStr(FLink.ReadErrors) + ' # ' + FLink.LastError;
  Assert.AreEqual('0 # ', LOutcome,
    'MEASURED: reading a persistent TField of a CLOSED dataset does not ' +
    'raise - it answers blank. So the "data error" the second explanation ' +
    'remembered is not produced by the read itself');
end;

// ---------------------------------------------------------------------------
// Reopening - what an application really does after Close
// ---------------------------------------------------------------------------

procedure TTestCloseVsEmpty.Reopen_AfterTheContainerClose_Works;
var
  LError: string;
begin
  BuildFlat(cROWS);
  FCont.Open;
  FCont.Close;

  LError := Capture(
    procedure
    begin
      FCont.Open;
    end);

  Assert.AreEqual('', LError,
    'reopening after the container Close must work. IT DID BEFORE #248 TOO, ' +
    'and for a different reason: that Close left the dataset open, so there ' +
    'was nothing to reopen. Now there is, and EnsureOpen does it');
  Assert.AreEqual(cROWS, FTable.RecordCount, 'and it must bring the rows back');
end;

procedure TTestCloseVsEmpty.Reopen_AfterARealClose_NowWorks;
var
  LError: string;
begin
  BuildFlat(cROWS);
  FCont.Open;
  TCloseAccess<TKeyOnly>.RealClose(FCont.This);
  Assert.IsFalse(FTable.Active);

  LError := Capture(
    procedure
    begin
      FCont.Open;
    end);

  Assert.AreEqual('', LError,
    'THE ONE-WAY DOOR IS GONE. In #246 this assertion read ' +
    '`Exception | ' + cCLOSEDMSG + '`: ' +
    'TFDMemTableAdapter<M>.OpenSQLInternal started with EmptyDataSet, ' +
    'TFDDataSet.EmptyDataSet opens with CheckBrowseMode, and CheckBrowseMode ' +
    'refuses a closed dataset. TDataSetBaseAdapter<M>.EnsureOpen now runs ' +
    'ahead of that EmptyDataSet, which is the whole of the fix');
  Assert.AreEqual(cROWS, FTable.RecordCount,
    'and the container is full again afterwards');
end;

procedure TTestCloseVsEmpty.Reopen_ARawDataSetOpenWasTheOnlyThingMissing;
var
  LError: string;
begin
  BuildFlat(cROWS);
  FCont.Open;
  TCloseAccess<TKeyOnly>.RealClose(FCont.This);
  Assert.IsFalse(FTable.Active);

  // The call the adapter did not make on the Open path before #248. It was
  // never exotic: TDataSetBaseAdapter<M>.AddLookupField already closed the
  // dataset and reopened it with exactly this, inside its own finally - and
  // EnsureOpen is now the same call, in the one place that was missing it.
  FTable.Open;
  Assert.IsTrue(FTable.Active,
    'a closed TFDMemTable reopens on a plain TDataSet.Open - nothing was ' +
    'destroyed by the close');

  LError := Capture(
    procedure
    begin
      FCont.Open;
    end);

  Assert.AreEqual('', LError,
    'and with the dataset open again the container works normally. THE HARM ' +
    'OF CLOSING WAS ONE MISSING REOPEN, NOT A LOST RESOURCE - which is why ' +
    'the whole of #248 is a bare Open in the right place');
  Assert.AreEqual(cROWS, FTable.RecordCount,
    'every row is back');
end;

// ---------------------------------------------------------------------------
// The lazy
// ---------------------------------------------------------------------------

procedure TTestCloseVsEmpty.Lazy_TheGateIsShutWhileOpenAndTheContainerCloseNowOpensIt;
var
  LBefore: Integer;
begin
  BuildTree(cTREEROWS, False);
  FRoot.Open;
  Assert.AreEqual(cTREEROWS, FRootTable.RecordCount, 'the master must have rows');
  Assert.IsTrue(FMidTable.Active,
    'TFDMemTableAdapter<M>.Create opened the child dataset, so the lazy gate ' +
    'is already shut before anybody calls anything');

  LBefore := FRows.CreateCount;
  FMid.LoadLazy(TAitMid(FRoot.This));
  Assert.AreEqual(LBefore, FRows.CreateCount,
    'LoadLazy exits on `if FOrmDataSet.Active then Exit` - not one cursor was ' +
    'opened. THIS HALF DID NOT CHANGE');

  FMid.Close;

  Assert.IsFalse(FMidTable.Active,
    'AND THIS HALF DID. The container Close now closes, so the gate LoadLazy ' +
    'reads finally opens. Until #248 this assertion was IsTrue and the lazy ' +
    'dataset path had no way in at all. What LoadLazy then asks the ' +
    'connection for is counted in Test.Janus.Reopen.Lazy - the cursor number ' +
    'is the point of the change and belongs with the change');
end;

procedure TTestCloseVsEmpty.Lazy_ARealCloseFlipsTheGateAndTheLoadNowCompletes;
var
  LBefore: Integer;
  LError: string;
begin
  BuildTree(cTREEROWS, False);
  FRoot.Open;
  TCloseAccess<TAitMid>.RealClose(FMid.This);
  Assert.IsFalse(FMidTable.Active, 'the gate is open now');

  LBefore := FRows.CreateCount;
  LError := Capture(
    procedure
    begin
      FMid.LoadLazy(TAitMid(FRoot.This));
    end);

  Assert.AreEqual('', LError,
    'MEASURED: past the gate, LoadLazy walks into OpenSQLInternal, and ' +
    'OpenSQLInternal now reopens the dataset before emptying it. In #246 this ' +
    'assertion read `Exception | ' + cCLOSEDMSG + '` and the reservation ' +
    'about the lazy was exactly that');
  Assert.IsTrue(FRows.CreateCount > LBefore,
    'and it reached the connection instead of dying in front of it: ' +
    IntToStr(FRows.CreateCount - LBefore) + ' cursor(s), against the zero ' +
    '#246 measured');
end;

procedure TTestCloseVsEmpty.Lazy_TheUnloadPathPerformsARealClose;
begin
  BuildTree(cTREEROWS, True);
  FRoot.Open;
  Assert.IsTrue(FMidTable.Active, 'the child starts open');

  // The unload branch of TDataSetAdapter<M>.LoadLazy: AOwner = nil.
  FMid.LoadLazy(nil);

  Assert.IsFalse(FMidTable.Active,
    'LoadLazy(nil) calls the PROTECTED Close, which is a real ' +
    'FOrmDataSet.Close. Before #248 this was the ONLY path on which the ' +
    'framework closed a dataset for real - and it was also the path with no ' +
    'way back, which is why the lazy was where the reopen had to be fixed');
end;

// ---------------------------------------------------------------------------
// Master-detail
// ---------------------------------------------------------------------------

procedure TTestCloseVsEmpty.Cascade_BothReachTheChildAndNowLeaveItClosed;
begin
  BuildTree(cTREEROWS, True);
  FRoot.Open;
  Assert.IsTrue(FMidTable.Active);

  FRoot.Close;
  Assert.IsFalse(FMidTable.Active,
    'the container Close now travels down TDataSetBaseAdapter<M>' +
    '.DoBeforeClose and leaves the child CLOSED. Until #248 it travelled down ' +
    'TFDMemTableAdapter<M>.EmptyDataSetChilds instead and left it OPEN and ' +
    'empty - the two routes are still distinct, the end state no longer is');
  Assert.AreEqual(0, FMidTable.RecordCount, 'and holding nothing');

  FRoot.Open;
  Assert.IsTrue(FRootTable.Active, 'the master comes back');
  Assert.IsTrue(FMidTable.Active,
    'AND SO DOES THE CHILD - which is the half that matters, and the half the ' +
    'assertion above cannot see. Reopening the master runs OpenDataSetChilds, ' +
    'which drives the child through its own Open*Internal and therefore ' +
    'through EnsureOpen. THE WHOLE TREE COMES BACK, and that is what makes ' +
    'the cascade above a decision instead of a trap: in #246 a cascaded real ' +
    'close put every child into a state nothing could recover from');

  TCloseAccess<TAitRoot>.RealClose(FRoot.This);
  Assert.IsFalse(FRootTable.Active, 'the master really closed');
  Assert.IsFalse(FMidTable.Active,
    'and the protected Close cascades to the child by the same DoBeforeClose ' +
    'route - the two Closes now agree end to end');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestCloseVsEmpty);

end.
