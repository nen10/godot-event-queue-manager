# EQM-013 Self-Review 2026-06-14

Pattern: P0 (linear autopilot, orchestrator-direct). Repair: 1 iteration (test-only param type-inference fix; no product-code change).

## Execution summary

Established the canonical trace export (`EQTrace`) and the determinism harness: a golden approval gate plus property/metamorphic tests over the scheduler. Traces are JSONL with one resolved-event record per line, int-only ordering keys, a resolution index `i`, and a structured `tie_break` (explanation-as-data). The canonical encoder sorts keys recursively, so output is byte-identical for identical input, has a fixed key order, and — crucially — keeps the record-kind schema open: later phases add kinds by passing new fields with no harness change. The golden fixture is re-baselined only via the explicit `--update-golden` flag.

## Changed files

- `addons/event_queue_manager/runtime/eq_trace.gd` — `EQTrace`: generic `record(fields)` (assigns `i`), `record_resolved`, canonical `to_jsonl` (recursive key-sort encoder; float → dev fail-fast), `records`, `size`, static `trace_run` / `_decided_by`.
- `tools/test.sh` — exports `EQ_RUN_OUT` (absolute run-output dir) to the Godot runner so trace tests can dump the produced trace under `traces/` on a golden mismatch (diff reporting, policy §2/§6). Existing `--update-golden` plumbing reused unchanged.
- `test_project/tests/golden/core_scheduler_basic.trace.jsonl` — golden fixture (5-record scenario), created via the explicit flag.
- `test_project/tests/core/test_eq_trace_golden.gd` — golden approval gate; read-only compare on normal runs, write only when `GODOT_UPDATE_GOLDEN == core_scheduler_basic`; dumps actual on mismatch.
- `test_project/tests/core/test_eq_trace_properties.gd` — replay determinism, permutation invariance, snapshot continuity, decided_by integrity, open record-kind schema.

## Acceptance result — met

| acceptance | result |
|---|---|
| same-seed replay → byte-identical trace | `_build_seeded(42)` twice → identical JSONL; seed 43 → different |
| insertion permutation with identical keys preserves pop order | same fixed entries inserted forward vs reversed → identical `ordered()` (= EQOrdering total order) |
| snapshot continuity holds | interrupted (snapshot/restore mid-run) trace == uninterrupted trace, byte-for-byte |
| golden update only via explicit flag | normal run compares read-only; write gated on `GODOT_UPDATE_GOLDEN == case`; per-policy procedure |
| trace-record-kind schema open/extensible | `event_line_progressed` / `window_opened` (kinds the scheduler never emits today) serialize canonically with no harness change; asserted byte-exact |

Additional (policy §4 explanation-as-data): `tie_break.decided_by` matches the comparator across all branches — due_tick / priority / sequence / terminal — and `compared` lists the int ordering keys.

## Golden baseline record (policy §2)

- Case `core_scheduler_basic`: **initial baseline** (no prior fixture). Created with `./tools/test.sh --update-golden core_scheduler_basic`.
- Content rationale: a fixed 5-push scenario (hero atk, orc atk@p5, hero move@t4, mage cast@t20→reschedule→t6, goblin atk@p5) chosen to exercise every `decided_by` branch in one trace: t4 move (due_tick), t6 rescheduled cast (due_tick), t10 orc vs goblin (sequence), goblin vs hero (priority), terminal. Diff vs prior golden: N/A (first baseline).
- Verified the subsequent normal run compares clean (read-only, no rewrite).

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0)
  [run_all] files=7 checks=92 failures=0
./tools/test.sh --update-golden core_scheduler_basic -> golden (re)written, run PASS
```

Classification: `passed`. Gate (§4 core, DETERMINISM_TRACE_TEST_POLICY): golden exact-match + property/metamorphic checks green.

## Repair record (gate REJECT → fix, attempt 1/3)

- Symptom: parse error in `test_eq_trace_properties._step` — `var e := s.pop()` could not infer type because the `s` parameter was untyped. (Same class of issue as EQM-011's repair; the masked-failure guard caught it.)
- Fix: typed the helper parameters `_step(tr: EQTrace, s: EQScheduler)`. Test-only; no product change. Re-run green.
- Note: the golden fixture had already been written by the earlier `--update-golden` run (the golden test file parsed fine independently of the properties file), so the baseline content was unaffected by this repair.

## Deviations

- Golden location: the queue lists `tests/golden/` as a target; for a Godot-produced/consumed fixture this is realized as `test_project/tests/golden/` (readable via `res://`). Python-tool fixtures (e.g. EQM-023 `api_surface.json`) can live at repo-root `tests/golden/`. Recorded here as the path convention for trace goldens.
- `tools/test.sh` touched (listed as an EQM-013 target): only added the `EQ_RUN_OUT` export; the `--update-golden` plumbing from EQM-001 was sufficient and reused.

## No sample-only completion

All acceptance rests on direct trace assertions, a golden approval gate, and property/metamorphic checks; no bundled sample is involved.

## Repair-now / follow-up

None blocking. The float guard in the encoder (`push_error`) is defensive — the scheduler trace is int-only and never triggers it. Next: **EQM-014 (event model semantics) is the autonomous-loop checkpoint** (§8.3, depth=decision): it records adopted/rejected decisions across `EVENT_MODEL_OPEN_QUESTIONS.md` and is explicitly a C5 design task to be split at planning time. The trace-kind schema is now open, so EQM-014's `event_line_progressed` / `window_opened` / `window_closed` kinds need no harness change. Stopping here for user direction per the checkpoint rule.
