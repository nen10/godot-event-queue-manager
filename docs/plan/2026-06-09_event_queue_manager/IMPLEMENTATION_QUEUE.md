# IMPLEMENTATION_QUEUE: Event Queue Manager

Source roadmap: `docs/plan/2026-06-09_event_queue_manager/ROADMAP.md`
Process references:

- `docs/devflow/PROJECT_PROFILE.md`
- `docs/devflow/TASK_PACKET.md`
- `docs/devflow/QUEUE_OPERATION_RULES.md`
- `docs/devflow/LINEAR_AUTOPILOT_QUEUE.md`
- `docs/devflow/policy/IMPLEMENTATION_QUEUE_DESIGN_POLICY.md`

## Queue notes

- Initial queue focuses on Phase 0-3 and lays dependencies for Phase 4-8.
- Tasks are product slices, not one-class fragments.
- A task may update code, tests, docs, and sample assets together when that is required to prove completion.
- `./tools/test.sh` is the standard verification path once created.
- If Godot is missing, use `BLOCKED_BY_TEST_ENV` only with code review proof and a clear environment note.
- UI tasks follow `docs/devflow/policy/UI_TESTABILITY_POLICY.md`; metric adoption stages M0-M5 map to EQM-086 / EQM-087 / EQM-093 / EQM-094 / EQM-095.
- Ordering / trace proof follows `docs/devflow/policy/DETERMINISM_TRACE_TEST_POLICY.md`; golden fixtures update only via the explicit approval procedure with self-review notes.
- Input narrowing follows `docs/devflow/policy/UX_PATH_REDUCTION_POLICY.md`; new feature acceptance includes rejection tests for narrowed inputs.

## Phase 0 — Devflow and test harness

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-001 | READY | — | `docs/plan/2026-06-09_event_queue_manager/EQM-001_devflow_profile/` | Event Queue Manager-specific devflow profile and test command skeleton. | `docs/devflow/PROJECT_PROFILE.md`, `docs/devflow/TEST.md`, `tools/test.sh`, `.agents/skills/roadmap-autopilot/SKILL.md` | Profile no longer references unrelated Hex domain; `TEST.md` defines standard commands; `tools/test.sh` exits clearly when Godot is missing; self-review notes missing-process-file fix. |
| EQM-002 | BACKLOG | EQM-001 | `docs/plan/2026-06-09_event_queue_manager/EQM-002_addon_scaffold/` | Minimal Godot addon scaffold that loads in a clean project. | `addons/event_queue_manager/plugin.cfg`, `addons/event_queue_manager/plugin.gd`, `addons/event_queue_manager/runtime/`, `test_project/` | Clean project load smoke path documented; addon can be enabled; `./tools/test.sh` reaches scaffold checks. |

## Phase 1 — Core scheduler MVP

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-010 | BACKLOG | EQM-002 | `docs/plan/2026-06-09_event_queue_manager/EQM-010_core_event_contract/` | Core event entry and ordering contract. | `runtime/eq_entry.gd`, `runtime/eq_ordering.gd`, `tests/core/` | Tests prove due_tick asc, priority desc, sequence asc, stable tie-breaking, invalid negative tick rejection. |
| EQM-011 | BACKLOG | EQM-010 | `docs/plan/2026-06-09_event_queue_manager/EQM-011_scheduler_operations/` | Scheduler push/pop/peek/cancel/reschedule with sorted-array backend. | `runtime/eq_scheduler.gd`, `runtime/backends/eq_sorted_array_backend.gd`, `tests/core/` | Tests cover push/pop, peek N, cancel by event_id, lazy invalidation/generation, reschedule, empty queue behavior. |
| EQM-012 | BACKLOG | EQM-011 | `docs/plan/2026-06-09_event_queue_manager/EQM-012_snapshot_roundtrip/` | Serializable snapshot for scheduler state. | `runtime/eq_snapshot.gd`, `runtime/eq_scheduler.gd`, `tests/core/` | Snapshot roundtrip reproduces current_tick, sequence counter, entries, generations, and subsequent pop order; snapshot carries `schema_version` and unknown versions produce a stable load error. |
| EQM-013 | BACKLOG | EQM-012 | `docs/plan/2026-06-09_event_queue_manager/EQM-013_trace_determinism_harness/` | Canonical trace export and determinism harness (golden + property tests). | `runtime/eq_trace.gd`, `tests/core/`, `tests/golden/`, `tools/test.sh` | Same-seed replay reproduces byte-identical trace; insertion permutation with identical keys preserves pop order; snapshot continuity holds; golden update only via explicit flag per `DETERMINISM_TRACE_TEST_POLICY.md`. |
| EQM-014 | BACKLOG | EQM-013 | `docs/plan/2026-06-09_event_queue_manager/EQM-014_event_model_semantics/` | Event model semantics spec and ordering model coverage matrix. | `docs/design/EVENT_MODEL_SEMANTICS.md`, `docs/design/ORDERING_MODEL_COVERAGE.md`, `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md` | Ordering key, tick advancement, phase/insertion-window model (turn-as-event), reentrancy, simultaneous-trigger resolution, and AP accounting rules are decided with adopted/rejected records; resolves all `EVENT_MODEL_OPEN_QUESTIONS.md` items, honoring user-decided Q01/Q02 with their verification conditions; coverage matrix maps >= 8 known ordering systems (CTB, energy, wait-turn, FE phase, 4X phase, stack/LIFO, Pokemon-style speed turn, 行動解決ターン制) onto the model; unmappable cases become queue candidates before the Phase 2 API freeze. |

## Phase 2 — Resource/API contract

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-020 | BACKLOG | EQM-014 | `docs/plan/2026-06-09_event_queue_manager/EQM-020_config_policy_resources/` | `EQConfig` and `EQPolicy` base Resources with validation, plus error taxonomy. | `resources/eq_config.gd`, `resources/policies/eq_policy.gd`, `docs/design/ERROR_CONTRACT.md`, `tests/resource/` | Resource can be saved/loaded; missing policy and ambiguous tie-breaker produce explicit validation results; contracts follow `docs/design/EVENT_MODEL_SEMANTICS.md`; error taxonomy (stable codes, recoverability classes, game/editor surfacing rules) documented in `ERROR_CONTRACT.md` and used by validation. |
| EQM-021 | BACKLOG | EQM-020 | `docs/plan/2026-06-09_event_queue_manager/EQM-021_actor_action_contract/` | Actor state and action result public API. | `runtime/eq_actor_state.gd`, `runtime/eq_action_result.gd`, `runtime/eq_actor_registry.gd`, `tests/resource/` | Actor id registration, duplicate rejection, weak binding placeholder, action cost/delay result validation tested. |
| EQM-022 | BACKLOG | EQM-021 | `docs/plan/2026-06-09_event_queue_manager/EQM-022_manager_headless_facade/` | Headless facade that coordinates scheduler, policy, actors, and action finish. | `runtime/eq_runtime.gd`, `tests/core/` | Register actors, start queue, pop ready event, finish action, and schedule next event without Godot scene tree. |
| EQM-023 | BACKLOG | EQM-022 | `docs/plan/2026-06-09_event_queue_manager/EQM-023_api_surface_gate/` | Public API surface snapshot gate. | `tools/check_api_surface.py`, `tests/golden/api_surface.json`, `docs/design/API_SURFACE.md` | Public/internal naming convention documented; deterministic export of the public API surface; surface diff without an accompanying doc note fails `./tools/test.sh`; golden update follows the explicit approval procedure. |

## Phase 3 — Basic policy MVP and runtime Node

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-030 | BACKLOG | EQM-022 | `docs/plan/2026-06-09_event_queue_manager/EQM-030_fixed_round_policy/` | Fixed round policy with initiative and tie-breaker options. | `resources/policies/eq_fixed_round_policy.gd`, `tests/policy/` | Tests cover battle-start ordering, round refresh, equal initiative tie-break, actor removal skip. |
| EQM-031 | BACKLOG | EQM-030 | `docs/plan/2026-06-09_event_queue_manager/EQM-031_ctb_policy/` | CTB policy with speed and action cost. | `resources/policies/eq_ctb_policy.gd`, `tests/policy/` | Tests cover faster actor extra turns, heavy action delay, wait action shorter delay, haste/slow next-turn behavior. |
| EQM-032 | BACKLOG | EQM-031 | `docs/plan/2026-06-09_event_queue_manager/EQM-032_eq_manager_node/` | Godot `EQManager` Node, signal integration, and game-loop driver contract. | `runtime/eq_manager.gd`, `addons/event_queue_manager/plugin.gd`, `tests/runtime/` | Scene-local manager emits `queue_changed`, `event_ready`, `turn_ready`, `event_resolved`; invalid actor policy tested; game-loop driver contract (who advances the queue, suspend semantics awaiting player input, await boundary for action presentation) documented in `EVENT_MODEL_SEMANTICS.md` and covered by tests. |
| EQM-033 | BACKLOG | EQM-032 | `docs/plan/2026-06-09_event_queue_manager/EQM-033_prediction_preview/` | Next-N prediction without mutating live scheduler. | `runtime/eq_prediction.gd`, `runtime/eq_snapshot.gd`, `tests/core/` | Prediction returns expected order; live queue remains unchanged; deterministic seed state preserved. |
| EQM-034 | BACKLOG | EQM-033 | `docs/plan/2026-06-09_event_queue_manager/EQM-034_ctb_sample_battle/` | Minimal CTB sample battle and quickstart docs. | `demos/ctb_battle/`, `docs/manual/quickstart.md`, `tests/debug_scene/` | Sample is explicitly learning path; quickstart uses project-created config; sample scene runs or is marked `BLOCKED_BY_TEST_ENV` with proof. |
| EQM-035 | BACKLOG | EQM-034 | `docs/plan/2026-06-09_event_queue_manager/EQM-035_v0_1_milestone_evaluation/` | v0.1 milestone evaluation (API friction, semantics drift, queue adjustment). | `docs/review/` | Evaluation report exists; semantics spec vs implementation drift is audited; API friction findings and gaps become queue candidates or explicit no-change records; roadmap updated or confirmed unchanged. |

## Phase 4 — Energy and Wait Turn policies

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-040 | BACKLOG | EQM-034 | `docs/plan/2026-06-09_event_queue_manager/EQM-040_energy_policy/` | Roguelike energy policy. | `resources/policies/eq_energy_policy.gd`, `tests/policy/` | Threshold readiness, action cost, speed differences, wait, and energy carry-over tested. |
| EQM-041 | BACKLOG | EQM-040 | `docs/plan/2026-06-09_event_queue_manager/EQM-041_wait_turn_policy/` | Tactics Ogre-style wait-turn policy. | `resources/policies/eq_wait_turn_policy.gd`, `tests/policy/`, `demos/wait_turn_tactics/` | Units with wait values resolve instantly to next ready unit; action cost modifies next wait; equal wait tie-break explained. |

## Phase 5 — Action Reservation model

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-050 | BACKLOG | EQM-041 | `docs/plan/2026-06-09_event_queue_manager/EQM-050_reservation_schema/` | Reservation Resource/API schema. | `resources/eq_action_definition.gd`, `runtime/eq_reservation.gd`, `tests/resource/` | Immediate, prepared, reaction preparation, wait, ready reservation, operation action, tags, duration, rumination fields validate. |
| EQM-051 | BACKLOG | EQM-050 | `docs/plan/2026-06-09_event_queue_manager/EQM-051_reservation_resolution/` | Reservation scheduling and resolution pipeline. | `runtime/eq_reservation_runtime.gd`, `tests/core/` | Immediate action resolves at delay 0; prepared action resolves after delay; wait schedules ready reservation; operation action causes target reservation. |
| EQM-052 | BACKLOG | EQM-051 | `docs/plan/2026-06-09_event_queue_manager/EQM-052_ap_ready_model/` | AP and ready reservation model for Action Resolution Turn-Based. | `resources/policies/eq_action_resolution_policy.gd`, `tests/policy/` | Ready reservation grants turn after AP recovery delay; AP spending and recovery are deterministic; turn closes through wait. |
| EQM-053 | BACKLOG | EQM-052 | `docs/plan/2026-06-09_event_queue_manager/EQM-053_policy_reducibility_proofs/` | Policy reducibility proofs (dedicated policies as reservation-model degenerate cases). | `tests/policy/`, `tests/golden/` | CTB, energy, and wait-turn configurations expressed via the reservation model reproduce the dedicated policies' golden traces across tie-break / speed / delay matrices; divergences are recorded as model gaps feeding the next evaluation. |

## Phase 6 — Trigger and reaction engine

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-060 | BACKLOG | EQM-052 | `docs/plan/2026-06-09_event_queue_manager/EQM-060_condition_contract/` | Condition and tag matching contract. | `resources/eq_condition.gd`, `runtime/eq_tag_matcher.gd`, `tests/trigger/` | Conditions can match event type, source, target, tags, range/sensing adapter placeholder, and custom predicate. |
| EQM-061 | BACKLOG | EQM-060 | `docs/plan/2026-06-09_event_queue_manager/EQM-061_reaction_preparation/` | Reaction preparation runtime. | `runtime/eq_trigger_engine.gd`, `tests/trigger/` | Counterattack preparation triggers on incoming `<損害>` reservation; duration expiry prevents trigger; owner/source matching tested. |
| EQM-062 | BACKLOG | EQM-061 | `docs/plan/2026-06-09_event_queue_manager/EQM-062_rumination_cycle_guard/` | Rumination and cycle prevention. | `runtime/eq_reservation_runtime.gd`, `runtime/eq_trigger_engine.gd`, `tests/trigger/` | Rumination count decrements and reschedules; max chain guard stops infinite loops with explicit error/event. |

## Phase 7 — Transaction and rollback

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-070 | BACKLOG | EQM-062 | `docs/plan/2026-06-09_event_queue_manager/EQM-070_transaction_snapshot/` | Player turn draft transaction. | `runtime/eq_transaction.gd`, `runtime/eq_snapshot.gd`, `tests/transaction/` | Draft actions can be applied, inspected, rolled back, and committed; live scheduler unchanged before commit. |
| EQM-071 | BACKLOG | EQM-070 | `docs/plan/2026-06-09_event_queue_manager/EQM-071_wait_commit_boundary/` | Wait/end-turn commit boundary. | `runtime/eq_transaction.gd`, `resources/policies/eq_action_resolution_policy.gd`, `tests/transaction/` | Player immediate actions are rollbackable before wait; wait commits draft and schedules ready reservation. |
| EQM-072 | BACKLOG | EQM-071 | `docs/plan/2026-06-09_event_queue_manager/EQM-072_deterministic_replay/` | Deterministic random and replay proof. | `runtime/eq_rng.gd`, `runtime/eq_snapshot.gd`, `tests/transaction/` | Snapshot restore reproduces random-dependent order and results under same seed. |

## Phase 8 — Effect and presentation pipeline

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-080 | BACKLOG | EQM-072 | `docs/plan/2026-06-09_event_queue_manager/EQM-080_effect_records/` | Simulation effect and presentation event records. | `runtime/eq_effect_record.gd`, `runtime/eq_presentation_event.gd`, `tests/presentation/` | Status effects record immediately; presentation requests can be queued separately with actor/position references. |
| EQM-081 | BACKLOG | EQM-080 | `docs/plan/2026-06-09_event_queue_manager/EQM-081_visibility_flush_policy/` | Importance/sensing/offscreen presentation policy. | `resources/eq_presentation_policy.gd`, `runtime/eq_presentation_buffer.gd`, `tests/presentation/` | Important event flushes previous visuals; sensed non-important defers; offscreen skips; player turn flush tested. |
| EQM-082 | BACKLOG | EQM-081 | `docs/plan/2026-06-09_event_queue_manager/EQM-082_moving_target_barrier/` | Moving-target consistency barrier. | `runtime/eq_presentation_buffer.gd`, `tests/presentation/` | Event referencing moved entity forces prior pending visuals to flush before resolving/displaying dependent event. |

## Phase 8b — Runtime order surface and dogfood

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-083 | BACKLOG | EQM-033, EQM-082 | `docs/plan/2026-06-09_event_queue_manager/EQM-083_runtime_timeline_hud/` | Player-facing runtime timeline HUD component (in-game turn order display). | `runtime/ui/eq_timeline_hud.gd`, `runtime/ui/eq_timeline_hud.tscn`, `tests/ui_headless/` | HUD renders injected prediction (projection integrity in-game); updates on `queue_changed`; shows explicit stale state while presentation is deferred; controls carry `ui_metric_id` metadata; no UI-side order recomputation. |
| EQM-084 | BACKLOG | EQM-083 | `docs/plan/2026-06-09_event_queue_manager/EQM-084_dogfood_vertical_slice/` | Dogfood consumer slice: minimal playable Action Resolution Turn-Based game consuming only the public addon API. | `dogfood/`, `docs/review/`, `tests/golden/` | Slice uses public API only (no runtime internals); ships its own golden trace; friction report `docs/review/DOGFOOD_FRICTION_<date>.md` records API ergonomics findings; findings become queue candidates or explicit no-change records. |

## Phase 9 — Editor tooling

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-086 | BACKLOG | EQM-034 | `docs/plan/2026-06-09_event_queue_manager/EQM-086_editor_ui_contract/` | Editor UI contract and state matrix (adoption M0). | `docs/ui/EDITOR_UI_CONTRACT.md`, `docs/ui/EDITOR_STATE_MATRIX.md` | Surfaces, required components, forbidden visible text, scenario states, and initial thresholds defined per `UI_LAYOUT_METRIC_TEST_POLICY.md`; docs-only acceptance, no Godot run required. |
| EQM-087 | BACKLOG | EQM-086 | `docs/plan/2026-06-09_event_queue_manager/EQM-087_ui_metric_harness/` | UI static audit + layout snapshot collector + WARN-only metric report (adoption M1-M3). | `tools/ui_static_audit.py`, `addons/event_queue_manager/editor/testing/`, `tests/ui_headless/` | Static audit runs inside `./tools/test.sh`; collector produces snapshot JSON for a synthetic scenario Control tree; evaluator reports metrics WARN-only; report written under `.godot_user/test-runs/`. |
| EQM-090 | BACKLOG | EQM-034, EQM-087 | `docs/plan/2026-06-09_event_queue_manager/EQM-090_timeline_dock_mvp/` | Timeline Preview Dock MVP for basic policies. | `editor/timeline_dock.tscn`, `editor/timeline_dock.gd`, `tests/ui_headless/` | User selects project config; dock shows next events or explicit unset/validation state; no silent sample default; controls carry `ui_metric_id` metadata; displayed order equals headless prediction (projection integrity); metric WARN report cited in self-review. |
| EQM-091 | BACKLOG | EQM-090 | `docs/plan/2026-06-09_event_queue_manager/EQM-091_debug_order_explanation/` | Debug order explanation view. | `editor/debug_inspector.gd`, `runtime/eq_order_explanation.gd`, `tests/ui_headless/` | For a selected event, UI can explain tick/priority/sequence/tie-break reason, rendered from structured explanation data (explanation-as-data), not free-form strings. |
| EQM-092 | BACKLOG | EQM-091, EQM-082 | `docs/plan/2026-06-09_event_queue_manager/EQM-092_action_resolution_template/` | Editor template for Action Resolution Turn-Based demo. | `editor/template_generator.gd`, `demos/action_resolution/`, `tests/ui_headless/` | Template creates project assets, not hidden sample defaults; generated demo uses reservation/trigger/presentation APIs. |
| EQM-093 | BACKLOG | EQM-090, EQM-091 | `docs/plan/2026-06-09_event_queue_manager/EQM-093_ui_metric_p0_gate/` | UI metric P0 acceptance gate (adoption M4). | `tests/ui_headless/`, `tools/test.sh` | No-op buttons, scroll reachability, state contradiction, debug leakage, float tick display, projection integrity, and sample fallback enforced as FAIL across the scenario matrix. |
| EQM-094 | BACKLOG | EQM-090 | `docs/plan/2026-06-09_event_queue_manager/EQM-094_layout_calibration_loop/` | Layout Calibration Loop MVP (tweak-and-bake debug tab + ledger). | `addons/event_queue_manager/editor/testing/eq_calibration_tab.gd`, `docs/ui/LAYOUT_CALIBRATION_LEDGER.md` | Debug-only tab edits layout params per `ui_metric_id`; Copy Layout Feedback emits schema-valid JSON per `UI_LAYOUT_CALIBRATION_POLICY.md`; tab hidden without flag (P0 test); bake procedure and cold-control ledger documented. |
| EQM-095 | BACKLOG | EQM-093, EQM-094 | `docs/plan/2026-06-09_event_queue_manager/EQM-095_ui_metric_p1_gate/` | UI metric P1 gate with calibrated thresholds (adoption M5). | `docs/ui/EDITOR_UI_CONTRACT.md`, `tests/ui_headless/` | Row geometry, truncation, and picker width thresholds updated from calibration ledger evidence; P1 gate active; exceptions declared in the contract. |

## Phase 10 — Documentation, package, release

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-100 | BACKLOG | EQM-082 | `docs/plan/2026-06-09_event_queue_manager/EQM-100_manual_reservations/` | Reservation and Action Resolution manual. | `docs/manual/reservations.md`, `docs/manual/action_resolution.md` | Manual matches current API; examples avoid sample-only assumptions; rollback/wait/ready semantics documented. |
| EQM-101 | BACKLOG | EQM-092, EQM-100 | `docs/plan/2026-06-09_event_queue_manager/EQM-101_demo_suite/` | Multi-genre demo suite. | `demos/`, `docs/manual/policy_selection.md`, `tests/golden/` | CTB, energy, wait-turn, action-resolution, phase, and stack demos load or are environment-blocked with proof; each demo emits its golden trace headless per `DETERMINISM_TRACE_TEST_POLICY.md`. |
| EQM-102 | BACKLOG | EQM-101 | `docs/plan/2026-06-09_event_queue_manager/EQM-102_performance_backend/` | Binary heap backend and trigger indexing. | `runtime/backends/eq_binary_heap_backend.gd`, `runtime/eq_trigger_index.gd`, `tests/performance/` | Numeric performance budgets (actor count, event count, per-advance cost) declared before benchmarking; large queue benchmark judged against the budgets with order correctness; backend selectable without public API break. |
| EQM-103 | BACKLOG | EQM-102 | `docs/plan/2026-06-09_event_queue_manager/EQM-103_package_release_candidate/` | v1.0 release candidate package proof. | `addons/event_queue_manager/`, `README.md`, `LICENSE`, `docs/review/` | Clean project load, addon manifest, docs links, sample isolation, and final self-review complete; snapshot schema compatibility stance (preserve/migrate/replace/defer) declared for v1.0. |

## Dynamic follow-up area

Add `follow-up-ready` tasks here during execution when a current task is complete but reveals nonblocking follow-up work.

| id | status | dependencies | source task | deliverable | acceptance / test path |
|---|---|---|---|---|---|
| — | — | — | — | — | — |

## Current pointer

Current: `EQM-001`

## Proof log

No task has been executed yet.
