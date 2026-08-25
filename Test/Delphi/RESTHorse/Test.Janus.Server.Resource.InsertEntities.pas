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

{ @abstract(Janus Framework - the insert answer says the key of EVERY row it
  wrote, and says whose each one is. Issue #312. PRODUCER side.)

  WHAT WAS WRONG

  TAppResourceBase.ParseInsert hands the whole aggregate to
  TRESTObjectSet.Insert, which cascades and lets the database generate a key
  for EVERY row. The answer then asked the primary key of exactly ONE class:

      LPrimaryKey := TMappingExplorer.GetMappingPrimaryKeyColumns(LObject.ClassType);

  with LObject bound to the ROOT. So the client's root came back reconciled and
  every level below it kept the AutoInc placeholder. The symptom is not an
  error at save time - it is the NEXT Update or Delete of that child, aiming at
  a key no row has.

  WHAT THIS FIXTURE MEASURES

  The DOCUMENT. It calls TAppResourceBase.insert against a live SQLite database
  - the same route Test.Janus.Server.Resource.KeyQuoting uses - and reads the
  body that comes back. It does not go over HTTP and it does not run a client
  adapter: the CONSUMER half is measured in Janus.Tests.RESTfulDriver by
  Test.Janus.Rest.GraphInsertEntities, which drives the reader with canned
  answers. NOTHING IN THIS REPOSITORY MEASURES THE TWO HALVES IN ONE PROCESS,
  and that is stated here rather than left to be discovered: no fixture under
  Test\Delphi\RESTHorse constructs a client-side object set at all - the
  integration suite there speaks to the server with a bare THTTPClient.

  WHY `params` IS ASSERTED TO BE UNCHANGED, IN ITS OWN CLAUSE

  Because that is the constraint the whole design rests on, and it is a
  constraint about a DIFFERENT reader. TRESTDataSetAdapter<M>.ApplyInserter
  walks ResultParams and writes ANY field the row has and the answer names -
  not only key columns - with the LAST one winning. A child's key put into
  `params` could therefore overwrite the ROOT's own key whenever the two spell
  the same column name. `params` keeps carrying the root's primary key and
  nothing else, and TheParamsArrayStillCarriesOnlyTheRootKey is what holds it
  there.

  WHY TAsymTree AND NOT THE MODEL NEXT DOOR

  Three levels with every key column spelled ONCE - rkey, mkey, lkey - so a
  walk that reported the wrong object's key cannot look right by coincidence.
  It also carries a to-ONE root, TAsymTreeOneRoot, which is the other
  multiplicity - though only its NIL shape is reachable from this side, for the
  reason spelled out in AToOneBranchArrivesNilThroughThisRouteAndIsNotReported.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Server.Resource.InsertEntities;

interface

uses
  Classes,
  SysUtils,
  Variants,
  IOUtils,
  JSON,
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
  Janus.Server.Resource,
  Test.Janus.Model.AsymTree;

type
  [TestFixture]
  TTestServerResourceInsertEntities = class
  private
    FDConnection: TFDConnection;
    FConnection: IDBConnection;
    FDbFile: String;
    FAnswer: TJSONObject;
    function _InsertRaw(const AResource, ABody: String): String;
    /// The parsed answer for the canonical three level body, kept on the
    /// fixture so the TearDown owns it.
    function _AnswerForTheTree: TJSONObject;
    function _Entities(const AAnswer: TJSONObject): TJSONArray;
    /// The entity element whose `path` is APath, or nil.
    function _EntityAt(const AAnswer: TJSONObject;
      const APath: String): TJSONObject;
    function _KeyOf(const AAnswer: TJSONObject;
      const APath, AKeyName: String): Integer;
    function _ScalarInt(const ASQL: String): Integer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// PREMISE. Without this the clauses below could be green over a tree that
    /// never reached the database.
    [Test]
    procedure Premise_TheWholeThreeLevelGraphReachedTheDatabase;

    /// THE CONSTRAINT THE WHOLE DESIGN RESTS ON. `params` is the root's
    /// primary key and NOTHING else, exactly as before this issue.
    [Test]
    procedure TheParamsArrayStillCarriesOnlyTheRootKey;

    /// THE DEFECT. One entry per row written, the root included.
    [Test]
    procedure EveryRowTheInsertWroteHasAnEntry;

    /// The child's own key, which the answer never named before.
    [Test]
    procedure TheChildEntryCarriesTheKeyTheDatabaseGenerated;

    /// The grandchild's own key - the level that had nothing at all.
    [Test]
    procedure TheGrandchildEntryCarriesTheKeyTheDatabaseGenerated;

    /// CORRESPONDENCE. Two siblings in ONE list are told apart by the ordinal
    /// in the path, and they carry DIFFERENT keys. A walk that named only the
    /// class, or that reused one ordinal, cannot pass this.
    [Test]
    procedure TwoSiblingsOfOneListAreToldApartByTheirOrdinal;

    /// And the ordinal is the position in the list the client sent, so the
    /// grandchildren of the SECOND mid are addressed under `mids[1]`.
    [Test]
    procedure TheOrdinalIsThePositionInTheListThatWasSent;

    /// Each entry says which class it measured, so the reader can refuse a
    /// path that resolves to something else.
    [Test]
    procedure EachEntryNamesTheClassItMeasured;

    /// The whole body has to stay ONE well formed document - the `result`
    /// message and `params` both survive next to the new key.
    [Test]
    procedure TheAnswerIsStillOneWellFormedDocument;

    /// PERTINENCE, and a MEASURED limit of this route. A to-one association
    /// arrives NIL through ParseInsert whatever the body says, so no row is
    /// written under it and nothing may be reported for it. The descending arm
    /// for a to-one association is therefore unreachable from this side and is
    /// measured on the consumer side instead - see the body.
    [Test]
    procedure AToOneBranchArrivesNilThroughThisRouteAndIsNotReported;
  end;

implementation

uses
  DataEngine.FactoryFireDAC;

const
  cDBFILE = 'janus_server_resource_insertentities.db';

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
  cDDL_PAIR =
    'CREATE TABLE IF NOT EXISTS atpair (' +
    '  pkey INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  ptag VARCHAR(20)' +
    ')';

  /// TWO mids, and TWO leaves under the FIRST of them. Both numbers are
  /// load-bearing: with one mid nothing distinguishes an ordinal from a class
  /// name, and with one leaf per mid nothing distinguishes the second level's
  /// ordinal from the third's.
  cBODY_TREE =
    '{"rtag":"root","mids":[' +
      '{"mtag":"mid0","leafs":[' +
        '{"ltag":"leaf00"},{"ltag":"leaf01"}]},' +
      '{"mtag":"mid1","leafs":[' +
        '{"ltag":"leaf10"}]}]}';

  /// The to-ONE root with its branch filled.
  cBODY_PAIR =
    '{"ptag":"pair","mid":{"mtag":"pairmid","leafs":[{"ltag":"pairleaf"}]}}';

{ TTestServerResourceInsertEntities }

procedure TTestServerResourceInsertEntities.Setup;
begin
  FAnswer := nil;
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
  /// The entities are registered in the INITIALIZATION of
  /// Test.Janus.Model.AsymTree, not here.
  FConnection.ExecuteDirect(cDDL_ROOT);
  FConnection.ExecuteDirect(cDDL_MID);
  FConnection.ExecuteDirect(cDDL_LEAF);
  FConnection.ExecuteDirect(cDDL_PAIR);
end;

procedure TTestServerResourceInsertEntities.TearDown;
begin
  FreeAndNil(FAnswer);
  FConnection := nil;
  if Assigned(FDConnection) then
  begin
    FDConnection.Connected := False;
    FreeAndNil(FDConnection);
  end;
  if TFile.Exists(FDbFile) then
    TFile.Delete(FDbFile);
end;

function TTestServerResourceInsertEntities._ScalarInt(const ASQL: String): Integer;
var
  LValue: Variant;
begin
  LValue := FDConnection.ExecSQLScalar(ASQL);
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Result := -1
  else
    Result := LValue;
end;

function TTestServerResourceInsertEntities._InsertRaw(const AResource,
  ABody: String): String;
var
  LResource: TAppResourceBase;
begin
  LResource := TAppResourceBase.Create(FConnection);
  try
    Result := LResource.insert(AResource, ABody);
  finally
    LResource.Free;
  end;
end;

function TTestServerResourceInsertEntities._AnswerForTheTree: TJSONObject;
var
  LBody: String;
begin
  if FAnswer <> nil then
    Exit(FAnswer);
  LBody := _InsertRaw('AsymTreeRoot', cBODY_TREE);
  FAnswer := TJSONObject.ParseJSONValue(LBody) as TJSONObject;
  Assert.IsNotNull(FAnswer,
    'the insert answer is not parseable JSON. Body was: ' + LBody);
  Result := FAnswer;
end;

function TTestServerResourceInsertEntities._Entities(
  const AAnswer: TJSONObject): TJSONArray;
begin
  Result := AAnswer.Values['entities'] as TJSONArray;
  Assert.IsNotNull(Result,
    'the answer carries no "entities" array. Body was: ' + AAnswer.ToJSON);
end;

function TTestServerResourceInsertEntities._EntityAt(const AAnswer: TJSONObject;
  const APath: String): TJSONObject;
var
  LArray: TJSONArray;
  LFor: Integer;
  LItem: TJSONObject;
begin
  Result := nil;
  LArray := _Entities(AAnswer);
  for LFor := 0 to LArray.Count -1 do
  begin
    if not (LArray.Items[LFor] is TJSONObject) then
      Continue;
    LItem := TJSONObject(LArray.Items[LFor]);
    if not (LItem.Values['path'] is TJSONString) then
      Continue;
    if LItem.Values['path'].Value = APath then
      Exit(LItem);
  end;
end;

function TTestServerResourceInsertEntities._KeyOf(const AAnswer: TJSONObject;
  const APath, AKeyName: String): Integer;
var
  LEntity: TJSONObject;
  LKeys: TJSONObject;
begin
  Result := -1;
  LEntity := _EntityAt(AAnswer, APath);
  Assert.IsNotNull(LEntity,
    'no entities element carries the path ' + QuotedStr(APath) +
    '. The answer was: ' + AAnswer.ToJSON);
  LKeys := LEntity.Values['keys'] as TJSONObject;
  Assert.IsNotNull(LKeys,
    'the element at ' + QuotedStr(APath) + ' carries no "keys" object');
  if not (LKeys.Values[AKeyName] is TJSONNumber) then
    Assert.Fail('the element at ' + QuotedStr(APath) + ' does not carry ' +
      QuotedStr(AKeyName) + ' as a JSON number. It was: ' + LKeys.ToJSON);
  Result := TJSONNumber(LKeys.Values[AKeyName]).AsInt;
end;

procedure TTestServerResourceInsertEntities
  .Premise_TheWholeThreeLevelGraphReachedTheDatabase;
begin
  _AnswerForTheTree;
  Assert.AreEqual(1, _ScalarInt('SELECT COUNT(*) FROM atroot'),
    'premise: one root row');
  Assert.AreEqual(2, _ScalarInt('SELECT COUNT(*) FROM atmid'),
    'premise: two mid rows - without both, the sibling clause below is ' +
    'measuring nothing');
  Assert.AreEqual(3, _ScalarInt('SELECT COUNT(*) FROM atleaf'),
    'premise: three leaf rows');
end;

procedure TTestServerResourceInsertEntities
  .TheParamsArrayStillCarriesOnlyTheRootKey;
var
  LAnswer: TJSONObject;
  LParams: TJSONArray;
  LFirst: TJSONObject;
begin
  LAnswer := _AnswerForTheTree;
  LParams := LAnswer.Values['params'] as TJSONArray;
  Assert.IsNotNull(LParams, 'the answer must still carry a "params" array');
  Assert.AreEqual(1, LParams.Count,
    'params must still be ONE element. A second one here would be a child ' +
    'key inside params, and TRESTDataSetAdapter<M>.ApplyInserter writes any ' +
    'field the answer names with the LAST one winning - a child called like ' +
    'the root would overwrite the ROOT key, silently');
  LFirst := LParams.Items[0] as TJSONObject;
  Assert.IsNotNull(LFirst, 'the params element must be a JSON object');
  Assert.AreEqual(1, LFirst.Count,
    'the root key is a single column, so params names exactly one pair');
  Assert.AreEqual('rkey', LFirst.Pairs[0].JsonString.Value, False,
    'params names the ROOT key and nothing else - not mkey, not lkey');
end;

procedure TTestServerResourceInsertEntities.EveryRowTheInsertWroteHasAnEntry;
var
  LAnswer: TJSONObject;
begin
  LAnswer := _AnswerForTheTree;
  Assert.AreEqual(6, _Entities(LAnswer).Count,
    'one entry per row written: the root, two mids and three leaves. ' +
    'A count of 1 here is the defect this issue was opened against - the ' +
    'answer naming the root and nothing under it');
  Assert.IsNotNull(_EntityAt(LAnswer, ''),
    'the ROOT has an entry too, at the EMPTY path. Its key is not read from ' +
    'here by this framework - the client reads the root from params - but an ' +
    'entities array that describes the whole graph is what a third party ' +
    'reader can use on its own');
end;

procedure TTestServerResourceInsertEntities
  .TheChildEntryCarriesTheKeyTheDatabaseGenerated;
var
  LAnswer: TJSONObject;
begin
  LAnswer := _AnswerForTheTree;
  Assert.AreEqual(_ScalarInt('SELECT mkey FROM atmid WHERE mtag = ' +
                             QuotedStr('mid0')),
    _KeyOf(LAnswer, 'mids[0]', 'mkey'),
    'the entry for the first mid must carry the key the DATABASE generated ' +
    'for that row. Before this issue no entry existed at all and the client ' +
    'kept the AutoInc placeholder');
end;

procedure TTestServerResourceInsertEntities
  .TheGrandchildEntryCarriesTheKeyTheDatabaseGenerated;
var
  LAnswer: TJSONObject;
begin
  LAnswer := _AnswerForTheTree;
  Assert.AreEqual(_ScalarInt('SELECT lkey FROM atleaf WHERE ltag = ' +
                             QuotedStr('leaf00')),
    _KeyOf(LAnswer, 'mids[0].leafs[0]', 'lkey'),
    'the THIRD level. This is the one the client could not reach by any ' +
    'route: SetAutoIncValueChilds walks one level and the REST ObjectSet ' +
    'client never cascades an insert of its own');
end;

procedure TTestServerResourceInsertEntities
  .TwoSiblingsOfOneListAreToldApartByTheirOrdinal;
var
  LAnswer: TJSONObject;
  LFirst: Integer;
  LSecond: Integer;
begin
  LAnswer := _AnswerForTheTree;
  LFirst := _KeyOf(LAnswer, 'mids[0]', 'mkey');
  LSecond := _KeyOf(LAnswer, 'mids[1]', 'mkey');
  Assert.AreNotEqual(LFirst, LSecond,
    'THE CORRESPONDENCE. Two rows of ONE list have two different generated ' +
    'keys, and the path is what says which is which. Equal numbers here mean ' +
    'the walk reported the same object twice - which is exactly what naming ' +
    'only the CLASS would produce');
  Assert.AreEqual(_ScalarInt('SELECT mkey FROM atmid WHERE mtag = ' +
                             QuotedStr('mid0')), LFirst,
    'and mids[0] must be the row the client sent FIRST, not merely some row');
  Assert.AreEqual(_ScalarInt('SELECT mkey FROM atmid WHERE mtag = ' +
                             QuotedStr('mid1')), LSecond,
    'and mids[1] the one it sent second');
end;

procedure TTestServerResourceInsertEntities
  .TheOrdinalIsThePositionInTheListThatWasSent;
var
  LAnswer: TJSONObject;
begin
  LAnswer := _AnswerForTheTree;
  Assert.AreEqual(_ScalarInt('SELECT lkey FROM atleaf WHERE ltag = ' +
                             QuotedStr('leaf01')),
    _KeyOf(LAnswer, 'mids[0].leafs[1]', 'lkey'),
    'the SECOND leaf of the FIRST mid. A path built from a running counter ' +
    'rather than from the position in each list would put this leaf ' +
    'somewhere else');
  Assert.AreEqual(_ScalarInt('SELECT lkey FROM atleaf WHERE ltag = ' +
                             QuotedStr('leaf10')),
    _KeyOf(LAnswer, 'mids[1].leafs[0]', 'lkey'),
    'and the first leaf of the SECOND mid is addressed under mids[1], which ' +
    'is what makes the ordinal per-list rather than global');
end;

procedure TTestServerResourceInsertEntities.EachEntryNamesTheClassItMeasured;
var
  LAnswer: TJSONObject;
begin
  LAnswer := _AnswerForTheTree;
  Assert.AreEqual('TAsymTreeRoot', _EntityAt(LAnswer, '').Values['class'].Value,
    False, 'the root entry names its class');
  Assert.AreEqual('TAsymTreeMid',
    _EntityAt(LAnswer, 'mids[0]').Values['class'].Value, False,
    'and so does a mid');
  Assert.AreEqual('TAsymTreeLeaf',
    _EntityAt(LAnswer, 'mids[0].leafs[0]').Values['class'].Value, False,
    'and a leaf. The reader refuses to write a key when the path resolves to ' +
    'a different class, which is the check a bare ordinal could never have');
end;

procedure TTestServerResourceInsertEntities
  .TheAnswerIsStillOneWellFormedDocument;
var
  LAnswer: TJSONObject;
begin
  LAnswer := _AnswerForTheTree;
  Assert.IsTrue(LAnswer.Values['result'] is TJSONString,
    'the `result` message must survive next to the new key');
  Assert.IsTrue(Pos('insert command executed successfully',
                    LAnswer.Values['result'].Value) > 0,
    'and must still say what it always said');
  Assert.IsTrue(LAnswer.Values['params'] is TJSONArray,
    'and `params` must still be an array - a client that reads only params ' +
    'must not be able to tell this answer from the one before this issue');
end;

procedure TTestServerResourceInsertEntities
  .AToOneBranchArrivesNilThroughThisRouteAndIsNotReported;
var
  LBody: String;
  LAnswer: TJSONObject;
begin
  // MEASURED, and it is a fact about the FRAMEWORK rather than about this
  // walk. ParseInsert builds the root with `LClassType.Create` plus a
  // published `Create` call and then hands the body to TJanusJson.JsonToObject.
  // For a to-MANY association that fills the list: the canonical tree above
  // comes back with six entries, one per row, so the body really is being
  // deserialised. For a to-ONE association whose property starts NIL - which
  // TAsymTreeOneRoot.mid does, deliberately, and no constructor fills it - the
  // branch is NOT instantiated. Measured through this very route with a body
  // that spells the branch out in full:
  //
  //     SELECT COUNT(*) FROM atmid  ->  0
  //
  // So the row is never written, there is no generated key to report, and the
  // walk must not report one. That is what this clause pins.
  //
  // AND IT MEANS THE DESCENDING ARM FOR A TO-ONE ASSOCIATION CANNOT BE REACHED
  // FROM THIS SIDE AT ALL. No body can put an object in that property, so no
  // call to TAppResourceBase.insert can make the walk descend a to-one branch.
  // It is measured on the CONSUMER side instead - see
  // Test.Janus.Rest.GraphInsertEntities, which builds the graph in memory and
  // therefore can fill it. Saying this out loud is the point: without it, the
  // to-one arm would look defended by a fixture that never runs it.
  LBody := _InsertRaw('AsymTreeOneRoot', cBODY_PAIR);
  FAnswer := TJSONObject.ParseJSONValue(LBody) as TJSONObject;
  Assert.IsNotNull(FAnswer, 'the answer is not parseable JSON: ' + LBody);
  LAnswer := FAnswer;
  Assert.AreEqual(0, _ScalarInt('SELECT COUNT(*) FROM atmid'),
    'the premise of this clause: the to-one branch did NOT reach the ' +
    'database. A 1 here means TJanusJson.JsonToObject has learned to ' +
    'instantiate a nil class-typed property, and this clause has to be ' +
    'rewritten into the descending one it stands in for');
  Assert.AreEqual(1, _Entities(LAnswer).Count,
    'only the root was written, so only the root has an entry');
  Assert.IsNull(_EntityAt(LAnswer, 'mid'),
    'and the branch that was never filled must not be reported at all. ' +
    'TValue reports tkClass for a NIL instance too, so a walk that trusted ' +
    'IsObject alone would have dereferenced nothing here');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestServerResourceInsertEntities);

end.
