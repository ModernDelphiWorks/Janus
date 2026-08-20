@echo off
REM Janus -- Auto-Validable Examples Build Gate (Windows worker)
REM
REM Owner:    round 65 / demand 5/8 / GitHub issue #188; cured for #190
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
REM
REM #190: this wrapper used to embed its own throwaway PowerShell (written via
REM a heredoc of "echo" lines into a temp .ps1) that ran msbuild with the
REM .dproj's OWN DCC_UnitSearchPath, absolutized by nothing in particular --
REM which is exactly what produced MSB6003 "filename or extension is too
REM long" locally (see issue #190). The real gate logic -- relative search
REM paths, sibling-dependency resolution, Test-Path pruning, the FluentSQL
REM pin, the stale-binary guard -- now lives in the versioned, independently
REM runnable build-examples-gate.ps1 next to this file, so local runs and CI
REM runs exercise the identical script instead of two hand-maintained copies.

setlocal EnableDelayedExpansion
set "SCRIPT_DIR=%~dp0"

set "PS_ARGS="
if /I "%~1"=="--dry-run" set "PS_ARGS=-DryRun"

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%build-examples-gate.ps1" %PS_ARGS%
set "EXITCODE=%ERRORLEVEL%"
endlocal & exit /b %EXITCODE%
