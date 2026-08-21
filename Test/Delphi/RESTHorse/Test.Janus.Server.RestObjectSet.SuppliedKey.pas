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

{ @abstract(Janus Framework - the ExistSequence guard the server copy wraps
  around its cascade propagation, issue #240.)

  WHAT IS UNDER TEST

  TRESTObjectSet.OneToManyCascadeActionsExecute, the CascadeInsert branch. The
  server copy wraps the propagation that follows FSession.Insert in
  `if FSession.ExistSequence then`. The base adapter,
  TObjectSetBaseAdapter<M>.OneToManyCascadeActionsExecute, propagates
  unconditionally.

  WHAT ExistSequence ACTUALLY REPORTS

  Measured by reading the chain: TRESTObjectSetSession.ExistSequence ->
  TRESTObjectManager.ExistSequence -> TDMLCommandFactory.ExistSequence ->
  TCommandInserter.AutoInc.ExistSequence. That last flag is a FIELD of a
  TCommandInserter that TDMLCommandFactory creates ONCE, in its constructor,
  and TRESTObjectManager creates its factory ONCE, also in its constructor.
  Nothing rebuilds either per entity.

  The flag is written in exactly one place, TCommandInserter.GenerateInsert,
  and only when the row being inserted has an AutoInc / SequenceInc primary key
  whose current value is null, empty or <= 0. It is never cleared. So it does
  not report "this entity has autoinc"; it reports "the last insert that
  reached the generator branch found a sequence" - and when no insert has
  reached that branch yet, it reports the initial False.

  THE SHAPE THAT MAKES THAT VISIBLE

  A caller that supplies its own keys. The framework supports this on purpose:
  the generator branch is entered only when the current value is <= 0, so a
  positive key that arrived in the request body is written as it stands. A REST
  server sees this constantly - a client PUTting or POSTing a nested payload
  that already carries its ids.

  With every key supplied, no insert enters the generator branch, ExistSequence
  is still the initial False, and the guard closes over the propagation. The
  children of the branch then reach the database with their foreign key at
  zero, silently - the same orphan the three merged fixes were about, reached
  by a fourth path.

  WHERE THE FLAG IS READ, MEASURED RATHER THAN ASSUMED

  A first version of this suite asserted the flag was False after the whole
  tree had been written, and that assertion went RED: by then it reads True.
  The LEAVES carry no supplied key, so their inserts DO enter the generator
  branch and set the flag - after the branch above them had already been
  stamped, or not stamped. That is the audit finding stated as sharply as it
  can be: the flag was flipped by a DIFFERENT entity than the guard it feeds
  was standing in front of. The premises below therefore read it at the moment
  the guard is evaluated, with a tree that stops at the branch, and separately
  record that it flips afterwards.

  BOTH HANDLERS, NOT ONE

  The guard stood in front of the propagation in BOTH cascade handlers, and
  CascadeActionsExecute picks between them by the multiplicity of the TOP
  association. Two fixtures live here for that reason - the same three levels,
  a list at the top in one and a single object in the other.

  WHAT THIS SUITE DELIBERATELY DOES NOT ASSERT

  The branch's own foreign key onto the root, atmid.mparent, is set by the test.
  The master level stamp in TRESTObjectSet.Insert is wrapped in the SAME guard,
  and so is the base's - TObjectSetAdapter<M>.Insert carries it too. That one
  is therefore NOT a divergence, and asserting it here would make this suite
  fail for something the two implementations agree on.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Server.RestObjectSet.SuppliedKey;

interface

uses
  Classes,
  SysUtils,
  Variants,
  IOUtils,
  Generics.Collections,
  DUnitX.TestFramework,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Comp.Client,
  DataEngine.FactoryInterfaces,
  Janus.Server.RestObjectSet,
  Test.Janus.Model.AsymTree;

type
  [TestFixture]
  TTestServerRestObjectSetSuppliedKey = class
  private
    FDConnection: TFDConnection;
    FConnection: IDBConnection;
    FDbFile: string;
    FObjectSet: TRESTObjectSet;
    FRoot: TAsymTreeRoot;
    function _ScalarInt(const ASQL: string): Integer;
    procedure _InsertATreeWhoseKeysWereAllSupplied;
    procedure _InsertATreeWhoseKeysAreGenerated;
    procedure _InsertABranchWithNoLeaves;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Premise_SuppliedKeysAreWrittenAsTheyStand;
    [Test]
    procedure Premise_TheGuardIsClosedAtTheMomentTheBranchWouldBeStamped;
    [Test]
    procedure Premise_TheFlagReportsTheLastInsertNotTheEntityInHand;
    [Test]
    procedure Control_TheSameTreeWithGeneratedKeysDoesPropagate;
    [Test]
    procedure TheBranchKeyMustReachItsOwnChildrenEvenWhenItWasSupplied;
    [Test]
    procedure TheBranchKeyMustReachTheDatabaseRowsEvenWhenItWasSupplied;
  end;

  /// The same question routed through OneToOneCascadeActionsExecute.
  [TestFixture]
  TTestServerRestObjectSetSuppliedKeyOneToOne = class
  private
    FDConnection: TFDConnection;
    FConnection: IDBConnection;
    FDbFile: string;
    FObjectSet: TRESTObjectSet;
    FRoot: TAsymTreeOneRoot;
    function _ScalarInt(const ASQL: string): Integer;
    procedure _InsertATreeWhoseKeysWereAllSupplied;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Premise_SuppliedKeysAreWrittenAsTheyStand;
    [Test]
    procedure TheBranchKeyMustReachItsOwnChildrenEvenWhenItWasSupplied;
    [Test]
    procedure TheBranchKeyMustReachTheDatabaseRowsEvenWhenItWasSupplied;
  end;

implementation

uses
  DataEngine.FactoryFireDAC;

const
  cDBFILE   = 'janus_server_objectset_suppliedkey.db';
  cLEAFS    = 3;
  cROOTKEY  = 500;
  cMIDKEY   = 600;
  cROOTTAG  = 'root';
  cMIDTAG   = 'mid';
  cLEAFTAG  = 'leaf';

  cDDL_ROOT =
    'CREATE TABLE IF NOT EXISTS atroot (' +
    '  rkey INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  rtag VARCHAR(20)' +
    ')';
  cDDL_MID =
    'CREATE TABLE IF NOT EXISTS atmid (' +
    '  mkey    INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  mparent INTEGER,' +
    '  mtag    VARCHAR(20)' +
    ')';
  cDDL_LEAF =
    'CREATE TABLE IF NOT EXISTS atleaf (' +
    '  lkey    INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  lparent INTEGER,' +
    '  ltag    VARCHAR(20)' +
    ')';

  cDBFILE_ONE = 'janus_server_objectset_suppliedkey_onetoone.db';
  cDDL_PAIR =
    'CREATE TABLE IF NOT EXISTS atpair (' +
    '  pkey INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  ptag VARCHAR(20)' +
    ')';

{ TTestServerRestObjectSetSuppliedKey }

procedure TTestServerRestObjectSetSuppliedKey.Setup;
begin
  FDbFile := cDBFILE;
  if TFile.Exists(FDbFile) then
    TFile.Delete(FDbFile);
  FDConnection := TFDConnection.Create(nil);
  FDConnection.Params.DriverID := 'SQLite';
  FDConnection.Params.Database := FDbFile;
  FDConnection.Params.Values['OpenMode'] := 'CreateUTF8';
  FDConnection.ResourceOptions.SilentMode := True;
  FDConnection.Connected := True;
  FConnection := TFactoryFireDAC.Create(FDConnection, dnSQLite);
  FConnection.ExecuteDirect(cDDL_ROOT);
  FConnection.ExecuteDirect(cDDL_MID);
  FConnection.ExecuteDirect(cDDL_LEAF);
end;

procedure TTestServerRestObjectSetSuppliedKey.TearDown;
begin
  FRoot.Free;
  FRoot := nil;
  FObjectSet.Free;
  FObjectSet := nil;
  FConnection := nil;
  if Assigned(FDConnection) then
  begin
    FDConnection.Connected := False;
    FreeAndNil(FDConnection);
  end;
  if TFile.Exists(FDbFile) then
    TFile.Delete(FDbFile);
end;

function TTestServerRestObjectSetSuppliedKey._ScalarInt(const ASQL: string): Integer;
var
  LValue: Variant;
begin
  LValue := FDConnection.ExecSQLScalar(ASQL);
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Result := -1
  else
    Result := LValue;
end;

procedure TTestServerRestObjectSetSuppliedKey._InsertATreeWhoseKeysWereAllSupplied;
var
  LMid: TAsymTreeMid;
  LLeaf: TAsymTreeLeaf;
  LFor: Integer;
begin
  FObjectSet := TRESTObjectSet.Create(FConnection, TAsymTreeRoot);
  FRoot := TAsymTreeRoot.Create;
  FRoot.rkey := cROOTKEY;
  FRoot.rtag := cROOTTAG;
  LMid := TAsymTreeMid.Create;
  LMid.mkey := cMIDKEY;
  LMid.mtag := cMIDTAG;
  // Set by the caller on purpose - see the header block.
  LMid.mparent := cROOTKEY;
  for LFor := 0 to cLEAFS - 1 do
  begin
    LLeaf := TAsymTreeLeaf.Create;
    LLeaf.ltag := cLEAFTAG + IntToStr(LFor);
    LMid.leafs.Add(LLeaf);
  end;
  FRoot.mids.Add(LMid);
  FObjectSet.Insert(FRoot);
end;

procedure TTestServerRestObjectSetSuppliedKey._InsertABranchWithNoLeaves;
var
  LMid: TAsymTreeMid;
begin
  // The same tree TRUNCATED at the branch. Every insert it performs carries a
  // supplied key, so the flag it leaves behind is the flag the branch's guard
  // read in the full tree - before the leaves existed to change it.
  FObjectSet := TRESTObjectSet.Create(FConnection, TAsymTreeRoot);
  FRoot := TAsymTreeRoot.Create;
  FRoot.rkey := cROOTKEY;
  FRoot.rtag := cROOTTAG;
  LMid := TAsymTreeMid.Create;
  LMid.mkey := cMIDKEY;
  LMid.mtag := cMIDTAG;
  LMid.mparent := cROOTKEY;
  FRoot.mids.Add(LMid);
  FObjectSet.Insert(FRoot);
end;

procedure TTestServerRestObjectSetSuppliedKey._InsertATreeWhoseKeysAreGenerated;
var
  LMid: TAsymTreeMid;
  LLeaf: TAsymTreeLeaf;
  LFor: Integer;
begin
  FObjectSet := TRESTObjectSet.Create(FConnection, TAsymTreeRoot);
  FRoot := TAsymTreeRoot.Create;
  FRoot.rtag := cROOTTAG;
  LMid := TAsymTreeMid.Create;
  LMid.mtag := cMIDTAG;
  for LFor := 0 to cLEAFS - 1 do
  begin
    LLeaf := TAsymTreeLeaf.Create;
    LLeaf.ltag := cLEAFTAG + IntToStr(LFor);
    LMid.leafs.Add(LLeaf);
  end;
  FRoot.mids.Add(LMid);
  FObjectSet.Insert(FRoot);
end;

procedure TTestServerRestObjectSetSuppliedKey.Premise_SuppliedKeysAreWrittenAsTheyStand;
begin
  // The control on the fixture's premise: the framework must honour a key the
  // caller supplied rather than replacing it. If it overwrote them, no insert
  // in this shape would skip the generator branch and the guard would never be
  // closed - the suite would measure nothing.
  _InsertATreeWhoseKeysWereAllSupplied;
  Assert.AreEqual(cROOTKEY, FRoot.rkey,
    'the root key supplied by the caller must survive the insert');
  Assert.AreEqual(cMIDKEY, FRoot.mids[0].mkey,
    'the branch key supplied by the caller must survive the insert');
  Assert.AreEqual(1, _ScalarInt('SELECT COUNT(*) FROM atmid WHERE mkey = ' +
                                IntToStr(cMIDKEY)),
    'the branch row must carry the supplied key');
end;

procedure TTestServerRestObjectSetSuppliedKey.Premise_TheGuardIsClosedAtTheMomentTheBranchWouldBeStamped;
begin
  // Names the mechanism instead of assuming it, and reads the flag WHERE the
  // guard reads it. If it came back True here the guard would be open and a red
  // assertion below would be pointing at the wrong cause.
  _InsertABranchWithNoLeaves;
  Assert.IsFalse(FObjectSet.ExistSequence,
    'with every key supplied no insert reaches the generator branch, so the ' +
    'flag the guard reads is still the initial False');
end;

procedure TTestServerRestObjectSetSuppliedKey.Premise_TheFlagReportsTheLastInsertNotTheEntityInHand;
begin
  // The audit finding, measured. The same tree one level deeper: the leaves
  // carry no supplied key, their inserts DO reach the generator branch, and the
  // flag ends up True - having been False when the branch above them was
  // stamped. One flag, written by whichever row was inserted last, read as
  // though it described the row in hand.
  _InsertATreeWhoseKeysWereAllSupplied;
  Assert.IsTrue(FObjectSet.ExistSequence,
    'the leaves flip the flag AFTER the branch was stamped - the flag is the ' +
    'state of the last insert, not a fact about the entity being propagated');
end;

procedure TTestServerRestObjectSetSuppliedKey.Control_TheSameTreeWithGeneratedKeysDoesPropagate;
begin
  // The independent witness. The identical tree, differing only in who chose
  // the keys, propagates today. That is what keeps this suite from being read
  // as "propagation is broken" rather than "the guard closes over it".
  _InsertATreeWhoseKeysAreGenerated;
  Assert.AreEqual(cLEAFS,
    _ScalarInt('SELECT COUNT(*) FROM atleaf WHERE lparent = ' +
               IntToStr(FRoot.mids[0].mkey)),
    'with generated keys every leaf row points at its branch');
end;

procedure TTestServerRestObjectSetSuppliedKey.TheBranchKeyMustReachItsOwnChildrenEvenWhenItWasSupplied;
var
  LFor: Integer;
  LSeen: Integer;
begin
  // The site. Whoever chose the branch's key, it is that key its leaves are
  // waiting for. The propagation is the only step that writes it and it runs
  // before the leaves are inserted.
  _InsertATreeWhoseKeysWereAllSupplied;
  LSeen := 0;
  for LFor := 0 to FRoot.mids[0].leafs.Count - 1 do
    if FRoot.mids[0].leafs[LFor].lparent = cMIDKEY then
      Inc(LSeen);
  Assert.AreEqual(cLEAFS, LSeen,
    'every leaf must carry the branch key - a leaf holding zero means the ' +
    'guard skipped the propagation for a branch that has one');
end;

procedure TTestServerRestObjectSetSuppliedKey.TheBranchKeyMustReachTheDatabaseRowsEvenWhenItWasSupplied;
begin
  // The same step measured where it hurts: the leaves are written after the
  // propagation would have run, so what it skipped is what the database keeps.
  _InsertATreeWhoseKeysWereAllSupplied;
  Assert.AreEqual(cLEAFS,
    _ScalarInt('SELECT COUNT(*) FROM atleaf WHERE lparent = ' +
               IntToStr(cMIDKEY)),
    'every leaf ROW must point at the branch - a row holding zero is an orphan');
end;

{ TTestServerRestObjectSetSuppliedKeyOneToOne }

procedure TTestServerRestObjectSetSuppliedKeyOneToOne.Setup;
begin
  FDbFile := cDBFILE_ONE;
  if TFile.Exists(FDbFile) then
    TFile.Delete(FDbFile);
  FDConnection := TFDConnection.Create(nil);
  FDConnection.Params.DriverID := 'SQLite';
  FDConnection.Params.Database := FDbFile;
  FDConnection.Params.Values['OpenMode'] := 'CreateUTF8';
  FDConnection.ResourceOptions.SilentMode := True;
  FDConnection.Connected := True;
  FConnection := TFactoryFireDAC.Create(FDConnection, dnSQLite);
  FConnection.ExecuteDirect(cDDL_PAIR);
  FConnection.ExecuteDirect(cDDL_MID);
  FConnection.ExecuteDirect(cDDL_LEAF);
end;

procedure TTestServerRestObjectSetSuppliedKeyOneToOne.TearDown;
begin
  FRoot.Free;
  FRoot := nil;
  FObjectSet.Free;
  FObjectSet := nil;
  FConnection := nil;
  if Assigned(FDConnection) then
  begin
    FDConnection.Connected := False;
    FreeAndNil(FDConnection);
  end;
  if TFile.Exists(FDbFile) then
    TFile.Delete(FDbFile);
end;

function TTestServerRestObjectSetSuppliedKeyOneToOne._ScalarInt(const ASQL: string): Integer;
var
  LValue: Variant;
begin
  LValue := FDConnection.ExecSQLScalar(ASQL);
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Result := -1
  else
    Result := LValue;
end;

procedure TTestServerRestObjectSetSuppliedKeyOneToOne._InsertATreeWhoseKeysWereAllSupplied;
var
  LMid: TAsymTreeMid;
  LLeaf: TAsymTreeLeaf;
  LFor: Integer;
begin
  FObjectSet := TRESTObjectSet.Create(FConnection, TAsymTreeOneRoot);
  FRoot := TAsymTreeOneRoot.Create;
  FRoot.pkey := cROOTKEY;
  FRoot.ptag := cROOTTAG;
  LMid := TAsymTreeMid.Create;
  LMid.mkey := cMIDKEY;
  LMid.mtag := cMIDTAG;
  // Set by the caller on purpose - see the header block.
  LMid.mparent := cROOTKEY;
  for LFor := 0 to cLEAFS - 1 do
  begin
    LLeaf := TAsymTreeLeaf.Create;
    LLeaf.ltag := cLEAFTAG + IntToStr(LFor);
    LMid.leafs.Add(LLeaf);
  end;
  FRoot.mid := LMid;
  FObjectSet.Insert(FRoot);
end;

procedure TTestServerRestObjectSetSuppliedKeyOneToOne.Premise_SuppliedKeysAreWrittenAsTheyStand;
begin
  _InsertATreeWhoseKeysWereAllSupplied;
  Assert.AreEqual(cROOTKEY, FRoot.pkey,
    'the root key supplied by the caller must survive the insert');
  Assert.AreEqual(cMIDKEY, FRoot.mid.mkey,
    'the branch key supplied by the caller must survive the insert');
end;

procedure TTestServerRestObjectSetSuppliedKeyOneToOne.TheBranchKeyMustReachItsOwnChildrenEvenWhenItWasSupplied;
var
  LFor: Integer;
  LSeen: Integer;
begin
  // The site, on the handler the OTHER fixture cannot reach.
  _InsertATreeWhoseKeysWereAllSupplied;
  LSeen := 0;
  for LFor := 0 to FRoot.mid.leafs.Count - 1 do
    if FRoot.mid.leafs[LFor].lparent = cMIDKEY then
      Inc(LSeen);
  Assert.AreEqual(cLEAFS, LSeen,
    'every leaf must carry the branch key - a leaf holding zero means the ' +
    'guard skipped the propagation for a branch that has one');
end;

procedure TTestServerRestObjectSetSuppliedKeyOneToOne.TheBranchKeyMustReachTheDatabaseRowsEvenWhenItWasSupplied;
begin
  _InsertATreeWhoseKeysWereAllSupplied;
  Assert.AreEqual(cLEAFS,
    _ScalarInt('SELECT COUNT(*) FROM atleaf WHERE lparent = ' +
               IntToStr(cMIDKEY)),
    'every leaf ROW must point at the branch - a row holding zero is an orphan');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestServerRestObjectSetSuppliedKey);
  TDUnitX.RegisterTestFixture(TTestServerRestObjectSetSuppliedKeyOneToOne);

end.
