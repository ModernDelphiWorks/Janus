@echo off
REM Janus -- Auto-Validable Examples Build Gate (Windows worker)
REM
REM Owner:    round 65 / demand 5/8 / GitHub issue #188
REM Manifest: Examples/Delphi/auto-validable.txt
REM
REM Usage:
REM   build_auto_validable.cmd            run the gate (compile each row)
REM   build_auto_validable.cmd --dry-run  parse manifest only; no msbuild
REM
REM Exit codes:
REM   0  success -- all compile/run rows built (or --dry-run parsed cleanly)
REM   N  N compile/run rows failed
REM   2  MANIFEST_DRIFT or MANIFEST_INVALID

setlocal EnableDelayedExpansion
set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%..\..\.." >nul

set "PSFILE=%TEMP%\janus_auto_validable_%RANDOM%.ps1"
> "%PSFILE%" (
  echo $ErrorActionPreference = 'Stop'
  echo $manifest = 'Examples/Delphi/auto-validable.txt'
  echo if ^(-not ^(Test-Path $manifest^)^) { Write-Host ^('::error::manifest not found: ' + $manifest^); exit 2 }
  echo $rows = Get-Content $manifest ^| Where-Object { $_ -and ^($_ -notmatch '^^#'^) } ^| ForEach-Object {
  echo     $p = $_ -split ^([char]9^)
  echo     $note = ''
  echo     if ^($p.Length -ge 3^) { $note = ^($p[2..^($p.Length-1^)] -join ' '^) }
  echo     [pscustomobject]@{ Path = $p[0]; Mode = $p[1]; Note = $note }
  echo }
  echo $tracked = @^(^&git ls-files 'Examples/Delphi/' ^| Where-Object { $_ -like '*.dproj' }^)
  echo if ^($tracked.Count -ne $rows.Count^) {
  echo     Write-Host ^('::error::MANIFEST_DRIFT manifest_rows={0} tracked_dproj={1}' -f $rows.Count, $tracked.Count^)
  echo     $manifestPaths = @^($rows ^| ForEach-Object { $_.Path }^)
  echo     $missing = @^($tracked ^| Where-Object { $manifestPaths -notcontains $_ }^)
  echo     $extra   = @^($manifestPaths ^| Where-Object { $tracked -notcontains $_ }^)
  echo     if ^($missing^) { Write-Host '  unregistered:'; $missing ^| ForEach-Object { Write-Host ^('    ' + $_^) } }
  echo     if ^($extra^)   { Write-Host '  manifest-only:'; $extra ^| ForEach-Object { Write-Host ^('    ' + $_^) } }
  echo     exit 2
  echo }
  echo $compile = @^($rows ^| Where-Object { $_.Mode -eq 'compile' }^).Count
  echo $run     = @^($rows ^| Where-Object { $_.Mode -eq 'run'     }^).Count
  echo $defer   = @^($rows ^| Where-Object { $_.Mode -eq 'defer'   }^).Count
  echo $exclude = @^($rows ^| Where-Object { $_.Mode -eq 'exclude' }^).Count
  echo Write-Host ^('compile={0} run={1} defer={2} exclude={3}' -f $compile, $run, $defer, $exclude^)
  echo if ^(^($compile + $run + $defer + $exclude^) -ne $rows.Count^) { Write-Host '::error::MANIFEST_INVALID -- unknown mode in some row'; exit 2 }
  echo $dry = $args -contains '--dry-run'
  echo if ^($dry^) { Write-Host '[dry-run] manifest valid; no msbuild invoked'; exit 0 }
  echo $rsvarsCandidates = @^(
  echo     'C:\Program Files ^(x86^)\Embarcadero\Studio\23.0\bin\rsvars.bat',
  echo     'C:\Program Files ^(x86^)\Embarcadero\Studio\22.0\bin\rsvars.bat',
  echo     'C:\Program Files ^(x86^)\Embarcadero\Studio\21.0\bin\rsvars.bat',
  echo     'C:\Program Files ^(x86^)\Embarcadero\Studio\20.0\bin\rsvars.bat'
  echo ^)
  echo $rsvars = $rsvarsCandidates ^| Where-Object { Test-Path $_ } ^| Select-Object -First 1
  echo if ^(-not $rsvars^) { Write-Host '::error::rsvars.bat not found -- Delphi RAD Studio is required'; exit 2 }
  echo Write-Host ^('Using rsvars: ' + $rsvars^)
  echo $built = 0; $failed = 0; $deferred = 0; $excluded = 0
  echo foreach ^($r in $rows^) {
  echo     if ^($r.Mode -eq 'compile' -or $r.Mode -eq 'run'^) {
  echo         if ^($r.Mode -eq 'run'^) { Write-Host ^('[run-mode reserved -- treated as compile] ' + $r.Path^) } else { Write-Host ^('[compile] ' + $r.Path^) }
  echo         $line = ^('call "{0}" ^&^& msbuild "{1}" /t:Build /p:Config=Debug /p:Platform=Win32 /verbosity:minimal' -f $rsvars, $r.Path^)
  echo         ^&cmd /c $line
  echo         if ^($LASTEXITCODE -ne 0^) { Write-Host ^('::error::compile failed: ' + $r.Path^); $failed++ } else { $built++ }
  echo     } elseif ^($r.Mode -eq 'defer'^) {
  echo         Write-Host ^('[DEFERRED] {0} -- {1}' -f $r.Path, $r.Note^); $deferred++
  echo     } elseif ^($r.Mode -eq 'exclude'^) {
  echo         Write-Host ^('[EXCLUDE]  {0} -- {1}' -f $r.Path, $r.Note^); $excluded++
  echo     } else {
  echo         Write-Host ^('::error::unknown mode "{0}" on row {1}' -f $r.Mode, $r.Path^); exit 2
  echo     }
  echo }
  echo Write-Host ^('summary: compiled={0} failed={1} deferred={2} excluded={3}' -f $built, $failed, $deferred, $excluded^)
  echo exit $failed
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PSFILE%" %*
set "EXITCODE=%ERRORLEVEL%"
del /q "%PSFILE%" >nul 2>&1
popd >nul
endlocal & exit /b %EXITCODE%
