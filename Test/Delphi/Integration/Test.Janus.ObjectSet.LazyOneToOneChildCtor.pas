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

{ @abstract(Janus Framework - the child of a LAZY single-object association
  must arrive with its OWN constructor having run. The lazy twin of #369.)

  WHAT IS WRONG

  Janus.Mapping.Lazy.CreateLazySingleAssociationLoadFunc builds the child with
  `LChildClass.Create` and nothing else. LChildClass is a TClass, and Create on
  a class REFERENCE binds STATICALLY to TObject.Create - the instance is
  allocated and zero-filled and the model's own constructor body never runs.
  The cause is the binding, not virtual dispatch: a virtual constructor reached
  the same way fails identically. The canonical account, with the eight-shape
  measurement behind it, is at Janus.Objects.Helper.TObjectHelper.MethodCall.

  Its own neighbour in the SAME unit, CreateLazyManyAssociationLoadFunc,
  allocates the same way and then calls MethodCall('Create', []) on the
  instance. Twelve lines apart, and the difference decides whether data
  survives.

  WHY THE SUITE WAS GREEN OVER A LIVE DEFECT - MEASURED, NOT ASSUMED

  A probe inside the load function, writing owner and child class names to a
  file, was run over the whole of Janus.Tests.Units at 8f5864f. The site
  executed exactly THREE times in 715 tests: TExame -> TProcedimento, three
  rows, all three from
  Test.Janus.Cursor.Advance.LazySingleAssociation_ThreeRows_Terminates, which
  calls the function DIRECTLY. So:

    - NO PUBLIC ROUTE reached it. Not one test loaded a lazy single-object
      association through an ObjectSet, a DataSet or the REST server.
    - The only target that ever arrived was TProcedimento, whose constructor
      is EMPTY, so a skipped constructor had nothing to lose.
    - The one fixture that drove it asserted on cursor advance, never on the
      state of the object it got back.

  The same probe over Janus.Tests.RESTfulDriver produced NO output at all: 283
  tests, site never reached.

  This fixture closes both holes at once - it is the first test in the
  repository to reach that load function through the public ObjectSet API, and
  the first to assert anything about the object it hands back.

  WHAT THE ROUTES ARE, AND WHY THESE CONTROLS

    lzlazy  --(OneToOne,  Lazy)--> lzchild    the route under test
    lzmany  --(OneToMany, Lazy)--> lzchild    CONTROL: lazy is not the cause
    lzeager --(OneToMany      )--> lzchild    CONTROL: the data is not the cause

  The EAGER single-object route is deliberately NOT a control: when this
  fixture was written it CARRIED the same defect, its repair was issue #369 on
  a different branch, and used here it would have been red beside the clause
  under test and would have isolated nothing. That repair has since landed -
  #371 (81d3c14), which merged BEFORE this fixture - so the eager route is no
  longer defective; the reason it is not a control is historical only.

  WHAT THE `2 -> 0` IS AND IS NOT

  In the defective state the loss clause dies at the same
  `Assert.IsNotNull(grands)` the first clause dies at, so its
  `Assert.AreEqual(2, Count)` is never exercised in red - a nil list has no
  Count. The `0` half rests on the seeding premise, which proves the two rows
  exist to be lost, and on the two controls, which prove those same rows do
  reach an object graph by every other route. The count assertion earns its
  keep in GREEN, where it separates "a list exists" from "the rows were
  appended to it".

  THE LEAK THIS FIXTURE STATES AND DOES NOT PIN

  ExecuteOneToMany appends each grandchild under `if LObjectList <> nil`, so
  with a nil list every row it has just built is neither added nor freed. Once
  the repair lands the list exists and there is nothing left to leak, so
  instrumenting for it would measure a state the repair removes.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.ObjectSet.LazyOneToOneChildCtor;

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
  Test.Janus.Model.LazyCtor;

type
  [TestFixture]
  TTestObjectSetLazyOneToOneChildCtor = class
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

    /// PREMISE. The model really builds the list in its own constructor, so a
    /// nil list after a load is the FRAMEWORK's doing, not the model's.
    [Test]
    procedure Premise_TheChildModelBuildsItsListInItsOwnConstructor;

    /// PREMISE. The rows exist and are linked, so a zero below cannot be a
    /// seeding mistake.
    [Test]
    procedure Premise_TheRowsAreInTheDatabaseAndLinked;

    /// PREMISE. The mapping - READ, not assumed from the attribute text - says
    /// this association is single-object AND lazy. Without this the whole
    /// fixture could be measuring some other route.
    [Test]
    procedure Premise_TheMappingSaysSingleObjectAndLazy;

    /// PREMISE. The route really is the LAZY one, proved BEHAVIOURALLY: the
    /// child row is edited AFTER Find and BEFORE the property is touched, and
    /// the value that arrives is the edit.
    [Test]
    procedure Premise_TheLoadHappensWhenThePropertyIsTouchedNotAtFind;

    /// PREMISE. The object that comes back is bound FROM THE DATABASE, which
    /// is what separates the defect from a load that never happened - and also
    /// rules out Lazy<T>.CreateDefaultValue, whose blank instance would carry
    /// no key and no tag.
    [Test]
    procedure Premise_TheLazyChildItselfLoadsAndIsBound;

    /// THE DEFECT. The child's own constructor must have run.
    [Test]
    procedure TheLazyOneToOneChildArrivesWithItsConstructorHavingRun;

    /// THE DATA LOSS. The grandchildren under that child must survive.
    [Test]
    procedure TheLazyOneToOneChildCarriesItsGrandchildren;

    /// CONTROL. The LAZY collection route - same lazy machinery, same child
    /// class, same row - already ran the constructor and must keep doing it.
    [Test]
    procedure Control_TheLazyOneToManyRouteRunsTheChildConstructor;

    /// CONTROL. The EAGER collection route, likewise. Together with the one
    /// above it leaves only the single-object lazy variant as the difference.
    [Test]
    procedure Control_TheEagerOneToManyRouteRunsTheChildConstructor;
  end;

implementation

uses
  DataEngine.FactoryFireDAC;

const
  cDBFILE = 'janus_objectset_lazy_onetoone_childctor.db';

  cDDL_LAZY =
    'CREATE TABLE IF NOT EXISTS lzlazy (' +
    '  zkey INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  ztag VARCHAR(20))';
  cDDL_MANY =
    'CREATE TABLE IF NOT EXISTS lzmany (' +
    '  ykey INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  ytag VARCHAR(20))';
  cDDL_EAGER =
    'CREATE TABLE IF NOT EXISTS lzeager (' +
    '  ekey INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  etag VARCHAR(20))';
  cDDL_CHILD =
    'CREATE TABLE IF NOT EXISTS lzchild (' +
    '  ckey    INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  cparent INTEGER,' +
    '  ctag    VARCHAR(20))';
  cDDL_GRAND =
    'CREATE TABLE IF NOT EXISTS lzgrand (' +
    '  gkey    INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  gparent INTEGER,' +
    '  gtag    VARCHAR(20))';

{ TTestObjectSetLazyOneToOneChildCtor }

procedure TTestObjectSetLazyOneToOneChildCtor.Setup;
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
  FConnection.ExecuteDirect(cDDL_LAZY);
  FConnection.ExecuteDirect(cDDL_MANY);
  FConnection.ExecuteDirect(cDDL_EAGER);
  FConnection.ExecuteDirect(cDDL_CHILD);
  FConnection.ExecuteDirect(cDDL_GRAND);
  /// ONE child row hanging off ALL THREE roots through the same `cparent` -
  /// every root keys on 1 - so the three routes read the SAME child row and
  /// the SAME grandchildren. That is what makes the controls controls:
  /// nothing differs except which association carried it.
  FConnection.ExecuteDirect(
    'INSERT INTO lzlazy (zkey, ztag) VALUES (1, ' + QuotedStr('theroot') + ')');
  FConnection.ExecuteDirect(
    'INSERT INTO lzmany (ykey, ytag) VALUES (1, ' + QuotedStr('theroot') + ')');
  FConnection.ExecuteDirect(
    'INSERT INTO lzeager (ekey, etag) VALUES (1, ' + QuotedStr('theroot') + ')');
  FConnection.ExecuteDirect(
    'INSERT INTO lzchild (ckey, cparent, ctag) VALUES (10, 1, ' +
    QuotedStr('thechild') + ')');
  FConnection.ExecuteDirect(
    'INSERT INTO lzgrand (gkey, gparent, gtag) VALUES (100, 10, ' +
    QuotedStr('g1') + ')');
  FConnection.ExecuteDirect(
    'INSERT INTO lzgrand (gkey, gparent, gtag) VALUES (101, 10, ' +
    QuotedStr('g2') + ')');
end;

procedure TTestObjectSetLazyOneToOneChildCtor.TearDown;
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

function TTestObjectSetLazyOneToOneChildCtor._ScalarInt(
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

procedure TTestObjectSetLazyOneToOneChildCtor
  .Premise_TheChildModelBuildsItsListInItsOwnConstructor;
var
  LChild: TLazyCtorChild;
begin
  LChild := TLazyCtorChild.Create;
  try
    Assert.IsNotNull(LChild.grands,
      'PREMISE. Constructed the ordinary way, TLazyCtorChild builds its own ' +
      'list. Without this a nil list after a load would say nothing about ' +
      'the framework - it could simply be a model that never builds one');
  finally
    LChild.Free;
  end;
end;

procedure TTestObjectSetLazyOneToOneChildCtor
  .Premise_TheRowsAreInTheDatabaseAndLinked;
begin
  Assert.AreEqual(1, _ScalarInt('SELECT COUNT(*) FROM lzchild WHERE cparent = 1'),
    'PREMISE: one child row, linked to every root');
  Assert.AreEqual(2, _ScalarInt('SELECT COUNT(*) FROM lzgrand WHERE gparent = 10'),
    'PREMISE: TWO grandchild rows under that child. A zero further down is a ' +
    'loss only because these rows exist');
end;

procedure TTestObjectSetLazyOneToOneChildCtor
  .Premise_TheMappingSaysSingleObjectAndLazy;
var
  LList: TAssociationMappingList;
  LItem: TAssociationMapping;
  LFound: TAssociationMapping;
begin
  /// READ THE MAPPING, do not trust the attribute text. What routes the load
  /// is TSQLCommandExecutor<M>.FillAssociation reading Multiplicity and Lazy
  /// off this object, so this is the only statement of "1:1 and lazy" that
  /// the framework itself acts on.
  LFound := nil;
  LList := TMappingExplorer.GetMappingAssociation(TLazyCtorLazyRoot);
  Assert.IsNotNull(LList, 'PREMISE: the lazy root must have associations');
  for LItem in LList do
    if SameText(LItem.PropertyRtti.Name, 'child') then
      LFound := LItem;
  Assert.IsNotNull(LFound,
    'PREMISE: the association must be carried by the NAVIGATION property, ' +
    'which is what CreateLazySingleAssociationLoadFunc dereferences as ' +
    'PropertyType.AsInstance.MetaclassType');
  Assert.IsTrue(LFound.Multiplicity = TMultiplicity.OneToOne,
    'PREMISE: single-object multiplicity - this is what sends FillAssociation ' +
    'to the SINGLE load function rather than the collection one');
  Assert.IsTrue(LFound.Lazy,
    'PREMISE: and LAZY - this is what makes FillAssociation inject a proxy ' +
    'and `Continue` instead of executing the eager path');
  Assert.AreEqual('TLazyCtorChild', LFound.ClassNameRef, False,
    'PREMISE: and it points at the child whose constructor builds a list');
end;

procedure TTestObjectSetLazyOneToOneChildCtor
  .Premise_TheLoadHappensWhenThePropertyIsTouchedNotAtFind;
var
  LSet: IContainerObjectSet<TLazyCtorLazyRoot>;
  LRoot: TLazyCtorLazyRoot;
begin
  /// THE PREMISE THAT NAMES THE ROUTE, AND IT IS BEHAVIOURAL ON PURPOSE.
  /// Asking the Lazy<T> record whether its proxy has fired is not available
  /// from here: ILazy<T> descends from TFunc<T>, so member access AUTO-INVOKES
  /// it - `LLazy.IsValueCreated` does not compile, and reaching past that with
  /// a Pointer() typecast AVs, because the invocation happens inside the cast
  /// too. Both measured. So the fixture asks the DATABASE instead.
  ///
  /// The row is edited AFTER Find and BEFORE the property is touched. Three
  /// outcomes, three different verdicts, and only one of them is lazy:
  ///   'lateedit' -> the SELECT ran on the touch. LAZY, which is the claim.
  ///   'thechild' -> the SELECT ran during Find. EAGER, and this whole
  ///                 fixture would be measuring the #369 route by mistake.
  ///   ''         -> no proxy was injected and Lazy<T>.CreateDefaultValue
  ///                 handed back a blank instance built by a REAL
  ///                 constructor - which would make the clauses below go
  ///                 green over a route that never touched the database.
  LSet := TContainerObjectSet<TLazyCtorLazyRoot>.Create(FConnection);
  LRoot := LSet.Find(Int64(1));
  try
    Assert.IsNotNull(LRoot, 'PREMISE: the root loaded');
    FConnection.ExecuteDirect(
      'UPDATE lzchild SET ctag = ' + QuotedStr('lateedit') + ' WHERE ckey = 10');
    Assert.IsNotNull(LRoot.child, 'PREMISE: touching the property yields a child');
    Assert.AreEqual('lateedit', LRoot.child.ctag, False,
      'PREMISE: the child carries an edit made AFTER Find returned, so the ' +
      'SELECT that built it ran when the property was TOUCHED. That is the ' +
      'lazy route, and it is also proof the object came from the database ' +
      'rather than from Lazy<T>.CreateDefaultValue');
  finally
    LRoot.Free;
  end;
end;

procedure TTestObjectSetLazyOneToOneChildCtor
  .Premise_TheLazyChildItselfLoadsAndIsBound;
var
  LSet: IContainerObjectSet<TLazyCtorLazyRoot>;
  LRoot: TLazyCtorLazyRoot;
begin
  LSet := TContainerObjectSet<TLazyCtorLazyRoot>.Create(FConnection);
  LRoot := LSet.Find(Int64(1));
  try
    Assert.IsNotNull(LRoot, 'PREMISE: the root loaded');
    Assert.IsNotNull(LRoot.child,
      'PREMISE: the lazy single-object child exists after the touch');
    Assert.AreEqual(10, LRoot.child.ckey,
      'PREMISE: bound to the right ROW. A blank default instance would carry ' +
      'zero here');
    Assert.AreEqual('thechild', LRoot.child.ctag, False,
      'PREMISE: and BOUND from the database. This is what separates the ' +
      'defect from a load that simply did not happen - the row arrives fully ' +
      'bound, and only what the CONSTRUCTOR owed is missing');
  finally
    LRoot.Free;
  end;
end;

procedure TTestObjectSetLazyOneToOneChildCtor
  .TheLazyOneToOneChildArrivesWithItsConstructorHavingRun;
var
  LSet: IContainerObjectSet<TLazyCtorLazyRoot>;
  LRoot: TLazyCtorLazyRoot;
begin
  LSet := TContainerObjectSet<TLazyCtorLazyRoot>.Create(FConnection);
  LRoot := LSet.Find(Int64(1));
  try
    Assert.IsNotNull(LRoot, 'the root loaded');
    Assert.IsNotNull(LRoot.child, 'the lazy single-object child exists');
    Assert.IsNotNull(LRoot.child.grands,
      'THE DEFECT. CreateLazySingleAssociationLoadFunc allocates the child ' +
      'with LChildClass.Create, and Create on a class REFERENCE binds ' +
      'statically to TObject.Create - so TLazyCtorChild.Create never ran and ' +
      'the list it builds is nil. Its neighbour in the very same unit, ' +
      'CreateLazyManyAssociationLoadFunc, calls MethodCall(''Create'', []) on ' +
      'the instance right after allocating it, which is exactly the line this ' +
      'route was missing');
  finally
    LRoot.Free;
  end;
end;

procedure TTestObjectSetLazyOneToOneChildCtor
  .TheLazyOneToOneChildCarriesItsGrandchildren;
var
  LSet: IContainerObjectSet<TLazyCtorLazyRoot>;
  LRoot: TLazyCtorLazyRoot;
begin
  LSet := TContainerObjectSet<TLazyCtorLazyRoot>.Create(FConnection);
  LRoot := LSet.Find(Int64(1));
  try
    Assert.IsNotNull(LRoot, 'the root loaded');
    Assert.IsNotNull(LRoot.child, 'the lazy single-object child exists');
    Assert.IsNotNull(LRoot.child.grands, 'the child carries a list at all');
    Assert.AreEqual(2, LRoot.child.grands.Count,
      'THE DATA LOSS, AND IT IS SILENT. Materialising the lazy child calls ' +
      'FillAssociation on it, and ExecuteOneToMany appends each grandchild ' +
      'under `if LObjectList <> nil` - so a nil list makes that guard DISCARD ' +
      'every row, with no exception and no log, and the objects it just built ' +
      'are neither added nor freed. Both grandchild rows are in the database; ' +
      'a 0 here is them being thrown away on the way out');
  finally
    LRoot.Free;
  end;
end;

procedure TTestObjectSetLazyOneToOneChildCtor
  .Control_TheLazyOneToManyRouteRunsTheChildConstructor;
var
  LSet: IContainerObjectSet<TLazyCtorManyRoot>;
  LRoot: TLazyCtorManyRoot;
begin
  LSet := TContainerObjectSet<TLazyCtorManyRoot>.Create(FConnection);
  LRoot := LSet.Find(Int64(1));
  try
    Assert.IsNotNull(LRoot, 'the root loaded');
    Assert.IsNotNull(LRoot.kids, 'the lazy collection materialised');
    Assert.AreEqual(1, LRoot.kids.Count, 'the same one child row');
    Assert.IsNotNull(LRoot.kids[0].grands,
      'THE CONTROL THAT ISOLATES THE CAUSE TO THE SINGLE-OBJECT VARIANT. This ' +
      'is the SAME lazy machinery - same proxy, same session token, same load ' +
      'function family, same child class, same row - differing only in ' +
      'multiplicity, and it has always called MethodCall(''Create'', []). If ' +
      'this clause is green while the one above is red, the cause is not ' +
      'laziness and not the model: it is the single-object load function');
    Assert.AreEqual(2, LRoot.kids[0].grands.Count,
      'and the same two grandchildren survive on this route');
  finally
    LRoot.Free;
  end;
end;

procedure TTestObjectSetLazyOneToOneChildCtor
  .Control_TheEagerOneToManyRouteRunsTheChildConstructor;
var
  LSet: IContainerObjectSet<TLazyCtorEagerRoot>;
  LRoot: TLazyCtorEagerRoot;
begin
  LSet := TContainerObjectSet<TLazyCtorEagerRoot>.Create(FConnection);
  LRoot := LSet.Find(Int64(1));
  try
    Assert.IsNotNull(LRoot, 'the root loaded');
    Assert.IsNotNull(LRoot.kids, 'the eager list exists');
    Assert.AreEqual(1, LRoot.kids.Count, 'the same one child row');
    Assert.IsNotNull(LRoot.kids[0].grands,
      'THE CONTROL THAT CLEARS THE SCHEMA AND THE DATA. Same rows, same ' +
      'classes, no lazy machinery at all. A red here would mean the fixture ' +
      'is measuring a seeding or mapping mistake rather than the load ' +
      'function');
    Assert.AreEqual(2, LRoot.kids[0].grands.Count,
      'and the same two grandchildren survive on this route');
  finally
    LRoot.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestObjectSetLazyOneToOneChildCtor);

end.
