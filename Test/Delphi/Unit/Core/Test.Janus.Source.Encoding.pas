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

  THE BASELINE: the tree still carries U+FFFD - characters destroyed by a past
  re-encode, inside comments, where restoring them means inferring the lost
  letter from the surrounding Portuguese. Those files are listed below with
  their exact count. The list is a ratchet: a file not on it may not carry a
  single non-ASCII byte, a listed file may not grow, may not carry any
  non-ASCII byte other than U+FFFD, and may not shrink without the entry being
  updated in the same commit. Entries are expected to disappear over time; an
  entry naming a file that no longer exists fails. }
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
  { One tolerated file, with the exact number of U+FFFD it still carries. }
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
    procedure BaselineIsExactAndOnlyShrinks;
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

  { Files under Source\ that still carry U+FFFD inside comments, measured at
    the commit that introduced this guard. Sorted by path. Shrink only. }
  CBaseline: array [0 .. 46] of TEncodingBaselineRow = (
    (Path: 'Core\Janus.Bind.pas'; Count: 14),
    (Path: 'Core\Janus.Command.Deleter.pas'; Count: 6),
    (Path: 'Core\Janus.Command.Executor.pas'; Count: 14),
    (Path: 'Core\Janus.Command.Updater.pas'; Count: 5),
    (Path: 'Core\Janus.DML.Generator.MongoDB.pas'; Count: 1),
    (Path: 'Core\Janus.DML.Generator.MySQL.pas'; Count: 5),
    (Path: 'Core\Janus.DML.Generator.Oracle.pas'; Count: 3),
    (Path: 'Core\Janus.DML.Generator.PostgreSQL.pas'; Count: 4),
    (Path: 'Core\Janus.DML.Generator.SQLite.pas'; Count: 5),
    (Path: 'Core\Janus.DML.Generator.pas'; Count: 1),
    (Path: 'Core\Janus.Json.pas'; Count: 2),
    (Path: 'Core\Janus.Objects.Helper.pas'; Count: 1),
    (Path: 'Core\Janus.Objects.Utils.pas'; Count: 7),
    (Path: 'Core\Janus.Session.Abstract.pas'; Count: 6),
    (Path: 'Core\Janus.Types.Blob.pas'; Count: 11),
    (Path: 'Dataset\Janus.DataSet.Abstract.pas'; Count: 3),
    (Path: 'Dataset\Janus.DataSet.Adapter.pas'; Count: 15),
    (Path: 'Dataset\Janus.DataSet.Base.Adapter.pas'; Count: 14),
    (Path: 'Dataset\Janus.DataSet.ClientDataSet.pas'; Count: 7),
    (Path: 'Dataset\Janus.DataSet.Consts.pas'; Count: 1),
    (Path: 'Dataset\Janus.DataSet.Events.pas'; Count: 1),
    (Path: 'Dataset\Janus.DataSet.FDMemTable.pas'; Count: 7),
    (Path: 'Dataset\Janus.DataSet.Fields.pas'; Count: 1),
    (Path: 'Dataset\Janus.Manager.DataSet.pas'; Count: 2),
    (Path: 'Dataset\Janus.Session.DataSet.pas'; Count: 4),
    (Path: 'Janus.inc'; Count: 14),
    (Path: 'Monitor\Janus.Form.Monitor.pas'; Count: 1),
    (Path: 'Objectset\Janus.Manager.ObjectSet.pas'; Count: 4),
    (Path: 'Objectset\Janus.ObjectSet.Adapter.pas'; Count: 8),
    (Path: 'Objectset\Janus.ObjectSet.Base.Adapter.pas'; Count: 3),
    (Path: 'Objectset\Janus.Session.ObjectSet.pas'; Count: 1),
    (Path: 'RESTful\Client\Janus.Client.Horse.pas'; Count: 19),
    (Path: 'RESTful\Client\Janus.Client.RestDriver.Horse.pas'; Count: 1),
    (Path: 'RESTful\Client\Janus.Client.RestDriver.WS.pas'; Count: 1),
    (Path: 'RESTful\Client\Janus.Client.RestHorse.Factory.pas'; Count: 2),
    (Path: 'RESTful\Client\Janus.Client.RestWS.Factory.pas'; Count: 2),
    (Path: 'RESTful\Client\Janus.Client.WS.pas'; Count: 11),
    (Path: 'RESTful\Client\Janus.Client.pas'; Count: 4),
    (Path: 'RESTful\Client\Janus.RestDataSet.Adapter.pas'; Count: 18),
    (Path: 'RESTful\Client\Janus.RestDataSet.ClientDataSet.pas'; Count: 3),
    (Path: 'RESTful\Client\Janus.RestDataSet.FDMemTable.pas'; Count: 3),
    (Path: 'RESTful\Client\Janus.Session.RESTful.pas'; Count: 14),
    (Path: 'RESTful\Common\Janus.RestFactory.Connection.pas'; Count: 2),
    (Path: 'RESTful\Server\Janus.Server.Horse.pas'; Count: 3),
    (Path: 'RESTful\Server\Janus.Server.RestObject.Manager.pas'; Count: 23),
    (Path: 'RESTful\Server\Janus.Server.RestObjectSet.Session.pas'; Count: 1),
    (Path: 'RESTful\Server\Janus.Server.RestObjectSet.pas'; Count: 10)
  );

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
  LFor: Integer;
begin
  for LFor := Low(CBaseline) to High(CBaseline) do
    if SameText(CBaseline[LFor].Path, ARelPath) then
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

procedure TTestJanusSourceEncoding.BaselineIsExactAndOnlyShrinks;
var
  LFor: Integer;
  LFull: string;
  LScan: TEncodingScan;
  LProblems: TStringList;
begin
  Assert.IsTrue(FRoot <> '', 'Repository root not found');
  LProblems := TStringList.Create;
  try
    for LFor := Low(CBaseline) to High(CBaseline) do
    begin
      LFull := TPath.Combine(TPath.Combine(FRoot, 'Source'), CBaseline[LFor].Path);
      if not TFile.Exists(LFull) then
      begin
        LProblems.Add(Format('%s: listed in the baseline but does not exist - ' +
                             'remove the entry', [CBaseline[LFor].Path]));
        Continue;
      end;
      LScan := _Scan(TFile.ReadAllBytes(LFull));
      if LScan.OtherNonAscii > 0 then
        LProblems.Add(Format('%s: carries %d non-ASCII byte(s) that are not ' +
                             'U+FFFD - a baseline file tolerates only the ' +
                             'characters already lost, never a new one',
                             [CBaseline[LFor].Path, LScan.OtherNonAscii]));
      if LScan.Replacements > CBaseline[LFor].Count then
        LProblems.Add(Format('%s: U+FFFD grew from %d to %d',
                             [CBaseline[LFor].Path, CBaseline[LFor].Count,
                              LScan.Replacements]))
      else if LScan.Replacements < CBaseline[LFor].Count then
        LProblems.Add(Format('%s: U+FFFD dropped from %d to %d - update the ' +
                             'baseline entry in the same commit (or delete it ' +
                             'if the count reached zero)',
                             [CBaseline[LFor].Path, CBaseline[LFor].Count,
                              LScan.Replacements]));
    end;
    Assert.AreEqual(0, LProblems.Count,
      Format('The encoding baseline is a ratchet and it no longer matches the ' +
             'tree (%d problem(s)): %s',
             [LProblems.Count, LProblems.CommaText]));
  finally
    LProblems.Free;
  end;
end;

initialization

TDUnitX.RegisterTestFixture(TTestJanusSourceEncoding);

end.
