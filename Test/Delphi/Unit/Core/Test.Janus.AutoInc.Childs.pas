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

{ @abstract(Janus Framework - CascadeAutoInc propagation to child datasets.)

  WHAT IS UNDER TEST

  TDataSetBaseAdapter<M>.SetAutoIncValueChilds - the method whose entire job is
  to stamp the key the database has just generated for a freshly inserted
  master onto the rows of its child datasets. It is reached from
  TFDMemTableAdapter<M>.ApplyInserter, TClientDataSetAdapter<M>.ApplyInserter
  and TRESTDataSetAdapter<M>.ApplyInserter, always with the master sitting in
  dsEdit carrying the NEW key, not yet posted. The fixture reproduces exactly
  that state and then calls the REAL method - not a mirror of it.

  THE DEFECT THIS SUITE PINS

  In the REST client family the child datasets are wired to the master by
  MasterSource/MasterFields (TRESTFDMemTableAdapter<M>._FilterDataSetChilds,
  TRESTClientDataSetAdapter<M>.FilterDataSetChilds). That link RANGES the child
  on `child.FK = master.key`. By the time SetAutoIncValueChilds runs the master
  already holds the NEW key while the children still hold the OLD one, so the
  child set is EMPTY and the loop had nothing to iterate: the method updated
  ZERO rows. Measured by
  LinkedChildSet_IsEmptyWhileTheMasterKeyChanged_PREMISE.

  There is a SECOND trap behind the first: detaching the link is not enough.
  When the child dataset is indexed by the very column being rewritten - which
  is what TFDMemTableAdapter<M>._GetIndexFieldNames produces for an entity
  whose [OrderBy] is its foreign key - writing the new value REORDERS the row,
  and a Post+Next walk lands past the end after the first one. Pinned by
  Unlinked_IndexedByForeignKey_AllRowsStillUpdated.

  WHY THE FIXTURE MUTES BeforeScroll/AfterScroll IN ITS OWN HELPERS

  TDataSetAdapter<M>.DoAfterScroll calls OpenDataSetChilds, which RE-OPENS every
  child dataset from the database. So merely walking a dataset to count its rows
  destroys the rows of its children. The production code under test is never
  muted - only the fixture's own set-up and measurement helpers are, so that a
  count is a count and not a side effect.

  WHICH MASTER ROW'S KEY REACHES THE CHILDREN - issue #261

  _AutoIncToChildRows reads the association's columns off the MASTER DATASET,
  which means off whatever row that dataset's cursor is sitting on, and writes
  them into EVERY pending child row. It consults no primary key and no per-row
  correspondence. Until this section existed nobody had ever run it with two
  master rows carrying different keys - the older grandchild test gives all
  three mid rows the SAME own key on purpose, and says so - so the outcome was
  unmeasured rather than known. It is measured now:

    * three mid rows carrying 91 / 92 / 93, two leaf rows starting on a key no
      mid row has: BOTH leaves come out on 91. Not one carries 92 or 93, and
      none is left alone. Measured by
      Linked_MidRowsWithDistinctKeys_EveryLeafGetsTheFirstMidRowKey and its
      Unlinked_ twin, so it is not an artefact of the REST client's wiring;

    * 91 is the FIRST mid row, not the last one processed - the probe records
      the last mid row the cascade touched as M2/93 in the same run. Which row
      the cursor ends on is decided by _AutoIncToChildRows' own `finally`, which
      calls AChild.First after writing. Mutating that single call to AChild.Last
      moves the value every leaf receives from 91 to 93 and reddens exactly
      those two tests out of 470 - which is why this file says the key is the
      CURSOR's row rather than merely observing that they collapse;

    * the master-detail range never protects anything. With the link live the
      visible leaf set is ZERO rows and both leaves are written all the same,
      because _AutoIncToChildRows calls _DetachMasterLink before it walks. The
      only filter left is _IsPendingInsertRow. That clause is a PREMISE inside
      the Linked_ test;

    * and one level up, TFDMemTableAdapter<M>.ApplyInserter loops over EVERY
      pending master row calling SetAutoIncValueChilds once per row, while the
      child rows stay dsInsert for the whole loop - TFDMemTableAdapter<M>
      .ApplyInternal only reaches each child's own ApplyInternal after the
      master loop has finished. So each pass re-stamps the same child rows and
      the LAST pending master row wins. Measured by
      TwoPendingMasterRows_EveryPendingChildEndsOnTheLastMasterKey, which
      asserts the rows are still pending on the second pass rather than
      assuming it.

  THE OTHER FAMILY DOES NOT DO THIS, AND THAT IS THE POINT

  TObjectSetBaseAdapter<M>.SetAutoIncValueOneToMany reads the value with
  AProperty.GetValue(AObject), where AObject is the parent OBJECT it was handed.
  Two parents are two arguments, never two positions in one cursor. Measured
  with the same three keys by
  ObjectSet_TwoParentsWithDistinctKeys_NeitherChildListCollapses: each list
  keeps its own parent's key. The two families are supposed to be
  interchangeable to a consumer and here they are not.

  WHY THE WRITE IS INSTRUMENTED AND NOT INFERRED

  A value found on a child row afterwards does not say who put it there - a
  later pass over the same level can leave the same number behind, and that
  confusion is what made an earlier defect in this series look like a feature.
  So the fixture hooks TField.OnChange on the column being propagated and
  records, INSIDE the write, which master row was current. That hook survives
  both mutes the production path installs: TDataSetBaseAdapter<M>
  .DisableDataSetEvents only nils the DATASET's own event properties (see its
  _FindEvents list, which has no field event in it), and TDataSet.DataEvent
  reaches TField.Change before the branch that DisableControls suppresses. Not
  argued - the probe records writes that happen inside both.
  NoPendingLeafRow_TheProbeRecordsNoWriteAtAll is the meta-check of the probe
  itself: an instrument that could not report a zero would make every count
  above unfalsifiable.

  WHAT THIS SECTION DID NOT MEASURE

  * Neither family is driven through its real ApplyInserter: that needs a live
    FSession.Insert. As everywhere else in this fixture, the state ApplyInserter
    creates is reproduced and the SHIPPED SetAutoIncValueChilds is called.
  * TwoPendingMasterRows_ moves the master cursor itself, wrapped in the
    framework's own DisableDataSetEvents, because ApplyInserter advances its
    cursor as a side effect of marking rows saved through its filter and that
    needs the session. What the mute buys is asserted, not assumed.
  * The ObjectSet test calls SetAutoIncValueChilds once per parent object the
    way OneToManyCascadeActionsExecute does, but does not run the cascade, so it
    measures the distribution step and not the call sequence that reaches it.
  * WHETHER the mid rows' own keys have been generated at the instant the
    recursion fires is issue #262 and is NOT answered here. This fixture writes
    those keys itself, so it can say WHICH key travels and never whether it had
    been generated.
  * Nothing here ran against a live database or a live REST server.
    TClientDataSetAdapter<M>.ApplyInserter and TRESTDataSetAdapter<M>
    .ApplyInserter carry the same per-pending-master-row loop, and
    TRESTDataSetAdapter<M>.OpenDataSetChilds has an empty body, so a master
    scroll there discards no pending child. Both are READ, not run.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`. A line anchor rots on the first
  commit that inserts a line above it.
}

unit Test.Janus.AutoInc.Childs;

interface

uses
  DB,
  Classes,
  SysUtils,
  Variants,
  TypInfo,
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
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Explorer,
  MetaDbDiff.Types.Mapping,
  Janus.DataSet.Base.Adapter,
  Janus.Container.DataSet.Interfaces,
  Janus.Container.FDMemTable,
  Janus.ObjectSet.Base.Adapter,
  Janus.ObjectSet.Adapter,
  Test.Janus.Model.AutoIncTree,
  Test.Janus.Cursor.Double;

type
  /// <summary> One observed WRITE into a child row's foreign key, captured at
  ///  the instant the write happens - not reconstructed from the rows
  ///  afterwards. `MasterTag`/`MasterKey` are read INSIDE the handler, so they
  ///  are the master row the cascade was standing on when it wrote, which is
  ///  the whole question issue #261 asks. </summary>
  TCascadeWrite = record
    Level: String;
    ChildTag: String;
    Value: Integer;
    MasterTag: String;
    MasterKey: Integer;
  end;

  /// <summary> One armed (child dataset, column) pair and the master dataset
  ///  whose current row is to be recorded alongside every write to it. </summary>
  TProbeArm = record
    Level: String;
    Child: TFDMemTable;
    Master: TFDMemTable;
    MasterColumn: String;
  end;

  /// <summary> Classic protected-access descendant. SetAutoIncValueChilds and
  ///  FOrmDataSource are protected, and the production call sites sit deep
  ///  inside ApplyInserter, which would need a live server or a live database.
  ///  Casting to a local descendant is what lets the test drive the SHIPPED
  ///  method itself. </summary>
  TAdapterAccess<M: class, constructor> = class(TDataSetBaseAdapter<M>)
  public
    class procedure Propagate(const AAdapter: TDataSetBaseAdapter<M>);
    class function SourceOf(const AAdapter: TDataSetBaseAdapter<M>): TDataSource;
    /// The SHIPPED mute, not a fixture imitation of it: TFDMemTableAdapter<M>
    /// .ApplyInternal calls exactly these two around the whole apply, which is
    /// why its ApplyInserter can walk from one pending master row to the next
    /// without DoAfterScroll re-opening - and therefore discarding - the child
    /// rows it is about to stamp.
    class procedure MuteAdapter(const AAdapter: TDataSetBaseAdapter<M>);
    class procedure UnmuteAdapter(const AAdapter: TDataSetBaseAdapter<M>);
  end;

  /// <summary> Same protected-access trick for the OTHER family that ships a
  ///  method called SetAutoIncValueChilds - the ObjectSet one, which takes
  ///  (AObject, AColumn) and walks an in-memory object graph instead of a
  ///  dataset. </summary>
  TObjectSetAccess<M: class, constructor> = class(TObjectSetBaseAdapter<M>)
  public
    class procedure Propagate(const AAdapter: TObjectSetBaseAdapter<M>;
      const AObject: TObject; const AColumn: TColumnMapping);
  end;

  [TestFixture]
  TTestAutoIncChilds = class
  private
    FConn: IDBConnection;
    FRootTable: TFDMemTable;
    FMidTable: TFDMemTable;
    FLeafTable: TFDMemTable;
    FOtherTable: TFDMemTable;
    FRoot: IContainerDataSet<TAitRoot>;
    FMid: IContainerDataSet<TAitMid>;
    FLeaf: IContainerDataSet<TAitLeaf>;
    FOther: IContainerDataSet<TAitNoCascade>;
    FWrites: TList<TCascadeWrite>;
    FArms: TList<TProbeArm>;
    procedure BuildTree(const AWithLeaf: Boolean = True;
      const AWithOther: Boolean = False);
    procedure LinkAsRestClientDoes;
    procedure AddMasterRow(const AKey: Integer);
    procedure AddChildRow(const ADataSet: TFDMemTable; const AKey: Integer;
      const ATag: String; const APending: Boolean = True;
      const AOwnKey: Integer = 0);
    function CountWithKey(const ADataSet: TFDMemTable;
      const AKey: Integer): Integer;
    function CountWithColumn(const ADataSet: TFDMemTable;
      const AColumn: String; const AKey: Integer): Integer;
    function VisibleRowCount(const ADataSet: TFDMemTable): Integer;
    procedure MoveMasterToNewKey(const ANewKey: Integer);
    procedure ArmWriteProbe(const ALevel: String; const AChild: TFDMemTable;
      const AColumn: String; const AMaster: TFDMemTable;
      const AMasterColumn: String);
    procedure DisarmWriteProbe;
    procedure ProbeFieldChanged(Sender: TField);
    function WritesAt(const ALevel: String): TArray<TCascadeWrite>;
    function WriteLog: String;
    procedure BuildDistinctKeyTree(const ALinked: Boolean;
      const AMidRows: Integer; const ALeafRows: Integer);
    procedure AssertLeavesCollapsedOntoTheFirstMidRow;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// The premise the whole fix is built on, measured independently.
    [Test]
    procedure LinkedChildSet_IsEmptyWhileTheMasterKeyChanged_PREMISE;

    /// REST-client shape: master-detail link live. More than one child.
    [Test]
    procedure Linked_EveryChildRowReceivesTheNewKey;
    /// ...and more than one level: the grandchildren too.
    [Test]
    procedure Linked_EveryGrandchildRowReceivesTheNewKey;
    /// The link must be exactly where it was, and live, when the method returns.
    [Test]
    procedure Linked_MasterDetailLinkIsRestored;

    /// Plain DataSet shape (no MasterSource anywhere): still every row.
    [Test]
    procedure Unlinked_EveryChildRowReceivesTheNewKey;
    /// ...even when the child is indexed by the column being rewritten.
    [Test]
    procedure Unlinked_IndexedByForeignKey_AllRowsStillUpdated;

    /// A row that is already persisted belongs to another master and must
    /// never be re-pointed at the new key.
    [Test]
    procedure PersistedChildRow_IsNotRepointed;
    /// An association without CascadeAutoInc must stay untouched.
    [Test]
    procedure AssociationWithoutCascadeAutoInc_IsNotTouched;
    /// A CascadeAutoInc association whose child dataset was never created.
    [Test]
    procedure ChildDataSetNotRegistered_DoesNotRaise;

    // -----------------------------------------------------------------------
    // Issue #261 - WHICH master row's key reaches the pending child rows
    // -----------------------------------------------------------------------

    /// The measurement the issue asks for: three mid rows, three DIFFERENT own
    /// keys, and the write into every leaf instrumented as it happens.
    [Test]
    procedure Linked_MidRowsWithDistinctKeys_EveryLeafGetsTheFirstMidRowKey;
    /// The same with no master-detail link anywhere, so the collapse cannot be
    /// blamed on the REST client's wiring.
    [Test]
    procedure Unlinked_MidRowsWithDistinctKeys_EveryLeafGetsTheFirstMidRowKey;
    /// ONE mid row. This case cannot tell a collapse from a correct
    /// distribution and does not claim to - see its own comment.
    [Test]
    procedure SingleMidRow_TheOnlyKeyReachesTheLeaves_DEGENERATE;
    /// ZERO pending leaf rows. Also not a detector of the collapse: it is the
    /// meta-check of the probe, which would be worthless if it could not report
    /// a zero.
    [Test]
    procedure NoPendingLeafRow_TheProbeRecordsNoWriteAtAll;
    /// Two pending MASTER rows, which is what ApplyInserter really loops over.
    [Test]
    procedure TwoPendingMasterRows_EveryPendingChildEndsOnTheLastMasterKey;

    /// The OTHER family. It has no cursor and no master-detail filter, so the
    /// defect above cannot exist there - measured, not assumed.
    [Test]
    procedure ObjectSet_EveryChildObjectReceivesTheNewKey;
    /// ...and the level below it, which is the one issue #244 is about: this
    /// family offers only the parent's OWN key columns, so the shape the
    /// fixture carried before #244 could not be expressed here at all.
    [Test]
    procedure ObjectSet_EveryGrandchildObjectReceivesTheMidKey;
    /// Issue #261 in the other family: TWO parents with different keys, each
    /// holding its own children. This is the comparison the issue calls the
    /// most valuable outcome, because the two families are meant to be
    /// interchangeable to a consumer.
    [Test]
    procedure ObjectSet_TwoParentsWithDistinctKeys_NeitherChildListCollapses;
  end;

implementation

const
  cROOTKEYOLD   = 0;
  cROOTKEYNEW   = 500;
  cOTHERROOT    = 7;
  cCHILDS       = 3;
  cGRANDS       = 2;
  cKEYFIELD     = 'root_id';
  /// The MID's own key - what the mid level propagates to its leaves since
  /// issue #244. `root_id` on the leaf is the denormalised column no
  /// association names, kept as the negative control for ancestor propagation.
  cOWNKEYFIELD  = 'mid_id';
  cMIDOWNKEY    = 90;
  cMASTERSOURCE = 'MasterSource';
  cWALKCEILING  = 50;
  /// ---- issue #261: THREE mid rows, three DIFFERENT own keys ----------------
  /// cMIDOWNKEY above is the one-key-for-all value the older grandchild test
  /// uses on purpose. These are its opposite, and the only reason this file
  /// can answer "which parent's key reaches the leaves".
  cMIDKEYFIRST  = 91;
  cMIDKEYMIDDLE = 92;
  cMIDKEYLAST   = 93;
  /// The leaves start on a value NO mid row carries, so "nothing was written"
  /// and "the first mid row was written" can never be read as the same result.
  cLEAFSTART    = -7;
  /// The SECOND pending master row's generated key - cROOTKEYNEW is the first.
  cROOTKEYB     = 600;
  /// What the probe records when the master dataset has no current row.
  cNOMASTERROW  = -999;
  cLEVELMID     = 'mid';
  cLEVELLEAF    = 'leaf';

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

{ TAdapterAccess<M> }

class procedure TAdapterAccess<M>.Propagate(
  const AAdapter: TDataSetBaseAdapter<M>);
begin
  TAdapterAccess<M>(AAdapter).SetAutoIncValueChilds;
end;

class function TAdapterAccess<M>.SourceOf(
  const AAdapter: TDataSetBaseAdapter<M>): TDataSource;
begin
  Result := TAdapterAccess<M>(AAdapter).FOrmDataSource;
end;

class procedure TAdapterAccess<M>.MuteAdapter(
  const AAdapter: TDataSetBaseAdapter<M>);
begin
  TAdapterAccess<M>(AAdapter).DisableDataSetEvents;
end;

class procedure TAdapterAccess<M>.UnmuteAdapter(
  const AAdapter: TDataSetBaseAdapter<M>);
begin
  TAdapterAccess<M>(AAdapter).EnableDataSetEvents;
end;

{ TObjectSetAccess<M> }

class procedure TObjectSetAccess<M>.Propagate(
  const AAdapter: TObjectSetBaseAdapter<M>; const AObject: TObject;
  const AColumn: TColumnMapping);
begin
  TObjectSetAccess<M>(AAdapter).SetAutoIncValueChilds(AObject, AColumn);
end;

{ TTestAutoIncChilds }

// ---------------------------------------------------------------------------
// The probe - see WHY THE WRITE IS INSTRUMENTED in the unit header
// ---------------------------------------------------------------------------

procedure TTestAutoIncChilds.ArmWriteProbe(const ALevel: String;
  const AChild: TFDMemTable; const AColumn: String; const AMaster: TFDMemTable;
  const AMasterColumn: String);
var
  LArm: TProbeArm;
begin
  LArm.Level := ALevel;
  LArm.Child := AChild;
  LArm.Master := AMaster;
  LArm.MasterColumn := AMasterColumn;
  FArms.Add(LArm);
  AChild.FieldByName(AColumn).OnChange := ProbeFieldChanged;
end;

procedure TTestAutoIncChilds.DisarmWriteProbe;
var
  LArm: TProbeArm;
  LFor: Integer;
begin
  if FArms = nil then
    Exit;
  for LArm in FArms do
    for LFor := 0 to LArm.Child.FieldCount - 1 do
      LArm.Child.Fields[LFor].OnChange := nil;
  FArms.Clear;
end;

procedure TTestAutoIncChilds.ProbeFieldChanged(Sender: TField);
var
  LArm: TProbeArm;
  LWrite: TCascadeWrite;
begin
  for LArm in FArms do
  begin
    if LArm.Child <> Sender.DataSet then
      Continue;
    LWrite.Level := LArm.Level;
    LWrite.Value := Sender.AsInteger;
    LWrite.ChildTag := LArm.Child.FieldByName('tag').AsString;
    // The master's CURRENT ROW, read at the instant of the write. This is the
    // measurement: everything else in this fixture is a consequence of it.
    if (LArm.Master = nil) or LArm.Master.IsEmpty then
    begin
      LWrite.MasterTag := '<empty>';
      LWrite.MasterKey := cNOMASTERROW;
    end
    else
    begin
      LWrite.MasterTag := LArm.Master.FieldByName('tag').AsString;
      LWrite.MasterKey := LArm.Master.FieldByName(LArm.MasterColumn).AsInteger;
    end;
    FWrites.Add(LWrite);
    Exit;
  end;
end;

function TTestAutoIncChilds.WritesAt(const ALevel: String): TArray<TCascadeWrite>;
var
  LFor: Integer;
  LCount: Integer;
begin
  SetLength(Result, 0);
  LCount := 0;
  for LFor := 0 to FWrites.Count - 1 do
  begin
    if FWrites[LFor].Level <> ALevel then
      Continue;
    SetLength(Result, LCount + 1);
    Result[LCount] := FWrites[LFor];
    Inc(LCount);
  end;
end;

/// Every assertion below quotes this, so a red never asks anyone to guess what
/// the run actually did.
function TTestAutoIncChilds.WriteLog: String;
var
  LFor: Integer;
begin
  Result := IntToStr(FWrites.Count) + ' write(s):';
  for LFor := 0 to FWrites.Count - 1 do
    Result := Result + ' [' + FWrites[LFor].Level + ' ' +
              FWrites[LFor].ChildTag + ' <- ' + IntToStr(FWrites[LFor].Value) +
              ' while the master sat on ' + FWrites[LFor].MasterTag + '/' +
              IntToStr(FWrites[LFor].MasterKey) + ']';
end;

procedure TTestAutoIncChilds.Setup;
begin
  FWrites := TList<TCascadeWrite>.Create;
  FArms := TList<TProbeArm>.Create;
  // The connection is only needed to build the adapters; no test here opens a
  // cursor. Zero rows keeps the double completely inert.
  FConn := TRowsConnection.Create(dnSQLite, 0,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add(cKEYFIELD, ftInteger);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName(cKEYFIELD).AsInteger := AIndex;
    end,
    'autoinc');
end;

procedure TTestAutoIncChilds.TearDown;
begin
  DisarmWriteProbe;
  FreeAndNil(FArms);
  FreeAndNil(FWrites);
  // Detach first: a TFDMemTable freed while another one still points at its
  // TDataSource is a crash, not a test result.
  if FLeafTable <> nil then
    FLeafTable.MasterSource := nil;
  if FMidTable <> nil then
    FMidTable.MasterSource := nil;
  if FOtherTable <> nil then
    FOtherTable.MasterSource := nil;
  FOther := nil;
  FLeaf := nil;
  FMid := nil;
  FRoot := nil;
  FreeAndNil(FOtherTable);
  FreeAndNil(FLeafTable);
  FreeAndNil(FMidTable);
  FreeAndNil(FRootTable);
  FConn := nil;
end;

procedure TTestAutoIncChilds.BuildTree(const AWithLeaf: Boolean;
  const AWithOther: Boolean);
begin
  FRootTable := TFDMemTable.Create(nil);
  FRoot := TContainerFDMemTable<TAitRoot>.Create(FConn, FRootTable);

  FMidTable := TFDMemTable.Create(nil);
  FMid := TContainerFDMemTable<TAitMid>.Create(FConn, FMidTable, FRoot.This);

  if AWithLeaf then
  begin
    FLeafTable := TFDMemTable.Create(nil);
    FLeaf := TContainerFDMemTable<TAitLeaf>.Create(FConn, FLeafTable, FMid.This);
  end;

  if AWithOther then
  begin
    FOtherTable := TFDMemTable.Create(nil);
    FOther := TContainerFDMemTable<TAitNoCascade>.Create(FConn, FOtherTable,
                                                        FRoot.This);
  end;
end;

/// Reproduces, from the mapping itself, what
/// TRESTFDMemTableAdapter<M>._FilterDataSetChilds installs on every child.
procedure TTestAutoIncChilds.LinkAsRestClientDoes;

  procedure Wire(const ASource: TDataSource; const AChild: TFDMemTable;
    const AOwnerClass: TClass; const AChildClassName: String);
  var
    LAssociations: TAssociationMappingList;
    LAssociation: TAssociationMapping;
    LFor: Integer;
    LIndexFields: String;
    LFields: String;
    LMute: TScrollMute;
  begin
    LAssociations := TMappingExplorer.GetMappingAssociation(AOwnerClass);
    Assert.IsNotNull(LAssociations, AOwnerClass.ClassName +
      ' must expose associations, otherwise this fixture proves nothing');
    for LAssociation in LAssociations do
    begin
      if LAssociation.ClassNameRef <> AChildClassName then
        Continue;
      LIndexFields := '';
      LFields := '';
      for LFor := 0 to LAssociation.ColumnsName.Count - 1 do
      begin
        LIndexFields := LIndexFields + LAssociation.ColumnsNameRef[LFor];
        LFields := LFields + LAssociation.ColumnsName[LFor];
        if LAssociation.ColumnsName.Count - 1 > LFor then
        begin
          LIndexFields := LIndexFields + '; ';
          LFields := LFields + '; ';
        end;
      end;
      // Installing the link re-ranges the child, which scrolls it; muted so
      // the wiring does not wipe the grandchildren it is not talking about.
      LMute := MuteScroll(AChild);
      try
        AChild.MasterSource := ASource;
        AChild.IndexFieldNames := LIndexFields;
        AChild.MasterFields := LFields;
      finally
        UnmuteScroll(AChild, LMute);
      end;
      Exit;
    end;
    Assert.Fail('no association from ' + AOwnerClass.ClassName + ' to ' +
                AChildClassName);
  end;

begin
  Wire(TAdapterAccess<TAitRoot>.SourceOf(FRoot.This), FMidTable,
       TAitRoot, TAitMid.ClassName);
  if FLeafTable <> nil then
    Wire(TAdapterAccess<TAitMid>.SourceOf(FMid.This), FLeafTable,
         TAitMid, TAitLeaf.ClassName);
  if FOtherTable <> nil then
    Wire(TAdapterAccess<TAitRoot>.SourceOf(FRoot.This), FOtherTable,
         TAitRoot, TAitNoCascade.ClassName);
end;

procedure TTestAutoIncChilds.AddMasterRow(const AKey: Integer);
begin
  FRootTable.Append;
  FRootTable.FieldByName(cKEYFIELD).AsInteger := AKey;
  FRootTable.FieldByName('tag').AsString := 'ROOT';
  FRootTable.Post;
end;

procedure TTestAutoIncChilds.AddChildRow(const ADataSet: TFDMemTable;
  const AKey: Integer; const ATag: String; const APending: Boolean;
  const AOwnKey: Integer);
var
  LInternal: TField;
  LSavedBeforePost: TDataSetNotifyEvent;
begin
  ADataSet.Append;
  ADataSet.FieldByName(cKEYFIELD).AsInteger := AKey;
  // Written on every row that HAS the column, leaves included, so the leaf's
  // starting value is stated rather than left to whatever an unset field
  // reads back as. Both entities carry `mid_id` since #244: on the mid it is
  // the primary key, on the leaf the foreign key onto it.
  if ADataSet.FindField(cOWNKEYFIELD) <> nil then
    ADataSet.FieldByName(cOWNKEYFIELD).AsInteger := AOwnKey;
  if ADataSet.FindField('tag') <> nil then
    ADataSet.FieldByName('tag').AsString := ATag;
  ADataSet.Post;
  if APending then
    Exit;
  // Mark the row as ALREADY PERSISTED - which is what
  // TFDMemTableAdapter<M>.ApplyInserter writes back once a row is saved. The
  // adapter's own BeforePost would immediately flip the marker back, so the
  // event is muted for this one write.
  LInternal := ADataSet.FindField('InternalField');
  Assert.IsNotNull(LInternal, 'the adapter must create the internal state field');
  LSavedBeforePost := ADataSet.BeforePost;
  ADataSet.BeforePost := nil;
  try
    ADataSet.Edit;
    LInternal.AsInteger := -1;
    ADataSet.Post;
  finally
    ADataSet.BeforePost := LSavedBeforePost;
  end;
  Assert.AreEqual(-1, LInternal.AsInteger,
    'the fixture must really be able to mark a row as persisted');
end;

/// Counts over the WHOLE table, never through the master-detail range - the
/// range would hide exactly the rows a wrong fix leaves behind.
function TTestAutoIncChilds.CountWithKey(const ADataSet: TFDMemTable;
  const AKey: Integer): Integer;
begin
  Result := CountWithColumn(ADataSet, cKEYFIELD, AKey);
end;

function TTestAutoIncChilds.CountWithColumn(const ADataSet: TFDMemTable;
  const AColumn: String; const AKey: Integer): Integer;
var
  LSource: TDataSource;
  LIndex: String;
  LMute: TScrollMute;
begin
  LMute := MuteScroll(ADataSet);
  LSource := ADataSet.MasterSource;
  LIndex := ADataSet.IndexFieldNames;
  ADataSet.MasterSource := nil;
  ADataSet.IndexFieldNames := '';
  try
    Result := 0;
    ADataSet.First;
    while (not ADataSet.Eof) and (Result <= cWALKCEILING) do
    begin
      if ADataSet.FieldByName(AColumn).AsInteger = AKey then
        Inc(Result);
      ADataSet.Next;
    end;
  finally
    ADataSet.IndexFieldNames := LIndex;
    ADataSet.MasterSource := LSource;
    UnmuteScroll(ADataSet, LMute);
  end;
end;

function TTestAutoIncChilds.VisibleRowCount(const ADataSet: TFDMemTable): Integer;
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

/// Mirror of ApplyInserter: the master sits in dsEdit carrying the key the
/// database has just generated, not yet posted. No First here on purpose -
/// scrolling the master would re-open (and therefore empty) its children.
procedure TTestAutoIncChilds.MoveMasterToNewKey(const ANewKey: Integer);
begin
  FRootTable.Edit;
  FRootTable.FieldByName(cKEYFIELD).AsInteger := ANewKey;
end;

// ---------------------------------------------------------------------------
// The premise
// ---------------------------------------------------------------------------

procedure TTestAutoIncChilds.LinkedChildSet_IsEmptyWhileTheMasterKeyChanged_PREMISE;
var
  LFor: Integer;
begin
  BuildTree(False);
  AddMasterRow(cROOTKEYOLD);
  for LFor := 0 to cCHILDS - 1 do
    AddChildRow(FMidTable, cROOTKEYOLD, 'M' + IntToStr(LFor));
  LinkAsRestClientDoes;

  Assert.AreEqual(cCHILDS, VisibleRowCount(FMidTable),
    'before the master key moves, the child set must show every child - if ' +
    'this is already 0 the fixture is broken, not the framework');

  MoveMasterToNewKey(cROOTKEYNEW);

  // THIS is the defect in one number: the loop inside SetAutoIncValueChilds
  // was handed a cursor with nothing in it.
  Assert.AreEqual(0, VisibleRowCount(FMidTable),
    'with the link live and the master key already changed, the child set is ' +
    'EMPTY - a walk over it cannot reach a single child');
end;

// ---------------------------------------------------------------------------
// REST-client shape
// ---------------------------------------------------------------------------

procedure TTestAutoIncChilds.Linked_EveryChildRowReceivesTheNewKey;
var
  LFor: Integer;
begin
  BuildTree(False);
  AddMasterRow(cROOTKEYOLD);
  for LFor := 0 to cCHILDS - 1 do
    AddChildRow(FMidTable, cROOTKEYOLD, 'M' + IntToStr(LFor));
  LinkAsRestClientDoes;
  MoveMasterToNewKey(cROOTKEYNEW);

  TAdapterAccess<TAitRoot>.Propagate(FRoot.This);

  Assert.AreEqual(cCHILDS, CountWithKey(FMidTable, cROOTKEYNEW),
    'EVERY child row must carry the key the database generated');
  Assert.AreEqual(0, CountWithKey(FMidTable, cROOTKEYOLD),
    'no child row may be left behind on the old key');
end;

procedure TTestAutoIncChilds.Linked_EveryGrandchildRowReceivesTheNewKey;
var
  LFor: Integer;
begin
  BuildTree(True);
  AddMasterRow(cROOTKEYOLD);
  // Every mid row carries the SAME own key, so the result does not depend on
  // which mid row the cursor happens to sit on when the recursion fires. That
  // is still true and still deliberate here - what it costs is that this test
  // cannot tell a correct per-parent distribution from a collapse onto one
  // parent. Issue #261 ran the case with three DIFFERENT keys instead: see
  // Linked_MidRowsWithDistinctKeys_EveryLeafGetsTheFirstMidRowKey.
  for LFor := 0 to cCHILDS - 1 do
    AddChildRow(FMidTable, cROOTKEYOLD, 'M' + IntToStr(LFor), True, cMIDOWNKEY);
  // The leaves start on mid_id = 0, and on the OLD root key.
  for LFor := 0 to cGRANDS - 1 do
    AddChildRow(FLeafTable, cROOTKEYOLD, 'L' + IntToStr(LFor));
  LinkAsRestClientDoes;
  MoveMasterToNewKey(cROOTKEYNEW);

  TAdapterAccess<TAitRoot>.Propagate(FRoot.This);

  // Level 3 first: counting level 2 would scroll it, and scrolling a master
  // re-opens its children.
  Assert.AreEqual(cGRANDS, CountWithColumn(FLeafTable, cOWNKEYFIELD, cMIDOWNKEY),
    'level 3 must be updated too - the recursion into each child adapter is ' +
    'the whole reason SetAutoIncValueChilds calls itself. What reaches the ' +
    'leaf is the MID key, because the mid association names the mid own key');
  // The other half of issue #244, and the reason `root_id` still exists on the
  // leaf: no association names it, so a cascade that wrote it would be
  // propagating an ANCESTOR key - a capability CascadeAutoInc does not offer.
  Assert.AreEqual(cGRANDS, CountWithKey(FLeafTable, cROOTKEYOLD),
    'the leaf root_id is denormalised and unlinked; the cascade must leave ' +
    'every one of them exactly as it found it');
  Assert.AreEqual(0, CountWithKey(FLeafTable, cROOTKEYNEW),
    'and not one leaf may come out carrying the ROOT new key');
  Assert.AreEqual(cCHILDS, CountWithKey(FMidTable, cROOTKEYNEW),
    'level 2 must be updated');
end;

procedure TTestAutoIncChilds.Linked_MasterDetailLinkIsRestored;
var
  LFor: Integer;
  LBefore: TObject;
begin
  BuildTree(True);
  AddMasterRow(cROOTKEYOLD);
  for LFor := 0 to cCHILDS - 1 do
    AddChildRow(FMidTable, cROOTKEYOLD, 'M' + IntToStr(LFor));
  for LFor := 0 to cGRANDS - 1 do
    AddChildRow(FLeafTable, cROOTKEYOLD, 'L' + IntToStr(LFor));
  LinkAsRestClientDoes;
  LBefore := GetObjectProp(FMidTable, cMASTERSOURCE);
  Assert.IsNotNull(LBefore, 'the fixture must really install the link');
  MoveMasterToNewKey(cROOTKEYNEW);

  TAdapterAccess<TAitRoot>.Propagate(FRoot.This);

  Assert.AreSame(LBefore, GetObjectProp(FMidTable, cMASTERSOURCE),
    'the child must be handed back exactly the MasterSource it had');
  Assert.IsNotNull(GetObjectProp(FLeafTable, cMASTERSOURCE),
    'the grandchild link must be restored as well');
  // The link must be LIVE again, not merely present: with the master on the
  // new key, the range must now show the children that were just re-stamped.
  Assert.AreEqual(cCHILDS, VisibleRowCount(FMidTable),
    'with the link restored the child set must range on the NEW master key');
end;

// ---------------------------------------------------------------------------
// Plain DataSet shape
// ---------------------------------------------------------------------------

procedure TTestAutoIncChilds.Unlinked_EveryChildRowReceivesTheNewKey;
var
  LFor: Integer;
begin
  // No MasterSource anywhere - this is what the non-REST DataSet family
  // (TFDMemTableAdapter / TClientDataSetAdapter) really looks like: nothing
  // under Source\Dataset ever assigns MasterSource.
  BuildTree(False);
  AddMasterRow(cROOTKEYOLD);
  for LFor := 0 to cCHILDS - 1 do
    AddChildRow(FMidTable, cROOTKEYOLD, 'M' + IntToStr(LFor));
  MoveMasterToNewKey(cROOTKEYNEW);

  TAdapterAccess<TAitRoot>.Propagate(FRoot.This);

  Assert.AreEqual(cCHILDS, CountWithKey(FMidTable, cROOTKEYNEW),
    'without a link the children were always visible; every one of them must ' +
    'still be updated');
end;

procedure TTestAutoIncChilds.Unlinked_IndexedByForeignKey_AllRowsStillUpdated;
var
  LFor: Integer;
  LMute: TScrollMute;
begin
  BuildTree(False);
  AddMasterRow(cROOTKEYOLD);
  for LFor := 0 to cCHILDS - 1 do
    AddChildRow(FMidTable, cROOTKEYOLD, 'M' + IntToStr(LFor));
  // An entity whose [OrderBy] is its foreign key gets exactly this index from
  // TFDMemTableAdapter<M>._GetIndexFieldNames. Writing the indexed column
  // re-sorts the row, so a Post+Next walk jumps past the end after row one.
  LMute := MuteScroll(FMidTable);
  try
    FMidTable.IndexFieldNames := cKEYFIELD;
  finally
    UnmuteScroll(FMidTable, LMute);
  end;
  MoveMasterToNewKey(cROOTKEYNEW);

  TAdapterAccess<TAitRoot>.Propagate(FRoot.This);

  Assert.AreEqual(cCHILDS, CountWithKey(FMidTable, cROOTKEYNEW),
    'a walk that trusts Next after writing the sort column updates ONE row; ' +
    'every row must be updated');
end;

// ---------------------------------------------------------------------------
// Scope: what must NOT be touched
// ---------------------------------------------------------------------------

procedure TTestAutoIncChilds.PersistedChildRow_IsNotRepointed;
var
  LFor: Integer;
begin
  BuildTree(False);
  AddMasterRow(cROOTKEYOLD);
  for LFor := 0 to cCHILDS - 1 do
    AddChildRow(FMidTable, cROOTKEYOLD, 'M' + IntToStr(LFor));
  // A child of ANOTHER, already saved master. In the REST client the child
  // memtable holds the children of every master the listing brought back.
  AddChildRow(FMidTable, cOTHERROOT, 'FOREIGN', False);
  MoveMasterToNewKey(cROOTKEYNEW);

  TAdapterAccess<TAitRoot>.Propagate(FRoot.This);

  Assert.AreEqual(cCHILDS, CountWithKey(FMidTable, cROOTKEYNEW),
    'the pending children must be updated');
  Assert.AreEqual(1, CountWithKey(FMidTable, cOTHERROOT),
    'a row that is already persisted belongs to another master; stamping the ' +
    'new key on it would silently re-parent someone else data');
end;

procedure TTestAutoIncChilds.AssociationWithoutCascadeAutoInc_IsNotTouched;
var
  LFor: Integer;
begin
  BuildTree(False, True);
  AddMasterRow(cROOTKEYOLD);
  for LFor := 0 to cCHILDS - 1 do
    AddChildRow(FMidTable, cROOTKEYOLD, 'M' + IntToStr(LFor));
  AddChildRow(FOtherTable, cROOTKEYOLD, '');
  MoveMasterToNewKey(cROOTKEYNEW);

  TAdapterAccess<TAitRoot>.Propagate(FRoot.This);

  Assert.AreEqual(cCHILDS, CountWithKey(FMidTable, cROOTKEYNEW),
    'the CascadeAutoInc association must be propagated');
  Assert.AreEqual(0, CountWithKey(FOtherTable, cROOTKEYNEW),
    'an association WITHOUT CascadeAutoInc must be left alone');
  Assert.AreEqual(1, CountWithKey(FOtherTable, cROOTKEYOLD),
    'its row must still carry the old key');
end;

procedure TTestAutoIncChilds.ChildDataSetNotRegistered_DoesNotRaise;
var
  LRootOnlyTable: TFDMemTable;
  LRootOnly: IContainerDataSet<TAitRoot>;
begin
  // TAitRoot declares CascadeAutoInc towards TAitMid, but no TAitMid dataset
  // was ever created. TDictionary.Items[] raises EListError on a missing key,
  // so the `if <> nil` guard that followed it could never be reached.
  LRootOnlyTable := TFDMemTable.Create(nil);
  try
    LRootOnly := TContainerFDMemTable<TAitRoot>.Create(FConn, LRootOnlyTable);
    LRootOnlyTable.Append;
    LRootOnlyTable.FieldByName(cKEYFIELD).AsInteger := cROOTKEYOLD;
    LRootOnlyTable.Post;
    LRootOnlyTable.Edit;
    LRootOnlyTable.FieldByName(cKEYFIELD).AsInteger := cROOTKEYNEW;
    Assert.WillNotRaise(
      procedure
      begin
        TAdapterAccess<TAitRoot>.Propagate(LRootOnly.This);
      end,
      EListError,
      'a CascadeAutoInc association whose child dataset does not exist must ' +
      'be skipped, not blow up the insert of the master');
    LRootOnly := nil;
  finally
    LRootOnlyTable.Free;
  end;
end;

// ---------------------------------------------------------------------------
// Issue #261 - WHICH master row's key reaches the pending child rows
// ---------------------------------------------------------------------------

/// Builds root + three mid rows carrying THREE DIFFERENT own keys + two leaf
/// rows starting on a key no mid row has, and arms the probe on both levels.
/// Mid rows go in before leaf rows because appending to the mid scrolls it, and
/// TDataSetAdapter<M>.DoAfterScroll re-opens - that is, empties - its children.
procedure TTestAutoIncChilds.BuildDistinctKeyTree(const ALinked: Boolean;
  const AMidRows: Integer; const ALeafRows: Integer);
var
  LFor: Integer;
begin
  BuildTree(True);
  AddMasterRow(cROOTKEYOLD);
  for LFor := 0 to AMidRows - 1 do
    AddChildRow(FMidTable, cROOTKEYOLD, 'M' + IntToStr(LFor), True,
                cMIDKEYFIRST + LFor);
  for LFor := 0 to ALeafRows - 1 do
    AddChildRow(FLeafTable, cROOTKEYOLD, 'L' + IntToStr(LFor), True, cLEAFSTART);
  if ALinked then
    LinkAsRestClientDoes;
  MoveMasterToNewKey(cROOTKEYNEW);
  ArmWriteProbe(cLEVELMID, FMidTable, cKEYFIELD, FRootTable, cKEYFIELD);
  ArmWriteProbe(cLEVELLEAF, FLeafTable, cOWNKEYFIELD, FMidTable, cOWNKEYFIELD);
end;

/// The two DataSet-family tests below assert the same four things about the
/// same run, so the wording lives once.
procedure TTestAutoIncChilds.AssertLeavesCollapsedOntoTheFirstMidRow;
var
  LMid: TArray<TCascadeWrite>;
  LLeaf: TArray<TCascadeWrite>;
  LFor: Integer;
begin
  LMid := WritesAt(cLEVELMID);
  LLeaf := WritesAt(cLEVELLEAF);

  // The probe has to have seen something, or every clause below is vacuous.
  Assert.AreEqual(cCHILDS, Length(LMid),
    'the probe must have observed one write per mid row - ' + WriteLog);
  Assert.AreEqual(cGRANDS, Length(LLeaf),
    'the probe must have observed one write per leaf row - ' + WriteLog);

  // WHICH mid row was processed LAST. Measured, not assumed, and it is the
  // reading the leaf result has to be told apart from.
  Assert.AreEqual('M' + IntToStr(cCHILDS - 1), LMid[Length(LMid) - 1].ChildTag,
    'the LAST mid row the cascade touched must be the last one added - ' +
    WriteLog);

  for LFor := 0 to Length(LLeaf) - 1 do
  begin
    // The instrumented half: this is read INSIDE the write, so it names the
    // row the cascade was standing on, not the row it ended on.
    Assert.AreEqual('M0', LLeaf[LFor].MasterTag,
      'every leaf write must have been taken from the FIRST mid row - ' +
      WriteLog);
    Assert.AreEqual(cMIDKEYFIRST, LLeaf[LFor].MasterKey,
      'and that row must be the one carrying the first key - ' + WriteLog);
    Assert.AreEqual(cMIDKEYFIRST, LLeaf[LFor].Value,
      'so the value written is the first mid row key, NOT the last mid row ' +
      'processed - ' + WriteLog);
  end;

  // And the rows agree with the probe, which is the cross-check that the
  // instrumentation is describing this run and not a different one.
  Assert.AreEqual(cGRANDS, CountWithColumn(FLeafTable, cOWNKEYFIELD, cMIDKEYFIRST),
    'both leaves end up parented to the first mid row');
  Assert.AreEqual(0, CountWithColumn(FLeafTable, cOWNKEYFIELD, cMIDKEYMIDDLE),
    'none is parented to the middle mid row');
  Assert.AreEqual(0, CountWithColumn(FLeafTable, cOWNKEYFIELD, cMIDKEYLAST),
    'and none to the last one - which is what a last-writer-wins walk would ' +
    'have produced');
  Assert.AreEqual(0, CountWithColumn(FLeafTable, cOWNKEYFIELD, cLEAFSTART),
    'and no leaf was simply left alone');
end;

procedure TTestAutoIncChilds.Linked_MidRowsWithDistinctKeys_EveryLeafGetsTheFirstMidRowKey;
begin
  BuildDistinctKeyTree(True, cCHILDS, cGRANDS);

  // THE RANGE DOES NOT PROTECT ANYTHING, and this is the number that says so:
  // the link is live, the mid cursor is on a row whose key no leaf carries, so
  // the leaf set the user can SEE is empty - and both leaves are written all
  // the same, because _AutoIncToChildRows detaches the link before it walks.
  Assert.AreEqual(0, VisibleRowCount(FLeafTable),
    'PREMISE: with the link live not one leaf row is inside the range');

  TAdapterAccess<TAitRoot>.Propagate(FRoot.This);
  DisarmWriteProbe;

  AssertLeavesCollapsedOntoTheFirstMidRow;
end;

procedure TTestAutoIncChilds.Unlinked_MidRowsWithDistinctKeys_EveryLeafGetsTheFirstMidRowKey;
begin
  // No MasterSource anywhere - the plain TFDMemTableAdapter / TClientDataSet
  // shape. Nothing under Source\Dataset ever assigns MasterSource, so if the
  // collapse survives here it is not an artefact of the REST client's wiring.
  BuildDistinctKeyTree(False, cCHILDS, cGRANDS);

  TAdapterAccess<TAitRoot>.Propagate(FRoot.This);
  DisarmWriteProbe;

  AssertLeavesCollapsedOntoTheFirstMidRow;
end;

procedure TTestAutoIncChilds.SingleMidRow_TheOnlyKeyReachesTheLeaves_DEGENERATE;
var
  LLeaf: TArray<TCascadeWrite>;
  LFor: Integer;
begin
  // WHAT THIS CASE DOES NOT DO. With one mid row there is exactly one key the
  // recursion could possibly carry, so this test cannot distinguish a correct
  // per-parent distribution from the collapse the two tests above measure, and
  // it is not written as if it could. What it does hold is the floor: the
  // recursion still fires, and still writes, when the collapse has nothing to
  // collapse - so a green pair above is not explained by "it never writes".
  BuildDistinctKeyTree(True, 1, cGRANDS);

  TAdapterAccess<TAitRoot>.Propagate(FRoot.This);
  DisarmWriteProbe;

  LLeaf := WritesAt(cLEVELLEAF);
  Assert.AreEqual(cGRANDS, Length(LLeaf),
    'the recursion must still write every leaf when there is a single mid ' +
    'row - ' + WriteLog);
  for LFor := 0 to Length(LLeaf) - 1 do
    Assert.AreEqual(cMIDKEYFIRST, LLeaf[LFor].Value,
      'and the only key available is the one that arrives - ' + WriteLog);
end;

procedure TTestAutoIncChilds.NoPendingLeafRow_TheProbeRecordsNoWriteAtAll;
begin
  // META-CHECK OF THE INSTRUMENT, not of the framework. Every other clause in
  // this section reads a write COUNT, and a probe that cannot report zero would
  // make all of them unfalsifiable. The mid level still has its three rows, so
  // this is not an empty run: the mid writes are observed and the leaf ones are
  // not, in the same execution.
  BuildDistinctKeyTree(True, cCHILDS, 0);

  TAdapterAccess<TAitRoot>.Propagate(FRoot.This);
  DisarmWriteProbe;

  Assert.AreEqual(cCHILDS, Length(WritesAt(cLEVELMID)),
    'the mid level must still have been written - ' + WriteLog);
  Assert.AreEqual(0, Length(WritesAt(cLEVELLEAF)),
    'and with no leaf row to stamp the probe must report ZERO, not silence - ' +
    WriteLog);
end;

procedure TTestAutoIncChilds.TwoPendingMasterRows_EveryPendingChildEndsOnTheLastMasterKey;
var
  LFor: Integer;
  LMid: TArray<TCascadeWrite>;
  LInternal: TField;
begin
  // WHY THIS IS THE SHIPPED CONFIGURATION, and not a shape invented to fail.
  // TFDMemTableAdapter<M>.ApplyInserter filters the master on
  // InternalField = dsInsert and loops WHILE THERE ARE ROWS LEFT, calling
  // SetAutoIncValueChilds once per pending master row. The child rows are not
  // marked saved in that loop - TFDMemTableAdapter<M>.ApplyInternal only
  // reaches each child's own ApplyInternal AFTER the master loop has finished -
  // so every iteration finds the same pending child rows again. The assertion
  // on InternalField below is that fact measured rather than read.
  BuildTree(False);
  AddMasterRow(cROOTKEYOLD);
  AddMasterRow(cROOTKEYOLD);
  for LFor := 0 to cCHILDS - 1 do
    AddChildRow(FMidTable, cROOTKEYOLD, 'M' + IntToStr(LFor), True,
                cMIDKEYFIRST + LFor);
  ArmWriteProbe(cLEVELMID, FMidTable, cKEYFIELD, FRootTable, cKEYFIELD);

  // The shipped mute, for the same reason ApplyInternal installs it: without it
  // moving the master cursor re-opens the children and there is nothing left to
  // measure. This is the one liberty the fixture takes with the call sequence,
  // and it takes it with the framework's own method.
  TAdapterAccess<TAitRoot>.MuteAdapter(FRoot.This);
  try
    FRootTable.First;
    FRootTable.Edit;
    FRootTable.FieldByName(cKEYFIELD).AsInteger := cROOTKEYNEW;
    TAdapterAccess<TAitRoot>.Propagate(FRoot.This);
    FRootTable.Post;

    LInternal := FMidTable.FindField('InternalField');
    Assert.IsNotNull(LInternal, 'the adapter must create the internal field');
    FMidTable.First;
    Assert.AreEqual(Integer(dsInsert), LInternal.AsInteger,
      'the child rows must STILL be pending after the first master row was ' +
      'stamped - if they were not, the second pass could not touch them');

    FRootTable.Last;
    FRootTable.Edit;
    FRootTable.FieldByName(cKEYFIELD).AsInteger := cROOTKEYB;
    TAdapterAccess<TAitRoot>.Propagate(FRoot.This);
    FRootTable.Post;
  finally
    TAdapterAccess<TAitRoot>.UnmuteAdapter(FRoot.This);
  end;
  DisarmWriteProbe;

  LMid := WritesAt(cLEVELMID);
  Assert.AreEqual(cCHILDS * 2, Length(LMid),
    'every child row must have been written ONCE PER PENDING MASTER ROW - ' +
    WriteLog);
  for LFor := 0 to cCHILDS - 1 do
    Assert.AreEqual(cROOTKEYNEW, LMid[LFor].Value,
      'the first pass parents them all on the first master row - ' + WriteLog);
  for LFor := cCHILDS to (cCHILDS * 2) - 1 do
    Assert.AreEqual(cROOTKEYB, LMid[LFor].Value,
      'and the second pass re-parents the very same rows on the second - ' +
      WriteLog);

  Assert.AreEqual(0, CountWithKey(FMidTable, cROOTKEYNEW),
    'not one child is left on the first master key');
  Assert.AreEqual(cCHILDS, CountWithKey(FMidTable, cROOTKEYB),
    'they all end up on the LAST pending master row - which is the answer to ' +
    'the second half of issue #261 at this level: last writer wins');
end;

// ---------------------------------------------------------------------------
// The other family
// ---------------------------------------------------------------------------

procedure TTestAutoIncChilds.ObjectSet_EveryChildObjectReceivesTheNewKey;
var
  LAdapter: TObjectSetAdapter<TAitRoot>;
  LRoot: TAitRoot;
  LMid: TAitMid;
  LPrimaryKey: TPrimaryKeyColumnsMapping;
  LFor: Integer;
  LSeen: Integer;
begin
  // TObjectSetBaseAdapter<M>.SetAutoIncValueChilds writes straight into the
  // objects of the association list by RTTI. There is no cursor to advance and
  // no MasterSource to hide anything, so the two defects pinned above have no
  // room to exist here. This test is what makes that a MEASUREMENT rather than
  // a reading, and a guard if anyone ever routes this family through a dataset.
  LRoot := TAitRoot.Create;
  LAdapter := TObjectSetAdapter<TAitRoot>.Create(FConn);
  try
    for LFor := 0 to cCHILDS - 1 do
    begin
      LMid := TAitMid.Create;
      LMid.root_id := cROOTKEYOLD;
      LRoot.mids.Add(LMid);
    end;
    // The key the database has just generated for the master.
    LRoot.root_id := cROOTKEYNEW;
    LPrimaryKey := TMappingExplorer.GetMappingPrimaryKeyColumns(TAitRoot);
    Assert.IsNotNull(LPrimaryKey, 'TAitRoot must expose a primary key mapping');

    TObjectSetAccess<TAitRoot>.Propagate(LAdapter, LRoot,
                                         LPrimaryKey.Columns[0]);

    LSeen := 0;
    for LFor := 0 to LRoot.mids.Count - 1 do
      if LRoot.mids[LFor].root_id = cROOTKEYNEW then
        Inc(LSeen);
    Assert.AreEqual(cCHILDS, LSeen,
      'every child OBJECT must carry the new key - if this ever goes red the ' +
      'ObjectSet family stopped being immune and needs its own fix');
  finally
    LAdapter.Free;
    LRoot.Free;
  end;
end;

procedure TTestAutoIncChilds.ObjectSet_EveryGrandchildObjectReceivesTheMidKey;
var
  LAdapter: TObjectSetAdapter<TAitMid>;
  LMid: TAitMid;
  LLeaf: TAitLeaf;
  LPrimaryKey: TPrimaryKeyColumnsMapping;
  LFor: Integer;
  LSeen: Integer;
  LKept: Integer;
begin
  // WHY THIS LEVEL AND NOT THE ONE ABOVE. The column this family propagates is
  // not free: TObjectSetBaseAdapter<M>.SetAutoIncValueOneToMany resolves the
  // parent's OWN primary key property against the association's ColumnsName,
  // so only a column the parent's key names can ever be written. Before issue
  // #244 the mid level offered `root_id` while its key is `mid_id`: the lookup
  // matched nothing, so every leaf in the list was skipped by the loop's
  // Continue - the early Exit belongs to the OneToOne sibling, not here - and
  // none was written, with nothing raised. That shape is what this test would
  // not tolerate.
  LMid := TAitMid.Create;
  LAdapter := TObjectSetAdapter<TAitMid>.Create(FConn);
  try
    for LFor := 0 to cGRANDS - 1 do
    begin
      LLeaf := TAitLeaf.Create;
      LLeaf.mid_id := 0;
      LLeaf.root_id := cROOTKEYOLD;
      LMid.leafs.Add(LLeaf);
    end;
    // The key the database has just generated for the MID, and a root key that
    // differs from it, so a leaf carrying the wrong one is visible.
    LMid.mid_id := cMIDOWNKEY;
    LMid.root_id := cROOTKEYNEW;
    LPrimaryKey := TMappingExplorer.GetMappingPrimaryKeyColumns(TAitMid);
    Assert.IsNotNull(LPrimaryKey, 'TAitMid must expose a primary key mapping');

    TObjectSetAccess<TAitMid>.Propagate(LAdapter, LMid, LPrimaryKey.Columns[0]);

    LSeen := 0;
    LKept := 0;
    for LFor := 0 to LMid.leafs.Count - 1 do
    begin
      if LMid.leafs[LFor].mid_id = cMIDOWNKEY then
        Inc(LSeen);
      if LMid.leafs[LFor].root_id = cROOTKEYOLD then
        Inc(LKept);
    end;
    Assert.AreEqual(cGRANDS, LSeen,
      'every leaf OBJECT must carry the key its OWN parent generated - that ' +
      'is the whole of what CascadeAutoInc offers, and the fixture now models ' +
      'it');
    Assert.AreEqual(cGRANDS, LKept,
      'and none may pick up the ROOT key the mid also carries: no association ' +
      'names the leaf root_id, and an ancestor key is not something this ' +
      'framework propagates');
  finally
    LAdapter.Free;
    LMid.Free;
  end;
end;

procedure TTestAutoIncChilds.ObjectSet_TwoParentsWithDistinctKeys_NeitherChildListCollapses;
var
  LAdapter: TObjectSetAdapter<TAitMid>;
  LMids: TObjectList<TAitMid>;
  LMid: TAitMid;
  LLeaf: TAitLeaf;
  LPrimaryKey: TPrimaryKeyColumnsMapping;
  LFor: Integer;
  LRow: Integer;
begin
  // WHAT THIS MIRRORS. TObjectSetBaseAdapter<M>.OneToManyCascadeActionsExecute
  // calls SetAutoIncValueChilds ONCE PER CHILD OBJECT, right after that object
  // has been inserted and has its own key - so the loop below is the shape the
  // shipped cascade runs, not a shape chosen to pass.
  //
  // WHY IT CANNOT COLLAPSE THE WAY THE DATASET FAMILY DOES. There is no cursor:
  // SetAutoIncValueOneToMany reads the value with AProperty.GetValue(AObject),
  // where AObject is the parent OBJECT it was handed. Two parents are two
  // arguments, never two positions in one dataset.
  //
  // WHAT IT IS NOT. This does not run the cascade itself - that needs a live
  // FSession.Insert - so it does not prove the shipped call sequence reaches
  // here with the right objects. It measures the distribution step only.
  LMids := TObjectList<TAitMid>.Create;
  LAdapter := TObjectSetAdapter<TAitMid>.Create(FConn);
  try
    for LRow := 0 to cCHILDS - 1 do
    begin
      LMid := TAitMid.Create;
      LMid.mid_id := cMIDKEYFIRST + LRow;
      LMid.root_id := cROOTKEYNEW;
      for LFor := 0 to cGRANDS - 1 do
      begin
        LLeaf := TAitLeaf.Create;
        LLeaf.mid_id := cLEAFSTART;
        LLeaf.root_id := cROOTKEYOLD;
        LMid.leafs.Add(LLeaf);
      end;
      LMids.Add(LMid);
    end;
    LPrimaryKey := TMappingExplorer.GetMappingPrimaryKeyColumns(TAitMid);
    Assert.IsNotNull(LPrimaryKey, 'TAitMid must expose a primary key mapping');

    for LRow := 0 to LMids.Count - 1 do
      TObjectSetAccess<TAitMid>.Propagate(LAdapter, LMids[LRow],
                                          LPrimaryKey.Columns[0]);

    for LRow := 0 to LMids.Count - 1 do
      for LFor := 0 to LMids[LRow].leafs.Count - 1 do
        Assert.AreEqual(cMIDKEYFIRST + LRow, LMids[LRow].leafs[LFor].mid_id,
          'leaf ' + IntToStr(LFor) + ' of parent ' + IntToStr(LRow) +
          ' must carry ITS OWN parent key. The DataSet family, measured in ' +
          'the same file with the same three keys, hands every leaf the ' +
          'FIRST parent key instead - that divergence is the finding');
  finally
    LAdapter.Free;
    LMids.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestAutoIncChilds);

end.
