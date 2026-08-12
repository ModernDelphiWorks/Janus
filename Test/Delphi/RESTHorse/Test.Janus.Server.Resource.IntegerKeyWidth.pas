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
    procedure UnsignedKeyAboveHighInt64_MustRoundTripThroughTheFramework;
    [Test]
    procedure UnsignedKeyAboveHighInt64_TheStorageIsTheWallAndNotTheFramework;
    [Test]
    procedure UnsignedKeyAboveHighInt64_TheCorrectLiteralStillLocatesNothing;
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


/// ISSUE #325, AND WHAT IS LEFT OF IT AFTER THE READ WAS WIDENED. The row on
/// disk carries the SIGNED reinterpretation of the key - see the two clauses
/// below for why that is the storage and not this framework - and reading it
/// back into an UNSIGNED property returns the bit pattern to the type that can
/// spell it. Measured at the base commit through the same route: 0, because
/// $8000000000000000 truncated to its low 32 bits is zero.
procedure TTestServerResourceIntegerKeyWidth.UnsignedKeyAboveHighInt64_MustRoundTripThroughTheFramework;
var
  LObjectSet: TRESTObjectSet;
  LObject: TObject;
begin
  InsertRaw('KeyTypeUnsigned', '{"ktu":9223372036854775808,"kttag":"u"}');
  LObjectSet := TRESTObjectSet.Create(FConnection, TKeyTypeUnsigned);
  try
    /// The predicate names the value the ROW carries, which the next clause
    /// measures and this one takes as given. Locating the row is not what is
    /// under test here - what is under test is what arrives in the property.
    LObject := LObjectSet.FindOne('(ktunsigned.ktu=-9223372036854775808)');
    Assert.IsNotNull(LObject,
      'The row the framework itself wrote was not found by the value it '
      + 'carries. Captured: ' + Captured);
    try
      Assert.AreEqual('9223372036854775808',
        UIntToStr(TKeyTypeUnsigned(LObject).ktu),
        'An unsigned key above High(Int64) did not come back as it was sent.');
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
/// integer. The framework's own bound parameter keeps typeof() = integer and
/// keeps every bit - it simply cannot keep the SIGN, because the column has
/// nowhere to put it.
///
/// So there is nothing here to repair inside Janus without changing what a
/// consumer sees: storing the key as TEXT, or refusing the mapping. Both are
/// contract changes and neither is made here.
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
  InsertRaw('KeyTypeUnsigned', '{"ktu":9223372036854775808,"kttag":"u"}');
  Assert.AreEqual('integer',
    ScalarStr('SELECT typeof(ktu) FROM ktunsigned'),
    'The bound parameter stopped landing in the INTEGER storage class, which '
    + 'is the only class that keeps all 64 bits.');
end;

/// THE CONSEQUENCE ISSUE #325 NAMES, PINNED SO THAT IT CANNOT BE FORGOTTEN.
/// The insert response #311 emits carries the UNSIGNED literal, which is the
/// key the caller sent and is correct - and it locates NOTHING, because the row
/// is on disk as the signed reinterpretation. Rendering the signed form in the
/// predicate would locate it under SQLite and would be WRONG under a dialect
/// with a real unsigned type, and only the DML generator knows the dialect:
/// reaching it from the resource layer means a new method on
/// IDMLGeneratorCommand. That is a contract change and it is not made here.
///
/// THIS CLAUSE PINS A DEFECT, NOT A CONTRACT. If a later branch teaches the
/// predicate the dialect, this is the clause that has to be rewritten, and its
/// message says so rather than leaving the next reader to guess.
procedure TTestServerResourceIntegerKeyWidth.UnsignedKeyAboveHighInt64_TheCorrectLiteralStillLocatesNothing;
begin
  InsertRaw('KeyTypeUnsigned', '{"ktu":9223372036854775808,"kttag":"u"}');
  Assert.AreEqual('0',
    ScalarStr('SELECT COUNT(*) FROM ktunsigned WHERE ktu = 9223372036854775808'),
    'The unsigned literal now locates the row. That is a REPAIR of issue #325 '
    + 'and this clause is the one that has to be rewritten to say so.');
  Assert.AreEqual('1',
    ScalarStr('SELECT COUNT(*) FROM ktunsigned WHERE ktu = -9223372036854775808'),
    'The signed reinterpretation stopped locating the row the framework wrote.');
end;

initialization
  /// Explicit registration: DUnitX's RTTI discovery does not find a fixture
  /// this project never names.
  TDUnitX.RegisterTestFixture(TTestServerResourceIntegerKeyWidth);

end.
