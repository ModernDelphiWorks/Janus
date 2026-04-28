#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# detect-orphan-fixtures.sh
#
# Purpose
#   Detect orphan DUnitX test fixtures: files in Test/Delphi/Tests/*.pas that
#   carry the [TestFixture] attribute but are NOT wired into the `uses` clause
#   of any of the 4 Janus test executors. Orphans never run during the suite,
#   so they accumulate undetected drift unless something cross-references the
#   fixture set against the executor `uses` clauses.
#
# Origin
#   Round 62 / demand 2/8 (audit-driven roadmap). Round 55 (#170, 26256a8) wired
#   7 orphan fixtures by hand after a manual audit found them; this script
#   automates that detection so future drift is caught before /verify closes.
#   See .local-readonly/janus_features_tests_examples_audit.md §1 risk #1.
#
# Inputs (hard-coded; relative to repo root)
#   Executors (4):
#     Test/Delphi/JanusSmoke.dpr
#     Test/Delphi/JanusRestHorse.dpr
#     Test/Delphi/JanusLiveBindings.dpr
#     Test/Delphi/JanusRESTHorseOracle.dpr
#   Fixture glob:
#     Test/Delphi/Tests/*.pas
#
#   JanusRESTHorseConsole.dpr is excluded by design (zero-endpoint runtime
#   demo, not a DUnitX test executor — ADR-007).
#
# Opt-out marker
#   A .pas file with `// orphan-detect: ignore` anywhere in its first 5 lines
#   is excluded from the candidate set, regardless of [TestFixture] presence.
#   Reserved as a forward-compat hatch for helper / base / model files (ADR-003).
#
# {$IFDEF} treatment
#   All identifiers inside `uses` are treated as referenced, including those
#   guarded by {$IFDEF}...{$ENDIF}. Skews toward false-negative over false-
#   positive (ADR-004 / BR-003).
#
# Exit codes
#   0 = clean (zero orphans).
#   1 = one or more orphans found.
#   2 = inputs missing (any executor not found, or fixture glob empty).
#
# Output
#   stdout: orphan basenames, one per line, sorted (empty when clean).
#   stderr: canonical summary `<N> orphan fixtures across 4 executors`.
#
# Properties
#   Read-only. No flags. Deterministic across runs. < 1 s on warm cache.
# ------------------------------------------------------------------------------

set -euo pipefail

EXECUTORS=(
  "Test/Delphi/JanusSmoke.dpr"
  "Test/Delphi/JanusRestHorse.dpr"
  "Test/Delphi/JanusLiveBindings.dpr"
  "Test/Delphi/JanusRESTHorseOracle.dpr"
)
FIXTURE_GLOB="Test/Delphi/Tests/*.pas"
OPT_OUT_MARKER='orphan-detect: ignore'

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

REFERENCED="$TMPDIR/referenced.txt"
CANDIDATES="$TMPDIR/candidates.txt"
: > "$REFERENCED"
: > "$CANDIDATES"

# Step 1 — verify executors exist
for dpr in "${EXECUTORS[@]}"; do
  if [[ ! -f "$dpr" ]]; then
    echo "ERROR: missing executor $dpr" >&2
    exit 2
  fi
done

# Step 2 — verify fixture glob is non-empty
shopt -s nullglob
fixtures=( $FIXTURE_GLOB )
shopt -u nullglob
if [[ ${#fixtures[@]} -eq 0 ]]; then
  echo "ERROR: fixture glob $FIXTURE_GLOB matched no files" >&2
  exit 2
fi

# Step 3 — extract referenced unit names from each executor's `uses` block.
# Strip `///` and `//` line comments before scanning. Match `<Unit> in '<path>'`
# tokens; capture the unit identifier (first column).
awk '
  FNR == 1 { in_uses = 0 }
  /^[[:space:]]*uses([[:space:]]|$)/ { in_uses = 1 }
  in_uses {
    line = $0
    sub(/\/\/.*$/, "", line)
    while (match(line, /[A-Za-z_][A-Za-z0-9_.]*[[:space:]]+in[[:space:]]+'\''[^'\'']+'\''/)) {
      tok = substr(line, RSTART, RLENGTH)
      sub(/[[:space:]]+in[[:space:]].*$/, "", tok)
      print tok
      line = substr(line, RSTART + RLENGTH)
    }
  }
  in_uses && /;[[:space:]]*$/ { in_uses = 0 }
' "${EXECUTORS[@]}" >> "$REFERENCED"

sort -u -o "$REFERENCED" "$REFERENCED"

# Step 4 — build candidate set. A candidate is a *.pas file with [TestFixture]
# (case-insensitive) AND no opt-out marker in its first 5 lines. Single awk
# pass over all fixtures to keep runtime under 1 s on Git Bash for Windows
# (per-file subprocess spawning is the dominant cost on that platform).
awk -v marker="$OPT_OUT_MARKER" '
  FNR == 1 { opted_out = 0; has_fixture = 0 }
  FNR <= 5 && index($0, marker) > 0 { opted_out = 1 }
  !opted_out && tolower($0) ~ /\[testfixture\]/ { has_fixture = 1 }
  ENDFILE {
    if (has_fixture && !opted_out) {
      n = split(FILENAME, parts, /[\/\\]/)
      base = parts[n]
      sub(/\.[Pp][Aa][Ss]$/, "", base)
      print base
    }
  }
' "${fixtures[@]}" >> "$CANDIDATES"

sort -u -o "$CANDIDATES" "$CANDIDATES"

# Step 5 — orphans = candidates ∖ referenced
ORPHANS="$TMPDIR/orphans.txt"
comm -23 "$CANDIDATES" "$REFERENCED" > "$ORPHANS"

cat "$ORPHANS"

count=$(wc -l < "$ORPHANS" | tr -d '[:space:]')
echo "${count} orphan fixtures across 4 executors" >&2

if [[ "$count" -eq 0 ]]; then
  exit 0
fi
exit 1
