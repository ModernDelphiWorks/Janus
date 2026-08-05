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

{ @abstract(Janus Framework - autoinc propagation inside the SERVER side
  cascade, issue #225.)

  WHAT IS UNDER TEST

  TRESTObjectSet is the object set the REST server builds for every resource
  it serves - TAppResourceBase constructs one per request. It carries its own
  copy of the autoinc propagation that TObjectSetBaseAdapter<M> also carries,
  and the copy is what runs for every write that arrives over HTTP.

  Inside OneToManyCascadeActionsExecute and OneToOneCascadeActionsExecute the
  sequence is: insert the child, read a primary key mapping, then hand each of
  its columns to SetAutoIncValueChilds together with the CHILD object. What
  the key mapping is read FROM is the whole question. SetAutoIncValueChilds
  ends in SetAutoIncValueOneToMany / SetAutoIncValueOneToOne, which do

      LIndex := AAssociation.ColumnsName.IndexOf(AProperty.Name);
      ...
      LProperty.SetValue(LObject, AProperty.GetValue(AObject));

  with AObject bound to the child that was just inserted. AProperty is
  therefore read OFF the child, so it has to BE a property of the child - it
  is the child's own freshly generated key that the child's own children are
  waiting for.

  THE DEFECT THIS SUITE PINS

  Both server side sites read the mapping from the MASTER
  (GetMappingPrimaryKeyColumns(AObject.ClassType)) and then propagate to the
  CHILD, where the base reads it from the child that is being written
  (GetMappingPrimaryKeyColumns(LObject.ClassType)).

  WHY THE SUITE NEEDED A NEW MODEL

  Measured before this unit existed: the one three level model the suite
  compiles, Test.Janus.Model.AutoIncTree, spells the mid level's association
  `root_id` - the ROOT's key name rather than the mid's own `mid_id`. With
  that one name reused the two readings are not distinguishable. The two
  level fixture Test.Janus.Model.AsymKey does have asymmetric names but the
  step under test is a no-op at two levels, because it fires only after a
  child is inserted and only reaches children OF that child.

  Test.Janus.Model.AsymTree supplies the missing shape: three levels, every
  column name spelled once.

  WHAT THE MEASUREMENT LOOKS LIKE

  Level one - the master's key onto its children - runs in Insert, not in the
  cascade, and reads the master's mapping correctly there. It is asserted
  here as a PREMISE: if it ever goes red the suite is measuring the wrong
  thing and the level two result means nothing.

  Level two - the mid's key onto the leaves - is the site. Reading the mid's
  own mapping finds `mkey` in the mid's association and the leaves are
  stamped. Reading the ROOT's mapping searches the mid's association for
  `rkey`, finds nothing, and returns without stamping anything: the failure
  is SILENT, and the leaf reaches the database carrying zero.

  Both the in-memory object and the persisted row are asserted, because a
  propagation that only reached the object would still be a defect and a
  propagation that only reached the row would be a different one.

  WHY IT LIVES IN Janus.Tests.RESTHorse

  Janus.Server.RestObjectSet is compiled by exactly two of the five test
  projects - this one and Janus.Tests.RESTOracle - and RESTOracle cannot run
  on a machine without an Oracle client. This project already builds a live
  SQLite database, so the production route (construct the object set, call
  Insert) is reachable without a stub.

  The fixture keeps its own connection and its own database file rather than
  deriving from TRestHorseTestBase: nothing here needs an HTTP listener, and
  staying off that base leaves the existing suites' server lifecycle alone.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Server.RestObjectSet.AutoInc;

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
  TTestServerRestObjectSetAutoInc = class
  private
    FDConnection: TFDConnection;
    FConnection: IDBConnection;
    FDbFile: String;
    function _ScalarInt(const ASQL: String): Integer;
    function _BuildTree: TAsymTreeRoot;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Premise_TheThreeLevelsSpellEveryKeyColumnOnlyOnce;
    [Test]
    procedure Premise_TheMastersKeyReachesItsChildren;
    [Test]
    procedure TheChildsOwnKeyMustReachItsOwnChildren;
    [Test]
    procedure TheChildsOwnKeyMustReachTheDatabaseRow;
  end;

implementation

uses
  DataEngine.FactoryFireDAC;

const
  cDBFILE   = 'janus_server_objectset_autoinc.db';
  cLEAFS    = 3;
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

{ TTestServerRestObjectSetAutoInc }

procedure TTestServerRestObjectSetAutoInc.Setup;
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

procedure TTestServerRestObjectSetAutoInc.TearDown;
begin
  FConnection := nil;
  if Assigned(FDConnection) then
  begin
    FDConnection.Connected := False;
    FreeAndNil(FDConnection);
  end;
  if TFile.Exists(FDbFile) then
    TFile.Delete(FDbFile);
end;

function TTestServerRestObjectSetAutoInc._ScalarInt(const ASQL: String): Integer;
var
  LValue: Variant;
begin
  LValue := FDConnection.ExecSQLScalar(ASQL);
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Result := -1
  else
    Result := LValue;
end;

function TTestServerRestObjectSetAutoInc._BuildTree: TAsymTreeRoot;
var
  LMid: TAsymTreeMid;
  LLeaf: TAsymTreeLeaf;
  LFor: Integer;
begin
  Result := TAsymTreeRoot.Create;
  Result.rtag := cROOTTAG;
  LMid := TAsymTreeMid.Create;
  LMid.mtag := cMIDTAG;
  for LFor := 0 to cLEAFS - 1 do
  begin
    LLeaf := TAsymTreeLeaf.Create;
    LLeaf.ltag := cLEAFTAG + IntToStr(LFor);
    LMid.leafs.Add(LLeaf);
  end;
  Result.mids.Add(LMid);
end;

procedure TTestServerRestObjectSetAutoInc.Premise_TheThreeLevelsSpellEveryKeyColumnOnlyOnce;
var
  LRootKey: TPrimaryKeyColumnsMapping;
  LMidKey: TPrimaryKeyColumnsMapping;
  LLeafKey: TPrimaryKeyColumnsMapping;
begin
  // The whole measurement rests on the three key names being different. If a
  // later edit ever spells two of them the same, the level two assertions stop
  // telling the two readings apart and start passing for the wrong reason.
  LRootKey := TMappingExplorer.GetMappingPrimaryKeyColumns(TAsymTreeRoot);
  LMidKey  := TMappingExplorer.GetMappingPrimaryKeyColumns(TAsymTreeMid);
  LLeafKey := TMappingExplorer.GetMappingPrimaryKeyColumns(TAsymTreeLeaf);
  Assert.IsNotNull(LRootKey, 'TAsymTreeRoot must expose a primary key mapping');
  Assert.IsNotNull(LMidKey,  'TAsymTreeMid must expose a primary key mapping');
  Assert.IsNotNull(LLeafKey, 'TAsymTreeLeaf must expose a primary key mapping');
  Assert.AreEqual(1, LRootKey.Columns.Count, 'root key must be a single column');
  Assert.AreEqual(1, LMidKey.Columns.Count,  'mid key must be a single column');
  Assert.AreEqual(1, LLeafKey.Columns.Count, 'leaf key must be a single column');
  Assert.AreEqual('rkey', LRootKey.Columns[0].ColumnName);
  Assert.AreEqual('mkey', LMidKey.Columns[0].ColumnName);
  Assert.AreEqual('lkey', LLeafKey.Columns[0].ColumnName);
end;

procedure TTestServerRestObjectSetAutoInc.Premise_TheMastersKeyReachesItsChildren;
var
  LObjectSet: TRESTObjectSet;
  LRoot: TAsymTreeRoot;
begin
  // Level one runs in Insert, BEFORE the cascade, and reads the master's own
  // mapping - which is the right mapping in that position. This is a control:
  // it must stay green whatever happens to the level two sites, otherwise the
  // tree never got inserted and the real assertions prove nothing.
  LRoot := _BuildTree;
  LObjectSet := TRESTObjectSet.Create(FConnection, TAsymTreeRoot);
  try
    LObjectSet.Insert(LRoot);
    Assert.IsTrue(LRoot.rkey > 0, 'the root must have received a generated key');
    Assert.AreEqual(LRoot.rkey, LRoot.mids[0].mparent,
      'the master key must reach the child object');
    Assert.AreEqual(LRoot.rkey, _ScalarInt('SELECT mparent FROM atmid WHERE mtag = ' +
                                           QuotedStr(cMIDTAG)),
      'the master key must reach the child row');
  finally
    LObjectSet.Free;
    LRoot.Free;
  end;
end;

procedure TTestServerRestObjectSetAutoInc.TheChildsOwnKeyMustReachItsOwnChildren;
var
  LObjectSet: TRESTObjectSet;
  LRoot: TAsymTreeRoot;
  LMid: TAsymTreeMid;
  LFor: Integer;
  LSeen: Integer;
begin
  // The site. After the mid is inserted and given its own key, that key is
  // what the leaves are waiting for in `lparent`. Reading the ROOT's mapping
  // here searches the mid's association for `rkey`, which is not there, and
  // leaves every leaf carrying zero without raising anything.
  LRoot := _BuildTree;
  LObjectSet := TRESTObjectSet.Create(FConnection, TAsymTreeRoot);
  try
    LObjectSet.Insert(LRoot);
    LMid := LRoot.mids[0];
    Assert.IsTrue(LMid.mkey > 0, 'the mid must have received a generated key');
    LSeen := 0;
    for LFor := 0 to LMid.leafs.Count - 1 do
      if LMid.leafs[LFor].lparent = LMid.mkey then
        Inc(LSeen);
    Assert.AreEqual(cLEAFS, LSeen,
      'every leaf must carry the MID key - a leaf still holding zero means the ' +
      'propagation read the key mapping of the master instead of the child');
  finally
    LObjectSet.Free;
    LRoot.Free;
  end;
end;

procedure TTestServerRestObjectSetAutoInc.TheChildsOwnKeyMustReachTheDatabaseRow;
var
  LObjectSet: TRESTObjectSet;
  LRoot: TAsymTreeRoot;
  LMid: TAsymTreeMid;
begin
  // The same step measured where it actually hurts: the leaves are inserted
  // AFTER the propagation, so whatever the propagation failed to stamp is what
  // the database is left holding. An orphan row is the production damage.
  LRoot := _BuildTree;
  LObjectSet := TRESTObjectSet.Create(FConnection, TAsymTreeRoot);
  try
    LObjectSet.Insert(LRoot);
    LMid := LRoot.mids[0];
    Assert.AreEqual(cLEAFS,
      _ScalarInt('SELECT COUNT(*) FROM atleaf'),
      'every leaf must have been inserted');
    Assert.AreEqual(cLEAFS,
      _ScalarInt('SELECT COUNT(*) FROM atleaf WHERE lparent = ' + IntToStr(LMid.mkey)),
      'every leaf ROW must point at the mid - a row holding zero is an orphan ' +
      'the server wrote without raising anything');
  finally
    LObjectSet.Free;
    LRoot.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestServerRestObjectSetAutoInc);

end.
