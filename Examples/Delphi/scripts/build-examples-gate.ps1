<#
  build-examples-gate.ps1

  Janus Examples compile gate (GitHub issue #190).

  Reads Examples/Delphi/auto-validable.txt and msbuild-compiles every row
  classified `compile` or `run`; `defer` and `exclude` rows are counted but
  not built. Prints a PASS/FAIL/DEFERRED/EXCLUDE line per row and exits with
  the number of failed rows (0 = gate green).

  WHY THIS SCRIPT EXISTS (the MSB6003 caveat from #190)
    Each Examples/*.dproj carries a DCC_UnitSearchPath baked in by #187 that
    points at Source\Dependencies\<Dep>\... — a tree that only exists after
    `boss install` populates it. On this machine `boss install` in this repo
    PANICS (measured 2026-08-20: "Version type not supported! improper
    constraint" -> nil pointer dereference in boss/core/installer/core.go),
    so that tree never exists and those entries are dead weight.
    The actual dependency sources live as sibling checkouts under .modules/
    (MetaDbDiff, DataEngine, JsonFlow, ModernSyntax, Horse), plus a FluentSQL
    PIN worktree (.modules/_wt-fluentsql-pin265) that must win over the plain
    .modules/FluentSQL checkout, which is missing 4 drivers.
    This script adds those sibling paths, always RELATIVE to each .dproj's
    own directory (never absolute — msbuild's targets repeat the search path
    across -U/-I/-O/-R, and an absolutized ~26-entry list on a long checkout
    path is exactly what blew past the 32K command-line limit and produced
    MSB6003 in the first place), and prunes any entry that does not exist on
    disk (Test-Path -LiteralPath, never a regex — a space in a path silently
    breaks a regex-based prune).

  PROVEN ELSEWHERE
    The same recipe (relative paths + Test-Path pruning + FluentSQL pin
    prepended) is what Test/Delphi/Tools/compile-coverage-census.ps1 uses to
    build all seven Test/Delphi projects clean (0 errors, measured). This
    script generalizes it to variable-depth Examples/*.dproj via
    [System.IO.Path]::GetRelativePath instead of one fixed offset.

  GUARDS
    - Never passes /p:DCC_DcuOutput (would make every Example collide in one
      output directory and silently report someone else's binary as PASS).
    - Stale-binary guard: a row is only PASS if msbuild exits 0 AND an .exe
      under the project directory has a newer mtime than before the build.
      exit 0 with no fresher binary is downgraded to FAIL.

  USAGE
    powershell -File Examples\Delphi\scripts\build-examples-gate.ps1
    powershell -File Examples\Delphi\scripts\build-examples-gate.ps1 -DryRun
#>

[CmdletBinding()]
param(
  # Repo root. Empty = three levels above this script
  # (Examples\Delphi\scripts -> repo root).
  [string]$Root = '',

  # FluentSQL pin, as a sibling directory NAME under .modules (not this repo).
  [string]$PinRel = '_wt-fluentsql-pin265',

  # Empty = probe the standard install path across a few known versions, in
  # order (this campaign's confirmed-working version, 37.0, first). Pass an
  # explicit value to pin one version.
  [string]$RsVars = '',
  [string]$BdsLib = '',

  [string]$OutDir,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

if ($Root -eq '') { $Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path }
$Manifest = Join-Path $Root 'Examples\Delphi\auto-validable.txt'
if (-not $OutDir) { $OutDir = Join-Path $Root 'Examples\Delphi\Win32\_gate' }
if (-not (Test-Path -LiteralPath $Manifest)) { Write-Host "::error::manifest not found: $Manifest"; exit 2 }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# ------------------------------------------------------------------ manifest
$rows = Get-Content -LiteralPath $Manifest | Where-Object { $_ -and ($_ -notmatch '^#') } | ForEach-Object {
  $p = $_ -split "`t"
  $note = ''
  if ($p.Length -ge 3) { $note = ($p[2..($p.Length - 1)] -join ' ') }
  [pscustomobject]@{ Path = $p[0]; Mode = $p[1]; Note = $note }
}

$tracked = @(git -C $Root ls-files 'Examples/Delphi/' | Where-Object { $_ -like '*.dproj' })
if ($tracked.Count -ne $rows.Count) {
  Write-Host ("::error::MANIFEST_DRIFT manifest_rows={0} tracked_dproj={1}" -f $rows.Count, $tracked.Count)
  $manifestPaths = @($rows | ForEach-Object { $_.Path })
  $missing = @($tracked | Where-Object { $manifestPaths -notcontains $_ })
  $extra = @($manifestPaths | Where-Object { $tracked -notcontains $_ })
  if ($missing) { Write-Host '  unregistered:'; $missing | ForEach-Object { Write-Host "    $_" } }
  if ($extra) { Write-Host '  manifest-only:'; $extra | ForEach-Object { Write-Host "    $_" } }
  exit 2
}

$modeSet = @('compile', 'run', 'defer', 'exclude')
foreach ($r in $rows) {
  if ($modeSet -notcontains $r.Mode) {
    Write-Host "::error::MANIFEST_INVALID -- unknown mode '$($r.Mode)' on row $($r.Path)"
    exit 2
  }
}

$compileN = @($rows | Where-Object { $_.Mode -eq 'compile' }).Count
$runN = @($rows | Where-Object { $_.Mode -eq 'run' }).Count
$deferN = @($rows | Where-Object { $_.Mode -eq 'defer' }).Count
$excludeN = @($rows | Where-Object { $_.Mode -eq 'exclude' }).Count
Write-Host ("compile={0} run={1} defer={2} exclude={3}" -f $compileN, $runN, $deferN, $excludeN)

if ($DryRun) { Write-Host '[dry-run] manifest valid; no msbuild invoked'; exit 0 }

# ------------------------------------------------------------- Delphi install
if ($RsVars -eq '') {
  $versionCandidates = @('37.0', '23.0', '22.0', '21.0', '20.0')
  $found = $versionCandidates | Where-Object {
    Test-Path -LiteralPath "C:\Program Files (x86)\Embarcadero\Studio\$_\bin\rsvars.bat"
  } | Select-Object -First 1
  if ($found) {
    $RsVars = "C:\Program Files (x86)\Embarcadero\Studio\$found\bin\rsvars.bat"
    if ($BdsLib -eq '') { $BdsLib = "C:\Program Files (x86)\Embarcadero\Studio\$found\lib" }
  }
}
if (-not (Test-Path -LiteralPath $RsVars)) { Write-Host "::error::rsvars.bat not found (looked at: $RsVars) -- Delphi RAD Studio is required"; exit 2 }
Write-Host "Using rsvars: $RsVars"

# ------------------------------------------------------------- sibling deps
# Root = <repo-clone>\... -> the sibling checkouts live one level above the
# repo clone (e.g. .modules\Janus -> .modules\MetaDbDiff, .modules\DataEngine, ...).
$ModulesDir = Split-Path -Parent $Root
$PinDir = Join-Path $ModulesDir $PinRel
if (-not (Test-Path -LiteralPath $PinDir)) {
  Write-Host "::warning::FluentSQL pin not found at $PinDir -- driver-dependent Examples will likely fail to link"
}

function Get-SubDirsWithPas([string]$root) {
  if (-not (Test-Path -LiteralPath $root)) { return @() }
  $withPas = Get-ChildItem -LiteralPath $root -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object {
    @(Get-ChildItem -LiteralPath $_.FullName -Filter *.pas -File -ErrorAction SilentlyContinue).Count -gt 0
  } | ForEach-Object { $_.FullName }
  return , $withPas
}

# Order matters: PIN first (must win over anything else), then the rest.
$ExtraAbsDirs = New-Object System.Collections.Generic.List[string]
if (Test-Path -LiteralPath $PinDir) {
  $ExtraAbsDirs.Add((Join-Path $PinDir 'Source\Core'))
  $ExtraAbsDirs.Add((Join-Path $PinDir 'Source\Drivers'))
}
foreach ($dep in @('MetaDbDiff', 'DataEngine', 'JsonFlow', 'ModernSyntax')) {
  $depSrc = Join-Path $ModulesDir "$dep\Source"
  foreach ($d in (Get-SubDirsWithPas $depSrc)) { $ExtraAbsDirs.Add($d) }
}
$horseSrc = Join-Path $ModulesDir 'Horse\src'
if (Test-Path -LiteralPath $horseSrc) { $ExtraAbsDirs.Add($horseSrc) }

# --------------------------------------------------------------- search path
# System.IO.Path.GetRelativePath is .NET Core-only; this script is invoked by
# `powershell` (Windows PowerShell 5.1 / .NET Framework) via the .cmd wrapper,
# where that method does not exist. Uri.MakeRelativeUri works on both.
function Get-RelativePathCompat([string]$fromDir, [string]$toPath) {
  $fromUri = New-Object System.Uri(($fromDir.TrimEnd('\') + '\'))
  $toUri = New-Object System.Uri($toPath)
  $relUri = $fromUri.MakeRelativeUri($toUri)
  $rel = [System.Uri]::UnescapeDataString($relUri.ToString())
  return $rel.Replace('/', '\')
}

function Get-UnitSearchPath([string]$dprojPath) {
  [xml]$xdoc = Get-Content -LiteralPath $dprojPath
  $nodes = $xdoc.SelectNodes("//*[local-name()='DCC_UnitSearchPath']")
  $acc = ''
  foreach ($nd in $nodes) { $acc = $nd.InnerText.Replace('$(DCC_UnitSearchPath)', $acc) }
  # String.Replace, never [regex]::Escape -- values contain parens and backslashes.
  $acc = $acc.Replace('$(BDSLIB)', $BdsLib)
  $acc = $acc.Replace('$(Platform)', 'Win32')
  $acc = $acc.Replace('$(Config)', 'Debug')

  $dprojDir = Split-Path -Parent $dprojPath
  $extraRel = $ExtraAbsDirs | ForEach-Object { Get-RelativePathCompat $dprojDir $_ }

  $entries = @($extraRel) + ($acc -split ';')
  $seen = New-Object 'System.Collections.Generic.HashSet[string]'
  $kept = New-Object System.Collections.ArrayList
  foreach ($entry in $entries) {
    $trimmed = $entry.Trim()
    if ($trimmed -eq '') { continue }
    $abs = if ([System.IO.Path]::IsPathRooted($trimmed)) { $trimmed } else { Join-Path $dprojDir $trimmed }
    try { $full = [System.IO.Path]::GetFullPath($abs) } catch { continue }
    if (-not (Test-Path -LiteralPath $full -PathType Container)) { continue }
    if (-not $seen.Add($full.ToLowerInvariant())) { continue }
    [void]$kept.Add($trimmed)
  }
  return ($kept -join ';')
}

# -------------------------------------------------------------------- build
$results = New-Object System.Collections.ArrayList
$failed = 0
foreach ($r in $rows) {
  if ($r.Mode -eq 'defer') {
    Write-Host ("[DEFERRED] {0} -- {1}" -f $r.Path, $r.Note)
    [void]$results.Add([pscustomobject]@{ Path = $r.Path; Result = 'DEFERRED'; Detail = $r.Note })
    continue
  }
  if ($r.Mode -eq 'exclude') {
    Write-Host ("[EXCLUDE]  {0} -- {1}" -f $r.Path, $r.Note)
    [void]$results.Add([pscustomobject]@{ Path = $r.Path; Result = 'EXCLUDE'; Detail = $r.Note })
    continue
  }

  $dprojAbs = Join-Path $Root $r.Path
  if (-not (Test-Path -LiteralPath $dprojAbs)) {
    Write-Host ("::error::dproj not found: {0}" -f $r.Path)
    [void]$results.Add([pscustomobject]@{ Path = $r.Path; Result = 'FAIL'; Detail = 'dproj not found' })
    $failed++
    continue
  }

  $usp = Get-UnitSearchPath $dprojAbs
  $label = if ($r.Mode -eq 'run') { '[run-mode reserved -- treated as compile]' } else { '[compile]' }
  Write-Host ("{0} {1}  (search path: {2} chars, {3} entries)" -f $label, $r.Path, $usp.Length, ($usp -split ';').Count)

  $safeName = ($r.Path -replace '[\\/: ]', '_')
  $bat = Join-Path $OutDir "build-$safeName.bat"
  $log = Join-Path $OutDir "build-$safeName.log"
  $dprojDir = Split-Path -Parent $dprojAbs
  $dprojName = Split-Path -Leaf $dprojAbs

  # Stale-binary guard: remember the newest .exe mtime under the project dir
  # before building, so an unchanged binary after a "successful" build is
  # caught rather than reported as a false PASS.
  $before = @(Get-ChildItem -LiteralPath $dprojDir -Recurse -Include *.exe -ErrorAction SilentlyContinue)
  $beforeMax = ($before | Measure-Object -Property LastWriteTimeUtc -Maximum).Maximum

  Set-Content -LiteralPath $bat -Encoding ASCII -Value @(
    '@echo off',
    "call `"$RsVars`" >nul",
    "cd /d `"$dprojDir`"",
    "msbuild `"$dprojName`" /t:Build /p:Config=Debug /p:Platform=Win32 /p:`"DCC_UnitSearchPath=$usp`" /v:minimal /nologo",
    'exit /b %ERRORLEVEL%'
  )
  cmd /c "`"$bat`"" > $log 2>&1
  $rc = $LASTEXITCODE

  $after = @(Get-ChildItem -LiteralPath $dprojDir -Recurse -Include *.exe -ErrorAction SilentlyContinue)
  $afterMax = ($after | Measure-Object -Property LastWriteTimeUtc -Maximum).Maximum
  $freshBinary = ($after.Count -gt 0) -and (($null -eq $beforeMax) -or ($afterMax -gt $beforeMax))

  if ($rc -eq 0 -and -not $freshBinary) {
    Write-Host '  ::warning:: exit=0 but no fresher .exe found -- stale-binary guard, treating as FAIL'
    $rc = 1
  }

  if ($rc -ne 0) {
    $errLines = @(Select-String -LiteralPath $log -Pattern 'error' -CaseSensitive:$false | Select-Object -First 5)
    Write-Host ("  FAIL exit={0}" -f $rc)
    $errLines | ForEach-Object { Write-Host ("    " + $_.Line.Trim()) }
    [void]$results.Add([pscustomobject]@{ Path = $r.Path; Result = 'FAIL'; Detail = (($errLines | ForEach-Object { $_.Line.Trim() }) -join ' | ') })
    $failed++
  }
  else {
    Write-Host '  PASS'
    [void]$results.Add([pscustomobject]@{ Path = $r.Path; Result = 'PASS'; Detail = '' })
  }
}

Write-Host ''
Write-Host ("summary: compiled_or_run={0} failed={1} deferred={2} excluded={3}" -f ($compileN + $runN - $failed), $failed, $deferN, $excludeN)
$results | Format-Table -AutoSize | Out-String | Write-Host

$csv = Join-Path $OutDir 'gate-results.csv'
$results | Export-Csv -Path $csv -NoTypeInformation
Write-Host "results: $csv"

exit $failed
