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

{ @abstract(Janus Framework - the base adapter's cascade delete order under an
  ENFORCED foreign key, issue #240.)

  WHY THIS SUITE EXISTS

  The server copy of the cascade deletes a row and reaches its children
  afterwards; the base adapter descends first and deletes afterwards. The
  server copy is being changed to match the base, and "match the base" is not
  by itself a reason - the base was checked before it was copied, and this is
  the check.

  It is also the independent witness the sibling suite in Janus.Tests.RESTHorse
  cannot be: Janus.Server.RestObjectSet is not compiled by Janus.Tests.Units,
  and TObjectSetBaseAdapter is not compiled by Janus.Tests.RESTHorse. Neither
  project can measure both orders, so the pair of suites does.

  WHAT IS UNDER TEST

  TObjectSetBaseAdapter<M>.OneToManyCascadeActionsExecute, the CascadeDelete
  branch, reached through TContainerObjectSet<M> -> TObjectSetAdapter<M>.Delete.

  As in the sibling suite, SQLite ignores REFERENCES unless the pragma is on,
  so the first test asks the database to accept an orphan and requires it to
  refuse.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.ObjectSet.CascadeDeleteOrder;

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
  Janus.Container.ObjectSet,
  Janus.Container.ObjectSet.Interfaces,
  Test.Janus.Model.AsymTree;

type
  [TestFixture]
  TTestObjectSetCascadeDeleteOrder = class
  private
    FDConnection: TFDConnection;
    FConnection: IDBConnection;
    FDbFile: string;
    FObjectSet: IContainerObjectSet<TAsymTreeRoot>;
    FRoot: TAsymTreeRoot;
    function _ScalarInt(const ASQL: string): Integer;
    procedure _WriteTheTree;
    function _DeleteTheRoot: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Premise_TheForeignKeyIsActuallyEnforced;
    [Test]
    procedure Premise_TheTreeIsWrittenWithEveryLinkResolved;
    [Test]
    procedure DeletingTheRootMustNotViolateTheChildsForeignKey;
    [Test]
    procedure DeletingTheRootMustEmptyEveryLevel;
  end;

implementation

uses
  DataEngine.FactoryFireDAC;

const
  cDBFILE  = 'janus_objectset_cascadedeleteorder.db';
  cLEAFS   = 3;
  cROOTTAG = 'root';
  cMIDTAG  = 'mid';
  cLEAFTAG = 'leaf';

  cDDL_ROOT =
    'CREATE TABLE IF NOT EXISTS atroot (' +
    '  rkey INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  rtag VARCHAR(20)' +
    ')';
  cDDL_MID =
    'CREATE TABLE IF NOT EXISTS atmid (' +
    '  mkey    INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  mparent INTEGER,' +
    '  mtag    VARCHAR(20),' +
    '  FOREIGN KEY (mparent) REFERENCES atroot(rkey)' +
    ')';
  cDDL_LEAF =
    'CREATE TABLE IF NOT EXISTS atleaf (' +
    '  lkey    INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  lparent INTEGER,' +
    '  ltag    VARCHAR(20),' +
    '  FOREIGN KEY (lparent) REFERENCES atmid(mkey)' +
    ')';

{ TTestObjectSetCascadeDeleteOrder }

procedure TTestObjectSetCascadeDeleteOrder.Setup;
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
  FConnection.ExecuteDirect('PRAGMA foreign_keys = ON');
  FConnection.ExecuteDirect(cDDL_ROOT);
  FConnection.ExecuteDirect(cDDL_MID);
  FConnection.ExecuteDirect(cDDL_LEAF);
end;

procedure TTestObjectSetCascadeDeleteOrder.TearDown;
begin
  FRoot.Free;
  FRoot := nil;
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

function TTestObjectSetCascadeDeleteOrder._ScalarInt(const ASQL: string): Integer;
var
  LValue: Variant;
begin
  LValue := FDConnection.ExecSQLScalar(ASQL);
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Result := -1
  else
    Result := LValue;
end;

procedure TTestObjectSetCascadeDeleteOrder._WriteTheTree;
var
  LMid: TAsymTreeMid;
  LLeaf: TAsymTreeLeaf;
  LFor: Integer;
begin
  FObjectSet := TContainerObjectSet<TAsymTreeRoot>.Create(FConnection);
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

function TTestObjectSetCascadeDeleteOrder._DeleteTheRoot: string;
begin
  Result := '';
  try
    FObjectSet.Delete(FRoot);
  except
    on E: Exception do
      Result := E.Message;
  end;
end;

procedure TTestObjectSetCascadeDeleteOrder.Premise_TheForeignKeyIsActuallyEnforced;
var
  LMessage: string;
begin
  LMessage := '';
  try
    FConnection.ExecuteDirect(
      'INSERT INTO atleaf (lparent, ltag) VALUES (999999, ' +
      QuotedStr('orphan') + ')');
  except
    on E: Exception do
      LMessage := E.Message;
  end;
  Assert.AreNotEqual('', LMessage,
    'the database must REFUSE a leaf pointing at a mid that does not exist - ' +
    'if it accepts one, the constraint is inert and this fixture measures nothing');
  Assert.AreEqual(0, _ScalarInt('SELECT COUNT(*) FROM atleaf'),
    'the refused row must not be there');
end;

procedure TTestObjectSetCascadeDeleteOrder.Premise_TheTreeIsWrittenWithEveryLinkResolved;
begin
  _WriteTheTree;
  Assert.AreEqual(1, _ScalarInt('SELECT COUNT(*) FROM atroot'));
  Assert.AreEqual(1, _ScalarInt('SELECT COUNT(*) FROM atmid WHERE mparent = ' +
                                IntToStr(FRoot.rkey)));
  Assert.AreEqual(cLEAFS, _ScalarInt('SELECT COUNT(*) FROM atleaf WHERE lparent = ' +
                                     IntToStr(FRoot.mids[0].mkey)));
end;

procedure TTestObjectSetCascadeDeleteOrder.DeletingTheRootMustNotViolateTheChildsForeignKey;
var
  LMessage: string;
begin
  // The base descends before it deletes, so the leaves are gone by the time the
  // branch row is removed and the constraint has nothing to object to.
  _WriteTheTree;
  LMessage := _DeleteTheRoot;
  Assert.AreEqual('', LMessage,
    'the base adapter must delete the tree without violating the constraint');
end;

procedure TTestObjectSetCascadeDeleteOrder.DeletingTheRootMustEmptyEveryLevel;
begin
  _WriteTheTree;
  _DeleteTheRoot;
  Assert.AreEqual(0, _ScalarInt('SELECT COUNT(*) FROM atleaf'),
    'every leaf row must be gone');
  Assert.AreEqual(0, _ScalarInt('SELECT COUNT(*) FROM atmid'),
    'the branch row must be gone');
  Assert.AreEqual(0, _ScalarInt('SELECT COUNT(*) FROM atroot'),
    'the root row must be gone');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestObjectSetCascadeDeleteOrder);

end.
