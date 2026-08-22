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

{ @abstract(Janus Framework - the predicate TDMLGeneratorAbstract.GetGeneratorWhere
  builds from a single AID. Issue #326.)

  ONE METHOD, TWO SEPARATE QUESTIONS, AND ONLY ONE OF THEM IS THIS COMMIT'S.

  THE ONE THAT IS: A DATE KEY USED TO LEAVE IN THE MACHINE'S LOCALE. The else
  arm spelled every non-integer AID as QuotedStr(AID.ToString), and for a TValue
  holding a TDateTime that goes through DateTimeToStr, which reads the GLOBAL
  FormatSettings. Two things were wrong with it at once: the text depended on
  the machine, and it was never the DIALECT's date literal even on a default
  machine. The dialect's own answer already existed one method away -
  TDMLGeneratorAbstract._GetPropertyValue formats every ftDate / ftDateTime
  column as FormatDateTime(FDateFormat, ..., FFormatSettings) - so this is not
  a new decision about what a date key should look like. The comment that used
  to sit on that arm said fixing it "exige decidir qual formato uma PK de data
  deve ter por dialeto"; that decision was already taken and is FDateFormat.

  THE ONE THAT WAS NOT, AND NOW IS: THE COMPOSITE KEY. The loop over the
  primary key columns carried `if LFor > 0 then Continue`, so from the second
  column on the key was DISCARDED and the predicate named only the first
  column - and the loop body did not even contain the ' AND ' a second term
  would need. It was functionality never finished, not a decision.

  WHAT THE REPAIR COSTS, DECLARED RATHER THAN GLOSSED. The generator itself
  needed no wider signature - the values ride inside the TValue it already
  took. But reaching it from consumer code added a MEMBER TO TWO PUBLISHED
  INTERFACES: Find(TArray<TValue>) on IContainerObjectSet<M>, and
  Find(TArray<TValue>) plus Open(TArray<TValue>) on IContainerDataSet<M>. That
  breaks a third-party implementer exactly as widening IDMLGeneratorCommand
  would have - the objection that ruled out the old design applies here too,
  one layer out. Inside this repository each interface has exactly ONE
  implementer, both enumerated and both updated; outside it, NOT MEASURED.

  IT IS REPAIRED, AND THE SHAPE OF THE REPAIR IS WHY NOTHING BELOW HAD TO DIE.
  The mechanism is the one this header already named as possible: a TValue
  holds a TArray<TValue> perfectly well. The predicate is now driven by how
  many values the CALLER SUPPLIES rather than by how many columns the key has,
  so a scalar aid still produces the single-column predicate it always did and
  every existing consumer is untouched. That matters because where the first
  key column happens to be UNIQUE the old behaviour was CORRECT - refusing a
  composite key, or answering the zero-rows guard, would have broken code that
  works today. The three original composite clauses therefore stay GREEN and
  keep documenting the scalar path; the new ones hand one value per column.

  THE PREDICATE ITSELF IS PINNED, AND AN EARLIER VERSION OF THIS FIXTURE
  REFUSED TO PIN IT. That refusal was argued as "a test that has to die for a
  fix to land is a tax on the fix" - and this same file KEEPS
  DateKey_Firebird_TakesTheSQLiteMaskBecauseTheSelecterSwapsIt, a clause with
  exactly that shape, saying "whoever undoes the swap will see this clause go
  red, which is the point of it". Two opposite postures on one form, a hundred
  lines apart. The posture chosen for BOTH is the second one: a clause that
  goes red when someone changes the thing it describes is doing its job, and
  the alternative left the CENTRAL claim of this issue with nothing behind it -
  the Find and Open clauses run against a double that answers the same rows
  whatever SQL it is handed, so they pin properties of Find and Open and say
  nothing about what GetGeneratorWhere emitted.

  AND THE CONSEQUENCE IS NOT ONE ANSWER BUT TWO, which is why there are two
  clauses and not one. Find demands RecordCount = 1 and answers nil: a false
  NEGATIVE. Open has no such guard - _PopularDataSet Appends every row it walks
  - so it hands the consumer BOTH rows, which is the issue's original wording
  literally. An earlier version of this header carried the first half as an
  unqualified sentence.

  THE MUTATIONS THAT WERE RUN, AND WHAT DIED IN EACH. Applied to
  Janus.DML.Generator.pas with a MESSAGE WARN directive dcc32 echoed as W1054
  in the same build. ALL SEVEN WERE RE-RUN on the tree that carries this table,
  whose green state is 620/0/0 - re-run and not re-labelled, which is the
  correction this table exists to carry:

    d1  the whole date arm short-circuited with `False and`     -> 6 red
    d2b FFormatSettings replaced by the GLOBAL FormatSettings   -> 2 red
    d3  a TTime key given FDateFormat instead of FTimeFormat    -> 1 red
    d4  the TDateTime term of the guard dropped                 -> 4 red
    d5  FDateFormat replaced by a hard-coded 'yyyy-MM-dd'       -> 2 red
    d6  the TDate term of the guard dropped                     -> 1 red
    d7  FFormatSettings replaced by TFormatSettings.Create('en-US') -> 0 red

  THREE OF THOSE COUNTS USED TO BE WRONG, AND THE WAY THEY WENT WRONG IS THE
  POINT. d1, d2b and d5 were first measured against a 617-clause tree, then
  the commit that added TDateKey_UsesTheDialectDateMask made each of them kill
  one more - and the table was re-stamped "618" without re-running. Each was
  short by exactly the one clause that commit added. A total re-labelled
  instead of re-measured is a number from a tree that never existed, and the
  commit that "anchored" these figures shipped the defect it was written to
  remove.

  d6 is why TDateKey_UsesTheDialectDateMask exists: without it that term had
  nothing to kill.

  d7 IS THE ONE SURVIVOR AND IT IS DECLARED. It is not evidence that the
  argument is dead code - d2b, which puts the GLOBAL settings there, kills two
  clauses - it is evidence that en-US happens to spell '/' and ':' the way the
  dialect masks do. Killing it would need a clause that runs under a THIRD
  named locale, which measures the RTL's locale table rather than this unit.
}

unit Test.Janus.DML.KeyPredicate;

interface

uses
  DB,
  Rtti,
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
  DataEngine.FactoryInterfaces,
  MetaDbDiff.Mapping.Attributes,
  MetaDbDiff.Mapping.Register,
  MetaDbDiff.Types.Mapping,
  Janus.Command.Selecter,
  Janus.Container.ObjectSet,
  Janus.Container.FDMemTable,
  Janus.Container.DataSet.Interfaces,
  Janus.Container.ObjectSet.Interfaces,
  Janus.DML.Generator,
  Janus.DML.Generator.SQLite,
  Janus.DML.Generator.Firebird,
  Janus.DML.Generator.MSSQL,
  Test.Janus.Model.KeyOnly,
  Test.Janus.Cursor.Double;

type
  /// A DATE primary key. TKeyTypeDate has the same shape but lives in a Common
  /// unit that Janus.Tests.Units does not link, and pulling it in would
  /// register a dozen entities this fixture does not use.
  [Entity]
  [Table('dkday', '')]
  [PrimaryKey('dkkey', TAutoIncType.NotInc, TGeneratorType.NoneInc,
              TSortingOrder.NoSort, True, 'Date primary key')]
  TDateKeyRow = class
  private
    Fdkkey: TDateTime;
    Fdktag: String;
  public
    [Column('dkkey', ftDate)]
    property dkkey: TDateTime read Fdkkey write Fdkkey;
    [Column('dktag', ftString, 20)]
    property dktag: String read Fdktag write Fdktag;
  end;

  /// A PRIMARY KEY THAT MAPS NO COLUMNS. MetaDbDiff's PrimaryKey.Create wraps
  /// the whole column-parsing block in `if Length(AColumns) > 0`, so an empty
  /// string leaves FColumns empty and Columns.Count is 0 while the mapping
  /// itself is NOT nil. Issue #326.
  [Entity]
  [Table('nokeycols', '')]
  [PrimaryKey('', TAutoIncType.NotInc, TGeneratorType.NoneInc,
              TSortingOrder.NoSort, True, 'no columns at all')]
  TNoKeyColsRow = class
  private
    Fnk_id: Integer;
  public
    [Column('nk_id', ftInteger)]
    property nk_id: Integer read Fnk_id write Fnk_id;
  end;

  /// ISSUE #361 - A CLASS THAT MAPS NO PRIMARY KEY AT ALL. Its neighbour
  /// TNoKeyColsRow declares a [PrimaryKey] whose column string is empty, which
  /// yields a mapping that is NOT nil; this one declares none, so
  /// TMappingExplorer.GetMappingPrimaryKey answers nil and the shape falls
  /// outside both #326 guards. It is a legal entity - nothing in the mapping
  /// layer requires a key - and reading it as a collection is still fine; only
  /// asking it for ONE row by id is refused.
  [Entity]
  [Table('nokeyatall', '')]
  TNoPrimaryKeyRow = class
  private
    Fnp_id: Integer;
    Fnp_tag: String;
  public
    [Column('np_id', ftInteger)]
    property np_id: Integer read Fnp_id write Fnp_id;
    [Column('np_tag', ftString, 20)]
    property np_tag: String read Fnp_tag write Fnp_tag;
  end;

  [TestFixture]
  TTestDMLKeyPredicate = class
  private
    FConnection: IDBConnection;
    FDateSaved: Char;
    FTimeSaved: Char;
    FShortDateSaved: String;
    function SelectIdSql(const ADriver: TDriverName;
      const AClass: TClass; const AID: TValue): String;
    /// The WHERE clause TKeyOnly's composite key produces from N values.
    function CompositeWhere(const AIDs: TArray<TValue>): String;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // ---- the date key: what this commit repairs -------------------------
    /// The literal must be the DIALECT's, and SQLite's FDateFormat is
    /// 'yyyy-MM-dd'. Before the repair this was the machine's DateTimeToStr.
    [Test]
    procedure DateKey_SQLite_UsesTheDialectMask;
    /// FIREBIRD DOES NOT GET FIREBIRD'S MASK, AND THIS BRANCH DID NOT DISCOVER
    /// THAT. TDMLGeneratorFirebird sets FDateFormat to 'MM/dd/yyyy', but
    /// TCommandSelecter.Create swaps dnFirebird and dnFirebird3 for dnSQLite,
    /// so every Firebird SELECT runs the SQLite generator. THE FACT WAS ALREADY
    /// WRITTEN DOWN before this frontier existed, in the doc comments over
    /// TDMLGeneratorFirebird.GuidLiteral and TDMLGeneratorFirebird3.GuidLiteral,
    /// which both name Janus.Command.Selecter as the place that does the swap.
    /// What is new here is only the CLAUSE: an earlier version of it expected
    /// '03/15/2027', went red, and is kept inverted so the swap is measured in
    /// CI instead of living only in prose. Reading a comment is not a finding.
    [Test]
    procedure DateKey_Firebird_TakesTheSQLiteMaskBecauseTheSelecterSwapsIt;
    /// AND THE SECOND MASK THAT IS ACTUALLY REACHABLE. MSSQL is 'dd/MM/yyyy'
    /// against SQLite's 'yyyy-MM-dd', and this pair is what tells a real
    /// per-dialect lookup from a hard-coded ISO literal: a repair that always
    /// emitted ISO would pass the SQLite clause and fail this one.
    [Test]
    procedure DateKey_MSSQL_UsesItsOwnMask;
    /// The locale must not reach the literal. DateSeparator is forced to '.'
    /// and TimeSeparator to '-', which is what turned the old AID.ToString
    /// into '15.03.2027 14-07-53'.
    [Test]
    procedure DateKey_UnderAHostileLocale_IsUnchanged;
    /// A TIME key takes FTimeFormat, which is the other half of the same
    /// decision _GetPropertyValue already took.
    [Test]
    procedure TimeKey_UsesTheDialectTimeMask;
    /// AND TDate, WHICH IS A TYPE OF ITS OWN. System declares TDate and TTime
    /// as `type TDateTime`, so all three carry DISTINCT PTypeInfo and a guard
    /// that names only TDateTime lets the other two through. This clause exists
    /// because the mutation that drops the TDate term had to have something to
    /// kill.
    [Test]
    procedure TDateKey_UsesTheDialectDateMask;
    /// The arm this repair must NOT disturb: a plain string key stays quoted
    /// and untouched, and an integer key stays bare.
    [Test]
    procedure StringKey_IsStillQuotedAndUnchanged;
    [Test]
    procedure IntegerKey_IsStillBareDigits;

    // ---- the composite key: measured, NOT repaired ----------------------
    /// THE PREDICATE ITSELF, which is the claim #326 is actually about.
    /// TKeyOnly's key is 'k1;k2' and the WHERE names only k1. Until this
    /// clause existed NOTHING in any suite held that claim down: the three
    /// clauses below drive Find and Open over a double that answers the same
    /// rows whatever SQL it is handed, so they pin properties of THOSE
    /// methods and say nothing about what GetGeneratorWhere emitted.
    [Test]
    procedure CompositeKey_TheWhereNamesOnlyTheFirstColumn;
    /// THE CONSEQUENCE ON THE Find CHAIN. Ask for one ID over a cursor that
    /// carries TWO rows - which is what a predicate naming only the first
    /// column returns when that column is not unique - and Find answers nil.
    /// The row is in the store and the consumer is told it is not there.
    [Test]
    procedure CompositeKey_FindOverMoreThanOneMatchingRow_AnswersNil;
    /// The control, so the clause above cannot be green because Find always
    /// answers nil: with ONE row it answers the object.
    [Test]
    procedure CompositeKey_FindOverExactlyOneRow_AnswersTheObject;
    /// THE OTHER CHAIN, AND IT GIVES THE OPPOSITE ANSWER.
    /// TSessionDataSet&lt;M&gt;._PopularDataSet Appends every row it walks and
    /// nothing on that path counts them, so Open over a composite key whose
    /// first column repeats loads MORE THAN ONE ROW into the consumer's
    /// dataset. On this chain the issue's original wording - "casam mais de
    /// uma linha" - is literally what happens.
    [Test]
    procedure CompositeKey_OpenIdLoadsEveryMatchingRow;

    // ---- the composite key: NOW REPAIRED, issue #326 --------------------
    /// THE REPAIR. Hand one value per key column - a TValue carrying a
    /// TArray<TValue>, which is what the header of GetGeneratorWhere said all
    /// along was possible - and the predicate names EVERY column, joined with
    /// the ' AND ' the old loop body did not even contain.
    [Test]
    procedure CompositeKey_OneValuePerColumn_NamesEveryColumnJoinedByAnd;
    /// EACH TERM KEEPS ITS OWN LITERAL FORM. The values are rendered one by
    /// one, so a composite key of mixed types spells each half the way a
    /// scalar of that type has always been spelled: the ordinal bare, the
    /// string quoted. A repair that stringified the whole array would pass
    /// the clause above and fail this one.
    [Test]
    procedure CompositeKey_MixedTypes_EachTermKeepsItsOwnLiteralForm;
    /// FEWER VALUES THAN COLUMNS NAMES ONLY WHAT IT WAS GIVEN, and this is
    /// the clause that pins the design decision rather than an accident: the
    /// loop is driven by the VALUES supplied, not by the columns the key has.
    /// A one-element array must give exactly the one-column predicate the
    /// scalar path gives - otherwise the repair would have to guess.
    [Test]
    procedure CompositeKey_FewerValuesThanColumns_NamesOnlyWhatItWasGiven;
    /// AND THE CONSUMER'S OWN ENTRY POINT, not the generator through a
    /// helper. The three clauses above ask TCommandSelecter directly; this
    /// one goes through IContainerObjectSet<M>.Find, which is what a user
    /// holds, and proves the array survives every layer between them -
    /// TObjectSetAdapter, TSessionAbstract and TSQLCommandExecutor - without
    /// any of them having needed a wider signature.
    [Test]
    procedure CompositeKey_ThroughTheContainerFind_ReachesTheFullPredicate;
    /// The Open chain has its own entry point and its own consequence - the
    /// one with no RecordCount guard - so it gets its own clause.
    [Test]
    procedure CompositeKey_ThroughTheContainerOpen_ReachesTheFullPredicate;
    /// THE HOLE THE ENTRY POINT OPENED, AND IT IS THE WORST SHAPE IN THIS
    /// ISSUE. An EMPTY array is an id that names nothing, and before the
    /// guard the generator answered `SELECT keyonly.k1, keyonly.k2 FROM
    /// keyonly` - no WHERE at all. Measured through the public entry point
    /// this branch created.
    [Test]
    procedure EmptyValueArray_IsRefusedInsteadOfMatchingEveryRow;
    /// AND THE SAME THING ON THE Open CHAIN, WHERE IT IS WORSE. Open has no
    /// RecordCount guard to mask it, so `Open([])` did not answer nil - it
    /// LOADED THE WHOLE TABLE into the consumer's dataset. Measured: two
    /// rows seeded, two rows loaded, for a question about one id.
    [Test]
    procedure EmptyValueArray_OnTheOpenChain_IsRefusedNotAWholeTableRead;
    /// MORE VALUES THAN THE KEY HAS COLUMNS. Three values against k1;k2
    /// emitted `WHERE keyonly.k1 = 1 AND keyonly.k2 = 2` and dropped the
    /// third in silence - which is the same class of defect as the
    /// `if LFor > 0 then Continue` this issue removed, so it is refused.
    [Test]
    procedure MoreValuesThanColumns_IsRefusedInsteadOfDiscardingThem;
    /// THE REGRESSION THIS BRANCH INTRODUCED, PAID BACK. A primary key that
    /// maps NO columns is constructible - MetaDbDiff's PrimaryKey.Create
    /// wraps its parsing in `if Length(AColumns) > 0` - and an earlier
    /// version of this fixture declared the shape uncoverable. It is not.
    /// Before the composite repair it produced a dangling ' WHERE ' that a
    /// database rejects loudly; moving the keyword after the loop made it a
    /// SILENT full-table read. Now it refuses.
    [Test]
    procedure PrimaryKeyWithNoColumns_IsRefusedNotAWholeTableRead;
    /// ISSUE #361 - THE THIRD MOUTH OF THE SAME HOLE, AND THE ONE #326 LEFT
    /// OPEN. The two clauses above both reach their guard from INSIDE the
    /// `if LPrimaryKey <> nil` arm. A class that maps no [PrimaryKey] AT ALL
    /// never enters that arm: GetGeneratorWhere fell out with the predicate
    /// still empty and the caller ran its SELECT or DELETE over the whole
    /// table for a question about one id. Measured by mutation: with the
    /// refusal disabled and the compiler echoing the tripwire, this is the
    /// ONLY clause in Units or RESTHorse that dies.
    [Test]
    procedure IdAgainstAClassWithNoPrimaryKeyMapping_IsRefusedNotAWholeTableRead;
    /// ISSUE #361 - THE INVERSION THE REPAIR INTRODUCED, PINNED SO IT CANNOT
    /// DRIFT BACK IN SILENCE. A TYPELESS TValue now means "every row", and
    /// that is deliberate: it is the out-of-band spelling of "no id" that
    /// replaced -1. It is also a REVERSAL - on 0103408 a typeless TValue was
    /// REFUSED by the #326 empty-values guard, because TValue.IsType<T>
    /// answers True for a typeless value and _KeyValues therefore handed back
    /// an EMPTY array. Measured base x HEAD through this very helper.
    [Test]
    procedure TypelessTValue_MeansEveryRow_AndThatIsDeliberate;
    /// ...and the shapes that only LOOK typeless must NOT mean "everything".
    /// TValue.IsEmpty is True for an empty dynamic array and for an empty
    /// string as well, which is exactly why the test is TypeInfo = nil.
    [Test]
    procedure ShapesThatOnlyLookTypeless_DoNotMeanEveryRow;
  end;

implementation

const
  cSTAMP_Y = 2027;
  cSTAMP_M = 3;
  cSTAMP_D = 15;

function Stamp: TDateTime;
begin
  Result := EncodeDate(cSTAMP_Y, cSTAMP_M, cSTAMP_D) + EncodeTime(14, 7, 53, 0);
end;

{ TTestDMLKeyPredicate }

procedure TTestDMLKeyPredicate.Setup;
begin
  FConnection := TRowsConnection.Create(dnSQLite, 1,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add('k1', ftInteger);
      ADataSet.FieldDefs.Add('k2', ftInteger);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName('k1').AsInteger := 1;
      ADataSet.FieldByName('k2').AsInteger := AIndex;
    end,
    'keypredicate');
  FDateSaved := FormatSettings.DateSeparator;
  FTimeSaved := FormatSettings.TimeSeparator;
  FShortDateSaved := FormatSettings.ShortDateFormat;
end;

procedure TTestDMLKeyPredicate.TearDown;
begin
  FormatSettings.DateSeparator := FDateSaved;
  FormatSettings.TimeSeparator := FTimeSaved;
  FormatSettings.ShortDateFormat := FShortDateSaved;
  FConnection := nil;
end;

function TTestDMLKeyPredicate.SelectIdSql(const ADriver: TDriverName;
  const AClass: TClass; const AID: TValue): String;
var
  LSelecter: TCommandSelecter;
  LObject: TObject;
  LConn: IDBConnection;
begin
  // THE DRIVER HAS TO BE ON THE CONNECTION AND NOT ONLY ON THE SELECTER, and
  // that is measured: asking TCommandSelecter for dnFirebird over a connection
  // built with dnSQLite answered SQLite's own mask ('2027-03-15' where
  // '03/15/2027' was expected), so the ADriver argument alone does not decide
  // which generator formats the literal.
  LConn := TRowsConnection.Create(ADriver, 1,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add('dkkey', ftDate);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName('dkkey').AsDateTime := Stamp;
    end,
    'keypredicate-sql');
  LObject := AClass.Create;
  try
    LSelecter := TCommandSelecter.Create(LConn, ADriver, LObject);
    try
      Result := LSelecter.GenerateSelectID(AClass, AID);
    finally
      LSelecter.Free;
    end;
  finally
    LObject.Free;
  end;
end;

procedure TTestDMLKeyPredicate.DateKey_SQLite_UsesTheDialectMask;
var
  LSQL: String;
begin
  LSQL := SelectIdSql(dnSQLite, TDateKeyRow, TValue.From<TDateTime>(Stamp));
  Assert.Contains(LSQL, '''2027-03-15''', True,
    'SQLite FDateFormat is yyyy-MM-dd, and that is the literal a date key ' +
    'must carry: ' + LSQL);
end;

procedure TTestDMLKeyPredicate.DateKey_Firebird_TakesTheSQLiteMaskBecauseTheSelecterSwapsIt;
var
  LSQL: String;
begin
  LSQL := SelectIdSql(dnFirebird, TDateKeyRow, TValue.From<TDateTime>(Stamp));
  Assert.Contains(LSQL, '''2027-03-15''', True,
    'TCommandSelecter.Create swaps dnFirebird for dnSQLite, so a Firebird ' +
    'SELECT runs the SQLite generator and its date key carries SQLite''s ' +
    'mask. Measured, not intended, and NOT changed here: ' + LSQL);
  Assert.DoesNotContain(LSQL, '''03/15/2027''', True,
    'TDMLGeneratorFirebird.FDateFormat is MM/dd/yyyy and it does NOT reach ' +
    'the SELECT - whoever undoes the swap will see this clause go red, which ' +
    'is the point of it: ' + LSQL);
end;

procedure TTestDMLKeyPredicate.DateKey_MSSQL_UsesItsOwnMask;
var
  LSQL: String;
begin
  LSQL := SelectIdSql(dnMSSQL, TDateKeyRow, TValue.From<TDateTime>(Stamp));
  Assert.Contains(LSQL, '''15/03/2027''', True,
    'MSSQL FDateFormat is dd/MM/yyyy - same characters as Firebird in the ' +
    'other order, which is the pair a coin toss cannot pass: ' + LSQL);
end;

procedure TTestDMLKeyPredicate.DateKey_UnderAHostileLocale_IsUnchanged;
var
  LSQL: String;
begin
  FormatSettings.DateSeparator := '.';
  FormatSettings.TimeSeparator := '-';
  FormatSettings.ShortDateFormat := 'dd.mm.yyyy';
  LSQL := SelectIdSql(dnSQLite, TDateKeyRow, TValue.From<TDateTime>(Stamp));
  Assert.Contains(LSQL, '''2027-03-15''', True,
    'the ambient locale must not reach the literal: ' + LSQL);
  Assert.DoesNotContain(LSQL, '15.03.2027', True,
    'and the old AID.ToString rendering must be gone entirely: ' + LSQL);
end;

procedure TTestDMLKeyPredicate.TimeKey_UsesTheDialectTimeMask;
var
  LSQL: String;
begin
  FormatSettings.TimeSeparator := '-';
  LSQL := SelectIdSql(dnSQLite, TDateKeyRow, TValue.From<TTime>(Stamp));
  // FTimeFormat is 'HH:MM:SS' on every dialect here. AN EARLIER VERSION OF THIS
  // CLAUSE EXPECTED '14:03:53' on the reading that 'MM' in a FormatDateTime
  // mask is always the MONTH; the run answered '14:07:53' and falsified it.
  // Delphi's rule is narrower than that: an m or mm that IMMEDIATELY FOLLOWS an
  // h or hh specifier is the MINUTE. So the house's mask means what it looks
  // like it means, and the correction is recorded rather than quietly applied.
  Assert.Contains(LSQL, '''14:07:53''', True,
    'a time key must take FTimeFormat through FFormatSettings, so the ' +
    'ambient TimeSeparator cannot move it: ' + LSQL);
end;

procedure TTestDMLKeyPredicate.TDateKey_UsesTheDialectDateMask;
var
  LSQL: String;
begin
  FormatSettings.DateSeparator := '.';
  LSQL := SelectIdSql(dnMSSQL, TDateKeyRow, TValue.From<TDate>(Stamp));
  Assert.Contains(LSQL, '''15/03/2027''', True,
    'a TDate AID is a distinct type info from TDateTime and must take the ' +
    'same dialect mask: ' + LSQL);
end;

procedure TTestDMLKeyPredicate.StringKey_IsStillQuotedAndUnchanged;
var
  LSQL: String;
begin
  LSQL := SelectIdSql(dnSQLite, TDateKeyRow, TValue.From<String>('A-1'));
  Assert.Contains(LSQL, '''A-1''', True,
    'a string AID keeps the arm it always had: ' + LSQL);
end;

procedure TTestDMLKeyPredicate.IntegerKey_IsStillBareDigits;
var
  LSQL: String;
begin
  LSQL := SelectIdSql(dnSQLite, TDateKeyRow, TValue.From<Integer>(10));
  Assert.Contains(LSQL, 'dkkey = 10', True,
    'an integer AID stays bare: ' + LSQL);
end;

procedure TTestDMLKeyPredicate.CompositeKey_TheWhereNamesOnlyTheFirstColumn;
var
  LSQL: String;
  LWhere: String;
  LPos: Integer;
begin
  LSQL := SelectIdSql(dnSQLite, TKeyOnly, TValue.From<Int64>(1));
  // ONLY THE PREDICATE, and the tail has to be cut out rather than asserted
  // over the whole statement: the SELECT LIST names every mapped column, so
  // `k2` appears in the statement whatever the WHERE says. Measured - the
  // first version of this clause asserted over the whole string and went red
  // against `SELECT keyonly.k1, keyonly.k2 FROM keyonly WHERE keyonly.k1 = 1`,
  // which is the very output it was written to accept.
  LPos := Pos(' WHERE ', UpperCase(LSQL));
  Assert.IsTrue(LPos > 0, 'premise: the statement carries a WHERE: ' + LSQL);
  LWhere := Copy(LSQL, LPos, Length(LSQL));
  Assert.Contains(LWhere, 'keyonly.k1 = 1', True,
    'premise: the predicate names the FIRST key column: ' + LWhere);
  Assert.DoesNotContain(LWhere, 'keyonly.k2', True,
    'ISSUE #326 IS REPAIRED AND THIS CLAUSE IS STILL GREEN, WHICH IS THE ' +
    'SHAPE OF THE REPAIR. An earlier version of it predicted it would be ' +
    '"deliberately DELETED-OR-INVERTED by whoever repairs it"; that ' +
    'prediction was WRONG. The predicate is driven by how many values the ' +
    'caller SUPPLIES, not by how many columns the key has, so a scalar aid ' +
    'still names the first column alone - byte for byte what it always did. ' +
    'That is exactly what keeps the repair from breaking consumers whose ' +
    'first key column IS unique, for whom the old behaviour was CORRECT. ' +
    'The composite answer is measured by the clauses that hand one value ' +
    'per column. Emitted here: ' + LWhere);
end;

procedure TTestDMLKeyPredicate.CompositeKey_OpenIdLoadsEveryMatchingRow;
var
  LTable: TFDMemTable;
  LContainer: IContainerDataSet<TKeyOnly>;
begin
  // TWO rows, the same premise as the Find clause: it is what a predicate
  // naming only k1 returns when k1 is not unique.
  FConnection := TRowsConnection.Create(dnSQLite, 2,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add('k1', ftInteger);
      ADataSet.FieldDefs.Add('k2', ftInteger);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName('k1').AsInteger := 1;
      ADataSet.FieldByName('k2').AsInteger := AIndex;
    end,
    'keypredicate-openid');
  LTable := TFDMemTable.Create(nil);
  try
    LContainer := TContainerFDMemTable<TKeyOnly>.Create(FConnection, LTable);
    LContainer.Open(Integer(1));
    Assert.AreEqual(2, LTable.RecordCount,
      'THE OTHER HALF OF #326, and it is NOT the false negative the Find ' +
      'chain gives: _PopularDataSet Appends every row the cursor walks and ' +
      'nothing counts them, so asking for ONE id over a composite key whose ' +
      'first column repeats hands the consumer BOTH rows. This is the ' +
      'issue''s original wording, literally.');
    LContainer := nil;
  finally
    LTable.Free;
  end;
end;

procedure TTestDMLKeyPredicate.CompositeKey_FindOverMoreThanOneMatchingRow_AnswersNil;
var
  LSet: IContainerObjectSet<TKeyOnly>;
  LFound: TKeyOnly;
begin
  // TWO rows come back, which is what a predicate naming only k1 returns when
  // k1 is not unique - and TKeyOnly's key is 'k1;k2', so k1 alone is not.
  // The question is asked through the CONSUMER's own entry point, not through
  // the executor: TSQLCommandExecutor<M> refuses to be built directly (it
  // raises 'O Object Manager nao deve ser instanciada diretamente') and a nil
  // owner reaches that check as an Access Violation - measured.
  FConnection := TRowsConnection.Create(dnSQLite, 2,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add('k1', ftInteger);
      ADataSet.FieldDefs.Add('k2', ftInteger);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName('k1').AsInteger := 1;
      ADataSet.FieldByName('k2').AsInteger := AIndex;
    end,
    'keypredicate-two');
  LSet := TContainerObjectSet<TKeyOnly>.Create(FConnection);
  LFound := LSet.Find(Int64(1));
  try
    Assert.IsNull(LFound,
      'THE CONSEQUENCE OF #326, at the layer a consumer sees: with a composite '+
      'key whose first column is not unique the predicate matches more than ' +
      'one row, and Find - which demands RecordCount = 1 - answers nil. The ' +
      'row is in the store and the caller is told it is not.');
  finally
    LFound.Free;
  end;
end;

procedure TTestDMLKeyPredicate.CompositeKey_FindOverExactlyOneRow_AnswersTheObject;
var
  LSet: IContainerObjectSet<TKeyOnly>;
  LFound: TKeyOnly;
begin
  LSet := TContainerObjectSet<TKeyOnly>.Create(FConnection);
  LFound := LSet.Find(Int64(1));
  try
    Assert.IsNotNull(LFound,
      'the control: Find does not answer nil for everything - with ONE ' +
      'matching row it answers the object');
  finally
    LFound.Free;
  end;
end;

function TTestDMLKeyPredicate.CompositeWhere(const AIDs: TArray<TValue>): String;
var
  LSQL: String;
  LPos: Integer;
begin
  LSQL := SelectIdSql(dnSQLite, TKeyOnly, TValue.From<TArray<TValue>>(AIDs));
  // Same reason the scalar clause cuts the tail out: the SELECT LIST names
  // every mapped column, so k2 appears in the statement whatever the WHERE
  // says. Asserting over the whole string measures the select list.
  LPos := Pos(' WHERE ', UpperCase(LSQL));
  Assert.IsTrue(LPos > 0, 'premise: the statement carries a WHERE: ' + LSQL);
  Result := Copy(LSQL, LPos, Length(LSQL));
end;

procedure TTestDMLKeyPredicate.
  CompositeKey_OneValuePerColumn_NamesEveryColumnJoinedByAnd;
var
  LWhere: String;
begin
  LWhere := CompositeWhere([TValue.From<Int64>(1), TValue.From<Int64>(2)]);
  Assert.Contains(LWhere, 'keyonly.k1 = 1', True,
    'the first key column must still be named exactly as before: ' + LWhere);
  Assert.Contains(LWhere, 'keyonly.k2 = 2', True,
    'ISSUE #326 REPAIRED: TKeyOnly declares a COMPOSITE key, k1;k2, and the ' +
    'second column now reaches the predicate. The loop used to carry ' +
    '`if LFor > 0 then Continue`: ' + LWhere);
  Assert.Contains(LWhere, 'keyonly.k1 = 1 AND keyonly.k2 = 2', True,
    'and the two terms must be joined by AND - the old loop body did not ' +
    'even contain the string, which is what made it unfinished rather than ' +
    'wrong: ' + LWhere);
end;

procedure TTestDMLKeyPredicate.
  CompositeKey_MixedTypes_EachTermKeepsItsOwnLiteralForm;
var
  LWhere: String;
begin
  LWhere := CompositeWhere([TValue.From<Int64>(7), TValue.From<String>('A-1')]);
  Assert.Contains(LWhere, 'keyonly.k1 = 7', True,
    'the ordinal term stays bare: ' + LWhere);
  Assert.Contains(LWhere, 'keyonly.k2 = ''A-1''', True,
    'and the string term stays quoted - each value is rendered on its own, ' +
    'so a composite key of mixed types spells each half the way a scalar of ' +
    'that type always was: ' + LWhere);
end;

procedure TTestDMLKeyPredicate.
  CompositeKey_FewerValuesThanColumns_NamesOnlyWhatItWasGiven;
var
  LWhere: String;
begin
  LWhere := CompositeWhere([TValue.From<Int64>(1)]);
  Assert.Contains(LWhere, 'keyonly.k1 = 1', True,
    'premise: the one value supplied names the first column: ' + LWhere);
  Assert.DoesNotContain(LWhere, 'keyonly.k2', True,
    'THE DESIGN DECISION, PINNED: the predicate is driven by the VALUES the ' +
    'caller supplied and not by the columns the key happens to have. A ' +
    'single value must give the single-column predicate this method has ' +
    'always given - that is what makes the repair additive instead of a ' +
    'change every existing consumer would feel: ' + LWhere);
  Assert.DoesNotContain(LWhere, ' AND ', True,
    'and with one term there is no join to emit: ' + LWhere);
end;

procedure TTestDMLKeyPredicate.
  CompositeKey_ThroughTheContainerFind_ReachesTheFullPredicate;
var
  LRows: TRowsConnection;
  LConn: IDBConnection;
  LSet: IContainerObjectSet<TKeyOnly>;
  LFound: TKeyOnly;
begin
  LRows := TRowsConnection.Create(dnSQLite, 1,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add('k1', ftInteger);
      ADataSet.FieldDefs.Add('k2', ftInteger);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName('k1').AsInteger := 1;
      ADataSet.FieldByName('k2').AsInteger := 2;
    end,
    'keypredicate-container-find');
  LConn := LRows;
  LSet := TContainerObjectSet<TKeyOnly>.Create(LConn);
  LFound := LSet.Find([TValue.From<Int64>(1), TValue.From<Int64>(2)]);
  try
    Assert.Contains(LRows.LastSQL, 'keyonly.k1 = 1 AND keyonly.k2 = 2', True,
      'ISSUE #326 at the layer a consumer actually holds: the values reach ' +
      'the predicate through TObjectSetAdapter, TSessionAbstract and ' +
      'TSQLCommandExecutor, none of which needed a wider signature - the ' +
      'array travels inside the TValue those already took. Emitted: ' +
      LRows.LastSQL);
  finally
    LFound.Free;
    LSet := nil;
    LConn := nil;
  end;
end;

procedure TTestDMLKeyPredicate.
  CompositeKey_ThroughTheContainerOpen_ReachesTheFullPredicate;
var
  LRows: TRowsConnection;
  LConn: IDBConnection;
  LTable: TFDMemTable;
  LContainer: IContainerDataSet<TKeyOnly>;
begin
  LRows := TRowsConnection.Create(dnSQLite, 1,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add('k1', ftInteger);
      ADataSet.FieldDefs.Add('k2', ftInteger);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName('k1').AsInteger := 1;
      ADataSet.FieldByName('k2').AsInteger := 2;
    end,
    'keypredicate-container-open');
  LConn := LRows;
  LTable := TFDMemTable.Create(nil);
  try
    LContainer := TContainerFDMemTable<TKeyOnly>.Create(LConn, LTable);
    LContainer.Open([TValue.From<Int64>(1), TValue.From<Int64>(2)]);
    Assert.Contains(LRows.LastSQL, 'keyonly.k1 = 1 AND keyonly.k2 = 2', True,
      'the OTHER chain - OpenIDInternal and TSessionDataSet<M>.OpenID - is ' +
      'the one with no RecordCount guard, so it is the one that used to hand ' +
      'the consumer EVERY row a one-column predicate matched. With one value ' +
      'per column it asks the question the caller meant. Emitted: ' +
      LRows.LastSQL);
    LContainer := nil;
  finally
    LTable.Free;
    LConn := nil;
  end;
end;

procedure TTestDMLKeyPredicate.
  EmptyValueArray_IsRefusedInsteadOfMatchingEveryRow;
var
  LEmpty: TArray<TValue>;
begin
  SetLength(LEmpty, 0);
  Assert.WillRaise(
    procedure
    begin
      SelectIdSql(dnSQLite, TKeyOnly, TValue.From<TArray<TValue>>(LEmpty));
    end,
    Exception,
    'ISSUE #326: an empty value array is an id that names nothing. Before ' +
    'this guard it emitted SELECT keyonly.k1, keyonly.k2 FROM keyonly - a ' +
    'statement with NO WHERE, matching every row in the table, reached ' +
    'through the public entry point this branch created.');
end;

procedure TTestDMLKeyPredicate.
  EmptyValueArray_OnTheOpenChain_IsRefusedNotAWholeTableRead;
var
  LTable: TFDMemTable;
  LRows: TRowsConnection;
  LConn: IDBConnection;
  LContainer: IContainerDataSet<TKeyOnly>;
  LEmpty: TArray<TValue>;
begin
  SetLength(LEmpty, 0);
  LRows := TRowsConnection.Create(dnSQLite, 2,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add('k1', ftInteger);
      ADataSet.FieldDefs.Add('k2', ftInteger);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName('k1').AsInteger := 1;
      ADataSet.FieldByName('k2').AsInteger := AIndex;
    end,
    'keypredicate-empty-open');
  LConn := LRows;
  LTable := TFDMemTable.Create(nil);
  try
    LContainer := TContainerFDMemTable<TKeyOnly>.Create(LConn, LTable);
    Assert.WillRaise(
      procedure
      begin
        LContainer.Open(LEmpty);
      end,
      Exception,
      'THE Open CHAIN HAS NO RecordCount GUARD TO MASK THIS. Measured ' +
      'before the repair: two rows seeded, and Open([]) loaded BOTH into ' +
      'the consumer dataset for a question about one id.');
    Assert.AreEqual(0, LTable.RecordCount,
      'and nothing may have been loaded on the way to the refusal');
    LContainer := nil;
  finally
    LTable.Free;
    LConn := nil;
  end;
end;

procedure TTestDMLKeyPredicate.
  MoreValuesThanColumns_IsRefusedInsteadOfDiscardingThem;
begin
  Assert.WillRaise(
    procedure
    begin
      SelectIdSql(dnSQLite, TKeyOnly, TValue.From<TArray<TValue>>(
        [TValue.From<Int64>(1), TValue.From<Int64>(2), TValue.From<Int64>(3)]));
    end,
    Exception,
    'TKeyOnly has TWO key columns. Before this guard a third value emitted ' +
    'WHERE keyonly.k1 = 1 AND keyonly.k2 = 2 and dropped the 3 in silence - ' +
    'the same class of defect as the `if LFor > 0 then Continue` #326 ' +
    'removed. FEWER values than columns stays allowed: that is the design.');
end;

procedure TTestDMLKeyPredicate.
  PrimaryKeyWithNoColumns_IsRefusedNotAWholeTableRead;
begin
  Assert.WillRaise(
    procedure
    begin
      SelectIdSql(dnSQLite, TNoKeyColsRow, TValue.From<Int64>(1));
    end,
    Exception,
    'A REGRESSION THIS BRANCH INTRODUCED AND THEN PAID BACK. On the base ' +
    'commit a zero-column key left a dangling '' WHERE '' - malformed SQL a ' +
    'database rejects loudly. Appending the keyword after the loop turned ' +
    'that into SELECT nokeycols.nk_id FROM nokeycols: a SILENT full-table ' +
    'read, measured. An earlier version of this fixture called the shape ' +
    'uncoverable; it is ten lines away. WHAT REFUSES IT IS THE ' +
    'TOO-MANY-VALUES GUARD, not a guard of its own: one scalar value against ' +
    'zero columns IS more values than columns. A dedicated Columns.Count = 0 ' +
    'test was written and DELETED because removing it killed nothing.');
end;

procedure TTestDMLKeyPredicate.
  IdAgainstAClassWithNoPrimaryKeyMapping_IsRefusedNotAWholeTableRead;
begin
  Assert.WillRaise(
    procedure
    begin
      SelectIdSql(dnSQLite, TNoPrimaryKeyRow, TValue.From<Integer>(7));
    end,
    Exception,
    'ISSUE #361: an id was supplied for a class that maps no primary key. ' +
    'Both #326 guards live INSIDE the  arm, so this ' +
    'shape walked past them and left the method with an EMPTY predicate - a ' +
    'SELECT or a DELETE over every row of the table, answered as though it ' +
    'had located one. Refusing by name is the form the neighbouring guards ' +
    'already use.');
end;

procedure TTestDMLKeyPredicate.
  TypelessTValue_MeansEveryRow_AndThatIsDeliberate;
var
  LSql: String;
begin
  /// TValue.Empty and Default(TValue) are the SAME value - a TValue whose
  /// FTypeInfo is nil - and both are asserted because the repair's contract is
  /// about the SHAPE, not about which spelling produced it.
  LSql := SelectIdSql(dnSQLite, TKeyOnly, TValue.Empty);
  Assert.DoesNotContain(LSql, ' WHERE ', True,
    'ISSUE #361: a typeless TValue is the out-of-band spelling of "no id" ' +
    'that replaced -1, so it must produce a statement with NO key predicate. ' +
    'Emitted: ' + LSql);
  LSql := SelectIdSql(dnSQLite, TKeyOnly, Default(TValue));
  Assert.DoesNotContain(LSql, ' WHERE ', True,
    'Default(TValue) IS TValue.Empty and must answer identically. ' +
    'Emitted: ' + LSql);
  /// AND THE DECLARED COST OF THAT CHOICE. On 0103408 this same shape RAISED
  /// - the #326 empty-values guard caught it, because TValue.IsType<T> is
  /// True for a typeless value and _KeyValues answered an empty array. So a
  /// caller who reaches GenerateSelectID holding a TValue that carries no
  /// type used to be refused and is now served the whole table. It is a
  /// REVERSAL and it is deliberate, and this clause is where it is written
  /// down rather than discovered.
  Assert.Pass('the reversal above is declared, not incidental');
end;

procedure TTestDMLKeyPredicate.
  ShapesThatOnlyLookTypeless_DoNotMeanEveryRow;
var
  LSql: String;
  LEmpty: TArray<TValue>;
begin
  SetLength(LEmpty, 0);
  /// AN EMPTY STRING IS AN ID, NOT AN ABSENT ONE. TValue.IsEmpty answers True
  /// for it; TypeInfo = nil does not. Measured base x HEAD: unchanged by the
  /// repair, which is the point.
  LSql := SelectIdSql(dnSQLite, TKeyOnly, TValue.From<String>(''));
  Assert.Contains(LSql, 'keyonly.k1 = ' + QuotedStr(''), True,
    'an empty STRING is a supplied id that names nothing findable, and it ' +
    'must still build its predicate. If this reads as "no id", the test in ' +
    '_NoIdSupplied has drifted from TypeInfo = nil back to IsEmpty. ' +
    'Emitted: ' + LSql);
  /// AN EMPTY VALUE ARRAY IS ALSO IsEmpty, AND IT MUST STILL BE REFUSED -
  /// this is the #326 guard, and it is the clause that caught the first draft
  /// of this repair when it asked IsEmpty instead of TypeInfo = nil.
  Assert.WillRaise(
    procedure
    begin
      SelectIdSql(dnSQLite, TKeyOnly, TValue.From<TArray<TValue>>(LEmpty));
    end,
    Exception,
    'an EMPTY TArray<TValue> is IsEmpty too. If _NoIdSupplied asks IsEmpty ' +
    'it swallows this shape as "no id" and the #326 refusal never runs.');
end;

initialization
  TRegisterClass.RegisterEntity(TNoPrimaryKeyRow);
  TRegisterClass.RegisterEntity(TNoKeyColsRow);
  TRegisterClass.RegisterEntity(TDateKeyRow);
  TDUnitX.RegisterTestFixture(TTestDMLKeyPredicate);

end.
