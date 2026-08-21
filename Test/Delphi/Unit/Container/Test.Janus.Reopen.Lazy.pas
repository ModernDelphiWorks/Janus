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

{ @abstract(Janus Framework - the reopen, and the lazy path it brings back to
  life. Issue #248.)

  WHAT IS UNDER TEST

  TDataSetBaseAdapter<M>.EnsureOpen, called at the head of every Open*Internal
  of the four dataset adapters, and the two Closes that were changed on top of
  it: TContainerDataSet<M>.Close and TManagerDataSet.Close<T>, which used to
  call EmptyDataSet and now close for real.

  THE NUMBER THAT JUSTIFIES THE CHANGE IS A CURSOR COUNT, NOT A STATE FLAG

  TDataSetAdapter<M>.LoadLazy uses FOrmDataSet.Active as its "already loaded"
  flag - `if FOrmDataSet.Active then Exit`. TFDMemTableAdapter<M>.Create opens
  the dataset and the old Close never closed it, so that flag was never false
  and the lazy branch never ran. #246 measured the consequence: ZERO cursors
  requested, ever. A test that only calls LoadLazy and looks at a boolean would
  not have caught that, because the boolean was never the problem - nobody was
  asking the connection for anything.

  So every lazy test here counts cursors, through TRowsConnection.CreateCount,
  which is the number of times the ORM asked the connection for a dataset.
  What both pin is the DELTA across the LoadLazy call, never the running total:
  Lazy_WhileTheDataSetIsOpenNoCursorIsEverRequested pins the old delta (0) and
  Lazy_AfterTheContainerCloseLoadLazyRequestsACursor the new one (EXACTLY 1, by
  equality and not by "more than before" - a lazy load that opened three cursors
  for one child would satisfy an inequality and is a defect). Both live in this
  same fixture, so the two numbers can never drift apart.

  NO SYMMETRY IS ASSUMED BETWEEN THE FOUR ADAPTERS

  #246 exercised the TFDMemTable family only. Everything about
  TClientDataSetAdapter, TRESTFDMemTableAdapter and TRESTClientDataSetAdapter is
  measured here on its own instance, and where the families disagree the test
  says so instead of averaging them - see
  Rows_ABareReopenBringsBackNothingOnFDMemTableAndEverythingOnClientDataSet and
  Lazy_TheRestFamilyGuardsTurnAwayAnOpenUnownedChild. That last one was
  Lazy_TheRestFamilyHasNoLazyAtAll until #251 filled in the two branches of
  TRESTDataSetAdapter<M>.LoadLazy; its numbers did not move, its explanation
  did, and the REST branches now have their own fixture in
  Janus.Tests.RESTfulDriver, Test.Janus.Rest.Lazy.

  WHAT IS DELIBERATELY NOT MEASURED HERE

  The by-id open of the two REST adapters is not driven to COMPLETION, because
  TInertRestConnection answers '[]' to every GET and a by-id GET deserialises
  into one object, so the session raises 'Error JSON to Object'. That raise
  lands after EnsureOpen, so those two legs assert which failure arrives - not
  the CheckBrowseMode one, and with the dataset open again - instead of
  asserting that none does. Written out rather than dropped, because the
  alternative was leaving two of the twelve EnsureOpen call sites with no test
  at all.

  How each of the four adapters USED to report the failed reopen. With
  EnsureOpen in place none of them fails any more, so the only way to measure it
  would be to remove EnsureOpen - which is a mutation run, not a test. #246 pins
  the one datum that survives: on TFDMemTableAdapter the failure arrived as
  `Exception | Cannot perform this operation on a closed dataset`, already
  re-wrapped by that adapter's own `except on E: Exception`.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

{ The dataset choice lives in Janus.inc, so a fixture that has to follow it
  must read it. Without this include the IFDEFs below are simply false and
  the fixture silently hard-codes one half of the choice again. }
{$INCLUDE ..\..\..\..\Source\Janus.inc}

unit Test.Janus.Reopen.Lazy;

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
  Janus.RestFactory.Interfaces,
  Janus.DataSet.Base.Adapter,
  Janus.RestDataSet.FDMemTable,
  Janus.RestDataSet.ClientDataSet,
  Janus.Container.DataSet.Interfaces,
  Janus.Container.FDMemTable,
  Janus.Container.ClientDataSet,
  Janus.Manager.DataSet,
  Janus.DML.Generator.SQLite,
  Test.Janus.Model.KeyOnly,
  Test.Janus.Model.AutoIncTree,
  Test.Janus.Cursor.Double,
  /// Only for TCloseAccess<M>, the same-family descendant that reaches the
  /// protected TDataSetBaseAdapter<M>.Close. That unit already ships it and a
  /// second copy would be a second thing to keep true.
  Test.Janus.Close.VsEmpty,
  /// Only for TInertRestConnection and the two REST crackers. Same reason.
  Test.Janus.MasterDetail.Link;

type
  /// <summary> Reaches the protected LoadLazy of the REST family, and the two
  ///  Open*Internal entry points that Test.Janus.MasterDetail.Link's crackers do
  ///  not cover. THERE ARE THREE EnsureOpen CALL SITES PER ADAPTER - one per
  ///  Open*Internal - and a call site no test drives is a call site no mutation
  ///  can redden. </summary>
  TRestLazyCrack<M: class, constructor> = class(TRESTFDMemTableAdapter<M>)
  public
    class procedure Lazy(const AAdapter: TRESTFDMemTableAdapter<M>;
      const AOwner: M);
    class procedure OpenID(const AAdapter: TRESTFDMemTableAdapter<M>;
      const AID: Integer);
    class procedure OpenSQL(const AAdapter: TRESTFDMemTableAdapter<M>);
  end;

  /// <summary> The same two entry points on the REST ClientDataSet adapter.
  /// </summary>
  TRestCdsOpenCrack<M: class, constructor> = class(TRESTClientDataSetAdapter<M>)
  public
    class procedure OpenID(const AAdapter: TRESTClientDataSetAdapter<M>;
      const AID: Integer);
    class procedure OpenSQL(const AAdapter: TRESTClientDataSetAdapter<M>);
  end;

  [TestFixture]
  TTestReopenLazy = class
  private
    FRows: TRowsConnection;
    FConn: IDBConnection;
    FInert: TInertRestConnection;
    FRest: IRESTConnection;
    FTable: TFDMemTable;
    FCont: IContainerDataSet<TKeyOnly>;
    FCds: TClientDataSet;
    FCdsCont: IContainerDataSet<TKeyOnly>;
    FRootTable: TFDMemTable;
    FMidTable: TFDMemTable;
    FRoot: IContainerDataSet<TAitRoot>;
    FMid: IContainerDataSet<TAitMid>;
    /// TManagerDataSet.ResolverDataSetType only accepts the dataset the
    /// configured directive names, so the manager's table follows the
    /// configuration rather than hard-coding one half of it. See #223.
    FManagerTable: TDataSet;
    FManager: TManagerDataSet;
    FRestMemTable: TFDMemTable;
    FRestMem: TRESTFDMemTableAdapter<TKeyOnly>;
    FRestCds: TClientDataSet;
    FRestCdsAdapter: TRESTClientDataSetAdapter<TKeyOnly>;
    FIdMemTable: TFDMemTable;
    FIdMem: IContainerDataSet<TAitRoot>;
    FIdCds: TClientDataSet;
    FIdCdsCont: IContainerDataSet<TAitRoot>;
    procedure BuildConnection(const ARows: Integer);
    procedure BuildFlat(const ARows: Integer);
    procedure BuildCds(const ARows: Integer);
    procedure BuildTree(const ARows: Integer; const ALinked: Boolean);
    procedure BuildManager(const ARows: Integer);
    procedure BuildIdPair;
    procedure BuildRestMem;
    procedure BuildRestCds;
    function Capture(const AProc: TProc): string;
    function FieldHandles(const ADataSet: TDataSet): TArray<TField>;
    function SameHandles(const A, B: TArray<TField>): Boolean;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // -----------------------------------------------------------------------
    // The lazy path - the cursor count that justifies the whole change
    // -----------------------------------------------------------------------

    /// The OLD number, and it is still the right one while the dataset is open:
    /// LoadLazy exits on its Active gate and asks the connection for nothing.
    [Test]
    procedure Lazy_WhileTheDataSetIsOpenNoCursorIsEverRequested;
    /// The NEW number, measured in the same fixture so the two cannot drift:
    /// after TContainerDataSet<M>.Close the gate is open, LoadLazy runs, and
    /// the connection is asked for a cursor. #246 measured 0 here.
    [Test]
    procedure Lazy_AfterTheContainerCloseLoadLazyRequestsACursor;
    /// A cursor being asked for is not the same as rows arriving. This measures
    /// that the rows LoadLazy asked for actually land in the child dataset.
    [Test]
    procedure Lazy_TheRowsAskedForReachTheChildDataSet;
    /// The full round trip: LoadLazy(nil) unloads through the protected Close -
    /// the path that already closed for real before #248, and the only one -
    /// and LoadLazy(owner) loads again. The second half used to be impossible.
    [Test]
    procedure Lazy_UnloadThenLoadIsARoundTripThatUsedToBeImpossible;
    /// The REST family still does not join in HERE, but the reason changed
    /// with #251: TRESTDataSetAdapter<M>.LoadLazy is no longer an empty body,
    /// it has both branches, and what turns this particular adapter away is
    /// its two GUARDS. Measured, not assumed from the shape of the other
    /// family. The REST branches themselves are proved in
    /// Janus.Tests.RESTfulDriver, Test.Janus.Rest.Lazy.
    [Test]
    procedure Lazy_TheRestFamilyGuardsTurnAwayAnOpenUnownedChild;

    // -----------------------------------------------------------------------
    // Close now closes - the deliberate behaviour change
    // -----------------------------------------------------------------------

    /// TContainerDataSet<M>.Close over the FDMemTable family.
    [Test]
    procedure Close_TheContainerNowLeavesTheFDMemTableClosed;
    /// The same, over the ClientDataSet family, which #246 never exercised.
    [Test]
    procedure Close_TheContainerNowLeavesTheClientDataSetClosed;
    /// TManagerDataSet.Close<T>, the manager's half of the same change.
    [Test]
    procedure Close_TheManagerNowLeavesTheDataSetClosed;
    /// And the old behaviour is still available under its honest name: both
    /// EmptyDataSet entry points clear the rows and leave the dataset OPEN.
    [Test]
    procedure Close_EmptyDataSetStillClearsWithoutClosing;
    /// A master Close now reaches the child through DoBeforeClose and leaves it
    /// CLOSED. Under the old Close it went through EmptyDataSetChilds and the
    /// child stayed open and empty.
    [Test]
    procedure Close_CascadesARealCloseToTheChild;

    // -----------------------------------------------------------------------
    // Reopening after a genuine close - one measurement per adapter
    // -----------------------------------------------------------------------

    [Test]
    procedure Reopen_FDMemTable_TheContainerOpensAgainAfterAGenuineClose;
    [Test]
    procedure Reopen_ClientDataSet_TheContainerOpensAgainAfterAGenuineClose;
    [Test]
    procedure Reopen_RestFDMemTable_OpenWhereWorksAfterAGenuineClose;
    [Test]
    procedure Reopen_RestClientDataSet_OpenWhereWorksAfterAGenuineClose;
    /// The Open-by-id leg of the two local adapters, which needs a
    /// single-column key and therefore its own pair of containers.
    [Test]
    procedure Reopen_TheIdPathComesBackOnBothLocalFamilies;

    // -----------------------------------------------------------------------
    // What the reopen brings back, and what it does not
    // -----------------------------------------------------------------------

    /// The two families disagree, and the difference costs the adapters nothing
    /// because EnsureOpen is followed by EmptyDataSet on every call site. It is
    /// measured here so nobody reads the reopen as a way to preserve data.
    [Test]
    procedure Rows_ABareReopenBringsBackNothingOnFDMemTableAndEverythingOnClientDataSet;
    /// The TField objects are the same objects before the close, after it and
    /// after the reopen - on both families. This is the reason a bare Open is
    /// the whole fix: nothing was destroyed that Open would have to rebuild.
    [Test]
    procedure Fields_TheSameObjectsSurviveCloseAndReopen_BothFamilies;
  end;

implementation

const
  cROWS      = 3;
  cTREEROWS  = 2;
  cCLOSEDMSG = 'Cannot perform this operation on a closed dataset';

{ TRestLazyCrack<M> }

class procedure TRestLazyCrack<M>.Lazy(
  const AAdapter: TRESTFDMemTableAdapter<M>; const AOwner: M);
begin
  TRestLazyCrack<M>(AAdapter).LoadLazy(AOwner);
end;

class procedure TRestLazyCrack<M>.OpenID(
  const AAdapter: TRESTFDMemTableAdapter<M>; const AID: Integer);
begin
  TRestLazyCrack<M>(AAdapter).OpenIDInternal(AID);
end;

class procedure TRestLazyCrack<M>.OpenSQL(
  const AAdapter: TRESTFDMemTableAdapter<M>);
begin
  TRestLazyCrack<M>(AAdapter).OpenSQLInternal('');
end;

{ TRestCdsOpenCrack<M> }

class procedure TRestCdsOpenCrack<M>.OpenID(
  const AAdapter: TRESTClientDataSetAdapter<M>; const AID: Integer);
begin
  TRestCdsOpenCrack<M>(AAdapter).OpenIDInternal(AID);
end;

class procedure TRestCdsOpenCrack<M>.OpenSQL(
  const AAdapter: TRESTClientDataSetAdapter<M>);
begin
  TRestCdsOpenCrack<M>(AAdapter).OpenSQLInternal('');
end;

{ TTestReopenLazy }

procedure TTestReopenLazy.Setup;
begin
  FRows := nil;
  FConn := nil;
  FInert := nil;
  FRest := nil;
  FTable := nil;
  FCont := nil;
  FCds := nil;
  FCdsCont := nil;
  FRootTable := nil;
  FMidTable := nil;
  FRoot := nil;
  FMid := nil;
  FManagerTable := nil;
  FManager := nil;
  FRestMemTable := nil;
  FRestMem := nil;
  FRestCds := nil;
  FRestCdsAdapter := nil;
  FIdMemTable := nil;
  FIdMem := nil;
  FIdCds := nil;
  FIdCdsCont := nil;
end;

procedure TTestReopenLazy.TearDown;
begin
  FIdCdsCont := nil;
  FIdMem := nil;
  FreeAndNil(FIdCds);
  FreeAndNil(FIdMemTable);
  FreeAndNil(FRestCdsAdapter);
  FreeAndNil(FRestCds);
  FreeAndNil(FRestMem);
  FreeAndNil(FRestMemTable);
  FreeAndNil(FManager);
  FreeAndNil(FManagerTable);
  FMid := nil;
  FRoot := nil;
  FCdsCont := nil;
  FCont := nil;
  FreeAndNil(FMidTable);
  FreeAndNil(FRootTable);
  FreeAndNil(FCds);
  FreeAndNil(FTable);
  FRest := nil;
  FInert := nil;
  FConn := nil;
  FRows := nil;
end;

/// The connection double every flat fixture below shares. Two integer columns,
/// no association, so the only thing moving is the container itself.
procedure TTestReopenLazy.BuildConnection(const ARows: Integer);
begin
  FRows := TRowsConnection.Create(dnSQLite, ARows, KeyOnlySchema(),
             KeyOnlyRow(), 'reopen');
  FConn := FRows;
end;

procedure TTestReopenLazy.BuildFlat(const ARows: Integer);
begin
  if FConn = nil then
    BuildConnection(ARows);
  FTable := TFDMemTable.Create(nil);
  FCont := TContainerFDMemTable<TKeyOnly>.Create(FConn, FTable);
end;

procedure TTestReopenLazy.BuildCds(const ARows: Integer);
begin
  if FConn = nil then
    BuildConnection(ARows);
  FCds := TClientDataSet.Create(nil);
  FCdsCont := TContainerClientDataSet<TKeyOnly>.Create(FConn, FCds);
end;

procedure TTestReopenLazy.BuildManager(const ARows: Integer);
begin
  if FConn = nil then
    BuildConnection(ARows);
  {$IFDEF USECLIENTDATASET}
  FManagerTable := TClientDataSet.Create(nil);
  {$ELSE}
  FManagerTable := TFDMemTable.Create(nil);
  {$ENDIF}
  FManager := TManagerDataSet.Create(FConn);
  FManager.AddAdapter<TKeyOnly>(FManagerTable);
end;

/// Root plus mid, over a cursor wide enough for BOTH entities - Bind
/// .SetFieldToField reads every field of the TARGET dataset out of the cursor
/// by name, so a column the cursor does not have is 'Field <name> not found'.
/// ALinked = False builds the mid WITHOUT a master, which is what
/// TDataSetAdapter<M>.LoadLazy requires: it exits when FOwnerMasterObject is
/// already set.
procedure TTestReopenLazy.BuildTree(const ARows: Integer;
  const ALinked: Boolean);
begin
  FRows := TRowsConnection.Create(dnSQLite, ARows,
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
    'reopen-tree');
  FConn := FRows;
  FRootTable := TFDMemTable.Create(nil);
  FRoot := TContainerFDMemTable<TAitRoot>.Create(FConn, FRootTable);
  FMidTable := TFDMemTable.Create(nil);
  if ALinked then
    FMid := TContainerFDMemTable<TAitMid>.Create(FConn, FMidTable, FRoot.This)
  else
    FMid := TContainerFDMemTable<TAitMid>.Create(FConn, FMidTable);
end;

/// A TFDMemTable container and a TClientDataSet container over TAitRoot, whose
/// key is ONE column - which is what OpenIDInternal needs. Neither has a child
/// registered, so OpenDataSetChilds has nothing to walk and the only thing
/// under measurement is the adapter's own open path.
procedure TTestReopenLazy.BuildIdPair;
begin
  FRows := TRowsConnection.Create(dnSQLite, cROWS,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add('root_id', ftInteger);
      ADataSet.FieldDefs.Add('tag', ftString, 20);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName('root_id').AsInteger := 1 + AIndex;
      ADataSet.FieldByName('tag').AsString := 'R' + IntToStr(AIndex);
    end,
    'reopen-id');
  FConn := FRows;
  FIdMemTable := TFDMemTable.Create(nil);
  FIdMem := TContainerFDMemTable<TAitRoot>.Create(FConn, FIdMemTable);
  FIdCds := TClientDataSet.Create(nil);
  FIdCdsCont := TContainerClientDataSet<TAitRoot>.Create(FConn, FIdCds);
end;

/// The REST pair answers '[]' to every GET, so no row ever arrives. What the
/// REST legs measure is whether the adapter can be driven at all after a close,
/// and how many times it went to the connection - the REST analogue of a
/// cursor, counted by TInertRestConnection.ExecuteCount.
procedure TTestReopenLazy.BuildRestMem;
begin
  FInert := TInertRestConnection.Create;
  FRest := FInert;
  FRestMemTable := TFDMemTable.Create(nil);
  FRestMem := TRESTFDMemTableAdapter<TKeyOnly>.Create(FRest, FRestMemTable,
                -1, nil);
end;

procedure TTestReopenLazy.BuildRestCds;
begin
  FInert := TInertRestConnection.Create;
  FRest := FInert;
  FRestCds := TClientDataSet.Create(nil);
  FRestCdsAdapter := TRESTClientDataSetAdapter<TKeyOnly>.Create(FRest, FRestCds,
                       -1, nil);
end;

function TTestReopenLazy.Capture(const AProc: TProc): string;
begin
  Result := '';
  try
    AProc();
  except
    on E: Exception do
      Result := E.ClassName + ' | ' + E.Message;
  end;
end;

function TTestReopenLazy.FieldHandles(const ADataSet: TDataSet): TArray<TField>;
var
  LFor: Integer;
begin
  SetLength(Result, ADataSet.Fields.Count);
  for LFor := 0 to ADataSet.Fields.Count - 1 do
    Result[LFor] := ADataSet.Fields[LFor];
end;

function TTestReopenLazy.SameHandles(const A, B: TArray<TField>): Boolean;
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
// The lazy path
// ---------------------------------------------------------------------------

procedure TTestReopenLazy.Lazy_WhileTheDataSetIsOpenNoCursorIsEverRequested;
var
  LBefore: Integer;
begin
  BuildTree(cTREEROWS, False);
  FRoot.Open;
  Assert.AreEqual(cTREEROWS, FRootTable.RecordCount,
    'the master must really be holding rows, otherwise nothing is measured');
  Assert.IsTrue(FMidTable.Active,
    'TFDMemTableAdapter<M>.Create opens the child dataset, so the lazy gate is ' +
    'already shut before anybody calls anything');

  LBefore := FRows.CreateCount;
  FMid.LoadLazy(TAitMid(FRoot.This));

  Assert.AreEqual(LBefore, FRows.CreateCount,
    'LoadLazy exits on `if FOrmDataSet.Active then Exit` and asks the ' +
    'connection for NOTHING. This is the number #246 measured, and it is ' +
    'still the right one while the dataset is open - what changed is that it ' +
    'is no longer the ONLY number reachable');
end;

procedure TTestReopenLazy.Lazy_AfterTheContainerCloseLoadLazyRequestsACursor;
var
  LBefore: Integer;
  LAfter: Integer;
  LError: string;
begin
  BuildTree(cTREEROWS, False);
  FRoot.Open;

  FMid.Close;
  Assert.IsFalse(FMidTable.Active,
    'TContainerDataSet<M>.Close now reaches TDataSetBaseAdapter<M>.Close, so ' +
    'the Active gate LoadLazy reads is finally false. Under the old Close ' +
    '(FDataSetAdapter.EmptyDataSet) it never was');

  LBefore := FRows.CreateCount;
  LError := Capture(
    procedure
    begin
      FMid.LoadLazy(TAitMid(FRoot.This));
    end);
  LAfter := FRows.CreateCount;

  Assert.AreEqual('', LError,
    'LoadLazy must not raise. #246 measured it dying here on ' +
    '`Cannot perform this operation on a closed dataset`, because ' +
    'OpenSQLInternal began with EmptyDataSet and nothing reopened the ' +
    'dataset first - TDataSetBaseAdapter<M>.EnsureOpen is what removed that');
  Assert.AreEqual(LBefore + 1, LAfter,
    'THE NUMBER THIS WHOLE CHANGE EXISTS FOR, and it is a NUMBER, not a sign. ' +
    'What is counted is the DELTA across the LoadLazy call, not the running ' +
    'total - FRoot.Open has already spent cursors before this window opens, ' +
    'which is why the expectation is LBefore + 1 and not 1. That delta was ' +
    'ZERO in #246, on both legs: the gate never opened, and once it was ' +
    'forced open the reopen wall stopped the call before it reached the ' +
    'connection. It is now EXACTLY ONE - the single select over the child ' +
    'table. Asserting merely "more than before" would let a regression from ' +
    'one cursor to three through, and a lazy load that opens three cursors ' +
    'for one child is a defect wearing a green tick');
  Assert.IsTrue(Pos('aitmid', LowerCase(FRows.LastSQL)) > 0,
    'and it asked for the CHILD table, which is what a lazy load is: ' +
    FRows.LastSQL);
end;

procedure TTestReopenLazy.Lazy_TheRowsAskedForReachTheChildDataSet;
begin
  BuildTree(cTREEROWS, False);
  FRoot.Open;
  FMid.Close;

  FMid.LoadLazy(TAitMid(FRoot.This));

  Assert.IsTrue(FMidTable.Active,
    'the child dataset is open again after the lazy load');
  Assert.AreEqual(cTREEROWS, FMidTable.RecordCount,
    'ASKING FOR A CURSOR IS NOT THE SAME AS ROWS ARRIVING. The rows the lazy ' +
    'load requested are in the child dataset - the double answers every ' +
    'select with its whole row set, so the count is the row count it was ' +
    'built with');
end;

procedure TTestReopenLazy.Lazy_UnloadThenLoadIsARoundTripThatUsedToBeImpossible;
var
  LBefore: Integer;
  LError: string;
begin
  BuildTree(cTREEROWS, True);
  FRoot.Open;
  Assert.IsTrue(FMidTable.Active, 'the child starts open');

  // The unload branch: AOwner = nil clears the master and calls the PROTECTED
  // Close, which always was a real FOrmDataSet.Close - see #246's
  // Lazy_TheUnloadPathPerformsARealClose.
  FMid.LoadLazy(nil);
  Assert.IsFalse(FMidTable.Active,
    'the unload branch closed the dataset for real, exactly as it always did');

  LBefore := FRows.CreateCount;
  LError := Capture(
    procedure
    begin
      FMid.LoadLazy(TAitMid(FRoot.This));
    end);

  Assert.AreEqual('', LError,
    'THE OTHER HALF OF THE ROUND TRIP. The framework could always unload; ' +
    'what it could not do was load again afterwards, because every Open path ' +
    'started with an EmptyDataSet that refuses a closed dataset');
  Assert.IsTrue(FRows.CreateCount > LBefore,
    'and the reload really went to the connection: ' +
    IntToStr(FRows.CreateCount - LBefore) + ' cursor(s)');
  Assert.IsTrue(FMidTable.Active, 'the child is loaded again');
end;

/// <summary> THIS TEST WAS Lazy_TheRestFamilyHasNoLazyAtAll AND ITS NUMBERS
///  DID NOT MOVE - ITS REASON DID.
///
///  When #248 wrote it, TRESTDataSetAdapter<M>.LoadLazy really was an empty
///  body, and "zero calls" followed from there. #251 gave that method both
///  branches, and the two numbers below are STILL zero - so the assertions
///  survived the change while the sentence explaining them became false. It
///  was rewritten rather than deleted for exactly that reason: the
///  measurement is still the only place in this fixture that pins what the
///  REST family does when the local one is revived, and dropping it would
///  have traded a wrong explanation for no measurement at all.
///
///  WHAT TURNS THIS ADAPTER AWAY NOW. BuildRestMem hands back an adapter with
///  NO master (AMasterObject nil) and an OPEN dataset, because the constructor
///  opens it. That is one guard on each branch:
///    * load  - `if FOrmDataSet.Active then Exit`, the 'already loaded' flag
///              copied from TDataSetAdapter<M>.LoadLazy;
///    * unload- `if FOwnerMasterObject = nil then Exit`, nothing to undo.
///
///  IT RELIES ON THE ORDER OF THE LOAD GUARDS. The Active check runs BEFORE
///  SetMasterObject, so the TKeyOnly handed in here is never stored and never
///  read as if it were an adapter. A reordering that stored it first would
///  reach this test as a crash, not as a red assertion - which is a fair
///  warning to leave written down.
///
///  THE REST BRANCHES THEMSELVES ARE NOT PROVED HERE. They need a connection
///  double that answers according to the $filter it was given, and a model
///  whose two association ends are spelled differently; both live in
///  Janus.Tests.RESTfulDriver, Test.Janus.Rest.Lazy. </summary>
procedure TTestReopenLazy.Lazy_TheRestFamilyGuardsTurnAwayAnOpenUnownedChild;
var
  LOwner: TKeyOnly;
  LExecutes: Integer;
  LActive: Boolean;
begin
  BuildRestMem;
  LActive := FRestMemTable.Active;
  LExecutes := FInert.ExecuteCount;

  LOwner := TKeyOnly.Create;
  try
    TRestLazyCrack<TKeyOnly>.Lazy(FRestMem, LOwner);
    TRestLazyCrack<TKeyOnly>.Lazy(FRestMem, nil);
  finally
    LOwner.Free;
  end;

  Assert.AreEqual(LExecutes, FInert.ExecuteCount,
    'BOTH BRANCHES OF TRESTDataSetAdapter<M>.LoadLazy EXIST SINCE #251, and ' +
    'both are turned away here by a guard: the child is already open, so the ' +
    'load has nothing to fetch, and it owns no master, so the unload has ' +
    'nothing to undo. Zero calls to the connection either way - the same ' +
    'number #248 measured, for a different reason');
  Assert.AreEqual(LActive, FRestMemTable.Active,
    'and neither branch touched the dataset state: the unload closes for ' +
    'real, but only once there is a master to unregister');
end;

// ---------------------------------------------------------------------------
// Close now closes
// ---------------------------------------------------------------------------

procedure TTestReopenLazy.Close_TheContainerNowLeavesTheFDMemTableClosed;
begin
  BuildFlat(cROWS);
  FCont.Open;
  Assert.AreEqual(cROWS, FTable.RecordCount,
    'the container must really be holding rows, otherwise nothing is measured');

  FCont.Close;

  Assert.IsFalse(FTable.Active,
    'DELIBERATE BEHAVIOUR CHANGE: TContainerDataSet<M>.Close calls ' +
    'FDataSetAdapter.Close, so what a consumer gets back is a CLOSED dataset. ' +
    'It used to call EmptyDataSet and hand back an open, empty one');
end;

procedure TTestReopenLazy.Close_TheContainerNowLeavesTheClientDataSetClosed;
begin
  BuildCds(cROWS);
  FCdsCont.Open;
  Assert.AreEqual(cROWS, FCds.RecordCount,
    'the ClientDataSet container must really be holding rows');

  FCdsCont.Close;

  Assert.IsFalse(FCds.Active,
    'the same change, measured on the ClientDataSet family instead of ' +
    'deduced from the FDMemTable one - #246 never exercised this adapter');
end;

procedure TTestReopenLazy.Close_TheManagerNowLeavesTheDataSetClosed;
begin
  BuildManager(cROWS);
  FManager.Open<TKeyOnly>;
  Assert.AreEqual(cROWS, FManagerTable.RecordCount,
    'the manager must really be holding rows');

  FManager.Close<TKeyOnly>;

  Assert.IsFalse(FManagerTable.Active,
    'TManagerDataSet.Close<T> is the manager half of the same change: it ' +
    'called Resolver<T>.EmptyDataSet and now calls Resolver<T>.Close');
end;

procedure TTestReopenLazy.Close_EmptyDataSetStillClearsWithoutClosing;
begin
  BuildFlat(cROWS);
  FCont.Open;
  BuildManager(cROWS);
  FManager.Open<TKeyOnly>;

  FCont.EmptyDataSet;
  FManager.EmptyDataSet<TKeyOnly>;

  Assert.IsTrue(FTable.Active,
    'THE OLD SHAPE IS STILL AVAILABLE, under the name that always described ' +
    'it. IContainerDataSet<M>.EmptyDataSet clears the rows and leaves the ' +
    'dataset OPEN - which is exactly what Close used to do');
  Assert.AreEqual(0, FTable.RecordCount, 'and it really cleared');
  Assert.IsTrue(FManagerTable.Active,
    'and TManagerDataSet.EmptyDataSet<T> likewise');
  Assert.AreEqual(0, FManagerTable.RecordCount, 'and it really cleared');
end;

procedure TTestReopenLazy.Close_CascadesARealCloseToTheChild;
begin
  BuildTree(cTREEROWS, True);
  FRoot.Open;
  Assert.IsTrue(FMidTable.Active, 'the child starts open');

  FRoot.Close;

  Assert.IsFalse(FRootTable.Active, 'the master closed');
  Assert.IsFalse(FMidTable.Active,
    'and the child closed with it, through TDataSetBaseAdapter<M>' +
    '.DoBeforeClose. The old Close reached the child by a different route - ' +
    'EmptyDataSetChilds - and left it OPEN and empty');
end;

// ---------------------------------------------------------------------------
// Reopening after a genuine close, one adapter at a time
// ---------------------------------------------------------------------------

procedure TTestReopenLazy.Reopen_FDMemTable_TheContainerOpensAgainAfterAGenuineClose;
var
  LBefore: Integer;
  LError: string;
begin
  BuildFlat(cROWS);
  FCont.Open;
  FCont.Close;
  Assert.IsFalse(FTable.Active, 'the close is genuine, not an EmptyDataSet');

  LBefore := FRows.CreateCount;
  LError := Capture(
    procedure
    begin
      FCont.Open;
    end);

  Assert.AreEqual('', LError,
    'TFDMemTableAdapter<M>.OpenSQLInternal now calls EnsureOpen ahead of the ' +
    'EmptyDataSet that used to raise here');
  Assert.IsTrue(FTable.Active, 'the dataset is open again');
  Assert.AreEqual(cROWS, FTable.RecordCount, 'and every row is back');
  Assert.IsTrue(FRows.CreateCount > LBefore,
    'from a fresh cursor, not from whatever the close left behind');

  // The SECOND EnsureOpen call site of this adapter. An untested call site is
  // one no mutation can redden, so each Open*Internal gets its own close. The
  // third one, OpenIDInternal, needs a single-column key and is measured in
  // Reopen_TheIdPathComesBackOnBothLocalFamilies.
  FCont.Close;
  LError := Capture(
    procedure
    begin
      FCont.OpenWhere('k1 > 0');
    end);
  Assert.AreEqual('', LError,
    'TFDMemTableAdapter<M>.OpenWhereInternal comes back too');
  Assert.IsTrue(FTable.Active, 'and left the dataset open');
  Assert.AreEqual(cROWS, FTable.RecordCount, 'with its rows');
end;

procedure TTestReopenLazy.Reopen_ClientDataSet_TheContainerOpensAgainAfterAGenuineClose;
var
  LBefore: Integer;
  LError: string;
begin
  BuildCds(cROWS);
  FCdsCont.Open;
  FCdsCont.Close;
  Assert.IsFalse(FCds.Active, 'the close is genuine');

  LBefore := FRows.CreateCount;
  LError := Capture(
    procedure
    begin
      FCdsCont.Open;
    end);

  Assert.AreEqual('', LError,
    'MEASURED ON THE CLIENTDATASET FAMILY, which had NO FOrmDataSet.Open ' +
    'call anywhere in it before EnsureOpen - its constructor only calls ' +
    'CreateDataSet');
  Assert.IsTrue(FCds.Active, 'the dataset is open again');
  Assert.AreEqual(cROWS, FCds.RecordCount, 'and every row is back');
  Assert.IsTrue(FRows.CreateCount > LBefore, 'from a fresh cursor');

  FCdsCont.Close;
  LError := Capture(
    procedure
    begin
      FCdsCont.OpenWhere('k1 > 0');
    end);
  Assert.AreEqual('', LError,
    'TClientDataSetAdapter<M>.OpenWhereInternal, the second of that ' +
    'adapter''s three EnsureOpen call sites');
  Assert.IsTrue(FCds.Active, 'and left the dataset open');
  Assert.AreEqual(cROWS, FCds.RecordCount, 'with its rows');
end;

procedure TTestReopenLazy.Reopen_TheIdPathComesBackOnBothLocalFamilies;
var
  LError: string;
begin
  // TKeyOnly has a COMPOSITE key, and OpenIDInternal takes one value, so the
  // third call site of each local adapter needs a single-column key: TAitRoot.
  BuildIdPair;
  FIdMem.Open(1);
  Assert.IsTrue(FIdMemTable.Active, 'the first open by id works');
  FIdCdsCont.Open(1);
  Assert.IsTrue(FIdCds.Active, 'on both families');

  FIdMem.Close;
  FIdCdsCont.Close;
  Assert.IsFalse(FIdMemTable.Active, 'both closes are genuine');
  Assert.IsFalse(FIdCds.Active, 'both closes are genuine');

  LError := Capture(
    procedure
    begin
      FIdMem.Open(1);
    end);
  Assert.AreEqual('', LError,
    'TFDMemTableAdapter<M>.OpenIDInternal - the third and last EnsureOpen ' +
    'call site of that adapter');
  Assert.IsTrue(FIdMemTable.Active, 'and the dataset is open again');

  LError := Capture(
    procedure
    begin
      FIdCdsCont.Open(1);
    end);
  Assert.AreEqual('', LError,
    'TClientDataSetAdapter<M>.OpenIDInternal - and the third of that one');
  Assert.IsTrue(FIdCds.Active, 'and the dataset is open again');
end;

procedure TTestReopenLazy.Reopen_RestFDMemTable_OpenWhereWorksAfterAGenuineClose;
var
  LBefore: Integer;
  LError: string;
begin
  BuildRestMem;
  TRestMemCrack<TKeyOnly>.OpenWhere(FRestMem);
  Assert.IsTrue(FRestMemTable.Active, 'the first open works, as it always did');

  TCloseAccess<TKeyOnly>.RealClose(FRestMem);
  Assert.IsFalse(FRestMemTable.Active, 'and this is a real close');

  LBefore := FInert.ExecuteCount;
  LError := Capture(
    procedure
    begin
      TRestMemCrack<TKeyOnly>.OpenWhere(FRestMem);
    end);

  Assert.AreEqual('', LError,
    'TRESTFDMemTableAdapter<M>.OpenWhereInternal now calls EnsureOpen. This ' +
    'adapter has NO except block of its own, so before EnsureOpen the ' +
    'EmptyDataSet failure travelled out of it unwrapped - #246 exercised ' +
    'only the non-REST family and could not say that');
  Assert.IsTrue(FRestMemTable.Active, 'the dataset is open again');
  Assert.IsTrue(FInert.ExecuteCount > LBefore,
    'and the adapter really went back to the connection');

  // The other two EnsureOpen call sites of this adapter, each after its own
  // genuine close.
  TCloseAccess<TKeyOnly>.RealClose(FRestMem);
  LError := Capture(
    procedure
    begin
      TRestLazyCrack<TKeyOnly>.OpenSQL(FRestMem);
    end);
  Assert.AreEqual('', LError, 'OpenSQLInternal comes back too');
  Assert.IsTrue(FRestMemTable.Active, 'and left the dataset open');

  // OpenIDInternal cannot be driven to completion with this double: it answers
  // '[]' to EVERY GET, and a by-id GET deserialises into ONE object, so the
  // session raises 'Error JSON to Object'. That raise happens AFTER EnsureOpen
  // and EmptyDataSet, which is precisely what makes this leg worth keeping:
  // remove EnsureOpen and the failure moves back to the CheckBrowseMode wall,
  // which is a different message and a still-closed dataset. The assertion is
  // therefore on WHICH failure arrives, not on there being none.
  TCloseAccess<TKeyOnly>.RealClose(FRestMem);
  LError := Capture(
    procedure
    begin
      TRestLazyCrack<TKeyOnly>.OpenID(FRestMem, 1);
    end);
  Assert.IsTrue(Pos(cCLOSEDMSG, LError) = 0,
    'OpenIDInternal got PAST the EmptyDataSet that refuses a closed dataset. ' +
    'What it died on instead is the double''s canned answer, not the reopen ' +
    'wall: ' + LError);
  Assert.IsTrue(FRestMemTable.Active,
    'and the proof it got past it is that the dataset is open again');
end;

procedure TTestReopenLazy.Reopen_RestClientDataSet_OpenWhereWorksAfterAGenuineClose;
var
  LBefore: Integer;
  LError: string;
begin
  BuildRestCds;
  TRestCdsCrack<TKeyOnly>.OpenWhere(FRestCdsAdapter);
  Assert.IsTrue(FRestCds.Active, 'the first open works');

  TCloseAccess<TKeyOnly>.RealClose(FRestCdsAdapter);
  Assert.IsFalse(FRestCds.Active, 'and this is a real close');

  LBefore := FInert.ExecuteCount;
  LError := Capture(
    procedure
    begin
      TRestCdsCrack<TKeyOnly>.OpenWhere(FRestCdsAdapter);
    end);

  Assert.AreEqual('', LError,
    'the fourth adapter, measured on its own instance. Nothing here was ' +
    'inferred from the other three');
  Assert.IsTrue(FRestCds.Active, 'the dataset is open again');
  Assert.IsTrue(FInert.ExecuteCount > LBefore,
    'and it really went back to the connection');

  TCloseAccess<TKeyOnly>.RealClose(FRestCdsAdapter);
  LError := Capture(
    procedure
    begin
      TRestCdsOpenCrack<TKeyOnly>.OpenSQL(FRestCdsAdapter);
    end);
  Assert.AreEqual('', LError, 'OpenSQLInternal comes back too');
  Assert.IsTrue(FRestCds.Active, 'and left the dataset open');

  // Same limit as the REST FDMemTable leg, same reason it is still worth
  // measuring - see the comment there.
  TCloseAccess<TKeyOnly>.RealClose(FRestCdsAdapter);
  LError := Capture(
    procedure
    begin
      TRestCdsOpenCrack<TKeyOnly>.OpenID(FRestCdsAdapter, 1);
    end);
  Assert.IsTrue(Pos(cCLOSEDMSG, LError) = 0,
    'OpenIDInternal got PAST the EmptyDataSet that refuses a closed dataset: ' +
    LError);
  Assert.IsTrue(FRestCds.Active,
    'and the dataset is open again, which is the proof');
end;

// ---------------------------------------------------------------------------
// What the reopen brings back
// ---------------------------------------------------------------------------

procedure TTestReopenLazy.Rows_ABareReopenBringsBackNothingOnFDMemTableAndEverythingOnClientDataSet;
var
  LMem: Integer;
  LCds: Integer;
begin
  BuildFlat(cROWS);
  BuildCds(cROWS);
  FCont.Open;
  FCdsCont.Open;
  Assert.AreEqual(cROWS, FTable.RecordCount);
  Assert.AreEqual(cROWS, FCds.RecordCount);

  TCloseAccess<TKeyOnly>.RealClose(FCont.This);
  TCloseAccess<TKeyOnly>.RealClose(FCdsCont.This);

  // The bare Open that EnsureOpen performs, done here in the open where the
  // count can be read before anything empties the dataset again.
  FTable.Open;
  FCds.Open;
  LMem := FTable.RecordCount;
  LCds := FCds.RecordCount;

  Assert.AreEqual(0, LMem,
    'A REOPENED TFDMemTable COMES BACK EMPTY: ' + IntToStr(LMem) + ' row(s)');
  Assert.AreEqual(cROWS, LCds,
    'AND A REOPENED TClientDataSet COMES BACK WITH THE ROWS IT HAD: ' +
    IntToStr(LCds) + ' row(s). The two families do not agree, and it costs ' +
    'the adapters nothing only because every EnsureOpen call site empties the ' +
    'dataset on the very next line. THE REOPEN IS NOT A WAY TO PRESERVE DATA ' +
    'ACROSS A CLOSE');
end;

procedure TTestReopenLazy.Fields_TheSameObjectsSurviveCloseAndReopen_BothFamilies;
var
  LMemOpen: TArray<TField>;
  LMemClosed: TArray<TField>;
  LMemReopened: TArray<TField>;
  LCdsOpen: TArray<TField>;
  LCdsClosed: TArray<TField>;
  LCdsReopened: TArray<TField>;
begin
  BuildFlat(cROWS);
  BuildCds(cROWS);
  FCont.Open;
  FCdsCont.Open;
  LMemOpen := FieldHandles(FTable);
  LCdsOpen := FieldHandles(FCds);
  Assert.IsTrue(Length(LMemOpen) > 0, 'there must be fields to lose');
  Assert.IsTrue(Length(LCdsOpen) > 0, 'there must be fields to lose');

  TCloseAccess<TKeyOnly>.RealClose(FCont.This);
  TCloseAccess<TKeyOnly>.RealClose(FCdsCont.This);
  LMemClosed := FieldHandles(FTable);
  LCdsClosed := FieldHandles(FCds);

  FTable.Open;
  FCds.Open;
  LMemReopened := FieldHandles(FTable);
  LCdsReopened := FieldHandles(FCds);

  Assert.IsTrue(SameHandles(LMemOpen, LMemClosed),
    'FDMemTable: closing destroys no field - ' + IntToStr(Length(LMemOpen)) +
    ' before, ' + IntToStr(Length(LMemClosed)) + ' after. They are ' +
    'lcPersistent, and TDataSet.DestroyFields only clears the automatic ones');
  Assert.IsTrue(SameHandles(LMemOpen, LMemReopened),
    'FDMemTable: and reopening rebuilds none either - ' +
    IntToStr(Length(LMemReopened)) + ' after the reopen, THE SAME OBJECTS');
  Assert.IsTrue(SameHandles(LCdsOpen, LCdsClosed),
    'ClientDataSet: same result on the other family - ' +
    IntToStr(Length(LCdsOpen)) + ' before, ' + IntToStr(Length(LCdsClosed)) +
    ' after');
  Assert.IsTrue(SameHandles(LCdsOpen, LCdsReopened),
    'ClientDataSet: and the same objects after the reopen - ' +
    IntToStr(Length(LCdsReopened)) + '. THIS IS WHY A BARE Open IS THE WHOLE ' +
    'FIX: a genuine close costs no resource that Open would have to rebuild');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestReopenLazy);

end.
