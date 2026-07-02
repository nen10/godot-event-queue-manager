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
    log "running tools/ui_static_audit.py (--enforce: UI metric adoption M4, EQM-093)"
    python3 tools/ui_static_audit.py --enforce | tee "${OUT_DIR}/ui_static_audit.log" || PY_FAIL=1
  else
    log "skip ui_static_audit.py (not present yet)"
  fi
  if [[ -f tools/check_api_surface.py ]]; then
    log "running tools/check_api_surface.py (layer-aware API surface gate)"
    python3 tools/check_api_surface.py --self-test | tee "${OUT_DIR}/api_surface_selftest.log" || PY_FAIL=1
    if [[ "$UPDATE_GOLDEN" == "api_surface" ]]; then
      python3 tools/check_api_surface.py --update | tee "${OUT_DIR}/api_surface.log" || PY_FAIL=1
    else
      python3 tools/check_api_surface.py | tee "${OUT_DIR}/api_surface.log" || PY_FAIL=1
    fi
  fi
  if [[ -f tools/check_contract_coverage.py ]]; then
    log "running tools/check_contract_coverage.py (frozen-contract coverage gate, EQM-110)"
    python3 tools/check_contract_coverage.py --self-test | tee "${OUT_DIR}/contract_coverage_selftest.log" || PY_FAIL=1
    python3 tools/check_contract_coverage.py | tee "${OUT_DIR}/contract_coverage.log" || PY_FAIL=1
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
  # Import pass: class_name resolution requires the project to be imported once
  # to build .godot/global_script_class_cache.cfg. .godot/ is gitignored, so a
  # clean checkout must import every run before the script run can resolve globals.
  log "import pass (register global classes)"
  "$GODOT_BIN" --headless --path test_project --import \
    > "${OUT_DIR}/godot_import.log" 2>&1 || true

  log "running Godot headless test runner"
  # EQ_RUN_OUT (absolute) lets trace tests dump produced traces under traces/
  # for diff reporting on a golden mismatch (DETERMINISM_TRACE_TEST_POLICY §2/§6).
  GODOT_UPDATE_GOLDEN="$UPDATE_GOLDEN" EQ_RUN_OUT="${REPO_ROOT}/${OUT_DIR}" "$GODOT_BIN" --headless \
    --path test_project --script res://tests/run_all.gd \
    2>&1 | tee "${OUT_DIR}/godot_tests.log"
  if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then GODOT_FAIL=1; fi

  # Guard against masked failures: a broken test can exit 0 while a compile /
  # script error scrolled past. Treat those as failures. (Intentional invalid-
  # input checks must not emit these patterns; they use null returns, not errors.)
  if grep -qE "SCRIPT ERROR|Compile Error|Parse Error|Failed to load script" "${OUT_DIR}/godot_tests.log"; then
    log "Godot script/compile error detected in test output"
    GODOT_FAIL=1
  fi
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
