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

{ @abstract(Janus Framework - a compile gate for Components\Source\. Issue #340.)

  THE DEFECT THIS GUARDS: Components\Source\Janus.Link.Reg.pas implements
  RequiresUnits for nine TSelectionEditor descendants - the design-time
  mechanism by which the IDE writes a unit into the CONSUMER's own uses
  clause when they drop one of the nine Janus-Links components on a form.
  Eight of those nine named a real unit. The ninth,
  TJanusDriverEditorSQLDirect, named 'Janus.DML.Generator.sqldirect', and NO
  such unit exists anywhere in this repository - git ls-tree confirmed 0
  hits on origin/develop. Whoever dropped TJanusDriverLinkSQLDirect got a
  uses clause that does not compile, in THEIR project, pointing at a unit
  of ours.

  WHY IT WENT UNCAUGHT: Components\Source\ is design-time-only code
  (DesignIntf/DesignEditors, IDE package units) that ZERO of the seven test
  projects compile - measured by the census that found this issue. A
  fixture that recompiled Janus.Link.Reg.pas itself would need those IDE
  units and is not attempted here (see the commit message for what was
  measured about that path). This fixture instead treats the unit as DATA:
  it reads the .pas file as text, extracts every unit name passed to
  Proc(...) inside a RequiresUnits body, and asserts each one is a real
  .pas file under Source\. That is exactly the fact whose absence caused
  the defect, checked without needing the IDE package chain at all.

  WHY Source\ AND NOT Components\Source\: every RequiresUnits entry names a
  DML generator (Janus.DML.Generator.*), and all thirteen of those live
  under Source\Core\, never under Components\. Searching Source\ recursively
  is therefore where a correct entry's target actually is; it is not a
  looser search standing in for a stricter one.

  RED-FIRST: this fixture was run against the tree BEFORE the fix, with the
  'Janus.DML.Generator.sqldirect' line still in place, and
  EveryRequiredUnitEqualsAFileUnderSource failed there - it is the specific
  test this issue's regression maps to. See the commit message for the run
  that produced that failure. }
unit Test.Janus.LinkReg.RequiresUnits;

interface

uses
  SysUtils,
  StrUtils,
  Classes,
  IOUtils,
  Types,
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestJanusLinkRegRequiresUnits = class
  strict private
    FRoot: string;
    FRegFile: string;
    FRequiredUnits: TArray<string>;
    class function _FindRepositoryRoot: string; static;
    { The parser under test, exposed so a positive control can drive it
      directly without touching the repository tree. }
    class function _ExtractProcArguments(const ASource: string): TArray<string>; static;
    class function _UnitFileExistsUnderSource(const ARoot, AUnitName: string): Boolean; static;
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure HarnessLocatesTheRegFile;
    [Test]
    procedure ParserFindsAtLeastTheEightGenuineEntries;
    [Test]
    procedure ParserExtractsAKnownLiteral;
    [Test]
    procedure CheckerRejectsAUnitNameThatDoesNotExist;
    [Test]
    procedure CheckerAcceptsAUnitNameKnownToExist;
    [Test]
    procedure EveryRequiredUnitEqualsAFileUnderSource;
  end;

implementation

const
  { The marker that identifies the repository root - same convention as
    Test.Janus.Source.Encoding. }
  CRootMarker = 'Source\Janus.inc';

  { How far up from the test executable the root may sit. }
  CMaxWalkUp = 8;

  { The file this fixture guards. }
  CRegFileRelativePath = 'Components\Source\Janus.Link.Reg.pas';

  { Post-fix the file carries eight genuine entries (Firebird, MSSQL,
    MongoDB, Oracle, MySQL, PostgreSQL, InterBase, SQLite); the ninth
    (SQLDirect) is repaired by REMOVING its Proc(...) call rather than
    renaming it - see the commit message for the measurement that decided
    that. A count below this means the parser broke and every other test
    here would pass by looking at nothing. }
  CMinExpectedProcCalls = 8;

class function TTestJanusLinkRegRequiresUnits._FindRepositoryRoot: string;
var
  LDir: string;
  LFor: Integer;
begin
  LDir := TPath.GetDirectoryName(ParamStr(0));
  for LFor := 0 to CMaxWalkUp - 1 do
  begin
    if TFile.Exists(TPath.Combine(LDir, CRootMarker)) then
      Exit(IncludeTrailingPathDelimiter(LDir));
    if TPath.GetPathRoot(LDir) = LDir then
      Break;
    LDir := TPath.GetDirectoryName(ExcludeTrailingPathDelimiter(LDir));
    if LDir = '' then
      Break;
  end;
  Result := '';
end;

{ Extracts the string literal argument of every call shaped like
  Proc('SomeUnitName') in the source text. Deliberately dumb: no Pascal
  parser, no knowledge of RequiresUnits or TSelectionEditor - it just finds
  the token "Proc('", then reads up to the closing quote. That is enough
  for this file, where every such call names a required unit, and it means
  the parser has nothing dialect-specific to get wrong. }
class function TTestJanusLinkRegRequiresUnits._ExtractProcArguments(
  const ASource: string): TArray<string>;
const
  CNeedle = 'Proc(''';
var
  LResult: TStringList;
  LPos: Integer;
  LStart: Integer;
  LEnd: Integer;
begin
  LResult := TStringList.Create;
  try
    LPos := 1;
    while True do
    begin
      LPos := PosEx(CNeedle, ASource, LPos);
      if LPos = 0 then
        Break;
      LStart := LPos + Length(CNeedle);
      LEnd := PosEx('''', ASource, LStart);
      if LEnd = 0 then
        Break;
      LResult.Add(Copy(ASource, LStart, LEnd - LStart));
      LPos := LEnd + 1;
    end;
    Result := LResult.ToStringArray;
  finally
    LResult.Free;
  end;
end;

{ Whether AUnitName.pas exists as a file anywhere under ARoot's Source\
  tree (recursive). This is the fact the defect got wrong: a name written
  into RequiresUnits with no file behind it under Source\. }
class function TTestJanusLinkRegRequiresUnits._UnitFileExistsUnderSource(
  const ARoot, AUnitName: string): Boolean;
var
  LSourceDir: string;
  LFiles: TStringDynArray;
  LWanted: string;
  LFile: string;
begin
  Result := False;
  LSourceDir := TPath.Combine(ARoot, 'Source');
  if not TDirectory.Exists(LSourceDir) then
    Exit;
  LWanted := LowerCase(AUnitName + '.pas');
  LFiles := TDirectory.GetFiles(LSourceDir, '*.pas', TSearchOption.soAllDirectories);
  for LFile in LFiles do
    if SameText(TPath.GetFileName(LFile), LWanted) then
      Exit(True);
end;

procedure TTestJanusLinkRegRequiresUnits.Setup;
begin
  FRoot := _FindRepositoryRoot;
  if FRoot = '' then
    Exit;
  FRegFile := TPath.Combine(FRoot, CRegFileRelativePath);
  if not TFile.Exists(FRegFile) then
    Exit;
  FRequiredUnits := _ExtractProcArguments(TFile.ReadAllText(FRegFile));
end;

{ Fail-closed: if the root or the reg file cannot be found, every other
  test in this fixture would pass by looking at nothing. }
procedure TTestJanusLinkRegRequiresUnits.HarnessLocatesTheRegFile;
begin
  Assert.IsTrue(FRoot <> '',
    Format('Repository root not found: no ancestor of "%s" within %d levels ' +
           'contains "%s". This guard cannot run.',
           [TPath.GetDirectoryName(ParamStr(0)), CMaxWalkUp, CRootMarker]));
  Assert.IsTrue(TFile.Exists(FRegFile),
    Format('%s not found under the located repository root %s - the file ' +
           'this fixture guards is missing or moved.', [CRegFileRelativePath, FRoot]));
end;

{ Fail-closed against the parser itself breaking (e.g. the file's Proc(...)
  spelling changes and the needle stops matching): a count below the
  expected floor means EveryRequiredUnitEqualsAFileUnderSource would pass
  vacuously over an empty array. }
procedure TTestJanusLinkRegRequiresUnits.ParserFindsAtLeastTheEightGenuineEntries;
begin
  Assert.IsTrue(FRoot <> '', 'Repository root not found');
  Assert.IsTrue(Length(FRequiredUnits) >= CMinExpectedProcCalls,
    Format('Parsed only %d Proc(...) call(s) out of %s; expected at least %d. ' +
           'Either the file lost entries or the parser broke.',
           [Length(FRequiredUnits), CRegFileRelativePath, CMinExpectedProcCalls]));
end;

{ A known literal, read straight off Janus.Link.Reg.pas:96 at HEAD -
  'Janus.DML.Generator.Firebird', the first RequiresUnits body in the file.
  Pins that the parser extracts the STRING, not some mangled slice of it. }
procedure TTestJanusLinkRegRequiresUnits.ParserExtractsAKnownLiteral;
var
  LFound: Boolean;
  LUnit: string;
begin
  Assert.IsTrue(FRoot <> '', 'Repository root not found');
  LFound := False;
  for LUnit in FRequiredUnits do
    if LUnit = 'Janus.DML.Generator.Firebird' then
      LFound := True;
  Assert.IsTrue(LFound,
    'Expected literal ''Janus.DML.Generator.Firebird'' was not among the ' +
    'parsed Proc(...) arguments - the parser is not reading the file this ' +
    'fixture thinks it is reading.');
end;

{ POSITIVE CONTROL for the file-existence checker, driven directly against
  a synthetic name rather than against the repository tree - proves the
  checker can say "missing" at all, independent of what Janus.Link.Reg.pas
  currently contains. Without this, EveryRequiredUnitEqualsAFileUnderSource
  passing could mean either "every entry is correct" or "the checker never
  reports failure" - the two are indistinguishable without a case known to
  be absent. }
procedure TTestJanusLinkRegRequiresUnits.CheckerRejectsAUnitNameThatDoesNotExist;
begin
  Assert.IsTrue(FRoot <> '', 'Repository root not found');
  Assert.IsFalse(
    _UnitFileExistsUnderSource(FRoot, 'Janus.DML.Generator.sqldirect'),
    'Janus.DML.Generator.sqldirect.pas was found under Source\ - either a ' +
    'file by that name was added (in which case the original issue #340 ' +
    'premise no longer holds and this fixture needs revisiting), or the ' +
    'checker is matching too loosely.');
  Assert.IsFalse(
    _UnitFileExistsUnderSource(FRoot, 'Janus.DML.Generator.NoSuchDialectAtAll'),
    'A deliberately absurd unit name was reported as existing under ' +
    'Source\ - the checker is vacuously true and cannot be trusted.');
end;

{ The checker's other half: a name known to exist (the same literal
  ParserExtractsAKnownLiteral pins) must be found. Without this, a checker
  that always answers False would pass CheckerRejectsAUnitNameThatDoesNotExist
  and still be useless. }
procedure TTestJanusLinkRegRequiresUnits.CheckerAcceptsAUnitNameKnownToExist;
begin
  Assert.IsTrue(FRoot <> '', 'Repository root not found');
  Assert.IsTrue(
    _UnitFileExistsUnderSource(FRoot, 'Janus.DML.Generator.Firebird'),
    'Janus.DML.Generator.Firebird.pas was not found under Source\Core\ - ' +
    'either the tree moved or the checker cannot see a file that is ' +
    'genuinely there.');
end;

{ THE GATE. Every unit name Janus.Link.Reg.pas asks the IDE to write into a
  consumer's uses clause must exist as a real .pas file under Source\. This
  is RED against the tree as it stood before the issue #340 fix (the
  'Janus.DML.Generator.sqldirect' entry has no file behind it anywhere in
  the repository) and GREEN after it. }
procedure TTestJanusLinkRegRequiresUnits.EveryRequiredUnitEqualsAFileUnderSource;
var
  LUnit: string;
  LOffenders: TStringList;
begin
  Assert.IsTrue(FRoot <> '', 'Repository root not found');
  Assert.IsTrue(Length(FRequiredUnits) > 0, 'No Proc(...) entries were parsed');
  LOffenders := TStringList.Create;
  try
    for LUnit in FRequiredUnits do
      if not _UnitFileExistsUnderSource(FRoot, LUnit) then
        LOffenders.Add(LUnit);
    Assert.AreEqual(0, LOffenders.Count,
      Format('%d RequiresUnits entr%s in %s name%s a unit with no .pas file ' +
             'under Source\: %s. Whoever drops the matching Janus-Links ' +
             'component gets this written into THEIR uses clause, and it ' +
             'will not compile - issue #340.',
             [LOffenders.Count, IfThen(LOffenders.Count = 1, 'y', 'ies'),
              CRegFileRelativePath, IfThen(LOffenders.Count = 1, 's', ''),
              LOffenders.CommaText]));
  finally
    LOffenders.Free;
  end;
end;

initialization

TDUnitX.RegisterTestFixture(TTestJanusLinkRegRequiresUnits);

end.
