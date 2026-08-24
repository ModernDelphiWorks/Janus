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

{ @abstract(Janus Framework - what a REST body says about an association whose
  property arrives NIL, and what the database ends up holding. Issue #366.)

  THIS FIXTURE PINS WHAT HAPPENS TODAY. IT DOES NOT ASSERT WHAT SHOULD.

  Issue #366 lists three directions and decides none of them: instantiate the
  class-typed property while applying the JSON, refuse the request naming the
  branch that could not be written, or report in the answer what was not
  written. Each one changes what a caller of this server observes, so the
  choice is the owner's. What this fixture does is make the CURRENT behaviour
  impossible to change by accident: every clause below carries the value
  measured today and says, in its own message, what a different value means.

  It is the same idiom Test.Janus.Server.Resource.InsertEntities already uses
  in AToOneBranchArrivesNilThroughThisRouteAndIsNotReported, and that clause is
  the neighbour to rewrite alongside these ones IF the to-one direction is ever
  taken. It was NOT taken here - see the box on the to-one silence below.

  WHAT IS UNDER MEASUREMENT

  TAppResourceBase.ParseInsert and TAppResourceBase.ParseUpdate both build the
  target with `LClassType.Create` plus a published `Create` call and then hand
  the request body to TJanusJson.JsonToObject. Whatever the body says, an
  association property that is still nil after the model's own constructor ran
  has nowhere for the deserialiser to write: the tkClass arm of
  TJsonBuilder._SetInstanceProp reads the property, finds nil, and does nothing
  at all - anchored by METHOD, and it lives in JsonFlow, a DIFFERENT
  REPOSITORY from this one.

  THE TWO LEGS STILL DO NOT BEHAVE THE SAME, AND ONE OF THEM WAS REPAIRED

  - to-ONE nil: the root row is written, the branch is not, and the answer is
    the ordinary success sentence. Silent - and STILL silent, by the decision
    written down in the next box, not by omission.
  - to-MANY nil: it USED to be an access violation, rolled back, so not even
    the root row survived. Both SetAutoIncValueOneToMany, which runs first
    from inside Insert, and OneToManyCascadeActionsExecute after it took the
    nil list out of the TValue - IsObject is true for a nil instance - and
    read `LObjectList.Count` off it. Their OneToOne neighbours were already
    safe: OneToOneCascadeActionsExecute grew an explicit `if LObject = nil
    then Exit` in issue #240, and SetAutoIncValueOneToOne leaves through the
    `Assigned(Self)` inside TObjectHelper.GetType. Both OneToMany ones now
    carry the same explicit exit, so the leg no longer raises: the root row
    is kept and the branch is dropped, which is what the to-one leg already
    did.

  WHY THE TO-ONE SILENCE WAS LEFT STANDING - DECIDED, NOT FORGOTTEN

  The repair was ruled NARROW: the access violation goes, nothing else moves.
  The other directions issue #366 listed were measured and rejected.
  Instantiating the nil class-typed property is what
  AConstructorBuiltBranchIsWrittenEvenWhenTheBodyOmitsIt measures the price
  of - every model that builds its branch in its constructor would start
  writing a phantom row for a member nobody sent. Making the server refuse
  runs against what this house decided elsewhere, that no row is an answer
  and not an error. And a new signal, property, event or reporting channel
  was vetoed outright. So the loss of a nil to-one branch is STILL silent,
  and the clauses below keep pinning it exactly as they did. What changed is
  only that the to-many leg stopped answering with an access violation,
  because an access violation is never an answer.

  WHAT THE MUTATIONS PROVE, AND WHAT THEY CANNOT

  Removing EITHER guard alone brings the raise back - the other site still
  reads the nil list - so each guard is load-bearing and the to-many clause
  below dies for either mutation. What no clause here can do is tell the two
  SITES apart: they fail with the same access violation, on the same nil
  pointer, through the same inherited `Count` getter, and whichever runs
  first simply wins. Their ORDER is the only difference between them and it
  is not observable from a request, so no clause was invented to pretend
  otherwise.

  TObjectSetBaseAdapter<M> CARRIES THE SAME UNGUARDED PAIR - the same two
  method names, the same unguarded `LObjectList.Count` - and was deliberately
  left untouched: this front was ruled narrow to the REST server route the
  issue names, and no clause here reaches that adapter. The sites were found
  by searching Source/ for the literal cast line that produces the list,
  `LObjectList := TObjectList<TObject>(LValue.AsObject);`. That search is
  blind to any site that reaches a nil list under a different variable name
  or a different spelling of the cast, so it bounds what was looked at, not
  what exists.

  THE CONTROL CLAUSES ARE NOT DECORATION

  Premise_AToOneBranchIsWrittenWhenTheConstructorBuildsIt and its to-many twin
  run the SAME body against the SAME child table through the SAME route, on a
  model whose constructor builds the branch. Without them every clause here
  could be green over a route that writes nothing at all, and the conclusion
  `the nil property is what loses the row` would be unsupported: the loss could
  have been the multiplicity, the table, or the document.

  AND THE SAFE CONVENTION HAS A PRICE OF ITS OWN

  AConstructorBuiltBranchIsWrittenEvenWhenTheBodyOmitsIt measures it: a model
  that builds its branch up front writes a row for that branch whether or not
  the caller asked for one. That is the measurement that bears on direction
  (a): making the deserialiser instantiate every nil class-typed property
  would give every model this behaviour, phantom row included.

  WHY THE MODELS LIVE HERE AND NOT IN Test.Janus.Model.AsymTree

  That unit is compiled by more than one test project, and a registered entity
  reaching a project that has no use for it is a change nobody asked for - the
  same reasoning Test.Janus.OneToOne.NilAssociation wrote down for
  TAsymTreeManyRoot. They hang off the SAME atmid rows through the same
  `mparent` foreign key, so the level under measurement is byte for byte the
  entity the neighbouring fixtures use.

  ANCHORS ARE BY METHOD, NEVER BY `file:line`.
}

unit Test.Janus.Server.Resource.NilBranchBody;

interface

uses
  Classes,
  DB,
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
  MetaDbDiff.mapping.attributes,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Register,
  Janus.Server.Resource,
  Test.Janus.Model.AsymTree;

type
  /// <summary> THE CONTROL for the to-ONE case. Identical to TAsymTreeOneRoot
  ///  in every respect the cascade can see - same multiplicity, same child
  ///  table, same foreign key - and different in exactly one: its constructor
  ///  builds the branch. It is the shape every Janus.Model.Master under
  ///  Examples/ uses. </summary>
  [Entity]
  [Table('atpre', '')]
  [PrimaryKey('ykey', TAutoIncType.AutoInc,
                      TGeneratorType.SequenceInc,
                      TSortingOrder.NoSort,
                      True, 'Primary key')]
  [Sequence('atpre')]
  TNilBranchPreRoot = class
  private
    Fykey: Integer;
    Fytag: String;
    Fmid: TAsymTreeMid;
  public
    constructor Create;
    destructor Destroy; override;

    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('ykey', ftInteger)]
    property ykey: Integer read Fykey write Fykey;

    [Column('ytag', ftString, 20)]
    property ytag: String read Fytag write Fytag;

    [Association(TMultiplicity.OneToOne, 'ykey', 'atmid', 'mparent')]
    [CascadeActions([TCascadeAction.CascadeAutoInc,
                     TCascadeAction.CascadeInsert,
                     TCascadeAction.CascadeUpdate,
                     TCascadeAction.CascadeDelete])]
    property mid: TAsymTreeMid read Fmid write Fmid;
  end;

  /// <summary> The to-MANY shape with the list left NIL. TAsymTreeRoot builds
  ///  its list in a constructor, so it can only ever measure the SAFE side of
  ///  the to-many case; this one is the other side. Nothing else differs -
  ///  same multiplicity, same child table, same foreign key. </summary>
  [Entity]
  [Table('atnil', '')]
  [PrimaryKey('nkey', TAutoIncType.AutoInc,
                      TGeneratorType.SequenceInc,
                      TSortingOrder.NoSort,
                      True, 'Primary key')]
  [Sequence('atnil')]
  TNilBranchListRoot = class
  private
    Fnkey: Integer;
    Fntag: String;
    Fmids: TObjectList<TAsymTreeMid>;
  public
    destructor Destroy; override;

    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('nkey', ftInteger)]
    property nkey: Integer read Fnkey write Fnkey;

    [Column('ntag', ftString, 20)]
    property ntag: String read Fntag write Fntag;

    /// No constructor fills this in - the whole point of the entity.
    [Association(TMultiplicity.OneToMany, 'nkey', 'atmid', 'mparent')]
    [CascadeActions([TCascadeAction.CascadeAutoInc,
                     TCascadeAction.CascadeInsert,
                     TCascadeAction.CascadeUpdate,
                     TCascadeAction.CascadeDelete])]
    property mids: TObjectList<TAsymTreeMid> read Fmids write Fmids;
  end;

  [TestFixture]
  TTestServerResourceNilBranchBody = class
  private
    FDConnection: TFDConnection;
    FConnection: IDBConnection;
    FDbFile: String;
    function _InsertRaw(const AResource, ABody: String): String;
    function _UpdateRaw(const AResource, ABody: String): String;
    function _ScalarInt(const ASQL: String): Integer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// CONTROL - to-ONE, branch built by the model's own constructor. This is
    /// the shape the Examples/ models use and it must keep working byte for
    /// byte whatever is decided.
    [Test]
    procedure Premise_AToOneBranchIsWrittenWhenTheConstructorBuildsIt;

    /// CONTROL - to-MANY, list built by the model's own constructor.
    [Test]
    procedure Premise_AToManyBranchIsWrittenWhenTheConstructorBuildsIt;

    /// THE DEFECT, to-ONE. The body spells the branch out in full and no row
    /// is written for it.
    [Test]
    procedure AToOneBranchThatArrivesNilIsLostAndTheRootIsKept;

    /// And the answer says success while it happens - the SILENCE half.
    [Test]
    procedure TheAnswerForALostToOneBranchIsIndistinguishableFromSuccess;

    /// THE TO-MANY LEG, which the issue left NOT MEASURED. It used to answer
    /// with an access violation; now it answers the way the to-one leg does.
    [Test]
    procedure AToManyBranchThatArrivesNilIsLostAndTheRootIsKept;

    /// THE UPDATE LEG, which the issue also left NOT MEASURED.
    [Test]
    procedure AToOneBranchThatArrivesNilOnUpdateIsLostAndTheRootIsUpdated;

    /// THE PRICE OF THE SAFE CONVENTION, and the measurement that bears on
    /// direction (a) of the issue.
    [Test]
    procedure AConstructorBuiltBranchIsWrittenEvenWhenTheBodyOmitsIt;
  end;

implementation

uses
  DataEngine.FactoryFireDAC;

const
  cDBFILE = 'janus_server_resource_nilbranchbody.db';

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
  cDDL_ROOT =
    'CREATE TABLE IF NOT EXISTS atroot (' +
    '  rkey INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  rtag VARCHAR(20)' +
    ')';
  cDDL_PRE =
    'CREATE TABLE IF NOT EXISTS atpre (' +
    '  ykey INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  ytag VARCHAR(20)' +
    ')';
  cDDL_NIL =
    'CREATE TABLE IF NOT EXISTS atnil (' +
    '  nkey INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  ntag VARCHAR(20)' +
    ')';

  /// One body shape, spelled the same way for every root, so nothing in the
  /// comparison below is about the document.
  cBODY_PRE  = '{"ytag":"pre","mid":{"mtag":"branch"}}';
  cBODY_PAIR = '{"ptag":"pair","mid":{"mtag":"branch"}}';
  cBODY_ROOT = '{"rtag":"root","mids":[{"mtag":"branch"}]}';
  cBODY_NIL  = '{"ntag":"nil","mids":[{"mtag":"branch"}]}';
  /// The same to-one root, with the branch NOT mentioned at all.
  cBODY_PRE_BARE = '{"ytag":"pre"}';

{ TNilBranchPreRoot }

constructor TNilBranchPreRoot.Create;
begin
  Fmid := TAsymTreeMid.Create;
end;

destructor TNilBranchPreRoot.Destroy;
begin
  Fmid.Free;
  inherited;
end;

{ TNilBranchListRoot }

destructor TNilBranchListRoot.Destroy;
begin
  Fmids.Free;
  inherited;
end;

{ TTestServerResourceNilBranchBody }

procedure TTestServerResourceNilBranchBody.Setup;
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
  FConnection.ExecuteDirect(cDDL_MID);
  FConnection.ExecuteDirect(cDDL_LEAF);
  FConnection.ExecuteDirect(cDDL_PAIR);
  FConnection.ExecuteDirect(cDDL_ROOT);
  FConnection.ExecuteDirect(cDDL_PRE);
  FConnection.ExecuteDirect(cDDL_NIL);
end;

procedure TTestServerResourceNilBranchBody.TearDown;
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

function TTestServerResourceNilBranchBody._ScalarInt(const ASQL: String): Integer;
var
  LValue: Variant;
begin
  LValue := FDConnection.ExecSQLScalar(ASQL);
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Result := -1
  else
    Result := LValue;
end;

function TTestServerResourceNilBranchBody._InsertRaw(const AResource,
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

function TTestServerResourceNilBranchBody._UpdateRaw(const AResource,
  ABody: String): String;
var
  LResource: TAppResourceBase;
begin
  LResource := TAppResourceBase.Create(FConnection);
  try
    Result := LResource.update(AResource, ABody);
  finally
    LResource.Free;
  end;
end;

procedure TTestServerResourceNilBranchBody
  .Premise_AToOneBranchIsWrittenWhenTheConstructorBuildsIt;
begin
  _InsertRaw('NilBranchPreRoot', cBODY_PRE);
  Assert.AreEqual(1, _ScalarInt('SELECT COUNT(*) FROM atpre'),
    'premise: the root row itself');
  Assert.AreEqual(1, _ScalarInt('SELECT COUNT(*) FROM atmid'),
    'THE CONTROL. The very same to-one branch, on a model whose constructor ' +
    'builds it, IS written. A zero here would mean the route cannot write a ' +
    'to-one branch at all, and every clause below would be measuring the ' +
    'wrong thing');
  Assert.AreEqual('branch',
    VarToStr(FDConnection.ExecSQLScalar('SELECT mtag FROM atmid')), False,
    'and it carries what the BODY said, not what the constructor left there ' +
    '- which is what proves the deserialiser reached INTO the branch');
end;

procedure TTestServerResourceNilBranchBody
  .Premise_AToManyBranchIsWrittenWhenTheConstructorBuildsIt;
begin
  _InsertRaw('AsymTreeRoot', cBODY_ROOT);
  Assert.AreEqual(1, _ScalarInt('SELECT COUNT(*) FROM atroot'),
    'premise: the root row itself');
  Assert.AreEqual(1, _ScalarInt('SELECT COUNT(*) FROM atmid'),
    'THE CONTROL for the to-many side. TAsymTreeRoot builds its list in its ' +
    'constructor and the child arrives');
end;

procedure TTestServerResourceNilBranchBody
  .AToOneBranchThatArrivesNilIsLostAndTheRootIsKept;
begin
  _InsertRaw('AsymTreeOneRoot', cBODY_PAIR);
  Assert.AreEqual(1, _ScalarInt('SELECT COUNT(*) FROM atpair'),
    'the ROOT row is written. Half the aggregate the caller sent is in the ' +
    'database, which is what makes the other half a loss rather than a ' +
    'refusal');
  Assert.AreEqual(0, _ScalarInt('SELECT COUNT(*) FROM atmid'),
    'THE LOSS, PINNED AS IT STANDS TODAY. The body spells the branch out in ' +
    'full, the property starts nil, the tkClass arm of _SetInstanceProp has ' +
    'nowhere to write it, and the cascade finds nothing. A 1 here means the ' +
    'decision of issue #366 has been taken - rewrite this clause into the ' +
    'assertion the chosen direction deserves, and rewrite ' +
    'AToOneBranchArrivesNilThroughThisRouteAndIsNotReported in ' +
    'Test.Janus.Server.Resource.InsertEntities with it');
end;

procedure TTestServerResourceNilBranchBody
  .TheAnswerForALostToOneBranchIsIndistinguishableFromSuccess;
var
  LBody: String;
  LAnswer: TJSONObject;
begin
  LBody := _InsertRaw('AsymTreeOneRoot', cBODY_PAIR);
  LAnswer := TJSONObject.ParseJSONValue(LBody) as TJSONObject;
  try
    Assert.IsNotNull(LAnswer, 'the answer is not parseable JSON: ' + LBody);
    Assert.IsTrue(LAnswer.Values['result'] is TJSONString,
      'THE SILENCE. Whatever is decided about the loss itself, this clause ' +
      'records what the caller is told today: a plain success message, with ' +
      'no exception and nothing naming the branch that was dropped');
    Assert.IsTrue(Pos('insert command executed successfully',
                      LAnswer.Values['result'].Value) > 0,
      'and it is the ordinary success sentence, byte for byte the one a ' +
      'complete insert produces');
    Assert.AreEqual(1, (LAnswer.Values['entities'] as TJSONArray).Count,
      'and `entities` - the answer issue #312 added, which names every row ' +
      'the insert wrote - carries the root ALONE. Direction (c) of issue ' +
      '#366 would be a second array next to this one, naming what was NOT ' +
      'written');
  finally
    LAnswer.Free;
  end;
end;

procedure TTestServerResourceNilBranchBody
  .AToManyBranchThatArrivesNilIsLostAndTheRootIsKept;
var
  LAnswer: String;
begin
  LAnswer := '';
  Assert.WillNotRaiseAny(
    procedure
    begin
      LAnswer := _InsertRaw('NilBranchListRoot', cBODY_NIL);
    end,
    'THE ACCESS VIOLATION IS GONE, and that is the whole of what issue #366 ' +
    'changed in Source. SetAutoIncValueOneToMany, which runs FIRST from ' +
    'inside Insert, and OneToManyCascadeActionsExecute after it both take ' +
    'the nil list out of the TValue - IsObject is true for a nil instance - ' +
    'and both now leave before reading LObjectList.Count, the same explicit ' +
    'exit OneToOneCascadeActionsExecute received in issue #240. A raise here ' +
    'means a guard was removed: EITHER one alone brings this clause down, ' +
    'because the other site still reads the nil list, which is what makes ' +
    'both of them load-bearing');
  Assert.AreEqual(1, _ScalarInt('SELECT COUNT(*) FROM atnil'),
    'and NO rollback: the ROOT row survives. It used to be swept away with ' +
    'the raise, so this is the half of the behaviour the guards moved. A 0 ' +
    'here means the insert died somewhere before the root was committed');
  Assert.AreEqual(0, _ScalarInt('SELECT COUNT(*) FROM atmid'),
    'THE SILENCE IS INHERITED, NOT INTRODUCED. The list property is still ' +
    'nil after the model constructor ran, so the deserialiser had nowhere ' +
    'to put the member the body spells out, and the cascade now walks past ' +
    'it instead of dereferencing it. The to-many leg therefore lands exactly ' +
    'where AToOneBranchThatArrivesNilIsLostAndTheRootIsKept already stands. ' +
    'A 1 here means the deserialiser started building nil branches, which ' +
    'is direction (a) of issue #366 and was REJECTED - see the phantom row ' +
    'AConstructorBuiltBranchIsWrittenEvenWhenTheBodyOmitsIt measures');
  Assert.IsTrue(Pos('insert command executed successfully', LAnswer) > 0,
    'and the caller is told the ordinary success sentence, with nothing ' +
    'naming the branch that was dropped. That silence is the DECISION of ' +
    'issue #366, recorded here so it cannot later be read as an oversight: ' +
    'a new signal, property, event or reporting channel was vetoed, so this ' +
    'clause - not a runtime warning - is where the loss stays declared. ' +
    'Answer as received: ' + LAnswer);
end;

procedure TTestServerResourceNilBranchBody
  .AToOneBranchThatArrivesNilOnUpdateIsLostAndTheRootIsUpdated;
begin
  FConnection.ExecuteDirect(
    'INSERT INTO atpair (pkey, ptag) VALUES (1, ' + QuotedStr('before') + ')');
  _UpdateRaw('AsymTreeOneRoot',
    '{"pkey":1,"ptag":"after","mid":{"mtag":"branch"}}');
  Assert.AreEqual('after',
    VarToStr(FDConnection.ExecSQLScalar('SELECT ptag FROM atpair WHERE pkey=1')),
    False,
    'premise: the update itself reached the root row. Without this the ' +
    'clause below could be green over an update that did nothing at all');
  Assert.AreEqual(0, _ScalarInt('SELECT COUNT(*) FROM atmid'),
    'THE UPDATE LEG CARRIES THE SAME LOSS - the case the issue marked NOT ' +
    'MEASURED. ParseUpdate builds its target exactly the way ParseInsert ' +
    'does and hands the body to the same deserialiser, so the branch has ' +
    'nowhere to be written and the cascade finds nothing to write. A 1 here ' +
    'means the decision of issue #366 has been taken');
end;

procedure TTestServerResourceNilBranchBody
  .AConstructorBuiltBranchIsWrittenEvenWhenTheBodyOmitsIt;
begin
  _InsertRaw('NilBranchPreRoot', cBODY_PRE_BARE);
  Assert.AreEqual(1, _ScalarInt('SELECT COUNT(*) FROM atpre'),
    'premise: the root row entered');
  Assert.AreEqual(1, _ScalarInt('SELECT COUNT(*) FROM atmid'),
    'THE PRICE OF THE SAFE CONVENTION. The body says nothing about the ' +
    'branch, and a row is written for it anyway - empty, because the ' +
    'constructor built an empty child and the cascade inserts whatever it ' +
    'finds. This is what direction (a) of issue #366 would generalise to ' +
    'EVERY model: instantiate the nil property and every optional to-one ' +
    'association starts writing a phantom row for a member nobody sent');
  Assert.IsTrue(
    VarToStr(FDConnection.ExecSQLScalar('SELECT mtag FROM atmid')) = '',
    'and the phantom row carries nothing, which is why it is a phantom and ' +
    'not a record');
end;

initialization
  TRegisterClass.RegisterEntity(TNilBranchPreRoot);
  TRegisterClass.RegisterEntity(TNilBranchListRoot);
  TDUnitX.RegisterTestFixture(TTestServerResourceNilBranchBody);

end.
