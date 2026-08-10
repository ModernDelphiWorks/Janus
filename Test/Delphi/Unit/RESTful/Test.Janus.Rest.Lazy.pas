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

{ @abstract(Janus Framework - lazy load and lazy unload on the REST family.
  Issue #251.)

  WHAT IS UNDER TEST

  TRESTDataSetAdapter<M>.LoadLazy, which had an EMPTY BODY: asking it to load a
  child and asking it to unload one produced the same answer - nothing, and no
  warning. Both branches now exist, and both are measured here.

  THE LOAD BRANCH IS NOT PROVED BY "IT DID NOT RAISE"

  The failure mode this feature has is not an exception, it is a load that
  brings back the WHOLE child resource instead of the rows of one master. A
  test that only checked for the absence of an error would pass on exactly the
  defect worth catching. So the double here is a SERVER THAT REALLY FILTERS,
  the seeded rows of the two masters are INTERLEAVED, and every assertion is on
  an ORDERED sequence of named markers - never on a set, and never on a count.

      cparent 10 -> ten-alpha, ten-beta, ten-delta
      cparent 20 -> twenty-gamma, twenty-epsilon

  Server order is alpha, beta, gamma, delta, epsilon, so "the whole table",
  "the right subset" and "the other master's subset" are three different
  strings, and a swap of the two ends of the association is a fourth.

  WHY Test.Janus.Model.AsymKey AND NOT THE TREE MODELS

  The association is mdmaster.mkey -> mdchild.cparent. The two ends are spelled
  DIFFERENTLY on purpose, so a WHERE that names the master column where it
  should name the child column produces a different string instead of the same
  one. Every model in the tree family names both ends `root_id`, which would
  make that mistake invisible.

  WHAT THE FILTER TEXT HAS TO LOOK LIKE, AND WHY IT IS ASSERTED LITERALLY

  TSessionRestFul<M>._ParseOperator rewrites ' = ' into ' eq ' - with the
  spaces INSIDE the pattern. A WHERE written without the spaces is not
  rewritten at all and reaches the server as something its OData tokenizer was
  not asked to read. The filter is therefore asserted as the exact string
  `cparent eq 10`, which pins three separate things at once: the child column
  on the left, the master's value on the right, and the rewrite having
  happened.

  THE "ALREADY LOADED" FLAG IS THE LOCAL FAMILY'S, DELIBERATELY

  FOrmDataSet.Active. #248 measured that this flag lies for as long as nothing
  ever closes the dataset, and the answer there was to make Close close for
  real rather than to change the flag. The question is identical in both
  families and the answer here is copied rather than reinvented; the two guard
  tests below pin the copy.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Rest.Lazy;

interface

uses
  DB,
  Classes,
  SysUtils,
  StrUtils,
  Generics.Collections,
  DUnitX.TestFramework,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Param,
  FireDAC.Stan.Error,
  FireDAC.DatS,
  FireDAC.Phys.Intf,
  FireDAC.DApt.Intf,
  FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  Janus.Client.Methods,
  Janus.RestFactory.Interfaces,
  Janus.DataSet.Base.Adapter,
  Janus.RestDataSet.FDMemTable,
  Test.Janus.Model.AsymKey,
  Test.Janus.Model.AutoIncTree;

type
  /// <summary> One seeded child row on the "server" side. </summary>
  TSeededChild = record
    ckey: Integer;
    cparent: Integer;
    ctag: String;
  end;

  /// <summary> An IRESTConnection that never leaves the process and ANSWERS
  ///  ACCORDING TO THE $filter IT WAS GIVEN. The recording double in
  ///  Test.Janus.RestConnection.Double answers the same canned body to
  ///  everything, which cannot tell a filtered load from a load that fetched
  ///  the whole resource - and that is precisely the distinction #251 is about.
  ///
  ///  ITS THREE ANSWERS ARE A CONTRACT, NOT AN IMITATION OF THE REAL SERVER:
  ///    * no $filter, or an empty one  -> the WHOLE seeded table. This models
  ///      "no filter reached the server", the outcome the empty LoadLazy body
  ///      would have produced through FSession.Find.
  ///    * `cparent eq N`               -> only the rows whose cparent is N,
  ///      in seeded order.
  ///    * anything else                -> the WHOLE table again, and the text
  ///      is kept in LastFilter so the test can name what actually arrived.
  ///  A wrong filter therefore fails LOUDLY, as the whole table, instead of
  ///  quietly as an empty result that an assertion might mistake for
  ///  "nothing matched". </summary>
  TFilteringRestConnection = class(TInterfacedObject, IRESTConnection)
  private
    FRows: TList<TSeededChild>;
    FQueryParams: TStringList;
    FLastFilter: String;
    FCallCount: Integer;
    function DoExecute(const AResource, ASubResource: String;
      const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc): String;
    function GetLastFilter: String;
    function GetCallCount: Integer;
    function _CurrentFilter: String;
    function _RowsAsJson(const AParent: Integer;
      const AAll: Boolean): String;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Seed(const ACKey, ACParent: Integer; const ACTag: String);
    // IRESTConnection
    function GetBaseURL: String;
    function GetFullURL: String;
    function GetUsername: String;
    function GetPassword: String;
    function GetMethodGET: String;
    function GetMethodGETId: String;
    function GetMethodGETWhere: String;
    function GetMethodPOST: String;
    function GetMethodPUT: String;
    function GetMethodDELETE: String;
    function GetMethodGETNextPacket: String;
    function GetMethodGETNextPacketWhere: String;
    function GetMethodToken: String;
    function GetServerUse: Boolean;
    procedure SetCommandMonitor(AMonitor: ICommandMonitor);
    procedure SetClassNotServerUse(const Value: Boolean);
    function CommandMonitor: ICommandMonitor;
    function Execute(const AResource, ASubResource: String;
      const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): String; overload;
    function Execute(const AResource: String;
      const ARequestMethod: TRESTRequestMethodType;
      const AParams: TProc = nil): String; overload;
    procedure AddParam(AValue: String);
    procedure AddQueryParam(AValue: String);
    procedure AddBodyParam(AValue: String);
    // transcript
    property LastFilter: String read GetLastFilter;
    property CallCount: Integer read GetCallCount;
  end;

  /// <summary> Classic cracker descendant. LoadLazy, Close and FMasterObject
  ///  are all protected, and LoadLazy is the whole subject here. </summary>
  TRestLazyCrack<M: class, constructor> = class(TRESTFDMemTableAdapter<M>)
  public
    class procedure Lazy(const AAdapter: TRESTFDMemTableAdapter<M>;
      const AOwner: M);
    class procedure CloseIt(const AAdapter: TRESTFDMemTableAdapter<M>);
    /// The registry the master keeps of its children, as an ORDERED, sorted,
    /// comma-separated list of class names. Which child left and which stayed
    /// is the state change the unload branch is FOR - a count would not say.
    class function RegisteredChilds(
      const AAdapter: TRESTFDMemTableAdapter<M>): String;
  end;

  [TestFixture]
  TTestRestLazy = class
  private
    FConn: IRESTConnection;
    FServer: TFilteringRestConnection;
    FMasterMem: TFDMemTable;
    FMemMaster: TRESTFDMemTableAdapter<TAsymMaster>;
    FChildMem: TFDMemTable;
    FMemChild: TRESTFDMemTableAdapter<TAsymChild>;
    FSiblingMem: TFDMemTable;
    FMemSibling: TRESTFDMemTableAdapter<TAitNoCascade>;
    /// Master with two rows and a child adapter that owns NO master yet - the
    /// only shape in which the load branch is reachable at all.
    procedure BuildPair;
    /// The same, minus the Close: the child comes out as the constructor
    /// leaves it, OPEN. Only the 'already loaded' guard can answer then.
    procedure BuildPairLeavingChildOpen;
    /// The same, plus a second adapter registered under the same master. It is
    /// never loaded; it is there so the unload can be shown to take exactly
    /// one child away and leave the other alone.
    procedure BuildPairWithSibling;
    procedure AddMasterRow(const AKey: Integer; const ATag: String);
    /// Positions the master on the row whose mkey is AKey, and says so if it
    /// could not - a silently mispositioned master would make every filter
    /// assertion below measure the wrong thing.
    procedure MasterGoTo(const AKey: Integer);
    /// The ordered marker sequence actually sitting in the child dataset,
    /// joined by '|'. Reading it walks the dataset from the first row to the
    /// last, so the ORDER is part of the answer.
    function ChildTags: String;
    function SiblingIds: String;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// The premise every measurement rests on: the two ends of the association
    /// are spelled differently, so naming the wrong one is visible.
    [Test]
    procedure Premise_TheAssociationEndsAreSpelledDifferently;
    /// And the premise about the double: with no filter it hands back the
    /// whole table, which is the shape the old empty body would have produced.
    [Test]
    procedure Premise_WithoutAFilterTheServerHandsBackTheWholeTable;

    // -----------------------------------------------------------------------
    // The load branch
    // -----------------------------------------------------------------------

    /// LOAD-BEARING. The exact filter text: child column on the left, master's
    /// value on the right, and ' = ' already rewritten into ' eq '.
    [Test]
    procedure Load_TheFilterNamesTheChildColumnAndTheMasterValue;
    /// LOAD-BEARING. Only the rows of THIS master come back, in order. The
    /// whole table and the other master's rows are both named in the failure
    /// message so a wrong answer says which wrong answer it is.
    [Test]
    procedure Load_OnlyTheRowsOfThisMasterComeBackAndInThatOrder;
    /// The load registers the child under the master - SetMasterObject(AOwner)
    /// is half of what the branch does and the unload undoes exactly it.
    [Test]
    procedure Load_TheChildEndsUpRegisteredUnderTheMaster;
    /// LOAD-BEARING, and the round trip: unload, move the master cursor, load
    /// again. The second load must follow the master's NEW row. This fails if
    /// the filter value is taken from anywhere but the master's current row,
    /// and it also fails if the unload did not really unload, because then the
    /// two guards would send the second load straight back out.
    [Test]
    procedure Load_AfterAnUnloadTheNextLoadFollowsTheMasterCursor;
    /// The 'already loaded' guard, copied from TDataSetAdapter<M>.LoadLazy.
    /// It is measured on a child that is OPEN and owns NO master, because
    /// that is the only state in which this guard is the ONLY one standing -
    /// after a load the FOwnerMasterObject guard would answer first and a
    /// test written that way stays green with this guard deleted. Measured:
    /// it did.
    [Test]
    procedure Load_AnAlreadyOpenChildIsNotFetchedAtAll;
    /// The other guard: a child that already has a master is left alone.
    [Test]
    procedure Load_AChildThatAlreadyHasAMasterIsNotLoadedAgain;

    // -----------------------------------------------------------------------
    // The unload branch
    // -----------------------------------------------------------------------

    /// LOAD-BEARING. The unload CLOSES the child for real and takes it OUT of
    /// the master's registry - and takes only it: the sibling stays registered
    /// and keeps its own rows, in order.
    [Test]
    procedure Unload_ClosesThisChildAndUnregistersOnlyIt;
    /// The unload's first guard: no master registered, nothing to undo.
    [Test]
    procedure Unload_WithNoMasterRegisteredLeavesEverythingAlone;
    /// The unload's second guard: the master's dataset is not open, so the
    /// link is left in place rather than silently dropped.
    [Test]
    procedure Unload_WithAClosedMasterLeavesTheLinkInPlace;
  end;

implementation

const
  cFILTERKEY   = '$filter=';
  cODATAEQ     = ' eq ';
  cWHOLETABLE  = 'ten-alpha|ten-beta|twenty-gamma|ten-delta|twenty-epsilon';
  cMASTERTEN   = 'ten-alpha|ten-beta|ten-delta';
  cMASTERTWENTY= 'twenty-gamma|twenty-epsilon';
  cCHILDCOLUMN = 'cparent';
  cMASTERCOLUMN= 'mkey';
  cCHILDTAG    = 'ctag';
  cSIBLINGKEY  = 'other_id';

{ TFilteringRestConnection }

constructor TFilteringRestConnection.Create;
begin
  inherited Create;
  FRows := TList<TSeededChild>.Create;
  FQueryParams := TStringList.Create;
  FLastFilter := '';
  FCallCount := 0;
end;

destructor TFilteringRestConnection.Destroy;
begin
  FQueryParams.Free;
  FRows.Free;
  inherited;
end;

procedure TFilteringRestConnection.Seed(const ACKey, ACParent: Integer;
  const ACTag: String);
var
  LRow: TSeededChild;
begin
  LRow.ckey := ACKey;
  LRow.cparent := ACParent;
  LRow.ctag := ACTag;
  FRows.Add(LRow);
end;

function TFilteringRestConnection.GetLastFilter: String;
begin
  Result := FLastFilter;
end;

function TFilteringRestConnection.GetCallCount: Integer;
begin
  Result := FCallCount;
end;

function TFilteringRestConnection._CurrentFilter: String;
var
  LFor: Integer;
begin
  Result := '';
  for LFor := 0 to FQueryParams.Count -1 do
    if StartsText(cFILTERKEY, FQueryParams[LFor]) then
      Exit(Copy(FQueryParams[LFor], Length(cFILTERKEY) + 1, MaxInt));
end;

function TFilteringRestConnection._RowsAsJson(const AParent: Integer;
  const AAll: Boolean): String;
var
  LRow: TSeededChild;
begin
  Result := '';
  for LRow in FRows do
  begin
    if (not AAll) and (LRow.cparent <> AParent) then
      Continue;
    if Length(Result) > 0 then
      Result := Result + ',';
    Result := Result + '{"ckey":' + IntToStr(LRow.ckey) +
                       ',"cparent":' + IntToStr(LRow.cparent) +
                       ',"ctag":"' + LRow.ctag + '"}';
  end;
  Result := '[' + Result + ']';
end;

function TFilteringRestConnection.DoExecute(const AResource,
  ASubResource: String; const ARequestMethod: TRESTRequestMethodType;
  const AParams: TProc): String;
var
  LParts: TArray<String>;
  LParent: Integer;
begin
  FQueryParams.Clear;
  // The framework pushes the query params from INSIDE this callback, so the
  // filter can only be read after it has run.
  if Assigned(AParams) then
    AParams();
  Inc(FCallCount);
  FLastFilter := _CurrentFilter;

  if FLastFilter = '' then
    Exit(_RowsAsJson(0, True));

  LParts := FLastFilter.Split([cODATAEQ]);
  if (Length(LParts) = 2) and SameText(Trim(LParts[0]), cCHILDCOLUMN) and
     TryStrToInt(Trim(LParts[1]), LParent) then
    Exit(_RowsAsJson(LParent, False));

  // A filter that is not the one this resource understands: answer everything,
  // the loud failure rather than the quiet one.
  Result := _RowsAsJson(0, True);
end;

function TFilteringRestConnection.Execute(const AResource, ASubResource: String;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): String;
begin
  Result := DoExecute(AResource, ASubResource, ARequestMethod, AParams);
end;

function TFilteringRestConnection.Execute(const AResource: String;
  const ARequestMethod: TRESTRequestMethodType; const AParams: TProc): String;
begin
  Result := DoExecute(AResource, '', ARequestMethod, AParams);
end;

procedure TFilteringRestConnection.AddQueryParam(AValue: String);
begin
  FQueryParams.Add(AValue);
end;

procedure TFilteringRestConnection.AddBodyParam(AValue: String);
begin
end;

procedure TFilteringRestConnection.AddParam(AValue: String);
begin
end;

function TFilteringRestConnection.CommandMonitor: ICommandMonitor;
begin
  Result := nil;
end;

procedure TFilteringRestConnection.SetCommandMonitor(AMonitor: ICommandMonitor);
begin
end;

procedure TFilteringRestConnection.SetClassNotServerUse(const Value: Boolean);
begin
end;

function TFilteringRestConnection.GetBaseURL: String;
begin
  Result := 'http://filtered.local';
end;

function TFilteringRestConnection.GetFullURL: String;
begin
  Result := 'http://filtered.local';
end;

function TFilteringRestConnection.GetUsername: String;
begin
  Result := '';
end;

function TFilteringRestConnection.GetPassword: String;
begin
  Result := '';
end;

function TFilteringRestConnection.GetMethodGET: String;
begin
  Result := '';
end;

function TFilteringRestConnection.GetMethodGETId: String;
begin
  Result := '';
end;

function TFilteringRestConnection.GetMethodGETWhere: String;
begin
  Result := '';
end;

function TFilteringRestConnection.GetMethodPOST: String;
begin
  Result := '';
end;

function TFilteringRestConnection.GetMethodPUT: String;
begin
  Result := '';
end;

function TFilteringRestConnection.GetMethodDELETE: String;
begin
  Result := '';
end;

function TFilteringRestConnection.GetMethodGETNextPacket: String;
begin
  Result := '';
end;

function TFilteringRestConnection.GetMethodGETNextPacketWhere: String;
begin
  Result := '';
end;

function TFilteringRestConnection.GetMethodToken: String;
begin
  Result := '';
end;

function TFilteringRestConnection.GetServerUse: Boolean;
begin
  Result := False;
end;

{ TRestLazyCrack<M> }

class procedure TRestLazyCrack<M>.Lazy(
  const AAdapter: TRESTFDMemTableAdapter<M>; const AOwner: M);
begin
  TRestLazyCrack<M>(AAdapter).LoadLazy(AOwner);
end;

class procedure TRestLazyCrack<M>.CloseIt(
  const AAdapter: TRESTFDMemTableAdapter<M>);
begin
  TRestLazyCrack<M>(AAdapter).Close;
end;

class function TRestLazyCrack<M>.RegisteredChilds(
  const AAdapter: TRESTFDMemTableAdapter<M>): String;
var
  LKeys: TStringList;
begin
  LKeys := TStringList.Create;
  try
    LKeys.Sorted := True;
    LKeys.AddStrings(TRestLazyCrack<M>(AAdapter).FMasterObject.Keys.ToArray);
    Result := LKeys.CommaText;
  finally
    LKeys.Free;
  end;
end;

{ TTestRestLazy }

procedure TTestRestLazy.Setup;
begin
  FServer := TFilteringRestConnection.Create;
  FConn := FServer;
  // Interleaved on purpose: seeded order is alpha, beta, gamma, delta,
  // epsilon, so no subset is a prefix of the table.
  FServer.Seed(1, 10, 'ten-alpha');
  FServer.Seed(2, 10, 'ten-beta');
  FServer.Seed(3, 20, 'twenty-gamma');
  FServer.Seed(4, 10, 'ten-delta');
  FServer.Seed(5, 20, 'twenty-epsilon');
  FMasterMem := nil;
  FMemMaster := nil;
  FChildMem := nil;
  FMemChild := nil;
  FSiblingMem := nil;
  FMemSibling := nil;
end;

procedure TTestRestLazy.TearDown;
begin
  FreeAndNil(FMemSibling);
  FreeAndNil(FMemChild);
  FreeAndNil(FMemMaster);
  FreeAndNil(FSiblingMem);
  FreeAndNil(FChildMem);
  FreeAndNil(FMasterMem);
  FConn := nil;
  FServer := nil;
end;

procedure TTestRestLazy.AddMasterRow(const AKey: Integer; const ATag: String);
begin
  FMasterMem.Append;
  FMasterMem.FieldByName(cMASTERCOLUMN).AsInteger := AKey;
  FMasterMem.FieldByName('mtag').AsString := ATag;
  FMasterMem.Post;
end;

procedure TTestRestLazy.BuildPair;
begin
  BuildPairLeavingChildOpen;
  // The adapter's constructor leaves the dataset OPEN, and the 'already
  // loaded' guard reads exactly that. #248 is the reason a genuine Close
  // exists to undo it.
  TRestLazyCrack<TAsymChild>.CloseIt(FMemChild);
end;

procedure TTestRestLazy.BuildPairLeavingChildOpen;
begin
  FMasterMem := TFDMemTable.Create(nil);
  FMemMaster := TRESTFDMemTableAdapter<TAsymMaster>.Create(FConn, FMasterMem,
                  -1, nil);
  AddMasterRow(10, 'master-ten');
  AddMasterRow(20, 'master-twenty');
  FMasterMem.First;

  // AMasterObject is nil: the child owns no master yet, which is the only
  // state in which the load branch does anything at all.
  FChildMem := TFDMemTable.Create(nil);
  FMemChild := TRESTFDMemTableAdapter<TAsymChild>.Create(FConn, FChildMem,
                 -1, nil);
end;

procedure TTestRestLazy.BuildPairWithSibling;
begin
  BuildPair;
  FSiblingMem := TFDMemTable.Create(nil);
  FMemSibling := TRESTFDMemTableAdapter<TAitNoCascade>.Create(FConn,
                   FSiblingMem, -1, FMemMaster);
  // root_id is NotNull on TAitNoCascade, and the adapter's own
  // _ExecuteCheckNotNull refuses the Post without it.
  FSiblingMem.Append;
  FSiblingMem.FieldByName(cSIBLINGKEY).AsInteger := 71;
  FSiblingMem.FieldByName('root_id').AsInteger := 10;
  FSiblingMem.Post;
  FSiblingMem.Append;
  FSiblingMem.FieldByName(cSIBLINGKEY).AsInteger := 72;
  FSiblingMem.FieldByName('root_id').AsInteger := 10;
  FSiblingMem.Post;
  FSiblingMem.First;
end;

procedure TTestRestLazy.MasterGoTo(const AKey: Integer);
begin
  FMasterMem.First;
  while not FMasterMem.Eof do
  begin
    if FMasterMem.FieldByName(cMASTERCOLUMN).AsInteger = AKey then
      Exit;
    FMasterMem.Next;
  end;
  Assert.Fail('the master has no row with ' + cMASTERCOLUMN + ' = ' +
    IntToStr(AKey) + ', so nothing below would be measuring what it says');
end;

function TTestRestLazy.ChildTags: String;
begin
  Result := '';
  if not FChildMem.Active then
    Exit;
  FChildMem.First;
  while not FChildMem.Eof do
  begin
    if Length(Result) > 0 then
      Result := Result + '|';
    Result := Result + FChildMem.FieldByName(cCHILDTAG).AsString;
    FChildMem.Next;
  end;
end;

function TTestRestLazy.SiblingIds: String;
begin
  Result := '';
  if not FSiblingMem.Active then
    Exit;
  FSiblingMem.First;
  while not FSiblingMem.Eof do
  begin
    if Length(Result) > 0 then
      Result := Result + '|';
    Result := Result + FSiblingMem.FieldByName(cSIBLINGKEY).AsString;
    FSiblingMem.Next;
  end;
end;

// ---------------------------------------------------------------------------
// Premises
// ---------------------------------------------------------------------------

procedure TTestRestLazy.Premise_TheAssociationEndsAreSpelledDifferently;
begin
  Assert.AreNotEqual(cMASTERCOLUMN, cCHILDCOLUMN,
    'the master column and the child column must be spelled differently, ' +
    'otherwise a WHERE that names the wrong end produces the same string as ' +
    'a correct one and every load measurement below proves nothing');
end;

procedure TTestRestLazy.Premise_WithoutAFilterTheServerHandsBackTheWholeTable;
var
  LJson: String;
begin
  LJson := FConn.Execute('mdchild', '', TRESTRequestMethodType.rtGET, nil);
  Assert.Contains(LJson, 'twenty-gamma',
    'with no $filter the double must answer the WHOLE seeded table - that is ' +
    'the shape a load with no filter produces, and the thing the load branch ' +
    'has to be shown NOT to do');
  Assert.Contains(LJson, 'ten-alpha',
    'and both masters rows are in it, otherwise the two answers would not ' +
    'be distinguishable');
end;

// ---------------------------------------------------------------------------
// The load branch
// ---------------------------------------------------------------------------

procedure TTestRestLazy.Load_TheFilterNamesTheChildColumnAndTheMasterValue;
begin
  BuildPair;
  MasterGoTo(10);

  TRestLazyCrack<TAsymChild>.Lazy(FMemChild, TAsymChild(FMemMaster));

  Assert.AreEqual('cparent eq 10', FServer.LastFilter,
    'THE THREE THINGS THIS ONE STRING PINS. Left of the operator must be the ' +
    'CHILD column (cparent), not the master one (mkey) - the two ends of the ' +
    'association are not interchangeable. Right of it must be the value of ' +
    'the master row the cursor is on. And the operator must already be the ' +
    'OData `eq`: TSessionRestFul<M>._ParseOperator only rewrites '' = '' with ' +
    'its spaces, so a WHERE built with a bare ''='' arrives untranslated');
end;

procedure TTestRestLazy.Load_OnlyTheRowsOfThisMasterComeBackAndInThatOrder;
begin
  BuildPair;
  MasterGoTo(10);

  TRestLazyCrack<TAsymChild>.Lazy(FMemChild, TAsymChild(FMemMaster));

  Assert.IsTrue(FChildMem.Active,
    'the load must leave the child open, otherwise there is nothing to read');
  Assert.AreEqual(cMASTERTEN, ChildTags,
    'ORDERED CORRESPONDENCE, NOT A SET. Expected the three rows of master 10 ' +
    'in seeded order. `' + cWHOLETABLE + '` would mean no filter reached the ' +
    'server - the exact failure the empty body used to produce through ' +
    'FSession.Find. `' + cMASTERTWENTY + '` would mean the filter carried ' +
    'the wrong master value. An empty answer would mean the filter named a ' +
    'column the resource does not have');
end;

procedure TTestRestLazy.Load_TheChildEndsUpRegisteredUnderTheMaster;
begin
  BuildPair;
  MasterGoTo(10);
  Assert.AreEqual('', TRestLazyCrack<TAsymMaster>.RegisteredChilds(FMemMaster),
    'the master starts with no child registered');

  TRestLazyCrack<TAsymChild>.Lazy(FMemChild, TAsymChild(FMemMaster));

  Assert.AreEqual('TAsymChild',
    TRestLazyCrack<TAsymMaster>.RegisteredChilds(FMemMaster),
    'the load calls SetMasterObject(AOwner), which is what puts the child in ' +
    'the master registry - and it is exactly what the unload branch undoes');
end;

procedure TTestRestLazy.Load_AfterAnUnloadTheNextLoadFollowsTheMasterCursor;
begin
  BuildPair;
  MasterGoTo(10);
  TRestLazyCrack<TAsymChild>.Lazy(FMemChild, TAsymChild(FMemMaster));
  Assert.AreEqual(cMASTERTEN, ChildTags,
    'the first leg must really be master 10, otherwise the second leg proves ' +
    'nothing about following the cursor');

  TRestLazyCrack<TAsymChild>.Lazy(FMemChild, nil);
  MasterGoTo(20);
  TRestLazyCrack<TAsymChild>.Lazy(FMemChild, TAsymChild(FMemMaster));

  Assert.AreEqual('cparent eq 20', FServer.LastFilter,
    'the second load must carry the value of the master row the cursor moved ' +
    'to - a filter built from anything but the current master row would ' +
    'still read `cparent eq 10` here');
  Assert.AreEqual(cMASTERTWENTY, ChildTags,
    'ORDERED CORRESPONDENCE. The child now holds the two rows of master 20, ' +
    'in seeded order. Still holding `' + cMASTERTEN + '` would mean the ' +
    'second load never happened - which is also how a broken unload shows ' +
    'up, because the two guards would have sent it straight back out');
end;

procedure TTestRestLazy.Load_AnAlreadyOpenChildIsNotFetchedAtAll;
var
  LCalls: Integer;
begin
  // NOT BuildPair: that one closes the child, which is what makes every other
  // load test above reach the fetch. Here the child is left exactly as the
  // constructor leaves it - OPEN - and it owns no master, so the guard under
  // test is the only one that can answer.
  BuildPairLeavingChildOpen;
  MasterGoTo(10);
  LCalls := FServer.CallCount;

  TRestLazyCrack<TAsymChild>.Lazy(FMemChild, TAsymChild(FMemMaster));

  Assert.AreEqual(LCalls, FServer.CallCount,
    'THE `already loaded` GUARD, COPIED FROM TDataSetAdapter<M>.LoadLazy. An ' +
    'open child is not fetched, full stop. #248 measured that ' +
    'FOrmDataSet.Active lies for as long as nothing ever closes the dataset; ' +
    'the answer there was to make Close close for real, not to pick a ' +
    'different flag, and this family copies that answer rather than ' +
    'inventing its own');
  Assert.AreEqual('', TRestLazyCrack<TAsymMaster>.RegisteredChilds(FMemMaster),
    'and the guard runs BEFORE SetMasterObject, so the refused load left no ' +
    'registration behind either - which is also what keeps the owner handed ' +
    'in here from being stored and later read as if it were an adapter');
end;

procedure TTestRestLazy.Load_AChildThatAlreadyHasAMasterIsNotLoadedAgain;
var
  LCalls: Integer;
begin
  BuildPair;
  MasterGoTo(10);
  TRestLazyCrack<TAsymChild>.Lazy(FMemChild, TAsymChild(FMemMaster));
  // Close the child WITHOUT unloading it: the dataset gate is now open again
  // but the master link is still in place, so the other guard is the only one
  // left standing.
  TRestLazyCrack<TAsymChild>.CloseIt(FMemChild);
  LCalls := FServer.CallCount;

  TRestLazyCrack<TAsymChild>.Lazy(FMemChild, TAsymChild(FMemMaster));

  Assert.AreEqual(LCalls, FServer.CallCount,
    'a child that already owns a master is left alone - the guard that reads ' +
    'FOwnerMasterObject, mirrored from the local family');
  Assert.IsFalse(FChildMem.Active,
    'and it was not reopened behind the guard');
end;

// ---------------------------------------------------------------------------
// The unload branch
// ---------------------------------------------------------------------------

procedure TTestRestLazy.Unload_ClosesThisChildAndUnregistersOnlyIt;
begin
  BuildPairWithSibling;
  MasterGoTo(10);
  TRestLazyCrack<TAsymChild>.Lazy(FMemChild, TAsymChild(FMemMaster));
  Assert.AreEqual(cMASTERTEN, ChildTags,
    'the child must really be carrying rows before the unload, otherwise ' +
    'closing it would be closing nothing');
  Assert.AreEqual('TAitNoCascade,TAsymChild',
    TRestLazyCrack<TAsymMaster>.RegisteredChilds(FMemMaster),
    'and BOTH children must be registered, otherwise "only it was removed" ' +
    'is not a claim this fixture can make');

  TRestLazyCrack<TAsymChild>.Lazy(FMemChild, nil);

  Assert.IsFalse(FChildMem.Active,
    'THE UNLOAD IS A REAL CLOSE, not an EmptyDataSet that hands back an open ' +
    'empty dataset - TDataSetBaseAdapter<M>.Close always closed for real');
  Assert.AreEqual('TAitNoCascade',
    TRestLazyCrack<TAsymMaster>.RegisteredChilds(FMemMaster),
    'ORDERED, NAMED CORRESPONDENCE ON THE REGISTRY. Exactly TAsymChild left ' +
    'and exactly TAitNoCascade stayed. `TAitNoCascade,TAsymChild` would mean ' +
    'SetMasterObject(nil) never ran and only the dataset was closed; an ' +
    'empty list would mean the unload took the sibling down with it');
  Assert.IsTrue(FSiblingMem.Active,
    'the sibling was not closed');
  Assert.AreEqual('71|72', SiblingIds,
    'and it still holds its own rows, in order');
end;

procedure TTestRestLazy.Unload_WithNoMasterRegisteredLeavesEverythingAlone;
var
  LCalls: Integer;
begin
  BuildPair;
  // FMemMaster owns no master of its own, so this is the first guard.
  LCalls := FServer.CallCount;

  TRestLazyCrack<TAsymMaster>.Lazy(FMemMaster, nil);

  Assert.IsTrue(FMasterMem.Active,
    'the first guard - FOwnerMasterObject is nil - means there is nothing to ' +
    'undo, and in particular nothing to close');
  Assert.AreEqual(2, FMasterMem.RecordCount,
    'and its rows are untouched');
  Assert.AreEqual(LCalls, FServer.CallCount,
    'the unload branch never talks to the server, by either route');
end;

procedure TTestRestLazy.Unload_WithAClosedMasterLeavesTheLinkInPlace;
begin
  BuildPair;
  MasterGoTo(10);
  TRestLazyCrack<TAsymChild>.Lazy(FMemChild, TAsymChild(FMemMaster));
  Assert.AreEqual('TAsymChild',
    TRestLazyCrack<TAsymMaster>.RegisteredChilds(FMemMaster),
    'the link has to exist before it can be shown to survive');

  TRestLazyCrack<TAsymMaster>.CloseIt(FMemMaster);
  TRestLazyCrack<TAsymChild>.Lazy(FMemChild, nil);

  Assert.AreEqual('TAsymChild',
    TRestLazyCrack<TAsymMaster>.RegisteredChilds(FMemMaster),
    'THE SECOND GUARD. With the master''s dataset closed the unload exits ' +
    'before SetMasterObject(nil), so the child stays registered - mirrored ' +
    'from TDataSetAdapter<M>.LoadLazy, which reads the master dataset''s ' +
    'Active for exactly this. Losing the registration here would leave the ' +
    'master unable to find its child again when it reopens');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRestLazy);

end.
