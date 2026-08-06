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

{ @abstract(Janus Framework - why the six Apply* loops terminate.)

  WHAT IS UNDER TEST

  Six loops walk a FILTERED dataset without ever calling Next:
  TFDMemTableAdapter<M>.ApplyInserter and .ApplyUpdater,
  TClientDataSetAdapter<M>.ApplyInserter and .ApplyUpdater,
  TRESTDataSetAdapter<M>.ApplyInserter and .ApplyUpdater. Five of them exit on
  `RecordCount > 0`; TRESTDataSetAdapter<M>.ApplyInserter exits on `not Eof`.
  All six advance only as a side effect of the Post in their own body pushing
  the current row out of the active Filter.

  WHAT THE MEASUREMENT FOUND

  The row leaves the filter only because the marker the body writes SURVIVES
  the Post. It survives because every shipped caller - the ApplyInternal of
  TFDMemTableAdapter<M>, TClientDataSetAdapter<M>, TRESTFDMemTableAdapter<M>
  and TRESTClientDataSetAdapter<M> - calls DisableDataSetEvents first, which
  unhooks TDataSetBaseAdapter<M>.DoBeforePost. With that event live,
  DoBeforePost rewrites the marker the body just cleared back to
  Integer(dsEdit) - and Integer(dsEdit) is exactly what ApplyUpdater filters
  on, so the row never leaves the filtered set. Measured in all three
  families: the loop runs until the fixture's ceiling stops it. The same event
  makes ApplyInserter TERMINATE - its filter is Integer(dsInsert), which
  differs from the rewritten value - but leaves every just-inserted row marked
  as a pending edit.

  So the coupling is not three-legged (filter expression, field written, value
  written); it is four-legged, and the fourth leg lives in a DIFFERENT method
  from the loops.

  WHY THE TESTS THAT CALL ApplyInserter / ApplyUpdater DIRECTLY ARE NOT
  CLAIMING A SHIPPED DEFECT

  No shipped caller reaches those two methods without DisableDataSetEvents:
  the only callers are the four ApplyInternal above, and each of them disables
  first. The direct calls here exist to MEASURE what that caller is
  protecting, so the protection is a number instead of a reading.

  THE OTHER LEG: FILTER BY NAME, WRITE BY INDEX

  The filter selects on the field NAMED cInternalField; the body reads and
  writes FOrmDataSet.Fields[FInternalIndex], and FInternalIndex is assigned 0
  in TDataSetBaseAdapter<M>.Create. Nothing in the compiler ties the two
  together: what puts that field at position 0 is
  TBind.SetInternalInitFieldDefsObjectClass, in another unit. The first group
  of tests measures that position in every field shape this framework can
  build.

  HOW A HANG BECOMES A RED

  A loop that never advances does not fail, it hangs. TWatchedMemTable and
  TWatchedClientDataSet descend from the REAL components the adapters take and
  count two things: the polls of RecordCount and the reads of field 0. Past a
  budget proportional to the row count they raise EApplyRunaway instead of
  answering, so the runaway fails in milliseconds naming the counts.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Apply.Loops;

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
  Janus.DataSet.Fields,
  Janus.DataSet.Base.Adapter,
  Janus.DataSet.FDMemTable,
  Janus.DataSet.ClientDataSet,
  Janus.RestDataSet.FDMemTable,
  Janus.RestDataSet.ClientDataSet,
  Janus.RestFactory.Interfaces,
  Janus.Client.Methods,
  Test.Janus.Model.Nested,
  Test.Janus.Model.FieldShapes,
  Test.Janus.Model.AutoIncTree,
  Test.Janus.Cursor.Double,
  Test.Janus.MasterDetail.Link;

type
  /// <summary> Raised by the watched datasets when a caller polls far more
  ///  times than the row count can justify - i.e. it is looping without the
  ///  current row ever leaving the filter. In production the very same code
  ///  path is an infinite loop. </summary>
  EApplyRunaway = class(Exception);

  /// <summary> The real TFDMemTable the FDMemTable and REST-FDMemTable
  ///  adapters take, instrumented so a non-terminating Apply* loop fails fast
  ///  instead of hanging. Both counters are needed: five of the six loops poll
  ///  RecordCount, and TRESTDataSetAdapter<M>.ApplyInserter polls Eof, which
  ///  is not virtual and cannot be counted - but every one of the six reads
  ///  field 0 once per iteration in its guard. </summary>
  TWatchedMemTable = class(TFDMemTable)
  private
    FPolls: Integer;
    FBudget: Integer;
    FReads: Integer;
    procedure _CountRead(const AField: TField);
  protected
    function GetRecordCount: Integer; override;
    function GetFieldData(Field: TField;
      var Buffer: TValueBuffer): Boolean; overload; override;
    function GetFieldData(Field: TField; var Buffer: TValueBuffer;
      NativeFormat: Boolean): Boolean; overload; override;
  public
    /// Budget 0 disarms, so the fixture can read the result of a run that has
    /// already burned its budget.
    procedure Arm(const ABudget: Integer);
    property Polls: Integer read FPolls;
    property Reads: Integer read FReads;
  end;

  /// <summary> Same instrumentation over the real TClientDataSet. </summary>
  TWatchedClientDataSet = class(TClientDataSet)
  private
    FPolls: Integer;
    FBudget: Integer;
    FReads: Integer;
    procedure _CountRead(const AField: TField);
  protected
    function GetRecordCount: Integer; override;
    function GetFieldData(Field: TField;
      var Buffer: TValueBuffer): Boolean; overload; override;
    function GetFieldData(Field: TField; var Buffer: TValueBuffer;
      NativeFormat: Boolean): Boolean; overload; override;
  public
    procedure Arm(const ABudget: Integer);
    property Polls: Integer read FPolls;
    property Reads: Integer read FReads;
  end;

  /// <summary> TInertRestConnection answers an empty JSON ARRAY.
  ///  TSessionRestFul<M>.Insert parses its answer as a JSON OBJECT, so that
  ///  answer raises EInvalidCast inside the session before the loop under test
  ///  can be reached. This one answers an empty OBJECT and nothing else.
  ///  </summary>
  TObjectRestConnection = class(TInertRestConnection, IRESTConnection)
  public
    function Execute(const AResource, ASubResource: String;
      const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): String; overload;
    function Execute(const AResource: String;
      const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): String; overload;
  end;

  /// <summary> Classic protected-access descendant. ApplyInserter,
  ///  ApplyUpdater, ApplyInternal, DisableDataSetEvents and
  ///  EnableDataSetEvents are protected, and driving the SHIPPED methods is
  ///  the whole point. </summary>
  TApplyAccess<M: class, constructor> = class(TDataSetBaseAdapter<M>)
  public
    class procedure Inserter(const A: TDataSetBaseAdapter<M>);
    class procedure Updater(const A: TDataSetBaseAdapter<M>);
    class procedure Internal(const A: TDataSetBaseAdapter<M>);
    class procedure MuteEvents(const A: TDataSetBaseAdapter<M>);
    class procedure UnmuteEvents(const A: TDataSetBaseAdapter<M>);
  end;

  [TestFixture]
  TTestApplyLoops = class
  private
    FConn: IDBConnection;
    FRest: IRESTConnection;
    procedure SeedPendingInserts(const ADataSet: TDataSet;
      const ARows: Integer);
    procedure SeedPendingEdits(const ADataSet: TDataSet; const ARows: Integer);
    function Markers(const ADataSet: TDataSet): string;
    function MinusOnes(const ADataSet: TDataSet): Integer;
    procedure ApplyOverFDMemTable(const ARows: Integer);
    procedure ApplyOverClientDataSet(const ARows: Integer);
    procedure ApplyOverRestFDMemTable(const ARows: Integer);
    procedure ApplyOverRestClientDataSet(const ARows: Integer);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // --- the field the filter names is the field the body writes ----------
    [Test]
    procedure InternalFieldIsFieldZero_FDMemTable;
    [Test]
    procedure InternalFieldIsFieldZero_ClientDataSet;
    [Test]
    procedure InternalFieldIsFieldZero_RestClient;
    [Test]
    procedure InternalFieldIsFieldZero_NestedDataSet;
    [Test]
    procedure InternalFieldIsFieldZero_WithCalcAndAggregateFields;
    [Test]
    procedure InternalFieldIsFieldZero_AfterAddLookupField;
    [Test]
    procedure InternalFieldIsFieldZero_AfterCloseAndReopen;
    [Test]
    procedure SecondAdapterOverTheSameDataSet_RefusesToBuild;
    [Test]
    procedure InternalFieldCarriesTheMinusOneDefault;

    // --- the six loops terminate on the shipped path ----------------------
    // N rows, ONE row and NO rows, on each of the FOUR concrete adapters that
    // own an ApplyInternal. One row is not redundant: a loop that walks a
    // single row can be broken and still look right, which is why the sibling
    // fixture of #207 measured 0, 1 and N as well.
    [Test]
    procedure FDMemTable_ApplyInternal_ClearsEveryPendingRow;
    [Test]
    procedure FDMemTable_ApplyInternal_WithOneRow;
    [Test]
    procedure FDMemTable_ApplyInternal_WithNoRows;
    [Test]
    procedure ClientDataSet_ApplyInternal_ClearsEveryPendingRow;
    [Test]
    procedure ClientDataSet_ApplyInternal_WithOneRow;
    [Test]
    procedure ClientDataSet_ApplyInternal_WithNoRows;
    [Test]
    procedure Rest_ApplyInternal_ClearsEveryPendingRow;
    [Test]
    procedure Rest_ApplyInternal_WithOneRow;
    [Test]
    procedure Rest_ApplyInternal_WithNoRows;
    [Test]
    procedure RestClientDataSet_ApplyInternal_ClearsEveryPendingRow;
    [Test]
    procedure RestClientDataSet_ApplyInternal_WithOneRow;
    [Test]
    procedure RestClientDataSet_ApplyInternal_WithNoRows;
    [Test]
    procedure MixedMarkers_ApplyInternal_ClearsEveryPendingRowAndKeepsKeys;

    // --- what makes them terminate ----------------------------------------
    [Test]
    procedure FDMemTable_ApplyUpdater_WithBeforePostLive_NeverTerminates;
    [Test]
    procedure ClientDataSet_ApplyUpdater_WithBeforePostLive_NeverTerminates;
    [Test]
    procedure Rest_ApplyUpdater_WithBeforePostLive_NeverTerminates;
    [Test]
    procedure RestClientDataSet_ApplyUpdater_WithBeforePostLive_NeverTerminates;
    [Test]
    procedure ApplyInserter_WithBeforePostLive_LeavesTheRowMarkedEdit;
    [Test]
    procedure DisableDataSetEvents_UnhooksBeforePost;

    // --- the -1 is an integrity guard, not loop bookkeeping ---------------
    [Test]
    procedure ApplyInserter_DoesNotRepointAChildRowOfAnotherMaster;
  end;

implementation

const
  cKEYFIELD = 'root_id';
  cOWNKEY   = 'mid_id';
  cTAG      = 'tag';
  cROWS     = 6;
  cFOREIGN  = 999;
  cNEWKEY   = 500;
  cAPPLIED  = -1;

/// A correct loop touches the marker once per row. Eight times that plus a
/// fixed slack absorbs the incidental reads the ORM and the dataset make
/// around the loop, and is still reached instantly by a loop that spins.
function Budget(const ARows: Integer): Integer;
begin
  Result := (ARows + 1) * 8 + 64;
end;

{ TWatchedMemTable }

procedure TWatchedMemTable.Arm(const ABudget: Integer);
begin
  FPolls := 0;
  FReads := 0;
  FBudget := ABudget;
end;

procedure TWatchedMemTable._CountRead(const AField: TField);
begin
  if FBudget <= 0 then
    Exit;
  if AField = nil then
    Exit;
  if AField.Index <> 0 then
    Exit;
  Inc(FReads);
  if FReads > FBudget then
    raise EApplyRunaway.CreateFmt(
      'field 0 read %d times (budget %d). The row the body writes is not ' +
      'leaving the filter - in production this is an infinite loop, not a ' +
      'slow one.', [FReads, FBudget]);
end;

function TWatchedMemTable.GetRecordCount: Integer;
begin
  if FBudget > 0 then
  begin
    Inc(FPolls);
    if FPolls > FBudget then
      raise EApplyRunaway.CreateFmt(
        'RecordCount polled %d times (budget %d). The row the body writes is ' +
        'not leaving the filter - in production this is an infinite loop.',
        [FPolls, FBudget]);
  end;
  Result := inherited GetRecordCount;
end;

function TWatchedMemTable.GetFieldData(Field: TField;
  var Buffer: TValueBuffer): Boolean;
begin
  _CountRead(Field);
  Result := inherited GetFieldData(Field, Buffer);
end;

function TWatchedMemTable.GetFieldData(Field: TField;
  var Buffer: TValueBuffer; NativeFormat: Boolean): Boolean;
begin
  _CountRead(Field);
  Result := inherited GetFieldData(Field, Buffer, NativeFormat);
end;

{ TWatchedClientDataSet }

procedure TWatchedClientDataSet.Arm(const ABudget: Integer);
begin
  FPolls := 0;
  FReads := 0;
  FBudget := ABudget;
end;

procedure TWatchedClientDataSet._CountRead(const AField: TField);
begin
  if FBudget <= 0 then
    Exit;
  if AField = nil then
    Exit;
  if AField.Index <> 0 then
    Exit;
  Inc(FReads);
  if FReads > FBudget then
    raise EApplyRunaway.CreateFmt(
      'field 0 read %d times (budget %d). The row the body writes is not ' +
      'leaving the filter - in production this is an infinite loop.',
      [FReads, FBudget]);
end;

function TWatchedClientDataSet.GetRecordCount: Integer;
begin
  if FBudget > 0 then
  begin
    Inc(FPolls);
    if FPolls > FBudget then
      raise EApplyRunaway.CreateFmt(
        'RecordCount polled %d times (budget %d). The row the body writes is ' +
        'not leaving the filter - in production this is an infinite loop.',
        [FPolls, FBudget]);
  end;
  Result := inherited GetRecordCount;
end;

function TWatchedClientDataSet.GetFieldData(Field: TField;
  var Buffer: TValueBuffer): Boolean;
begin
  _CountRead(Field);
  Result := inherited GetFieldData(Field, Buffer);
end;

function TWatchedClientDataSet.GetFieldData(Field: TField;
  var Buffer: TValueBuffer; NativeFormat: Boolean): Boolean;
begin
  _CountRead(Field);
  Result := inherited GetFieldData(Field, Buffer, NativeFormat);
end;

{ TObjectRestConnection }

function TObjectRestConnection.Execute(const AResource, ASubResource: String;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): String;
begin
  if Assigned(AParams) then
    AParams();
  Result := '{}';
end;

function TObjectRestConnection.Execute(const AResource: String;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): String;
begin
  if Assigned(AParams) then
    AParams();
  Result := '{}';
end;

{ TApplyAccess<M> }

class procedure TApplyAccess<M>.Inserter(const A: TDataSetBaseAdapter<M>);
begin
  TApplyAccess<M>(A).ApplyInserter(0);
end;

class procedure TApplyAccess<M>.Updater(const A: TDataSetBaseAdapter<M>);
begin
  TApplyAccess<M>(A).ApplyUpdater(0);
end;

class procedure TApplyAccess<M>.Internal(const A: TDataSetBaseAdapter<M>);
begin
  TApplyAccess<M>(A).ApplyInternal(0);
end;

class procedure TApplyAccess<M>.MuteEvents(const A: TDataSetBaseAdapter<M>);
begin
  TApplyAccess<M>(A).DisableDataSetEvents;
end;

class procedure TApplyAccess<M>.UnmuteEvents(const A: TDataSetBaseAdapter<M>);
begin
  TApplyAccess<M>(A).EnableDataSetEvents;
end;

{ TTestApplyLoops }

procedure TTestApplyLoops.Setup;
begin
  // Zero rows keeps the cursor double inert: no test here opens a cursor.
  FConn := TRowsConnection.Create(dnSQLite, 0,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add(cKEYFIELD, ftInteger);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName(cKEYFIELD).AsInteger := AIndex;
    end,
    'apply-loops');
  FRest := TObjectRestConnection.Create;
end;

procedure TTestApplyLoops.TearDown;
begin
  FRest := nil;
  FConn := nil;
end;

/// Rows exactly as the operator leaves them after typing: posted into the
/// in-memory table and never applied, so DoBeforePost has stamped
/// Integer(dsInsert) on each one.
procedure TTestApplyLoops.SeedPendingInserts(const ADataSet: TDataSet;
  const ARows: Integer);
var
  LFor: Integer;
begin
  for LFor := 1 to ARows do
  begin
    ADataSet.Append;
    ADataSet.FieldByName(cOWNKEY).AsInteger := LFor;
    ADataSet.FieldByName(cKEYFIELD).AsInteger := 100 + LFor;
    ADataSet.FieldByName(cTAG).AsString := 'T' + IntToStr(LFor);
    ADataSet.Post;
  end;
end;

/// Rows that were already applied once - marker back to -1, the way
/// ApplyInserter leaves them - and then edited again, so DoBeforePost stamps
/// Integer(dsEdit). That is the only state ApplyUpdater looks at.
procedure TTestApplyLoops.SeedPendingEdits(const ADataSet: TDataSet;
  const ARows: Integer);
var
  LSaved: TDataSetNotifyEvent;
begin
  SeedPendingInserts(ADataSet, ARows);
  LSaved := ADataSet.BeforePost;
  ADataSet.BeforePost := nil;
  try
    ADataSet.First;
    while not ADataSet.Eof do
    begin
      ADataSet.Edit;
      ADataSet.Fields[0].AsInteger := cAPPLIED;
      ADataSet.Post;
      ADataSet.Next;
    end;
  finally
    ADataSet.BeforePost := LSaved;
  end;
  ADataSet.First;
  while not ADataSet.Eof do
  begin
    ADataSet.Edit;
    ADataSet.FieldByName(cTAG).AsString := 'E';
    ADataSet.Post;
    ADataSet.Next;
  end;
end;

function TTestApplyLoops.Markers(const ADataSet: TDataSet): string;
begin
  Result := '';
  ADataSet.Filtered := False;
  ADataSet.Filter := '';
  ADataSet.First;
  while not ADataSet.Eof do
  begin
    Result := Result + IntToStr(ADataSet.Fields[0].AsInteger) + ',';
    ADataSet.Next;
  end;
end;

function TTestApplyLoops.MinusOnes(const ADataSet: TDataSet): Integer;
begin
  Result := 0;
  ADataSet.Filtered := False;
  ADataSet.Filter := '';
  ADataSet.First;
  while not ADataSet.Eof do
  begin
    if ADataSet.Fields[0].AsInteger = cAPPLIED then
      Inc(Result);
    ADataSet.Next;
  end;
end;

// ---------------------------------------------------------------------------
// The field the filter names is the field the body writes
// ---------------------------------------------------------------------------

procedure TTestApplyLoops.InternalFieldIsFieldZero_FDMemTable;
var
  LTable: TFDMemTable;
  LA: TFDMemTableAdapter<TAitMid>;
begin
  LTable := TFDMemTable.Create(nil);
  try
    LA := TFDMemTableAdapter<TAitMid>.Create(FConn, LTable, -1, nil);
    try
      Assert.AreEqual(cInternalField, LTable.Fields[0].FieldName,
        'the six loops filter by NAME and write by INDEX 0; if those are not ' +
        'the same field the guard is false for every row and the loop spins');
    finally
      LA.Free;
    end;
  finally
    LTable.Free;
  end;
end;

procedure TTestApplyLoops.InternalFieldIsFieldZero_ClientDataSet;
var
  LCds: TClientDataSet;
  LA: TClientDataSetAdapter<TAitMid>;
begin
  LCds := TClientDataSet.Create(nil);
  try
    LA := TClientDataSetAdapter<TAitMid>.Create(FConn, LCds, -1, nil);
    try
      Assert.AreEqual(cInternalField, LCds.Fields[0].FieldName,
        'the ClientDataSet family must place the internal field at 0 too');
    finally
      LA.Free;
    end;
  finally
    LCds.Free;
  end;
end;

procedure TTestApplyLoops.InternalFieldIsFieldZero_RestClient;
var
  LTable: TFDMemTable;
  LA: TRESTFDMemTableAdapter<TAitMid>;
begin
  LTable := TFDMemTable.Create(nil);
  try
    LA := TRESTFDMemTableAdapter<TAitMid>.Create(FRest, LTable, -1, nil);
    try
      Assert.AreEqual(cInternalField, LTable.Fields[0].FieldName,
        'the REST client builds its dataset through the same Bind call; ' +
        'measured here rather than inferred from the local family');
    finally
      LA.Free;
    end;
  finally
    LTable.Free;
  end;
end;

procedure TTestApplyLoops.InternalFieldIsFieldZero_NestedDataSet;
var
  LTable: TFDMemTable;
  LA: TFDMemTableAdapter<TNestedParent>;
  LNested: TDataSet;
begin
  LTable := TFDMemTable.Create(nil);
  try
    LA := TFDMemTableAdapter<TNestedParent>.Create(FConn, LTable, -1, nil);
    try
      LNested := (LTable.FieldByName('items') as TDataSetField).NestedDataSet;
      Assert.AreEqual(cInternalField, LTable.Fields[0].FieldName,
        'the owner of a nested dataset column must still hold it at 0');
      Assert.AreEqual(cInternalField, LNested.Fields[0].FieldName,
        'a nested dataset gets its fields from a SECOND, recursive call to ' +
        'TBind.SetInternalInitFieldDefsObjectClass; it must land at 0 as well');
    finally
      LA.Free;
    end;
  finally
    LTable.Free;
  end;
end;

procedure TTestApplyLoops.InternalFieldIsFieldZero_WithCalcAndAggregateFields;
var
  LTable: TFDMemTable;
  LA: TFDMemTableAdapter<TFsShapes>;
begin
  LTable := TFDMemTable.Create(nil);
  try
    LA := TFDMemTableAdapter<TFsShapes>.Create(FConn, LTable, -1, nil);
    try
      // TBind.SetInternalInitFieldDefsObjectClass moves the internal field to
      // 0 and only THEN adds the calc and aggregate fields, so this is the
      // shape most likely to displace it.
      Assert.AreEqual(cInternalField, LTable.Fields[0].FieldName,
        'fields created AFTER the internal field must not displace it');
      Assert.AreEqual(fkInternalCalc, LTable.Fields[3].FieldKind,
        'the fixture must really produce a calculated field, otherwise the ' +
        'assertion above proves nothing');
      Assert.AreEqual(1, LTable.AggFields.Count,
        'the fixture must really produce an aggregate field');
    finally
      LA.Free;
    end;
  finally
    LTable.Free;
  end;
end;

procedure TTestApplyLoops.InternalFieldIsFieldZero_AfterAddLookupField;
var
  LTable: TFDMemTable;
  LLkTable: TFDMemTable;
  LA: TFDMemTableAdapter<TFsShapes>;
  LLookup: TFDMemTableAdapter<TFsLookup>;
begin
  LTable := TFDMemTable.Create(nil);
  LLkTable := TFDMemTable.Create(nil);
  try
    LA := TFDMemTableAdapter<TFsShapes>.Create(FConn, LTable, -1, nil);
    LLookup := TFDMemTableAdapter<TFsLookup>.Create(FConn, LLkTable, -1, nil);
    try
      // TDataSetBaseAdapter<M>.AddLookupField closes the dataset, adds a field
      // and reopens it - the one public API that adds a field after the
      // adapter is built.
      LA.AddLookupField('LKDESC', 'fskey', LLookup, 'lkkey', 'lkname',
                        'Lookup');
      Assert.AreEqual(cInternalField, LTable.Fields[0].FieldName,
        'a lookup field added after construction must not displace it');
      Assert.AreEqual(fkLookup, LTable.Fields[4].FieldKind,
        'the fixture must really add a lookup field');
    finally
      LLookup.Free;
      LA.Free;
    end;
  finally
    LLkTable.Free;
    LTable.Free;
  end;
end;

procedure TTestApplyLoops.InternalFieldIsFieldZero_AfterCloseAndReopen;
var
  LTable: TFDMemTable;
  LCds: TClientDataSet;
  LA: TFDMemTableAdapter<TAitMid>;
  LB: TClientDataSetAdapter<TAitMid>;
begin
  LTable := TFDMemTable.Create(nil);
  LCds := TClientDataSet.Create(nil);
  try
    LA := TFDMemTableAdapter<TAitMid>.Create(FConn, LTable, -1, nil);
    LB := TClientDataSetAdapter<TAitMid>.Create(FConn, LCds, -1, nil);
    try
      LTable.Close;
      LTable.Open;
      LCds.Close;
      LCds.CreateDataSet;
      Assert.AreEqual(cInternalField, LTable.Fields[0].FieldName,
        'reopening must not rebuild the field list in another order');
      Assert.AreEqual(cInternalField, LCds.Fields[0].FieldName,
        'the two families reopen differently; measured on both');
    finally
      LB.Free;
      LA.Free;
    end;
  finally
    LCds.Free;
    LTable.Free;
  end;
end;

procedure TTestApplyLoops.SecondAdapterOverTheSameDataSet_RefusesToBuild;
var
  LTable: TFDMemTable;
  LA: TFDMemTableAdapter<TAitMid>;
begin
  LTable := TFDMemTable.Create(nil);
  try
    LA := TFDMemTableAdapter<TAitMid>.Create(FConn, LTable, -1, nil);
    try
      // TFieldSingleton.AddField does not check whether the internal field
      // already exists, so the only thing standing between a dataset and TWO
      // fields named InternalField is the component-name clash. Measured, not
      // assumed: a dataset cannot reach the loops carrying a duplicate.
      Assert.WillRaise(
        procedure
        begin
          TFDMemTableAdapter<TAitMid>.Create(FConn, LTable, -1, nil).Free;
        end,
        EComponentError,
        'a second adapter over the same dataset must be refused; if this ' +
        'ever starts succeeding, field 0 is no longer guaranteed to be the ' +
        'field the filter selects');
    finally
      LA.Free;
    end;
  finally
    LTable.Free;
  end;
end;

procedure TTestApplyLoops.InternalFieldCarriesTheMinusOneDefault;
var
  LTable: TFDMemTable;
  LA: TFDMemTableAdapter<TAitMid>;
begin
  LTable := TFDMemTable.Create(nil);
  try
    LA := TFDMemTableAdapter<TAitMid>.Create(FConn, LTable, -1, nil);
    try
      // WHICH method writes this default is a question the code answered two
      // different ways. TBind.SetDataDictionary only walks columns that are
      // MAPPED and carry a Dictionary attribute, and the internal field is
      // neither - it is created and defaulted by
      // TBind.SetInternalInitFieldDefsObjectClass. TAitMid declares no
      // Dictionary at all, so under this fixture SetDataDictionary writes
      // nothing whatsoever and the default below can only have come from the
      // other method.
      Assert.AreEqual('-1', LTable.Fields[0].DefaultExpression,
        'the internal field must carry the -1 default; a row being typed has ' +
        'not reached DoBeforePost yet, and this default is the only thing ' +
        'that keeps it out of both Apply* filters');
      Assert.IsFalse(LTable.Fields[0].Visible,
        'and it must stay invisible - it is not a column of the entity');
    finally
      LA.Free;
    end;
  finally
    LTable.Free;
  end;
end;

// ---------------------------------------------------------------------------
// The six loops terminate on the shipped path
// ---------------------------------------------------------------------------

/// <summary> Builds the adapter over the REAL component, seeds ARows rows the
///  operator typed and never applied, and drives the SHIPPED entry point -
///  ApplyInternal, which disables the dataset events and only then runs
///  ApplyInserter and ApplyUpdater. Every row must come back marked applied
///  and no row may be lost. </summary>
procedure TTestApplyLoops.ApplyOverFDMemTable(const ARows: Integer);
var
  LTable: TWatchedMemTable;
  LA: TFDMemTableAdapter<TAitMid>;
begin
  LTable := TWatchedMemTable.Create(nil);
  try
    LA := TFDMemTableAdapter<TAitMid>.Create(FConn, LTable, -1, nil);
    try
      SeedPendingInserts(LTable, ARows);
      LTable.Arm(Budget(ARows));
      TApplyAccess<TAitMid>.Internal(LA);
      LTable.Arm(0);
      Assert.AreEqual(ARows, MinusOnes(LTable),
        'every pending row must come back marked applied; anything else ' +
        'means the loop stopped early or the marker did not survive Post');
      Assert.AreEqual(ARows, LTable.RecordCount,
        'no row may be lost or invented by the walk');
    finally
      LA.Free;
    end;
  finally
    LTable.Free;
  end;
end;

procedure TTestApplyLoops.ApplyOverClientDataSet(const ARows: Integer);
var
  LCds: TWatchedClientDataSet;
  LA: TClientDataSetAdapter<TAitMid>;
begin
  LCds := TWatchedClientDataSet.Create(nil);
  try
    LA := TClientDataSetAdapter<TAitMid>.Create(FConn, LCds, -1, nil);
    try
      SeedPendingInserts(LCds, ARows);
      LCds.Arm(Budget(ARows));
      TApplyAccess<TAitMid>.Internal(LA);
      LCds.Arm(0);
      Assert.AreEqual(ARows, MinusOnes(LCds),
        'the ClientDataSet family must terminate and clear every row too');
      Assert.AreEqual(ARows, LCds.RecordCount,
        'no row may be lost or invented by the walk');
    finally
      LA.Free;
    end;
  finally
    LCds.Free;
  end;
end;

/// <summary> TRESTDataSetAdapter<M>.ApplyInserter is the one of the six that
///  walks on `not Eof`; the field-0 counter is what bounds it, because Eof is
///  not virtual and cannot be counted. </summary>
procedure TTestApplyLoops.ApplyOverRestFDMemTable(const ARows: Integer);
var
  LTable: TWatchedMemTable;
  LA: TRESTFDMemTableAdapter<TAitMid>;
begin
  LTable := TWatchedMemTable.Create(nil);
  try
    LA := TRESTFDMemTableAdapter<TAitMid>.Create(FRest, LTable, -1, nil);
    try
      SeedPendingInserts(LTable, ARows);
      LTable.Arm(Budget(ARows));
      TApplyAccess<TAitMid>.Internal(LA);
      LTable.Arm(0);
      Assert.AreEqual(ARows, MinusOnes(LTable),
        'the REST FDMemTable family must terminate and clear every row too');
      Assert.AreEqual(ARows, LTable.RecordCount,
        'no row may be lost or invented by the walk');
    finally
      LA.Free;
    end;
  finally
    LTable.Free;
  end;
end;

/// <summary> The FOURTH ApplyInternal. It shares its two loops with
///  TRESTFDMemTableAdapter<M> - both inherit them from TRESTDataSetAdapter<M> -
///  but it owns its own ApplyInternal, and therefore its own
///  DisableDataSetEvents. Nothing else in the repository drives it: every
///  other fixture that builds a TRESTClientDataSetAdapter reaches for
///  OpenWhereInternal, DeleteDataSetChilds or RefreshRecordInternal. Without
///  this runner the note on that method would name a test that does not
///  exercise it. </summary>
procedure TTestApplyLoops.ApplyOverRestClientDataSet(const ARows: Integer);
var
  LCds: TWatchedClientDataSet;
  LA: TRESTClientDataSetAdapter<TAitMid>;
begin
  LCds := TWatchedClientDataSet.Create(nil);
  try
    LA := TRESTClientDataSetAdapter<TAitMid>.Create(FRest, LCds, -1, nil);
    try
      SeedPendingInserts(LCds, ARows);
      LCds.Arm(Budget(ARows));
      TApplyAccess<TAitMid>.Internal(LA);
      LCds.Arm(0);
      Assert.AreEqual(ARows, MinusOnes(LCds),
        'the REST ClientDataSet family must terminate and clear every row too');
      Assert.AreEqual(ARows, LCds.RecordCount,
        'no row may be lost or invented by the walk');
    finally
      LA.Free;
    end;
  finally
    LCds.Free;
  end;
end;

procedure TTestApplyLoops.FDMemTable_ApplyInternal_ClearsEveryPendingRow;
begin
  ApplyOverFDMemTable(cROWS);
end;

procedure TTestApplyLoops.FDMemTable_ApplyInternal_WithOneRow;
begin
  ApplyOverFDMemTable(1);
end;

procedure TTestApplyLoops.FDMemTable_ApplyInternal_WithNoRows;
begin
  ApplyOverFDMemTable(0);
end;

procedure TTestApplyLoops.ClientDataSet_ApplyInternal_ClearsEveryPendingRow;
begin
  ApplyOverClientDataSet(cROWS);
end;

procedure TTestApplyLoops.ClientDataSet_ApplyInternal_WithOneRow;
begin
  ApplyOverClientDataSet(1);
end;

procedure TTestApplyLoops.ClientDataSet_ApplyInternal_WithNoRows;
begin
  ApplyOverClientDataSet(0);
end;

procedure TTestApplyLoops.Rest_ApplyInternal_ClearsEveryPendingRow;
begin
  ApplyOverRestFDMemTable(cROWS);
end;

procedure TTestApplyLoops.Rest_ApplyInternal_WithOneRow;
begin
  ApplyOverRestFDMemTable(1);
end;

procedure TTestApplyLoops.Rest_ApplyInternal_WithNoRows;
begin
  ApplyOverRestFDMemTable(0);
end;

procedure TTestApplyLoops.RestClientDataSet_ApplyInternal_ClearsEveryPendingRow;
begin
  ApplyOverRestClientDataSet(cROWS);
end;

procedure TTestApplyLoops.RestClientDataSet_ApplyInternal_WithOneRow;
begin
  ApplyOverRestClientDataSet(1);
end;

procedure TTestApplyLoops.RestClientDataSet_ApplyInternal_WithNoRows;
begin
  ApplyOverRestClientDataSet(0);
end;

procedure TTestApplyLoops.MixedMarkers_ApplyInternal_ClearsEveryPendingRowAndKeepsKeys;
var
  LTable: TWatchedMemTable;
  LA: TFDMemTableAdapter<TAitMid>;
  LSaved: TDataSetNotifyEvent;
  LFor: Integer;
begin
  LTable := TWatchedMemTable.Create(nil);
  try
    LA := TFDMemTableAdapter<TAitMid>.Create(FConn, LTable, -1, nil);
    try
      // The realistic grid: pending inserts, pending edits and already applied
      // rows interleaved, so each filter selects a SPARSE subset of the table
      // rather than the whole of it.
      SeedPendingInserts(LTable, cROWS);
      LSaved := LTable.BeforePost;
      LTable.BeforePost := nil;
      try
        LTable.First;
        LFor := 1;
        while not LTable.Eof do
        begin
          if LFor mod 3 <> 1 then
          begin
            LTable.Edit;
            LTable.Fields[0].AsInteger := cAPPLIED;
            LTable.Post;
          end;
          Inc(LFor);
          LTable.Next;
        end;
      finally
        LTable.BeforePost := LSaved;
      end;
      LTable.First;
      LFor := 1;
      while not LTable.Eof do
      begin
        if LFor mod 3 = 0 then
        begin
          LTable.Edit;
          LTable.FieldByName(cTAG).AsString := 'E';
          LTable.Post;
        end;
        Inc(LFor);
        LTable.Next;
      end;
      Assert.AreEqual('3,-1,2,3,-1,2,', Markers(LTable),
        'the fixture must really produce the three states, otherwise the run ' +
        'below is the uniform case all over again');

      LTable.Arm(Budget(cROWS));
      TApplyAccess<TAitMid>.Internal(LA);
      LTable.Arm(0);

      Assert.AreEqual(cROWS, MinusOnes(LTable),
        'a sparse filtered set must be walked to the end just the same');
      LTable.First;
      LFor := 1;
      while not LTable.Eof do
      begin
        Assert.AreEqual(100 + LFor, LTable.FieldByName(cKEYFIELD).AsInteger,
          'no row may have its foreign key touched by the apply loops');
        Inc(LFor);
        LTable.Next;
      end;
    finally
      LA.Free;
    end;
  finally
    LTable.Free;
  end;
end;

// ---------------------------------------------------------------------------
// What makes them terminate. These call the protected loop DIRECTLY, which no
// shipped caller does - all four ApplyInternal disable the events first. The
// point is to put a number on what that caller is protecting.
// ---------------------------------------------------------------------------

procedure TTestApplyLoops.FDMemTable_ApplyUpdater_WithBeforePostLive_NeverTerminates;
var
  LTable: TWatchedMemTable;
  LA: TFDMemTableAdapter<TAitMid>;
begin
  LTable := TWatchedMemTable.Create(nil);
  try
    LA := TFDMemTableAdapter<TAitMid>.Create(FConn, LTable, -1, nil);
    try
      SeedPendingEdits(LTable, cROWS);
      LTable.Arm(Budget(cROWS));
      Assert.WillRaise(
        procedure
        begin
          TApplyAccess<TAitMid>.Updater(LA);
        end,
        EApplyRunaway,
        'with DoBeforePost live it rewrites the marker the body just cleared ' +
        'back to Integer(dsEdit), which is the value this filter selects on, ' +
        'so the row never leaves the filtered set');
      LTable.Arm(0);
    finally
      LA.Free;
    end;
  finally
    LTable.Free;
  end;
end;

procedure TTestApplyLoops.ClientDataSet_ApplyUpdater_WithBeforePostLive_NeverTerminates;
var
  LCds: TWatchedClientDataSet;
  LA: TClientDataSetAdapter<TAitMid>;
begin
  LCds := TWatchedClientDataSet.Create(nil);
  try
    LA := TClientDataSetAdapter<TAitMid>.Create(FConn, LCds, -1, nil);
    try
      SeedPendingEdits(LCds, cROWS);
      LCds.Arm(Budget(cROWS));
      Assert.WillRaise(
        procedure
        begin
          TApplyAccess<TAitMid>.Updater(LA);
        end,
        EApplyRunaway,
        'the ClientDataSet family behaves the same - measured, not inferred ' +
        'from the FDMemTable one');
      LCds.Arm(0);
    finally
      LA.Free;
    end;
  finally
    LCds.Free;
  end;
end;

procedure TTestApplyLoops.Rest_ApplyUpdater_WithBeforePostLive_NeverTerminates;
var
  LTable: TWatchedMemTable;
  LA: TRESTFDMemTableAdapter<TAitMid>;
begin
  LTable := TWatchedMemTable.Create(nil);
  try
    LA := TRESTFDMemTableAdapter<TAitMid>.Create(FRest, LTable, -1, nil);
    try
      SeedPendingEdits(LTable, cROWS);
      LTable.Arm(Budget(cROWS));
      Assert.WillRaise(
        procedure
        begin
          TApplyAccess<TAitMid>.Updater(LA);
        end,
        EApplyRunaway,
        'the REST family behaves the same - measured, not inferred');
      LTable.Arm(0);
    finally
      LA.Free;
    end;
  finally
    LTable.Free;
  end;
end;

procedure TTestApplyLoops.RestClientDataSet_ApplyUpdater_WithBeforePostLive_NeverTerminates;
var
  LCds: TWatchedClientDataSet;
  LA: TRESTClientDataSetAdapter<TAitMid>;
begin
  LCds := TWatchedClientDataSet.Create(nil);
  try
    LA := TRESTClientDataSetAdapter<TAitMid>.Create(FRest, LCds, -1, nil);
    try
      SeedPendingEdits(LCds, cROWS);
      LCds.Arm(Budget(cROWS));
      Assert.WillRaise(
        procedure
        begin
          TApplyAccess<TAitMid>.Updater(LA);
        end,
        EApplyRunaway,
        'the fourth family behaves the same - measured, not inferred from ' +
        'the other three');
      LCds.Arm(0);
    finally
      LA.Free;
    end;
  finally
    LCds.Free;
  end;
end;

procedure TTestApplyLoops.ApplyInserter_WithBeforePostLive_LeavesTheRowMarkedEdit;
var
  LTable: TWatchedMemTable;
  LA: TFDMemTableAdapter<TAitMid>;
begin
  LTable := TWatchedMemTable.Create(nil);
  try
    LA := TFDMemTableAdapter<TAitMid>.Create(FConn, LTable, -1, nil);
    try
      SeedPendingInserts(LTable, cROWS);
      LTable.Arm(Budget(cROWS));
      // The asymmetry between the two loops, and the reason ApplyInserter is
      // NOT a hang: DoBeforePost rewrites the marker to Integer(dsEdit), and
      // this filter selects Integer(dsInsert), so the row does leave the set.
      // It terminates - and hands every just-inserted row to ApplyUpdater as
      // if the operator had edited it.
      TApplyAccess<TAitMid>.Inserter(LA);
      LTable.Arm(0);
      Assert.AreEqual(0, MinusOnes(LTable),
        'not one row may come back marked applied when the event is live');
      Assert.AreEqual('2,2,2,2,2,2,', Markers(LTable),
        'every row must come back carrying Integer(dsEdit) - the value ' +
        'DoBeforePost wrote over the -1 the loop body had just written');
    finally
      LA.Free;
    end;
  finally
    LTable.Free;
  end;
end;

procedure TTestApplyLoops.DisableDataSetEvents_UnhooksBeforePost;
var
  LTable: TFDMemTable;
  LA: TFDMemTableAdapter<TAitMid>;
begin
  LTable := TFDMemTable.Create(nil);
  try
    LA := TFDMemTableAdapter<TAitMid>.Create(FConn, LTable, -1, nil);
    try
      Assert.IsTrue(Assigned(LTable.BeforePost),
        'the adapter must install its own BeforePost, otherwise the rest of ' +
        'this test measures nothing');
      TApplyAccess<TAitMid>.MuteEvents(LA);
      try
        Assert.IsFalse(Assigned(LTable.BeforePost),
          'BeforePost must be unhooked - that single call is what keeps the ' +
          'six Apply* loops finite; TDataSetBaseAdapter<M>._FindEvents is ' +
          'the list that decides it');
      finally
        TApplyAccess<TAitMid>.UnmuteEvents(LA);
      end;
      Assert.IsTrue(Assigned(LTable.BeforePost),
        'and it must be handed back afterwards');
    finally
      LA.Free;
    end;
  finally
    LTable.Free;
  end;
end;

// ---------------------------------------------------------------------------
// The -1 is an integrity guard, not loop bookkeeping
// ---------------------------------------------------------------------------

procedure TTestApplyLoops.ApplyInserter_DoesNotRepointAChildRowOfAnotherMaster;
var
  LMasterTable: TWatchedMemTable;
  LChildTable: TFDMemTable;
  LMaster: TFDMemTableAdapter<TAitRoot>;
  LChild: TFDMemTableAdapter<TAitMid>;
  LSaved: TDataSetNotifyEvent;
  LForeign: Integer;
  LStamped: Integer;
  LKey: Integer;
  LGen: IDBConnection;
begin
  // TDMLCommandInserter only asks the generator - and therefore only sets
  // ExistSequence, which is what gates SetAutoIncValueChilds - when the row's
  // own key is still unset. So this connection hands out ONE row carrying the
  // key the database is pretending to generate.
  LGen := TRowsConnection.Create(dnSQLite, 1,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add('GEN', ftInteger);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName('GEN').AsInteger := cNEWKEY;
    end,
    'generator');
  LMasterTable := TWatchedMemTable.Create(nil);
  LChildTable := TFDMemTable.Create(nil);
  try
    // The LOCAL family on purpose: TFDMemTableAdapter<M>.ApplyInserter reaches
    // SetAutoIncValueChilds whenever the entity has a sequence, while
    // TRESTDataSetAdapter<M>.ApplyInserter reaches it only when the server
    // answered with a `params` element - measured, and out of reach of a
    // double that answers nothing.
    LMaster := TFDMemTableAdapter<TAitRoot>.Create(LGen, LMasterTable, -1,
                 nil);
    LChild := TFDMemTableAdapter<TAitMid>.Create(LGen, LChildTable, -1,
                LMaster);
    try
      // Key still unset: this is the master the database has not seen yet.
      LMasterTable.Append;
      LMasterTable.FieldByName(cKEYFIELD).AsInteger := 0;
      LMasterTable.FieldByName(cTAG).AsString := 'ROOT';
      LMasterTable.Post;

      // Two children the operator has just typed under this master...
      LChildTable.Append;
      LChildTable.FieldByName(cOWNKEY).AsInteger := 1;
      LChildTable.FieldByName(cKEYFIELD).AsInteger := 0;
      LChildTable.FieldByName(cTAG).AsString := 'C1';
      LChildTable.Post;
      LChildTable.Append;
      LChildTable.FieldByName(cOWNKEY).AsInteger := 2;
      LChildTable.FieldByName(cKEYFIELD).AsInteger := 0;
      LChildTable.FieldByName(cTAG).AsString := 'C2';
      LChildTable.Post;
      // ...and one row that is ALREADY SAVED and belongs to a DIFFERENT
      // master. In the REST client the child memtable holds the children of
      // every master the listing brought back.
      LChildTable.Append;
      LChildTable.FieldByName(cOWNKEY).AsInteger := 3;
      LChildTable.FieldByName(cKEYFIELD).AsInteger := cFOREIGN;
      LChildTable.FieldByName(cTAG).AsString := 'C3';
      LChildTable.Post;
      LSaved := LChildTable.BeforePost;
      LChildTable.BeforePost := nil;
      try
        LChildTable.Edit;
        LChildTable.Fields[0].AsInteger := cAPPLIED;
        LChildTable.Post;
      finally
        LChildTable.BeforePost := LSaved;
      end;

      LMasterTable.Arm(Budget(1));
      TApplyAccess<TAitRoot>.Internal(LMaster);
      LMasterTable.Arm(0);
      // Read the key back rather than predict it: the generator command
      // derives the next value from what the connection answered, and the
      // arithmetic is not what this test is about.
      LKey := LMasterTable.FieldByName(cKEYFIELD).AsInteger;
      Assert.IsTrue(LKey > 0,
        'the master must have received a generated key, otherwise ' +
        'SetAutoIncValueChilds had nothing to propagate and the assertions ' +
        'below would pass for the wrong reason');
      Assert.AreNotEqual(cFOREIGN, LKey,
        'the generated key must differ from the foreign one, otherwise the ' +
        'test cannot tell a re-parented row from an untouched one');

      LForeign := 0;
      LStamped := 0;
      LChildTable.First;
      while not LChildTable.Eof do
      begin
        if LChildTable.FieldByName(cKEYFIELD).AsInteger = cFOREIGN then
          Inc(LForeign);
        if LChildTable.FieldByName(cKEYFIELD).AsInteger = LKey then
          Inc(LStamped);
        LChildTable.Next;
      end;
      Assert.AreEqual(2, LStamped,
        'the two pending children must receive the key of their master');
      Assert.AreEqual(1, LForeign,
        'the already saved row belongs to ANOTHER master; stamping the new ' +
        'key on it would silently re-parent someone else data. What stops ' +
        'that is the -1 the loop body writes, read back by ' +
        'TDataSetBaseAdapter<M>._IsPendingInsertRow');
    finally
      LChild.Free;
      LMaster.Free;
    end;
  finally
    LChildTable.Free;
    LMasterTable.Free;
    LGen := nil;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestApplyLoops);

end.
