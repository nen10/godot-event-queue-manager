# EQM-022 Self-Review 2026-06-15

Pattern: P0 (orchestrator-direct). Repair: 0.

## Execution summary

Built `EQRuntime`, the headless facade that coordinates scheduler + actor registry + (optional) config + trace with no scene tree, and implemented the dev/shipped resilience two-mode toggle. dev surfaces anomalies loudly and halts the current advance (observable `halted`, no hard assert); shipped skips the offending event, logs it, records an `invalid_event_skipped` trace, and continues. Normal input is mode-invariant: dev and shipped produce a byte-identical trace.

## Changed files

- `addons/event_queue_manager/runtime/eq_runtime.gd` — `EQRuntime`: `Mode{DEV,SHIPPED}`, register_actor/start/schedule/advance/finish_action, `faults`/`halted`, `trace`/`trace_jsonl`, `_fault` (dev halt+loud / shipped log+continue), `emit_engine_diagnostics` knob.
- `addons/event_queue_manager/runtime/eq_error.gd` — +2 runtime codes (unregistered_actor_event, schedule_unregistered_actor).
- `docs/design/ERROR_CONTRACT.md` — +2 runtime code rows.
- `test_project/tests/core/test_eq_runtime.gd` — basic flow, mode neutrality, dev halt, shipped skip+continue+snapshot integrity, finish rejects bad result.

## Acceptance result — met

| acceptance | result |
|---|---|
| register / start / pop ready event / finish / schedule next, no scene tree | basic-flow test: register → schedule → advance (clock advances) → finish_action schedules next at current_tick+delay |
| dev/shipped resilience mode toggle | `Mode` enum + `_fault`: dev halts (`halted=true`, returns null) + loud; shipped skips + logs + `invalid_event_skipped` + continues |
| normal-input traces byte-identical across modes | mode-neutrality test: identical operation script under DEV and SHIPPED → identical `trace_jsonl()` |

Extra (RUNTIME_RESILIENCE §2/§3): anomalies recorded in `faults` in both modes (no silent swallow); shipped skip keeps the scheduler consistent (snapshot still restores OK after a skip).

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=12 checks=191 failures=0
```

Gate (§4 runtime/integration): dev/shipped two-mode + mode neutrality green. Node-bridge save/load rebind is EQM-085 (this task is headless, as scoped).

## Design notes

- **No hard assert for dev fail-fast.** A real `assert(false)` would crash the test runner and the consumer game. dev "stop" is modelled as an observable `halted` flag + an optional engine diagnostic (`push_error`), which is testable and never takes the game down — consistent with the policy's intent ("surface, don't swallow") without the crash.
- **`emit_engine_diagnostics`** (default true): faults always go to the structured `faults` log; this knob only gates the additional engine-console emission. Tests set it false to keep the log clean while still asserting on faults/halted/trace.
- **delay is result-driven.** Policy-computed delay (speed/AP) is Phase 3; the facade uses `EQActionResult.delay`. config/policy is a validated slot in `start()` + a future hook.

## UX path reduction (self-review checklist)

- **Added**: `EQRuntime` facade surface (register_actor/start/schedule/advance/finish_action).
- **Narrowed**: `finish_action` takes `EQActionResult` (no raw Dictionary); mode is explicit (no silent auto-detect).
- **Residual fallback**: none. Anomalies are explicit faults, not silent recoveries.

## Deviations

- None beyond the planned +2 runtime codes.

## No sample-only completion

All acceptance rests on direct facade-flow, mode-neutrality, and resilience assertions. No sample.

## Repair-now / follow-up

None. Next: EQM-023 (layer-aware public API surface snapshot gate) — the terminal Phase 2 task. It will snapshot the public surface (including `EQRuntime`) tagged by layer L0–L3 and fail on an L3 leak into L0/L1 or an undocumented surface diff; its completion is the Phase 2 milestone.
