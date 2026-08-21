{
  ------------------------------------------------------------------------------
  Janus
  Modern Object-Relational Mapping (ORM) framework for Delphi.

  SPDX-License-Identifier: MIT
  Copyright (c) 2016-2026 Isaque Pinheiro
  ------------------------------------------------------------------------------
}

(* @abstract(Janus Framework - an id of -1 must address the row whose key is -1
  and nothing else, issue #361.)

  WHAT IS UNDER TEST

  The server's by-id path, driven end to end: a real Horse listener, a real
  SQLite file, and raw HTTP with no Janus client anywhere in the picture. That
  matters, because the defect this fixture pins is reachable by ANY caller that
  puts -1 in the path segment - an old client, a third party integration, a
  hand-typed URL - and a fixture written over the Janus client would have
  proved only that the client stopped sending it.

  WHAT WAS WRONG

  -1 was two values at once. It is the placeholder an AutoInc key carries until
  the database answers - cAutoIncNotGenerated, Janus.DataSet.Fields.pas:51 -
  and it was ALSO the server's private way of saying "no id at all":
  TDMLGeneratorAbstract._IsType answered True for exactly -1 as UInt64, Int64,
  Integer and as the string '-1', and GetGeneratorWhere answered an id it
  agreed with by discarding the WHOLE predicate. So `resource(-1)` asked for
  one row and produced a statement over EVERY row.

  MEASURED ON develop 0103408, BEFORE THE REPAIR, BY THIS FIXTURE

  Against a table holding a single row, DELETE idsmid(-1) answered 200 and
  "delete command executed successfully", and left idsmid AND its cascaded
  child idsleaf EMPTY. GET idsmid(-1) handed back the row whose key is 1. Two
  real rows destroyed by asking for a key that does not exist.

  WHAT LIMITED IT, AND WHY THAT IS NOT A DEFENCE

  TRESTObjectManager.Find (Janus.Server.RestObject.Manager.pas) builds an
  object only when RecordCount = 1, so with two rows in the table the same
  request answered "No records found to delete". The blast radius was decided
  by how many rows happened to be in the table, which is not a guard.

  THE REPAIR THESE CLAUSES CERTIFY

  "Give me everything" and "give me the row with this id" stopped being told
  apart by a VALUE. "No id" is now a TYPELESS TValue - out of band, so no
  caller supplying an id can spell it - and -1 went back to being an ordinary
  key. See TDMLGeneratorAbstract._NoIdSupplied.

  THE CONTROLS ARE NOT DECORATIVE

  TheCollection_StillAnswersEveryRow is the clause that dies for the lazy
  repair. The two callers that legitimately mean "everything" -
  TCommandSelecter.GenerateSelectAll and its GenerateNextPacket overload - used
  to say so by handing -1 to the generator, so any fix that merely stops -1
  from meaning "no filter" without moving THEM turns every collection read into
  an empty one. RealId_StillReadsThatRow and MinusTwo_StillAnswersNull pin that
  the repair changed the sentinel and not the by-id path.

  WHAT THIS FIXTURE DELIBERATELY DOES NOT REPAIR, AND SAYS SO

  ThePut_AddressesExactlyTheRowWhoseKeyIsMinusOne characterises the PUT route,
  which the issue reported as a third symptom. It is GREEN BEFORE AND AFTER the
  repair and it is here to record that, because the reading in the issue does
  not survive contact with the code: ParseUpdate builds its WHERE by literal
  through _PrimaryKeyValueToSql (Janus.Server.Resource.pas) and never consults
  the sentinel at all, so a PUT carrying key -1 matches the row whose key IS -1
  - which is the CORRECT answer to the question asked. What made that look like
  a defect is the client arriving with a stale placeholder, and that is issue
  #312's ground, not this one's. Refusing -1 as a key outright would be a
  product decision about a value the database accepts, and it is not taken
  here.

  ANCHORS ARE BY SYMBOL, NEVER BY file:line. *)

unit Test.Janus.Server.IdSentinelCollision;

interface

uses
  SysUtils,
  Classes,
  Variants,
  Generics.Collections,
  DB,
  DUnitX.TestFramework,
  Net.HTTPClient,
  Net.URLClient,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Comp.Client,
  MetaDbDiff.mapping.attributes,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Register,
  RestHorseTest.Base;

type
  /// THE NAMES ARE NOT DECORATIVE. TRESTQueryParse.GetResourceName answers
  /// 'T' + the path segment and TMappingRepository.FindEntityByName matches it
  /// against ClassName, so the shipped convention is class = 'T' + table. Every
  /// key column is spelled once (im, il) so a propagation that reads the wrong
  /// entity's key mapping cannot resolve by coincidence.
  [Entity]
  [Table('idsleaf', '')]
  [PrimaryKey('ilkey', TAutoIncType.AutoInc, TGeneratorType.SequenceInc,
              TSortingOrder.NoSort, True, 'Primary key')]
  [Sequence('idsleaf')]
  Tidsleaf = class
  private
    Filkey: Integer;
    Filparent: Integer;
    Filtag: String;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('ilkey', ftInteger)]
    property ilkey: Integer read Filkey write Filkey;
    [Column('ilparent', ftInteger)]
    property ilparent: Integer read Filparent write Filparent;
    [Column('iltag', ftString, 20)]
    property iltag: String read Filtag write Filtag;
  end;

  [Entity]
  [Table('idsmid', '')]
  [PrimaryKey('imkey', TAutoIncType.AutoInc, TGeneratorType.SequenceInc,
              TSortingOrder.NoSort, True, 'Primary key')]
  [Sequence('idsmid')]
  Tidsmid = class
  private
    Fimkey: Integer;
    Fimtag: String;
    Fleafs: TObjectList<Tidsleaf>;
  public
    constructor Create;
    destructor Destroy; override;
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('imkey', ftInteger)]
    property imkey: Integer read Fimkey write Fimkey;
    [Column('imtag', ftString, 20)]
    property imtag: String read Fimtag write Fimtag;
    [Association(TMultiplicity.OneToMany, 'imkey', 'idsleaf', 'ilparent')]
    [CascadeActions([TCascadeAction.CascadeAutoInc,
                     TCascadeAction.CascadeInsert,
                     TCascadeAction.CascadeUpdate,
                     TCascadeAction.CascadeDelete])]
    property leafs: TObjectList<Tidsleaf> read Fleafs write Fleafs;
  end;

  [TestFixture]
  TTestServerIdSentinelCollision = class(TRestHorseTestBase)
  private
    FProbeDb: TFDConnection;
    FHttp: THTTPClient;
    function _Base: String;
    function _Get(const APath: String): IHTTPResponse;
    function _Delete(const APath: String): IHTTPResponse;
    function _Scalar(const ASQL: String): String;
    function _Count(const ATable: String): Integer;
    procedure _CreateSchema;
    /// One mid row and one leaf hanging off it. ONE row is the whole point:
    /// TRESTObjectManager.Find only builds an object when RecordCount = 1, so
    /// a table of one is where the discarded predicate becomes destructive.
    procedure _SeedOneMidWithOneLeaf;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// THE HEADLINE. Deleting a key that does not exist must not delete the
    /// key that does.
    [Test]
    procedure DeleteByThePlaceholder_MustNotDeleteTheOnlyRow;

    /// ...nor the grandchild the cascade takes with it.
    [Test]
    procedure DeleteByThePlaceholder_MustNotCascadeIntoTheChild;

    /// And it must SAY so, rather than reporting a successful delete of
    /// something it never named.
    [Test]
    procedure DeleteByThePlaceholder_MustNotReportSuccess;

    /// The read side of the same hole.
    [Test]
    procedure GetByThePlaceholder_MustNotAnswerWithAnotherRow;

    /// CONTROL - the repair must not turn "everything" into "nothing".
    [Test]
    procedure TheCollection_StillAnswersEveryRow;

    /// CONTROL - a real id still reads its own row.
    [Test]
    procedure RealId_StillReadsThatRow;

    /// CONTROL - it was never "any negative"; -2 answered null then and now.
    [Test]
    procedure MinusTwo_StillAnswersNull;

    /// CHARACTERISATION, GREEN ON BOTH SIDES - see the header.
    [Test]
    procedure GetMinusOne_ReadsTheRowWhoseKeyIsMinusOneWhenThereIsOne;
  end;

implementation

uses
  Janus.Server.Resource;

const
  cDDL_MID =
    'CREATE TABLE IF NOT EXISTS idsmid (' +
    '  imkey INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  imtag VARCHAR(20))';
  cDDL_LEAF =
    'CREATE TABLE IF NOT EXISTS idsleaf (' +
    '  ilkey    INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  ilparent INTEGER,' +
    '  iltag    VARCHAR(20))';

{ Tidsmid }

constructor Tidsmid.Create;
begin
  Fleafs := TObjectList<Tidsleaf>.Create;
end;

destructor Tidsmid.Destroy;
begin
  Fleafs.Free;
  inherited;
end;

{ TTestServerIdSentinelCollision }

procedure TTestServerIdSentinelCollision._CreateSchema;
begin
  ExecuteSQL('DROP TABLE IF EXISTS idsleaf');
  ExecuteSQL('DROP TABLE IF EXISTS idsmid');
  ExecuteSQL(cDDL_MID);
  ExecuteSQL(cDDL_LEAF);
end;

procedure TTestServerIdSentinelCollision._SeedOneMidWithOneLeaf;
begin
  ExecuteSQL('INSERT INTO idsmid (imtag) VALUES (''keepme'')');
  ExecuteSQL('INSERT INTO idsleaf (ilparent, iltag) VALUES (1, ''keepmetoo'')');
end;

procedure TTestServerIdSentinelCollision.Setup;
begin
  inherited Setup;
  _CreateSchema;
  FProbeDb := TFDConnection.Create(nil);
  FProbeDb.Params.DriverID := 'SQLite';
  FProbeDb.Params.Database := cTEST_DB_PATH;
  FProbeDb.Params.Values['OpenMode'] := 'CreateUTF8';
  FProbeDb.ResourceOptions.SilentMode := True;
  FProbeDb.Connected := True;
  FHttp := THTTPClient.Create;
  FHttp.ConnectionTimeout := 5000;
  FHttp.ResponseTimeout := 5000;
end;

procedure TTestServerIdSentinelCollision.TearDown;
begin
  FreeAndNil(FHttp);
  if Assigned(FProbeDb) then
  begin
    FProbeDb.Connected := False;
    FreeAndNil(FProbeDb);
  end;
  inherited TearDown;
end;

function TTestServerIdSentinelCollision._Base: String;
begin
  Result := Format('http://127.0.0.1:%d/api/Janus/', [Port]);
end;

function TTestServerIdSentinelCollision._Get(const APath: String): IHTTPResponse;
begin
  Result := FHttp.Get(_Base + APath);
end;

function TTestServerIdSentinelCollision._Delete(const APath: String): IHTTPResponse;
begin
  Result := FHttp.Delete(_Base + APath);
end;

function TTestServerIdSentinelCollision._Scalar(const ASQL: String): String;
var
  LValue: Variant;
begin
  LValue := FProbeDb.ExecSQLScalar(ASQL);
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Result := '<null>'
  else
    Result := VarToStr(LValue);
end;

function TTestServerIdSentinelCollision._Count(const ATable: String): Integer;
begin
  Result := StrToIntDef(_Scalar('SELECT COUNT(*) FROM ' + ATable), -99);
end;

procedure TTestServerIdSentinelCollision.DeleteByThePlaceholder_MustNotDeleteTheOnlyRow;
var
  LResp: IHTTPResponse;
begin
  _SeedOneMidWithOneLeaf;
  Assert.AreEqual(1, _Count('idsmid'), 'premise: exactly one mid row is seeded');
  LResp := _Delete('idsmid(-1)');
  Assert.AreEqual(1, _Count('idsmid'),
    'DELETE idsmid(-1) named a key that does not exist and the only real row '
    + 'is gone. -1 was the server''s private word for "no id", so the WHERE '
    + 'was discarded and the statement addressed the whole table. The server '
    + 'answered ' + IntToStr(LResp.StatusCode) + ' '
    + LResp.ContentAsString(TEncoding.UTF8));
  Assert.AreEqual('keepme', _Scalar('SELECT imtag FROM idsmid'),
    'the surviving row is not the row that was seeded');
end;

procedure TTestServerIdSentinelCollision.DeleteByThePlaceholder_MustNotCascadeIntoTheChild;
begin
  _SeedOneMidWithOneLeaf;
  Assert.AreEqual(1, _Count('idsleaf'), 'premise: exactly one leaf is seeded');
  _Delete('idsmid(-1)');
  Assert.AreEqual(1, _Count('idsleaf'),
    'the child went down with the parent the request never named. This is the '
    + 'second row destroyed by one request for a key that does not exist, and '
    + 'it is why the defect is not merely a wrong answer.');
end;

procedure TTestServerIdSentinelCollision.DeleteByThePlaceholder_MustNotReportSuccess;
var
  LResp: IHTTPResponse;
  LBody: String;
begin
  _SeedOneMidWithOneLeaf;
  LResp := _Delete('idsmid(-1)');
  LBody := LResp.ContentAsString(TEncoding.UTF8);
  Assert.IsFalse(LBody.Contains('executed successfully'),
    'the server reported a successful delete for a key it never located: '
    + IntToStr(LResp.StatusCode) + ' ' + LBody);
end;

procedure TTestServerIdSentinelCollision.GetByThePlaceholder_MustNotAnswerWithAnotherRow;
var
  LBody: String;
begin
  _SeedOneMidWithOneLeaf;
  LBody := _Get('idsmid(-1)').ContentAsString(TEncoding.UTF8);
  Assert.IsFalse(LBody.Contains('keepme'),
    'GET idsmid(-1) handed back the row whose key is 1. Asking for a key that '
    + 'does not exist must not answer with a different row. Body: ' + LBody);
end;

procedure TTestServerIdSentinelCollision.TheCollection_StillAnswersEveryRow;
var
  LBody: String;
begin
  ExecuteSQL('INSERT INTO idsmid (imtag) VALUES (''one'')');
  ExecuteSQL('INSERT INTO idsmid (imtag) VALUES (''two'')');
  LBody := _Get('idsmid').ContentAsString(TEncoding.UTF8);
  Assert.IsTrue(LBody.Contains('one') and LBody.Contains('two'),
    'THE CONTROL FOR THE LAZY REPAIR. "Give me everything" used to be spelled '
    + 'by handing -1 to the generator, so a fix that stops -1 meaning "no '
    + 'filter" without moving that caller turns every collection read into an '
    + 'empty one. Body: ' + LBody);
end;

procedure TTestServerIdSentinelCollision.RealId_StillReadsThatRow;
var
  LBody: String;
begin
  ExecuteSQL('INSERT INTO idsmid (imkey, imtag) VALUES (7, ''seven'')');
  ExecuteSQL('INSERT INTO idsmid (imkey, imtag) VALUES (8, ''eight'')');
  LBody := _Get('idsmid(7)').ContentAsString(TEncoding.UTF8);
  Assert.IsTrue(LBody.Contains('seven'),
    'a real id stopped reading its own row. Body: ' + LBody);
  Assert.IsFalse(LBody.Contains('eight'),
    'a real id read a row that is not its own. Body: ' + LBody);
end;

procedure TTestServerIdSentinelCollision.MinusTwo_StillAnswersNull;
var
  LBody: String;
begin
  _SeedOneMidWithOneLeaf;
  LBody := _Get('idsmid(-2)').ContentAsString(TEncoding.UTF8);
  Assert.IsFalse(LBody.Contains('keepme'),
    'IT WAS NEVER "ANY NEGATIVE". -2 answered null before the repair and must '
    + 'still answer null after it, which is what makes -1 a collision with the '
    + 'AutoInc placeholder and not a sign error. Body: ' + LBody);
end;

procedure TTestServerIdSentinelCollision.GetMinusOne_ReadsTheRowWhoseKeyIsMinusOneWhenThereIsOne;
var
  LBody: String;
begin
  /// SQLite accepts an explicit negative value in an INTEGER PRIMARY KEY
  /// AUTOINCREMENT column, so a row whose real key IS the placeholder can be
  /// planted. This clause is GREEN ON BOTH SIDES of the repair and is here to
  /// record what -1 means once it stops being a sentinel: an ordinary key.
  ExecuteSQL('INSERT INTO idsmid (imkey, imtag) VALUES (-1, ''iamminusone'')');
  LBody := _Get('idsmid(-1)').ContentAsString(TEncoding.UTF8);
  Assert.IsTrue(LBody.Contains('iamminusone'),
    'the row whose key is -1 must be reachable BY that key - refusing -1 '
    + 'outright would be a product decision about a value the database '
    + 'accepts, and this branch does not take it. Body: ' + LBody);
end;

initialization
  TRegisterClass.RegisterEntity(Tidsleaf);
  TRegisterClass.RegisterEntity(Tidsmid);
  TDUnitX.RegisterTestFixture(TTestServerIdSentinelCollision);

end.
