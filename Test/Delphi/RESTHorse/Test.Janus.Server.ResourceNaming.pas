{
  ------------------------------------------------------------------------------
  Janus
  Modern Object-Relational Mapping (ORM) framework for Delphi.

  SPDX-License-Identifier: MIT
  Copyright (c) 2016-2026 Isaque Pinheiro
  ------------------------------------------------------------------------------
}

(* @abstract(Janus Framework - the server must find an entity the same way this
   framework own client names it, issue #364.)

  WHAT IS UNDER TEST

  How a URL path segment becomes a TClass on the server. One symbol decides it:
  TRESTQueryParse.GetResourceName, whose answer is handed straight to
  TMappingRepository.FindEntityByName - four call sites in
  Janus.Server.Resource.pas (ParseDelete, ParseFind, ParseInsert, ParseUpdate),
  and the DMVC, DataSnap, MARS and WiRL resources read the same getter - and
  matched with SameText against ClassName.

  WHAT WAS WRONG, AND IT IS NOT WHAT THE ISSUE SAYS

  GetResourceName answered 'T' + the segment. The issue reads that as "a model
  whose class is not 'T' + table is UNREACHABLE". MEASURED, that is FALSE:
  such a model is perfectly reachable - by its CLASS NAME MINUS THE T. Every
  other clause this suite already had proves it, because TCustomerTest maps
  table customer_test and every one of them addresses it as CustomerTest.

  What is really wrong is a PROTOCOL DISAGREEMENT between the two halves of
  this framework:

    server  segment -> 'T' + segment -> ClassName         (this file subject)
    client  TSessionRestFul<M>.Create sets FResource := Table(LTable).Name -
            THE TABLE NAME - in its `if FConnection.ServerUse` branch, AND in
            the other branch too whenever the model carries no [Resource]

  The two agree on ONE CONDITION: ClassName = 'T' + table. That condition is a
  convention, not a constraint - nothing declares it, nothing validates it, and
  the registry does not keep it. This file does NOT state how many classes in
  the tree are outside it: a count measured by hand is exactly the kind of
  claim that rots between commits, and one already did, in the first draft of
  this very file. Premise_EveryModelThisSuiteShips_IsOffTheConvention asks the
  LIVE registry instead, of the eight models the suite ships, and answers with
  their own [Table] mappings.

  So a Janus client with JanusServerUse set to True, pointed at a Janus server,
  could not read this framework's own test models. The refusal it got was
  `Resource [Tcustomer_test] not registered on the server!` - naming a symbol
  that appears in no source file, which is why the report reads as "I forgot to
  register it" when the registration is fine.

  THE REPAIR THESE CLAUSES CERTIFY

  The segment is RESOLVED against the registry instead of being decorated:
  ClassName first, so no URL that worked yesterday changes meaning, then the
  [Table] name - the information the client actually sends, already carried by
  the model and not guessed from its spelling. When nothing matches at all,
  'T' + segment is still the answer, so the "not registered" refusal and the
  never-empty contract Test.Janus.Server.Resource.MARS pins both survive.

  AND WHEN TWO ENTITIES CLAIM ONE SEGMENT BY [Table], IT REFUSES

  Two classes mapping one table is a LEGITIMATE shape - a full entity and a
  projection over it. Choosing between them would be choosing in the order
  TRepository._GetEntity hands the classes over, which is `FEntitys.Keys` of a
  TObjectDictionary<TClass, ..>: hash-bucket order over VMT POINTERS, in an
  image linked /DYNAMICBASE. That is not a stable order, it is an accident of
  the loader. So the server refuses and names both candidates, and
  WhenTwoEntitiesClaimTheSegmentByTable_TheServerRefusesToChoose is what dies
  if anyone puts the silent choice back.

  WHAT THIS REPAIR DOES **NOT** FIX, AND IT IS NOT AN OVERSIGHT

  1. [Resource('name')] (MetaDbDiff.Mapping.Attributes.pas:60) is an EXPLICIT
     resource name, and the server ignores it completely: the one and only
     reader of TObjectHelper.GetResource in all of Source is
     Janus.Session.RESTful.pas:149, inside the ServerUse=False branch. A model
     that carries [Resource('tapilookup')] over table `lookup` is STILL refused
     at /tapilookup after this repair, because nothing on the server side ever
     reads that attribute. Teaching the resolver to read it is a change to the
     wire protocol, not a repair of it, and it is reported rather than smuggled
     in here.

  2. The disagreement was never exclusive to ServerUse. The ServerUse=False
     branch of TSessionRestFul<M>.Create ALSO sends Table(LTable).Name whenever
     [Resource] is absent (Janus.Session.RESTful.pas:153-158). ServerUse is
     where it BITES, because that branch cannot fall back to a [Resource] name
     at all, but a model with neither [Resource] nor the convention was
     unreachable from both branches.

  HOW MANY REAL COLLISIONS THE REPAIR HAD TO SURVIVE: ONE, AND IT IS NOT THE
  TWELVE

  The twelve files named Janus.Model.Client.pas across Examples are twelve
  copies of ONE class over ONE table. Copies of one ANSWER are not an
  ambiguity, which is exactly why the resolver compares the answers and not
  the matches: two entities with the same ClassName resolve to the same
  string, so there is nothing to choose between.

  Measured over the whole tree - every [Table] attribute paired with the class
  that follows it - exactly ONE table name is claimed by two DIFFERENT class
  names: `client`, by Tclient (the twelve example copies) and by TClientModel
  in Projects\Janus DLL Framework. Even that one cannot bite at runtime,
  because no program in this repository links both. The genuinely dangerous
  pairs in a live process are the two THIS FILE declares on purpose, and that
  is the point of declaring them: the shape exists, it is legitimate, and
  before this repair nothing in the suite could see it.

  THE CONTROLS ARE NOT DECORATIVE

  TheClassNameSpelling_StillReaches is what dies if the repair REPLACES the
  convention instead of extending it - and every other clause of this suite
  goes with it, because they all address CustomerTest.
  AnUnknownResource_IsStillRefused is what dies if the resolver ever answers a
  class for a segment nobody mapped.
  WhenBothRulesClaimTheSegment_TheClassNameWins is what dies if the two
  readings ever swap places, and it exists because a mutation proved the
  rest of the suite could not tell: with the ClassName pass deleted
  outright, RESTHorse was GREEN. It needed a segment that BOTH rules claim,
  so this file declares the models it invents - and the segment it uses is
  ALSO claimed twice by [Table], so the same clause proves the refusal never
  swallows a segment the class name already resolves.
  AJanusClientWithServerUse_ReadsThisSuitesOwnModel is the only clause in the
  file that drives BOTH halves of the protocol - the real TRESTClientHorse
  naming the resource, and the real server resolving it.

  ANCHORS ARE BY SYMBOL, NEVER BY file:line, except where a line is quoted
  above as evidence about a file this suite does not compile. *)

unit Test.Janus.Server.ResourceNaming;

interface

uses
  SysUtils,
  Classes,
  Generics.Collections,
  DUnitX.TestFramework,
  Net.HTTPClient,
  Net.URLClient,
  DB,
  MetaDbDiff.Mapping.Explorer,
  MetaDbDiff.Mapping.Classes,
  MetaDbDiff.Mapping.Attributes,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Register,
  Janus.Client.Horse,
  Janus.RestObjectSet.Adapter,
  RestHorseTest.Base;

type
  /// THE COLLISION PAIR, AND IT IS THE ONLY THING IN THIS FILE THAT IS NOT
  /// A REAL MODEL. One segment - `jns364` - that BOTH rules can claim: it is
  /// this class's name minus the 'T', and it is the OTHER class's table.
  /// Without such a pair the precedence in _ResolveResourceName is
  /// unfalsifiable: MEASURED, deleting the whole ClassName pass left the
  /// suite GREEN, because for every other model in it the ClassName answer
  /// and the fallback 'T' + segment are the same string. The two rows are
  /// spelled apart so the clause cannot pass by reading the wrong table and
  /// finding something plausible.
  [Entity]
  [Table('jns364_alias', '')]
  [PrimaryKey('ckey', TAutoIncType.NotInc, TGeneratorType.NoneInc,
              TSortingOrder.NoSort, True, 'Primary key')]
  Tjns364 = class
  private
    Fckey: Integer;
    Fctag: String;
  public
    [Restrictions([TRestriction.NotNull])]
    [Column('ckey', ftInteger)]
    property ckey: Integer read Fckey write Fckey;
    [Column('ctag', ftString, 20)]
    property ctag: String read Fctag write Fctag;
  end;

  /// ...and the entity whose TABLE is spelled `jns364`.
  [Entity]
  [Table('jns364', '')]
  [PrimaryKey('tkey', TAutoIncType.NotInc, TGeneratorType.NoneInc,
              TSortingOrder.NoSort, True, 'Primary key')]
  TJns364TableOwner = class
  private
    Ftkey: Integer;
    Fttag: String;
  public
    [Restrictions([TRestriction.NotNull])]
    [Column('tkey', ftInteger)]
    property tkey: Integer read Ftkey write Ftkey;
    [Column('ttag', ftString, 20)]
    property ttag: String read Fttag write Fttag;
  end;

  /// A SECOND claimant of table `jns364`, and the reason it exists: without
  /// it, WhenBothRulesClaimTheSegment_TheClassNameWins would only prove that
  /// ClassName beats ONE table claim. With it, the segment `jns364` is
  /// AMBIGUOUS by table AND resolvable by class name at the same time, so
  /// the same clause dies if the ambiguity refusal is ever hoisted above the
  /// ClassName pass - which would turn a URL that resolves today into a
  /// refusal. It is a projection over the same table, which is the shape
  /// that makes two entities over one table legitimate in the first place.
  [Entity]
  [Table('jns364', '')]
  [PrimaryKey('tkey', TAutoIncType.NotInc, TGeneratorType.NoneInc,
              TSortingOrder.NoSort, True, 'Primary key')]
  TJns364TableRival = class
  private
    Ftkey: Integer;
  public
    [Restrictions([TRestriction.NotNull])]
    [Column('tkey', ftInteger)]
    property tkey: Integer read Ftkey write Ftkey;
  end;

  /// THE AMBIGUOUS PAIR. Two entities over table `jns364amb`, and NO class
  /// named Tjns364amb - so the ClassName pass cannot end the scan and the
  /// resolver has to face the choice it used to make in silence. The row
  /// they would read carries a marker, so a clause cannot tell a refusal
  /// from a silent pick by accident: a silent pick answers DATA.
  [Entity]
  [Table('jns364amb', '')]
  [PrimaryKey('akey', TAutoIncType.NotInc, TGeneratorType.NoneInc,
              TSortingOrder.NoSort, True, 'Primary key')]
  TJns364AmbFull = class
  private
    Fakey: Integer;
    Fatag: String;
  public
    [Restrictions([TRestriction.NotNull])]
    [Column('akey', ftInteger)]
    property akey: Integer read Fakey write Fakey;
    [Column('atag', ftString, 20)]
    property atag: String read Fatag write Fatag;
  end;

  /// ...and the projection over it. Same table, different class, so the two
  /// ANSWERS differ - which is the only kind of collision that can send a
  /// caller to the wrong entity.
  [Entity]
  [Table('jns364amb', '')]
  [PrimaryKey('akey', TAutoIncType.NotInc, TGeneratorType.NoneInc,
              TSortingOrder.NoSort, True, 'Primary key')]
  TJns364AmbSlim = class
  private
    Fakey: Integer;
  public
    [Restrictions([TRestriction.NotNull])]
    [Column('akey', ftInteger)]
    property akey: Integer read Fakey write Fakey;
  end;

  [TestFixture]
  TTestServerResourceNaming = class(TRestHorseTestBase)
  private
    FHttp: THTTPClient;
    function _Url(const AResource: String): String;
    function _Get(const AResource: String): String;
    function _Post(const AResource, ABody: String): String;
    function _ObeysTheConvention(const AClass: TClass): Boolean;
    procedure _CreateCollisionSchema;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// PREMISE. The model this fixture drives really is outside the shipped
    /// convention, and it is outside it in the repository - not in a stub
    /// written here to make a point.
    [Test]
    procedure Premise_TheModelUnderTest_IsOffTheConvention;

    /// PREMISE, ASKED OF THE LIVE REGISTRY. Not one model of the eight this
    /// suite ships obeys `class = 'T' + table`. This replaces a hand
    /// counted census of the whole tree, which was wrong the first time it
    /// was written and would have rotted even if it had been right.
    [Test]
    procedure Premise_EveryModelThisSuiteShips_IsOffTheConvention;

    /// PREMISE and CONTROL. The route, the registration and the seed are
    /// live, and the class-name spelling reaches the entity. If this clause
    /// fails, nothing else in the fixture means anything.
    [Test]
    procedure TheClassNameSpelling_StillReaches;

    /// THE HEADLINE. The TABLE name - the exact string TSessionRestFul puts
    /// on the wire when JanusServerUse is on - must reach the same entity.
    [Test]
    procedure TheTableNameSpelling_MustReachTheSameEntity;

    /// ...and the refusal it used to get named a symbol that exists nowhere.
    [Test]
    procedure TheTableNameSpelling_MustNotBeRefusedByAnInventedName;

    /// It is not a GET-only repair: every verb reads the same getter.
    [Test]
    procedure ThePostByTableName_MustInsert;

    /// THE OTHER HALF OF THE PROTOCOL. Everything above spells the URL by
    /// hand; this one lets the real client spell it, with JanusServerUse
    /// set, and reads rows back through TRESTObjectSetAdapter.
    [Test]
    procedure AJanusClientWithServerUse_ReadsThisSuitesOwnModel;

    /// CONTROL. A segment nobody mapped must still be refused, or the
    /// resolver has stopped resolving and started agreeing.
    [Test]
    procedure AnUnknownResource_IsStillRefused;

    /// CONTROL, AND THE ONE THAT PINS THE PRECEDENCE. When a segment can be
    /// read BOTH ways, the ClassName reading wins - which is the whole
    /// reason no URL that resolved yesterday can change meaning today. The
    /// segment is also claimed TWICE by [Table], so this clause equally
    /// pins that the ambiguity refusal never fires above a class name.
    [Test]
    procedure WhenBothRulesClaimTheSegment_TheClassNameWins;

    /// THE REFUSAL. Two entities, one table, nobody claiming the segment by
    /// class name: the server must say so instead of picking whichever the
    /// hash table enumerated first.
    [Test]
    procedure WhenTwoEntitiesClaimTheSegmentByTable_TheServerRefusesToChoose;

    /// ...and the refusal has to be USEFUL and REPEATABLE: it names both
    /// candidates, and it names them in an order that does not depend on
    /// the enumeration that caused the problem.
    [Test]
    procedure TheAmbiguityRefusal_NamesBothCandidates;
  end;

implementation

uses
  RestHorseTest.Models;

const
  cTIMEOUT_MS = 3000;

{ TTestServerResourceNaming }

procedure TTestServerResourceNaming.Setup;
begin
  inherited Setup;
  FHttp := THTTPClient.Create;
  FHttp.ConnectionTimeout := cTIMEOUT_MS;
  FHttp.ResponseTimeout := cTIMEOUT_MS;
  SeedCustomers;
  _CreateCollisionSchema;
end;

procedure TTestServerResourceNaming.TearDown;
begin
  FreeAndNil(FHttp);
  inherited TearDown;
end;

function TTestServerResourceNaming._Url(const AResource: String): String;
begin
  Result := Format('http://127.0.0.1:%d/api/Janus/%s', [Port, AResource]);
end;

function TTestServerResourceNaming._Get(const AResource: String): String;
begin
  Result := FHttp.Get(_Url(AResource)).ContentAsString(TEncoding.UTF8);
end;

function TTestServerResourceNaming._Post(const AResource,
  ABody: String): String;
var
  LStream: TStringStream;
begin
  LStream := TStringStream.Create(ABody, TEncoding.UTF8);
  try
    Result := FHttp.Post(_Url(AResource), LStream, nil,
      [TNameValuePair.Create('Content-Type', 'application/json')])
        .ContentAsString(TEncoding.UTF8);
  finally
    LStream.Free;
  end;
end;

function TTestServerResourceNaming._ObeysTheConvention(
  const AClass: TClass): Boolean;
var
  LTable: TTableMapping;
begin
  LTable := TMappingExplorer.GetMappingTable(AClass);
  Assert.IsNotNull(LTable, AClass.ClassName + ' carries no [Table] mapping');
  Result := SameText('T' + LTable.Name, AClass.ClassName);
end;

procedure TTestServerResourceNaming.Premise_TheModelUnderTest_IsOffTheConvention;
var
  LTable: TTableMapping;
begin
  LTable := TMappingExplorer.GetMappingTable(TCustomerTest);
  Assert.IsNotNull(LTable, 'premise: TCustomerTest carries a [Table] mapping');
  Assert.AreEqual('customer_test', LTable.Name,
    'premise: the table this fixture spells in its URLs');
  Assert.AreNotEqual(LowerCase('T' + LTable.Name),
    LowerCase(TCustomerTest.ClassName),
    'PREMISE LOST. This fixture only means something while the model under ' +
    'test is OUTSIDE the class = T + table convention. Someone renamed the ' +
    'class or the table and the defect can no longer be reached from here - ' +
    'point the fixture at another off-convention model, do not delete it.');
end;

procedure TTestServerResourceNaming.Premise_EveryModelThisSuiteShips_IsOffTheConvention;
var
  LObeying: String;

  procedure Check(const AClass: TClass);
  begin
    if _ObeysTheConvention(AClass) then
      LObeying := LObeying + ' ' + AClass.ClassName;
  end;

begin
  LObeying := '';
  Check(TCustomerTest);
  Check(TOrderTest);
  Check(TProductTest);
  Check(TCustomerOrderSummary);
  Check(TGrantGETOnly);
  Check(TGrantGETAndPOST);
  Check(TGrantFullAllow);
  Check(TGrantReadOnlyWithPOST);
  Assert.AreEqual('', LObeying,
    'THE CONVENTION IS NOT A RULE, AND THIS IS THE MEASUREMENT THAT SAYS SO. ' +
    'It is asked of the LIVE [Table] mappings of the eight models this suite ' +
    'ships, not counted by hand over the tree - a counted census is a claim ' +
    'that rots, and the first draft of this file shipped one that was ' +
    'arithmetically impossible. If a model now OBEYS the convention it is ' +
    'no longer evidence for anything here and the fixture should be pointed ' +
    'at one that does not. Obeying:' + LObeying);
end;

procedure TTestServerResourceNaming.TheClassNameSpelling_StillReaches;
var
  LBody: String;
begin
  LBody := _Get('CustomerTest');
  Assert.IsTrue(LBody.Contains('Alice'),
    'THE CONTROL FOR A REPAIR THAT REPLACES INSTEAD OF EXTENDING. Every ' +
    'other clause in this suite addresses this entity by its class name ' +
    'minus the T; if resolving by table name costs that spelling, the whole ' +
    'suite goes with it. Body: ' + LBody);
end;

procedure TTestServerResourceNaming.TheTableNameSpelling_MustReachTheSameEntity;
var
  LBody: String;
begin
  LBody := _Get('customer_test');
  Assert.IsTrue(LBody.Contains('Alice'),
    'THE HEADLINE. customer_test is not a spelling this fixture invented: ' +
    'it is the literal string TSessionRestFul<M>.Create puts on the wire ' +
    'when the connection has ServerUse - FResource := Table(LTable).Name. ' +
    'The server decorated the segment into Tcustomer_test and matched THAT ' +
    'against ClassName, so a Janus client could not read a model of this ' +
    'framework own test repository. Body: ' + LBody);
end;

procedure TTestServerResourceNaming.TheTableNameSpelling_MustNotBeRefusedByAnInventedName;
var
  LBody: String;
begin
  LBody := _Get('customer_test');
  Assert.IsFalse(LBody.Contains('Tcustomer_test'),
    'THE REFUSAL NAMED A SYMBOL THAT IS IN NO SOURCE FILE. Tcustomer_test ' +
    'is neither the class, nor the table, nor what the caller asked for - it ' +
    'is the server own guess, handed back as if the caller had typed it. ' +
    'That is why this defect reads as a missing registration. Body: ' + LBody);
end;

procedure TTestServerResourceNaming.ThePostByTableName_MustInsert;
var
  LBody: String;
begin
  ResetDatabase;
  LBody := _Post('customer_test',
    '{"name":"Dave","email":"dave@test.com","active":true}');
  Assert.IsFalse(LBody.Contains('not registered'),
    'the resolution lives in one getter that every verb reads, so a repair ' +
    'that only reaches GET is in the wrong place. Body: ' + LBody);
  Assert.IsTrue(_Get('CustomerTest').Contains('Dave'),
    'the POST by table name did not refuse, and no row arrived either. The ' +
    'read-back deliberately uses the OTHER spelling: both names must address ' +
    'one entity and one table, not two. Body: ' + LBody);
end;

procedure TTestServerResourceNaming.AJanusClientWithServerUse_ReadsThisSuitesOwnModel;
var
  LClient: TRESTClientHorse;
  LObjectSet: TRESTObjectSetAdapter<TCustomerTest>;
  LList: TObjectList<TCustomerTest>;
begin
  LClient := TRESTClientHorse.Create(nil);
  try
    LClient.Host := '127.0.0.1';
    LClient.Port := Port;
    /// BEFORE the adapter is built, on purpose: TSessionRestFul<M>.Create
    /// reads FConnection.ServerUse ONCE, in its constructor, and that is the
    /// read that decides the resource is spelled with the TABLE name.
    LClient.JanusServerUse := True;
    LObjectSet := TRESTObjectSetAdapter<TCustomerTest>.Create(
                    LClient.AsConnection);
    try
      LList := LObjectSet.Find;
      try
        Assert.AreEqual(3, LList.Count,
          'THE ONLY CLAUSE HERE THAT DRIVES BOTH HALVES OF THE PROTOCOL. ' +
          'No URL is spelled by this test: TRESTClientHorse builds it from ' +
          'the model, and with JanusServerUse that spelling is the TABLE ' +
          'name. Against the unrepaired server this same call came back as ' +
          '"Resource [Tcustomer_test] not registered on the server!" - the ' +
          'framework client unable to read the framework own test model.');
        Assert.AreEqual('Alice', LList[0].Name,
          'three rows arrived but not the seeded ones - the segment reached ' +
          'something, and it was not customer_test.');
      finally
        LList.Free;
      end;
    finally
      LObjectSet.Free;
    end;
  finally
    LClient.Free;
  end;
end;

procedure TTestServerResourceNaming._CreateCollisionSchema;
begin
  ExecuteSQL('DROP TABLE IF EXISTS jns364_alias');
  ExecuteSQL('DROP TABLE IF EXISTS jns364');
  ExecuteSQL('DROP TABLE IF EXISTS jns364amb');
  ExecuteSQL('CREATE TABLE jns364_alias (ckey INTEGER PRIMARY KEY, '
    + 'ctag VARCHAR(20))');
  ExecuteSQL('CREATE TABLE jns364 (tkey INTEGER PRIMARY KEY, '
    + 'ttag VARCHAR(20))');
  ExecuteSQL('CREATE TABLE jns364amb (akey INTEGER PRIMARY KEY, '
    + 'atag VARCHAR(20))');
  ExecuteSQL('INSERT INTO jns364_alias (ckey, ctag) VALUES (1, '
    + '''iamtheclass'')');
  ExecuteSQL('INSERT INTO jns364 (tkey, ttag) VALUES (1, ''iamthetable'')');
  ExecuteSQL('INSERT INTO jns364amb (akey, atag) VALUES (1, '
    + '''iamambiguous'')');
end;

procedure TTestServerResourceNaming.WhenBothRulesClaimTheSegment_TheClassNameWins;
var
  LBody: String;
begin
  LBody := _Get('jns364');
  Assert.IsTrue(LBody.Contains('iamtheclass'),
    'THE PRECEDENCE INVERTED. `jns364` is claimed by three registered '
    + 'entities at once - it is Tjns364 minus the T, and it is the table of '
    + 'BOTH TJns364TableOwner and TJns364TableRival - and the ClassName '
    + 'reading is the one that answered before this repair existed. If a '
    + 'table reading now wins, a URL that used to reach one entity silently '
    + 'reaches another, which is a worse defect than the one being fixed. '
    + 'Body: ' + LBody);
  Assert.IsFalse(LBody.Contains('iamthetable'),
    'the segment resolved to an entity whose TABLE it names, not the one '
    + 'whose CLASS it names. Body: ' + LBody);
  Assert.IsFalse(LBody.Contains('is ambiguous on the server'),
    'THE REFUSAL ATE A SEGMENT THAT RESOLVES. Two entities do map table '
    + '`jns364`, so the ambiguity is real - but a class name claims the '
    + 'segment too, and the class name is checked first and ENDS the scan. '
    + 'If the refusal is ever hoisted above the ClassName pass, every URL '
    + 'that a duplicated table shadows starts failing. Body: ' + LBody);
end;

procedure TTestServerResourceNaming.WhenTwoEntitiesClaimTheSegmentByTable_TheServerRefusesToChoose;
var
  LBody: String;
begin
  LBody := _Get('jns364amb');
  /// The refusal is matched by a phrase that the DATA cannot contain. The
  /// marker row is spelled `iamambiguous` ON PURPOSE, and a first draft of
  /// this clause asked only for 'ambiguous' - which the marker satisfies, so
  /// the assertion passed on a body that was the silent pick it exists to
  /// forbid. It was a MUTATION that exposed it, not a re-reading.
  Assert.IsTrue(LBody.Contains('is ambiguous on the server'),
    'THE SILENT CHOICE IS BACK. Table `jns364amb` is mapped by BOTH '
    + 'TJns364AmbFull and TJns364AmbSlim and no class is named Tjns364amb, '
    + 'so the resolver has to face a choice with no rule behind it. The '
    + 'order it used to choose in is `FEntitys.Keys` of a '
    + 'TObjectDictionary<TClass, ..> - hash buckets over VMT pointers, in an '
    + 'image linked /DYNAMICBASE. MEASURED, in this fixture, with the '
    + 'silent pick put back and NOTHING else changed but the order of the '
    + 'two RegisterEntity lines below: /jns364amb answered '
    + '[{"akey":1,"atag":"iamambiguous"}] with one order and [{"akey":1}] '
    + 'with the other - two different entities for one URL. Answering the '
    + 'wrong entity in silence is worse than refusing. Body: ' + LBody);
  Assert.IsFalse(LBody.Contains('iamambiguous'),
    'IT DID NOT REFUSE - IT ANSWERED, AND IT ANSWERED DATA. The row exists '
    + 'precisely so this clause can tell a refusal from a silent pick '
    + 'instead of passing because the table happened to be missing. '
    + 'Body: ' + LBody);
end;

procedure TTestServerResourceNaming.TheAmbiguityRefusal_NamesBothCandidates;
var
  LBody: String;
begin
  LBody := _Get('jns364amb');
  Assert.IsTrue(LBody.Contains('TJns364AmbFull'),
    'a refusal that does not name the candidates leaves the caller with '
    + 'nothing to do about it. Body: ' + LBody);
  Assert.IsTrue(LBody.Contains('TJns364AmbSlim'),
    'only one candidate was named - and which one would then depend on the '
    + 'same enumeration order the refusal exists to escape. Body: ' + LBody);
  Assert.IsTrue(LBody.IndexOf('TJns364AmbFull') < LBody.IndexOf('TJns364AmbSlim'),
    'THE REFUSAL ITSELF IS ORDER-DEPENDENT. The two names are the LEXICAL '
    + 'extremes of the claimant set, not the first two the enumeration '
    + 'produced, so the sentence is the same on every run and on every '
    + 'machine. If they are emitted in encounter order, a message that '
    + 'reports non-determinism becomes non-deterministic. Body: ' + LBody);
end;

procedure TTestServerResourceNaming.AnUnknownResource_IsStillRefused;
var
  LBody: String;
begin
  LBody := _Get('no_such_resource_9364');
  Assert.IsTrue(LBody.Contains('not registered'),
    'THE CONTROL AGAINST A RESOLVER THAT AGREES WITH EVERYTHING. A segment ' +
    'no model claims must still be refused, and refused by the documented ' +
    'sentence. Body: ' + LBody);
end;

initialization
  /// REGISTERED HERE, NOT IN SetupFixture, ON PURPOSE:
  /// TMappingExplorer.GetRepositoryMapping builds its TMappingRepository
  /// ONCE, from a snapshot of TRegisterClass, and caches it - anything
  /// registered after the first request is invisible to the resolver.
  TRegisterClass.RegisterEntity(Tjns364);
  TRegisterClass.RegisterEntity(TJns364TableOwner);
  TRegisterClass.RegisterEntity(TJns364TableRival);
  TRegisterClass.RegisterEntity(TJns364AmbFull);
  TRegisterClass.RegisterEntity(TJns364AmbSlim);
  TDUnitX.RegisterTestFixture(TTestServerResourceNaming);

end.
