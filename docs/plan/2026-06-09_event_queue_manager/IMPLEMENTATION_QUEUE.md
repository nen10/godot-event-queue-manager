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
| EQM-012 | BACKLOG | EQM-011 | `docs/plan/2026-06-09_event_queue_manager/EQM-012_snapshot_roundtrip/` | Serializable snapshot for scheduler state. | `runtime/eq_snapshot.gd`, `runtime/eq_scheduler.gd`, `tests/core/` | Snapshot roundtrip reproduces current_tick, sequence counter, entries, generations, and subsequent pop order. |

## Phase 2 — Resource/API contract

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-020 | BACKLOG | EQM-012 | `docs/plan/2026-06-09_event_queue_manager/EQM-020_config_policy_resources/` | `EQConfig` and `EQPolicy` base Resources with validation. | `resources/eq_config.gd`, `resources/policies/eq_policy.gd`, `tests/resource/` | Resource can be saved/loaded; missing policy and ambiguous tie-breaker produce explicit validation results. |
| EQM-021 | BACKLOG | EQM-020 | `docs/plan/2026-06-09_event_queue_manager/EQM-021_actor_action_contract/` | Actor state and action result public API. | `runtime/eq_actor_state.gd`, `runtime/eq_action_result.gd`, `runtime/eq_actor_registry.gd`, `tests/resource/` | Actor id registration, duplicate rejection, weak binding placeholder, action cost/delay result validation tested. |
| EQM-022 | BACKLOG | EQM-021 | `docs/plan/2026-06-09_event_queue_manager/EQM-022_manager_headless_facade/` | Headless facade that coordinates scheduler, policy, actors, and action finish. | `runtime/eq_runtime.gd`, `tests/core/` | Register actors, start queue, pop ready event, finish action, and schedule next event without Godot scene tree. |

## Phase 3 — Basic policy MVP and runtime Node

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-030 | BACKLOG | EQM-022 | `docs/plan/2026-06-09_event_queue_manager/EQM-030_fixed_round_policy/` | Fixed round policy with initiative and tie-breaker options. | `resources/policies/eq_fixed_round_policy.gd`, `tests/policy/` | Tests cover battle-start ordering, round refresh, equal initiative tie-break, actor removal skip. |
| EQM-031 | BACKLOG | EQM-030 | `docs/plan/2026-06-09_event_queue_manager/EQM-031_ctb_policy/` | CTB policy with speed and action cost. | `resources/policies/eq_ctb_policy.gd`, `tests/policy/` | Tests cover faster actor extra turns, heavy action delay, wait action shorter delay, haste/slow next-turn behavior. |
| EQM-032 | BACKLOG | EQM-031 | `docs/plan/2026-06-09_event_queue_manager/EQM-032_eq_manager_node/` | Godot `EQManager` Node and signal integration. | `runtime/eq_manager.gd`, `addons/event_queue_manager/plugin.gd`, `tests/runtime/` | Scene-local manager emits `queue_changed`, `event_ready`, `turn_ready`, `event_resolved`; invalid actor policy tested. |
| EQM-033 | BACKLOG | EQM-032 | `docs/plan/2026-06-09_event_queue_manager/EQM-033_prediction_preview/` | Next-N prediction without mutating live scheduler. | `runtime/eq_prediction.gd`, `runtime/eq_snapshot.gd`, `tests/core/` | Prediction returns expected order; live queue remains unchanged; deterministic seed state preserved. |
| EQM-034 | BACKLOG | EQM-033 | `docs/plan/2026-06-09_event_queue_manager/EQM-034_ctb_sample_battle/` | Minimal CTB sample battle and quickstart docs. | `demos/ctb_battle/`, `docs/manual/quickstart.md`, `tests/debug_scene/` | Sample is explicitly learning path; quickstart uses project-created config; sample scene runs or is marked `BLOCKED_BY_TEST_ENV` with proof. |

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

## Phase 9 — Editor tooling

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-090 | BACKLOG | EQM-034 | `docs/plan/2026-06-09_event_queue_manager/EQM-090_timeline_dock_mvp/` | Timeline Preview Dock MVP for basic policies. | `editor/timeline_dock.tscn`, `editor/timeline_dock.gd`, `tests/ui_headless/` | User selects project config; dock shows next events or explicit unset/validation state; no silent sample default. |
| EQM-091 | BACKLOG | EQM-090 | `docs/plan/2026-06-09_event_queue_manager/EQM-091_debug_order_explanation/` | Debug order explanation view. | `editor/debug_inspector.gd`, `runtime/eq_order_explanation.gd`, `tests/ui_headless/` | For a selected event, UI can explain tick/priority/sequence/tie-break reason. |
| EQM-092 | BACKLOG | EQM-091, EQM-082 | `docs/plan/2026-06-09_event_queue_manager/EQM-092_action_resolution_template/` | Editor template for Action Resolution Turn-Based demo. | `editor/template_generator.gd`, `demos/action_resolution/`, `tests/ui_headless/` | Template creates project assets, not hidden sample defaults; generated demo uses reservation/trigger/presentation APIs. |

## Phase 10 — Documentation, package, release

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-100 | BACKLOG | EQM-082 | `docs/plan/2026-06-09_event_queue_manager/EQM-100_manual_reservations/` | Reservation and Action Resolution manual. | `docs/manual/reservations.md`, `docs/manual/action_resolution.md` | Manual matches current API; examples avoid sample-only assumptions; rollback/wait/ready semantics documented. |
| EQM-101 | BACKLOG | EQM-092, EQM-100 | `docs/plan/2026-06-09_event_queue_manager/EQM-101_demo_suite/` | Multi-genre demo suite. | `demos/`, `docs/manual/policy_selection.md` | CTB, energy, wait-turn, action-resolution, phase, and stack demos load or are environment-blocked with proof. |
| EQM-102 | BACKLOG | EQM-101 | `docs/plan/2026-06-09_event_queue_manager/EQM-102_performance_backend/` | Binary heap backend and trigger indexing. | `runtime/backends/eq_binary_heap_backend.gd`, `runtime/eq_trigger_index.gd`, `tests/performance/` | Large queue benchmark records order correctness and performance; backend selectable without public API break. |
| EQM-103 | BACKLOG | EQM-102 | `docs/plan/2026-06-09_event_queue_manager/EQM-103_package_release_candidate/` | v1.0 release candidate package proof. | `addons/event_queue_manager/`, `README.md`, `LICENSE`, `docs/review/` | Clean project load, addon manifest, docs links, sample isolation, and final self-review complete. |

## Dynamic follow-up area

Add `follow-up-ready` tasks here during execution when a current task is complete but reveals nonblocking follow-up work.

| id | status | dependencies | source task | deliverable | acceptance / test path |
|---|---|---|---|---|---|
| — | — | — | — | — | — |

## Current pointer

Current: `EQM-001`

## Proof log

No task has been executed yet.
