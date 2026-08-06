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

{
  @abstract(Janus Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
}

{ Encoding guard for Source\ - see CONTRIBUTING.md, "Source file encoding".

  THE RULE: every file under Source\ is pure ASCII, with no BOM. A character
  outside ASCII that a user is meant to read is written as a Delphi #$XXXX
  escape, which keeps the source byte-identical under every editor while the
  compiled string still carries the character.

  WHY ASCII AND NOT "cp1252 IS FINE, UTF-8 IS NOT": the two are not
  distinguishable by inspecting bytes. Take the two bytes C3 A9. Read as
  cp1252 they are the two characters A-WITH-TILDE + COPYRIGHT-SIGN; read as
  UTF-8 they are the one character E-WITH-ACUTE. Both readings are legal, the
  text differs, and nothing in the file says which was meant. That is not a
  curiosity: of the 1920 two-byte UTF-8 sequences, 1770 are made entirely of
  bytes cp1252 also defines, so they are legal both ways. A rule phrased as
  "reject UTF-8 in a BOM-less file" therefore has to guess.

  ASCII-only is decidable, and DetectorAnswersItsKnownByteProbes below pins
  that this guard treats a cp1252 byte and a UTF-8 sequence exactly alike:
  both are non-ASCII, both are refused. The measured cost of the stricter rule
  was three bytes in one file.

  THE BASELINE IS EMPTY, and that is the interesting part. It used to list 47
  files carrying 288 U+FFFD - characters destroyed by a past re-encode, inside
  comments, where restoring one means inferring the lost letter from the
  surrounding Portuguese. All 288 were repaired, so the ratchet has reached
  zero and every file under Source\ is now held to plain ASCII with no
  exception.

  Restoring those characters needed a rule worth keeping written down: a
  U+FFFD proves a non-ASCII byte stood there, so an unaccented spelling is
  excluded by construction - but it says only THAT an accent existed, never
  WHICH. So it cannot be done in bulk. Where the ASCII spelling of the lost
  word would be a DIFFERENT Portuguese word - "e" (and) for "e-acute" (is),
  "esta" (this) for "esta-acute" (is at) - the sentence was reworded instead
  of flattened, because both folds still read correctly and would corrupt the
  comment silently. }
unit Test.Janus.Source.Encoding;

interface

uses
  SysUtils,
  StrUtils,
  Classes,
  IOUtils,
  Types,
  DUnitX.TestFramework;

type
  { One tolerated file, with the exact number of U+FFFD it still carries.
    The type outlives the empty list on purpose: tolerating a file again has
    to be spelled out as a row, where a reviewer can see it. }
  TEncodingBaselineRow = record
    Path: string;
    Count: Integer;
  end;

  { What a scan of one file found. }
  TEncodingScan = record
    HasBom: Boolean;
    Replacements: Integer;   // count of the 3-byte sequence EF BF BD
    OtherNonAscii: Integer;  // every other byte >= $80, counted one by one
  end;

  [TestFixture]
  TTestJanusSourceEncoding = class
  strict private
    FRoot: string;
    FFiles: TStringList;
    function _RelativePath(const AFullPath: string): string;
    function _BaselineIndexOf(const ARelPath: string): Integer;
    class function _Baseline: TArray<TEncodingBaselineRow>; static;
    class function _FindRepositoryRoot: string; static;
    class function _Scan(const ABytes: TBytes): TEncodingScan; static;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure DetectorAnswersItsKnownByteProbes;
    [Test]
    procedure HarnessLocatesTheSourceTree;
    [Test]
    procedure SourceCarriesNoByteOrderMark;
    [Test]
    procedure SourceIsAsciiOutsideTheDeclaredBaseline;
    [Test]
    procedure BaselineIsAtZeroAndTheTreeAgrees;
  end;

implementation

const
  { The marker that identifies the repository root. }
  CRootMarker = 'Source\Janus.inc';

  { How far up from the test executable the root may sit. }
  CMaxWalkUp = 8;

  { A scan that finds fewer files than this means the enumeration broke and
    every other test in this fixture would pass vacuously. }
  CMinExpectedFiles = 120;

  { The declared baseline. EMPTY: the last U+FFFD under Source\ was repaired,
    so no file is tolerated any more and SourceIsAsciiOutsideTheDeclaredBaseline
    now covers every file it enumerates. Putting a row back is how a file gets
    excused, and BaselineIsAtZeroAndTheTreeAgrees refuses one on its own. }
class function TTestJanusSourceEncoding._Baseline: TArray<TEncodingBaselineRow>;
begin
  Result := nil;
end;

class function TTestJanusSourceEncoding._FindRepositoryRoot: string;
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

class function TTestJanusSourceEncoding._Scan(const ABytes: TBytes): TEncodingScan;
var
  LFor: Integer;
  LLen: Integer;
begin
  Result.HasBom := False;
  Result.Replacements := 0;
  Result.OtherNonAscii := 0;
  LLen := Length(ABytes);

  if (LLen >= 3) and (ABytes[0] = $EF) and (ABytes[1] = $BB) and (ABytes[2] = $BF) then
    Result.HasBom := True
  else if (LLen >= 2) and (ABytes[0] = $FF) and (ABytes[1] = $FE) then
    Result.HasBom := True
  else if (LLen >= 2) and (ABytes[0] = $FE) and (ABytes[1] = $FF) then
    Result.HasBom := True;

  LFor := 0;
  while LFor < LLen do
  begin
    if ABytes[LFor] < $80 then
    begin
      Inc(LFor);
      Continue;
    end;
    if (LFor + 2 < LLen) and (ABytes[LFor] = $EF) and (ABytes[LFor + 1] = $BF)
      and (ABytes[LFor + 2] = $BD) then
    begin
      Inc(Result.Replacements);
      Inc(LFor, 3);
      Continue;
    end;
    Inc(Result.OtherNonAscii);
    Inc(LFor);
  end;
end;

function TTestJanusSourceEncoding._RelativePath(const AFullPath: string): string;
begin
  Result := Copy(AFullPath, Length(FRoot) + Length('Source\') + 1, MaxInt);
end;

function TTestJanusSourceEncoding._BaselineIndexOf(const ARelPath: string): Integer;
var
  LRows: TArray<TEncodingBaselineRow>;
  LFor: Integer;
begin
  LRows := _Baseline;
  for LFor := Low(LRows) to High(LRows) do
    if SameText(LRows[LFor].Path, ARelPath) then
      Exit(LFor);
  Result := -1;
end;

procedure TTestJanusSourceEncoding.Setup;
var
  LSourceDir: string;
  LExternalDir: string;
  LFiles: TStringDynArray;
  LFile: string;
  LExt: string;
begin
  FFiles := TStringList.Create;
  FRoot := _FindRepositoryRoot;
  if FRoot = '' then
    Exit;

  LSourceDir := TPath.Combine(FRoot, 'Source');
  LExternalDir := IncludeTrailingPathDelimiter(TPath.Combine(LSourceDir, 'External'));
  LFiles := TDirectory.GetFiles(LSourceDir, '*', TSearchOption.soAllDirectories);
  for LFile in LFiles do
  begin
    if StartsText(LExternalDir, LFile) then
      Continue;
    LExt := LowerCase(TPath.GetExtension(LFile));
    if (LExt = '.pas') or (LExt = '.inc') or (LExt = '.dpr') or (LExt = '.dpk') then
      FFiles.Add(LFile);
  end;
end;

procedure TTestJanusSourceEncoding.TearDown;
begin
  FFiles.Free;
end;

{ The guard's own detector, pinned against probes whose bytes are known.
  A detector that cannot tell these apart cannot be trusted with the tree. }
procedure TTestJanusSourceEncoding.DetectorAnswersItsKnownByteProbes;
var
  LScan: TEncodingScan;
begin
  // Probe A - pure ASCII: nothing to report.
  LScan := _Scan(TBytes.Create($2F, $2F, $20, $6F, $6B));
  Assert.IsFalse(LScan.HasBom, 'probe A: ASCII carries no BOM');
  Assert.AreEqual(0, LScan.Replacements, 'probe A: ASCII has no U+FFFD');
  Assert.AreEqual(0, LScan.OtherNonAscii, 'probe A: ASCII has no other high byte');

  // Probe B - EF BF BD, a character already destroyed: counted as U+FFFD, once.
  LScan := _Scan(TBytes.Create($70, $61, $72, $EF, $BF, $BD, $6F));
  Assert.AreEqual(1, LScan.Replacements, 'probe B: one U+FFFD');
  Assert.AreEqual(0, LScan.OtherNonAscii, 'probe B: U+FFFD is not counted twice');

  // Probe C - a cp1252 accent (E3): non-ASCII, and NOT a U+FFFD.
  LScan := _Scan(TBytes.Create($6E, $E3, $6F));
  Assert.AreEqual(0, LScan.Replacements, 'probe C: a cp1252 accent is not U+FFFD');
  Assert.AreEqual(1, LScan.OtherNonAscii, 'probe C: one high byte');

  // Probe D - the same accent as UTF-8 (C3 A3): also refused, as two bytes.
  // C and D differing only in the count, never in the verdict, is the point:
  // the guard does not try to tell cp1252 from UTF-8, because it cannot.
  LScan := _Scan(TBytes.Create($6E, $C3, $A3, $6F));
  Assert.AreEqual(0, LScan.Replacements, 'probe D: a UTF-8 accent is not U+FFFD');
  Assert.AreEqual(2, LScan.OtherNonAscii, 'probe D: two high bytes');

  // Probe E - a UTF-8 BOM is seen for what it is.
  LScan := _Scan(TBytes.Create($EF, $BB, $BF, $6F, $6B));
  Assert.IsTrue(LScan.HasBom, 'probe E: UTF-8 BOM detected');
end;

{ Fail-closed. If the tree cannot be found, or almost nothing was enumerated,
  every other test here would pass by looking at nothing. }
procedure TTestJanusSourceEncoding.HarnessLocatesTheSourceTree;
begin
  Assert.IsTrue(FRoot <> '',
    Format('Repository root not found: no ancestor of "%s" within %d levels ' +
           'contains "%s". The encoding guard cannot run.',
           [TPath.GetDirectoryName(ParamStr(0)), CMaxWalkUp, CRootMarker]));
  Assert.IsTrue(FFiles.Count >= CMinExpectedFiles,
    Format('Only %d source files enumerated under "%sSource" (expected at ' +
           'least %d). The guard would pass vacuously.',
           [FFiles.Count, FRoot, CMinExpectedFiles]));
end;

procedure TTestJanusSourceEncoding.SourceCarriesNoByteOrderMark;
var
  LFile: string;
  LOffenders: TStringList;
begin
  Assert.IsTrue(FRoot <> '', 'Repository root not found');
  LOffenders := TStringList.Create;
  try
    for LFile in FFiles do
      if _Scan(TFile.ReadAllBytes(LFile)).HasBom then
        LOffenders.Add(_RelativePath(LFile));
    Assert.AreEqual(0, LOffenders.Count,
      Format('Source\ is BOM-less by convention; %d file(s) now carry one: %s',
             [LOffenders.Count, LOffenders.CommaText]));
  finally
    LOffenders.Free;
  end;
end;

procedure TTestJanusSourceEncoding.SourceIsAsciiOutsideTheDeclaredBaseline;
var
  LFile: string;
  LRel: string;
  LScan: TEncodingScan;
  LOffenders: TStringList;
begin
  Assert.IsTrue(FRoot <> '', 'Repository root not found');
  LOffenders := TStringList.Create;
  try
    for LFile in FFiles do
    begin
      LRel := _RelativePath(LFile);
      if _BaselineIndexOf(LRel) >= 0 then
        Continue;
      LScan := _Scan(TFile.ReadAllBytes(LFile));
      if (LScan.Replacements > 0) or (LScan.OtherNonAscii > 0) then
        LOffenders.Add(Format('%s (U+FFFD=%d, other non-ASCII bytes=%d)',
                              [LRel, LScan.Replacements, LScan.OtherNonAscii]));
    end;
    Assert.AreEqual(0, LOffenders.Count,
      Format('%d file(s) under Source\ carry a non-ASCII byte and are not in ' +
             'the declared baseline. Write the character as a Delphi #$XXXX ' +
             'escape inside the literal, or spell the comment in ASCII - see ' +
             'CONTRIBUTING.md. Offenders: %s',
             [LOffenders.Count, LOffenders.CommaText]));
  finally
    LOffenders.Free;
  end;
end;

{ The ratchet reached its end, and this pins BOTH halves of that - because
  either half alone can be satisfied while the other rots. The table has to be
  empty, AND the tree has to actually carry no U+FFFD. Emptying the table while
  damage survives fails the second half; damage coming back under cover of a
  freshly added row fails the first. }
procedure TTestJanusSourceEncoding.BaselineIsAtZeroAndTheTreeAgrees;
var
  LRows: TArray<TEncodingBaselineRow>;
  LFor: Integer;
  LFile: string;
  LScan: TEncodingScan;
  LProblems: TStringList;
begin
  Assert.IsTrue(FRoot <> '', 'Repository root not found');
  LRows := _Baseline;
  LProblems := TStringList.Create;
  try
    for LFor := Low(LRows) to High(LRows) do
      LProblems.Add(Format('%s: the baseline reached zero and is closed. A row ' +
                           'excusing a file from the ASCII rule is a decision to ' +
                           'argue for in review, not to add quietly',
                           [LRows[LFor].Path]));

    for LFile in FFiles do
    begin
      LScan := _Scan(TFile.ReadAllBytes(LFile));
      if LScan.Replacements > 0 then
        LProblems.Add(Format('%s: carries %d U+FFFD - a character a bad re-encode ' +
                             'destroyed. Recover the word from the surrounding ' +
                             'Portuguese and spell it in ASCII; where the ' +
                             'unaccented spelling would be a different word, ' +
                             'reword the sentence instead of flattening it',
                             [_RelativePath(LFile), LScan.Replacements]));
    end;

    Assert.AreEqual(0, LProblems.Count,
      Format('The encoding baseline is closed at zero and the tree no longer ' +
             'agrees (%d problem(s)): %s',
             [LProblems.Count, LProblems.CommaText]));
  finally
    LProblems.Free;
  end;
end;

initialization

TDUnitX.RegisterTestFixture(TTestJanusSourceEncoding);

end.
