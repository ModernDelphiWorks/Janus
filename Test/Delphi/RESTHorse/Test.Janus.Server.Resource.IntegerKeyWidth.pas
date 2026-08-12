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

(* @abstract(Janus Framework - the WIDTH of an integer primary key, issues #324
  and #325.)

  A parenthesis-star header: the text quotes JSON fragments that carry braces,
  and a brace inside a brace comment ends the comment where the text does not.

  ANCHORS ARE BY SYMBOL OR METHOD, NEVER BY file:line. *)

unit Test.Janus.Server.Resource.IntegerKeyWidth;

interface

uses
  Classes,
  SysUtils,
  Variants,
  StrUtils,
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
  Janus.Server.Resource,
  Janus.Server.RestObjectSet,
  Janus.Container.ObjectSet,
  Janus.Container.ObjectSet.Interfaces,
  Test.Janus.Model.KeyTypes;

type
  [TestFixture]
  TTestServerResourceIntegerKeyWidth = class
  private
    FDConnection: TFDConnection;
    FConnection: IDBConnection;
    /// Every command TDMLCommandFactory emits, in order, with its parameters.
    FCommands: TStringList;
    function InsertRaw(const AResource, ABody: String): String;
    function UpdateRaw(const AResource, ABody: String): String;
    /// The commands captured so far, one per line, for a failure message.
    function Captured: String;
    /// True when a captured command starts with AVerb and mentions ATable.
    function Emitted(const AVerb, ATable: String): Boolean;
    function ScalarStr(const ASQL: String): String;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;
    [Setup]
    procedure Setup;

    [Test]
    procedure A64BitKeyMustSurviveTheReadBackIntoItsProperty;
    [Test]
    procedure AnIntegerKeyMustStillSurviveTheReadBack;
    [Test]
    procedure Local_A64BitKeyMustSurviveTheReadBackIntoItsProperty;
    [Test]
    procedure Put_On64BitKey_MustEmitAnUpdate;
    [Test]
    procedure Put_On64BitKey_MustNotEmitADelete;
    [Test]
    procedure Put_On64BitKey_MustReachItsRow;
    [Test]
    procedure Put_On64BitKey_MustNotDestroyTheRowTheTruncationCollidesWith;
    [Test]
    procedure Put_OnIntegerKey_MustStillEmitAnUpdate;
    [Test]
    procedure UnsignedKeyAtTheSignedExtreme_MustReachItsUnsignedProperty;
    [Test]
    procedure UnsignedKeyAboveHighInt64_TheStorageIsTheWallAndNotTheFramework;
    [Test]
    procedure UnsignedKeyAboveHighInt64_TheInsertMustBeRefusedAndNameTheWay;
    [Test]
    procedure UnsignedKeyAboveHighInt64_TheRefusedInsertMustWriteNothing;
    [Test]
    procedure UnsignedValueAboveHighInt64_OnANonKeyColumn_TheInsertMustBeRefused;
    [Test]
    procedure UnsignedValueAboveHighInt64_OnANonKeyColumn_ThePutMustBeRefused;
    [Test]
    procedure UnsignedKeyAboveHighInt64_TheLocalUpdateMustStillReachItsRow;
    [Test]
    procedure UnsignedKeyAboveHighInt64_TheLocalDeleteMustStillReachItsRow;
    [Test]
    procedure UnsignedKeyAboveHighInt64_OnATextColumn_MustStillBeWritten;
    [Test]
    procedure UnsignedKeyAtHighInt64_MustStillBeWritten;
    [Test]
    procedure UnsignedKeyWellBelowHighInt64_MustStillBeWritten;
    [Test]
    procedure ANegative64BitKey_MustStillBeWritten;
  end;

implementation

uses
  DataEngine.FactoryFireDAC;

const
  cDBFILE = 'janus_server_resource_integerkeywidth.db';

  cDDL_BIG = 'CREATE TABLE IF NOT EXISTS ktbig ('   +
             '  ktbig BIGINT PRIMARY KEY, kttag VARCHAR(60))';
  cDDL_NUM = 'CREATE TABLE IF NOT EXISTS ktnum ('   +
             '  ktid INTEGER PRIMARY KEY, kttag VARCHAR(60))';
  cDDL_UNS = 'CREATE TABLE IF NOT EXISTS ktunsigned (' +
             '  ktu BIGINT PRIMARY KEY, kttag VARCHAR(60))';
  /// The escape hatch the refusal's message recommends, given a table so that
  /// the recommendation can be EXERCISED and not merely read.
  cDDL_UTX = 'CREATE TABLE IF NOT EXISTS ktutext (' +
             '  ktut VARCHAR(20) PRIMARY KEY, ktw BIGINT, kttag VARCHAR(60))';

  /// 2^53 + 1. Above 2^32, so a narrowing to 32 bits shows; above 2^53, so a
  /// repair that routes the value through a Double loses it too.
  cBIGKEY: Int64 = 9007199254740993;
  /// The low 32 bits of cBIGKEY. 9007199254740993 mod 2^32 = 1.
  cBIGKEY_LOW32: Int64 = 1;

{ TTestServerResourceIntegerKeyWidth }

procedure TTestServerResourceIntegerKeyWidth.SetupFixture;
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
  /// Test.Janus.Model.KeyTypes.
  FConnection.ExecuteDirect(cDDL_BIG);
  FConnection.ExecuteDirect(cDDL_NUM);
  FConnection.ExecuteDirect(cDDL_UNS);
  FConnection.ExecuteDirect(cDDL_UTX);
end;

procedure TTestServerResourceIntegerKeyWidth.TearDownFixture;
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

procedure TTestServerResourceIntegerKeyWidth.Setup;
begin
  FConnection.ExecuteDirect('DELETE FROM ktbig');
  FConnection.ExecuteDirect('DELETE FROM ktnum');
  FConnection.ExecuteDirect('DELETE FROM ktunsigned');
  FConnection.ExecuteDirect('DELETE FROM ktutext');
  FCommands.Clear;
end;

function TTestServerResourceIntegerKeyWidth.InsertRaw(const AResource,
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

function TTestServerResourceIntegerKeyWidth.UpdateRaw(const AResource,
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

function TTestServerResourceIntegerKeyWidth.Captured: String;
begin
  Result := FCommands.Text;
end;

function TTestServerResourceIntegerKeyWidth.Emitted(const AVerb,
  ATable: String): Boolean;
var
  LFor: Integer;
  LLine: String;
begin
  for LFor := 0 to FCommands.Count - 1 do
  begin
    LLine := TrimLeft(FCommands[LFor]);
    if not StartsText(AVerb, LLine) then
      Continue;
    if not ContainsText(LLine, ATable) then
      Continue;
    Exit(True);
  end;
  Result := False;
end;

function TTestServerResourceIntegerKeyWidth.ScalarStr(const ASQL: String): String;
var
  LValue: Variant;
begin
  LValue := FDConnection.ExecSQLScalar(ASQL);
  if VarIsNull(LValue) or VarIsEmpty(LValue) then
    Result := ''
  else
    Result := VarToStr(LValue);
end;

/// THE POINT OF THE CONVERSION, ASKED DIRECTLY. The row is written through the
/// server's own bound-parameter INSERT and read back through the server's own
/// FindOne, and the clause compares Int64 TO Int64 - never a rendered string,
/// because VarToStr and AsString are exactly the operations that erase width.
procedure TTestServerResourceIntegerKeyWidth.A64BitKeyMustSurviveTheReadBackIntoItsProperty;
var
  LObjectSet: TRESTObjectSet;
  LObject: TObject;
begin
  InsertRaw('KeyTypeBig', '{"ktbig":9007199254740993,"kttag":"before"}');
  LObjectSet := TRESTObjectSet.Create(FConnection, TKeyTypeBig);
  try
    LObject := LObjectSet.FindOne('(ktbig.ktbig=9007199254740993)');
    Assert.IsNotNull(LObject,
      'The row the framework itself wrote was not found. Captured: ' + Captured);
    try
      Assert.IsTrue(TKeyTypeBig(LObject).ktbig = cBIGKEY,
        'The 64-bit key did not survive the read back into its property. '
        + 'Expected ' + IntToStr(cBIGKEY) + ', got '
        + IntToStr(TKeyTypeBig(LObject).ktbig) + '. The low 32 bits of the '
        + 'expected value are ' + IntToStr(cBIGKEY_LOW32) + '.');
    finally
      LObject.Free;
    end;
  finally
    LObjectSet.Free;
  end;
end;

/// The control. A repair that widens the read must not stop an ordinary
/// integer key from arriving.
procedure TTestServerResourceIntegerKeyWidth.AnIntegerKeyMustStillSurviveTheReadBack;
var
  LObjectSet: TRESTObjectSet;
  LObject: TObject;
begin
  InsertRaw('KeyTypeNum', '{"ktid":10,"kttag":"before"}');
  LObjectSet := TRESTObjectSet.Create(FConnection, TKeyTypeNum);
  try
    LObject := LObjectSet.FindOne('(ktnum.ktid=10)');
    Assert.IsNotNull(LObject, 'The integer-key row was not found.');
    try
      Assert.AreEqual(10, TKeyTypeNum(LObject).ktid,
        'An ordinary integer key stopped arriving in its property.');
    finally
      LObject.Free;
    end;
  finally
    LObjectSet.Free;
  end;
end;

/// THE SAME QUESTION OF THE LOCAL FAMILY, which issue #324 left explicitly
/// unmeasured. TContainerObjectSet reaches Janus.Session.Abstract, which binds
/// through the same TBind instance the REST manager uses.
procedure TTestServerResourceIntegerKeyWidth.Local_A64BitKeyMustSurviveTheReadBackIntoItsProperty;
var
  LContainer: IContainerObjectSet<TKeyTypeBig>;
  LList: TObjectList<TKeyTypeBig>;
begin
  InsertRaw('KeyTypeBig', '{"ktbig":9007199254740993,"kttag":"before"}');
  LContainer := TContainerObjectSet<TKeyTypeBig>.Create(FConnection);
  LList := LContainer.FindWhere('(ktbig.ktbig=9007199254740993)');
  try
    Assert.AreEqual(1, LList.Count,
      'The local family did not find the row. Captured: ' + Captured);
    Assert.IsTrue(LList.Items[0].ktbig = cBIGKEY,
      'The LOCAL family narrows the 64-bit key too. Expected '
      + IntToStr(cBIGKEY) + ', got ' + IntToStr(LList.Items[0].ktbig) + '.');
  finally
    LList.Free;
  end;
end;

procedure TTestServerResourceIntegerKeyWidth.Put_On64BitKey_MustEmitAnUpdate;
begin
  InsertRaw('KeyTypeBig', '{"ktbig":9007199254740993,"kttag":"before"}');
  FCommands.Clear;
  UpdateRaw('KeyTypeBig', '{"ktbig":9007199254740993,"kttag":"after"}');
  Assert.IsTrue(Emitted('UPDATE', 'ktbig'),
    'The PUT emitted no UPDATE at all. Captured: ' + Captured);
end;

procedure TTestServerResourceIntegerKeyWidth.Put_On64BitKey_MustNotEmitADelete;
begin
  InsertRaw('KeyTypeBig', '{"ktbig":9007199254740993,"kttag":"before"}');
  FCommands.Clear;
  UpdateRaw('KeyTypeBig', '{"ktbig":9007199254740993,"kttag":"after"}');
  Assert.IsFalse(Emitted('DELETE', 'ktbig'),
    'A PUT emitted a DELETE. Captured: ' + Captured);
end;

procedure TTestServerResourceIntegerKeyWidth.Put_On64BitKey_MustReachItsRow;
begin
  InsertRaw('KeyTypeBig', '{"ktbig":9007199254740993,"kttag":"before"}');
  UpdateRaw('KeyTypeBig', '{"ktbig":9007199254740993,"kttag":"after"}');
  Assert.AreEqual('after',
    ScalarStr('SELECT kttag FROM ktbig WHERE ktbig = 9007199254740993'),
    'The PUT did not reach the row its 64-bit key names.');
end;

/// THE DATA LOSS, ASKED AS A ROW-LEVEL QUESTION. The truncated key is a VALID
/// key of another row, and that row is a different consumer's data.
procedure TTestServerResourceIntegerKeyWidth.Put_On64BitKey_MustNotDestroyTheRowTheTruncationCollidesWith;
begin
  InsertRaw('KeyTypeBig', '{"ktbig":1,"kttag":"bystander"}');
  InsertRaw('KeyTypeBig', '{"ktbig":9007199254740993,"kttag":"before"}');
  UpdateRaw('KeyTypeBig', '{"ktbig":9007199254740993,"kttag":"after"}');
  Assert.AreEqual('bystander',
    ScalarStr('SELECT kttag FROM ktbig WHERE ktbig = 1'),
    'A PUT on a 64-bit key destroyed the row whose key is the low 32 bits of '
    + 'it. Captured: ' + Captured);
end;

procedure TTestServerResourceIntegerKeyWidth.Put_OnIntegerKey_MustStillEmitAnUpdate;
begin
  InsertRaw('KeyTypeNum', '{"ktid":10,"kttag":"before"}');
  FCommands.Clear;
  UpdateRaw('KeyTypeNum', '{"ktid":10,"kttag":"after"}');
  Assert.IsTrue(Emitted('UPDATE', 'ktnum'),
    'The control PUT stopped emitting an UPDATE. Captured: ' + Captured);
  Assert.IsFalse(Emitted('DELETE', 'ktnum'),
    'The control PUT started emitting a DELETE. Captured: ' + Captured);
end;


/// THE READ SIDE OF ISSUE #325, WHICH THE REFUSAL DOES NOT TOUCH AND MUST NOT.
/// A BIGINT column may legitimately hold Low(Int64) - written by another tool,
/// by a migration, or by this framework through an Int64 property - and reading
/// it back into an UNSIGNED property returns the bit pattern to the type that
/// can spell it. Measured at 865370e through the same route: 0, because
/// $8000000000000000 truncated to its low 32 bits is zero.
///
/// THE ROW IS WRITTEN BY HAND HERE, AND THAT IS THE WHOLE POINT OF THE RENAME.
/// It used to be written by the framework, from the JSON body
/// {"ktu":9223372036854775808}; the framework now REFUSES that body, so the
/// clause would measure the refusal instead of the read. The subject is the
/// read, so the row arrives by a route the refusal has no say over.
///
/// IT IS ALSO WHAT KEEPS TBind._SetFieldToPropertyInteger's AsLargeInt ARM
/// GUARDED FOR THE UNSIGNED CASE - the doc comment over that routine names this
/// clause, and it names it under THIS name.
procedure TTestServerResourceIntegerKeyWidth.UnsignedKeyAtTheSignedExtreme_MustReachItsUnsignedProperty;
var
  LObjectSet: TRESTObjectSet;
  LObject: TObject;
begin
  FDConnection.ExecSQL(
    'INSERT INTO ktunsigned (ktu, kttag) VALUES (-9223372036854775808, ' +
    QuotedStr('u') + ')');
  LObjectSet := TRESTObjectSet.Create(FConnection, TKeyTypeUnsigned);
  try
    LObject := LObjectSet.FindOne('(ktunsigned.ktu=-9223372036854775808)');
    Assert.IsNotNull(LObject,
      'The row written by hand was not found by the value it carries. '
      + 'Captured: ' + Captured);
    try
      Assert.AreEqual('9223372036854775808',
        UIntToStr(TKeyTypeUnsigned(LObject).ktu),
        'Low(Int64) on disk did not reach the unsigned property as the bit '
        + 'pattern it is.');
    finally
      LObject.Free;
    end;
  finally
    LObjectSet.Free;
  end;
end;

/// THE SENTENCE THIS CLAUSE EXISTS TO FALSIFY IS IN ISSUE #325 ITSELF, and it
/// is the author's own: that the conversion which flips the sign is "na
/// montagem do parametro, no driver, ou no mapeamento do tipo". It is in none
/// of the three. SQLite's INTEGER storage class IS a signed 64-bit integer,
/// and 9223372036854775808 is High(Int64) + 1 - it does not exist in it.
///
/// The control is a SQL literal typed by hand, which passes through no TParam,
/// no TField and no mapping of ours: SQLite answers typeof() = real, having
/// silently promoted the literal to a float because it could not be an
/// integer. So even a caller who bypasses this framework entirely cannot put
/// 2^63 in that column as an integer.
///
/// AND THE WALL IS ACTUALLY ONE STOREY LOWER THAN THIS COMMENT USED TO SAY.
/// The framework never got as far as SQLite: measured in a standalone probe
/// built with the same Studio 37.0 and using nothing but the RTL, a UInt64
/// property arrives as a Variant of VType varUInt64 (21), a TParam declared
/// ftLargeint KEEPS VType 21 when it is assigned, and TParam.AsLargeInt -
/// Data.DB's own accessor - already answers -9223372036854775808. The sign was
/// gone before any driver was asked. The reading that survives is the narrow
/// one: nothing under Janus's control could have kept it.
///
/// So the choice was between storing the key as TEXT and refusing the mapping.
/// THE REFUSAL IS THE ONE THAT WAS MADE, and the second half of this clause
/// measures it: the framework no longer writes the sign-flipped row at all.
procedure TTestServerResourceIntegerKeyWidth.UnsignedKeyAboveHighInt64_TheStorageIsTheWallAndNotTheFramework;
begin
  FDConnection.ExecSQL(
    'INSERT INTO ktunsigned (ktu, kttag) VALUES (9223372036854775808, ' +
    QuotedStr('direct') + ')');
  Assert.AreEqual('real',
    ScalarStr('SELECT typeof(ktu) FROM ktunsigned WHERE kttag = ' +
              QuotedStr('direct')),
    'SQLite stored the literal as an integer after all. If that is true, the '
    + 'sign flip is no longer the storage limit and issue #325 has a repair '
    + 'this fixture argued it did not.');
  FConnection.ExecuteDirect('DELETE FROM ktunsigned');
  Assert.WillRaise(
    procedure
    begin
      InsertRaw('KeyTypeUnsigned', '{"ktu":9223372036854775808,"kttag":"u"}');
    end,
    Exception,
    'The framework accepted the insert again. It used to write the row under '
    + 'the signed reinterpretation, in silence, and issue #325 chose to refuse '
    + 'it instead.');
end;

/// THE DECISION OF ISSUE #325, TAKEN AND MEASURED. The clause that used to
/// stand here pinned the consequence - the correct literal locating nothing -
/// and its own message said it was the clause to rewrite once somebody decided.
/// Somebody decided: the mapping is REFUSED, with an error that names the way
/// out, because the alternative on offer was to keep writing a row under a key
/// the caller never sent.
///
/// THE MESSAGE IS THE PRODUCT HERE, NOT THE RAISE. An error that says "cannot"
/// and stops is a prettier silence. Every fragment asserted below is a thing
/// the reader needs in order to act: which value was refused, which property
/// and which entity carry it, what the limit is, and what to write instead.
procedure TTestServerResourceIntegerKeyWidth.UnsignedKeyAboveHighInt64_TheInsertMustBeRefusedAndNameTheWay;
var
  LMessage: String;
begin
  LMessage := '';
  try
    InsertRaw('KeyTypeUnsigned', '{"ktu":9223372036854775808,"kttag":"u"}');
  except
    on E: Exception do
      LMessage := E.Message;
  end;
  Assert.IsFalse(LMessage = '',
    'The insert of an unsigned key above High(Int64) was accepted. Issue #325 '
    + 'decided it must be refused. Captured: ' + Captured);
  Assert.IsTrue(ContainsText(LMessage, '9223372036854775808'),
    'The refusal does not quote the value it refused: ' + LMessage);
  Assert.IsTrue(ContainsText(LMessage, 'ktu'),
    'The refusal names neither the property nor the column: ' + LMessage);
  Assert.IsTrue(ContainsText(LMessage, 'TKeyTypeUnsigned'),
    'The refusal does not name the entity: ' + LMessage);
  Assert.IsTrue(ContainsText(LMessage, '9223372036854775807'),
    'The refusal does not state the limit: ' + LMessage);
  Assert.IsTrue(ContainsText(LMessage, 'ftString'),
    'The refusal does not say what to do instead. A named error that stops at '
    + '"no" is only a prettier raise: ' + LMessage);
end;

/// REFUSING IS ONLY BETTER THAN CORRUPTING IF NOTHING IS WRITTEN. A guard that
/// raises AFTER the row has landed would leave the caller with the same wrong
/// key and an exception on top of it.
procedure TTestServerResourceIntegerKeyWidth.UnsignedKeyAboveHighInt64_TheRefusedInsertMustWriteNothing;
begin
  try
    InsertRaw('KeyTypeUnsigned', '{"ktu":9223372036854775808,"kttag":"u"}');
  except
    on E: Exception do ;
  end;
  Assert.AreEqual('0', ScalarStr('SELECT COUNT(*) FROM ktunsigned'),
    'The refused insert wrote a row anyway. Captured: ' + Captured);
end;

/// THE REFUSAL IS ABOUT A VALUE AND NOT ABOUT A KEY, and this is the clause
/// that says so. ktw is an ordinary column on an entity whose KEY is accepted,
/// so the insert gets far enough for the question to be asked at all: a value
/// the column cannot carry is a value the column cannot carry, key or not.
procedure TTestServerResourceIntegerKeyWidth.UnsignedValueAboveHighInt64_OnANonKeyColumn_TheInsertMustBeRefused;
begin
  Assert.WillRaise(
    procedure
    begin
      InsertRaw('KeyTypeUnsignedAsText',
                '{"ktut":7,"ktw":9223372036854775808,"kttag":"u"}');
    end,
    Exception,
    'A non-key unsigned column above High(Int64) was accepted. The refusal of '
    + 'issue #325 is about the VALUE, not about the primary key.');
  Assert.AreEqual('0', ScalarStr('SELECT COUNT(*) FROM ktutext'),
    'The refused insert wrote a row anyway. Captured: ' + Captured);
end;

/// THE UPDATE WRITES TOO, and the loop that writes its VALUES carries the same
/// guard as the insert. It is a different loop from the one that builds the
/// WHERE, and only this one is guarded - the two clauses below measure the
/// other half of that asymmetry.
procedure TTestServerResourceIntegerKeyWidth.UnsignedValueAboveHighInt64_OnANonKeyColumn_ThePutMustBeRefused;
begin
  InsertRaw('KeyTypeUnsignedAsText', '{"ktut":7,"ktw":5,"kttag":"before"}');
  Assert.WillRaise(
    procedure
    begin
      UpdateRaw('KeyTypeUnsignedAsText',
                '{"ktut":7,"ktw":9223372036854775808,"kttag":"after"}');
    end,
    Exception,
    'A PUT writing an unsigned value above High(Int64) into a column that '
    + 'cannot carry it was accepted. Captured: ' + Captured);
  Assert.AreEqual('5', ScalarStr('SELECT ktw FROM ktutext WHERE ktut = ' +
                                 QuotedStr('7')),
    'The refused PUT wrote the value anyway. Captured: ' + Captured);
end;

/// THE OTHER HALF OF THE ASYMMETRY, AND THE REASON THE GUARD IS NOT IN THE
/// WHERE. A row already carrying Low(Int64) - written by another tool, by a
/// migration, or by this framework before the refusal existed - reads back into
/// the unsigned property as 2^63, and saving it goes down as a BOUND PARAMETER
/// that Data.DB reinterprets straight back to Low(Int64). The round trip is
/// self-consistent and it REACHES THE RIGHT ROW.
///
/// This works at the base commit and it has to keep working. Refusing here
/// would take away the only way to repair a row that already carries such a
/// key, which is strictly worse than what happens today - and "worse than
/// today" is the one thing this branch was not allowed to produce.
procedure TTestServerResourceIntegerKeyWidth.UnsignedKeyAboveHighInt64_TheLocalUpdateMustStillReachItsRow;
var
  LContainer: IContainerObjectSet<TKeyTypeUnsigned>;
  LList: TObjectList<TKeyTypeUnsigned>;
begin
  FDConnection.ExecSQL(
    'INSERT INTO ktunsigned (ktu, kttag) VALUES (-9223372036854775808, ' +
    QuotedStr('before') + ')');
  LContainer := TContainerObjectSet<TKeyTypeUnsigned>.Create(FConnection);
  LList := LContainer.FindWhere('(ktunsigned.ktu=-9223372036854775808)');
  try
    Assert.AreEqual(1, LList.Count,
      'The row written by hand was not found. Captured: ' + Captured);
    LContainer.Modify(LList.Items[0]);
    LList.Items[0].kttag := 'after';
    LContainer.Update(LList.Items[0]);
  finally
    LList.Free;
  end;
  Assert.AreEqual('after',
    ScalarStr('SELECT kttag FROM ktunsigned WHERE ktu = -9223372036854775808'),
    'An update on a row whose key is Low(Int64) stopped reaching it. Captured: '
    + Captured);
end;

/// The same asymmetry on the DELETE, which has no write loop at all - every
/// parameter it builds is part of the WHERE. Refusing there would mean a row
/// with such a key could never be removed through this framework again.
procedure TTestServerResourceIntegerKeyWidth.UnsignedKeyAboveHighInt64_TheLocalDeleteMustStillReachItsRow;
var
  LContainer: IContainerObjectSet<TKeyTypeUnsigned>;
  LList: TObjectList<TKeyTypeUnsigned>;
begin
  FDConnection.ExecSQL(
    'INSERT INTO ktunsigned (ktu, kttag) VALUES (-9223372036854775808, ' +
    QuotedStr('doomed') + ')');
  LContainer := TContainerObjectSet<TKeyTypeUnsigned>.Create(FConnection);
  LList := LContainer.FindWhere('(ktunsigned.ktu=-9223372036854775808)');
  try
    Assert.AreEqual(1, LList.Count,
      'The row written by hand was not found. Captured: ' + Captured);
    LContainer.Delete(LList.Items[0]);
  finally
    LList.Free;
  end;
  Assert.AreEqual('0', ScalarStr('SELECT COUNT(*) FROM ktunsigned'),
    'A delete on a row whose key is Low(Int64) stopped reaching it. Captured: '
    + Captured);
end;

/// THE ADVICE INSIDE THE REFUSAL, EXERCISED. The message tells the caller to
/// declare the column ftString; TKeyTypeUnsignedAsText is that declaration over
/// the SAME UInt64 property, and the whole value lands.
///
/// IT IS ALSO THE CLAUSE THAT MAKES THE GUARD'S ftLargeint TERM LOAD-BEARING.
/// Drop that term and this clause dies, because the guard would then refuse the
/// mapping its own message recommends.
procedure TTestServerResourceIntegerKeyWidth.UnsignedKeyAboveHighInt64_OnATextColumn_MustStillBeWritten;
begin
  InsertRaw('KeyTypeUnsignedAsText', '{"ktut":9223372036854775808,"kttag":"u"}');
  Assert.AreEqual('9223372036854775808',
    ScalarStr('SELECT ktut FROM ktutext'),
    'The escape hatch the refusal recommends does not work, which makes the '
    + 'advice in that message false. Captured: ' + Captured);
end;

/// THE BOUNDARY, AND THE REASON THE REFUSAL IS ABOUT THE VALUE AND NOT THE
/// TYPE. High(Int64) is the largest key the column can carry and it is written
/// unchanged; a guard written with >= instead of > kills this clause.
procedure TTestServerResourceIntegerKeyWidth.UnsignedKeyAtHighInt64_MustStillBeWritten;
begin
  InsertRaw('KeyTypeUnsigned', '{"ktu":9223372036854775807,"kttag":"edge"}');
  Assert.AreEqual('1',
    ScalarStr('SELECT COUNT(*) FROM ktunsigned WHERE ktu = 9223372036854775807'),
    'High(Int64) itself stopped being written through an unsigned property. '
    + 'That is the regression refusing the TYPE would have caused. Captured: '
    + Captured);
end;

/// The ordinary case, which is the one a consumer of this framework is most
/// likely to actually have: an unsigned key whose value is nowhere near the
/// boundary. It works today and it has to keep working - that is the whole
/// argument for refusing the value rather than the type.
procedure TTestServerResourceIntegerKeyWidth.UnsignedKeyWellBelowHighInt64_MustStillBeWritten;
begin
  InsertRaw('KeyTypeUnsigned', '{"ktu":42,"kttag":"small"}');
  Assert.AreEqual('1',
    ScalarStr('SELECT COUNT(*) FROM ktunsigned WHERE ktu = 42'),
    'A small unsigned key stopped being written. Captured: ' + Captured);
end;

/// A NEGATIVE 64-BIT KEY IS LEGAL AND MUST NOT BE MISTAKEN FOR AN OVERFLOW.
/// Read as an unsigned pattern, -1 is $FFFFFFFFFFFFFFFF, which is above
/// High(Int64) by any arithmetic that ignores the variant's TAG. This clause is
/// what makes the guard's varUInt64 term load-bearing: drop the tag test and a
/// perfectly ordinary negative key starts being refused.
procedure TTestServerResourceIntegerKeyWidth.ANegative64BitKey_MustStillBeWritten;
begin
  InsertRaw('KeyTypeBig', '{"ktbig":-9007199254740993,"kttag":"neg"}');
  Assert.AreEqual('1',
    ScalarStr('SELECT COUNT(*) FROM ktbig WHERE ktbig = -9007199254740993'),
    'A negative 64-bit key stopped being written. Captured: ' + Captured);
end;

initialization
  /// Explicit registration: DUnitX's RTTI discovery does not find a fixture
  /// this project never names.
  TDUnitX.RegisterTestFixture(TTestServerResourceIntegerKeyWidth);

end.
