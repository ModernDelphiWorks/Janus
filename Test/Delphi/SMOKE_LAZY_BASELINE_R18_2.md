# R18.2 Smoke Baseline - Transparent Lazy Loading

## Purpose

Define an expanded but bounded smoke baseline for ObjectSet and DataSet lazy-loading paths, reusing the fixture models under Examples/Delphi/Data/Object Lazy.

## Fixture references

- Examples/Delphi/Data/Object Lazy/Model.Exame.pas
- Examples/Delphi/Data/Object Lazy/Model.Procedimento.pas
- Examples/Delphi/Data/Object Lazy/Model.Setor.pas

## Smoke matrix

| Context | Unit | Scenario | Expected result |
|---|---|---|---|
| ObjectSet | TestSmokeLazyLoading | Mapping has lazy association for TExame | At least one association with Lazy=True |
| ObjectSet | TestObjectSetLazyProxy | Deferred proxy before invoke | IsValueCreated=False before first Invoke |
| ObjectSet | TestObjectSetLazyProxy | Invalidated session | Invoke raises ELazyLoadException |
| ObjectSet | TestObjectSetLazyProxy | Reset and re-injection | Reset clears value and next Invoke loads new instance |
| DataSet | TestDataSetAutoLazy | Scroll skips lazy children | Lazy associations are detectable and routed to proxy injection |
| DataSet | TestDataSetAutoLazy | PK change behavior | PK change triggers reset/re-injection path |
| DataSet | TestDataSetLazyProxy | Deferred lazy proxy | Proxy is not loaded at creation |
| DataSet | TestDataSetLazyProxy | Cache behavior | First Invoke caches and reuses value |
| DataSet | TestDataSetLazyProxy | Reset behavior | Reset causes a new factory execution |

## Deterministic evidence contract

1. Canonical command
- Run from Test/Delphi: JanusSmoke.exe --exitbehavior:Continue --xmlfile:dunitx-results.xml

2. XML output preconditions
- Execute from Test/Delphi so dunitx-results.xml resolves to a deterministic local path.
- If a custom xmlfile path contains directories, create and validate the target directory before execution.
- If the output directory cannot be created or validated, stop and record the caveat as environment-bound evidence.

3. Output artifact
- Test/Delphi/dunitx-results.xml

4. Traceability expectations
- Report the exact canonical command used.
- Report generated artifact path and existence result.
- Map failed/passed tests to acceptance criteria in pipeline reports.
- Ensure modified-files section in reports matches the tracked git diff.

## R18.4 portability hardening — Path strategy declaration

Every evidence-producing run must explicitly declare which path strategy was used. Evidence that omits the path strategy declaration must be rejected at review and QA gates.

### Strategy A — Default relative path (run-directory-relative)

```
cd Test/Delphi
JanusSmoke.exe --exitbehavior:Continue --xmlfile:dunitx-results.xml
```

- XML resolves to: `Test/Delphi/dunitx-results.xml`
- Precondition: the working directory must be `Test/Delphi` before execution.
- Known caveat: may raise `EInOutError: Unable to create directory` in environments where the working directory path contains restricted segments. If this occurs, fallback to Strategy B.
- Evidence declaration required: `PATH_STRATEGY=relative; ARTIFACT=Test/Delphi/dunitx-results.xml; exists=<true|false>`

### Strategy B — Explicit target path (pre-created directory)

```powershell
$targetDir = "<absolute-path>\<target-dir>"
if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir | Out-Null }
cd Test/Delphi
JanusSmoke.exe --exitbehavior:Continue --xmlfile:"$targetDir\dunitx-results.xml"
```

- XML resolves to the explicit `$targetDir\dunitx-results.xml`.
- Precondition: target directory must exist before invoking JanusSmoke.exe. Agent must create it and confirm existence.
- Fallback declaration required when Strategy A fails: record reason and confirm target directory was created successfully.
- Evidence declaration required: `PATH_STRATEGY=explicit; ARTIFACT=<absolute-path>; exists=<true|false>`

### Fallback rule

If Strategy A raises `EInOutError` or produces no XML artifact: switch to Strategy B, record the caveat, and map it to the evidence declaration. Do not silently accept exit code `0` as sufficient evidence when XML artifact is absent or unverifiable.

## Scenario-to-output traceability matrix

| Scenario group | Baseline scenarios | Expected deterministic output | Evidence in reports |
|---|---|---|---|
| ObjectSet lazy association contract | TestSmokeLazyLoading + TestObjectSetLazyProxy (deferred, invalid session, reset) | Console summary and NUnit XML include passing assertions for lazy association behavior | Implement and QA reports must map command output + XML artifact to ObjectSet scope |
| DataSet auto-lazy and proxy contract | TestDataSetAutoLazy + TestDataSetLazyProxy (scroll, pk change, cache, reset) | Console summary and NUnit XML include passing assertions for DataSet lazy routing and proxy lifecycle | Implement and QA reports must map command output + XML artifact to DataSet scope |

## R18.5 — ESP-003 bug fix: relative-path EInOutError and exit code hardening

### Problem corrected

Three failure modes were confirmed when running Strategy A (canonical relative-path command) in certain environments:

1. `EInOutError: Unable to create directory` raised by `TDUnitXXMLNUnitFileLogger.Create()` during XML logger initialization.
2. Exit code `0` returned despite the exception — silent false-positive success because the `except` block did not set `ExitCode := EXIT_FAILURE`.
3. Stale XML artifact risk: a prior artifact could be accepted as fresh evidence because no timestamp check was performed.

### Fix applied in `JanusSmoke.dpr` (issue #113)

| Fix | Mechanism |
|-----|-----------|
| Relative-path directory creation | Before `TDUnitXXMLNUnitFileLogger.Create`, resolve the full XML output path with `TPath.GetFullPath`, extract the directory component, and call `TDirectory.CreateDirectory` if the directory does not yet exist. |
| Exit code on exception | `except` handler now explicitly sets `System.ExitCode := EXIT_FAILURE` before printing the exception message. Default `ExitCode=0` false-positive eliminated. |
| Artifact existence check | After `LRunner.Execute`, verify the XML file exists at the resolved full path. If absent, print `EVIDENCE ERROR` and set `EXIT_FAILURE`. |
| Artifact freshness check | After `LRunner.Execute`, verify `TFile.GetLastWriteTime(LXmlOutputFile) >= LRunStartTime` (recorded at the start of the try block). If the artifact timestamp predates the run start, print `EVIDENCE ERROR` (stale artifact) and set `EXIT_FAILURE`. |

### Updated evidence rules

After R18.5, the following rules apply to all evidence-producing smoke runs:

1. **Artifact must exist**: any run that does not produce a non-empty XML artifact at the declared path is treated as FAILED, regardless of console output.
2. **Artifact must be fresh**: the XML file's last-write timestamp must be greater than or equal to `LRunStartTime` captured at the beginning of the run. A stale artifact from a prior run is never accepted as valid evidence.
3. **Exit code must be non-zero on failure**: any exception during harness setup, logger creation, or test execution yields `EXIT_FAILURE` (exit code 1). Exit code 0 now reliably means all tests passed AND a fresh XML artifact was produced.
4. **Strategy A is now the canonical path after this fix**: reports must still declare `PATH_STRATEGY=relative` or `PATH_STRATEGY=explicit` as required by R18.4.

### Strategy A freshness evidence declaration (post-R18.5)

```
PATH_STRATEGY=relative
ARTIFACT=Test/Delphi/dunitx-results.xml
exists=<true|false>
fresh=<true|false>   ← NEW: must be true for valid evidence
EXIT_CODE=<0|1>
```

### Fallback rule update

If Strategy A still fails after the R18.5 fix is compiled and deployed, fallback to Strategy B remains valid. Record `PATH_STRATEGY=explicit` and the stale/absent artifact diagnosis. Do not accept exit code 0 as valid evidence when the fresh= declaration cannot be confirmed.
