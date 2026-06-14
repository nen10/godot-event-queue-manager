#!/usr/bin/env bash
# Event Queue Manager — standard verification harness.
#
# Exit codes:
#   0  all runnable checks passed
#   1  a check failed
#   3  BLOCKED_BY_TEST_ENV (a required tool such as Godot is missing)
#
# Output goes under a run-specific, ignored directory:
#   .godot_user/test-runs/<run-id>/
# Never writes to a shared log or a fixed resource path.
#
# Usage:
#   ./tools/test.sh                      run all available checks
#   ./tools/test.sh --update-golden <c>  explicit golden re-baseline (see DETERMINISM_TRACE_TEST_POLICY.md)

set -uo pipefail

EXIT_OK=0
EXIT_FAIL=1
EXIT_BLOCKED=3

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

RUN_ID="$(date +%Y%m%d-%H%M%S)-$$"
OUT_DIR=".godot_user/test-runs/${RUN_ID}"
mkdir -p "$OUT_DIR"

UPDATE_GOLDEN=""
if [[ "${1:-}" == "--update-golden" ]]; then
  UPDATE_GOLDEN="${2:-}"
  if [[ -z "$UPDATE_GOLDEN" ]]; then
    echo "ERROR: --update-golden requires a <case> argument" >&2
    exit "$EXIT_FAIL"
  fi
fi

log() { echo "[test.sh] $*"; }

# --- locate Godot --------------------------------------------------------
GODOT_BIN=""
for cand in "${GODOT:-}" godot godot4; do
  [[ -z "$cand" ]] && continue
  if command -v "$cand" >/dev/null 2>&1; then GODOT_BIN="$cand"; break; fi
done

log "run-id: ${RUN_ID}"
log "output: ${OUT_DIR}"

# --- python-only checks (run regardless of Godot) ------------------------
PY_FAIL=0
if command -v python3 >/dev/null 2>&1; then
  if [[ -f tools/ui_static_audit.py ]]; then
    log "running tools/ui_static_audit.py"
    python3 tools/ui_static_audit.py | tee "${OUT_DIR}/ui_static_audit.log" || PY_FAIL=1
  else
    log "skip ui_static_audit.py (not present yet)"
  fi
else
  log "skip python checks (python3 not found)"
fi

# --- Godot headless tests ------------------------------------------------
if [[ -z "$GODOT_BIN" ]]; then
  log "BLOCKED_BY_TEST_ENV: Godot not found (set \$GODOT, or put 'godot'/'godot4' on PATH)."
  log "Docs-only and Python-only checks above still ran; Godot test paths could not."
  echo "BLOCKED_BY_TEST_ENV" > "${OUT_DIR}/status"
  exit "$EXIT_BLOCKED"
fi

log "godot: $($GODOT_BIN --version 2>/dev/null || echo unknown)"

GODOT_FAIL=0
RUNNER="test_project/tests/run_all.gd"
if [[ -f "$RUNNER" ]]; then
  log "running Godot headless test runner"
  GODOT_UPDATE_GOLDEN="$UPDATE_GOLDEN" "$GODOT_BIN" --headless \
    --path test_project --script res://tests/run_all.gd \
    | tee "${OUT_DIR}/godot_tests.log" || GODOT_FAIL=1
else
  log "skip Godot tests (${RUNNER} not present yet)"
fi

# --- verdict -------------------------------------------------------------
if [[ "$PY_FAIL" -ne 0 || "$GODOT_FAIL" -ne 0 ]]; then
  log "RESULT: FAIL"
  echo "FAIL" > "${OUT_DIR}/status"
  exit "$EXIT_FAIL"
fi

log "RESULT: PASS"
echo "PASS" > "${OUT_DIR}/status"
exit "$EXIT_OK"
