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
  server side cascade, issue #239.)

  WHAT IS UNDER TEST

  TRESTObjectSet.OneToOneCascadeActionsExecute, the CascadeUpdate branch, and
  inside it the `else` leg - the one that runs when the child object is NOT in
  the state snapshot Modify took. The server reaches it on every PUT that adds
  a nested object the stored row did not have: TAppResourceBase.ResolverPut
  loads the old row, calls Modify on it, then calls Update with the object it
  parsed from the request body, so a child that only exists in the body has no
  entry in FObjectState and lands on that leg.

  The leg inserts the child. What happens NEXT is the question. The base
  adapter, TObjectSetBaseAdapter<M>.OneToOneCascadeActionsExecute, inserts and
  then reads the CHILD's primary key mapping and hands every column of it to
  SetAutoIncValueChilds, which stamps the child's freshly generated key onto
  the child's OWN children. The server side copy stopped at the insert.

  WHAT THE MEASUREMENT LOOKS LIKE

  Right after the insert the branch object holds a generated mkey and its
  leaves still hold zero in lparent. The propagation is the only step that
  would fill them, and it runs BEFORE the leaves are inserted - the recursive
  CascadeActionsExecute call at the end of the method is what writes them. So
  whatever the propagation failed to stamp is what the database is left
  holding: leaf rows with lparent = 0, pointing at no mid, written without
  anything being raised.

  Both the in-memory object and the persisted row are asserted, for the same
  reason the sibling suite gives: a propagation that only reached the object
  would still be a defect, and one that only reached the row a different one.

  WHY A NEW SHAPE IN THE FIXTURE

  Test.Janus.Model.AsymTree already spells every key name once across three
  levels, which is what makes a wrong-entity lookup impossible to satisfy by
  coincidence. But its top association is OneToMany, and OneToMany is routed
  to the OTHER handler. Measured before TAsymTreeOneRoot existed: neither
  model unit this project compiles declared any OneToOne or ManyToOne
  association, so no fixture here could reach OneToOneCascadeActionsExecute.
  TAsymTreeOneRoot adds a single-object top level over the SAME mid and leaf
  entities.

  WHAT THIS SUITE DELIBERATELY DOES NOT ASSERT

  The new branch's own foreign key onto its master - atmid.mparent - is set by
  the test, not by the framework. The master level stamp lives in Insert, and
  the update path never calls Insert on the master: measured by a throwaway
  probe on the OneToMany sibling shape, a branch added on the update leg came
  back with mparent = 0 and no atmid row pointing at the root. That is a real
  gap against the insert path, but it is NOT the defect under test, it is not
  a divergence either - the base adapter has the same shape - and asserting it
  here would make this suite fail for a second, unrelated reason.

  WHY IT LIVES IN Janus.Tests.RESTHorse

  Janus.Server.RestObjectSet is compiled by exactly two of the five test
  projects - this one and Janus.Tests.RESTOracle - and RESTOracle cannot run
  without an Oracle client. This project builds a live SQLite database, and
  TRESTObjectSet has a public constructor, so the production route is
  reachable with no stub and no HTTP listener.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Server.RestObjectSet.CascadeUpdate;

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
  TTestServerRestObjectSetCascadeUpdate = class
  private
    FDConnection: TFDConnection;
    FConnection: IDBConnection;
    FDbFile: string;
    FRootKey: Integer;
    FObjectSet: TRESTObjectSet;
    FOld: TAsymTreeOneRoot;
    FNew: TAsymTreeOneRoot;
    function _ScalarInt(const ASQL: string): Integer;
    procedure _UpdateTheRootWithABrandNewBranch;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Premise_TheTopAssociationIsSingleObjectAndCascadesOnUpdate;
    [Test]
    procedure Premise_TheBranchIsWrittenByTheInsertLegOfCascadeUpdate;
    [Test]
    procedure TheInsertedBranchsOwnKeyMustReachItsOwnChildren;
    [Test]
    procedure TheInsertedBranchsOwnKeyMustReachTheDatabaseRow;
  end;

implementation

uses
  DataEngine.FactoryFireDAC;

const
  cDBFILE     = 'janus_server_objectset_cascadeupdate.db';
  cLEAFS      = 3;
  cROOTTAG    = 'root';
  cROOTTAGNEW = 'rootedit';
  cMIDTAG     = 'mid';
  cLEAFTAG    = 'leaf';

  cDDL_PAIR =
    'CREATE TABLE IF NOT EXISTS atpair (' +
    '  pkey INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  ptag VARCHAR(20)' +
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

{ TTestServerRestObjectSetCascadeUpdate }

procedure TTestServerRestObjectSetCascadeUpdate.Setup;
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
  FConnection.ExecuteDirect(cDDL_PAIR);
  FConnection.ExecuteDirect(cDDL_MID);
  FConnection.ExecuteDirect(cDDL_LEAF);
  // The stored row the server would have loaded before a PUT. Written with
  // plain SQL, not through the object set: measured by a throwaway probe on
  // this same fixture, TRESTObjectSet.Insert of a root whose OneToOne branch
  // is nil comes back as `Exception: Access violation ... Read of address
  // 00000000` and rolls the row back. The base adapter exits on a nil child
  // at that point and the server copy does not - a separate divergence, not
  // the one under test here.
  FConnection.ExecuteDirect('INSERT INTO atpair (ptag) VALUES (' +
                            QuotedStr(cROOTTAG) + ')');
  FRootKey := _ScalarInt('SELECT MAX(pkey) FROM atpair');
end;

procedure TTestServerRestObjectSetCascadeUpdate.TearDown;
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

function TTestServerRestObjectSetCascadeUpdate._ScalarInt(const ASQL: string): Integer;
var
  LValue: Variant;
begin
  LValue := FDConnection.ExecSQLScalar(ASQL);
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Result := -1
  else
    Result := LValue;
end;

procedure TTestServerRestObjectSetCascadeUpdate._UpdateTheRootWithABrandNewBranch;
var
  LMid: TAsymTreeMid;
  LLeaf: TAsymTreeLeaf;
  LFor: Integer;
begin
  FObjectSet := TRESTObjectSet.Create(FConnection, TAsymTreeOneRoot);
  // The row as it stands in the database: no branch. This is what the server
  // hands to Modify, and it is why the branch in the request body will not be
  // found in the state snapshot.
  FOld := TAsymTreeOneRoot.Create;
  FOld.pkey := FRootKey;
  FOld.ptag := cROOTTAG;
  FObjectSet.Modify(FOld);
  // The object parsed from the request body: same row, plus a branch that
  // does not exist yet, carrying leaves of its own.
  FNew := TAsymTreeOneRoot.Create;
  FNew.pkey := FRootKey;
  FNew.ptag := cROOTTAGNEW;
  LMid := TAsymTreeMid.Create;
  LMid.mtag := cMIDTAG;
  // Set by the caller on purpose - see the header block.
  LMid.mparent := FRootKey;
  for LFor := 0 to cLEAFS - 1 do
  begin
    LLeaf := TAsymTreeLeaf.Create;
    LLeaf.ltag := cLEAFTAG + IntToStr(LFor);
    LMid.leafs.Add(LLeaf);
  end;
  FNew.mid := LMid;
  FObjectSet.Update(FNew);
end;

procedure TTestServerRestObjectSetCascadeUpdate.Premise_TheTopAssociationIsSingleObjectAndCascadesOnUpdate;
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LFound: Boolean;
begin
  // Without a single-object multiplicity the cascade goes to the OneToMany
  // handler and the assertions below stop measuring the site they name. And
  // without CascadeUpdate in the set the branch is skipped before any
  // multiplicity is consulted.
  LFound := False;
  LAssociations := TMappingExplorer.GetMappingAssociation(TAsymTreeOneRoot);
  Assert.IsNotNull(LAssociations, 'TAsymTreeOneRoot must expose associations');
  for LAssociation in LAssociations do
  begin
    if LAssociation.Multiplicity <> TMultiplicity.OneToOne then
      Continue;
    LFound := True;
    Assert.IsTrue(TCascadeAction.CascadeUpdate in LAssociation.CascadeActions,
      'the OneToOne association must cascade on update');
    Assert.IsTrue(TCascadeAction.CascadeAutoInc in LAssociation.CascadeActions,
      'the OneToOne association must be walked by the autoinc propagation');
  end;
  Assert.IsTrue(LFound, 'TAsymTreeOneRoot must reach the OneToOne handler');
end;

procedure TTestServerRestObjectSetCascadeUpdate.Premise_TheBranchIsWrittenByTheInsertLegOfCascadeUpdate;
begin
  // The control. The branch starts at key zero and only an insert can give it
  // one, so a generated mkey proves the `else` leg ran rather than the update
  // leg. If this ever goes red the two assertions below are measuring nothing.
  _UpdateTheRootWithABrandNewBranch;
  Assert.IsTrue(FNew.mid.mkey > 0,
    'the branch must have been inserted and given a generated key');
  Assert.AreEqual(1,
    _ScalarInt('SELECT COUNT(*) FROM atmid WHERE mtag = ' + QuotedStr(cMIDTAG)),
    'the branch row must have been written');
  Assert.AreEqual(cLEAFS,
    _ScalarInt('SELECT COUNT(*) FROM atleaf'),
    'every leaf must have been written');
end;

procedure TTestServerRestObjectSetCascadeUpdate.TheInsertedBranchsOwnKeyMustReachItsOwnChildren;
var
  LFor: Integer;
  LSeen: Integer;
begin
  // The site. After the branch is inserted and given its own key, that key is
  // what its leaves are waiting for in `lparent`. Inserting and stopping there
  // leaves every leaf holding zero and raises nothing.
  _UpdateTheRootWithABrandNewBranch;
  LSeen := 0;
  for LFor := 0 to FNew.mid.leafs.Count - 1 do
    if FNew.mid.leafs[LFor].lparent = FNew.mid.mkey then
      Inc(LSeen);
  Assert.AreEqual(cLEAFS, LSeen,
    'every leaf must carry the key of the branch that was just inserted - a ' +
    'leaf still holding zero means the update leg inserted without propagating');
end;

procedure TTestServerRestObjectSetCascadeUpdate.TheInsertedBranchsOwnKeyMustReachTheDatabaseRow;
begin
  // The same step measured where it hurts. The leaves are written AFTER the
  // propagation would have run, so what it failed to stamp is what the
  // database keeps: orphan rows the server wrote in silence.
  _UpdateTheRootWithABrandNewBranch;
  Assert.AreEqual(cLEAFS,
    _ScalarInt('SELECT COUNT(*) FROM atleaf WHERE lparent = ' +
               IntToStr(FNew.mid.mkey)),
    'every leaf ROW must point at the branch - a row holding zero is an orphan');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestServerRestObjectSetCascadeUpdate);

end.
