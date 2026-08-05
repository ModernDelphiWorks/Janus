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

{ @abstract(Janus Framework - the ORDER in which the server side cascade
  deletes a tree, issue #240.)

  WHAT IS UNDER TEST

  TRESTObjectSet.OneToManyCascadeActionsExecute and
  TRESTObjectSet.OneToOneCascadeActionsExecute, the CascadeDelete branch of
  each, and the recursive CascadeActionsExecute call that closes the method.

  The base adapter, TObjectSetBaseAdapter<M>, cascades DOWN first and deletes
  the object afterwards, and it skips the closing recursion when the action is
  a delete - the descent already happened. The server copy does the opposite:
  it deletes the object and reaches its children on the closing recursion,
  which runs unconditionally.

  Both orders write the same rows when nothing checks them. Under an ENFORCED
  foreign key they do not: deleting a row while rows still point at it is the
  violation the constraint exists to raise.

  WHY THE FOREIGN KEY IS DECLARED AND THE PRAGMA IS ISSUED

  SQLite parses REFERENCES in DDL but does NOT enforce it unless
  `PRAGMA foreign_keys = ON` is issued on the connection. A suite that only
  declared the constraint would measure nothing at all and would stay green
  against either order, so the first test here does not test the framework: it
  tests the harness, by asking the database to accept a row that points at
  nothing and requiring it to refuse.

  BOTH HANDLERS, NOT ONE

  CascadeActionsExecute routes OneToMany / ManyToMany to one handler and
  OneToOne / ManyToOne to the other, and BOTH carried the inverted order. Two
  fixtures live here for that reason: the same three levels, differing only in
  the multiplicity of the TOP association, which is what picks the handler. A
  suite that exercised one of them would leave the other fixed in the dark.

  WHY THREE LEVELS

  TRESTObjectSet.Delete already cascades before deleting the master, so the
  top level is not where the orders differ. The difference is INSIDE the
  handler, on the objects it walks - which means the row that gets deleted too
  early has to be a middle level with children of its own.

  WHY IT LIVES IN Janus.Tests.RESTHorse

  Measured one project at a time by which build leaves the .dcu behind:
  Janus.Server.RestObjectSet is compiled by Janus.Tests.RESTHorse and by
  Janus.Tests.RESTOracle, and the latter cannot run without an Oracle client.
  The base adapter is NOT compiled here, so the base's behaviour under the
  same enforced constraint is measured by a sibling suite in
  Janus.Tests.Units - Test.Janus.ObjectSet.CascadeDeleteOrder.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Server.RestObjectSet.CascadeDelete;

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
  TTestServerRestObjectSetCascadeDelete = class
  private
    FDConnection: TFDConnection;
    FConnection: IDBConnection;
    FDbFile: string;
    FObjectSet: TRESTObjectSet;
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

  /// The same three levels with a SINGLE-OBJECT association at the top, which
  /// is what routes the cascade through OneToOneCascadeActionsExecute instead.
  [TestFixture]
  TTestServerRestObjectSetCascadeDeleteOneToOne = class
  private
    FDConnection: TFDConnection;
    FConnection: IDBConnection;
    FDbFile: string;
    FObjectSet: TRESTObjectSet;
    FRoot: TAsymTreeOneRoot;
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
  cDBFILE  = 'janus_server_objectset_cascadedelete.db';
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

  cDBFILE_ONE = 'janus_server_objectset_cascadedelete_onetoone.db';
  cDDL_PAIR =
    'CREATE TABLE IF NOT EXISTS atpair (' +
    '  pkey INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  ptag VARCHAR(20)' +
    ')';
  cDDL_MID_ONE =
    'CREATE TABLE IF NOT EXISTS atmid (' +
    '  mkey    INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  mparent INTEGER,' +
    '  mtag    VARCHAR(20),' +
    '  FOREIGN KEY (mparent) REFERENCES atpair(pkey)' +
    ')';

{ TTestServerRestObjectSetCascadeDelete }

procedure TTestServerRestObjectSetCascadeDelete.Setup;
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
  // Without this the REFERENCES clauses below are decoration. The first test
  // in this fixture exists to prove the line took effect.
  FConnection.ExecuteDirect('PRAGMA foreign_keys = ON');
  FConnection.ExecuteDirect(cDDL_ROOT);
  FConnection.ExecuteDirect(cDDL_MID);
  FConnection.ExecuteDirect(cDDL_LEAF);
end;

procedure TTestServerRestObjectSetCascadeDelete.TearDown;
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

function TTestServerRestObjectSetCascadeDelete._ScalarInt(const ASQL: string): Integer;
var
  LValue: Variant;
begin
  LValue := FDConnection.ExecSQLScalar(ASQL);
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Result := -1
  else
    Result := LValue;
end;

procedure TTestServerRestObjectSetCascadeDelete._WriteTheTree;
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
  // The insert path stamps every foreign key on the way down, so the tree that
  // reaches the database satisfies both constraints. Whatever the delete does
  // next is measured against a state the constraint already accepted.
  FObjectSet.Insert(FRoot);
end;

function TTestServerRestObjectSetCascadeDelete._DeleteTheRoot: string;
begin
  Result := '';
  try
    FObjectSet.Delete(FRoot);
  except
    on E: Exception do
      Result := E.Message;
  end;
end;

procedure TTestServerRestObjectSetCascadeDelete.Premise_TheForeignKeyIsActuallyEnforced;
var
  LMessage: string;
begin
  // Not a test of the framework. SQLite accepts REFERENCES in DDL and ignores
  // it unless the pragma is on, and a suite whose constraint is inert would
  // stay green whichever order the cascade uses.
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

procedure TTestServerRestObjectSetCascadeDelete.Premise_TheTreeIsWrittenWithEveryLinkResolved;
begin
  // The control. If the tree never reached the database, or reached it with a
  // link at zero, the delete below would be walking something other than the
  // shape this suite names.
  _WriteTheTree;
  Assert.AreEqual(1, _ScalarInt('SELECT COUNT(*) FROM atroot'));
  Assert.AreEqual(1, _ScalarInt('SELECT COUNT(*) FROM atmid WHERE mparent = ' +
                                IntToStr(FRoot.rkey)));
  Assert.AreEqual(cLEAFS, _ScalarInt('SELECT COUNT(*) FROM atleaf WHERE lparent = ' +
                                     IntToStr(FRoot.mids[0].mkey)));
end;

procedure TTestServerRestObjectSetCascadeDelete.DeletingTheRootMustNotViolateTheChildsForeignKey;
var
  LMessage: string;
begin
  // The site. Deleting the middle row before its leaves is exactly what an
  // enforced foreign key is there to stop, so the order shows up as a raised
  // exception rather than as a wrong row.
  _WriteTheTree;
  LMessage := _DeleteTheRoot;
  Assert.AreEqual('', LMessage,
    'deleting the tree must not raise - a constraint violation here means the ' +
    'cascade deleted a parent row while its children still pointed at it');
end;

procedure TTestServerRestObjectSetCascadeDelete.DeletingTheRootMustEmptyEveryLevel;
begin
  // The same step measured on the rows. A cascade that raised mid-way rolls its
  // transaction back, so every level is still populated afterwards.
  _WriteTheTree;
  _DeleteTheRoot;
  Assert.AreEqual(0, _ScalarInt('SELECT COUNT(*) FROM atleaf'),
    'every leaf row must be gone');
  Assert.AreEqual(0, _ScalarInt('SELECT COUNT(*) FROM atmid'),
    'the branch row must be gone');
  Assert.AreEqual(0, _ScalarInt('SELECT COUNT(*) FROM atroot'),
    'the root row must be gone');
end;

{ TTestServerRestObjectSetCascadeDeleteOneToOne }

procedure TTestServerRestObjectSetCascadeDeleteOneToOne.Setup;
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
  FConnection.ExecuteDirect('PRAGMA foreign_keys = ON');
  FConnection.ExecuteDirect(cDDL_PAIR);
  FConnection.ExecuteDirect(cDDL_MID_ONE);
  FConnection.ExecuteDirect(cDDL_LEAF);
end;

procedure TTestServerRestObjectSetCascadeDeleteOneToOne.TearDown;
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

function TTestServerRestObjectSetCascadeDeleteOneToOne._ScalarInt(const ASQL: string): Integer;
var
  LValue: Variant;
begin
  LValue := FDConnection.ExecSQLScalar(ASQL);
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Result := -1
  else
    Result := LValue;
end;

procedure TTestServerRestObjectSetCascadeDeleteOneToOne._WriteTheTree;
var
  LMid: TAsymTreeMid;
  LLeaf: TAsymTreeLeaf;
  LFor: Integer;
begin
  FObjectSet := TRESTObjectSet.Create(FConnection, TAsymTreeOneRoot);
  FRoot := TAsymTreeOneRoot.Create;
  FRoot.ptag := cROOTTAG;
  LMid := TAsymTreeMid.Create;
  LMid.mtag := cMIDTAG;
  for LFor := 0 to cLEAFS - 1 do
  begin
    LLeaf := TAsymTreeLeaf.Create;
    LLeaf.ltag := cLEAFTAG + IntToStr(LFor);
    LMid.leafs.Add(LLeaf);
  end;
  FRoot.mid := LMid;
  FObjectSet.Insert(FRoot);
end;

function TTestServerRestObjectSetCascadeDeleteOneToOne._DeleteTheRoot: string;
begin
  Result := '';
  try
    FObjectSet.Delete(FRoot);
  except
    on E: Exception do
      Result := E.Message;
  end;
end;

procedure TTestServerRestObjectSetCascadeDeleteOneToOne.Premise_TheForeignKeyIsActuallyEnforced;
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

procedure TTestServerRestObjectSetCascadeDeleteOneToOne.Premise_TheTreeIsWrittenWithEveryLinkResolved;
begin
  _WriteTheTree;
  Assert.AreEqual(1, _ScalarInt('SELECT COUNT(*) FROM atpair'));
  Assert.AreEqual(1, _ScalarInt('SELECT COUNT(*) FROM atmid WHERE mparent = ' +
                                IntToStr(FRoot.pkey)));
  Assert.AreEqual(cLEAFS, _ScalarInt('SELECT COUNT(*) FROM atleaf WHERE lparent = ' +
                                     IntToStr(FRoot.mid.mkey)));
end;

procedure TTestServerRestObjectSetCascadeDeleteOneToOne.DeletingTheRootMustNotViolateTheChildsForeignKey;
var
  LMessage: string;
begin
  // The site, on the handler the OTHER fixture cannot reach.
  _WriteTheTree;
  LMessage := _DeleteTheRoot;
  Assert.AreEqual('', LMessage,
    'deleting the tree must not raise - a constraint violation here means the ' +
    'single-object cascade deleted a parent row while its children still ' +
    'pointed at it');
end;

procedure TTestServerRestObjectSetCascadeDeleteOneToOne.DeletingTheRootMustEmptyEveryLevel;
begin
  _WriteTheTree;
  _DeleteTheRoot;
  Assert.AreEqual(0, _ScalarInt('SELECT COUNT(*) FROM atleaf'),
    'every leaf row must be gone');
  Assert.AreEqual(0, _ScalarInt('SELECT COUNT(*) FROM atmid'),
    'the branch row must be gone');
  Assert.AreEqual(0, _ScalarInt('SELECT COUNT(*) FROM atpair'),
    'the root row must be gone');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestServerRestObjectSetCascadeDelete);
  TDUnitX.RegisterTestFixture(TTestServerRestObjectSetCascadeDeleteOneToOne);

end.
