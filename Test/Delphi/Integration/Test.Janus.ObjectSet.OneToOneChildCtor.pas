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

{ @abstract(Janus Framework - the child of a 1:1 association must arrive with
  its OWN constructor having run. Issue #369.)

  WHAT WAS WRONG

  TSQLCommandExecutor<M>.ExecuteOneToOne built the child with
  `AProperty.PropertyType.AsInstance.MetaclassType.Create` and nothing else.
  MetaclassType is a TClass, and `Create` on a class REFERENCE resolves to
  TObject.Create, which is not virtual - so the child's own constructor body
  never ran. Anything that constructor was responsible for arrived nil.

  Its sibling TSQLCommandExecutor<M>.ExecuteOneToMany does the same allocation
  and then calls MethodCall('Create', []) on the instance, which invokes the
  real constructor through RTTI. One line apart, and the difference decided
  whether data survived.

  WHY THAT LOSES ROWS, AND SILENTLY

  ExecuteOneToMany appends each child row with
  `if LObjectList <> nil then LObjectList.MethodCall('Add', ...)`. When the
  owner's list property is nil - because the owner's constructor never ran -
  that guard DISCARDS the row. No exception, no log. The objects it had just
  built are not added and not freed either, so each dropped row is also a leak.
  This fixture does not pin the leak with a pointer count: once the list
  exists the rows are added, so there is nothing left to leak, and
  instrumenting the shared Common model to prove a state that the fix removes
  would cost more than it says. It is stated instead.

  THE MEASUREMENT THAT OPENED THE ISSUE, reproduced by the clauses below

    same model, same rows, only the ROUTE differs
      via 1:1  ->  mid.leafs = nil,  grandchildren lost   (2 rows -> 0)
      via 1:N  ->  mid.leafs.Count = 2, grandchildren kept

  TAsymTreeMid is a REAL model of this repository, not one written for the
  bug: its constructor builds `Fleafs`, and it is the 1:1 target of
  TAsymTreeOneRoot. The defect was therefore reachable by a fixture that
  already existed, which is why the control clause matters - without it, a
  green "the list is not nil" could be green over a route that loaded nothing.

  WHAT IS NOT MEASURED HERE

  The REST server's own twin, TRESTObjectManager.ExecuteOneToOne, which does
  not create the child AT ALL and hands whatever it finds - possibly nil - to
  TBind.SetFieldToProperty. That is a THIRD behaviour, read and not measured,
  and it is deliberately left alone by this issue.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.ObjectSet.OneToOneChildCtor;

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
  TTestObjectSetOneToOneChildCtor = class
  private
    FDConnection: TFDConnection;
    FConnection: IDBConnection;
    FDbFile: string;
    function _ScalarInt(const ASQL: string): Integer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// PREMISE. The model really does build the list itself, so a nil list
    /// after a load is the FRAMEWORK's doing and not the model's.
    [Test]
    procedure Premise_TheChildModelBuildsItsListInItsOwnConstructor;

    /// PREMISE. The grandchild rows are in the database and linked, so a zero
    /// below cannot be a seeding mistake.
    [Test]
    procedure Premise_TheGrandchildRowsAreInTheDatabaseAndLinked;

    /// PREMISE. The 1:1 child itself loads and is bound - so the clauses below
    /// are about the CONSTRUCTOR, not about a load that failed.
    [Test]
    procedure Premise_TheOneToOneChildItselfLoadsAndIsBound;

    /// THE DEFECT. The child's own constructor must have run.
    [Test]
    procedure TheOneToOneChildArrivesWithItsConstructorHavingRun;

    /// THE DATA LOSS. The grandchildren under that child must survive.
    [Test]
    procedure TheOneToOneChildCarriesItsGrandchildren;

    /// THE CONTROL. The 1:N route already carried them, and must keep doing
    /// exactly what it did.
    [Test]
    procedure Control_TheOneToManyRouteStillCarriesItsGrandchildren;
  end;

implementation

uses
  DataEngine.FactoryFireDAC;

const
  cDBFILE = 'janus_objectset_onetoone_childctor.db';

  cDDL_PAIR =
    'CREATE TABLE IF NOT EXISTS atpair (' +
    '  pkey INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  ptag VARCHAR(20))';
  cDDL_ROOT =
    'CREATE TABLE IF NOT EXISTS atroot (' +
    '  rkey INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  rtag VARCHAR(20))';
  cDDL_MID =
    'CREATE TABLE IF NOT EXISTS atmid (' +
    '  mkey    INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  mparent INTEGER,' +
    '  mtag    VARCHAR(20))';
  cDDL_LEAF =
    'CREATE TABLE IF NOT EXISTS atleaf (' +
    '  lkey    INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  lparent INTEGER,' +
    '  ltag    VARCHAR(20))';

{ TTestObjectSetOneToOneChildCtor }

procedure TTestObjectSetOneToOneChildCtor.Setup;
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
  FConnection.ExecuteDirect(cDDL_ROOT);
  FConnection.ExecuteDirect(cDDL_MID);
  FConnection.ExecuteDirect(cDDL_LEAF);
  /// ONE mid row, hanging off BOTH roots through the same `mparent` - atpair
  /// and atroot both key on 1 - so the two routes below read the SAME child
  /// row and the SAME grandchildren. That is what makes the control a
  /// control: nothing differs except which association carried it.
  FConnection.ExecuteDirect(
    'INSERT INTO atpair (pkey, ptag) VALUES (1, ' + QuotedStr('theroot') + ')');
  FConnection.ExecuteDirect(
    'INSERT INTO atroot (rkey, rtag) VALUES (1, ' + QuotedStr('theroot') + ')');
  FConnection.ExecuteDirect(
    'INSERT INTO atmid (mkey, mparent, mtag) VALUES (10, 1, ' +
    QuotedStr('thechild') + ')');
  FConnection.ExecuteDirect(
    'INSERT INTO atleaf (lkey, lparent, ltag) VALUES (100, 10, ' +
    QuotedStr('g1') + ')');
  FConnection.ExecuteDirect(
    'INSERT INTO atleaf (lkey, lparent, ltag) VALUES (101, 10, ' +
    QuotedStr('g2') + ')');
end;

procedure TTestObjectSetOneToOneChildCtor.TearDown;
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

function TTestObjectSetOneToOneChildCtor._ScalarInt(const ASQL: string): Integer;
var
  LValue: Variant;
begin
  LValue := FDConnection.ExecSQLScalar(ASQL);
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Result := -1
  else
    Result := LValue;
end;

procedure TTestObjectSetOneToOneChildCtor
  .Premise_TheChildModelBuildsItsListInItsOwnConstructor;
var
  LMid: TAsymTreeMid;
begin
  LMid := TAsymTreeMid.Create;
  try
    Assert.IsNotNull(LMid.leafs,
      'PREMISE. Constructed the ordinary way, TAsymTreeMid builds its own ' +
      'list. Without this, a nil list after a load would say nothing about ' +
      'the framework - it could simply be a model that never builds one');
  finally
    LMid.Free;
  end;
end;

procedure TTestObjectSetOneToOneChildCtor
  .Premise_TheGrandchildRowsAreInTheDatabaseAndLinked;
begin
  Assert.AreEqual(1, _ScalarInt('SELECT COUNT(*) FROM atmid WHERE mparent = 1'),
    'PREMISE: one child row, linked to the root');
  Assert.AreEqual(2, _ScalarInt('SELECT COUNT(*) FROM atleaf WHERE lparent = 10'),
    'PREMISE: TWO grandchild rows, linked to that child. A zero further down ' +
    'is a loss only because these rows exist');
end;

procedure TTestObjectSetOneToOneChildCtor
  .Premise_TheOneToOneChildItselfLoadsAndIsBound;
var
  LSet: IContainerObjectSet<TAsymTreeOneRoot>;
  LRoot: TAsymTreeOneRoot;
begin
  LSet := TContainerObjectSet<TAsymTreeOneRoot>.Create(FConnection);
  LRoot := LSet.Find(Int64(1));
  try
    Assert.IsNotNull(LRoot, 'PREMISE: the root loaded');
    Assert.IsNotNull(LRoot.mid,
      'PREMISE: the 1:1 child object exists after the load');
    Assert.AreEqual('thechild', LRoot.mid.mtag, False,
      'PREMISE: and it is BOUND from the database. This is what separates ' +
      'the defect from a load that simply did not happen - the row arrives, ' +
      'fully bound, and only what the CONSTRUCTOR owed is missing');
    Assert.AreEqual(10, LRoot.mid.mkey, 'PREMISE: bound to the right row');
  finally
    LRoot.Free;
  end;
end;

procedure TTestObjectSetOneToOneChildCtor
  .TheOneToOneChildArrivesWithItsConstructorHavingRun;
var
  LSet: IContainerObjectSet<TAsymTreeOneRoot>;
  LRoot: TAsymTreeOneRoot;
begin
  LSet := TContainerObjectSet<TAsymTreeOneRoot>.Create(FConnection);
  LRoot := LSet.Find(Int64(1));
  try
    Assert.IsNotNull(LRoot, 'the root loaded');
    Assert.IsNotNull(LRoot.mid, 'the 1:1 child exists');
    Assert.IsNotNull(LRoot.mid.leafs,
      'THE DEFECT. The child of a 1:1 association is allocated through a ' +
      'TClass, and Create on a class reference resolves to TObject.Create, ' +
      'which is not virtual - so TAsymTreeMid.Create never ran and the list ' +
      'it builds is nil. Its 1:N sibling calls MethodCall(''Create'', []) on ' +
      'the instance right after allocating, which is exactly the line this ' +
      'route was missing');
  finally
    LRoot.Free;
  end;
end;

procedure TTestObjectSetOneToOneChildCtor
  .TheOneToOneChildCarriesItsGrandchildren;
var
  LSet: IContainerObjectSet<TAsymTreeOneRoot>;
  LRoot: TAsymTreeOneRoot;
begin
  LSet := TContainerObjectSet<TAsymTreeOneRoot>.Create(FConnection);
  LRoot := LSet.Find(Int64(1));
  try
    Assert.IsNotNull(LRoot, 'the root loaded');
    Assert.IsNotNull(LRoot.mid, 'the 1:1 child exists');
    Assert.IsNotNull(LRoot.mid.leafs, 'the child carries a list at all');
    Assert.AreEqual(2, LRoot.mid.leafs.Count,
      'THE DATA LOSS, AND IT IS SILENT. ExecuteOneToMany builds each ' +
      'grandchild and then appends it under `if LObjectList <> nil` - so a ' +
      'nil list makes that guard DISCARD every row, with no exception and no ' +
      'log, and the objects it just built are neither added nor freed. Both ' +
      'grandchild rows are in the database; a 0 here is them being thrown ' +
      'away on the way out');
  finally
    LRoot.Free;
  end;
end;

procedure TTestObjectSetOneToOneChildCtor
  .Control_TheOneToManyRouteStillCarriesItsGrandchildren;
var
  LSet: IContainerObjectSet<TAsymTreeRoot>;
  LRoot: TAsymTreeRoot;
begin
  LSet := TContainerObjectSet<TAsymTreeRoot>.Create(FConnection);
  LRoot := LSet.Find(Int64(1));
  try
    Assert.IsNotNull(LRoot, 'the root loaded');
    Assert.IsNotNull(LRoot.mids, 'the 1:N list exists');
    Assert.AreEqual(1, LRoot.mids.Count, 'one child on this route too');
    Assert.IsNotNull(LRoot.mids[0].leafs,
      'THE CONTROL. The SAME child row, reached through the 1:N route, has ' +
      'always had its constructor run - that route already called ' +
      'MethodCall(''Create'', []). If this clause ever goes red, the repair ' +
      'broke the route that was working rather than fixing the one that was ' +
      'not');
    Assert.AreEqual(2, LRoot.mids[0].leafs.Count,
      'and the same two grandchildren. Same rows, same classes - only the ' +
      'multiplicity of the association above them differs, which is what ' +
      'makes this a control and not a second measurement');
  finally
    LRoot.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestObjectSetOneToOneChildCtor);

end.
