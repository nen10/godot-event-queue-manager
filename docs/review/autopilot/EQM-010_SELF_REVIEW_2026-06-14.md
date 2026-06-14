# EQM-010 Self-Review 2026-06-14

Pattern: P0 (linear autopilot, orchestrator-direct). Repair: 1 iteration (headless class_name resolution).

## Execution summary

Defined the core event entry (EQEntry) and the deterministic total order (EQOrdering), and established the headless test framework (discovering runner + assert helper) that later core tasks reuse.

## Changed files

- `addons/event_queue_manager/runtime/eq_entry.gd` — `EQEntry`: keys (due_tick, priority, sequence) + identity (event_id, generation) + kind/actor/payload; `make()` (null on negative tick), `to_dict()`/`from_dict()`.
- `addons/event_queue_manager/runtime/eq_ordering.gd` — `EQOrdering.less_than` / `sort` (due_tick ASC, priority DESC, sequence ASC).
- `test_project/tests/eq_test.gd` — assert collector (loaded by path).
- `test_project/tests/run_all.gd` — rewritten to discover `tests/**/test_*.gd` (sorted) and call `static run(t)`.
- `test_project/tests/core/test_scaffold.gd` — EQM-002 smoke moved into the runner.
- `test_project/tests/core/test_eq_ordering.gd` — 9 checks: key precedence, total order, permutation invariance, tick validity.
- `tools/test.sh` — import pass (register globals) + masked-failure guard (fail on compile/script errors despite exit 0).

## Acceptance result — met

| acceptance | result |
|---|---|
| due_tick asc, priority desc, sequence asc | pairwise + full-sort checks |
| stable tie-breaking | permutation invariance check (sequence makes order total) |
| invalid negative tick rejection | `make(-1) == null`, `make(0) != null` |

## Test summary

```text
./tools/test.sh (clean, .godot/ removed) -> import pass -> RESULT: PASS (exit 0)
  [run_all] files=2 checks=9 failures=0
```

Classification: `passed`.

## Repair record (gate REJECT → fix, attempt 1/3)

- Symptom: `class_name EQEntry` self-reference failed to compile in a fresh headless project ("Identifier not found: EQEntry"); the runner masked it as PASS.
- Root cause: global class_name registration requires a project import pass; `.godot/` is gitignored so a fresh run had none.
- Fix: (a) `tools/test.sh` does `--import` before the runner; (b) `tools/test.sh` greps the run output for `SCRIPT ERROR|Compile Error|Parse Error|Failed to load script` and fails even on exit 0 (closes the masking hole); (c) dropped the intentional `push_error` from `EQEntry.make` so "any error in output = real problem" stays a clean gate signal.

## Deviations

- Scope additions beyond the listed target files: `tools/test.sh` (import pass + guard) and `test_project/tests/run_all.gd` (discovering runner) — justified: this is the first task with real tests, so the framework had to be established here (PROJECT_PROFILE scope control).

## No sample-only completion

Tests assert the ordering contract directly; no claim rests on a bundled sample.

## Repair-now / follow-up

None blocking. Next: EQM-011 (scheduler operations) unblocked.
