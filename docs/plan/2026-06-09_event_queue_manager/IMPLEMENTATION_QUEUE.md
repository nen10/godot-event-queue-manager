# IMPLEMENTATION_QUEUE: Event Queue Manager

Source roadmap: `docs/plan/2026-06-09_event_queue_manager/ROADMAP.md`
Process references:

- `docs/devflow/PROJECT_PROFILE.md`
- `docs/devflow/TASK_PACKET.md`
- `docs/devflow/QUEUE_OPERATION_RULES.md`
- `docs/devflow/LINEAR_AUTOPILOT_QUEUE.md`
- `docs/devflow/policy/IMPLEMENTATION_QUEUE_DESIGN_POLICY.md`

## Queue notes

- The queue is elaborated through release (Phase 0-10); execution still gates Phase 4+ behind the v0.1 MVP contracts (roadmap §10).
- Queue phase headers are an execution slicing and do **not** map 1:1 to the roadmap's thematic phases. Mapping: queue P0-P8 == roadmap P0-P8; queue P8b (runtime order surface / dogfood) + the `EQManager` node (EQM-032, in queue P3) together cover roadmap P9 "Godot runtime integration"; queue P9 (editor tooling) == roadmap P10; queue P10 (docs/package/release) == roadmap P11+P12. Milestone "Included phases" uses roadmap numbering.
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
| EQM-001 | COMPLETE | — | `docs/plan/2026-06-09_event_queue_manager/EQM-001_devflow_profile/` | Event Queue Manager-specific devflow profile and test command skeleton. | `docs/devflow/PROJECT_PROFILE.md`, `docs/devflow/TEST.md`, `tools/test.sh`, `.agents/skills/roadmap-autopilot/SKILL.md` | Profile no longer references unrelated Hex domain; `TEST.md` defines standard commands; `tools/test.sh` exits clearly when Godot is missing; self-review notes missing-process-file fix. |
| EQM-002 | COMPLETE | EQM-001 | `docs/plan/2026-06-09_event_queue_manager/EQM-002_addon_scaffold/` | Minimal Godot addon scaffold that loads in a clean project. | `addons/event_queue_manager/plugin.cfg`, `addons/event_queue_manager/plugin.gd`, `addons/event_queue_manager/runtime/`, `test_project/` | Clean project load smoke path documented; addon can be enabled; `./tools/test.sh` reaches scaffold checks; target Godot version declared in `plugin.cfg`/`project.godot` and pinned by the clean-load smoke test (roadmap §3.2). |

## Phase 1 — Core scheduler MVP

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-010 | COMPLETE | EQM-002 | `docs/plan/2026-06-09_event_queue_manager/EQM-010_core_event_contract/` | Core event entry and ordering contract. | `runtime/eq_entry.gd`, `runtime/eq_ordering.gd`, `tests/core/` | Tests prove due_tick asc, priority desc, sequence asc, stable tie-breaking, invalid negative tick rejection. |
| EQM-011 | COMPLETE | EQM-010 | `docs/plan/2026-06-09_event_queue_manager/EQM-011_scheduler_operations/` | Scheduler push/pop/peek/cancel/reschedule with sorted-array backend behind a backend contract. | `runtime/eq_scheduler.gd`, `runtime/backends/eq_backend.gd`, `runtime/backends/eq_sorted_array_backend.gd`, `tests/core/` | Tests cover push/pop, peek N, cancel by event_id, lazy invalidation/generation, reschedule, empty queue behavior; the backend is accessed through a language-agnostic contract interface so it can be swapped (sorted-array → binary heap → future native) without a public API change (roadmap §3.2, principle 19). |
| EQM-012 | COMPLETE | EQM-011 | `docs/plan/2026-06-09_event_queue_manager/EQM-012_snapshot_roundtrip/` | Serializable snapshot for scheduler state. | `runtime/eq_snapshot.gd`, `runtime/eq_scheduler.gd`, `tests/core/` | Snapshot roundtrip reproduces current_tick, sequence counter, entries, generations, and subsequent pop order; snapshot carries `schema_version` and unknown versions produce a stable load error. |
| EQM-013 | COMPLETE | EQM-012 | `docs/plan/2026-06-09_event_queue_manager/EQM-013_trace_determinism_harness/` | Canonical trace export and determinism harness (golden + property tests). | `runtime/eq_trace.gd`, `tests/core/`, `tests/golden/`, `tools/test.sh` | Same-seed replay reproduces byte-identical trace; insertion permutation with identical keys preserves pop order; snapshot continuity holds; golden update only via explicit flag per `DETERMINISM_TRACE_TEST_POLICY.md`; the trace-record-kind schema is open/extensible so later phases (EQM-014 `event_line_progressed`/`window_opened`/`window_closed`, EQM-061 invalidation `closed_by`) add kinds without rewriting the harness. |
| EQM-014 | COMPLETE | EQM-013 | `docs/plan/2026-06-09_event_queue_manager/EQM-014_event_model_semantics/` | Event model semantics spec, progression (event-line) model, and ordering coverage matrix. | `docs/design/EVENT_MODEL_SEMANTICS.md`, `docs/design/ORDERING_MODEL_COVERAGE.md`, `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md`, `docs/design/EVENT_MODEL_CONCEPTS.md` | Builds on the confirmed three-plane model (`docs/design/EVENT_MODEL_CONCEPTS.md`: event-line = progression input / event = ordered output / `event_line_progressed` = trace observation) and records adopted/rejected for all `EVENT_MODEL_OPEN_QUESTIONS.md` items per the 2026-06-14 decisions (`docs/review/EVENT_MODEL_OPEN_QUESTIONS_SYNTHESIS_2026-06-14.md`), including the Q26 event-line identity/granularity/lifecycle resolution. Reserves these contracts in Phase1/2 (backend impl may defer to Phase4/5 with no later backward-incompat break): (1) **event-line** = acceptance-defined incremental integer progression; global tick = primary event-line; event-side issuance allowed; per-entity event-line is acceptance-defined, not a built-in required field; invariant: event-line = progression input, master timeline = resolution output via single int comparator (tick/priority/sequence), due_tick rewrite forbidden (reschedule-only). (2) **solve_conditions (AND default) / invalidation_conditions (OR default)**; AND-invalidation via decremental counter event-line; OR-resolution via race pattern with a race-group id and the 3-display separation concept contract (EQM debug / game-dev debug / presentation). (3) **composite resolution comparator hook**: acceptance-provided deterministic key from serializable state (float allowed here only, never in core ordering key; live-object refs forbidden; golden-covered); final fallback = event issuance order on the default event-line; simultaneous/parallel issuance forbidden. (4) **sweep point** = post-event-resolution collection window; eager = trigger-type invalidation condition. (5) **reentrancy spec** unifying window nest (meta-cost budget, Q02) and trigger nest (bounded round + cycle guard, EQM-062), crossing cases in scope with provisional cost design. (6) **save boundary** = empty effect-processing-chunk (chunk added at resolution not issuance; window-open clears); equals an allowed sync barrier. (7) trace record kinds incl. `event_line_progressed`, `window_opened`, `window_closed`, invalidation `closed_by`. Coverage matrix maps >= 8 systems (CTB, energy, wait-turn TO/FFT-CT, FE phase, 4X phase, stack/LIFO, Pokemon-style speed turn, ATB, 行動解決ターン制); grouped/micro-event-line (Q24) and sync-barrier naming (Q25) recorded as deferred/support; unmappable cases become queue candidates before the Phase 2 API freeze. Planning note: this is a C5 task — split into SUB_TASKS at planning time (e.g. event-line + conditions contract / reentrancy + save + trace-kind / coverage matrix) per `docs/devflow/TASK_PACKET.md`. **Split 2026-06-15 (user-approved) into EQM-014.01/.02/.03** (umbrella row; COMPLETE via the three sub-tasks, all COMPLETE 2026-06-15). |
| EQM-014.01 | COMPLETE | EQM-013 | `docs/plan/2026-06-09_event_queue_manager/EQM-014.01_semantics_spec/` | Event model semantics spec: three-plane model + the 7 reserved contract groups + driver/await reservation + Q03 deadline window. | `docs/design/EVENT_MODEL_SEMANTICS.md` | Records the 7 contract groups (event-line; solve AND/invalidation OR + race pattern + race-group/3-display; composite comparator hook; sweep/eager; unified reentrancy; save boundary; trace kinds) consistently with `EVENT_MODEL_CONCEPTS.md`; states Phase1/2 reservation with no Phase4/5 backward-incompat break; layer L0–L3 separation noted. Docs-only acceptance (no Godot run); gate = contract consistency + `./tools/test.sh` unaffected (green). |
| EQM-014.02 | COMPLETE | EQM-014.01 | `docs/plan/2026-06-09_event_queue_manager/EQM-014.02_ordering_coverage/` | Ordering coverage matrix mapping >= 8 systems to the model. | `docs/design/ORDERING_MODEL_COVERAGE.md` | Every matrix row resolves to mapped-or-queue-candidate; 4X (Q13) and 行動解決ターン制 shown mappable; grouped/micro-event-line (Q24) deferred and sync-barrier (Q25) support recorded; any unmappable case recorded as a Phase-2-freeze-gating queue candidate. Docs-only. |
| EQM-014.03 | COMPLETE | EQM-014.02 | `docs/plan/2026-06-09_event_queue_manager/EQM-014.03_registry_concepts/` | Open-questions registry finalization + concepts reconciliation. | `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md`, `docs/design/EVENT_MODEL_CONCEPTS.md` | adopted/rejected for all Q01–Q26 present at a settled status per the 2026-06-14 decisions; Q17/Q24/Q25 recorded as defer/support; CONCEPTS Q26 pointer reconciled to the now-settled decision. **Phase 2 API freeze gates on this task** (terminal of the EQM-014 group). Docs-only. |

## Phase 2 — Resource/API contract

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-020 | COMPLETE | EQM-014.03 | `docs/plan/2026-06-09_event_queue_manager/EQM-020_config_policy_resources/` | `EQConfig` and `EQPolicy` base Resources with validation, plus error taxonomy. | `resources/eq_config.gd`, `resources/policies/eq_policy.gd`, `docs/design/ERROR_CONTRACT.md`, `tests/resource/` | Resource can be saved/loaded; missing policy and ambiguous tie-breaker produce explicit validation results; contracts follow `docs/design/EVENT_MODEL_SEMANTICS.md`; error taxonomy (stable codes, recoverability classes, game/editor surfacing rules) documented in `ERROR_CONTRACT.md` and used by validation; recoverability classes map to the dev fail-fast / shipped fail-safe two modes of `docs/devflow/policy/RUNTIME_RESILIENCE_POLICY.md`. |
| EQM-021 | COMPLETE | EQM-020 | `docs/plan/2026-06-09_event_queue_manager/EQM-021_actor_action_contract/` | Actor state and action result public API. | `runtime/eq_actor_state.gd`, `runtime/eq_action_result.gd`, `runtime/eq_actor_registry.gd`, `tests/resource/` | Actor id registration, duplicate rejection, weak binding placeholder, action cost/delay result validation tested. |
| EQM-022 | COMPLETE | EQM-021 | `docs/plan/2026-06-09_event_queue_manager/EQM-022_manager_headless_facade/` | Headless facade that coordinates scheduler, policy, actors, and action finish. | `runtime/eq_runtime.gd`, `tests/core/` | Register actors, start queue, pop ready event, finish action, and schedule next event without Godot scene tree; exposes the dev/shipped resilience mode toggle, with normal-input traces byte-identical across modes (`RUNTIME_RESILIENCE_POLICY.md`). |
| EQM-023 | COMPLETE | EQM-022 | `docs/plan/2026-06-09_event_queue_manager/EQM-023_api_surface_gate/` | Layer-aware public API surface snapshot gate. | `tools/check_api_surface.py`, `tests/golden/api_surface.json`, `docs/design/API_SURFACE.md` | Public/internal naming convention documented; the API surface is tagged by layer (L0 turn order / L1 policy / L2 reservation / L3 event-line) per roadmap §3.1; deterministic export; a change that leaks an L3 symbol into the L0/L1 surface, or any surface diff without a doc note, fails `./tools/test.sh`; golden update follows the explicit approval procedure. |

## Phase 3 — Basic policy MVP and runtime Node

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-030 | COMPLETE | EQM-022 | `docs/plan/2026-06-09_event_queue_manager/EQM-030_fixed_round_policy/` | Fixed round policy with initiative and tie-breaker options. | `resources/policies/eq_fixed_round_policy.gd`, `tests/policy/` | Tests cover battle-start ordering, round refresh, equal initiative tie-break, actor removal skip. |
| EQM-031 | COMPLETE | EQM-030 | `docs/plan/2026-06-09_event_queue_manager/EQM-031_ctb_policy/` | CTB policy with speed and action cost. | `resources/policies/eq_ctb_policy.gd`, `tests/policy/` | Tests cover faster actor extra turns, heavy action delay, wait action shorter delay, haste/slow next-turn behavior. |
| EQM-032 | READY | EQM-031 | `docs/plan/2026-06-09_event_queue_manager/EQM-032_eq_manager_node/` | Godot `EQManager` Node, signal integration, and game-loop driver contract. | `runtime/eq_manager.gd`, `addons/event_queue_manager/plugin.gd`, `tests/runtime/` | Scene-local manager emits `queue_changed`, `event_ready`, `turn_ready`, `event_resolved`; invalid actor policy tested; game-loop driver contract (who advances the queue, suspend semantics awaiting player input, await boundary for action presentation) documented in `EVENT_MODEL_SEMANTICS.md` and covered by tests; the driver offers a frame-budget / time-sliced advance mode (resolve up to a per-frame budget to avoid large-battle hitches) and coexists with Godot idioms (`SceneTree` pause, and `EditorUndoRedoManager` for editor-side mutations) without breaking determinism. |
| EQM-033 | BACKLOG | EQM-032 | `docs/plan/2026-06-09_event_queue_manager/EQM-033_prediction_preview/` | Next-N prediction as a pure hypothetical API (for HUD and AI planning). | `runtime/eq_prediction.gd`, `runtime/eq_snapshot.gd`, `tests/core/` | Prediction returns expected order; live queue remains unchanged (snapshot before == after, prediction purity); deterministic seed state preserved; exposes a hypothetical-branch API (branch snapshot → virtual advance with a candidate action → discard) so AI/players can compare act-now vs wait without mutating live state (roadmap principle 17); watched-set is re-evaluated per simulated step, independent of prediction depth N (Q26). |
| EQM-034 | BACKLOG | EQM-033 | `docs/plan/2026-06-09_event_queue_manager/EQM-034_ctb_sample_battle/` | Minimal CTB sample battle and quickstart docs. | `demos/ctb_battle/`, `docs/manual/quickstart.md`, `tests/debug_scene/` | Sample is explicitly learning path; quickstart uses project-created config; sample scene runs or is marked `BLOCKED_BY_TEST_ENV` with proof. |
| EQM-035 | BACKLOG | EQM-034 | `docs/plan/2026-06-09_event_queue_manager/EQM-035_v0_1_milestone_evaluation/` | v0.1 milestone evaluation (API friction, semantics drift, queue adjustment, value metrics). | `docs/review/` | Evaluation report exists; semantics spec vs implementation drift is audited; API friction findings and gaps become queue candidates or explicit no-change records; product-value north-star metrics defined and baselined (e.g. simple-path completion without L3, dogfood friction count, layer-leak count); roadmap updated or confirmed unchanged. |

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
| EQM-053 | BACKLOG | EQM-052 | `docs/plan/2026-06-09_event_queue_manager/EQM-053_policy_reducibility_proofs/` | Policy reducibility proofs (dedicated policies as reservation/event-line degenerate cases). | `tests/policy/`, `tests/golden/` | CTB, energy, and wait-turn (TO/FFT-CT) configurations expressed via the reservation + event-line model reproduce the dedicated policies' golden traces across tie-break / speed / delay matrices; per-tick event-line polling (Q17) and any optimized backend produce identical traces; reducibility proves the model's generality but does not mandate that every model reduce — independent `EQPolicy` implementations remain permitted (roadmap §1.1); divergences are recorded as model gaps feeding the next evaluation. |

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
| EQM-085 | BACKLOG | EQM-032, EQM-072, EQM-082 | `docs/plan/2026-06-09_event_queue_manager/EQM-085_godot_node_bridge/` | Godot node bridge: save/load rebind adapter, optional autoload installer, actor-deletion handling, full multi-domain signal bridge. | `runtime/eq_node_bridge.gd`, `runtime/eq_save_adapter.gd`, `tests/runtime/` | Save/load stores `actor_id` + Resources, never live Nodes, and rebinds on load; actor deletion routes pending events through the Q05 invalidation path; optional autoload installer is opt-in (scene-local default per profile); signal bridge covers turn/reservation/trigger/effect/presentation/invalid; tests cover scene-local manager, actor deletion, and save/load rebind (roadmap Phase 9 "Godot runtime integration"). |
| EQM-083 | BACKLOG | EQM-033, EQM-082 | `docs/plan/2026-06-09_event_queue_manager/EQM-083_runtime_timeline_hud/` | Player-facing runtime timeline HUD + consumer runtime debug overlay. | `runtime/ui/eq_timeline_hud.gd`, `runtime/ui/eq_timeline_hud.tscn`, `runtime/ui/eq_debug_overlay.gd`, `tests/ui_headless/` | HUD renders injected prediction (projection integrity in-game); updates on `queue_changed`; shows explicit stale state while presentation is deferred; controls carry `ui_metric_id` metadata; no UI-side order recomputation; HUD labels are localizable and order/state uses non-text modality (icon/badge) for colorblind/screen-reader safety; a separate opt-in debug overlay/log hook lets a developer inspect the live order and "why next" in their own game. |
| EQM-084 | BACKLOG | EQM-083 | `docs/plan/2026-06-09_event_queue_manager/EQM-084_dogfood_vertical_slice/` | Dogfood consumer slice: minimal playable Action Resolution Turn-Based game consuming only the public addon API (exercises EQM-085 save/load if present). | `dogfood/`, `docs/review/`, `tests/golden/` | Slice uses public API only (no runtime internals); ships its own golden trace; friction report `docs/review/DOGFOOD_FRICTION_<date>.md` records API ergonomics findings; findings become queue candidates or explicit no-change records. |

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
| EQM-100 | BACKLOG | EQM-082 | `docs/plan/2026-06-09_event_queue_manager/EQM-100_manual_reservations/` | Reservation and Action Resolution manual, plus the mental-model chapter. | `docs/manual/concepts.md`, `docs/manual/reservations.md`, `docs/manual/action_resolution.md` | Manual matches current API; examples avoid sample-only assumptions; rollback/wait/ready semantics documented; a concepts chapter teaches the three-plane mental model (event-line / event / trace) from `docs/design/EVENT_MODEL_CONCEPTS.md` and the L0→L3 layering so simple-path users never need L3. |
| EQM-101 | BACKLOG | EQM-092, EQM-100 | `docs/plan/2026-06-09_event_queue_manager/EQM-101_demo_suite/` | Multi-genre demo suite. | `demos/`, `docs/manual/policy_selection.md`, `tests/golden/` | CTB, energy, wait-turn, action-resolution, phase, and stack demos load or are environment-blocked with proof; each demo emits its golden trace headless per `DETERMINISM_TRACE_TEST_POLICY.md`. |
| EQM-102 | BACKLOG | EQM-101 | `docs/plan/2026-06-09_event_queue_manager/EQM-102_performance_backend/` | Binary heap backend and trigger indexing. | `runtime/backends/eq_binary_heap_backend.gd`, `runtime/eq_trigger_index.gd`, `tests/performance/` | Numeric performance budgets (actor count, event count, per-advance cost) declared before benchmarking; large queue benchmark judged against the budgets with order correctness; backend selectable without public API break. |
| EQM-103 | BACKLOG | EQM-102 | `docs/plan/2026-06-09_event_queue_manager/EQM-103_package_release_candidate/` | v1.0 release candidate package proof. | `addons/event_queue_manager/`, `README.md`, `LICENSE`, `docs/review/` | Clean project load, addon manifest, docs links, sample isolation, and final self-review complete; snapshot schema compatibility stance (preserve/migrate/replace/defer) declared for v1.0; LICENSE chosen (AssetLib-compatible) and AssetLib submission requirements checked; copied game names treated clean-room. |

## Dynamic follow-up area

Add `follow-up-ready` tasks here during execution when a current task is complete but reveals nonblocking follow-up work.

| id | status | dependencies | source task | deliverable | acceptance / test path |
|---|---|---|---|---|---|
| — | — | — | — | — | — |

## Current pointer

Current: `EQM-032` (Phase 3 autonomous run; 030/031 COMPLETE → 032 → 033 → 034 → 035 = v0.1 MVP milestone)

## Proof log

### EQM-001 — COMPLETE (2026-06-14)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-001_devflow_profile/
  review: docs/review/autopilot/EQM-001_SELF_REVIEW_2026-06-14.md
  tests:
    - ./tools/test.sh  -> exit 3 BLOCKED_BY_TEST_ENV (Godot absent); harness behaves as specified
  docs:
    - docs/devflow/TEST.md (filled), docs/devflow/PROJECT_PROFILE.md (EQM-specialized)
  major files:
    - tools/test.sh (new, executable), .gitignore (+.godot_user/)
    - .agents/skills/roadmap-autopilot/SKILL.md (wording)
```

Dependency sweep: EQM-001 COMPLETE → EQM-002 READY. Current pointer → EQM-002.

### EQM-002 — COMPLETE (2026-06-14)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-002_addon_scaffold/
  review: docs/review/autopilot/EQM-002_SELF_REVIEW_2026-06-14.md
  pattern: P0 (orchestrator-direct)
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); Godot 4.6.2 headless ran test_project smoke
  major files:
    - addons/event_queue_manager/{plugin.cfg,plugin.gd,runtime/eq_version.gd} (new)
    - test_project/{project.godot,tests/run_all.gd} (new)
    - test_project/addons/event_queue_manager -> ../../addons/event_queue_manager (symlink)
```

Dependency sweep: EQM-002 COMPLETE → EQM-010 READY. Current pointer → EQM-010.

### EQM-010 — COMPLETE (2026-06-14)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-010_core_event_contract/
  review: docs/review/autopilot/EQM-010_SELF_REVIEW_2026-06-14.md
  pattern: P0 (orchestrator-direct); repair 1/3 (headless class_name → import pass + guard)
  tests:
    - ./tools/test.sh (clean) -> RESULT: PASS (exit 0); files=2 checks=9 failures=0
  major files:
    - addons/event_queue_manager/runtime/{eq_entry.gd,eq_ordering.gd} (new)
    - test_project/tests/{eq_test.gd,run_all.gd,core/test_scaffold.gd,core/test_eq_ordering.gd}
    - tools/test.sh (import pass + masked-failure guard)
```

Dependency sweep: EQM-010 COMPLETE → EQM-011 READY. Current pointer → EQM-011.

### EQM-011 — COMPLETE (2026-06-14)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-011_scheduler_operations/
  review: docs/review/autopilot/EQM-011_SELF_REVIEW_2026-06-14.md
  pattern: P0 (orchestrator-direct); repair 1/3 (test-only param type; no product change)
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=4 checks=50 failures=0
  gate: §4 core (ordering property + metamorphic backend-equivalence); full golden harness deferred to EQM-013
  major files:
    - addons/event_queue_manager/runtime/eq_scheduler.gd (new)
    - addons/event_queue_manager/runtime/backends/{eq_backend.gd,eq_sorted_array_backend.gd} (new)
    - test_project/tests/core/{test_eq_scheduler.gd,test_eq_backend_contract.gd} (new)
```

Dependency sweep: EQM-011 COMPLETE → EQM-012 READY. Current pointer → EQM-012.

### EQM-012 — COMPLETE (2026-06-14)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-012_snapshot_roundtrip/
  review: docs/review/autopilot/EQM-012_SELF_REVIEW_2026-06-14.md
  pattern: P0 (orchestrator-direct); repair 0/3 (gate green first run)
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=5 checks=74 failures=0
  gate: §4 core (snapshot roundtrip/continuity fidelity + stable load-error contract); golden harness deferred to EQM-013
  major files:
    - addons/event_queue_manager/runtime/eq_snapshot.gd (new)
    - addons/event_queue_manager/runtime/eq_scheduler.gd (snapshot/restore added)
    - test_project/tests/core/test_eq_snapshot.gd (new)
```

Dependency sweep: EQM-012 COMPLETE → EQM-013 READY. Current pointer → EQM-013.

### EQM-013 — COMPLETE (2026-06-14)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-013_trace_determinism_harness/
  review: docs/review/autopilot/EQM-013_SELF_REVIEW_2026-06-14.md
  pattern: P0 (orchestrator-direct); repair 1/3 (test-only param type; no product change)
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=7 checks=92 failures=0
    - ./tools/test.sh --update-golden core_scheduler_basic -> golden baseline written, run PASS
  gate: §4 core (golden exact-match + property: replay determinism / permutation invariance / snapshot continuity / decided_by integrity / open kind schema)
  golden: tests/golden/core_scheduler_basic.trace.jsonl (initial baseline, recorded in self-review per DETERMINISM_TRACE_TEST_POLICY §2)
  major files:
    - addons/event_queue_manager/runtime/eq_trace.gd (new)
    - tools/test.sh (EQ_RUN_OUT export)
    - test_project/tests/golden/core_scheduler_basic.trace.jsonl (new)
    - test_project/tests/core/{test_eq_trace_golden.gd,test_eq_trace_properties.gd} (new)
```

Dependency sweep: EQM-013 COMPLETE → EQM-014 READY. Current pointer → EQM-014.
CHECKPOINT: EQM-014 is depth=decision (event model semantics, C5). Autonomous loop stops here for user direction (QUEUE_EXECUTION_PATTERNS §8.3).

### EQM-014 — SPLIT_REQUIRED → split (2026-06-15, user-approved)

```text
status: SPLIT_REQUIRED (docs/state)
reason: C5 with multiple completion boundaries (semantics spec / coverage matrix / registry+concepts).
        Per TASK_PACKET C5, split into queued sub-tasks before implementation.
plan: docs/plan/2026-06-09_event_queue_manager/EQM-014_event_model_semantics/SUB_TASKS.md (umbrella, user-reviewed)
split (.NN convention, TASK_PACKET §plan scheduling):
  - EQM-014.01 semantics spec       (dep EQM-013)     -> docs/design/EVENT_MODEL_SEMANTICS.md
  - EQM-014.02 ordering coverage     (dep EQM-014.01)  -> docs/design/ORDERING_MODEL_COVERAGE.md
  - EQM-014.03 registry+concepts     (dep EQM-014.02)  -> EVENT_MODEL_OPEN_QUESTIONS.md / EVENT_MODEL_CONCEPTS.md
dependency re-point: EQM-020 dep EQM-014 -> EQM-014.03 (terminal of group). Phase 2 API freeze gates on EQM-014.03.
user decisions: split approved; numbering arbitrary (use .NN convention); Q17 prediction-depth-N deferred to EQM-033/102.
```

Dependency sweep: EQM-013 COMPLETE → EQM-014.01 READY (EQM-014 umbrella SPLIT_REQUIRED). Current pointer → EQM-014.01.

### EQM-014.01 — COMPLETE (2026-06-15)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-014.01_semantics_spec/ (+ umbrella EQM-014 SUB_TASKS.md)
  review: docs/review/autopilot/EQM-014.01_SELF_REVIEW_2026-06-15.md
  pattern: P0 (orchestrator-direct, decision-depth docs, user-approved after plan review); repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=7 checks=92 failures=0 (docs change does not affect build/tests)
  gate: docs-only contract consistency (7 contract groups consistent with CONCEPTS; Phase1/2 reservation boundary explicit)
  major files:
    - docs/design/EVENT_MODEL_SEMANTICS.md (new)
```

Dependency sweep: EQM-014.01 COMPLETE → EQM-014.02 READY. Current pointer → EQM-014.02.

### EQM-014.02 — COMPLETE (2026-06-15)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-014.02_ordering_coverage/ (+ umbrella SUB_TASKS.md)
  review: docs/review/autopilot/EQM-014.02_SELF_REVIEW_2026-06-15.md
  pattern: P0 (orchestrator-direct, decision-depth docs); repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=7 checks=92 failures=0
  gate: docs-only; 9 systems all mapped, no unmappable case -> no new Phase-2-freeze candidate
  finding: 4X (Q13) maps via N event-lines + shared primary tick; 行動解決ターン制 maps via AP-recovery line + ready reservation + reaction-count decremental invalidation; WT next-threshold trace-equality deferred to EQM-053
  major files:
    - docs/design/ORDERING_MODEL_COVERAGE.md (new)
```

Dependency sweep: EQM-014.02 COMPLETE → EQM-014.03 READY. Current pointer → EQM-014.03.

### EQM-014.03 — COMPLETE (2026-06-15) — closes the EQM-014 group

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-014.03_registry_concepts/ (+ umbrella SUB_TASKS.md)
  review: docs/review/autopilot/EQM-014.03_SELF_REVIEW_2026-06-15.md
  pattern: P0 (orchestrator-direct, decision-depth docs); repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=7 checks=92 failures=0
  gate: docs-only; Q01–Q26 settled w/ decision-location pointer map; Q17 N deferred (EQM-033/102); CONCEPTS Q26 reconciled
  major files:
    - docs/design/EVENT_MODEL_OPEN_QUESTIONS.md (finalization banner + pointer map + Q17 defer)
    - docs/design/EVENT_MODEL_CONCEPTS.md (Q26 pointer reconciled)
```

EQM-014 group COMPLETE (014.01 semantics spec / 014.02 coverage matrix / 014.03 registry+concepts). The four design docs (CONCEPTS / SEMANTICS / COVERAGE / OPEN_QUESTIONS) are v1-authoritative and mutually consistent.

Dependency sweep: EQM-014.03 COMPLETE → EQM-020 READY (EQM-014 umbrella COMPLETE via sub-tasks). Current pointer → EQM-020.
CHECKPOINT: **Phase 2 API freeze boundary** (milestone, §8.3). Autonomous run paused for user direction before entering Phase 2 (EQM-020: EQConfig/EQPolicy + error taxonomy).
User direction 2026-06-15: proceed autonomously through Phase 2 (EQM-020→023) to the Phase 2 milestone; consult on design forks.

### EQM-020 — COMPLETE (2026-06-15)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-020_config_policy_resources/
  review: docs/review/autopilot/EQM-020_SELF_REVIEW_2026-06-15.md
  pattern: P0 (orchestrator-direct); repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=9 checks=132 failures=0
  gate: §4 resource/API (validation + .tres roundtrip); error taxonomy established
  major files:
    - addons/event_queue_manager/runtime/{eq_error.gd,eq_validation.gd} (new)
    - addons/event_queue_manager/resources/eq_config.gd, resources/policies/eq_policy.gd (new)
    - docs/design/ERROR_CONTRACT.md (new)
    - test_project/tests/resource/{test_eq_error_taxonomy.gd,test_eq_config.gd} (new)
```

Dependency sweep: EQM-020 COMPLETE → EQM-021 READY. Current pointer → EQM-021.

### EQM-021 — COMPLETE (2026-06-15)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-021_actor_action_contract/
  review: docs/review/autopilot/EQM-021_SELF_REVIEW_2026-06-15.md
  pattern: P0 (orchestrator-direct); repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=11 checks=167 failures=0
  gate: §4 resource/API (registration/duplicate/reuse/empty rejection + weak binding + action validation)
  major files:
    - addons/event_queue_manager/runtime/{eq_actor_state.gd,eq_action_result.gd,eq_actor_registry.gd} (new); eq_error.gd (+5 codes)
    - docs/design/ERROR_CONTRACT.md (+5 codes)
    - test_project/tests/resource/{test_eq_actor_registry.gd,test_eq_action_result.gd} (new)
```

Dependency sweep: EQM-021 COMPLETE → EQM-022 READY. Current pointer → EQM-022.

### EQM-022 — COMPLETE (2026-06-15)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-022_manager_headless_facade/
  review: docs/review/autopilot/EQM-022_SELF_REVIEW_2026-06-15.md
  pattern: P0 (orchestrator-direct); repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=12 checks=191 failures=0
  gate: §4 runtime/integration (dev/shipped two-mode resilience + mode neutrality + shipped-skip scheduler integrity)
  major files:
    - addons/event_queue_manager/runtime/eq_runtime.gd (new); eq_error.gd (+2 runtime codes)
    - docs/design/ERROR_CONTRACT.md (+2 codes)
    - test_project/tests/core/test_eq_runtime.gd (new)
```

Dependency sweep: EQM-022 COMPLETE → EQM-023 READY. Current pointer → EQM-023.

### EQM-023 — COMPLETE (2026-06-15) — Phase 2 milestone

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-023_api_surface_gate/
  review: docs/review/autopilot/EQM-023_SELF_REVIEW_2026-06-15.md
  pattern: P0 (orchestrator-direct); repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=12 checks=191 failures=0
    - [api-surface] self-test ok; surface matches golden; no untagged; no L3 leak
    - negative (source-unmodified): untagged + leak detectors both fire
  gate: §4 resource/API (layer-aware surface snapshot + L3-leak gate)
  golden: tests/golden/api_surface.json (16 classes: core 10 / L0 4 / L1 2), initial baseline via --update
  major files:
    - tools/check_api_surface.py (new), tools/test.sh (wired), docs/design/API_SURFACE.md (new)
```

Dependency sweep: EQM-023 COMPLETE → **Phase 2 (resource/API) milestone reached** (EQM-020..023 COMPLETE). EQM-030 READY (dep EQM-022). Current pointer → EQM-030.
CHECKPOINT: Phase 2/3 milestone boundary (§8.3). Autonomous run paused for user direction before Phase 3 (EQM-030: fixed round policy — first concrete EQPolicy).
User direction 2026-06-15: proceed autonomously through Phase 3 (EQM-030→035) to the v0.1 MVP milestone; consult on design forks.

### EQM-030 — COMPLETE (2026-06-15)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-030_fixed_round_policy/
  review: docs/review/autopilot/EQM-030_SELF_REVIEW_2026-06-15.md
  pattern: P0 (orchestrator-direct); repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=13 checks=197 failures=0; [api-surface] ok
  gate: §4 policy (battle-start/round-refresh/tie-break/removal) + API surface (EQFixedRoundPolicy L1, no leak)
  surface: api_surface.json re-baselined (EQPolicy +seed/+on_turn_finished, +EQFixedRoundPolicy L1) via explicit --update
  major files:
    - addons/event_queue_manager/resources/policies/{eq_policy.gd(+contract),eq_fixed_round_policy.gd(new)}
    - tools/check_api_surface.py (LAYER_MAP), docs/design/API_SURFACE.md, tests/golden/api_surface.json
    - test_project/tests/policy/test_eq_fixed_round_policy.gd (new)
```

Dependency sweep: EQM-030 COMPLETE → EQM-031 READY. Current pointer → EQM-031.

### EQM-031 — COMPLETE (2026-06-15)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-031_ctb_policy/
  review: docs/review/autopilot/EQM-031_SELF_REVIEW_2026-06-15.md
  pattern: P0 (orchestrator-direct); repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=14 checks=206 failures=0; [api-surface] ok
  gate: §4 policy (faster-more-turns/heavy-delay/wait-shorter/haste-slow) + API surface (EQCTBPolicy L1)
  surface: api_surface.json re-baselined (+EQCTBPolicy L1) via explicit --update
  major files:
    - addons/event_queue_manager/resources/policies/eq_ctb_policy.gd (new)
    - tools/check_api_surface.py, docs/design/API_SURFACE.md, tests/golden/api_surface.json
    - test_project/tests/policy/test_eq_ctb_policy.gd (new)
```

Dependency sweep: EQM-031 COMPLETE → EQM-032 READY. Current pointer → EQM-032.
