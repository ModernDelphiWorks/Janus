---
name: verify
description: run fast per-task quality gates (static analysis, cyclomatic complexity, test coverage) on the active stacks. use after /test approves, before /develop, to catch regressions that /review cannot. produces verify-report.md. does not modify code. heavy gates (mutation testing, SonarCloud, CodeQL) live in GitHub Actions instead.
---

# Skill: Verify

Quality gatekeeper for local runs. Run three fast checks on the code changed in this task: static analysis, cyclomatic complexity, test coverage. Any failure against project thresholds → reject, return to `/implement`. Heavy gates (mutation, Sonar, CodeQL) run in CI when `/release` opens the PR — not your job.

## Output style

See `.claude/skills/references/output-style.md`.

## Cycle status

Final response must end with the mandatory closing line — see "Cycle status — pipeline-wide closing line" in `.claude/skills/references/pipeline-contract.md`.

- All gates PASSED, `verify-report.md` written → `▎ Cycle status: closed for handoff — next: /develop — demanda N/X.`
- Any gate FAILED (returns to `/implement`) → `▎ Cycle status: blocked — rejected — demanda N/X.`
- Anti-loop detected (second consecutive FAILED) → `▎ Cycle status: blocked — anti-loop — demanda N/X.`
- Skill invoked without `pipeline/test-report.md` (APPROVED) → `▎ Cycle status: blocked — meta query (no new demand to formalize) — demanda 0/0.`

Read `N/X` from `pipeline/task-input.md`. Single demand → `1/1`. Do not paraphrase.

## When to use

- After `/test` approves, before `/develop`.
- Inside `/hotfix` — only the `static` layer, inline (see hotfix skill).
- Never rerun inside the `/review` ↔ `/implement` rejection loop.
- Per-task and per-batch: `/verify` → `/develop`.

## Mandatory reading

Consult `.claude/skills/references/pipeline-contract.md` for shared rules.

Read in order:
1. `.claude/SKILL.md` — `Active stacks` and `Quality thresholds`
2. `.claude/pipeline/task.md` — scope
3. `.claude/pipeline/implement-report.md` — changed files
4. `.claude/pipeline/test-report.md` — must be APPROVED or APPROVED WITH CAVEATS

`test-report.md` REJECTED or missing → stop. Do not run verify.

Load language rules via `.claude/skills/references/stack-detection.md` — only active stacks.

Tool commands per stack live in `.claude/skills/references/verify-tools-matrix.md`.

## What to do

### 0. Readiness sentinel — install only if needed

Sentinel file: `.claude/pipeline/.verify-ready` (one line: `active_stacks=<sorted,comma,list>`).

```bash
CURRENT=$(read Active stacks from .claude/SKILL.md, sort alphabetically, join with commas)
SENTINEL=.claude/pipeline/.verify-ready

if [ -f "$SENTINEL" ] && grep -q "^active_stacks=$CURRENT$" "$SENTINEL"; then
    # Tools already installed for this stack set → skip to Step 1.
    :
else
    # First run, or Active stacks changed → install.
    # Self-heal: if install script is missing, generate it from the matrix
    # before running. Never stop /verify just because the script is absent.
    if [ ! -f scripts/install-verify.sh ] && [ ! -f scripts/install-verify.ps1 ]; then
        # Generate both scripts from .claude/skills/references/verify-tools-matrix.md
        # → "Install snippets per stack" section, concatenating only the
        # snippets for stacks present in CURRENT. Do not invent commands;
        # copy them verbatim from the matrix.
        mkdir -p scripts
        emit scripts/install-verify.sh   (bash header  + concatenated bash snippets)
        emit scripts/install-verify.ps1  (pwsh header  + concatenated pwsh snippets)
        chmod +x scripts/install-verify.sh
    fi
    if [ -f scripts/install-verify.sh ]; then
        bash scripts/install-verify.sh
    else
        pwsh scripts/install-verify.ps1
    fi
    echo "active_stacks=$CURRENT" > "$SENTINEL"
fi
```

The sentinel lives in `.claude/pipeline/` (already gitignored as pipeline infrastructure). Do not commit it.

Run install script only when sentinel is absent or mismatches current Active stacks. From the second run onward, Step 0 is a single file-existence check — no token waste on tool detection.

Install fails → stop, surface stderr to the user, do not write the sentinel. Next run will retry.

### 1. Resolve stacks and thresholds

Read `Active stacks` from `.claude/SKILL.md`. For each stack, consult `verify-tools-matrix.md` for static/complexity/coverage commands.

Read `Quality thresholds` from `.claude/SKILL.md`. Section absent → use defaults:

| Gate | Default |
|------|---------|
| Static analysis errors | 0 (warnings allowed, counted) |
| Cyclomatic complexity max per function | 10 |
| Test coverage | 80% |

### 1.5. Delphi pre-check (only when `delphi` is an active stack)

Before running any Delphi analysis, verify infrastructure is ready. Read `.claude/skills/references/delphi-verify-environment.md` for full setup context.

**a) Locate `projectKey`** — read from `.claude/SKILL.md` → `SonarQube Config` section (field `projectKey`). Section absent → derive from repository name (lowercase, no spaces).

**b) Check properties file exists:**

```powershell
$key = "<projectKey>"
$props = "D:\Delphi Tools\sonar-projects\$key.properties"
Test-Path $props
```

File **does not exist** → **BLOCKED — Human action required**. Do not continue Delphi analysis. Surface this message:

> **Action required:** Create `D:\Delphi Tools\sonar-projects\<projectKey>.properties` before running `/verify` for this project.
> Use any existing file in `D:\Delphi Tools\sonar-projects\` as the template.
> Adjust `sonar.projectKey`, `sonar.projectName`, `sonar.sources`, `sonar.tests` for this project.
> Full template and lessons learned: `.claude/skills/references/delphi-verify-environment.md` → Section 4.
> **The agent cannot create this file** — it lives outside the project directory and requires manual creation.

Write `verify-report.md` with verdict `BLOCKED` (not FAILED), gate `delphi-sonar-config`, and the instructions above.

**c) Check SonarQube Docker container is running:**

```powershell
docker ps --filter "name=sonarqube-delphi" --format "{{.Status}}"
```

Container not running → instruct user to run `docker start sonarqube-delphi` and retry. Surface as `BLOCKED`, same pattern as above.

Proceed to Step 2 only when both checks pass.

---

### 2. Run static analysis

Per active stack, run commands from the tools matrix. Capture full output. Count `errors` and `warnings`.

- Errors > 0 → FAILED.
- Warnings → recorded, non-blocking.

### 3. Run complexity check

Use `lizard` (language-agnostic) unless the matrix specifies a language-native tool. Run against changed files only (from `implement-report.md`).

```bash
lizard --CCN <threshold> <changed files>
```

Any function above threshold → FAILED (list each).

### 4. Run coverage

Rerun project's coverage command from `.claude/SKILL.md` / `verify-tools-matrix.md`. Measure coverage **on changed files**, not whole project.

Below threshold → FAILED.

### 5. Aggregate verdict

- All three PASSED → verdict `PASSED`.
- Any FAILED → verdict `FAILED`.

### 6. Report in `.claude/pipeline/verify-report.md`

Use the `verify-report.md` template in `.claude/skills/references/report-templates.md`. Full-file write, never append. Exactly one issue identity per run.

### 7. Final summary

State the verdict and the gate that failed (if any). FAILED → leave actionable prompt for `/implement`.

PASSED → next step is `/develop`.

## Anti-loop

Same rule as `/review` and `/test`: previous `verify-report.md` shows FAILED for the same issue and new run is also FAILED → mark **BLOCKED**, escalate. Do not attempt a third correction.

## Rules

- No code modifications. Only run checks and report.
- Load rules only via `stack-detection.md` — never read every `.claude/rules/*` folder.
- Tool still missing after Step 0's install script ran → mark the specific layer as `TOOL_MISSING` in the report, stop. Do not treat `TOOL_MISSING` as PASSED or FAILED. User fixes the install script or installs manually.
- `scripts/install-verify.{sh,ps1}` missing → never block. Generate both from `verify-tools-matrix.md` → `Install snippets per stack` for the current Active stacks, then run. Do not ask the user to run `/bootstrap update` first.
- Thresholds come from `.claude/SKILL.md` → `Quality thresholds`. Never invent.
- REJECTED from `/verify` means code needs work — not that tests are wrong. Redirect to `/implement` only.
- Do not run heavy gates (mutation, Sonar, CodeQL) — those live in `.github/workflows/quality.yml` and fire when `/release` opens the PR.
