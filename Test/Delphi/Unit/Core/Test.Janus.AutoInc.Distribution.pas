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

  THE ORDERING THAT MAKES THE STATE REACHABLE, WITH NOTHING MUTED

  Two pending masters each able to hold pending children is not reachable in
  the local family by typing the children first: TDataSetAdapter<M>.DoNewRecord
  calls EmptyDataSetChilds BEFORE the inherited call, so appending the second
  master wipes them. It IS reachable the other way round - append both masters
  while the child table is still empty, scroll back to the first, and only then
  type the children. Nothing is lost at either step because there is nothing to
  lose yet, and ApplyInternal disables events before it walks, so the typed
  children arrive at ApplyInserter intact.

  Every test below uses that ordering. NO adapter is muted anywhere in the
  set-up, no marker is written by hand, and no handler is installed - what runs
  is the configuration Janus ships. The one exception is
  UntokenisedRows_KeepTheHistoricalBehaviour, which mutes ON PURPOSE and says
  why in its own body.

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

  WHAT IS NOT MEASURED HERE

  No live database and no live REST server. The generator is a double that
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
    /// How many times the generator was asked. Zero means no key was ever
    /// generated, which would make every key assertion vacuous.
    property SequenceCalls: Integer read FSequenceCalls;
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

    // --- the boundary of the fix -------------------------------------------
    [Test]
    procedure UntokenisedRows_KeepTheHistoricalBehaviour;
    [Test]
    procedure ChildRowWithNoRecordedParentage_IsStillWrittenByItsMaster;

    // --- the latent position site the new column must not disturb ----------
    [Test]
    procedure MappedColumnsKeepTheOffsetTheNestedFillReliesOn;
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
      Assert.AreEqual(2, RowCount(LMasterTable),
        'and counting the children must not have cost a master row');
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
  // WHAT THIS FIXES IN PLACE, and it is a limit rather than a feature. The
  // parentage a pending child row carries is recorded when the row is created,
  // by TDataSetBaseAdapter<M>.DoNewRecord. A row that never went through that
  // event - because the caller had the adapter's events unhooked - carries no
  // parentage at all, and for such a row the cascade cannot do better than
  // what it always did: stamp it on every pending master in turn, last one
  // wins.
  //
  // The set-up below is exactly that case, and it is the ONLY test in this
  // file that mutes anything. It exists so the boundary is a measurement
  // instead of a silence: a later change that made untokenised rows behave
  // differently would show up here rather than in a consumer.
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
  LIndex := 1;
  for LColumn in LColumns do
  begin
    Assert.AreEqual(LColumn.ColumnName, ADataSet.Fields[LIndex].FieldName,
      AWhere + ': mapped column ' + IntToStr(LIndex - 1) + ' must sit at ' +
      'field index ' + IntToStr(LIndex) + '. TBind._FillADTField and ' +
      'TBind._FillDataSetField copy source field N into ' +
      'ATarget.Fields[N + 1], so a second internal column placed before the ' +
      'mapped ones would silently write every value one column to the right');
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

initialization
  TDUnitX.RegisterTestFixture(TTestAutoIncDistribution);

end.
