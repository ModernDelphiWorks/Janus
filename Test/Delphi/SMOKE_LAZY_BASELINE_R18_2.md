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

## Scenario-to-output traceability matrix

| Scenario group | Baseline scenarios | Expected deterministic output | Evidence in reports |
|---|---|---|---|
| ObjectSet lazy association contract | TestSmokeLazyLoading + TestObjectSetLazyProxy (deferred, invalid session, reset) | Console summary and NUnit XML include passing assertions for lazy association behavior | Implement and QA reports must map command output + XML artifact to ObjectSet scope |
| DataSet auto-lazy and proxy contract | TestDataSetAutoLazy + TestDataSetLazyProxy (scroll, pk change, cache, reset) | Console summary and NUnit XML include passing assertions for DataSet lazy routing and proxy lifecycle | Implement and QA reports must map command output + XML artifact to DataSet scope |
