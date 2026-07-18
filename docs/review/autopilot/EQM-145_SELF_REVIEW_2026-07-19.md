# EQM-145 Self Review — Consumer-facing scheduler backend selection

Date: 2026-07-19 (Asia/Tokyo)
Status: COMPLETE

## Summary

EQM-145 exposes scheduler backend selection through `EQConfig.scheduler_backend`. Sorted-array remains the default/legacy value; binary heap is an explicit large-queue opt-in. `EQRuntime` constructs the configured backend at setup, and `EQManager.configure()` applies backend choice only while the scheduler has no live events. Non-empty reconfiguration records a stable fault and keeps the existing scheduler.

## Changed files

- `addons/event_queue_manager/resources/eq_config.gd`
- `addons/event_queue_manager/runtime/eq_runtime.gd`
- `addons/event_queue_manager/runtime/eq_manager.gd`
- `addons/event_queue_manager/runtime/eq_error.gd`
- `test_project/tests/resource/test_eq_config.gd`
- `test_project/tests/runtime/test_eq_scheduler_backend_selection.gd`
- `test_project/tests/performance/test_eq_configured_heap_backend.gd`
- `docs/design/API_SURFACE.md`
- `docs/ja/design/API_SURFACE.md`
- `docs/design/ERROR_CONTRACT.md`
- `docs/ja/design/ERROR_CONTRACT.md`
- `docs/design/SNAPSHOT_COMPAT_V1.md`
- `docs/design/RUNTIME_PERFORMANCE_PROFILE.md`
- `tests/golden/api_surface.json`
- `docs/plan/2026-06-09_event_queue_manager/EQM-145_backend_selection/{SUB_TASKS,UX,POLICY,IMPLEMENTATION_PLAN}.md`
- `docs/plan/2026-06-09_event_queue_manager/IMPLEMENTATION_QUEUE.md`

## Acceptance result

| acceptance | result | proof |
|---|---|---|
| additive `EQConfig.scheduler_backend` enum/config | PASS | API golden includes `SchedulerBackend` and `scheduler_backend`; config tests cover default, heap, unknown |
| unknown backend stable config error | PASS | `eqm.config.scheduler_backend_unknown` validation test + docs |
| runtime/manager setup-time backend application | PASS | manager config test sees `EQBinaryHeapBackend` before seed |
| non-empty backend replacement rejected safely | PASS | test records `eqm.runtime.scheduler_backend_reconfigure_nonempty`, keeps scheduler/backend, and live event remains |
| sorted/heap ordering parity | PASS | manager trace parity test compares JSONL |
| snapshot portability documented | PASS | `SNAPSHOT_COMPAT_V1.md` notes backend choice is config, not snapshot state |
| consumer/Amberground docs | PASS | EN/JA API surface notes include no-action changes, `has_event` migration, and heap opt-in instructions |
| performance guard | PASS | configured heap drain fixture resolves 1,024 events with trace sentinel under coarse guard |

## Tests

- `python3 tools/check_api_surface.py --update` → PASS
  - golden diff: `EQConfig.SchedulerBackend`, `EQConfig.scheduler_backend`, `EQError.CONFIG_SCHEDULER_BACKEND_UNKNOWN`, `EQError.RUNTIME_SCHEDULER_BACKEND_RECONFIGURE_NONEMPTY`
- `./tools/test.sh` → PASS
  - run id: `20260719-043726-48423`
  - suite: regression
  - files: 80
  - checks: 2133
  - failures: 0
- `./tools/test.sh --performance` → PASS
  - run id: `20260719-043732-48583`
  - suite: performance
  - files: 8
  - checks: 68
  - failures: 0
  - EQM-145 advisory: configured heap drain N=1024 elapsed 14 ms, guard < 500 ms

## Deviation record

- The runtime backend-apply helper is intentionally internal (`_apply_config_scheduler_backend`) to avoid exposing an unnecessary public runtime mutator. Consumer entrypoints are `EQConfig.scheduler_backend` plus `EQManager.configure(config)` or `EQRuntime.new(config)`.
- `scheduler_backend` is exported as the enum type so the API surface gate captures it. Validation still covers unknown integer assignment.

## Repair-now audit

No repair-now items remain.

## Scheduled task audit

No new scheduled tasks were created. Phase 15 has no remaining READY/BACKLOG tasks after EQM-145.

## Completion judgment

COMPLETE. Phase 15 closes with scheduler live-peek, reschedule lookup, membership API, and backend selection implemented and documented for consumers.
