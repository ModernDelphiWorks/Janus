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
  server side OneToMany cascade, issue #242.)

  WHAT IS UNDER TEST

  TRESTObjectSet.OneToManyCascadeActionsExecute, the CascadeUpdate branch, and
  inside it the `else` leg - the one that runs when a child of the list is NOT
  in the state snapshot Modify took. The server reaches it on every PUT that
  adds a detail line the stored master did not have: TAppResourceBase.ResolverPut
  loads the old row, calls Modify on it, then calls Update with the object it
  parsed from the request body, so a detail that only exists in the body has no
  entry in FObjectState and lands on that leg.

  The leg inserts the detail. What happens NEXT is the question. The sibling
  handler for single-object associations, corrected under issue #239, inserts
  and then reads the CHILD's primary key mapping and hands every column of it
  to SetAutoIncValueChilds, which stamps the child's freshly generated key onto
  the child's OWN children. This one stopped at the insert.

  WHY THE LIST SHAPE IS NOT THE SAME MEASUREMENT AS #239

  The single-object handler inserts one child. This one walks a list and
  inserts N, each with children of its own, and each one recurses into
  CascadeActionsExecute at the bottom of the SAME iteration. So a propagation
  that ran once outside the loop, or that ran after the loop, would leave every
  detail but one holding a stale or zero key. The assertions below therefore
  measure EACH branch against ITS OWN key and require the two branch keys to
  differ, which is what makes "stamped the wrong branch's key" fail as loudly
  as "stamped nothing".

  WHAT THE MEASUREMENT LOOKS LIKE

  Right after a branch is inserted it holds a generated mkey and its leaves
  still hold zero in lparent. The propagation is the only step that would fill
  them, and it runs BEFORE the leaves are inserted - the recursive
  CascadeActionsExecute call at the end of each iteration is what writes them.
  So whatever the propagation failed to stamp is what the database is left
  holding: leaf rows with lparent = 0, pointing at no mid, written without
  anything being raised.

  Both the in-memory object and the persisted row are asserted, for the same
  reason the sibling suites give: a propagation that only reached the object
  would still be a defect, and one that only reached the row a different one.

  WHY THIS FIXTURE SHAPE

  Test.Janus.Model.AsymTree spells every key name once across three levels -
  rkey, mkey, lkey, mparent, lparent - which is what makes a wrong-entity
  lookup impossible to satisfy by coincidence. Its TOP association, the one
  TAsymTreeRoot declares, is OneToMany, and CascadeActionsExecute routes
  OneToMany and ManyToMany to the handler under test here. Nothing new had to
  be added to the model for this suite.

  WHAT THIS SUITE DELIBERATELY DOES NOT ASSERT

  The branch's own foreign key onto its master - atmid.mparent - is set by the
  test, not left to the framework, in the two tests above. The master level
  stamp is a separate site with its own suite in this project
  (Test.Janus.Server.RestObjectSet.UpdateMasterKey), and asserting it here
  would make this suite fail for a second reason.

  WHY IT LIVES IN Janus.Tests.RESTHorse

  Measured, one project at a time from a cleaned tree, by whether the build
  leaves Janus.Server.RestObjectSet.dcu behind: exactly two of the five test
  projects compile this unit - this one and Janus.Tests.RESTOracle - and
  RESTOracle cannot run here, its twelve tests all error on `OCI is not
  properly installed on this machine`. This project builds a live SQLite
  database, and TRESTObjectSet has a public constructor, so the production
  route is reachable with no stub and no HTTP listener.

  The same measurement says this project does NOT compile the ObjectSet base
  adapter, which is why the twin of this suite could not live here and sits in
  Janus.Tests.Units instead.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Server.RestObjectSet.CascadeUpdateList;

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
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Explorer,
  MetaDbDiff.Types.Mapping,
  Janus.Server.RestObjectSet,
  Test.Janus.Model.AsymTree;

type
  [TestFixture]
  TTestServerRestObjectSetCascadeUpdateList = class
  private
    FDConnection: TFDConnection;
    FConnection: IDBConnection;
    FDbFile: string;
    FRootKey: Integer;
    FObjectSet: TRESTObjectSet;
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
  cDBFILE     = 'janus_server_objectset_cascadeupdatelist.db';
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

{ TTestServerRestObjectSetCascadeUpdateList }

procedure TTestServerRestObjectSetCascadeUpdateList.Setup;
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
  // The stored row the server would have loaded before a PUT, written with
  // plain SQL so the master exists without any cascade having run yet.
  FConnection.ExecuteDirect('INSERT INTO atroot (rtag) VALUES (' +
                            QuotedStr(cROOTTAG) + ')');
  FRootKey := _ScalarInt('SELECT MAX(rkey) FROM atroot');
end;

procedure TTestServerRestObjectSetCascadeUpdateList.TearDown;
begin
  FNew.Free;
  FNew := nil;
  FOld.Free;
  FOld := nil;
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

function TTestServerRestObjectSetCascadeUpdateList._ScalarInt(
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

procedure TTestServerRestObjectSetCascadeUpdateList._UpdateTheRootWithBrandNewBranches;
var
  LMid: TAsymTreeMid;
  LLeaf: TAsymTreeLeaf;
  LMidFor: Integer;
  LLeafFor: Integer;
begin
  FObjectSet := TRESTObjectSet.Create(FConnection, TAsymTreeRoot);
  // The row as it stands in the database: no detail at all. This is what the
  // server hands to Modify, and it is why every branch in the request body
  // will be missing from the state snapshot.
  FOld := TAsymTreeRoot.Create;
  FOld.rkey := FRootKey;
  FOld.rtag := cROOTTAG;
  FObjectSet.Modify(FOld);
  // The object parsed from the request body: same row, plus TWO branches that
  // do not exist yet, each carrying leaves of its own.
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

procedure TTestServerRestObjectSetCascadeUpdateList.Premise_TheTopAssociationIsAListAndCascadesOnUpdate;
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

procedure TTestServerRestObjectSetCascadeUpdateList.Premise_EveryBranchIsWrittenByTheInsertLegOfCascadeUpdate;
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

procedure TTestServerRestObjectSetCascadeUpdateList.EveryInsertedBranchsOwnKeyMustReachItsOwnChildren;
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

procedure TTestServerRestObjectSetCascadeUpdateList.EveryInsertedBranchsOwnKeyMustReachTheDatabaseRows;
var
  LMidFor: Integer;
begin
  // The same step measured where it hurts. The leaves are written AFTER the
  // propagation would have run, so what it failed to stamp is what the
  // database keeps: orphan rows the server wrote in silence.
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
  TDUnitX.RegisterTestFixture(TTestServerRestObjectSetCascadeUpdateList);

end.
