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

{ @abstract(Janus Framework - the MASTER's key reaching a child added during an
  update, server side. Issue #242.)

  WHAT IS UNDER TEST

  TRESTObjectSet.Update. Its sibling TRESTObjectSet.Insert reads the master's
  primary key mapping and hands every column of it to SetAutoIncValueChilds
  BEFORE running the cascade, which is what puts the master's key into the
  foreign key property of each child about to be written. Update runs the
  cascade and never performs that step, so a child that only exists in the
  edited object - a detail line the stored master did not have - is inserted
  with its foreign key at whatever the caller left in it, which for a freshly
  constructed object is zero. Nothing is raised.

  This is a DIFFERENT site from the one Test.Janus.Server.RestObjectSet.
  CascadeUpdateList measures. There the key that fails to travel is the
  CHILD's own key, on its way to the grandchildren, and the site is inside the
  cascade handler. Here the key that fails to travel is the MASTER's, on its
  way to its direct children, and the site is the update entry point itself.
  The two suites are kept apart so a red one names which of the two is broken.

  WHY THE CHILD CARRIES NO LEAVES HERE

  A leafless branch cannot fail for the other reason. If this fixture carried
  grandchildren it would go red on the CascadeUpdateList defect as well and
  stop identifying its own site.

  WHY THE MASTER KEY IS NOT INVENTED BY THE TEST

  The master row is written with plain SQL and its key read back, so the value
  the assertions expect is the one the database generated, not one the fixture
  chose. A propagation that wrote a constant would not satisfy it.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Server.RestObjectSet.UpdateMasterKey;

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
  TTestServerRestObjectSetUpdateMasterKey = class
  private
    FDConnection: TFDConnection;
    FConnection: IDBConnection;
    FDbFile: string;
    FRootKey: Integer;
    FObjectSet: TRESTObjectSet;
    FOld: TAsymTreeRoot;
    FNew: TAsymTreeRoot;
    function _ScalarInt(const ASQL: string): Integer;
    procedure _UpdateTheRootWithABrandNewBranch;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Premise_TheBranchIsWrittenByTheInsertLegOfCascadeUpdate;
    [Test]
    procedure TheMasterKeyMustReachTheBranchAddedOnUpdate;
    [Test]
    procedure TheMasterKeyMustReachTheBranchRowAddedOnUpdate;
  end;

implementation

uses
  DataEngine.FactoryFireDAC;

const
  cDBFILE     = 'janus_server_objectset_updatemasterkey.db';
  cROOTTAG    = 'root';
  cROOTTAGNEW = 'rootedit';
  cMIDTAG     = 'mid';

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

{ TTestServerRestObjectSetUpdateMasterKey }

procedure TTestServerRestObjectSetUpdateMasterKey.Setup;
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
  FConnection.ExecuteDirect('INSERT INTO atroot (rtag) VALUES (' +
                            QuotedStr(cROOTTAG) + ')');
  FRootKey := _ScalarInt('SELECT MAX(rkey) FROM atroot');
end;

procedure TTestServerRestObjectSetUpdateMasterKey.TearDown;
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

function TTestServerRestObjectSetUpdateMasterKey._ScalarInt(
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

procedure TTestServerRestObjectSetUpdateMasterKey._UpdateTheRootWithABrandNewBranch;
var
  LMid: TAsymTreeMid;
begin
  FObjectSet := TRESTObjectSet.Create(FConnection, TAsymTreeRoot);
  FOld := TAsymTreeRoot.Create;
  FOld.rkey := FRootKey;
  FOld.rtag := cROOTTAG;
  FObjectSet.Modify(FOld);
  FNew := TAsymTreeRoot.Create;
  FNew.rkey := FRootKey;
  FNew.rtag := cROOTTAGNEW;
  // mparent is left at zero on purpose: filling it in is the framework's job
  // on the insert path, and the question here is whether the update path does
  // the same. No leaves - see the header block.
  LMid := TAsymTreeMid.Create;
  LMid.mtag := cMIDTAG;
  FNew.mids.Add(LMid);
  FObjectSet.Update(FNew);
end;

procedure TTestServerRestObjectSetUpdateMasterKey.Premise_TheBranchIsWrittenByTheInsertLegOfCascadeUpdate;
begin
  // The control. The branch starts at key zero and only an insert can give it
  // one, so a generated mkey proves the `else` leg of the cascade ran. If this
  // goes red the two assertions below are measuring nothing.
  _UpdateTheRootWithABrandNewBranch;
  Assert.IsTrue(FNew.mids[0].mkey > 0,
    'the branch must have been inserted and given a generated key');
  Assert.AreEqual(1, _ScalarInt('SELECT COUNT(*) FROM atmid'),
    'the branch row must have been written');
end;

procedure TTestServerRestObjectSetUpdateMasterKey.TheMasterKeyMustReachTheBranchAddedOnUpdate;
begin
  _UpdateTheRootWithABrandNewBranch;
  Assert.AreEqual(FRootKey, FNew.mids[0].mparent,
    'the branch added on update must carry the master key - a zero here means ' +
    'the update path never ran the propagation its insert sibling runs');
end;

procedure TTestServerRestObjectSetUpdateMasterKey.TheMasterKeyMustReachTheBranchRowAddedOnUpdate;
begin
  // The same step measured where it hurts: the row is written during the
  // cascade, so whatever the propagation failed to stamp is what the database
  // keeps - a detail line pointing at no master.
  _UpdateTheRootWithABrandNewBranch;
  Assert.AreEqual(1,
    _ScalarInt('SELECT COUNT(*) FROM atmid WHERE mparent = ' +
               IntToStr(FRootKey)),
    'the branch ROW must point at the master - a row holding zero is an orphan');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestServerRestObjectSetUpdateMasterKey);

end.
