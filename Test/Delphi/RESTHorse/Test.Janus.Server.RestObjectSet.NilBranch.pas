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

{ @abstract(Janus Framework - a single-object association that is nil on the
  server side cascade, issue #240.)

  WHAT IS UNDER TEST

  TRESTObjectSet.OneToOneCascadeActionsExecute. It reads the association's
  value, accepts it when TValue reports an object, and goes straight on to use
  it. TValue reports tkClass for a nil instance too, so a branch that was never
  filled in arrives at FSession.Insert as nil, and the mapping lookup inside
  dereferences it.

  The base adapter, TObjectSetBaseAdapter<M>.OneToOneCascadeActionsExecute,
  takes the object out of the TValue and exits when it is nil, BEFORE any of
  the three branches. The server copy does not carry that line.

  WHAT THE MEASUREMENT LOOKS LIKE

  `Access violation ... Read of address 00000000`, wrapped by the transaction
  handler in TRESTObjectSet.Insert, which rolls back - so the master row is not
  written either. A record whose optional nested object was simply not sent
  cannot be created at all.

  This is the shape a REST server meets constantly: a resource with an optional
  nested object, and a request body that omits it.

  WHY THE FIXTURE ALREADY FITS

  Test.Janus.Model.AsymTree's TAsymTreeOneRoot deliberately does NOT create its
  branch in a constructor - it starts nil by design, for the sibling suite that
  needed a root whose branch is absent from a Modify snapshot. The same
  property serves here with nothing added.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Server.RestObjectSet.NilBranch;

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
  TTestServerRestObjectSetNilBranch = class
  private
    FDConnection: TFDConnection;
    FConnection: IDBConnection;
    FDbFile: string;
    FObjectSet: TRESTObjectSet;
    FRoot: TAsymTreeOneRoot;
    function _ScalarInt(const ASQL: string): Integer;
    function _InsertARootWithNoBranch: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Premise_TheBranchIsASingleObjectAssociationAndStartsNil;
    [Test]
    procedure InsertingARootWhoseBranchIsNilMustNotRaise;
    [Test]
    procedure InsertingARootWhoseBranchIsNilMustStillWriteTheRow;
  end;

implementation

uses
  DataEngine.FactoryFireDAC;

const
  cDBFILE  = 'janus_server_objectset_nilbranch.db';
  cROOTTAG = 'root';

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

{ TTestServerRestObjectSetNilBranch }

procedure TTestServerRestObjectSetNilBranch.Setup;
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
end;

procedure TTestServerRestObjectSetNilBranch.TearDown;
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

function TTestServerRestObjectSetNilBranch._ScalarInt(const ASQL: string): Integer;
var
  LValue: Variant;
begin
  LValue := FDConnection.ExecSQLScalar(ASQL);
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Result := -1
  else
    Result := LValue;
end;

function TTestServerRestObjectSetNilBranch._InsertARootWithNoBranch: string;
begin
  Result := '';
  FObjectSet := TRESTObjectSet.Create(FConnection, TAsymTreeOneRoot);
  FRoot := TAsymTreeOneRoot.Create;
  FRoot.ptag := cROOTTAG;
  // FRoot.mid is left exactly as the constructor leaves it: nil.
  try
    FObjectSet.Insert(FRoot);
  except
    on E: Exception do
      Result := E.Message;
  end;
end;

procedure TTestServerRestObjectSetNilBranch.Premise_TheBranchIsASingleObjectAssociationAndStartsNil;
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LRoot: TAsymTreeOneRoot;
  LFound: Boolean;
begin
  // Without a single-object multiplicity the cascade goes to the OTHER handler,
  // and without CascadeInsert the branch is skipped before the value is read.
  // And if the model ever started creating its branch, the value under test
  // would not be nil at all.
  LFound := False;
  LAssociations := TMappingExplorer.GetMappingAssociation(TAsymTreeOneRoot);
  Assert.IsNotNull(LAssociations, 'TAsymTreeOneRoot must expose associations');
  for LAssociation in LAssociations do
  begin
    if LAssociation.Multiplicity <> TMultiplicity.OneToOne then
      Continue;
    LFound := True;
    Assert.IsTrue(TCascadeAction.CascadeInsert in LAssociation.CascadeActions,
      'the OneToOne association must cascade on insert');
  end;
  Assert.IsTrue(LFound, 'TAsymTreeOneRoot must reach the OneToOne handler');
  LRoot := TAsymTreeOneRoot.Create;
  try
    Assert.IsNull(LRoot.mid,
      'a freshly created root must carry a nil branch - that is the value ' +
      'this fixture hands the cascade');
  finally
    LRoot.Free;
  end;
end;

procedure TTestServerRestObjectSetNilBranch.InsertingARootWhoseBranchIsNilMustNotRaise;
begin
  // The site. An optional nested object that was not sent is nil, and the
  // handler uses it without asking.
  Assert.AreEqual('', _InsertARootWithNoBranch,
    'inserting a root whose optional branch is nil must not raise - an access ' +
    'violation here is the missing nil guard');
end;

procedure TTestServerRestObjectSetNilBranch.InsertingARootWhoseBranchIsNilMustStillWriteTheRow;
begin
  // The same step measured on the rows. The exception is raised inside the
  // transaction, so the master row is rolled back with it: the record cannot
  // be created at all, not merely created without its branch.
  _InsertARootWithNoBranch;
  Assert.AreEqual(1, _ScalarInt('SELECT COUNT(*) FROM atpair'),
    'the master row must be written even though the branch is absent');
  Assert.AreEqual(0, _ScalarInt('SELECT COUNT(*) FROM atmid'),
    'a nil branch must write no branch row');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestServerRestObjectSetNilBranch);

end.
