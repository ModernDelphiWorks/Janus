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

{ @abstract(Janus Framework - the server-side lazy load of TRESTObjectSet.)

  WHAT IS UNDER TEST

  TRESTObjectSet.LoadLazy -> TRESTObjectSetSession.LoadLazy ->
  TRESTObjectManager.LoadLazy -> FillAssociationLazy.

  The middle link was a body whose only statement was commented out. Asking
  the server to load a lazy branch and asking it to do nothing produced the
  same answer: nothing, with no exception and no log. The caller reads the
  branch afterwards and finds the empty list the lazy record creates on first
  touch, which is indistinguishable from "this owner has no children".

  WHY "IT DID NOT RAISE" IS NOT A TEST HERE

  The two ways this can go wrong are both silent:

    * load nothing at all - the defect as measured;
    * load the WHOLE child table instead of this owner's rows, which is what a
      WHERE built from the wrong end of the association mapping produces.

  So every assertion in this fixture is on an ORDERED sequence of named
  markers joined into one string. The three sequences "this owner's rows",
  "the other owner's rows" and "the whole table" are deliberately different
  from one another, and different from the order the rows were written in.

  WHY THE OTHER BRANCH IS ASSERTED TOO

  LoadLazy does not name the association. It takes a sample of the CHILD and
  FillAssociationLazy picks the association whose ClassNameRef is contained in
  that sample's class name. A fixture that only checks that SOMETHING was
  loaded would pass on an implementation that loads every lazy branch it can
  find. Test.Janus.Model.LazyTwoBranch gives the owner two lazy branches to
  two different child classes; each load names one of them and the other one
  has to come back empty.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Server.RestObjectSet.LoadLazy;

interface

uses
  Classes,
  SysUtils,
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
  Test.Janus.Model.LazyTwoBranch;

type
  [TestFixture]
  TTestServerRestObjectSetLoadLazy = class
  private
    FDConnection: TFDConnection;
    FConnection: IDBConnection;
    FDbFile: string;
    FObjectSet: TRESTObjectSet;
    FRoot: TLazyBranchRoot;
    function _AlfaMarkers: String;
    function _BetaMarkers: String;
    function _OwnerWithKey(const AKey: Integer): TLazyBranchRoot;
    procedure _LoadTheAlfaBranch;
    procedure _LoadTheBetaBranch;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Premise_TheOwnerCarriesTwoLazyBranchesToTwoDifferentClasses;
    [Test]
    procedure Premise_AFreshOwnerCarriesTwoEmptyBranches;
    [Test]
    procedure LoadingTheAlfaBranchMustFillItWithThisOwnersRowsInMappedOrder;
    [Test]
    procedure LoadingTheAlfaBranchMustLeaveTheBetaBranchEmpty;
    [Test]
    procedure LoadingTheBetaBranchMustFillItAndLeaveTheAlfaBranchEmpty;
    [Test]
    procedure LoadingASecondOwnerMustBringThatOwnersRowsAndNotTheFirstOnes;
  end;

implementation

uses
  DataEngine.FactoryFireDAC;

const
  cDBFILE = 'janus_server_objectset_loadlazy.db';

  /// The owner under test and the owner that must stay out of the answer.
  cOWNER_UNDERTEST = 10;
  cOWNER_FOREIGN   = 20;

  cDDL_ROOT =
    'CREATE TABLE IF NOT EXISTS lzroot (' +
    '  rkey INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  rtag VARCHAR(20)' +
    ')';
  cDDL_ALFA =
    'CREATE TABLE IF NOT EXISTS lzalfa (' +
    '  akey   INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  aowner INTEGER,' +
    '  atag   VARCHAR(20)' +
    ')';
  cDDL_BETA =
    'CREATE TABLE IF NOT EXISTS lzbeta (' +
    '  bkey   INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  bowner INTEGER,' +
    '  btag   VARCHAR(20)' +
    ')';

  /// What the three readings look like, spelled out so a failure message says
  /// WHICH wrong answer came back:
  ///
  ///   this owner's alfas   alfa-anchor|alfa-middle|alfa-tail
  ///   the other owner's    alfa-far-one|alfa-far-two
  ///   the whole table      alfa-anchor|alfa-far-one|alfa-far-two|alfa-middle|alfa-tail
  ///   the WRITE order      alfa-tail|alfa-anchor|alfa-middle
  cALFAS_UNDERTEST = 'alfa-anchor|alfa-middle|alfa-tail';
  cALFAS_FOREIGN   = 'alfa-far-one|alfa-far-two';
  cBETAS_UNDERTEST = 'beta-first|beta-second';

{ TTestServerRestObjectSetLoadLazy }

procedure TTestServerRestObjectSetLoadLazy.Setup;
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
  FConnection.ExecuteDirect(cDDL_ALFA);
  FConnection.ExecuteDirect(cDDL_BETA);

  FConnection.ExecuteDirect(Format(
    'INSERT INTO lzroot (rkey, rtag) VALUES (%d, ''root-undertest'')', [cOWNER_UNDERTEST]));
  FConnection.ExecuteDirect(Format(
    'INSERT INTO lzroot (rkey, rtag) VALUES (%d, ''root-foreign'')', [cOWNER_FOREIGN]));

  // Written in an order that is NOT the sorted order and NOT grouped by owner.
  // A load that ignores [OrderBy] and a load that ignores the owner filter
  // therefore both produce a sequence this fixture can name.
  FConnection.ExecuteDirect(Format(
    'INSERT INTO lzalfa (aowner, atag) VALUES (%d, ''alfa-tail'')', [cOWNER_UNDERTEST]));
  FConnection.ExecuteDirect(Format(
    'INSERT INTO lzalfa (aowner, atag) VALUES (%d, ''alfa-far-two'')', [cOWNER_FOREIGN]));
  FConnection.ExecuteDirect(Format(
    'INSERT INTO lzalfa (aowner, atag) VALUES (%d, ''alfa-anchor'')', [cOWNER_UNDERTEST]));
  FConnection.ExecuteDirect(Format(
    'INSERT INTO lzalfa (aowner, atag) VALUES (%d, ''alfa-far-one'')', [cOWNER_FOREIGN]));
  FConnection.ExecuteDirect(Format(
    'INSERT INTO lzalfa (aowner, atag) VALUES (%d, ''alfa-middle'')', [cOWNER_UNDERTEST]));

  FConnection.ExecuteDirect(Format(
    'INSERT INTO lzbeta (bowner, btag) VALUES (%d, ''beta-second'')', [cOWNER_UNDERTEST]));
  FConnection.ExecuteDirect(Format(
    'INSERT INTO lzbeta (bowner, btag) VALUES (%d, ''beta-first'')', [cOWNER_UNDERTEST]));
end;

procedure TTestServerRestObjectSetLoadLazy.TearDown;
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

function TTestServerRestObjectSetLoadLazy._AlfaMarkers: String;
var
  LAlfa: TLazyBranchAlfa;
begin
  Result := '';
  for LAlfa in FRoot.alfas do
  begin
    if Result <> '' then
      Result := Result + '|';
    Result := Result + LAlfa.atag;
  end;
end;

function TTestServerRestObjectSetLoadLazy._BetaMarkers: String;
var
  LBeta: TLazyBranchBeta;
begin
  Result := '';
  for LBeta in FRoot.betas do
  begin
    if Result <> '' then
      Result := Result + '|';
    Result := Result + LBeta.btag;
  end;
end;

function TTestServerRestObjectSetLoadLazy._OwnerWithKey(
  const AKey: Integer): TLazyBranchRoot;
begin
  // The owner is built by hand instead of being fetched. Find would run
  // FillAssociation, which injects a lazy proxy factory into both branches -
  // and then reading a branch would load it through the PROXY, not through
  // the entry point under test. Built by hand, the branches are the empty
  // lists Lazy<T> creates on first touch and nothing but LoadLazy can fill
  // them.
  FObjectSet := TRESTObjectSet.Create(FConnection, TLazyBranchRoot);
  Result := TLazyBranchRoot.Create;
  Result.rkey := AKey;
end;

procedure TTestServerRestObjectSetLoadLazy._LoadTheAlfaBranch;
var
  LSample: TLazyBranchAlfa;
begin
  // The second argument is a SAMPLE of the child class, not a row: it is what
  // FillAssociationLazy matches against ClassNameRef to pick the branch.
  LSample := TLazyBranchAlfa.Create;
  try
    FObjectSet.LoadLazy(FRoot, LSample);
  finally
    LSample.Free;
  end;
end;

procedure TTestServerRestObjectSetLoadLazy._LoadTheBetaBranch;
var
  LSample: TLazyBranchBeta;
begin
  LSample := TLazyBranchBeta.Create;
  try
    FObjectSet.LoadLazy(FRoot, LSample);
  finally
    LSample.Free;
  end;
end;

procedure TTestServerRestObjectSetLoadLazy.Premise_TheOwnerCarriesTwoLazyBranchesToTwoDifferentClasses;
var
  LAssociations: TAssociationMappingList;
  LAssociation: TAssociationMapping;
  LNames: String;
  LLazyCount: Integer;
begin
  // Without Lazy = True on both, FillAssociationLazy skips them before the
  // class-name match is even consulted, and every assertion below would be
  // measuring an association that never enters the loop.
  LNames := '';
  LLazyCount := 0;
  LAssociations := TMappingExplorer.GetMappingAssociation(TLazyBranchRoot);
  Assert.IsNotNull(LAssociations, 'TLazyBranchRoot must expose associations');
  for LAssociation in LAssociations do
  begin
    if not LAssociation.Lazy then
      Continue;
    Inc(LLazyCount);
    if LNames <> '' then
      LNames := LNames + '|';
    LNames := LNames + LAssociation.ClassNameRef;
  end;
  Assert.AreEqual(2, LLazyCount,
    'the owner must carry exactly two LAZY associations - one branch cannot ' +
    'tell a selective load apart from a load-everything');
  Assert.AreEqual('TLazyBranchAlfa|TLazyBranchBeta', LNames,
    'the two lazy branches must point at those two child classes, in that ' +
    'declaration order');

  // The pick is Pos(ClassNameRef, AObject.ClassName), a substring search. If
  // either name contained the other, a sample of one class would select both.
  Assert.AreEqual(0, Pos('TLazyBranchAlfa', 'TLazyBranchBeta'),
    'the alfa class name must not be contained in the beta class name');
  Assert.AreEqual(0, Pos('TLazyBranchBeta', 'TLazyBranchAlfa'),
    'the beta class name must not be contained in the alfa class name');
end;

procedure TTestServerRestObjectSetLoadLazy.Premise_AFreshOwnerCarriesTwoEmptyBranches;
begin
  // The starting state every other test measures the change against. If a
  // fresh owner already carried rows, "the branch is filled" would prove
  // nothing about LoadLazy.
  FRoot := _OwnerWithKey(cOWNER_UNDERTEST);
  Assert.AreEqual('', _AlfaMarkers,
    'a hand-built owner must start with an empty alfa branch');
  Assert.AreEqual('', _BetaMarkers,
    'a hand-built owner must start with an empty beta branch');
end;

procedure TTestServerRestObjectSetLoadLazy.LoadingTheAlfaBranchMustFillItWithThisOwnersRowsInMappedOrder;
begin
  FRoot := _OwnerWithKey(cOWNER_UNDERTEST);
  _LoadTheAlfaBranch;
  // An empty answer is the defect: LoadLazy did nothing and said nothing.
  // The other owner's markers appearing here is the loud failure: the WHERE
  // was built from the wrong end of the association. A different order is a
  // dropped ORDER BY.
  Assert.AreEqual(cALFAS_UNDERTEST, _AlfaMarkers,
    'loading the alfa branch must fill it with THIS owner''s rows, in the ' +
    'order the child mapping asks for - an empty string here is a LoadLazy ' +
    'that loaded nothing, and any alfa-far- marker is the whole table');
end;

procedure TTestServerRestObjectSetLoadLazy.LoadingTheAlfaBranchMustLeaveTheBetaBranchEmpty;
begin
  FRoot := _OwnerWithKey(cOWNER_UNDERTEST);
  _LoadTheAlfaBranch;
  Assert.AreEqual('', _BetaMarkers,
    'loading the alfa branch must leave the beta branch untouched - the ' +
    'sample class names ONE branch, it does not ask for every lazy branch ' +
    'the owner has');
end;

procedure TTestServerRestObjectSetLoadLazy.LoadingTheBetaBranchMustFillItAndLeaveTheAlfaBranchEmpty;
begin
  FRoot := _OwnerWithKey(cOWNER_UNDERTEST);
  _LoadTheBetaBranch;
  Assert.AreEqual(cBETAS_UNDERTEST, _BetaMarkers,
    'loading the beta branch must fill the beta branch, in the order the ' +
    'child mapping asks for');
  Assert.AreEqual('', _AlfaMarkers,
    'loading the beta branch must leave the alfa branch empty - the branch ' +
    'that gets filled must follow the sample, not the declaration order');
end;

procedure TTestServerRestObjectSetLoadLazy.LoadingASecondOwnerMustBringThatOwnersRowsAndNotTheFirstOnes;
begin
  // The same call over a different owner. A filter that is built from the
  // owner really being asked about answers differently here; a constant one,
  // or none at all, answers the same twice.
  FRoot := _OwnerWithKey(cOWNER_FOREIGN);
  _LoadTheAlfaBranch;
  Assert.AreEqual(cALFAS_FOREIGN, _AlfaMarkers,
    'a second owner must get ITS own alfa rows - the same answer as the ' +
    'first owner would mean the filter does not read the owner at all');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestServerRestObjectSetLoadLazy);

end.
