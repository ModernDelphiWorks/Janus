#!/usr/bin/env bash
# Janus — Auto-Validable Examples Build Gate (POSIX skeleton)
#
# Owner: round 65 / demand 5/8 / GitHub issue #188
#
# Delphi compilation requires Windows + RAD Studio; this script is a
# graceful no-op outside Git Bash for Windows. On Git Bash / MSYS, it
# delegates to build_auto_validable.cmd. Elsewhere, prints [skip] and
# exits 0 (cross-platform contributor convenience, ADR-005).

set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"

case "${OSTYPE:-}${MSYSTEM:-}" in
  *msys*|*MINGW*|*MSYS*|*cygwin*)
    cmd_path="${script_dir}/build_auto_validable.cmd"
    if [ ! -f "${cmd_path}" ]; then
      echo "::error::build_auto_validable.cmd not found at ${cmd_path}" >&2
      exit 2
    fi
    cmd_win="$(cygpath -w "${cmd_path}" 2>/dev/null || echo "${cmd_path}")"
    exec cmd.exe //c "${cmd_win}" "$@"
    ;;
  *)
    echo "[skip] auto-validable build gate not supported on this platform; Delphi compilation requires Windows"
    exit 0
    ;;
esac
