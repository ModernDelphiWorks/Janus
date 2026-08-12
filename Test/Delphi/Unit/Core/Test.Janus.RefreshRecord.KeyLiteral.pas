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

{ @abstract(Janus Framework - the WHERE that TSessionDataSet<M>.RefreshRecord
  builds for the row under the cursor. Issue #327.)

  WHAT WAS UNDER TEST AND WHAT WAS NOT. The site is
  Janus.Session.DataSet.pas, TSessionDataSet<M>.RefreshRecord(TParams) -
  anchored BY SYMBOL, because the RESTful client family is being worked on in
  parallel and a line number would be a lie by the time it is read. Before this
  commit the method spelled every key column as

      AColumns[LFor].Name + '=' + AColumns[LFor].AsString

  - the value RAW, with no quotes and no dispatch by type. The local sibling of
  the REST defect closed by #320 (Janus.Server.Resource.pas,
  _PrimaryKeyValueToSql), and it had gone unmeasured because the ONE fixture
  that drives this method - Test.Janus.Cursor.Advance, RefreshRecord_ThreeRows_
  Terminates - asks whether the loop TERMINATES and uses a key of type
  ftInteger, which is the single label the raw form gets right.

  WHY IT MATTERS EVEN THOUGH THE VALUE IS NOT A CONSUMER'S JSON. The value here
  comes from a TParams the framework itself filled from the dataset's own
  fields (TDataSetBaseAdapter<M>.RefreshRecord), so the INJECTION reading of
  #320 is weaker on this side. The BREAKAGE and the SILENCE are identical: a
  text key leaves as a bare token and the statement dies at the driver, a date
  key leaves in whatever the machine's locale prints, a float key carries the
  ambient DecimalSeparator into the SQL, and a key the row left NULL produced
  `col=` - a syntax error, not an answer.

  THE THREE DISPATCH TABLES, AND WHY THIS IS THE THIRD. Two already existed
  when this was written, and they DISAGREE with each other:

    * TRESTDataSetAdapter<M>._FilterLiteral, Janus.RestDataSet.Adapter.pas -
      the REST CLIENT. Reads a TField. Has NO ftBoolean branch, FUSES ftDate
      with ftDateTime into one ISO mask, carries neither DB.ftSingle nor
      DB.ftExtended on its decimal branch, and passes no TFormatSettings to
      FormatDateTime.
    * _PrimaryKeyValueToSql, Janus.Server.Resource.pas - the REST SERVER, the
      newest and the most complete of the three. Reads a TColumnMapping plus
      the object. Has ftBoolean, separates ftDate / ftDateTime / ftTime, names
      DB.ftSingle and DB.ftExtended, and passes TFormatSettings.Invariant.

  REUSING EITHER ONE FROM HERE WAS MEASURED, NOT ASSUMED, and both answers are
  compiler errors rather than opinions. With `uses Janus.RestDataSet.Adapter,
  Janus.Server.Resource;` added to this unit's implementation section and one
  call to each written into RefreshRecord, dcc32 (Studio 37, Win32, Debug)
  answered:

    Janus.Session.DataSet.pas(130): error E2003: Undeclared identifier:
      '_PrimaryKeyValueToSql'
    Janus.Session.DataSet.pas(131): error E2361: Cannot access private symbol
      TRESTDataSetAdapter<...>._FilterLiteral, of unit
      Janus.RestDataSet.Adapter
      (dcc32 prints the owning unit in braces before the type name; the braces
       are dropped HERE because a Delphi block comment does not nest)

  The server's table is a unit-level routine declared AFTER `implementation`,
  so it is not exported at all; the client's is a `private` method of a generic
  class, which Delphi's unit-scoped friendship does not extend to another unit.
  Neither is a visibility accident that could be waved away by widening a
  section, because the SHAPES differ too: one takes a TField, one takes a
  TColumnMapping plus a TObject, and this site holds a TParam.

  Making one serve all three means a new shared unit under Source\Core and a
  change of behaviour at the two EXISTING call sites - the client would gain a
  boolean branch and lose its fused date branch. That is a repair of the REST
  client family, which has open work in flight, and it is not this issue's to
  make. So the divergence is DECLARED rather than closed, and what this commit
  adds converges on the SERVER's table label for label - the most complete of
  the two - so that a future unification has two agreeing tables and one
  outlier rather than three-way disagreement.

  NOTHING ANYWHERE COMPARES THE TABLES TO EACH OTHER, and this fixture does not
  either. It cannot: neither of the OTHER TWO is reachable from a test unit,
  for the very reasons measured above. The new one IS - KeyLiteralToSql had to
  go in the interface section to satisfy E2506, and two clauses here call it
  directly - so a future unification has one end already open. What is written
  down here about the other two is a READING at this commit, and a reading goes
  stale: a clause that would go red when they drift apart would have to live
  inside one of those two units.

  THE MUTATIONS THAT WERE RUN, AND WHAT DIED IN EACH. Every one was applied to
  Janus.Session.DataSet.pas together with a MESSAGE WARN directive naming
  TRIPWIRE-n - written with the braces a directive needs, which cannot be
  reproduced inside this comment because a Delphi block comment does not nest -
  and dcc32 echoed it as W1054 in the same build, so "applied" is not a claim.
  Totals are of
  Janus.Tests.Units, WHOSE TOTAL MOVED AFTERWARDS - the runs below were made
  on commit e259b53, where the green state was 604/0/0. The count is the
  record of a run and not a description of HEAD: two later commits on this
  branch added clauses of their own, so anyone re-running these mutations will
  see a larger total with the SAME clauses dying.

    n1  the whole literal put back to AColumns[LFor].AsString  -> 7 red
    n2  ftBoolean branch removed                               -> 1 red
    n3  DB.ftSingle deleted from the decimal branch            -> 1 red
    n4  DB.ftExtended deleted from the decimal branch          -> 1 red
    n6  the cNOROWSGUARD arm and its Break removed             -> 1 red
    n7  VarIsEmpty half of the null guard removed              -> 1 red
    n8  QuotedStr replaced by bare concatenation               -> 3 red
    n9  VarIsNull half of the null guard removed               -> 2 red

  n1 kills SEVEN and not nine, and that is the honest arithmetic rather than a
  hole: the integer clause is a NO-CHANGE guard and stays green by design, and
  the undetermined-key clause is held up by the cNOROWSGUARD arm, which n1 does
  not touch - n6 is the mutation that kills that one.

  n4 SURVIVED ON THE FIRST PASS - 604 green at e259b53, tripwire echoed - because
  DB.ftExtended had no model of its own. That is the shape #320 could only
  declare; here TRefreshExtendedKey was written and the mutation now dies.
  n7 SURVIVED ON THE FIRST PASS for the same reason and got the same treatment:
  every TParam the framework builds carries an assigned value, so only a caller
  of the public RefreshRecord(TParams) reaches varEmpty.

  ONE SURVIVOR IS DECLARED AND KEPT. Removing TFormatSettings.Invariant from
  the ftDate branch kills nothing (604 green at e259b53, tripwire echoed). It is inert
  against the CURRENT MASK and not against the contract: in a FormatDateTime
  mask only '/' and ':' are separator placeholders, cISODATE is 'yyyy-mm-dd'
  whose '-' is a literal, and the two other masks quote their colons. So no
  ambient setting can move that text WHILE THE MASKS STAY AS THEY ARE - and a
  mask is one edit away from carrying a '/'. The clause that would catch it
  cannot be written against these masks, which is the same reading the sibling
  _PrimaryKeyValueToSql records for the same argument.
}

unit Test.Janus.RefreshRecord.KeyLiteral;

interface

uses
  DB,
  Classes,
  SysUtils,
  Variants,
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
  Janus.Container.FDMemTable,
  Janus.Container.DataSet.Interfaces,
  Janus.Session.DataSet,
  Janus.DML.Generator.SQLite,
  Test.Janus.Cursor.Double;

type
  /// A TEXT primary key. This is the shape the raw concatenation broke: the
  /// value left as a bare token and the driver refused the statement.
  [Entity]
  [Table('rrtext', '')]
  [PrimaryKey('rtkey', TAutoIncType.NotInc, TGeneratorType.NoneInc,
              TSortingOrder.NoSort, True, 'Text primary key')]
  TRefreshTextKey = class
  private
    Frtkey: String;
    Frttag: String;
  public
    [Column('rtkey', ftString, 20)]
    property rtkey: String read Frtkey write Frtkey;
    [Column('rttag', ftString, 20)]
    property rttag: String read Frttag write Frttag;
  end;

  /// A DATE primary key. Its text is the machine's, not the dialect's, until
  /// something formats it.
  [Entity]
  [Table('rrdate', '')]
  [PrimaryKey('rdkey', TAutoIncType.NotInc, TGeneratorType.NoneInc,
              TSortingOrder.NoSort, True, 'Date primary key')]
  TRefreshDateKey = class
  private
    Frdkey: TDateTime;
    Frdtag: String;
  public
    [Column('rdkey', ftDate)]
    property rdkey: TDateTime read Frdkey write Frdkey;
    [Column('rdtag', ftString, 20)]
    property rdtag: String read Frdtag write Frdtag;
  end;

  /// A FLOAT primary key - the DecimalSeparator branch.
  [Entity]
  [Table('rrfloat', '')]
  [PrimaryKey('rfkey', TAutoIncType.NotInc, TGeneratorType.NoneInc,
              TSortingOrder.NoSort, True, 'Float primary key')]
  TRefreshFloatKey = class
  private
    Frfkey: Double;
    Frftag: String;
  public
    [Column('rfkey', ftFloat)]
    property rfkey: Double read Frfkey write Frfkey;
    [Column('rftag', ftString, 20)]
    property rftag: String read Frftag write Frftag;
  end;

  /// A SINGLE primary key. DB.ftSingle and DB.ftExtended are the two labels
  /// that ESCAPED the first round of the sibling repair (#320) and had to be
  /// added after a measured SQLite syntax error. Janus.DataSet.Fields builds a
  /// TSingleField for this column, so DB.ftSingle is what reaches the TParam.
  /// DB.ftExtended has a model of its own below - see the note there.
  [Entity]
  [Table('rrsingle', '')]
  [PrimaryKey('rskey', TAutoIncType.NotInc, TGeneratorType.NoneInc,
              TSortingOrder.NoSort, True, 'Single primary key')]
  TRefreshSingleKey = class
  private
    Frskey: Single;
    Frstag: String;
  public
    [Column('rskey', ftSingle)]
    property rskey: Single read Frskey write Frskey;
    [Column('rstag', ftString, 20)]
    property rstag: String read Frstag write Frstag;
  end;

  /// An EXTENDED primary key. THIS MODEL EXISTS BECAUSE OF A SURVIVING
  /// MUTATION and not from the start: with only TRefreshSingleKey in place,
  /// deleting DB.ftExtended from the decimal branch left the whole suite green
  /// - 601/0/0 on the tree that carried the first half of this repair, with the
  /// tripwire echoed by dcc32. That is exactly the shape
  /// the sibling repair #320 had to declare as "grouped by argument"; here the
  /// missing clause was cheap enough to write, so the label is MEASURED
  /// instead of argued.
  [Entity]
  [Table('rrext', '')]
  [PrimaryKey('rekey', TAutoIncType.NotInc, TGeneratorType.NoneInc,
              TSortingOrder.NoSort, True, 'Extended primary key')]
  TRefreshExtendedKey = class
  private
    Frekey: Extended;
    Fretag: String;
  public
    [Column('rekey', ftExtended)]
    property rekey: Extended read Frekey write Frekey;
    [Column('retag', ftString, 20)]
    property retag: String read Fretag write Fretag;
  end;

  /// A BOOLEAN primary key - VarToStr renders it as the bare token True.
  [Entity]
  [Table('rrbool', '')]
  [PrimaryKey('rbkey', TAutoIncType.NotInc, TGeneratorType.NoneInc,
              TSortingOrder.NoSort, True, 'Boolean primary key')]
  TRefreshBoolKey = class
  private
    Frbkey: Boolean;
    Frbtag: String;
  public
    [Column('rbkey', ftBoolean)]
    property rbkey: Boolean read Frbkey write Frbkey;
    [Column('rbtag', ftString, 20)]
    property rbtag: String read Frbtag write Frbtag;
  end;

  /// An INTEGER primary key. The one label the raw form always got right, kept
  /// so that the repair is measured NOT to have changed it.
  [Entity]
  [Table('rrint', '')]
  [PrimaryKey('rikey', TAutoIncType.NotInc, TGeneratorType.NoneInc,
              TSortingOrder.NoSort, True, 'Integer primary key')]
  TRefreshIntKey = class
  private
    Frikey: Integer;
    Fritag: String;
  public
    [Column('rikey', ftInteger)]
    property rikey: Integer read Frikey write Frikey;
    [Column('ritag', ftString, 20)]
    property ritag: String read Fritag write Fritag;
  end;

  /// A COMPOSITE key of two DIFFERENT types. With one column the separator
  /// between terms is never written, so ' AND ' could have been anything.
  [Entity]
  [Table('rrcomp', '')]
  [PrimaryKey('rck1;rck2', TAutoIncType.NotInc, TGeneratorType.NoneInc,
              TSortingOrder.NoSort, True, 'Composite primary key')]
  TRefreshCompositeKey = class
  private
    Frck1: Integer;
    Frck2: String;
    Frctag: String;
  public
    [Column('rck1', ftInteger)]
    property rck1: Integer read Frck1 write Frck1;
    [Column('rck2', ftString, 20)]
    property rck2: String read Frck2 write Frck2;
    [Column('rctag', ftString, 20)]
    property rctag: String read Frctag write Frctag;
  end;

  [TestFixture]
  TTestRefreshRecordKeyLiteral = class
  private
    FDecimalSaved: Char;
    FShortDateSaved: String;
    function RefreshSqlOfText(const AKey: String): String;
    function RefreshSqlOfDate(const AKey: TDateTime): String;
    function RefreshSqlOfFloat(const AKey: Double): String;
    function RefreshSqlOfSingle(const AKey: Single): String;
    function RefreshSqlOfExtended(const AKey: Extended): String;
    function RefreshSqlOfBool(const AKey: Boolean): String;
    function RefreshSqlOfInt(const AKey: Integer): String;
    function RefreshSqlOfComposite(const AK1: Integer;
      const AK2: String): String;
    function RefreshSqlOfNullText: String;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// A text key must leave QUOTED. Raw it was `rtkey=A-1`, which no dialect
    /// parses.
    [Test]
    procedure TextKey_LeavesQuoted;
    /// ...and QuotedStr, not hand-written quotes, because it DOUBLES the inner
    /// apostrophe. Raw, a key of O'Brien ended the string in the middle of the
    /// statement - the same shape #320 removed from the server side.
    [Test]
    procedure TextKeyCarryingAnApostrophe_HasItDoubled;
    /// A date key must leave in ISO-8601 and quoted, not in whatever the
    /// machine's ShortDateFormat prints. Measured with the ambient format set
    /// to something no dialect accepts.
    [Test]
    procedure DateKey_LeavesInIso8601AndQuoted;
    /// A float key must carry the SQL decimal separator. Measured with the
    /// ambient DecimalSeparator forced to ',', which is what turned the raw
    /// form into `rfkey=10,5` - a syntax error in every dialect here.
    [Test]
    procedure FloatKey_CarriesTheSqlDecimalSeparator;
    /// The same for DB.ftSingle, which is one of the two labels the sibling
    /// repair missed on its first pass.
    [Test]
    procedure SingleKey_CarriesTheSqlDecimalSeparator;
    /// And for DB.ftExtended, the OTHER label of that pair. This clause was
    /// added after the mutation that deletes DB.ftExtended from the decimal
    /// branch SURVIVED - see the note on TRefreshExtendedKey.
    [Test]
    procedure ExtendedKey_CarriesTheSqlDecimalSeparator;
    /// A boolean key must leave as 1 / 0 and not as the bare token True.
    [Test]
    procedure BooleanKey_LeavesAsOneOrZero;
    /// THE TWO HALVES OF THE NULL GUARD, REACHED DIRECTLY. KeyLiteralToSql is
    /// exported - it had to be, see its header - so unlike the two sibling
    /// tables it can be called from a test with a TParam built by hand. These
    /// two exist because deleting the VarIsEmpty half left the whole suite
    /// green: every param the FRAMEWORK builds carries an assigned value, so
    /// only a caller of the PUBLIC RefreshRecord(TParams) can produce the
    /// other shape. Measured on a freshly added TParam that nothing assigned:
    /// VarIsEmpty True, VarIsNull False, VarType 0, Bound False. The two
    /// halves therefore catch DIFFERENT shapes and neither covers the other.
    [Test]
    procedure AnUnboundParam_HasNoLiteral;
    [Test]
    procedure AParamHoldingNull_HasNoLiteral;
    /// The label the raw form got right must STILL be bare digits: a repair
    /// that quotes everything breaks the case that worked.
    [Test]
    procedure IntegerKey_StaysBareDigits;
    /// Two terms, two types, and the separator between them.
    [Test]
    procedure CompositeKey_SpellsBothTermsSeparatedByAnd;
    /// A key column the row left NULL cannot identify a row. Raw it produced
    /// `rtkey=` and the driver refused the statement; it must become the
    /// house's own zero-rows guard instead.
    [Test]
    procedure AnUndeterminedKey_BecomesTheZeroRowsGuard;
  end;

implementation

const
  cROW = 1;

/// The spy connection, one row, built from the schema of the model under test.
/// TRowsConnection records the SQL of the LAST CreateDataSet, and RefreshRecord
/// is the last thing each helper does, so LastSQL is the statement this
/// fixture is about.
function TextConnection: TRowsConnection;
begin
  Result := TRowsConnection.Create(dnSQLite, cROW,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add('rtkey', ftString, 20);
      ADataSet.FieldDefs.Add('rttag', ftString, 20);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName('rtkey').AsString := 'seed';
      ADataSet.FieldByName('rttag').AsString := 'seed';
    end,
    'refresh-text');
end;

function TTestRefreshRecordKeyLiteral.RefreshSqlOfText(
  const AKey: String): String;
var
  LConn: TRowsConnection;
  LConnRef: IDBConnection;
  LTable: TFDMemTable;
  LContainer: IContainerDataSet<TRefreshTextKey>;
begin
  LConn := TextConnection;
  LConnRef := LConn;
  LTable := TFDMemTable.Create(nil);
  try
    LContainer := TContainerFDMemTable<TRefreshTextKey>.Create(LConnRef, LTable);
    LContainer.Open;
    LTable.First;
    LTable.Edit;
    LTable.FieldByName('rtkey').AsString := AKey;
    LTable.Post;
    LContainer.RefreshRecord;
    Result := LConn.LastSQL;
    LContainer := nil;
  finally
    LTable.Free;
  end;
end;

function TTestRefreshRecordKeyLiteral.RefreshSqlOfNullText: String;
var
  LConn: TRowsConnection;
  LConnRef: IDBConnection;
  LTable: TFDMemTable;
  LContainer: IContainerDataSet<TRefreshTextKey>;
begin
  LConn := TextConnection;
  LConnRef := LConn;
  LTable := TFDMemTable.Create(nil);
  try
    LContainer := TContainerFDMemTable<TRefreshTextKey>.Create(LConnRef, LTable);
    LContainer.Open;
    LTable.First;
    LTable.Edit;
    LTable.FieldByName('rtkey').Clear;
    LTable.Post;
    LContainer.RefreshRecord;
    Result := LConn.LastSQL;
    LContainer := nil;
  finally
    LTable.Free;
  end;
end;

function TTestRefreshRecordKeyLiteral.RefreshSqlOfDate(
  const AKey: TDateTime): String;
var
  LConn: TRowsConnection;
  LConnRef: IDBConnection;
  LTable: TFDMemTable;
  LContainer: IContainerDataSet<TRefreshDateKey>;
begin
  LConn := TRowsConnection.Create(dnSQLite, cROW,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add('rdkey', ftDate);
      ADataSet.FieldDefs.Add('rdtag', ftString, 20);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName('rdkey').AsDateTime := EncodeDate(2000, 1, 1);
      ADataSet.FieldByName('rdtag').AsString := 'seed';
    end,
    'refresh-date');
  LConnRef := LConn;
  LTable := TFDMemTable.Create(nil);
  try
    LContainer := TContainerFDMemTable<TRefreshDateKey>.Create(LConnRef, LTable);
    LContainer.Open;
    LTable.First;
    LTable.Edit;
    LTable.FieldByName('rdkey').AsDateTime := AKey;
    LTable.Post;
    LContainer.RefreshRecord;
    Result := LConn.LastSQL;
    LContainer := nil;
  finally
    LTable.Free;
  end;
end;

function TTestRefreshRecordKeyLiteral.RefreshSqlOfFloat(
  const AKey: Double): String;
var
  LConn: TRowsConnection;
  LConnRef: IDBConnection;
  LTable: TFDMemTable;
  LContainer: IContainerDataSet<TRefreshFloatKey>;
begin
  LConn := TRowsConnection.Create(dnSQLite, cROW,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add('rfkey', ftFloat);
      ADataSet.FieldDefs.Add('rftag', ftString, 20);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName('rfkey').AsFloat := 0;
      ADataSet.FieldByName('rftag').AsString := 'seed';
    end,
    'refresh-float');
  LConnRef := LConn;
  LTable := TFDMemTable.Create(nil);
  try
    LContainer := TContainerFDMemTable<TRefreshFloatKey>.Create(LConnRef, LTable);
    LContainer.Open;
    LTable.First;
    LTable.Edit;
    LTable.FieldByName('rfkey').AsFloat := AKey;
    LTable.Post;
    LContainer.RefreshRecord;
    Result := LConn.LastSQL;
    LContainer := nil;
  finally
    LTable.Free;
  end;
end;

function TTestRefreshRecordKeyLiteral.RefreshSqlOfSingle(
  const AKey: Single): String;
var
  LConn: TRowsConnection;
  LConnRef: IDBConnection;
  LTable: TFDMemTable;
  LContainer: IContainerDataSet<TRefreshSingleKey>;
begin
  LConn := TRowsConnection.Create(dnSQLite, cROW,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add('rskey', ftSingle);
      ADataSet.FieldDefs.Add('rstag', ftString, 20);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName('rskey').AsSingle := 0;
      ADataSet.FieldByName('rstag').AsString := 'seed';
    end,
    'refresh-single');
  LConnRef := LConn;
  LTable := TFDMemTable.Create(nil);
  try
    LContainer := TContainerFDMemTable<TRefreshSingleKey>.Create(LConnRef,
                    LTable);
    LContainer.Open;
    LTable.First;
    LTable.Edit;
    LTable.FieldByName('rskey').AsSingle := AKey;
    LTable.Post;
    LContainer.RefreshRecord;
    Result := LConn.LastSQL;
    LContainer := nil;
  finally
    LTable.Free;
  end;
end;

function TTestRefreshRecordKeyLiteral.RefreshSqlOfExtended(
  const AKey: Extended): String;
var
  LConn: TRowsConnection;
  LConnRef: IDBConnection;
  LTable: TFDMemTable;
  LContainer: IContainerDataSet<TRefreshExtendedKey>;
begin
  LConn := TRowsConnection.Create(dnSQLite, cROW,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add('rekey', ftExtended);
      ADataSet.FieldDefs.Add('retag', ftString, 20);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName('rekey').AsExtended := 0;
      ADataSet.FieldByName('retag').AsString := 'seed';
    end,
    'refresh-extended');
  LConnRef := LConn;
  LTable := TFDMemTable.Create(nil);
  try
    LContainer := TContainerFDMemTable<TRefreshExtendedKey>.Create(LConnRef,
                    LTable);
    LContainer.Open;
    LTable.First;
    LTable.Edit;
    LTable.FieldByName('rekey').AsExtended := AKey;
    LTable.Post;
    LContainer.RefreshRecord;
    Result := LConn.LastSQL;
    LContainer := nil;
  finally
    LTable.Free;
  end;
end;

function TTestRefreshRecordKeyLiteral.RefreshSqlOfBool(
  const AKey: Boolean): String;
var
  LConn: TRowsConnection;
  LConnRef: IDBConnection;
  LTable: TFDMemTable;
  LContainer: IContainerDataSet<TRefreshBoolKey>;
begin
  LConn := TRowsConnection.Create(dnSQLite, cROW,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add('rbkey', ftBoolean);
      ADataSet.FieldDefs.Add('rbtag', ftString, 20);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName('rbkey').AsBoolean := False;
      ADataSet.FieldByName('rbtag').AsString := 'seed';
    end,
    'refresh-bool');
  LConnRef := LConn;
  LTable := TFDMemTable.Create(nil);
  try
    LContainer := TContainerFDMemTable<TRefreshBoolKey>.Create(LConnRef, LTable);
    LContainer.Open;
    LTable.First;
    LTable.Edit;
    LTable.FieldByName('rbkey').AsBoolean := AKey;
    LTable.Post;
    LContainer.RefreshRecord;
    Result := LConn.LastSQL;
    LContainer := nil;
  finally
    LTable.Free;
  end;
end;

function TTestRefreshRecordKeyLiteral.RefreshSqlOfInt(
  const AKey: Integer): String;
var
  LConn: TRowsConnection;
  LConnRef: IDBConnection;
  LTable: TFDMemTable;
  LContainer: IContainerDataSet<TRefreshIntKey>;
begin
  LConn := TRowsConnection.Create(dnSQLite, cROW,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add('rikey', ftInteger);
      ADataSet.FieldDefs.Add('ritag', ftString, 20);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName('rikey').AsInteger := 0;
      ADataSet.FieldByName('ritag').AsString := 'seed';
    end,
    'refresh-int');
  LConnRef := LConn;
  LTable := TFDMemTable.Create(nil);
  try
    LContainer := TContainerFDMemTable<TRefreshIntKey>.Create(LConnRef, LTable);
    LContainer.Open;
    LTable.First;
    LTable.Edit;
    LTable.FieldByName('rikey').AsInteger := AKey;
    LTable.Post;
    LContainer.RefreshRecord;
    Result := LConn.LastSQL;
    LContainer := nil;
  finally
    LTable.Free;
  end;
end;

function TTestRefreshRecordKeyLiteral.RefreshSqlOfComposite(
  const AK1: Integer; const AK2: String): String;
var
  LConn: TRowsConnection;
  LConnRef: IDBConnection;
  LTable: TFDMemTable;
  LContainer: IContainerDataSet<TRefreshCompositeKey>;
begin
  LConn := TRowsConnection.Create(dnSQLite, cROW,
    procedure(const ADataSet: TFDMemTable)
    begin
      ADataSet.FieldDefs.Add('rck1', ftInteger);
      ADataSet.FieldDefs.Add('rck2', ftString, 20);
      ADataSet.FieldDefs.Add('rctag', ftString, 20);
    end,
    procedure(const ADataSet: TFDMemTable; const AIndex: Integer)
    begin
      ADataSet.FieldByName('rck1').AsInteger := 0;
      ADataSet.FieldByName('rck2').AsString := 'seed';
      ADataSet.FieldByName('rctag').AsString := 'seed';
    end,
    'refresh-comp');
  LConnRef := LConn;
  LTable := TFDMemTable.Create(nil);
  try
    LContainer := TContainerFDMemTable<TRefreshCompositeKey>.Create(LConnRef,
                    LTable);
    LContainer.Open;
    LTable.First;
    LTable.Edit;
    LTable.FieldByName('rck1').AsInteger := AK1;
    LTable.FieldByName('rck2').AsString := AK2;
    LTable.Post;
    LContainer.RefreshRecord;
    Result := LConn.LastSQL;
    LContainer := nil;
  finally
    LTable.Free;
  end;
end;

{ TTestRefreshRecordKeyLiteral }

procedure TTestRefreshRecordKeyLiteral.Setup;
begin
  // The two ambient settings the raw form leaked into the SQL. They are FORCED
  // here rather than read, so the clauses below measure the code and not the
  // machine the suite happens to run on.
  FDecimalSaved := FormatSettings.DecimalSeparator;
  FShortDateSaved := FormatSettings.ShortDateFormat;
  FormatSettings.DecimalSeparator := ',';
  FormatSettings.ShortDateFormat := 'dd/mm/yyyy';
end;

procedure TTestRefreshRecordKeyLiteral.TearDown;
begin
  FormatSettings.DecimalSeparator := FDecimalSaved;
  FormatSettings.ShortDateFormat := FShortDateSaved;
end;

procedure TTestRefreshRecordKeyLiteral.TextKey_LeavesQuoted;
var
  LSQL: String;
begin
  LSQL := RefreshSqlOfText('A-1');
  Assert.Contains(LSQL, 'rtkey=''A-1''', True,
    'a text key must reach the statement QUOTED - raw it was rtkey=A-1, ' +
    'which no dialect here parses: ' + LSQL);
end;

procedure TTestRefreshRecordKeyLiteral.TextKeyCarryingAnApostrophe_HasItDoubled;
var
  LSQL: String;
begin
  LSQL := RefreshSqlOfText('O''Brien');
  Assert.Contains(LSQL, 'rtkey=''O''''Brien''', True,
    'QuotedStr and not hand-written quotes: the inner apostrophe must be ' +
    'DOUBLED or the string ends in the middle of the statement: ' + LSQL);
end;

procedure TTestRefreshRecordKeyLiteral.DateKey_LeavesInIso8601AndQuoted;
var
  LSQL: String;
begin
  LSQL := RefreshSqlOfDate(EncodeDate(2026, 8, 11));
  Assert.Contains(LSQL, 'rdkey=''2026-08-11''', True,
    'a date key must leave in ISO-8601 and quoted, not in the machine''s ' +
    'ShortDateFormat: ' + LSQL);
  Assert.DoesNotContain(LSQL, '11/08/2026', True,
    'the ambient date format must not reach the SQL at all: ' + LSQL);
end;

procedure TTestRefreshRecordKeyLiteral.FloatKey_CarriesTheSqlDecimalSeparator;
var
  LSQL: String;
begin
  LSQL := RefreshSqlOfFloat(10.5);
  Assert.Contains(LSQL, 'rfkey=10.5', True,
    'the decimal separator has to be the SQL one and not the machine''s - ' +
    'with DecimalSeparator '','' the raw form emitted rfkey=10,5: ' + LSQL);
end;

procedure TTestRefreshRecordKeyLiteral.SingleKey_CarriesTheSqlDecimalSeparator;
var
  LSQL: String;
begin
  LSQL := RefreshSqlOfSingle(10.5);
  Assert.Contains(LSQL, 'rskey=10.5', True,
    'DB.ftSingle shares the decimal branch - it is one of the two labels the ' +
    'sibling repair missed on its first pass: ' + LSQL);
end;

procedure TTestRefreshRecordKeyLiteral.ExtendedKey_CarriesTheSqlDecimalSeparator;
var
  LSQL: String;
begin
  LSQL := RefreshSqlOfExtended(10.5);
  Assert.Contains(LSQL, 'rekey=10.5', True,
    'DB.ftExtended shares the decimal branch, and this clause exists because ' +
    'deleting that label from it left the whole suite green: ' + LSQL);
end;

procedure TTestRefreshRecordKeyLiteral.AnUnboundParam_HasNoLiteral;
var
  LParams: TParams;
  LParam: TParam;
begin
  LParams := TParams.Create(nil);
  try
    LParam := LParams.Add as TParam;
    LParam.Name := 'p';
    LParam.DataType := ftString;
    // The premise, measured rather than assumed: an unbound TParam answers a
    // varEmpty and NOT a varNull, so VarIsNull alone would let it through.
    Assert.IsTrue(VarIsEmpty(LParam.Value),
      'premise: an unbound TParam answers a varEmpty');
    Assert.IsFalse(VarIsNull(LParam.Value),
      'premise: and it is NOT a varNull, so the two halves are not the same ' +
      'guard written twice');
    Assert.AreEqual('', KeyLiteralToSql(LParam),
      'a param nobody bound cannot identify a row and has no literal');
  finally
    LParams.Free;
  end;
end;

procedure TTestRefreshRecordKeyLiteral.AParamHoldingNull_HasNoLiteral;
var
  LParams: TParams;
  LParam: TParam;
begin
  LParams := TParams.Create(nil);
  try
    LParam := LParams.Add as TParam;
    LParam.Name := 'p';
    // THE ORDER OF THESE TWO LINES IS THE MEASUREMENT, not a style choice, and
    // it is the order TDataSetBaseAdapter<M>.RefreshRecord itself uses. With
    // Value assigned BEFORE DataType the param answers a varEmpty and this
    // premise goes red; with DataType first it answers a varNull. TParam.Clear
    // does not reach varNull either.
    LParam.DataType := ftString;
    LParam.Value := Null;
    Assert.IsTrue(VarIsNull(LParam.Value),
      'premise: a TParam assigned Null answers a varNull');
    Assert.AreEqual('', KeyLiteralToSql(LParam),
      'a key column the row left NULL cannot identify a row either');
  finally
    LParams.Free;
  end;
end;

procedure TTestRefreshRecordKeyLiteral.BooleanKey_LeavesAsOneOrZero;
var
  LSQL: String;
begin
  LSQL := RefreshSqlOfBool(True);
  Assert.Contains(LSQL, 'rbkey=1', True,
    'a boolean key must leave as 1, not as the bare token True: ' + LSQL);
  Assert.DoesNotContain(LSQL, 'True', True,
    'the VarToStr rendering of a boolean must not reach the SQL: ' + LSQL);
end;

procedure TTestRefreshRecordKeyLiteral.IntegerKey_StaysBareDigits;
var
  LSQL: String;
begin
  LSQL := RefreshSqlOfInt(7);
  Assert.Contains(LSQL, 'rikey=7', True,
    'the one label the raw form got right must stay bare: a repair that ' +
    'quotes everything breaks the case that worked: ' + LSQL);
  Assert.DoesNotContain(LSQL, '''7''', True,
    'an integer key must NOT be quoted: ' + LSQL);
end;

procedure TTestRefreshRecordKeyLiteral.CompositeKey_SpellsBothTermsSeparatedByAnd;
var
  LSQL: String;
begin
  LSQL := RefreshSqlOfComposite(4, 'B-2');
  Assert.Contains(LSQL, 'rck1=4 AND rck2=''B-2''', True,
    'both terms, each in its own type, joined by AND: ' + LSQL);
end;

procedure TTestRefreshRecordKeyLiteral.AnUndeterminedKey_BecomesTheZeroRowsGuard;
var
  LSQL: String;
begin
  LSQL := RefreshSqlOfNullText;
  Assert.Contains(LSQL, '1 = 0', True,
    'a key column the row left NULL cannot identify a row: it must become ' +
    'the house''s zero-rows guard, not the syntax error rtkey= : ' + LSQL);
  Assert.DoesNotContain(LSQL, 'rtkey=', True,
    'and the undetermined column must not be named at all: ' + LSQL);
end;

initialization
  /// Registered HERE and not in a [SetupFixture]:
  /// TMappingExplorer.GetRepositoryMapping seals its repository on the FIRST
  /// lookup, and a registration inside a fixture setup can arrive after that
  /// snapshot - the reason Test.Janus.Model.KeyTypes gives for the same choice.
  TRegisterClass.RegisterEntity(TRefreshTextKey);
  TRegisterClass.RegisterEntity(TRefreshDateKey);
  TRegisterClass.RegisterEntity(TRefreshFloatKey);
  TRegisterClass.RegisterEntity(TRefreshSingleKey);
  TRegisterClass.RegisterEntity(TRefreshExtendedKey);
  TRegisterClass.RegisterEntity(TRefreshBoolKey);
  TRegisterClass.RegisterEntity(TRefreshIntKey);
  TRegisterClass.RegisterEntity(TRefreshCompositeKey);
  TDUnitX.RegisterTestFixture(TTestRefreshRecordKeyLiteral);

end.
