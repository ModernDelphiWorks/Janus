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

(* @abstract(Janus Framework - the WHERE clause a PUT locates its row with,
  issue #320.)

  A parenthesis-star header, like its sibling Test.Janus.Server.Resource.KeyQuoting:
  the text below quotes SQL and JSON fragments that contain braces, and a brace
  inside a brace comment ends the comment where the text does not.

  WHAT IS UNDER TEST

  TAppResourceBase.ParseUpdate, the loop that builds the predicate handed to
  TRESTObjectSet.FindOne. It is the ONLY producer of that predicate in Source\ -
  the Horse, WiRL, MARS, DMVC and DataSnap resources all reach it through
  TAppResourceBase.update and none of them assembles a predicate of its own.

  AND THE LAST THREE CLAUSES ARE NOT ABOUT THAT LOOP AT ALL, WHICH FALSIFIES
  THE PARAGRAPH ABOVE IF IT IS READ AS A DESCRIPTION OF THE FIXTURE RATHER THAN
  OF ParseUpdate. They exercise ParseDelete and ResolverFindID, which locate
  their row from the URI's ID instead of building a predicate, and they are
  here because the issue named those two paths as unmeasured. They are green at
  the base commit; see the comment on them.

  WHAT THE LOOP USED TO DO

  It concatenated text: table name, dot, column name, '=', and then the value
  straight out of VarToStr, with no quoting and no parameter. An integer key
  produced (TAB.ID=10), which is valid SQL by coincidence - a bare integer is
  also a SQL numeric literal. Every other type produced a BARE TOKEN where SQL
  requires a quoted literal, and a bare token in that position is a COLUMN
  REFERENCE.

  So the whole of PUT was broken for any entity whose key is not a bare number,
  and the value came out of the request body, so the shape of the statement was
  the client's to choose.

  WHY THE ASSERTIONS ARE PARTLY ON THE WIRE AND NOT ONLY ON THE ROWS

  SQLite applies COLUMN AFFINITY: with an INTEGER column, `WHERE ktid = '10'`
  converts the text literal and matches anyway. Measured, not assumed - see
  IntegerKey_TheKeyLiteralMustNotBeQuoted, which fails against a repair that
  quotes every value while every row-level clause in this fixture stays green.
  A fixture that only looked at rows would therefore accept the cheapest wrong
  repair. The clauses that have to see the STATEMENT read it from the command
  monitor, which is the same TMonitorProc callback TDMLCommandFactory feeds for
  every command it emits.

  WHY THE ROWS ARE SEEDED THROUGH THE SERVER'S OWN INSERT

  A seed written with a hand-built INSERT literal would be rendered by this
  fixture, and the fixture would then be asserting that its own rendering
  matches the one under test - blind to any shape both get wrong together. The
  seeds here go through TAppResourceBase.insert, which writes through BOUND
  PARAMETERS (TCommandInserter fills a TParams and DataEngine binds it). The
  write path and the read-back path are therefore different mechanisms, and a
  date or a fraction that only round trips because both sides mangle it the
  same way cannot pass.

  WHAT THIS FIXTURE DELIBERATELY DOES NOT ASSERT

  It does not pin a date literal FORMAT beyond what SQLite needs. The correct
  literal for a date key is a per-dialect question - TDMLGeneratorAbstract
  carries an FDateFormat with four distinct values across the thirteen dialects
  - and the resource layer cannot reach that field. What is pinned here is that
  a date key locates the row the framework itself wrote. See the note on
  _PrimaryKeyValueToSql in Janus.Server.Resource for the residue.

  ANCHORS ARE BY METHOD, NEVER BY file:line. *)

unit Test.Janus.Server.Resource.UpdateWhere;

interface

uses
  Classes,
  SysUtils,
  Variants,
  StrUtils,
  IOUtils,
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
  Janus.Server.RestQuery.Parse,
  Test.Janus.Model.KeyTypes,
  Test.Janus.Model.KeyTypeDecoy;

type
  [TestFixture]
  TTestServerResourceUpdateWhere = class
  private
    FDConnection: TFDConnection;
    FConnection: IDBConnection;
    /// Every command TDMLCommandFactory emits, in order, captured through the
    /// TMonitorProc the connection was built with.
    FCommands: TStringList;
    function InsertRaw(const AResource, ABody: String): String;
    /// The two SIBLING paths of ParseUpdate, which locate their row from the
    /// URI's ID rather than by building a predicate out of the body.
    function DeleteRaw(const AURI: String): String;
    function FindRaw(const AURI: String): String;
    function UpdateRaw(const AResource, ABody: String): String;
    /// The last SELECT the factory emitted against ATable. Fails - dumping the
    /// whole capture - when there is none.
    function LastSelect(const ATable: String): String;
    function ScalarStr(const ASQL: String): String;
    function ScalarInt(const ASQL: String): Integer;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;
    [Setup]
    procedure Setup;

    /// THE HEADLINE. A textual key must locate its row instead of being read
    /// as the name of a column.
    [Test]
    procedure TextualKey_ThePutMustReachTheRowItNames;

    /// ...and it must reach ONLY that row.
    [Test]
    procedure TextualKey_ThePutMustLeaveTheOtherRowsAlone;

    /// The control against a repair that stops quoting nothing and starts
    /// quoting everything. SQLite converts '10' for an INTEGER column, so no
    /// row-level clause in this fixture can see it; this one reads the wire.
    [Test]
    procedure IntegerKey_TheKeyLiteralMustNotBeQuoted;

    /// The control that an integer key still works at all.
    [Test]
    procedure IntegerKey_ThePutMustStillReachItsRow;

    /// A quote inside the value. Wrapping the value in quotes WITHOUT doubling
    /// the embedded one produces a statement that is malformed again, in a new
    /// way. This is the clause that separates QuotedStr from `'' + v + ''`.
    [Test]
    procedure TextualKeyCarryingAQuote_ThePutMustReachTheRowItNames;

    /// The injection. The value is chosen so that the OLD concatenation
    /// produces a syntactically VALID statement whose predicate is not the one
    /// the server meant - a bare column reference OR'd with a second clause.
    [Test]
    procedure AnInjectedPredicateMustTravelAsAValueAndNotAsStructure;

    /// ...and the row it was aimed at must come out untouched.
    [Test]
    procedure AnInjectedPredicateMustNotReachTheRowItTargets;

    /// Braces and hyphens: a generated GUID key, stored as text.
    [Test]
    procedure GuidShapedKey_ThePutMustReachTheRowItNames;

    /// A slash - or whatever the ambient FormatSettings renders - inside what
    /// SQL reads as an identifier.
    [Test]
    procedure DateKey_ThePutMustReachTheRowItNames;

    /// A decimal separator. The key must stay a NUMERIC literal: a fractional
    /// key quoted, or rendered with the ambient comma, locates nothing.
    [Test]
    procedure FractionalKey_ThePutMustReachTheRowItNames;
    [Test]
    procedure FractionalKey_TheKeyLiteralMustCarryADecimalPoint;

    /// THESE TWO ASSERT THE LITERAL AND NOT THE ROW, AND THE REASON IS
    /// MEASURED RATHER THAN CHOSEN. Both keys are rendered CORRECTLY by the
    /// predicate at the base commit already, so neither clause is red-first;
    /// they are regression guards over the numeric branch. Neither can be
    /// written as a row-level clause, because a PUT on either entity does not
    /// reach its row for reasons that are NOT this issue's - both measured at
    /// the base commit through the command monitor and reported separately:
    ///
    ///  - 64-BIT: the predicate is exactly (ktbig.ktbig=9007199254740993), it
    ///    matches the row - COUNT(*) over that same text answers 1 - and the
    ///    PUT then emits no UPDATE at all. What it emits is
    ///    `DELETE FROM ktbig WHERE ktbig = :ktbig` with the parameter bound to
    ///    1, which is TRESTObjectSet.Update's master-detail sweep firing over
    ///    a state object whose key is not the one Modify snapshotted.
    ///  - UNSIGNED: the row the framework's own INSERT writes carries
    ///    -9223372036854775808 - the signed reinterpretation of the key the
    ///    caller sent, written by the INSERT path, before any of this runs.
    ///
    /// Width. Nothing about selecting the numeric branch depends on it.
    [Test]
    procedure BigIntegerKey_TheKeyLiteralMustNotBeNarrowed;
    /// An unsigned key above High(Int64): read back through a signed cast the
    /// bit pattern is negative, which is a perfectly valid SQL literal that
    /// locates nothing.
    [Test]
    procedure UnsignedKeyAboveHighInt64_TheKeyLiteralMustNotFlipSign;

    /// A boolean key. VarIsOrdinal answers True for varBoolean, so a repair
    /// that keys off the Variant alone swallows it into the numeric branch.
    [Test]
    procedure BooleanKey_ThePutMustReachTheRowItNames;

    /// The predicate names the COLUMN. TKeyTypeAlias maps the property
    /// `ktcode` onto the column `kt_code`, and it is the only entity in this
    /// project that can tell the two apart.
    [Test]
    procedure ThePredicateNamesTheColumn_NotTheProperty;

    /// The pair list is a LOOP. Two rows share their first key column, so a
    /// loop that stops after its first turn reaches the wrong one.
    [Test]
    procedure CompositeTextualKey_EveryKeyColumnStaysInThePredicate;

    /// A key the request did not carry cannot identify a row, and must not be
    /// allowed to identify an arbitrary one.
    [Test]
    procedure NullableKeyWithNoValue_MustNotReachAnyRow;

    /// ...AND THE ROW-LEVEL CLAUSE ABOVE CANNOT SEE THE GUARD THAT MAKES IT
    /// TRUE, which is why this one exists. Measured by mutation: deleting the
    /// whole `VarIsNull or VarIsEmpty` test leaves the clause above green,
    /// because the branch it then falls into renders the empty Variant as the
    /// literal '' and no seeded row carries an empty key - and even a row that
    /// did would not be UPDATED, since the update's own predicate binds the
    /// same absent value and `col = NULL` matches nothing in SQL. Two layers
    /// of accident, neither of them the guard. This clause reads the statement.
    [Test]
    procedure NullableKeyWithNoValue_ThePredicateMustBeUnsatisfiable;

    /// The OTHER half of that guard. MetaDbDiff's GetNullableValue answers a
    /// Variant NULL for a Nullable whose FHasValue is clear, and leaves the
    /// EMPTY TValue it started with - varEmpty, not varNull - for a
    /// Nullable-SHAPED record that has no FValue field at all, which the
    /// framework accepts because IsNullable is a check BY NAME. Only
    /// TKeyTypeDecoy reaches that state.
    [Test]
    procedure NullableShapedKeyWithNoValueField_MustNotReachAnyRow;

    /// The wire half of the same pair, and the ONLY clause in this fixture
    /// that dies when the VarIsEmpty half alone is removed.
    [Test]
    procedure NullableShapedKeyWithNoValueField_ThePredicateMustBeUnsatisfiable;

    /// The guard against a repair whose predicate is always true.
    [Test]
    procedure AKeyThatMatchesNothing_LeavesEveryRowAlone;

    /// The response of a PUT that did land.
    [Test]
    procedure TheUpdateResponseNamesTheResource;

    /// THE TWO SIBLING PATHS THE ISSUE LEFT UNMEASURED, AND THEY ARE MEASURED
    /// HERE RATHER THAN REPAIRED, BECAUSE THEY TURNED OUT NOT TO NEED IT.
    /// ParseDelete and ResolverFindID hand AQuery.ID.ToString to
    /// TRESTObjectSet.Find, which reaches TDMLGeneratorAbstract.GetGeneratorWhere
    /// (anchored by METHOD) - and that method already dispatches: bare for
    /// Integer, Int64 and UInt64, QuotedStr for everything else. These clauses
    /// are regression guards over that dispatch, not repairs. They are green at
    /// the base commit and they say so.
    [Test]
    procedure ParseDelete_ATextualIdReachesOnlyItsOwnRow;
    [Test]
    procedure ParseDelete_AnIdCarryingAQuoteTravelsAsAValue;
    [Test]
    procedure ResolverFindID_ATextualIdReachesOnlyItsOwnRow;
  end;

implementation

uses
  DataEngine.FactoryFireDAC;

const
  cDBFILE = 'janus_server_resource_updatewhere.db';

  cDDL_TEXT  = 'CREATE TABLE IF NOT EXISTS kttext ('  +
               '  ktcode VARCHAR(60) PRIMARY KEY, kttag VARCHAR(60))';
  cDDL_NUM   = 'CREATE TABLE IF NOT EXISTS ktnum ('   +
               '  ktid INTEGER PRIMARY KEY, kttag VARCHAR(60))';
  cDDL_GUID  = 'CREATE TABLE IF NOT EXISTS ktguid ('  +
               '  ktuid VARCHAR(38) PRIMARY KEY, kttag VARCHAR(60))';
  cDDL_DATE  = 'CREATE TABLE IF NOT EXISTS ktdate ('  +
               '  ktday DATE PRIMARY KEY, kttag VARCHAR(60))';
  cDDL_FLOAT = 'CREATE TABLE IF NOT EXISTS ktfloat (' +
               '  ktnum NUMERIC(18,4) PRIMARY KEY, kttag VARCHAR(60))';
  cDDL_ALIAS = 'CREATE TABLE IF NOT EXISTS ktalias (' +
               '  kt_code VARCHAR(60) PRIMARY KEY, kttag VARCHAR(60))';
  cDDL_BOOL  = 'CREATE TABLE IF NOT EXISTS ktbool ('  +
               '  ktflag BOOLEAN PRIMARY KEY, kttag VARCHAR(60))';
  cDDL_NULL  = 'CREATE TABLE IF NOT EXISTS ktnull ('  +
               '  ktopt VARCHAR(60), kttag VARCHAR(60))';
  cDDL_BIG   = 'CREATE TABLE IF NOT EXISTS ktbig ('   +
               '  ktbig BIGINT PRIMARY KEY, kttag VARCHAR(60))';
  cDDL_UNS   = 'CREATE TABLE IF NOT EXISTS ktunsigned (' +
               '  ktu BIGINT PRIMARY KEY, kttag VARCHAR(60))';
  cDDL_DECOY = 'CREATE TABLE IF NOT EXISTS ktdecoy (' +
               '  ktdec VARCHAR(60), kttag VARCHAR(60))';
  cDDL_COMP  = 'CREATE TABLE IF NOT EXISTS ktcomp ('  +
               '  ktca VARCHAR(60), ktcb VARCHAR(60), kttag VARCHAR(60),' +
               '  PRIMARY KEY (ktca, ktcb))';

  /// The payload of the injection clauses. Chosen so that the OLD
  /// concatenation - '(kttext.ktcode=' + value + ')' - closes into
  ///   (kttext.ktcode=kttag) OR (kttext.ktcode='ABC')
  /// which SQLite accepts and which selects the row named ABC. A payload made
  /// of quotes alone would only produce a syntax error, and "it raised" is not
  /// the same finding as "it selected something else".
  cINJECTION = 'kttag) OR (kttext.ktcode=''ABC''';

{ TTestServerResourceUpdateWhere }

procedure TTestServerResourceUpdateWhere.SetupFixture;
var
  LCommands: TStringList;
begin
  if TFile.Exists(cDBFILE) then
    TFile.Delete(cDBFILE);
  FCommands := TStringList.Create;
  LCommands := FCommands;
  FDConnection := TFDConnection.Create(nil);
  FDConnection.Params.DriverID := 'SQLite';
  FDConnection.Params.Database := cDBFILE;
  FDConnection.Params.Values['OpenMode'] := 'CreateUTF8';
  FDConnection.ResourceOptions.SilentMode := True;
  FDConnection.Connected := True;
  /// The three-argument constructor takes a TMonitorProc, which
  /// TDMLCommandFactory._SendCommandMonitor calls for EVERY command it emits -
  /// including the SELECT that FindOne runs. That callback is the only way to
  /// read the statement the server actually built.
  FConnection := TFactoryFireDAC.Create(FDConnection, dnSQLite,
    TMonitorProc(
      procedure(const ACommand: TMonitorParam)
      var
        LFor: Integer;
        LLine: String;
      begin
        LLine := ACommand.Command;
        if ACommand.Params <> nil then
          for LFor := 0 to ACommand.Params.Count - 1 do
            LLine := LLine + ' [' + ACommand.Params[LFor].Name + '='
                     + VarToStr(ACommand.Params[LFor].Value) + ']';
        LCommands.Add(LLine);
      end));
  /// The entities are registered in the INITIALIZATION of
  /// Test.Janus.Model.KeyTypes, not here - see the note in that unit.
  FConnection.ExecuteDirect(cDDL_TEXT);
  FConnection.ExecuteDirect(cDDL_NUM);
  FConnection.ExecuteDirect(cDDL_GUID);
  FConnection.ExecuteDirect(cDDL_DATE);
  FConnection.ExecuteDirect(cDDL_FLOAT);
  FConnection.ExecuteDirect(cDDL_ALIAS);
  FConnection.ExecuteDirect(cDDL_BOOL);
  FConnection.ExecuteDirect(cDDL_NULL);
  FConnection.ExecuteDirect(cDDL_BIG);
  FConnection.ExecuteDirect(cDDL_UNS);
  FConnection.ExecuteDirect(cDDL_COMP);
  FConnection.ExecuteDirect(cDDL_DECOY);
end;

procedure TTestServerResourceUpdateWhere.TearDownFixture;
begin
  FConnection := nil;
  if Assigned(FDConnection) then
  begin
    FDConnection.Connected := False;
    FreeAndNil(FDConnection);
  end;
  FreeAndNil(FCommands);
  if TFile.Exists(cDBFILE) then
    TFile.Delete(cDBFILE);
end;

procedure TTestServerResourceUpdateWhere.Setup;
begin
  FConnection.ExecuteDirect('DELETE FROM kttext');
  FConnection.ExecuteDirect('DELETE FROM ktnum');
  FConnection.ExecuteDirect('DELETE FROM ktguid');
  FConnection.ExecuteDirect('DELETE FROM ktdate');
  FConnection.ExecuteDirect('DELETE FROM ktfloat');
  FConnection.ExecuteDirect('DELETE FROM ktalias');
  FConnection.ExecuteDirect('DELETE FROM ktbool');
  FConnection.ExecuteDirect('DELETE FROM ktnull');
  FConnection.ExecuteDirect('DELETE FROM ktbig');
  FConnection.ExecuteDirect('DELETE FROM ktunsigned');
  FConnection.ExecuteDirect('DELETE FROM ktcomp');
  FConnection.ExecuteDirect('DELETE FROM ktdecoy');
  FCommands.Clear;
end;

function TTestServerResourceUpdateWhere.InsertRaw(const AResource,
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

function TTestServerResourceUpdateWhere.UpdateRaw(const AResource,
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

function TTestServerResourceUpdateWhere.LastSelect(const ATable: String): String;
var
  LFor: Integer;
  LLine: String;
begin
  Result := '';
  for LFor := FCommands.Count - 1 downto 0 do
  begin
    LLine := FCommands[LFor];
    if not StartsText('SELECT', TrimLeft(LLine)) then
      Continue;
    if not ContainsText(LLine, ATable) then
      Continue;
    Exit(LLine);
  end;
  Assert.Fail('No SELECT against ' + ATable + ' was emitted. Captured: '
    + FCommands.Text);
end;

function TTestServerResourceUpdateWhere.ScalarStr(const ASQL: String): String;
var
  LValue: Variant;
begin
  LValue := FDConnection.ExecSQLScalar(ASQL);
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Result := ''
  else
    Result := VarToStr(LValue);
end;

function TTestServerResourceUpdateWhere.ScalarInt(const ASQL: String): Integer;
var
  LValue: Variant;
begin
  LValue := FDConnection.ExecSQLScalar(ASQL);
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Result := -1
  else
    Result := LValue;
end;

procedure TTestServerResourceUpdateWhere.TextualKey_ThePutMustReachTheRowItNames;
begin
  InsertRaw('KeyTypeText', '{"ktcode":"ABC","kttag":"before"}');
  UpdateRaw('KeyTypeText', '{"ktcode":"ABC","kttag":"after"}');
  Assert.AreEqual('after',
    ScalarStr('SELECT kttag FROM kttext WHERE ktcode = ''ABC'''),
    'The PUT did not reach the row its key names. A textual key pasted into '
    + 'the predicate unquoted is read by the database as a COLUMN NAME.');
end;

procedure TTestServerResourceUpdateWhere.TextualKey_ThePutMustLeaveTheOtherRowsAlone;
begin
  InsertRaw('KeyTypeText', '{"ktcode":"ABC","kttag":"before"}');
  InsertRaw('KeyTypeText', '{"ktcode":"DEF","kttag":"untouched"}');
  UpdateRaw('KeyTypeText', '{"ktcode":"ABC","kttag":"after"}');
  Assert.AreEqual('untouched',
    ScalarStr('SELECT kttag FROM kttext WHERE ktcode = ''DEF'''),
    'The PUT reached a row its key does not name.');
end;

procedure TTestServerResourceUpdateWhere.IntegerKey_TheKeyLiteralMustNotBeQuoted;
var
  LSQL: String;
begin
  InsertRaw('KeyTypeNum', '{"ktid":10,"kttag":"before"}');
  FCommands.Clear;
  UpdateRaw('KeyTypeNum', '{"ktid":10,"kttag":"after"}');
  LSQL := LastSelect('ktnum');
  Assert.IsTrue(ContainsText(LSQL, '(ktnum.ktid=10)'),
    'The integer key is no longer a bare numeric literal. The cheapest wrong '
    + 'repair is to quote EVERY value; SQLite converts ''10'' for an INTEGER '
    + 'column, so every row-level clause here stays green and only this one '
    + 'sees it. Statement was: ' + LSQL);
end;

procedure TTestServerResourceUpdateWhere.IntegerKey_ThePutMustStillReachItsRow;
begin
  InsertRaw('KeyTypeNum', '{"ktid":10,"kttag":"before"}');
  UpdateRaw('KeyTypeNum', '{"ktid":10,"kttag":"after"}');
  Assert.AreEqual('after', ScalarStr('SELECT kttag FROM ktnum WHERE ktid = 10'),
    'The integer key stopped locating its row. This is the case that worked '
    + 'before the repair and must keep working after it.');
end;

procedure TTestServerResourceUpdateWhere.TextualKeyCarryingAQuote_ThePutMustReachTheRowItNames;
begin
  /// The key is O'Brien. Wrapping it in quotes without doubling the embedded
  /// one yields 'O'Brien', which closes the literal at the apostrophe.
  InsertRaw('KeyTypeText', '{"ktcode":"O''Brien","kttag":"before"}');
  UpdateRaw('KeyTypeText', '{"ktcode":"O''Brien","kttag":"after"}');
  Assert.AreEqual('after',
    ScalarStr('SELECT kttag FROM kttext WHERE ktcode = ''O''''Brien'''),
    'A quote inside the key broke the statement. Quoting has to DOUBLE the '
    + 'embedded quote, which is what QuotedStr does and naive wrapping does not.');
end;

procedure TTestServerResourceUpdateWhere.AnInjectedPredicateMustTravelAsAValueAndNotAsStructure;
var
  LSQL: String;
begin
  InsertRaw('KeyTypeText', '{"ktcode":"ABC","kttag":"keep"}');
  FCommands.Clear;
  UpdateRaw('KeyTypeText',
    '{"ktcode":"' + cINJECTION + '","kttag":"pwned"}');
  LSQL := LastSelect('kttext');
  Assert.IsTrue(ContainsText(LSQL,
    '(kttext.ktcode=''kttag) OR (kttext.ktcode=''''ABC'''''')'),
    'The value the client sent is still SQL STRUCTURE in the statement the '
    + 'server built. It has to arrive as one quoted literal, embedded quotes '
    + 'doubled. Statement was: ' + LSQL);
end;

procedure TTestServerResourceUpdateWhere.AnInjectedPredicateMustNotReachTheRowItTargets;
begin
  InsertRaw('KeyTypeText', '{"ktcode":"ABC","kttag":"keep"}');
  UpdateRaw('KeyTypeText',
    '{"ktcode":"' + cINJECTION + '","kttag":"pwned"}');
  Assert.AreEqual('keep',
    ScalarStr('SELECT kttag FROM kttext WHERE ktcode = ''ABC'''),
    'A key value carrying a parenthesis and an OR selected a row it does not '
    + 'name.');
end;

procedure TTestServerResourceUpdateWhere.GuidShapedKey_ThePutMustReachTheRowItNames;
var
  LKey: String;
begin
  /// TGeneratorType.Guid38Inc: the SERVER makes the key on insert, in the
  /// braced hyphenated form. Every one of those characters is illegal in a
  /// bare SQL token.
  InsertRaw('KeyTypeGuid', '{"kttag":"before"}');
  LKey := ScalarStr('SELECT ktuid FROM ktguid');
  Assert.AreEqual(38, Length(LKey),
    'The seed did not write a braced GUID key. Got: ' + LKey);
  UpdateRaw('KeyTypeGuid', '{"ktuid":"' + LKey + '","kttag":"after"}');
  Assert.AreEqual('after',
    ScalarStr('SELECT kttag FROM ktguid WHERE ktuid = ' + QuotedStr(LKey)),
    'The PUT did not reach the row a generated GUID key names.');
end;

procedure TTestServerResourceUpdateWhere.DateKey_ThePutMustReachTheRowItNames;
begin
  FCommands.Clear;
  InsertRaw('KeyTypeDate', '{"ktday":"2026-03-17","kttag":"before"}');
  Assert.AreEqual(1, ScalarInt('SELECT COUNT(*) FROM ktdate'),
    'The seed did not write the date row.');
  UpdateRaw('KeyTypeDate', '{"ktday":"2026-03-17","kttag":"after"}');
  Assert.AreEqual('after', ScalarStr('SELECT kttag FROM ktdate'),
    'The PUT did not reach the row a date key names. The key the framework '
    + 'WROTE and the key the framework LOOKS UP have to agree. Stored key is ['
    + ScalarStr('SELECT ktday FROM ktdate') + ']. Commands: '
    + StringReplace(FCommands.Text, sLineBreak, ' ~ ', [rfReplaceAll]));
end;

procedure TTestServerResourceUpdateWhere.FractionalKey_ThePutMustReachTheRowItNames;
begin
  InsertRaw('KeyTypeFloat', '{"ktnum":10.5,"kttag":"before"}');
  Assert.AreEqual(1, ScalarInt('SELECT COUNT(*) FROM ktfloat'),
    'The seed did not write the fractional row.');
  UpdateRaw('KeyTypeFloat', '{"ktnum":10.5,"kttag":"after"}');
  Assert.AreEqual('after', ScalarStr('SELECT kttag FROM ktfloat'),
    'The PUT did not reach the row a fractional key names.');
end;

procedure TTestServerResourceUpdateWhere.FractionalKey_TheKeyLiteralMustCarryADecimalPoint;
var
  LSQL: String;
begin
  InsertRaw('KeyTypeFloat', '{"ktnum":10.5,"kttag":"before"}');
  FCommands.Clear;
  UpdateRaw('KeyTypeFloat', '{"ktnum":10.5,"kttag":"after"}');
  LSQL := LastSelect('ktfloat');
  Assert.IsTrue(ContainsText(LSQL, '(ktfloat.ktnum=10.5)'),
    'The fractional key is not a numeric literal with a DOT. On a machine '
    + 'whose ambient DecimalSeparator is a comma, VarToStr renders 10,5 and '
    + 'the comma is read as an argument separator. Statement was: ' + LSQL);
end;

procedure TTestServerResourceUpdateWhere.BigIntegerKey_TheKeyLiteralMustNotBeNarrowed;
begin
  InsertRaw('KeyTypeBig', '{"ktbig":9007199254740993,"kttag":"before"}');
  Assert.AreEqual('9007199254740993', ScalarStr('SELECT ktbig FROM ktbig'),
    'The seed did not write the 64-bit key verbatim, so nothing below is about '
    + 'the predicate.');
  FCommands.Clear;
  UpdateRaw('KeyTypeBig', '{"ktbig":9007199254740993,"kttag":"after"}');
  Assert.IsTrue(ContainsText(LastSelect('ktbig'), '(ktbig.ktbig=9007199254740993)'),
    'A 64-bit key was narrowed on its way into the predicate. Above '
    + 'High(Integer) and above 2^53, so both a 32-bit narrowing and a detour '
    + 'through Double are caught, and both would still be valid SQL. '
    + 'Statement was: ' + LastSelect('ktbig'));
end;

procedure TTestServerResourceUpdateWhere.UnsignedKeyAboveHighInt64_TheKeyLiteralMustNotFlipSign;
begin
  /// High(Int64) + 1. Reinterpreted as signed, this exact bit pattern is
  /// -9223372036854775808 - a valid SQL literal that names no row.
  InsertRaw('KeyTypeUnsigned',
    '{"ktu":9223372036854775808,"kttag":"before"}');
  Assert.AreEqual(1, ScalarInt('SELECT COUNT(*) FROM ktunsigned'),
    'The seed did not write the unsigned row.');
  FCommands.Clear;
  UpdateRaw('KeyTypeUnsigned',
    '{"ktu":9223372036854775808,"kttag":"after"}');
  Assert.IsTrue(ContainsText(LastSelect('ktunsigned'),
    '(ktunsigned.ktu=9223372036854775808)'),
    'An unsigned key above High(Int64) came into the predicate reinterpreted '
    + 'as a signed value. -9223372036854775808 is a perfectly valid SQL '
    + 'literal, so only a clause about the TEXT can see it. Statement was: '
    + LastSelect('ktunsigned'));
end;

procedure TTestServerResourceUpdateWhere.BooleanKey_ThePutMustReachTheRowItNames;
begin
  FCommands.Clear;
  InsertRaw('KeyTypeBool', '{"ktflag":true,"kttag":"before"}');
  /// The shape the framework's own INSERT leaves behind, read back through
  /// SQLite's own typeof(). It is what decides the literal the predicate needs.
  Assert.AreEqual('integer',
    ScalarStr('SELECT typeof(ktflag) FROM ktbool'),
    'The boolean key is no longer stored as an integer, so the integer literal '
    + 'the predicate uses is no longer the right one.');
  Assert.AreEqual(1, ScalarInt('SELECT COUNT(*) FROM ktbool'),
    'The seed did not write the boolean row.');
  UpdateRaw('KeyTypeBool', '{"ktflag":true,"kttag":"after"}');
  Assert.AreEqual('after', ScalarStr('SELECT kttag FROM ktbool'),
    'The PUT did not reach the row a boolean key names. Stored key is ['
    + ScalarStr('SELECT ktflag FROM ktbool') + ']. Commands: '
    + StringReplace(FCommands.Text, sLineBreak, ' ~ ', [rfReplaceAll]));
end;

procedure TTestServerResourceUpdateWhere.ThePredicateNamesTheColumn_NotTheProperty;
var
  LSQL: String;
begin
  /// TKeyTypeAlias maps the property `ktcode` onto the column `kt_code`, and
  /// it is the only entity in this project where the two differ.
  InsertRaw('KeyTypeAlias', '{"ktcode":"ABC","kttag":"before"}');
  FCommands.Clear;
  UpdateRaw('KeyTypeAlias', '{"ktcode":"ABC","kttag":"after"}');
  LSQL := LastSelect('ktalias');
  Assert.IsTrue(ContainsText(LSQL, '(ktalias.kt_code='''),
    'The predicate names the PROPERTY. SQL knows only the COLUMN. Statement '
    + 'was: ' + LSQL);
  Assert.AreEqual('after',
    ScalarStr('SELECT kttag FROM ktalias WHERE kt_code = ''ABC'''),
    'The PUT did not reach the aliased row.');
end;

procedure TTestServerResourceUpdateWhere.CompositeTextualKey_EveryKeyColumnStaysInThePredicate;
begin
  /// The two rows share their FIRST key column. A loop that stops after one
  /// turn reaches the wrong row, and every single-column clause above is blind
  /// to that.
  InsertRaw('KeyTypeComposite', '{"ktca":"A","ktcb":"1","kttag":"first"}');
  InsertRaw('KeyTypeComposite', '{"ktca":"A","ktcb":"2","kttag":"second"}');
  UpdateRaw('KeyTypeComposite', '{"ktca":"A","ktcb":"2","kttag":"after"}');
  Assert.AreEqual('after',
    ScalarStr('SELECT kttag FROM ktcomp WHERE ktca=''A'' AND ktcb=''2'''),
    'The PUT did not reach the composite row it names.');
  Assert.AreEqual('first',
    ScalarStr('SELECT kttag FROM ktcomp WHERE ktca=''A'' AND ktcb=''1'''),
    'The PUT reached the row that only shares the FIRST key column. The '
    + 'predicate has to carry EVERY key column.');
end;

procedure TTestServerResourceUpdateWhere.NullableKeyWithNoValue_MustNotReachAnyRow;
begin
  /// The caller sends no key at all and the property is Nullable, so nothing
  /// gives it a value. A key with no value identifies no row, and must not be
  /// allowed to identify an arbitrary one.
  InsertRaw('KeyTypeNullable', '{"ktopt":"K1","kttag":"keep"}');
  UpdateRaw('KeyTypeNullable', '{"kttag":"pwned"}');
  Assert.AreEqual('keep', ScalarStr('SELECT kttag FROM ktnull'),
    'A PUT whose key carries no value reached a row anyway.');
end;

procedure TTestServerResourceUpdateWhere.NullableKeyWithNoValue_ThePredicateMustBeUnsatisfiable;
var
  LSQL: String;
begin
  InsertRaw('KeyTypeNullable', '{"ktopt":"K1","kttag":"keep"}');
  FCommands.Clear;
  UpdateRaw('KeyTypeNullable', '{"kttag":"pwned"}');
  LSQL := LastSelect('ktnull');
  Assert.IsTrue(ContainsText(LSQL, '(1 = 0)'),
    'A key the request left undetermined has to produce the unsatisfiable '
    + 'predicate. Rendering it as a literal instead makes the empty string a '
    + 'KEY, and a row that carries one would be selected by a request that '
    + 'named no key at all. Statement was: ' + LSQL);
end;

procedure TTestServerResourceUpdateWhere.NullableShapedKeyWithNoValueField_ThePredicateMustBeUnsatisfiable;
var
  LSQL: String;
begin
  InsertRaw('KeyTypeDecoy', '{"kttag":"keep"}');
  FCommands.Clear;
  UpdateRaw('KeyTypeDecoy', '{"kttag":"pwned"}');
  LSQL := LastSelect('ktdecoy');
  Assert.IsTrue(ContainsText(LSQL, '(1 = 0)'),
    'An EMPTY Variant reached a branch that rendered it as a literal. '
    + 'VarIsNull is False for varEmpty, so only the VarIsEmpty half of the '
    + 'guard stands in front of this. Statement was: ' + LSQL);
end;

procedure TTestServerResourceUpdateWhere.NullableShapedKeyWithNoValueField_MustNotReachAnyRow;
begin
  InsertRaw('KeyTypeDecoy', '{"kttag":"keep"}');
  Assert.AreEqual(1, ScalarInt('SELECT COUNT(*) FROM ktdecoy'),
    'The seed did not write the decoy row.');
  UpdateRaw('KeyTypeDecoy', '{"kttag":"pwned"}');
  Assert.AreEqual('keep', ScalarStr('SELECT kttag FROM ktdecoy'),
    'A PUT whose key is an EMPTY Variant reached a row anyway. Dropping the '
    + 'VarIsEmpty half of the guard sends it to a branch that renders it as a '
    + 'literal, and an empty literal is something a row can match.');
end;

procedure TTestServerResourceUpdateWhere.AKeyThatMatchesNothing_LeavesEveryRowAlone;
begin
  InsertRaw('KeyTypeText', '{"ktcode":"ABC","kttag":"keep"}');
  UpdateRaw('KeyTypeText', '{"ktcode":"ZZZ","kttag":"pwned"}');
  Assert.AreEqual('keep',
    ScalarStr('SELECT kttag FROM kttext WHERE ktcode = ''ABC'''),
    'A PUT naming a key no row carries still modified a row. A predicate that '
    + 'is always true passes every other clause in this fixture.');
  Assert.AreEqual(1, ScalarInt('SELECT COUNT(*) FROM kttext'),
    'The PUT inserted a row instead of leaving the table alone.');
end;

function TTestServerResourceUpdateWhere.DeleteRaw(const AURI: String): String;
var
  LResource: TAppResourceBase;
  LQuery: TRESTQueryParse;
begin
  LResource := TAppResourceBase.Create(FConnection);
  try
    LQuery := TRESTQueryParse.Create;
    try
      LQuery.ParseQuery(AURI);
      Result := LResource.ParseDelete(LQuery);
    finally
      LQuery.Free;
    end;
  finally
    LResource.Free;
  end;
end;

function TTestServerResourceUpdateWhere.FindRaw(const AURI: String): String;
var
  LResource: TAppResourceBase;
  LQuery: TRESTQueryParse;
begin
  LResource := TAppResourceBase.Create(FConnection);
  try
    LQuery := TRESTQueryParse.Create;
    try
      LQuery.ParseQuery(AURI);
      Result := LResource.ParseFind(LQuery);
    finally
      LQuery.Free;
    end;
  finally
    LResource.Free;
  end;
end;

procedure TTestServerResourceUpdateWhere.ParseDelete_ATextualIdReachesOnlyItsOwnRow;
begin
  InsertRaw('KeyTypeText', '{"ktcode":"ABC","kttag":"gone"}');
  InsertRaw('KeyTypeText', '{"ktcode":"DEF","kttag":"stays"}');
  DeleteRaw('KeyTypeText(ABC)');
  Assert.AreEqual(0, ScalarInt('SELECT COUNT(*) FROM kttext WHERE ktcode = ''ABC'''),
    'DELETE by a textual ID did not reach its row.');
  Assert.AreEqual(1, ScalarInt('SELECT COUNT(*) FROM kttext WHERE ktcode = ''DEF'''),
    'DELETE by a textual ID reached a row it does not name.');
end;

procedure TTestServerResourceUpdateWhere.ParseDelete_AnIdCarryingAQuoteTravelsAsAValue;
begin
  InsertRaw('KeyTypeText', '{"ktcode":"O''Brien","kttag":"gone"}');
  InsertRaw('KeyTypeText', '{"ktcode":"DEF","kttag":"stays"}');
  DeleteRaw('KeyTypeText(O''Brien)');
  Assert.AreEqual(0,
    ScalarInt('SELECT COUNT(*) FROM kttext WHERE ktcode = ''O''''Brien'''),
    'DELETE by an ID carrying a quote did not reach its row.');
  Assert.AreEqual(1, ScalarInt('SELECT COUNT(*) FROM kttext WHERE ktcode = ''DEF'''),
    'DELETE by an ID carrying a quote reached a row it does not name.');
end;

procedure TTestServerResourceUpdateWhere.ResolverFindID_ATextualIdReachesOnlyItsOwnRow;
var
  LBody: String;
begin
  InsertRaw('KeyTypeText', '{"ktcode":"ABC","kttag":"mine"}');
  InsertRaw('KeyTypeText', '{"ktcode":"DEF","kttag":"theirs"}');
  LBody := FindRaw('KeyTypeText(ABC)');
  Assert.IsTrue(ContainsText(LBody, 'mine'),
    'GET by a textual ID did not return its row. Body was: ' + LBody);
  Assert.IsFalse(ContainsText(LBody, 'theirs'),
    'GET by a textual ID returned a row it does not name. Body was: ' + LBody);
end;

procedure TTestServerResourceUpdateWhere.TheUpdateResponseNamesTheResource;
var
  LRaw: String;
begin
  InsertRaw('KeyTypeText', '{"ktcode":"ABC","kttag":"before"}');
  LRaw := UpdateRaw('KeyTypeText', '{"ktcode":"ABC","kttag":"after"}');
  Assert.AreEqual(
    '{"result":"Resource TKeyTypeText update command executed successfully"}',
    LRaw, 'The update response body changed.');
end;

initialization
  /// Explicit registration: DUnitX's RTTI discovery does not find a fixture
  /// this project never names.
  TDUnitX.RegisterTestFixture(TTestServerResourceUpdateWhere);

end.
