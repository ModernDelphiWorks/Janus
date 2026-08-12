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

  THE ONE THAT IS NOT: THE COMPOSITE KEY. The loop over the primary key columns
  carries `if LFor > 0 then Continue`, so from the second column on the key is
  DISCARDED and the predicate names only the first column. That cannot be
  repaired inside this signature: GetGeneratorWhere receives AID: TValue - ONE
  value - and a composite key needs N. The clauses below MEASURE the
  consequence and deliberately do not change it; see the header of
  GetGeneratorWhere for the enumeration of callers and for why each candidate
  repair is a consumer-visible contract change.

  WHY NO CLAUSE HERE PINS THE TRUNCATED PREDICATE ITSELF. A clause asserting
  "the WHERE names k1 and not k2" would have to be deleted by whoever repairs
  it, and a test that has to die for a fix to land is a tax on the fix. What is
  pinned instead is the OBSERVABLE consequence at the layer a consumer sees -
  Find over a result set that carries more than one row answers nil - which
  stays true whatever the repair turns out to be.
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

  [TestFixture]
  TTestDMLKeyPredicate = class
  private
    FConnection: IDBConnection;
    FDateSaved: Char;
    FTimeSaved: Char;
    FShortDateSaved: String;
    function SelectIdSql(const ADriver: TDriverName;
      const AClass: TClass; const AID: TValue): String;
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
    /// FIREBIRD DOES NOT GET FIREBIRD'S MASK, AND THAT IS NOT THIS REPAIR'S
    /// DOING. TDMLGeneratorFirebird sets FDateFormat to 'MM/dd/yyyy', but
    /// TCommandSelecter.Create swaps dnFirebird and dnFirebird3 for dnSQLite,
    /// so every Firebird SELECT runs the SQLite generator - a house decision
    /// that predates #326 and that TDMLGeneratorFirebird.GuidLiteral's own
    /// comment already records. An earlier version of this clause expected
    /// '03/15/2027' and went red for that reason; it is kept, inverted, so the
    /// swap is measured instead of rediscovered.
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
    /// The arm this repair must NOT disturb: a plain string key stays quoted
    /// and untouched, and an integer key stays bare.
    [Test]
    procedure StringKey_IsStillQuotedAndUnchanged;
    [Test]
    procedure IntegerKey_IsStillBareDigits;

    // ---- the composite key: measured, NOT repaired ----------------------
    /// THE CONSEQUENCE, at the layer a consumer can see. TKeyOnly's key is
    /// 'k1;k2'. Ask the executor for one ID over a cursor that carries TWO
    /// rows - which is what a predicate naming only the first column returns
    /// when that column is not unique - and Find answers nil. The row is in
    /// the store and the consumer is told it is not there.
    [Test]
    procedure CompositeKey_FindOverMoreThanOneMatchingRow_AnswersNil;
    /// The control, so the clause above cannot be green because Find always
    /// answers nil: with ONE row it answers the object.
    [Test]
    procedure CompositeKey_FindOverExactlyOneRow_AnswersTheObject;
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

initialization
  TRegisterClass.RegisterEntity(TDateKeyRow);
  TDUnitX.RegisterTestFixture(TTestDMLKeyPredicate);

end.
