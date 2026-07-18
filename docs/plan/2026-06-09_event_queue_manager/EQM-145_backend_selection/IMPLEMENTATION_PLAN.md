# EQM-145 — Scheduler backend selection — IMPLEMENTATION_PLAN

## Scope

- Add `EQConfig.SchedulerBackend` enum and exported `scheduler_backend` field.
- Add stable errors for unknown backend and non-empty backend reconfiguration.
- Add backend factory/apply method to `EQRuntime` and call it from `EQManager.configure()`.
- Add tests for config validation, manager/runtime backend selection, non-empty rejection, and backend trace parity.
- Update API surface golden/docs, ERROR_CONTRACT docs, SNAPSHOT_COMPAT docs, runtime performance profile.
- Add performance proof that opt-in heap drain is not regressed by trace peek.

## Target files

- `addons/event_queue_manager/resources/eq_config.gd`
- `addons/event_queue_manager/runtime/eq_runtime.gd`
- `addons/event_queue_manager/runtime/eq_manager.gd`
- `addons/event_queue_manager/runtime/eq_error.gd`
- `test_project/tests/resource/`, `test_project/tests/runtime/`, `test_project/tests/performance/`
- `docs/design/{API_SURFACE,ERROR_CONTRACT,SNAPSHOT_COMPAT_V1,RUNTIME_PERFORMANCE_PROFILE}.md`
- `docs/ja/design/{API_SURFACE,ERROR_CONTRACT}.md`
- `tests/golden/api_surface.json`

## Steps

1. Implement config enum/validation and runtime backend factory.
2. Wire `EQManager.configure()` setup-time backend application.
3. Add regression tests.
4. Add/update performance fixture for configured heap drain.
5. Update docs and API golden.
6. Run regression and performance suites.
7. Self-review, queue completion, commit.

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| EQM-142 live-peek | heap exposed but trace peek sorts every step | performance fixture + existing EQM-142 fixture |
| config validation | bad enum silently accepted | resource test |
| runtime configure | live events lost | non-empty rejection test |
| consumer docs | Amberground misses action | API_SURFACE EN/JA + SNAPSHOT note |

## Completion checklist

- [ ] `scheduler_backend` additive config field.
- [ ] heap opt-in via manager/runtime before seed.
- [ ] non-empty configure rejected safely.
- [ ] API/error docs and golden updated.
- [ ] regression PASS.
- [ ] performance PASS.
