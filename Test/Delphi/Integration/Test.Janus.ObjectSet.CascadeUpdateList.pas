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

{ @abstract(Janus Framework - autoinc propagation on the UPDATE leg of the
  ObjectSet OneToMany cascade, issue #242.)

  WHAT IS UNDER TEST

  TObjectSetBaseAdapter<M>.OneToManyCascadeActionsExecute, the CascadeUpdate
  branch, and inside it the `else` leg - the one that runs when a child of the
  list is NOT in the state snapshot Modify took. Every caller that adds a
  detail line to a master it has just Modify'd lands there: the detail has no
  entry in FObjectState, so it is inserted rather than updated.

  The leg inserts the detail. What happens NEXT is the question. The sibling
  branch in the SAME method - the CascadeInsert one - inserts and then reads
  the CHILD's primary key mapping and hands every column of it to
  SetAutoIncValueChilds, which stamps the child's freshly generated key onto
  the child's OWN children. This leg stopped at the insert.

  This is the same shape, character for character, that the server side copy
  carries in Janus.Server.RestObjectSet. Neither one derives from the other at
  runtime; they are two independent sites and each one needs its own
  measurement, which is why this suite exists alongside
  Test.Janus.Server.RestObjectSet.CascadeUpdateList in Janus.Tests.RESTHorse.

  WHY THE LIST SHAPE IS NOT THE SAME MEASUREMENT AS THE SINGLE-OBJECT ONE

  The single-object handler inserts one child. This one walks a list and
  inserts N, each with children of its own, and each one recurses into
  CascadeActionsExecute at the bottom of the SAME iteration. So a propagation
  that ran once outside the loop, or that ran after the loop, would leave every
  detail but one holding a stale or zero key. The assertions below therefore
  measure EACH branch against ITS OWN key and require the two branch keys to
  differ, which is what makes "stamped the wrong branch's key" fail as loudly
  as "stamped nothing".

  WHY A LIVE DATABASE, AND WHY THIS PROJECT

  Test.Janus.AutoInc.Childs already drives TObjectSetBaseAdapter<M>'s
  SetAutoIncValueChilds directly through a protected-access descendant, against
  an inert connection double. That reaches the propagation ROUTINE but not the
  CALL SITE: the question here is whether the cascade calls it at all, which
  only the real Insert/Update path can answer, and that path needs a database
  that generates keys.

  Which project to put it in was measured, one project at a time from a cleaned
  tree, by whether the build leaves the .dcu behind. Janus.ObjectSet.Base.
  Adapter is compiled by Janus.Tests.Units and by Janus.Tests.RESTfulDriver -
  the latter through the REST client adapter, which descends from it - and
  Janus.ObjectSet.Adapter, the concrete class this suite drives, by
  Janus.Tests.Units alone. Janus.Tests.RESTHorse, where the server side twin of
  this suite lives, compiles NEITHER, so this could not have joined it there.
  Neither project had a live database in the ObjectSet family before; this
  suite builds its own SQLite file.

  TContainerObjectSet<M> is used rather than TObjectSetAdapter<M> directly: it
  is the shipped entry point every caller goes through, and it forwards Modify
  and Update to the adapter untouched.

  WHAT THIS SUITE DELIBERATELY DOES NOT ASSERT

  The branch's own foreign key onto its master - atmid.mparent - is set by the
  test, not left to the framework, in the two site tests. The master level
  stamp is a separate site with its own suite (Test.Janus.ObjectSet.
  UpdateMasterKey), and asserting it here would make this suite fail for a
  second reason.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.ObjectSet.CascadeUpdateList;

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
  FireDAC.ConsoleUI.Wait,
  FireDAC.Phys.Intf,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Comp.Client,
  DataEngine.FactoryInterfaces,
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Explorer,
  MetaDbDiff.Types.Mapping,
  Janus.Container.ObjectSet,
  Janus.Container.ObjectSet.Interfaces,
  Test.Janus.Model.AsymTree;

type
  [TestFixture]
  TTestObjectSetCascadeUpdateList = class
  private
    FDConnection: TFDConnection;
    FConnection: IDBConnection;
    FDbFile: string;
    FRootKey: Integer;
    FObjectSet: IContainerObjectSet<TAsymTreeRoot>;
    FOld: TAsymTreeRoot;
    FNew: TAsymTreeRoot;
    function _ScalarInt(const ASQL: string): Integer;
    procedure _UpdateTheRootWithBrandNewBranches;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Premise_TheTopAssociationIsAListAndCascadesOnUpdate;
    [Test]
    procedure Premise_EveryBranchIsWrittenByTheInsertLegOfCascadeUpdate;
    [Test]
    procedure EveryInsertedBranchsOwnKeyMustReachItsOwnChildren;
    [Test]
    procedure EveryInsertedBranchsOwnKeyMustReachTheDatabaseRows;
  end;

implementation

uses
  DataEngine.FactoryFireDAC;

const
  cDBFILE     = 'janus_objectset_cascadeupdatelist.db';
  cMIDS       = 2;
  cLEAFS      = 3;
  cROOTTAG    = 'root';
  cROOTTAGNEW = 'rootedit';
  cMIDTAG     = 'mid';
  cLEAFTAG    = 'leaf';

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

{ TTestObjectSetCascadeUpdateList }

procedure TTestObjectSetCascadeUpdateList.Setup;
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
  // The stored row as it already stands, written with plain SQL so the master
  // exists without any cascade having run yet.
  FConnection.ExecuteDirect('INSERT INTO atroot (rtag) VALUES (' +
                            QuotedStr(cROOTTAG) + ')');
  FRootKey := _ScalarInt('SELECT MAX(rkey) FROM atroot');
end;

procedure TTestObjectSetCascadeUpdateList.TearDown;
begin
  FNew.Free;
  FNew := nil;
  FOld.Free;
  FOld := nil;
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

function TTestObjectSetCascadeUpdateList._ScalarInt(
  const ASQL: string): Integer;
var
  LValue: Variant;
begin
  LValue := FDConnection.ExecSQLScalar(ASQL);
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Result := -1
  else
    Result := LValue;
end;

procedure TTestObjectSetCascadeUpdateList._UpdateTheRootWithBrandNewBranches;
var
  LMid: TAsymTreeMid;
  LLeaf: TAsymTreeLeaf;
  LMidFor: Integer;
  LLeafFor: Integer;
begin
  FObjectSet := TContainerObjectSet<TAsymTreeRoot>.Create(FConnection);
  // The master as it stands in the database: no detail at all. This is what
  // Modify snapshots, and it is why every branch below will be missing from
  // the state.
  FOld := TAsymTreeRoot.Create;
  FOld.rkey := FRootKey;
  FOld.rtag := cROOTTAG;
  FObjectSet.Modify(FOld);
  // The edited master: same row, plus TWO branches that do not exist yet, each
  // carrying leaves of its own.
  FNew := TAsymTreeRoot.Create;
  FNew.rkey := FRootKey;
  FNew.rtag := cROOTTAGNEW;
  for LMidFor := 0 to cMIDS - 1 do
  begin
    LMid := TAsymTreeMid.Create;
    LMid.mtag := cMIDTAG + IntToStr(LMidFor);
    // Set by the caller on purpose - see the header block.
    LMid.mparent := FRootKey;
    for LLeafFor := 0 to cLEAFS - 1 do
    begin
      LLeaf := TAsymTreeLeaf.Create;
      LLeaf.ltag := cLEAFTAG + IntToStr(LMidFor) + '_' + IntToStr(LLeafFor);
      LMid.leafs.Add(LLeaf);
    end;
    FNew.mids.Add(LMid);
  end;
  FObjectSet.Update(FNew);
end;

procedure TTestObjectSetCascadeUpdateList.Premise_TheTopAssociationIsAListAndCascadesOnUpdate;
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LFound: Boolean;
begin
  // Without a list multiplicity the cascade goes to the single-object handler
  // and the assertions below stop measuring the site they name. And without
  // CascadeUpdate in the set the branch is skipped before any multiplicity is
  // consulted.
  LFound := False;
  LAssociations := TMappingExplorer.GetMappingAssociation(TAsymTreeRoot);
  Assert.IsNotNull(LAssociations, 'TAsymTreeRoot must expose associations');
  for LAssociation in LAssociations do
  begin
    if LAssociation.Multiplicity <> TMultiplicity.OneToMany then
      Continue;
    LFound := True;
    Assert.IsTrue(TCascadeAction.CascadeUpdate in LAssociation.CascadeActions,
      'the OneToMany association must cascade on update');
    Assert.IsTrue(TCascadeAction.CascadeAutoInc in LAssociation.CascadeActions,
      'the OneToMany association must be walked by the autoinc propagation');
  end;
  Assert.IsTrue(LFound, 'TAsymTreeRoot must reach the OneToMany handler');
end;

procedure TTestObjectSetCascadeUpdateList.Premise_EveryBranchIsWrittenByTheInsertLegOfCascadeUpdate;
var
  LFor: Integer;
begin
  // The control. Every branch starts at key zero and only an insert can give
  // it one, so a generated mkey on each proves the `else` leg ran rather than
  // the update leg. Distinct keys prove the two branches are really two rows.
  // If this ever goes red the assertions below are measuring nothing.
  _UpdateTheRootWithBrandNewBranches;
  for LFor := 0 to cMIDS - 1 do
    Assert.IsTrue(FNew.mids[LFor].mkey > 0,
      'branch ' + IntToStr(LFor) +
      ' must have been inserted and given a generated key');
  Assert.AreNotEqual(FNew.mids[0].mkey, FNew.mids[1].mkey,
    'the two branches must carry DIFFERENT keys, otherwise stamping the wrong ' +
    'one would be indistinguishable from stamping the right one');
  Assert.AreEqual(cMIDS,
    _ScalarInt('SELECT COUNT(*) FROM atmid'),
    'every branch row must have been written');
  Assert.AreEqual(cMIDS * cLEAFS,
    _ScalarInt('SELECT COUNT(*) FROM atleaf'),
    'every leaf must have been written');
end;

procedure TTestObjectSetCascadeUpdateList.EveryInsertedBranchsOwnKeyMustReachItsOwnChildren;
var
  LMidFor: Integer;
  LLeafFor: Integer;
  LMid: TAsymTreeMid;
  LSeen: Integer;
begin
  // The site. After a branch is inserted and given its own key, that key is
  // what ITS leaves are waiting for in `lparent`. Inserting and stopping there
  // leaves every leaf holding zero and raises nothing. Measured per branch:
  // a propagation hoisted out of the loop would satisfy one branch and leave
  // the other one wrong.
  _UpdateTheRootWithBrandNewBranches;
  for LMidFor := 0 to cMIDS - 1 do
  begin
    LMid := FNew.mids[LMidFor];
    LSeen := 0;
    for LLeafFor := 0 to LMid.leafs.Count - 1 do
      if LMid.leafs[LLeafFor].lparent = LMid.mkey then
        Inc(LSeen);
    Assert.AreEqual(cLEAFS, LSeen,
      'every leaf of branch ' + IntToStr(LMidFor) + ' must carry the key of ' +
      'THAT branch - a leaf still holding zero means the update leg inserted ' +
      'without propagating, and a leaf holding the other branch key means the ' +
      'propagation did not run once per child');
  end;
end;

procedure TTestObjectSetCascadeUpdateList.EveryInsertedBranchsOwnKeyMustReachTheDatabaseRows;
var
  LMidFor: Integer;
begin
  // The same step measured where it hurts. The leaves are written AFTER the
  // propagation would have run, so what it failed to stamp is what the
  // database keeps: orphan rows written in silence.
  _UpdateTheRootWithBrandNewBranches;
  for LMidFor := 0 to cMIDS - 1 do
    Assert.AreEqual(cLEAFS,
      _ScalarInt('SELECT COUNT(*) FROM atleaf WHERE lparent = ' +
                 IntToStr(FNew.mids[LMidFor].mkey)),
      'every leaf ROW of branch ' + IntToStr(LMidFor) +
      ' must point at that branch');
  Assert.AreEqual(0,
    _ScalarInt('SELECT COUNT(*) FROM atleaf WHERE lparent = 0'),
    'no leaf row may be left pointing at nothing');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestObjectSetCascadeUpdateList);

end.
