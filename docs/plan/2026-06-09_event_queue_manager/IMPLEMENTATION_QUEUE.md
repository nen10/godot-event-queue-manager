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
| EQM-032 | COMPLETE | EQM-031 | `docs/plan/2026-06-09_event_queue_manager/EQM-032_eq_manager_node/` | Godot `EQManager` Node, signal integration, and game-loop driver contract. | `runtime/eq_manager.gd`, `addons/event_queue_manager/plugin.gd`, `tests/runtime/` | Scene-local manager emits `queue_changed`, `event_ready`, `turn_ready`, `event_resolved`; invalid actor policy tested; game-loop driver contract (who advances the queue, suspend semantics awaiting player input, await boundary for action presentation) documented in `EVENT_MODEL_SEMANTICS.md` and covered by tests; the driver offers a frame-budget / time-sliced advance mode (resolve up to a per-frame budget to avoid large-battle hitches) and coexists with Godot idioms (`SceneTree` pause, and `EditorUndoRedoManager` for editor-side mutations) without breaking determinism. |
| EQM-033 | COMPLETE | EQM-032 | `docs/plan/2026-06-09_event_queue_manager/EQM-033_prediction_preview/` | Next-N prediction as a pure hypothetical API (for HUD and AI planning). | `runtime/eq_prediction.gd`, `runtime/eq_snapshot.gd`, `tests/core/` | Prediction returns expected order; live queue remains unchanged (snapshot before == after, prediction purity); deterministic seed state preserved; exposes a hypothetical-branch API (branch snapshot → virtual advance with a candidate action → discard) so AI/players can compare act-now vs wait without mutating live state (roadmap principle 17); watched-set is re-evaluated per simulated step, independent of prediction depth N (Q26). |
| EQM-034 | COMPLETE | EQM-033 | `docs/plan/2026-06-09_event_queue_manager/EQM-034_ctb_sample_battle/` | Minimal CTB sample battle and quickstart docs. | `demos/ctb_battle/`, `docs/manual/quickstart.md`, `tests/debug_scene/` | Sample is explicitly learning path; quickstart uses project-created config; sample scene runs or is marked `BLOCKED_BY_TEST_ENV` with proof. |
| EQM-035 | COMPLETE | EQM-034 | `docs/plan/2026-06-09_event_queue_manager/EQM-035_v0_1_milestone_evaluation/` | v0.1 milestone evaluation (API friction, semantics drift, queue adjustment, value metrics). | `docs/review/` | Evaluation report exists; semantics spec vs implementation drift is audited; API friction findings and gaps become queue candidates or explicit no-change records; product-value north-star metrics defined and baselined (e.g. simple-path completion without L3, dogfood friction count, layer-leak count); roadmap updated or confirmed unchanged. |

## Phase 4 — Energy and Wait Turn policies

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-040 | COMPLETE | EQM-034 | `docs/plan/2026-06-09_event_queue_manager/EQM-040_energy_policy/` | Roguelike energy policy. | `resources/policies/eq_energy_policy.gd`, `tests/policy/` | Threshold readiness, action cost, speed differences, wait, and energy carry-over tested. |
| EQM-041 | COMPLETE | EQM-040 | `docs/plan/2026-06-09_event_queue_manager/EQM-041_wait_turn_policy/` | Tactics Ogre-style wait-turn policy. | `resources/policies/eq_wait_turn_policy.gd`, `tests/policy/`, `demos/wait_turn_tactics/` | Units with wait values resolve instantly to next ready unit; action cost modifies next wait; equal wait tie-break explained. |

## Phase 5 — Action Reservation model

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-050 | COMPLETE | EQM-041 | `docs/plan/2026-06-09_event_queue_manager/EQM-050_reservation_schema/` | Reservation Resource/API schema. | `resources/eq_action_definition.gd`, `runtime/eq_reservation.gd`, `tests/resource/` | Immediate, prepared, reaction preparation, wait, ready reservation, operation action, tags, duration, rumination fields validate. |
| EQM-051 | COMPLETE | EQM-050 | `docs/plan/2026-06-09_event_queue_manager/EQM-051_reservation_resolution/` | Reservation scheduling and resolution pipeline. | `runtime/eq_reservation_runtime.gd`, `tests/core/` | Immediate action resolves at delay 0; prepared action resolves after delay; wait schedules ready reservation; operation action causes target reservation. |
| EQM-052 | COMPLETE | EQM-051 | `docs/plan/2026-06-09_event_queue_manager/EQM-052_ap_ready_model/` | AP and ready reservation model for Action Resolution Turn-Based. | `resources/policies/eq_action_resolution_policy.gd`, `tests/policy/` | Ready reservation grants turn after AP recovery delay; AP spending and recovery are deterministic; turn closes through wait. |
| EQM-053 | COMPLETE | EQM-052 | `docs/plan/2026-06-09_event_queue_manager/EQM-053_policy_reducibility_proofs/` | Policy reducibility proofs (dedicated policies as reservation/event-line degenerate cases). | `tests/policy/`, `tests/golden/` | CTB, energy, and wait-turn (TO/FFT-CT) configurations expressed via the reservation + event-line model reproduce the dedicated policies' golden traces across tie-break / speed / delay matrices; per-tick event-line polling (Q17) and any optimized backend produce identical traces; reducibility proves the model's generality but does not mandate that every model reduce — independent `EQPolicy` implementations remain permitted (roadmap §1.1); divergences are recorded as model gaps feeding the next evaluation. |

## Phase 6 — Trigger and reaction engine

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-060 | COMPLETE | EQM-052 | `docs/plan/2026-06-09_event_queue_manager/EQM-060_condition_contract/` | Condition and tag matching contract. | `resources/eq_condition.gd`, `runtime/eq_tag_matcher.gd`, `tests/trigger/` | Conditions can match event type, source, target, tags, range/sensing adapter placeholder, and custom predicate. |
| EQM-061 | COMPLETE | EQM-060 | `docs/plan/2026-06-09_event_queue_manager/EQM-061_reaction_preparation/` | Reaction preparation runtime. | `runtime/eq_trigger_engine.gd`, `tests/trigger/` | Counterattack preparation triggers on incoming `<損害>` reservation; duration expiry prevents trigger; owner/source matching tested. |
| EQM-062 | COMPLETE | EQM-061 | `docs/plan/2026-06-09_event_queue_manager/EQM-062_rumination_cycle_guard/` | Rumination and cycle prevention. | `runtime/eq_reservation_runtime.gd`, `runtime/eq_trigger_engine.gd`, `tests/trigger/` | Rumination count decrements and reschedules; max chain guard stops infinite loops with explicit error/event. |

## Phase 7 — Transaction and rollback

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-070 | COMPLETE | EQM-062 | `docs/plan/2026-06-09_event_queue_manager/EQM-070_transaction_snapshot/` | Player turn draft transaction. | `runtime/eq_transaction.gd`, `runtime/eq_snapshot.gd`, `tests/transaction/` | Draft actions can be applied, inspected, rolled back, and committed; live scheduler unchanged before commit. |
| EQM-071 | COMPLETE | EQM-070 | `docs/plan/2026-06-09_event_queue_manager/EQM-071_wait_commit_boundary/` | Wait/end-turn commit boundary. | `runtime/eq_transaction.gd`, `resources/policies/eq_action_resolution_policy.gd`, `tests/transaction/` | Player immediate actions are rollbackable before wait; wait commits draft and schedules ready reservation. |
| EQM-072 | COMPLETE | EQM-071 | `docs/plan/2026-06-09_event_queue_manager/EQM-072_deterministic_replay/` | Deterministic random and replay proof. | `runtime/eq_rng.gd`, `runtime/eq_snapshot.gd`, `tests/transaction/` | Snapshot restore reproduces random-dependent order and results under same seed. |

## Phase 8 — Effect and presentation pipeline

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-080 | COMPLETE | EQM-072 | `docs/plan/2026-06-09_event_queue_manager/EQM-080_effect_records/` | Simulation effect and presentation event records. | `runtime/eq_effect_record.gd`, `runtime/eq_presentation_event.gd`, `tests/presentation/` | Status effects record immediately; presentation requests can be queued separately with actor/position references. |
| EQM-081 | COMPLETE | EQM-080 | `docs/plan/2026-06-09_event_queue_manager/EQM-081_visibility_flush_policy/` | Importance/sensing/offscreen presentation policy. | `resources/eq_presentation_policy.gd`, `runtime/eq_presentation_buffer.gd`, `tests/presentation/` | Important event flushes previous visuals; sensed non-important defers; offscreen skips; player turn flush tested. |
| EQM-082 | COMPLETE | EQM-081 | `docs/plan/2026-06-09_event_queue_manager/EQM-082_moving_target_barrier/` | Moving-target consistency barrier. | `runtime/eq_presentation_buffer.gd`, `tests/presentation/` | Event referencing moved entity forces prior pending visuals to flush before resolving/displaying dependent event. |

## Phase 8b — Runtime order surface and dogfood

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-085 | COMPLETE | EQM-032, EQM-072, EQM-082 | `docs/plan/2026-06-09_event_queue_manager/EQM-085_godot_node_bridge/` | Godot node bridge: save/load rebind adapter, optional autoload installer, actor-deletion handling, full multi-domain signal bridge. | `runtime/eq_node_bridge.gd`, `runtime/eq_save_adapter.gd`, `tests/runtime/` | Save/load stores `actor_id` + Resources, never live Nodes, and rebinds on load; actor deletion routes pending events through the Q05 invalidation path; optional autoload installer is opt-in (scene-local default per profile); signal bridge covers turn/reservation/trigger/effect/presentation/invalid; tests cover scene-local manager, actor deletion, and save/load rebind (roadmap Phase 9 "Godot runtime integration"). |
| EQM-083 | COMPLETE | EQM-033, EQM-082 | `docs/plan/2026-06-09_event_queue_manager/EQM-083_runtime_timeline_hud/` | Player-facing runtime timeline HUD + consumer runtime debug overlay. | `runtime/ui/eq_timeline_hud.gd`, `runtime/ui/eq_timeline_hud.tscn`, `runtime/ui/eq_debug_overlay.gd`, `tests/ui_headless/` | HUD renders injected prediction (projection integrity in-game); updates on `queue_changed`; shows explicit stale state while presentation is deferred; controls carry `ui_metric_id` metadata; no UI-side order recomputation; HUD labels are localizable and order/state uses non-text modality (icon/badge) for colorblind/screen-reader safety; a separate opt-in debug overlay/log hook lets a developer inspect the live order and "why next" in their own game. |
| EQM-084 | COMPLETE | EQM-083 | `docs/plan/2026-06-09_event_queue_manager/EQM-084_dogfood_vertical_slice/` | Dogfood consumer slice: minimal playable Action Resolution Turn-Based game consuming only the public addon API (exercises EQM-085 save/load if present). | `dogfood/`, `docs/review/`, `tests/golden/` | Slice uses public API only (no runtime internals); ships its own golden trace; friction report `docs/review/DOGFOOD_FRICTION_<date>.md` records API ergonomics findings; findings become queue candidates or explicit no-change records. |

## Phase 9 — Editor tooling

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-086 | COMPLETE | EQM-034 | `docs/plan/2026-06-09_event_queue_manager/EQM-086_editor_ui_contract/` | Editor UI contract and state matrix (adoption M0). | `docs/ui/EDITOR_UI_CONTRACT.md`, `docs/ui/EDITOR_STATE_MATRIX.md` | Surfaces, required components, forbidden visible text, scenario states, and initial thresholds defined per `UI_LAYOUT_METRIC_TEST_POLICY.md`; docs-only acceptance, no Godot run required. |
| EQM-087 | COMPLETE | EQM-086 | `docs/plan/2026-06-09_event_queue_manager/EQM-087_ui_metric_harness/` | UI static audit + layout snapshot collector + WARN-only metric report (adoption M1-M3). | `tools/ui_static_audit.py`, `addons/event_queue_manager/editor/testing/`, `tests/ui_headless/` | Static audit runs inside `./tools/test.sh`; collector produces snapshot JSON for a synthetic scenario Control tree; evaluator reports metrics WARN-only; report written under `.godot_user/test-runs/`. |
| EQM-090 | COMPLETE | EQM-034, EQM-087 | `docs/plan/2026-06-09_event_queue_manager/EQM-090_timeline_dock_mvp/` | Timeline Preview Dock MVP for basic policies. | `editor/timeline_dock.tscn`, `editor/timeline_dock.gd`, `tests/ui_headless/` | User selects project config; dock shows next events or explicit unset/validation state; no silent sample default; controls carry `ui_metric_id` metadata; displayed order equals headless prediction (projection integrity); metric WARN report cited in self-review. |
| EQM-091 | COMPLETE | EQM-090 | `docs/plan/2026-06-09_event_queue_manager/EQM-091_debug_order_explanation/` | Debug order explanation view. | `editor/debug_inspector.gd`, `runtime/eq_order_explanation.gd`, `tests/ui_headless/` | For a selected event, UI can explain tick/priority/sequence/tie-break reason, rendered from structured explanation data (explanation-as-data), not free-form strings. |
| EQM-092 | COMPLETE | EQM-091, EQM-082 | `docs/plan/2026-06-09_event_queue_manager/EQM-092_action_resolution_template/` | Editor template for Action Resolution Turn-Based demo. | `editor/template_generator.gd`, `demos/action_resolution/`, `tests/ui_headless/` | Template creates project assets, not hidden sample defaults; generated demo uses reservation/trigger/presentation APIs. |
| EQM-093 | COMPLETE | EQM-090, EQM-091 | `docs/plan/2026-06-09_event_queue_manager/EQM-093_ui_metric_p0_gate/` | UI metric P0 acceptance gate (adoption M4). | `tests/ui_headless/`, `tools/test.sh` | No-op buttons, scroll reachability, state contradiction, debug leakage, float tick display, projection integrity, and sample fallback enforced as FAIL across the scenario matrix. |
| EQM-094 | COMPLETE | EQM-090 | `docs/plan/2026-06-09_event_queue_manager/EQM-094_layout_calibration_loop/` | Layout Calibration Loop MVP (tweak-and-bake debug tab + ledger). | `addons/event_queue_manager/editor/testing/eq_calibration_tab.gd`, `docs/ui/LAYOUT_CALIBRATION_LEDGER.md` | Debug-only tab edits layout params per `ui_metric_id`; Copy Layout Feedback emits schema-valid JSON per `UI_LAYOUT_CALIBRATION_POLICY.md`; tab hidden without flag (P0 test); bake procedure and cold-control ledger documented. |
| EQM-095 | COMPLETE | EQM-093, EQM-094 | `docs/plan/2026-06-09_event_queue_manager/EQM-095_ui_metric_p1_gate/` | UI metric P1 gate with calibrated thresholds (adoption M5). | `docs/ui/EDITOR_UI_CONTRACT.md`, `tests/ui_headless/` | Row geometry, truncation, and picker width thresholds updated from calibration ledger evidence; P1 gate active; exceptions declared in the contract. |

## Phase 10 — Documentation, package, release

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-100 | COMPLETE | EQM-082 | `docs/plan/2026-06-09_event_queue_manager/EQM-100_manual_reservations/` | Reservation and Action Resolution manual, plus the mental-model chapter. | `docs/manual/concepts.md`, `docs/manual/reservations.md`, `docs/manual/action_resolution.md` | Manual matches current API; examples avoid sample-only assumptions; rollback/wait/ready semantics documented; a concepts chapter teaches the three-plane mental model (event-line / event / trace) from `docs/design/EVENT_MODEL_CONCEPTS.md` and the L0→L3 layering so simple-path users never need L3. |
| EQM-101 | COMPLETE | EQM-092, EQM-100 | `docs/plan/2026-06-09_event_queue_manager/EQM-101_demo_suite/` | Multi-genre demo suite. | `demos/`, `docs/manual/policy_selection.md`, `tests/golden/` | CTB, energy, wait-turn, action-resolution, phase, and stack demos load or are environment-blocked with proof; each demo emits its golden trace headless per `DETERMINISM_TRACE_TEST_POLICY.md`. |
| EQM-102 | COMPLETE | EQM-101 | `docs/plan/2026-06-09_event_queue_manager/EQM-102_performance_backend/` | Binary heap backend and trigger indexing. | `runtime/backends/eq_binary_heap_backend.gd`, `runtime/eq_trigger_index.gd`, `tests/performance/` | Numeric performance budgets (actor count, event count, per-advance cost) declared before benchmarking; large queue benchmark judged against the budgets with order correctness; backend selectable without public API break. |
| EQM-103 | COMPLETE | EQM-102 | `docs/plan/2026-06-09_event_queue_manager/EQM-103_package_release_candidate/` | v1.0 release candidate package proof. | `addons/event_queue_manager/`, `README.md`, `LICENSE`, `docs/review/` | Clean project load, addon manifest, docs links, sample isolation, and final self-review complete; snapshot schema compatibility stance (preserve/migrate/replace/defer) declared for v1.0; LICENSE chosen (AssetLib-compatible) and AssetLib submission requirements checked; copied game names treated clean-room. |

## Phase 11 — v1.1 event-model implementation round (Q27–Q43)

Source: `docs/review/EVENT_MODEL_DESIGN_GAP_AUDIT_2026-07-02.md` (v1.0 凍結契約の未実装監査) + `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md` 実装ラウンド Q27–Q43 (DECIDED 2026-07-02)。各 task acceptance は凍結契約 ID (SEM v1.1 § / `docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md` row) を引用し、完了時に coverage row を `implemented` へ flip する (gate: `tools/check_contract_coverage.py`)。

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-110 | COMPLETE | — | `docs/plan/2026-06-09_event_queue_manager/EQM-110_semantics_round2/` | Semantics round 2: Q27–Q43 確定記述 (SEM v1.1) + registry finalization + synthesis + contract coverage gate。 | `docs/design/EVENT_MODEL_SEMANTICS.md`, `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md`, `docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md`, `docs/review/EVENT_MODEL_OPEN_QUESTIONS_SYNTHESIS_2026-07-02.md`, `tools/check_contract_coverage.py`, `tools/test.sh` | SEM v1.1 が Q27–Q43 を (v1.1) 節として additive 記録 (Q31 は宣言 linkage reconciliation)。§16.1 re-freeze 記録。registry 全 Q DECIDED(user) + pointer 表。coverage matrix + checker が test.sh gate (implemented 行の path 実在 / COMPLETE task の reserved 残留 FAIL / self-test negative)。`./tools/test.sh` PASS。 |
| EQM-111 | COMPLETE | EQM-110 | `docs/plan/2026-06-09_event_queue_manager/EQM-111_conditions_contract/` | Conditions 契約実装 (coverage: conditions-contract, named-predicate-registry)。 | `resources/eq_condition_spec.gd`, `resources/eq_action_definition.gd`, `runtime/eq_runtime.gd`, `runtime/eq_error.gd`, `docs/design/ERROR_CONTRACT.md`, `tests/resource/`, `tests/trigger/` | SEM §5.4/§5.5/§5.6: `EQConditionSpec` (LINE_THRESHOLD/COUNTER/NAMED_PREDICATE) が `.tres` roundtrip; `solve_conditions`/`invalidation_conditions` additive 追加; duration/rumination 糖衣の条件正規化; level-triggered AND / OR / invalidation-wins の評価 helper; named predicate registry (runtime instance, serializable view のみ, 未登録 load = 安定 error); ERROR_CONTRACT へ codes 追加; API surface 更新 (L2)。coverage row flip。 |
| EQM-112 | COMPLETE | EQM-111 | `docs/plan/2026-06-09_event_queue_manager/EQM-112_event_line_backend/` | Event-line backend (coverage: event-line-backend, sweep-rule-registry, progression-budgets)。 | `runtime/eq_event_lines.gd`, `runtime/eq_runtime.gd`, `runtime/eq_trace.gd`, `tests/core/`, `tests/performance/` | SEM §4.3/§4.6/§4.7/§12.1: line = {id, value, rate} data のみ; deterministic 採番; 明示 advance / re-rate; watched 導出 (pending 条件参照) + sparse polling (watched かつ rate≠0); `event_line_progressed` trace 実 emit; sweep rule registry (登録順固定, actor_id 昇順走査, rule name trace); Q43 予算 test (actor 200 / line 300 / +0.5ms 以内)。coverage rows flip。 |
| EQM-113 | COMPLETE | EQM-112 | `docs/plan/2026-06-09_event_queue_manager/EQM-113_resolution_pipeline/` | 解決 pipeline 統合 (coverage: resolution-pipeline, reaction-schedule, expiry-event, invalidate-actor)。 | `runtime/eq_runtime.gd`, `runtime/eq_reservation_runtime.gd`, `runtime/eq_trigger_engine.gd`, `runtime/eq_effect_chunk.gd`, `runtime/eq_node_bridge.gd`, `tests/core/`, `tests/trigger/` | SEM §6.1–§6.3/§13: 5-step pipeline に advance/resolve_next 統合; effect_name 宣言 linkage (未登録 = 安定 error, 空 = effect なし解決); chunk へ解決時記録 + drain; fired reaction は schedule 化 (in-place `fire_cascade` 廃止, bounded rounds + round 番号 trace); expiry event (`closed_by: duration/reaction_count/already_closed`); `invalidate_actor` (mode 中立, `closed_by: actor_removed`, bridge 配線); golden 更新は明示 flag。coverage rows flip。 |
| EQM-114 | COMPLETE | EQM-113 | `docs/plan/2026-06-09_event_queue_manager/EQM-114_window_model/` | Window object model (coverage: window-object-model)。 | `runtime/eq_window.gd`, `runtime/eq_runtime.gd`, `runtime/eq_transaction.gd`, `tests/transaction/`, `tests/runtime/` | SEM §8.1/§9: EQWindow {id, owner, nest_level, kind, deadline, budget_paid, draft}; EQTransaction 従属 (互換 wrapper); 暗黙 L0 window (turn_ready→suspend); meta-cost budget (owner state 支払い, chain 中非回復, 絶対 max depth backstop); deadline 既定 = rollback + close + `window_closed(cause: deadline)`, close 前 hook で明示 commit; `window_opened/closed` trace 実 emit。coverage row flip。 |
| EQM-115 | COMPLETE | EQM-114 | `docs/plan/2026-06-09_event_queue_manager/EQM-115_ordering_hook/` | Ordering hook (coverage: ordering-hook)。 | `runtime/eq_runtime.gd`, `resources/eq_config.gd`, `tests/core/`, `tests/golden/` | SEM §7.1: `order_simultaneous(candidates) -> permutation`; candidates view = serializable (entity stat / event tag / event-line 値 / nest level); 既定 = 発行順; hook 出力の golden 被覆; live object 拒否 validation。composite atomic bundle は defer 明記 (実装しない)。coverage row flip。 |
| EQM-116 | COMPLETE | EQM-115 | `docs/plan/2026-06-09_event_queue_manager/EQM-116_race_pattern/` | Race pattern (coverage: race-pattern)。 | `runtime/eq_reservation_runtime.gd`, `runtime/eq_trace.gd`, `runtime/ui/eq_debug_overlay.gd`, `tests/trigger/`, `tests/golden/` | SEM §5.2/§5.4: race-group id (deterministic 採番); OR 解決の racing events 発行 API; 勝者 = hook → 発行順, 敗者は OR invalidation で一掃 (`closed_by`); trace に race_group field; debug overlay で race group を候補群として集約表示 (3 表示分離の最小実装 — EQM 内部 debug と開発者 debug)。coverage row flip。 |
| EQM-117 | COMPLETE | EQM-116 | `docs/plan/2026-06-09_event_queue_manager/EQM-117_snapshot_v2/` | Snapshot v2 + save 境界 enforcement (coverage: snapshot-v2 + save-enforcement)。 | `runtime/eq_snapshot.gd`, `runtime/eq_save_adapter.gd`, `runtime/eq_manager.gd`, `docs/design/SNAPSHOT_COMPAT_V1.md`, `tests/core/`, `tests/transaction/` | SEM §10: schema_version 2 (event_lines/windows/armed_triggers additive, 条件 inline); v1→v2 migrator (欠落 = 空); v2-in-v1 = 安定 error; `is_save_allowed` を save 経路へ配線 (chunk 非空 = 安定 error, force flag なし); draft save 既定 = rollback to boundary; replay 証明拡張 (条件/line/window を跨ぐ roundtrip → 同一 pop 順 + 同一 trace)。coverage row flip。 |
| EQM-118 | COMPLETE | EQM-117 | `docs/plan/2026-06-09_event_queue_manager/EQM-118_reducibility_reproof/` | Reducibility 再証明 (coverage: reducibility-product-proof)。EQM-053 の縮小 (test 内手書き sim) を解消。 | `tests/policy/`, `tests/golden/` | SEM §16.1: CTB / energy / wait-turn 構成を **product の** conditions + event-line model (EQM-111/112 実装) で組み、dedicated policy の golden trace と比較 (order 配列でなく trace); tie-break/speed/delay matrix + 非約数 speed; 差分は model gap として記録。coverage row flip。 |
| EQM-119 | COMPLETE | EQM-118 | `docs/plan/2026-06-09_event_queue_manager/EQM-119_authoring_surface/` | L2 authoring surface + dogfood/manual 更新 (coverage: authoring-acceptance)。 | `resources/eq_action_definition.gd`, `dogfood/`, `demos/action_resolution/`, `docs/manual/reservations.md`, `docs/manual/action_resolution.md`, `tests/resource/`, `tests/golden/` | SEM §5.6 凍結基準: 「反撃準備 — 3 回 or 5 ターン or どちらか / deadline ∞」を .tres 1 個・GDScript 0 行で宣言し、`closed_by` がどちらで閉じたか golden で可視; dogfood slice を named-effect natural path へ更新; manual 更新 (三面モデル + 条件宣言); Q35 effect grouping follow-up の要否をここで再評価。coverage row 最終 flip。 |

## Phase 12 — v1.2 EBS 拡張ラウンド (Q44–Q54)

Source: `EBS_EXTENSION_REQUEST_2026-07-05.md` (受領原本、EBS 依頼 R01–R12) + `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md` 拡張ラウンド Q44–Q54 (相談ラウンド2・3 で DECIDED、2026-07-05) + roadmap Phase 13。各 task acceptance は凍結契約 ID (SEM v1.2 § / coverage row) を引用し、完了時に coverage row を `implemented` へ flip する (gate: `tools/check_contract_coverage.py`)。拡張は全て L2/L3 opt-in — L0/L1 非漏出は EQM-023 gate で維持。

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-120 | COMPLETE | — | `docs/plan/2026-06-09_event_queue_manager/EQM-120_semantics_round3/` | Semantics round 3: Q44–Q54 確定記述 (SEM v1.2) + registry finalization + synthesis + coverage reserved 行 + queue Phase 12 起票 + EBS 原本同期。 | `docs/design/EVENT_MODEL_SEMANTICS.md`, `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md`, `docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md`, `docs/review/EVENT_MODEL_OPEN_QUESTIONS_SYNTHESIS_2026-07-05.md` | SEM v1.2 が Q44–Q54 を *(v1.2)* 節として additive 記録 (§4.8/§5.7/§6.4–6.5/§7.2/§8.2–8.4/§10.1/§11/§13.1/§16.2)。registry 全 Q DECIDED/SETTLED + 相談ラウンド2・3 表 + pointer 表。coverage reserved 10 行 (owning = EQM-121..128)。`./tools/test.sh` PASS。 |
| EQM-121 | COMPLETE | EQM-120 | `docs/plan/2026-06-09_event_queue_manager/EQM-121_state_algebra/` | 状態代数 backend (coverage: state-algebra, rate-modifier-stack)。 | `runtime/eq_state_algebra.gd`, `runtime/eq_event_lines.gd`, `resources/`, `tests/core/` | SEM §5.7/§4.8: inv ペア宣言 + 共存規則 (相殺 = 符号付き 1 本 / 排他 = 解除→付与 / 共存); wrapper 合成構造 (wrap 順適用・LIFO unwrap・trace); rate modifier-stack (加算 + override、実効再計算、寿命 = 既存 invalidation 語彙); 寿命 3 種 acceptance (スタック系/ターン系/現象 golden)。coverage rows flip。 |
| EQM-122 | COMPLETE | EQM-121 | `docs/plan/2026-06-09_event_queue_manager/EQM-122_relation_graph/` | 関係グラフ backend (coverage: relation-graph)。 | `runtime/eq_relation_graph.gd`, `runtime/eq_runtime.gd`, `tests/core/` | SEM §13.1: 関係 instance table (決定的採番) + 関係型宣言 (分類 / inv 反転形 / TREE 制約 validation / 維持条件 / 宣言 sweep / 解消時規則); 直列縫合; invalidate_actor 連動; relation trace kinds; 月/星 acceptance 例。coverage row flip。 |
| EQM-123 | COMPLETE | EQM-122 | `docs/plan/2026-06-09_event_queue_manager/EQM-123_resolution_rewrites/` | pipeline 拡張: 展開 + 変換 + provenance (coverage: expansion-transform, provenance-chain)。 | `runtime/eq_reservation_runtime.gd`, `runtime/eq_trace.gd`, `tests/core/` | SEM §6.4/§6.5: 2a target 展開 (BFS 関係 id 昇順、メタ/コスト停止規律 — §8 語彙); 2b パターン変換 (パラメータ別型: target 差し替え / 状態代数 inv、メタ降順→priority→sequence、多重適用 + 有界 round 安全弁、適用ごと trace); provenance 連鎖の自動継承・追記 (event 側)。鑑波の損害波及 golden。coverage rows flip。 |
| EQM-124 | COMPLETE | EQM-123 | `docs/plan/2026-06-09_event_queue_manager/EQM-124_atomic_bundle/` | composite atomic bundle (coverage: atomic-bundle)。 | `runtime/eq_reservation_runtime.gd`, `tests/core/`, `tests/golden/` | SEM §7.2: bundle API (member 全 effect 適用 → 単一 sweep、member 順 = §7.1 hook → 発行順、`bundle_resolved` trace); 公平の並列 golden (composite 解決 + 事後の個別反射誘発 — 相談3 意味論)。coverage row flip。 |
| EQM-125 | COMPLETE | EQM-124 | `docs/plan/2026-06-09_event_queue_manager/EQM-125_meta_premature_close/` | メタレベル + window premature close (coverage: meta-level-premature-close)。 | `runtime/eq_window.gd`, `runtime/eq_reservation_runtime.gd`, `resources/eq_action_definition.gd`, `tests/transaction/` | SEM §8.2/§8.3: meta_level 宣言 (default 0) を event/window が運ぶ; 介入 close 判定 (intervener >= window、同値 = 介入成功); 解決済み維持・pending 一掃・`window_closed(cause: intervention)` + 両メタ値 trace; 迎撃 (5 歩移動の 2 歩目) golden。coverage row flip。 |
| EQM-126 | COMPLETE | EQM-125 | `docs/plan/2026-06-09_event_queue_manager/EQM-126_phase_recursion/` | 操作フェーズ再帰 + ループ解消 (coverage: phase-recursion)。 | `runtime/eq_window.gd`, `runtime/eq_transaction.gd`, `tests/transaction/` | SEM §8.4: フェーズ内 sub-checkpoint (順序付き・決定的 id); 遷移履歴によるループ検出 (同一フェーズ再訪 = 最小 cycle); ループ開始点へ巻き戻し + cycle 上の鏡面入力解除 + `phase_rolled_back` trace; 水鏡の再帰入力 golden。coverage row flip。 |
| EQM-127 | COMPLETE | EQM-126 | `docs/plan/2026-06-09_event_queue_manager/EQM-127_snapshot_v3/` | snapshot v3 + replay 証明拡張 (coverage: snapshot-v3)。 | `runtime/eq_snapshot.gd`, `runtime/eq_save_adapter.gd`, `docs/design/SNAPSHOT_COMPAT_V1.md`, `tests/transaction/` | SEM §10.1: schema_version 3 (line_modifiers / relations / phase_checkpoints additive、wrapper・provenance inline); v2→v3 migrator (欠落 = 空); v3-in-v2 = 安定 error; roundtrip 証明 (modifier/relation/provenance/checkpoint を跨ぐ → 同一 pop 順 + 同一 trace)。coverage row flip。 |
| EQM-128 | COMPLETE_WITH_BACKLOG | EQM-127 | `docs/plan/2026-06-09_event_queue_manager/EQM-128_ebs_acceptance_suite/` | Q54 確認系 acceptance 束 + authoring/manual 更新 (coverage: ebs-acceptance-suite)。 | `dogfood/`, `docs/manual/`, `tests/golden/`, `tests/resource/` | SEM §16.2: R04 normalized spatial event tag + `EQCondition` trigger standard form; definition solve/invalidation FIRE gateはEQM-141へre-reserve。R06 相互反撃停止 golden (資源述語閉包); R08 スタック順 comparator 例; R09 公平 golden (EQM-124 依存分の統合); R11 蘇生/追加ターン + invalidate→issue 原子性確認; R12 変更不要記録。inv ペア/関係/メタレベルの .tres 宣言性を manual へ。 |
| EQM-129 | COMPLETE | EQM-128 | `docs/plan/2026-06-09_event_queue_manager/EQM-129_wrapper_semantics/` | [repair, 意図監査 A1] wrapper 意味論の標準 2 種 (inv 反転 / 関係連鎖付与)。 | `runtime/eq_state_algebra.gd`, `runtime/eq_relation_graph.gd`, `runtime/eq_reservation_runtime.gd`, `tests/core/`, `tests/golden/` | SEM §5.7 改訂 (標準 wrapper 2 種): kind=inv_chain は包まれた状態の grant を dual へ反転、kind=relation_chain は grant 時に関係沿いに連鎖付与 (展開機構と同一の cost 停止、連鎖の再帰なし)。未知 kind = 不活性 data (互換)。`state_wrapper_applied` trace (SEM §11 additive)。透徹連鎖・反転連鎖 acceptance golden。既存 golden 不変。 |
| EQM-130 | COMPLETE | EQM-129 | `docs/plan/2026-06-09_event_queue_manager/EQM-130_maintenance_autodrive/` | [repair, 意図監査 A2/C1/C2] 維持条件 sweep の自動駆動 + 公平合成 acceptance + 迎撃標準形。 | `runtime/eq_reservation_runtime.gd`, `runtime/eq_runtime.gd`, `tests/core/`, `tests/golden/` | 相談4「EQM が評価タイミングを固定」の実装: 既定 sweep は step_tick で自動評価、カスタム sweep 名は同名 sweep rule (§4.7) 実行直後に自動評価。predicates は named registry から自動供給。公平: 公平関係 → 展開 → 非対称反射の合成 golden。迎撃: effect handler から intervene_close を呼ぶ標準形の例示。既存 golden 不変。 |
| EQM-131 | COMPLETE | EQM-130 | `docs/plan/2026-06-09_event_queue_manager/EQM-131_acceptance_repair/` | [repair, 意図監査 B1/B2 + EBS A-R08-1] R06 資源述語停止 / retarget 中間段 / R08 消費順整合。 | `runtime/eq_reservation_runtime.gd`, `tests/core/`, `tests/golden/` | R06: 焦点 counter line decrement + `<= 0` invalidation で停止する golden 変種 (「コスト述語の閉包」の証明) + 常真 assert の実質化。retarget: `params.stage` に int (連鎖 index、reach 検査) を additive 追加。R08: 例を EBS A-R08-1 (メタレベル昇順・同率付与順) に揃える。既存 golden 不変 (mutual_counter_stop は変種追加のみ)。 |

## Phase 13 — Consumer runtime performance lane

Source: roadmap Phase 14 + EQM-102 deferred production integration + EQM-134 consumer-informed work-scale evidence。correctness/serialization回帰とruntime performance測定を別suiteとして扱う。

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-136 | COMPLETE | EQM-102, EQM-134 | `docs/plan/2026-06-09_event_queue_manager/EQM-136_trigger_index_runtime/` | Production trigger-index integration + independent performance test lane. | `runtime/eq_trigger_engine.gd`, `runtime/eq_trigger_index.gd`, `resources/eq_condition.gd`, `tools/test.sh`, `test_project/tests/{trigger,performance,support}/`, performance/test docs | Public API/schema/trace unchanged。production matchingはtarget bucket + wildcardだけをfull評価し、arm順・rumination・expiry・disarm・condition mutation・save/load continuationがlinear semanticsと一致。`./tools/test.sh`はperformanceを収集せずPASS、`./tools/test.sh --performance`はperformanceだけを収集してwork-count reductionとelapsedを記録しPASS。 |

## Phase 14 — Evidence-driven runtime hardening

Source: roadmap Phase 15 + EQM-136 follow-up benchmark + EBS integration false-green
audit (2026-07-18)。correctness boundary を先に閉じ、performance hot path は独立した
task として線形に実装・検証する。

| id | status | dependencies | plan_dir | deliverable | target files | acceptance / test path |
|---|---|---|---|---|---|---|
| EQM-137 | COMPLETE_WITH_BACKLOG | EQM-136 | `docs/plan/2026-06-09_event_queue_manager/EQM-137_reaction_condition_contract/` | Reaction-condition type contract hardening + consumer false-green repair proof. | `runtime/{eq_error,eq_reservation_runtime,eq_trigger_engine,eq_trigger_index}.gd`, error/API docs, trigger/runtime tests; EBS integration/tests/docs are consumer-owned proof | `reaction_condition` is `EQCondition|null`; wrong types produce a stable contract fault/rejection trace before any reservation/index/scheduler mutation in dev and shipped modes。direct engine/index calls reject explicitly without ghost state。valid reaction behavior and normal goldens remain unchanged。EBS current-head regression detects the former bad input as rejection, corrects the R04 standard form, and its runner fails on `SCRIPT ERROR`; EQM `./tools/test.sh` and `./tools/test.sh --performance` both PASS。 |
| EQM-138 | COMPLETE | EQM-137 | `docs/plan/2026-06-09_event_queue_manager/EQM-138_trigger_candidate_merge/` | Stable linear merge for target + wildcard trigger candidates. | `runtime/eq_trigger_index.gd`, trigger regression/performance tests, runtime performance profile | Candidate order/fired occurrences remain exactly equivalent to arm order across target-only/wildcard-only/mixed/mutated conditions。candidate assembly performs no full candidate sort; independent lane records sparse and wildcard-heavy work/elapsed, while regression and performance discovery remain exclusive。 |
| EQM-139 | READY | EQM-138 | `docs/plan/2026-06-09_event_queue_manager/EQM-139_relation_adjacency_runtime/` | Production relation queries/expansion/invalidation use the existing actor adjacency. | `runtime/eq_relation_graph.gd`, core/performance tests, runtime performance profile | `relations_of`/`expand`/actor invalidation inspect only incident relation ids while preserving relation-id ordering, TREE/GRAPH semantics, maintenance, trace, snapshot roundtrip。regression + independent performance lane PASS with deterministic workload evidence。 |
| EQM-140 | BACKLOG | EQM-139 | `docs/plan/2026-06-09_event_queue_manager/EQM-140_sparse_event_line_polling/` | Watched-only event-line polling and derived effective-rate cache. | `runtime/eq_event_lines.gd`, core/performance tests, runtime performance profile | polling work is bounded by watched existing lines rather than all lines; modifier add/remove/re-rate and restore rebuild cache deterministically。progression trace/order/snapshot semantics unchanged; regression + independent performance lane PASS。 |

## Dynamic follow-up area

Add `follow-up-ready` tasks here during execution when a current task is complete but reveals nonblocking follow-up work.

| id | status | dependencies | source task | deliverable | acceptance / test path |
|---|---|---|---|---|---|
| EQM-132 | COMPLETE | EQM-131 | Amberground reaction counter runtime profile | FIRE ごとの独立 occurrence + versioned cause transport + schema-v5 checkpoint | armed と pending FIRE の instance 分離、context deep-copy、2回発火、expiry、save/load continuation、stable rejection を `test_eq_reaction_fire_context.gd` と full gate で証明。 |
| EQM-133 | COMPLETE | EQM-132 | Amberground reaction checkpoint audit | schema-v6 reaction-expiry ownership + exact one-event resolution boundary | count終了後のexpiryをsave/loadしFIRE/FIRE/`already_closed` continuation一致、v5 armed migration／orphan rejection、table tamper、後続reservationを消費しない1-event boundaryをfull gateで証明。 |
| EQM-134 | COMPLETE | EQM-133 | Amberground state/passive/perception implementation audit | State/relation engineering work-scale rung + one-shot inversion hot-path repair | 64 tokens×8 actors、1,024 relations、200 actual triggersのround-trip/resolve、work-scale profile、full gate。 |
| EQM-135 | COMPLETE | EQM-134 | Amberground interception tranche | 発行済みPREPARED単独予約へのmeta介入primitive | 発行時metaを予約instanceへ固定し、同値以上の介入でeffect未実行のまま`event_invalidated(closed_by: intervention)`、不足時は`intervention_avoided`、非対応contextはstable rejection。snapshot/pending消失とtrace順を専用test + full gateで証明。 |
| EQM-141 | BACKLOG | EQM-140 | EQM-137 / historical R04 false-green audit | Reaction FIRE condition semantics (preview/commit + condition bind/save contract). | trigger match後・rumination消費前にsolve/invalidationを評価する二相契約、WAIT時のlifetime、trigger/reaction view、COUNTER bind、snapshotをtask packetで決定し、false/true/invalidation-wins/save-loadを厳密test。EQM-137へは混ぜない。 |

## Current pointer

Run-to-end (user-approved 2026-06-18): execute the queue in dependency order to EQM-103; cross milestone checkpoints; delegate clear low-shrink tasks to Codex 5.5; stop only at genuine design forks / env-missing / external-upload (§8.4). Phase 8 (EQM-080/081/082, other-model) reviewed — no shrink.

Run-to-end round 2 (user-approved 2026-07-02): Q27–Q43 決定に基づき Phase 11 (EQM-110→119) を依存順に自律実行する。停止は設計 fork / env 欠如 / 外部 upload のみ (§8.4)。

Current: **EQM-139 READY** — EQM-137はtrace schema、SHIPPED continuation、consumer
R04 false-greenを修理してCOMPLETE_WITH_BACKLOG。addon `754f905`をEBS DEPS/logへ記録し、
同revisionでconsumer 3 gateも再検証済み。user-approved autonomous hardening round
(2026-07-18)として
EQM-138→140を線形実行し、各performance taskは通常回帰と独立performance laneの
両方を完了証拠にする。

Repair round (user-approved 2026-07-05, **完了 2026-07-05**): EQM-129→131 実行済み。wrapper 語彙は標準 2 種で確定 (user)。**B3 (展開のメタ関与) は EBS 側文書 `META_LEVEL_ASSIGNMENT.md` で解消** — メタレベル (比較値) とメタコスト予算 (展開の深さ) は別系・統合しない、hop cost は acceptance 宣言 budget = 現行実装が整合 (修理不要、確定記録)。EBS 宿題「メタレベル値付け」は同文書 (メタクラス二層 + 発行時注入) で起草済み — EQM 契約 (単一 int) と矛盾なし。前 round: **Phase 11 (v1.1 event-model implementation round) COMPLETE** (EQM-110..119, 2026-07-03)。contract coverage 21/21 implemented (`tools/check_contract_coverage.py` gate green)。SEM v1.1 の凍結契約はすべて実装・test 済み。次 round は新たな設計判断 (composite atomic bundle / race 帳簿 serialize / editor dock mounting 等の declared follow-ups) の需要が確定した時点で起票する。

**需要確定 (2026-07-05)**: EBS (godot-editable-battleskill-system) から拡張依頼 R01–R12 を受領 (受領原本 `EBS_EXTENSION_REQUEST_2026-07-05.md`)。registry 拡張ラウンド Q44–Q54 起票、相談ラウンド2 で意味論 fork 8 点 DECIDED(user)、roadmap Phase 13 追加。declared follow-up の composite atomic bundle は Q49 として本 round に取り込み。

**設計ラウンド完了 (2026-07-05, EQM-120)**: 相談ラウンド3 で残 fork 8 点も確定 (計 16 fork、逸脱 5 点は synthesis 記載)。SEM v1.2 確定記述 + registry finalization + coverage reserved 10 行 + Phase 12 (EQM-120..128) 起票済み。EQM-121 READY。

Run-to-end round 3 (user-approved 2026-07-05): Phase 12 (EQM-121→128) を依存順に自律実行する。**作業委任形式** (QUEUE_EXECUTION_PATTERNS P2: codex への external 委譲、billed run はこの承認で当該ラン免除、委任結果の検証は orchestrator gate — §1.1/§8.3)。ユーザーは英語設計文書を確認しない (SEM v1.2 が正; 要点の日本語提示は報告側で行う)。停止は設計 fork / env 欠如 / 外部 upload / repair 上限のみ (§8.4)。

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

### EQM-032 — COMPLETE (2026-06-15)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-032_eq_manager_node/
  review: docs/review/autopilot/EQM-032_SELF_REVIEW_2026-06-15.md
  pattern: P0 (orchestrator-direct); repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=15 checks=217 failures=0; [api-surface] ok
  gate: §4 runtime/integration (signals + suspend + frame-budget determinism + invalid policy) + API surface (EQManager L0)
  surface: api_surface.json re-baselined (+EQManager L0, 6 signals + 12 methods) via explicit --update
  major files:
    - addons/event_queue_manager/runtime/eq_manager.gd (new); addons/event_queue_manager/plugin.gd (custom type)
    - docs/design/EVENT_MODEL_SEMANTICS.md (§14 aligned)
    - tools/check_api_surface.py, docs/design/API_SURFACE.md, tests/golden/api_surface.json
    - test_project/tests/runtime/test_eq_manager.gd (new)
```

Dependency sweep: EQM-032 COMPLETE → EQM-033 READY. Current pointer → EQM-033.

### EQM-033 — COMPLETE (2026-06-15)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-033_prediction_preview/
  review: docs/review/autopilot/EQM-033_SELF_REVIEW_2026-06-15.md
  pattern: P0 (orchestrator-direct); repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=16 checks=230 failures=0; [api-surface] ok
  gate: §4 core (prediction purity snapshot before==after + predict==actual + branch independence + act-now-vs-wait) + API surface (EQPrediction L0)
  surface: api_surface.json re-baselined (+EQPrediction L0, +EQSnapshot.equals) via explicit --update
  major files:
    - addons/event_queue_manager/runtime/eq_prediction.gd (new); eq_snapshot.gd (+equals)
    - tools/check_api_surface.py, docs/design/API_SURFACE.md, tests/golden/api_surface.json
    - test_project/tests/core/test_eq_prediction.gd (new)
```

Dependency sweep: EQM-033 COMPLETE → EQM-034 READY. Current pointer → EQM-034.

### EQM-034 — COMPLETE (2026-06-15)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-034_ctb_sample_battle/
  review: docs/review/autopilot/EQM-034_SELF_REVIEW_2026-06-15.md
  pattern: P0 (orchestrator-direct); repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=17 checks=234 failures=0; [api-surface] ok
    - ./tools/test.sh --update-golden demo_ctb_battle -> demo golden written, PASS
  gate: §4 demo (headless golden trace) — public-API-only sample
  golden: test_project/tests/golden/demo_ctb_battle.trace.jsonl (faster combatant leads; ceil(cost*scale/speed) verified)
  major files:
    - demos/ctb_battle/{ctb_battle.gd,ctb_battle.tscn,README.md} (new); test_project/demos symlink
    - docs/manual/quickstart.md (new)
    - test_project/tests/debug_scene/test_ctb_battle_demo.gd (new)
```

Dependency sweep: EQM-034 COMPLETE → EQM-035 READY. Current pointer → EQM-035.

### EQM-035 — COMPLETE (2026-06-15) — v0.1 MVP milestone

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-035_v0_1_milestone_evaluation/
  review: docs/review/autopilot/EQM-035_SELF_REVIEW_2026-06-15.md
  pattern: P0 (orchestrator-direct, evaluation); repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=17 checks=234 failures=0; [api-surface] ok
  gate: docs-only evaluation (no code change; green build confirms)
  finding: no semantics drift; 0 blocking friction (4 minor → EQM-100 docs / no-change); north-star baselined (simple-path-without-L3 achieved, layer-leak 0); roadmap confirmed unchanged
  deliverable: docs/review/V0_1_MILESTONE_EVALUATION_2026-06-15.md
```

Dependency sweep: EQM-035 COMPLETE → **Phase 3 COMPLETE = v0.1 MVP milestone reached** (EQM-030..035 COMPLETE). EQM-040 READY (dep EQM-034). Current pointer → EQM-040.
CHECKPOINT: v0.1 MVP milestone boundary (§8.3). Autonomous run paused for user direction before Phase 4 (EQM-040 energy / EQM-041 wait-turn).
User direction 2026-06-15: proceed autonomously through Phase 4 (EQM-040→041) to the Phase 4 milestone; consult on design forks.

### EQM-040 — COMPLETE (2026-06-15)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-040_energy_policy/
  review: docs/review/autopilot/EQM-040_SELF_REVIEW_2026-06-15.md
  pattern: P0 (orchestrator-direct); repair 1/3 (test-only type; no product change)
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=18 checks=241 failures=0; [api-surface] ok
  gate: §4 policy (readiness/cost/speed/wait/carry-over) + API surface (EQEnergyPolicy L1)
  surface: api_surface.json re-baselined (+EQEnergyPolicy L1) via explicit --update
  major files:
    - addons/event_queue_manager/resources/policies/eq_energy_policy.gd (new)
    - tools/check_api_surface.py, docs/design/API_SURFACE.md, tests/golden/api_surface.json
    - test_project/tests/policy/test_eq_energy_policy.gd (new)
```

Dependency sweep: EQM-040 COMPLETE → EQM-041 READY. Current pointer → EQM-041.

### EQM-041 — COMPLETE (2026-06-15) — Phase 4 milestone

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-041_wait_turn_policy/
  review: docs/review/autopilot/EQM-041_SELF_REVIEW_2026-06-15.md
  pattern: P0 (orchestrator-direct); repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=20 checks=256 failures=0; [api-surface] ok
    - ./tools/test.sh --update-golden demo_wait_turn -> demo golden written, PASS
  gate: §4 policy (instant resolve / action cost / equal-wait tie-break) + §4 demo (golden) + API surface (EQWaitTurnPolicy L1)
  golden: test_project/tests/golden/demo_wait_turn.trace.jsonl (smallest-wait leads; clock jumps)
  major files:
    - addons/event_queue_manager/resources/policies/eq_wait_turn_policy.gd (new)
    - demos/wait_turn_tactics/{wait_turn.gd,wait_turn.tscn,README.md} (new)
    - tools/check_api_surface.py, docs/design/API_SURFACE.md, tests/golden/api_surface.json
    - test_project/tests/policy/test_eq_wait_turn_policy.gd, test_project/tests/debug_scene/test_wait_turn_demo.gd (new)
```

Dependency sweep: EQM-041 COMPLETE → **Phase 4 (energy + wait-turn) milestone reached** (EQM-040, EQM-041 COMPLETE). EQM-050 READY. Current pointer → EQM-050.
CHECKPOINT: Phase 4/5 milestone boundary (§8.3). Autonomous run paused for user direction before Phase 5 (EQM-050 reservation schema — first L2 surface).
User direction 2026-06-15: proceed autonomously through Phase 5; may delegate clear low-design-shrink-risk tasks to the conservative Codex 5.5 executor (billed checkpoint waived for those per §1.1). Conductor decision: EQM-050/051/052 orchestrator-direct (design core); EQM-053 (reducibility = reproduce existing goldens) candidate for Codex.

### EQM-050 — COMPLETE (2026-06-15) — first L2 surface

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-050_reservation_schema/
  review: docs/review/autopilot/EQM-050_SELF_REVIEW_2026-06-15.md
  pattern: P0 (orchestrator-direct); repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=22 checks=291 failures=0; [api-surface] ok
  gate: §4 resource/API (per-kind validation + .tres roundtrip) + API surface (L2 populated, no L3 leak)
  surface: api_surface.json re-baselined (L2: EQActionDefinition, EQReservation) via explicit --update
  major files:
    - addons/event_queue_manager/resources/eq_action_definition.gd, runtime/eq_reservation.gd (new); eq_error.gd (+8 codes)
    - docs/design/ERROR_CONTRACT.md, API_SURFACE.md; tools/check_api_surface.py; tests/golden/api_surface.json
    - test_project/tests/resource/{test_eq_action_definition.gd,test_eq_reservation.gd} (new)
```

Dependency sweep: EQM-050 COMPLETE → EQM-051 READY. Current pointer → EQM-051.

### EQM-051 — COMPLETE (2026-06-15)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-051_reservation_resolution/
  review: docs/review/autopilot/EQM-051_SELF_REVIEW_2026-06-15.md
  pattern: P0 (orchestrator-direct); repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=23 checks=308 failures=0; [api-surface] ok
  gate: §4 core (immediate=delay0 / prepared=delay / wait->ready / operation->target reservation / reaction arm) + API surface (EQReservationRuntime L2)
  surface: api_surface.json re-baselined (L2 +EQReservationRuntime; EQReservation +target_id) via explicit --update
  major files:
    - addons/event_queue_manager/runtime/eq_reservation_runtime.gd (new); eq_reservation.gd (+target_id)
    - tools/check_api_surface.py, docs/design/API_SURFACE.md, tests/golden/api_surface.json
    - test_project/tests/core/test_eq_reservation_runtime.gd (new)
```

Dependency sweep: EQM-051 COMPLETE → EQM-052 READY. Current pointer → EQM-052.

### EQM-052 — COMPLETE (2026-06-15)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-052_ap_ready_model/
  review: docs/review/autopilot/EQM-052_SELF_REVIEW_2026-06-15.md
  pattern: P0 (orchestrator-direct, design core); repair 1/3 (test-only type; no product change)
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=24 checks=319 failures=0; [api-surface] ok
  gate: §4 policy (ready after AP recovery delay / AP spend+recovery deterministic / turn closes through wait / ready reservation object) + API surface (EQActionResolutionPolicy L2)
  surface: api_surface.json re-baselined (L2 +EQActionResolutionPolicy) via explicit --update
  major files:
    - addons/event_queue_manager/resources/policies/eq_action_resolution_policy.gd (new)
    - tools/check_api_surface.py, docs/design/API_SURFACE.md, tests/golden/api_surface.json
    - test_project/tests/policy/test_eq_action_resolution_policy.gd (new)
```

Dependency sweep: EQM-052 COMPLETE → EQM-053 READY. Current pointer → EQM-053.

### EQM-053 — COMPLETE (2026-06-15) — Phase 5 milestone — P2 delegation (Codex 5.5)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-053_policy_reducibility_proofs/
  review: docs/review/autopilot/EQM-053_SELF_REVIEW_2026-06-15.md
  pattern: P2 delegation — Codex 5.5 (gpt-5.5 xhigh) authored under contract; orchestrator owned gate; 1 orchestrator gate-repair (CTB carry semantics)
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=25 checks=326 failures=0; [api-surface] ok
  gate: §4 policy (metamorphic: per-tick event-line sim order == dedicated policy order for CTB/energy/wait across speed/cost/tie matrices, incl. non-divisor speeds)
  finding: gate caught CTB carry divergence (sim carried; policy is no-carry; only coincided for divisor speeds) -> repaired to no-carry + non-divisor case; energy carries (matches), wait countdown
  scope: tests-only; api-surface golden unchanged
  major files:
    - test_project/tests/policy/test_eq_reducibility.gd (new; Codex-authored + orchestrator CTB repair)
```

Dependency sweep: EQM-053 COMPLETE → **Phase 5 (Action Reservation model) milestone reached** (EQM-050..053 COMPLETE). EQM-060 READY. Current pointer → EQM-060.
CHECKPOINT: Phase 5/6 milestone boundary (§8.3). Autonomous run paused for user direction before Phase 6 (EQM-060 condition/tag matching — trigger/reaction engine).
User direction 2026-06-15: proceed autonomously through Phase 6; delegate clear low-shrink tasks to Codex. Conductor: EQM-060 delegated (contract pinned); EQM-061/062 orchestrator-direct (design core).

### EQM-060 — COMPLETE (2026-06-15) — P2 delegation (Codex 5.5)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-060_condition_contract/
  review: docs/review/autopilot/EQM-060_SELF_REVIEW_2026-06-15.md
  pattern: P2 delegation — Codex 5.5 (gpt-5.5 xhigh) implemented orchestrator-pinned contract; orchestrator owned surface wiring + gate; repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=27 checks=344 failures=0; [api-surface] ok
  gate: §4 resource/API (condition matches kind/source/target/tags/predicate; sensing placeholder) + API surface (EQCondition/EQTagMatcher L2, no L3 leak)
  surface: api_surface.json re-baselined (L2 +EQCondition +EQTagMatcher) via explicit --update (orchestrator)
  major files:
    - addons/event_queue_manager/resources/eq_condition.gd, runtime/eq_tag_matcher.gd (new; Codex + orchestrator docs)
    - tools/check_api_surface.py, docs/design/API_SURFACE.md, tests/golden/api_surface.json (orchestrator)
    - test_project/tests/trigger/{test_eq_condition.gd,test_eq_tag_matcher.gd} (new; Codex)
```

Dependency sweep: EQM-060 COMPLETE → EQM-061 READY. Current pointer → EQM-061.

### EQM-061 — COMPLETE (2026-06-15)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-061_reaction_preparation/
  review: docs/review/autopilot/EQM-061_SELF_REVIEW_2026-06-15.md
  pattern: P0 (orchestrator-direct, trigger firing semantics); repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=28 checks=358 failures=0; [api-surface] ok
  gate: §4 trigger (counterattack on incoming damage / duration expiry prevents trigger / owner-source matching / one-shot / sweep-point) + API surface (EQTriggerEngine L2)
  surface: api_surface.json re-baselined (L2 +EQTriggerEngine) via explicit --update
  major files:
    - addons/event_queue_manager/runtime/eq_trigger_engine.gd (new)
    - tools/check_api_surface.py, docs/design/API_SURFACE.md, tests/golden/api_surface.json
    - test_project/tests/trigger/test_eq_trigger_engine.gd (new)
```

Dependency sweep: EQM-061 COMPLETE → EQM-062 READY. Current pointer → EQM-062.

### EQM-062 — COMPLETE (2026-06-15) — Phase 6 milestone

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-062_rumination_cycle_guard/
  review: docs/review/autopilot/EQM-062_SELF_REVIEW_2026-06-15.md
  pattern: P0 (orchestrator-direct, cycle-guard safety); repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=29 checks=370 failures=0; [api-surface] ok
  gate: §4 trigger (rumination decrements+reschedules for reservation & reaction; cycle guard bounds a runaway cascade with TRIGGER_CHAIN_LIMIT fault, no crash; rumination 0 = one-shot compat)
  surface: api_surface.json re-baselined (EQTriggerEngine +fire_cascade/max_chain/faults) via explicit --update; +1 error code (eqm.trigger.chain_limit, BUDGET_EXCEEDED)
  major files:
    - addons/event_queue_manager/runtime/{eq_trigger_engine.gd(+rumination/cascade),eq_reservation_runtime.gd(+rumination),eq_error.gd(+code)}
    - docs/design/ERROR_CONTRACT.md, API_SURFACE.md; tools/check_api_surface.py; tests/golden/api_surface.json
    - test_project/tests/trigger/test_eq_rumination_cycle_guard.gd (new)
```

Dependency sweep: EQM-062 COMPLETE → **Phase 6 (Trigger/reaction engine) milestone reached** (EQM-060..062 COMPLETE). EQM-070 READY. Current pointer → EQM-070.
CHECKPOINT: Phase 6/7 milestone boundary (§8.3). Autonomous run paused for user direction before Phase 7 (EQM-070 transaction snapshot — player-turn draft / rollback / commit).
User direction 2026-06-15: proceed autonomously through Phase 7; delegate clear low-shrink tasks to Codex. Conductor: EQM-070/071 orchestrator-direct (transaction model + wait-commit policy coupling); EQM-072 (deterministic RNG + replay proof) = Codex-delegation candidate.

### EQM-070 — COMPLETE (2026-06-15)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-070_transaction_snapshot/
  review: docs/review/autopilot/EQM-070_SELF_REVIEW_2026-06-15.md
  pattern: P0 (orchestrator-direct, transaction model); repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=30 checks=388 failures=0; [api-surface] ok
  gate: §4 transaction (draft/inspect/rollback/commit; live unchanged before commit) + API surface (EQTransaction L2)
  surface: api_surface.json re-baselined (L2 +EQTransaction) via explicit --update
  major files:
    - addons/event_queue_manager/runtime/eq_transaction.gd (new)
    - tools/check_api_surface.py, docs/design/API_SURFACE.md, tests/golden/api_surface.json
    - test_project/tests/transaction/test_eq_transaction.gd (new)
```

Dependency sweep: EQM-070 COMPLETE → EQM-071 READY. Current pointer → EQM-071.

### EQM-071 — COMPLETE (2026-06-15)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-071_wait_commit_boundary/
  review: docs/review/autopilot/EQM-071_SELF_REVIEW_2026-06-15.md
  pattern: P0 (orchestrator-direct, wait semantics); repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=31 checks=402 failures=0; [api-surface] ok
  gate: §4 transaction (immediate rollbackable before wait; wait commits draft + schedules ready; commit guard) + API surface (EQActionResolutionPolicy +wait_close)
  surface: api_surface.json re-baselined (EQActionResolutionPolicy +wait_close) via explicit --update
  major files:
    - addons/event_queue_manager/runtime/eq_transaction.gd (commit guard); resources/policies/eq_action_resolution_policy.gd (+wait_close)
    - tools/check_api_surface.py, docs/design/API_SURFACE.md, tests/golden/api_surface.json
    - test_project/tests/transaction/test_eq_wait_commit_boundary.gd (new)
```

Dependency sweep: EQM-071 COMPLETE → EQM-072 READY. Current pointer → EQM-072.

### EQM-072 — COMPLETE (2026-06-15) — Phase 7 milestone — P2 delegation (Codex 5.5)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-072_deterministic_replay/
  review: docs/review/autopilot/EQM-072_SELF_REVIEW_2026-06-15.md
  pattern: P2 delegation — Codex 5.5 (gpt-5.5 xhigh) implemented orchestrator-pinned contract; orchestrator owned surface wiring + gate; repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=32 checks=407 failures=0; [api-surface] ok
  gate: §4 transaction/determinism (same-seed determinism; save/restore continues stream; snapshot+rng-state restore reproduces random-dependent scheduler order) + API surface (EQRng core)
  surface: api_surface.json re-baselined (core +EQRng) via explicit --update (orchestrator)
  major files:
    - addons/event_queue_manager/runtime/eq_rng.gd (new; Codex + orchestrator doc)
    - tools/check_api_surface.py, docs/design/API_SURFACE.md, tests/golden/api_surface.json (orchestrator)
    - test_project/tests/transaction/test_eq_rng_replay.gd (new; Codex)
```

Dependency sweep: EQM-072 COMPLETE → **Phase 7 (Transaction and rollback) milestone reached** (EQM-070..072 COMPLETE). EQM-080 READY. Current pointer → EQM-080.
CHECKPOINT: Phase 7/8 milestone boundary (§8.3). Autonomous run paused for user direction before Phase 8 (EQM-080 effect/presentation records — simulation/presentation split).

### EQM-080 — COMPLETE (2026-06-18)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-080_effect_records/
  review: docs/review/autopilot/EQM-080_SELF_REVIEW_2026-06-15.md
  pattern: P0 (orchestrator-direct — simulation/presentation split foundation; design forks pre-agreed in approved Phase 8 plan). Repair: 0.
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=34 checks=438 failures=0; [api-surface] ok
  gate: simulation/presentation split (EQEffectRecord immediate + deterministic; EQEffectChunk is_save_allowed=is_empty, §10/§22; EQPresentationEvent value-snapshot/no-live-node) + API surface (presentation layer added)
  surface: api_surface.json re-baselined (core +EQEffectRecord/EQEffectChunk; +presentation layer with EQPresentationEvent) via explicit --update (orchestrator)
  major files:
    - addons/event_queue_manager/runtime/eq_effect_record.gd (new; core)
    - addons/event_queue_manager/runtime/eq_effect_chunk.gd (new; core)
    - addons/event_queue_manager/runtime/eq_presentation_event.gd (new; presentation)
    - test_project/tests/presentation/test_eq_effect_record.gd (new)
    - test_project/tests/presentation/test_eq_presentation_event.gd (new)
    - tools/check_api_surface.py, docs/design/API_SURFACE.md, tests/golden/api_surface.json (orchestrator)
```

Dependency sweep: EQM-080 COMPLETE → EQM-081 READY. Current pointer → EQM-081.

### EQM-081 — COMPLETE (2026-06-18)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-081_visibility_flush_policy/
  review: docs/review/autopilot/EQM-081_SELF_REVIEW_2026-06-18.md
  pattern: P0 (orchestrator-direct). Repair: 0.
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=35 checks=469 failures=0; [api-surface] ok
  gate: flush-policy rules (immediate/skip/defer-coalesce); presentation-neutrality property test (chunk contents identical under two policies; flushed output differs)
  surface: api_surface.json re-baselined (presentation +EQPresentationPolicy, +EQPresentationBuffer) via explicit --update (orchestrator)
  major files:
    - addons/event_queue_manager/resources/eq_presentation_policy.gd (new; presentation)
    - addons/event_queue_manager/runtime/eq_presentation_buffer.gd (new; presentation)
    - addons/event_queue_manager/runtime/eq_error.gd (+PRESENTATION_POLICY_CLASS_CONFLICT)
    - test_project/tests/presentation/test_eq_presentation_buffer.gd (new)
    - tools/check_api_surface.py, docs/design/API_SURFACE.md, tests/golden/api_surface.json (orchestrator)
```

Dependency sweep: EQM-081 COMPLETE → EQM-082 READY. Current pointer → EQM-082.

### EQM-082 — COMPLETE (2026-06-18)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-082_moving_target_barrier/
  review: docs/review/autopilot/EQM-082_SELF_REVIEW_2026-06-18.md
  pattern: P0 (orchestrator-direct). Repair: 0.
  tests:
    - ./tools/test.sh -> RESULT: PASS (exit 0); files=36 checks=489 failures=0; [api-surface] ok
  gate: barrier selective flush (depends_on ∩ changes_position_of); insertion-order preserved; neutrality holds
  surface: no change (no new class_name; _barrier_flush is internal)
  major files:
    - addons/event_queue_manager/runtime/eq_presentation_buffer.gd (extended: _barrier_flush)
    - test_project/tests/presentation/test_eq_moving_target_barrier.gd (new)
```

Dependency sweep: EQM-082 COMPLETE → **Phase 8 (Effect and Presentation Pipeline) milestone reached** (EQM-080..082 COMPLETE).
CHECKPOINT: Phase 8/9 milestone boundary. Autonomous run paused for user direction before Phase 8b (EQM-085 Godot node bridge).

### EQM-083 — COMPLETE (2026-06-18)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-083_runtime_timeline_hud/
  review: docs/review/autopilot/EQM-083_SELF_REVIEW_2026-06-18.md
  pattern: P0 (orchestrator-direct, first UI surface); repair 0
  tests: ./tools/test.sh -> PASS (exit 0); files=37 checks=504 failures=0; [api-surface] ok
  gate: §4 UI (L4 projection integrity + L2 state matrix + ui_metric_id metadata); new `ui` API-surface layer
  major files: addons/event_queue_manager/runtime/ui/{eq_timeline_hud.gd,eq_timeline_hud.tscn,eq_debug_overlay.gd} (new); test_project/tests/ui_headless/test_eq_timeline_hud.gd (new)
```

Dependency sweep: EQM-083 COMPLETE → EQM-084 READY. Current pointer → EQM-084.

### EQM-084 — COMPLETE (2026-06-18)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-084_dogfood_vertical_slice/
  review: docs/review/autopilot/EQM-084_SELF_REVIEW_2026-06-18.md
  friction: docs/review/DOGFOOD_FRICTION_2026-06-18.md (4 findings; 0 blocking; F1 turn-close-paths -> EQM-100; F2 effect/presentation signals -> EQM-085/EQM-100)
  pattern: P0 (orchestrator-direct, full-API dogfood); repair 1 (in-slice wait_close->finish_action; no addon change)
  tests: ./tools/test.sh -> PASS (exit 0); files=38 checks=510 failures=0; [api-surface] ok
  golden: tests/golden/dogfood_action_resolution.trace.jsonl (turn x8, effect x8, reaction_fired x2; seeded RNG)
  major files: dogfood/action_resolution/{battle.gd,README.md} (new); test_project/dogfood symlink; test_project/tests/debug_scene/test_dogfood_action_resolution.gd (new)
```

Dependency sweep: EQM-084 COMPLETE → (EQM-085 already READY via 032/072/082). Current pointer → EQM-085.

### EQM-085 — COMPLETE (2026-06-18) — Phase 8b complete

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-085_godot_node_bridge/
  review: docs/review/autopilot/EQM-085_SELF_REVIEW_2026-06-18.md
  pattern: P0 (orchestrator-direct, runtime/Godot integration); repair 0
  tests: ./tools/test.sh -> PASS (exit 0); files=40 checks=530 failures=0; [api-surface] ok
  gate: §4 runtime/integration (node-free save/load + rebind reproduces order; actor-deletion invalidation; 6-domain signal bridge; scene-local)
  major files: addons/event_queue_manager/runtime/{eq_save_adapter.gd,eq_node_bridge.gd} (new); test_project/tests/runtime/{test_eq_save_adapter,test_eq_node_bridge}.gd (new)
```

Dependency sweep: EQM-085 COMPLETE → Phase 8b done (083/084/085). EQM-086 READY. Current pointer → EQM-086.

Dependency sweep: EQM-086 COMPLETE → Phase 9 UI contract (M0) authored (`docs/ui/EDITOR_UI_CONTRACT.md`, `EDITOR_STATE_MATRIX.md`). EQM-087 READY (UI metric harness, M1-M3 — Codex 5.5 candidate: contract-pinned, mechanical). Current pointer → EQM-087.

Dependency sweep: EQM-087 COMPLETE → UI metric harness live (M1-M3, WARN-only): Pass A frame-stepping collector/evaluator + Pass B static audit, report under `.godot_user/test-runs/<id>/ui_metrics.{json,md}`. 10 scenarios (good+broken) prove non-tautology (13 P0 broken-only, 0 good). EQM-090 READY (Timeline Preview Dock MVP — first real surface). Current pointer → EQM-090.

Dependency sweep: EQM-090 COMPLETE → Timeline Preview Dock (EQTimelineDock, ui) is a projection-first surface (empty/validation/order states, no silent sample default); projection integrity proven on the real dock via the EQM-087 harness vs an independent prediction. Added EQPrediction.predict_entries (golden re-baselined, additive). EQM-091 READY (debug order explanation, explanation-as-data). Current pointer → EQM-091.

Dependency sweep: EQM-091 COMPLETE → explanation-as-data: EQOrderExplanation (core) over the authoritative EQOrdering.decided_by; EQDebugInspector (ui, order_inspector) renders structured factor rows, deciding factor marked non-textually. Overlay (EQM-083) now has a producer. Golden re-baselined (additive). EQM-092 READY (Action Resolution demo template — deps 091+082 both done). Current pointer → EQM-092.

Dependency sweep: EQM-092 COMPLETE → Action Resolution demo (demos/action_resolution/demo_battle.gd, public-API, reservation+trigger+presentation, deterministic) + EQTemplateGenerator (ui) with two-step sample separation (generate=badged sample, duplicate_to_project=writes project assets). §5.10 sample_separation metric added + enforced on the real surface. Golden re-baselined (additive). EQM-093 READY (UI metric P0 gate, adoption M4). Current pointer → EQM-093.

Dependency sweep: EQM-093 COMPLETE → UI metric adoption M4: P0 enforced as build FAIL on real/good surfaces (broken_* excluded as self-test); added §5.3 scroll_reachability + §5.8 state_contradiction; ui_static_audit runs --enforce. EQM-094 READY (Layout Calibration Loop — debug tab + ledger). Current pointer → EQM-094.

Dependency sweep: EQM-094 COMPLETE → Layout Calibration tab (debug-only, EQ_EDITOR_CALIBRATION flag; hidden in normal mode = structural P0) edits layout params per ui_metric_id live + emits schema-valid eq_layout_feedback JSON (layout params only); LAYOUT_CALIBRATION_LEDGER.md (bake procedure + cold-control rule). EQM-095 READY (UI metric P1 gate, adoption M5). Current pointer → EQM-095.

Dependency sweep: EQM-095 COMPLETE → UI metric adoption M5: P1 gate active (row geometry/truncation/picker width enforced as FAIL on real+good surfaces; exceptions declared §8). Thresholds ratified at initial values — no calibration ledger evidence baked yet (manual-optional loop), documented honestly (no fabrication). **Phase 9 (editor UI) complete** (086/087/090/091/092/093/094/095). EQM-100 READY (reservation/action-resolution manual + concepts). Current pointer → EQM-100.

Dependency sweep: EQM-100 COMPLETE → consumer manual (docs/manual/concepts.md three-plane + L0→L3 layering; reservations.md; action_resolution.md with the finish_action-vs-wait_close F1 warning). All signatures verified against source. EQM-101 READY (multi-genre demo suite). Current pointer → EQM-101.

Dependency sweep: EQM-101 COMPLETE → multi-genre demo suite (6 genres: CTB, energy[new], wait-turn, action-resolution[+golden], phase[new], stack[new]); phase=initiative bands on FixedRound, stack=priority-as-depth LIFO on L0 EQRuntime (compositions, no new policy). Each emits a golden trace (--update-golden flow). docs/manual/policy_selection.md genre map. EQM-102 READY (binary heap backend + trigger indexing — Codex 5.5 candidate). Current pointer → EQM-102.

Dependency sweep: EQM-102 COMPLETE → EQBinaryHeapBackend (core, order-identical to sorted-array, opt-in via EQScheduler.new(backend), no API break) + EQTriggerIndex (L2, bucket-by-target, parity-tested vs real engine). Budgets declared; 5000-entry order-identity + 10k throughput + index parity green. Golden re-baselined (additive). EQM-103 READY (release candidate). Current pointer → EQM-103 (FINAL — STOP before external AssetLib upload, §8.4). 658 checks.

Dependency sweep: EQM-103 COMPLETE → v1.0 release candidate ready (MIT LICENSE, plugin.cfg 1.0.0, README install/manual links, SNAPSHOT_COMPAT_V1.md schema stance [preserve/migrate/replace/defer], AssetLib checklist prepared-not-submitted, clean-room genericization). Clean load: 658 checks, 0 import errors. **IMPLEMENTATION QUEUE COMPLETE through EQM-103.** Current pointer → (none — queue complete). STOP per §8.4: external AssetLib upload (tag v1.0.0 + submit form) is the user's action; not performed. Declared v1.x follow-ups: icon.png, editor-dock mounting, snapshot v2 migrator.

### EQM-110 — COMPLETE (2026-07-02) — opens Phase 11 (v1.1 event-model implementation round)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-110_semantics_round2/
  review: docs/review/autopilot/EQM-110_SELF_REVIEW_2026-07-02.md
  pattern: P0 (orchestrator-direct, decision-depth docs + process gate); repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS; files=48 checks=658 failures=0; [api-surface] ok;
      [contract-coverage] self-test ok; rows=21 implemented=6 reserved=15 violations=0
  gate: docs 契約整合 (Q27–Q43 全 DECIDED / SEM v1.1 additive / Q01–Q26 不変) + coverage gate 導入 green
  inputs: user 注釈 2026-07-02 (16 承認 + Q31 条件承認 → 宣言 linkage reconciliation で任意項目確定)
  major files:
    - docs/design/EVENT_MODEL_SEMANTICS.md (v1.1: §4.6/§4.7/§5.4–§5.6/§6.1–§6.3/§7.1/§8.1/§9/§10/§11/§12.1/§13/§16.1)
    - docs/design/EVENT_MODEL_OPEN_QUESTIONS.md (Q27–Q43 finalization + Q31 reconciliation + Q12 pointer 補正)
    - docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md (new), tools/check_contract_coverage.py (new), tools/test.sh (gate 配線)
    - docs/review/EVENT_MODEL_OPEN_QUESTIONS_SYNTHESIS_2026-07-02.md (new)
    - docs/review/EVENT_MODEL_DESIGN_GAP_AUDIT_2026-07-02.md (監査記録, 本 round の起点)
```

Dependency sweep: EQM-110 COMPLETE → EQM-111 READY (conditions 契約実装)。EQM-112..119 BACKLOG (線形鎖)。Current pointer → EQM-111。

### EQM-111 — COMPLETE (2026-07-02)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-111_conditions_contract/
  review: docs/review/autopilot/EQM-111_SELF_REVIEW_2026-07-02.md
  pattern: P0 (orchestrator-direct); repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS; files=50 checks=726 failures=0; [api-surface] ok; [contract-coverage] violations=0
  gate: §4 resource/API (spec validate + .tres/dict roundtrip + 糖衣正規化) + trigger (level AND / OR / invalidation-wins / closed_by / fault-as-value / registry)
  surface: api_surface.json re-baselined (+EQConditionSpec L2, +EQConditionEval L2, EQActionDefinition +solve/invalidation_conditions +normalized_conditions +PRIMARY_LINE_ID, EQRuntime +register_predicate/has_predicate/predicates) via explicit --update
  coverage: conditions-contract / named-predicate-registry -> implemented
  major files:
    - addons/event_queue_manager/resources/eq_condition_spec.gd (new), runtime/eq_condition_eval.gd (new)
    - addons/event_queue_manager/resources/eq_action_definition.gd (+conditions/+normalized_conditions), runtime/eq_runtime.gd (+predicate registry), runtime/eq_error.gd (+5 codes)
    - docs/design/ERROR_CONTRACT.md (+5 codes, presentation row backfill), docs/design/API_SURFACE.md, tests/golden/api_surface.json
    - test_project/tests/resource/test_eq_condition_spec.gd (new), test_project/tests/trigger/test_eq_condition_eval.gd (new)
```

Dependency sweep: EQM-111 COMPLETE → EQM-112 READY (event-line backend)。Current pointer → EQM-112。

### EQM-112 — COMPLETE (2026-07-02)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-112_event_line_backend/
  review: docs/review/autopilot/EQM-112_SELF_REVIEW_2026-07-02.md
  pattern: P0 (orchestrator-direct); repair 0
  tests:
    - ./tools/test.sh -> RESULT: PASS; files=52 checks=780 failures=0; [api-surface] ok (no L3 leak); [contract-coverage] violations=0
  gate: §4 core (data-only lines / sparse poll / 走査順決定性 / counter 採番 / dict roundtrip / trace 実 emit) + performance (Q43 予算 guard)
  surface: api_surface.json re-baselined (+EQEventLines L3 — 初の L3 tag; standalone class で L0/L1 署名に不露出) via explicit --update
  coverage: event-line-backend / sweep-rule-registry / progression-budgets -> implemented
  major files:
    - addons/event_queue_manager/runtime/eq_event_lines.gd (new, L3)
    - test_project/tests/core/test_eq_event_lines.gd (new), test_project/tests/performance/test_eq_event_line_budget.gd (new)
    - tools/check_api_surface.py (+L3), docs/design/API_SURFACE.md, tests/golden/api_surface.json
```

Dependency sweep: EQM-112 COMPLETE → EQM-113 READY (解決 pipeline 統合)。Current pointer → EQM-113。

### EQM-113 — COMPLETE (2026-07-02)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-113_resolution_pipeline/
  review: docs/review/autopilot/EQM-113_SELF_REVIEW_2026-07-02.md
  pattern: P0 (orchestrator-direct); repair 1/3 (新規 file の EOF 改行欠落 → parse error 修正のみ; 挙動変更なし)
  tests:
    - ./tools/test.sh -> RESULT: PASS; files=54 checks=839 failures=0; [api-surface] ok (no L3 leak); [contract-coverage] violations=0
  gate: §4 core (5-step pipeline / 宣言 linkage / chunk=save 境界 / Q27 検出 tick push / lazy+sweep invalidation / invalidation-wins / invalidate_actor mode 中立)
      + trigger (reaction schedule 化 / round trace / 有界 cascade / expiry event closed_by 三種)
  surface: api_surface.json re-baselined via explicit --update
    (+EQActionDefinition.priority/effect_name/expiry_effect_name; +EQRuntime.register_effect/has_effect/effects/invalidate_actor;
     EQReservationRuntime pipeline 面 (+lines/chunk/engine/last_drained/max_cascade_rounds/step_tick/invalidate_actor/pending_conditional, submit +reaction_condition);
     EQTriggerEngine: -fire_cascade/-max_chain/-faults, +disarm/+disarm_for/+expired — in-place cascade の廃止, replace stance)
  goldens: demo/dogfood trace golden は不変 (fire_cascade/EQReservationRuntime 非使用を確認; sync_primary は無記録の鏡に変更)
  coverage: resolution-pipeline / reaction-schedule / expiry-event / invalidate-actor -> implemented
  major files:
    - addons/event_queue_manager/runtime/eq_reservation_runtime.gd (pipeline 再構成), eq_runtime.gd (+effect registry/+invalidate_actor), eq_trigger_engine.gd (契約変更), eq_node_bridge.gd (正規経路配線), eq_event_lines.gd (sync_primary 無記録化)
    - addons/event_queue_manager/resources/eq_action_definition.gd (+3 fields), runtime/eq_error.gd (+1 code), docs/design/ERROR_CONTRACT.md, docs/design/EVENT_MODEL_SEMANTICS.md (§11 kinds 追記)
    - test_project/tests/core/test_eq_resolution_pipeline.gd (new), tests/trigger/test_eq_reaction_pipeline.gd (new), tests/trigger/test_eq_rumination_cycle_guard.gd (新契約へ更新)
```

Dependency sweep: EQM-113 COMPLETE → EQM-114 READY (window object model)。Current pointer → EQM-114。

### EQM-114 — COMPLETE (2026-07-02)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-114_window_model/
  review: docs/review/autopilot/EQM-114_SELF_REVIEW_2026-07-02.md
  pattern: P0 (orchestrator-direct); repair 2/3 (test の型推論 1 件; deadline window の clock 込み snapshot 比較が commit を誤 conflict → is_live_unchanged_ignoring_clock + clock 保存 commit で修正)
  tests:
    - ./tools/test.sh -> RESULT: PASS; files=55 checks=876 failures=0; [api-surface] ok; [contract-coverage] violations=0
  gate: §4 transaction (stack/trace/budget 非回復/深度 backstop/deadline 既定 rollback/pre-close 明示 commit/commit 競合 guard/save boundary helper) — demo golden 不変 (暗黙 root は trace しない)
  surface: api_surface.json re-baselined (+EQWindow L2; EQReservationRuntime +open_window/close_window/window_depth/current_window/is_save_boundary/max_window_depth; EQTransaction +is_live_unchanged_ignoring_clock) via explicit --update
  coverage: window-object-model -> implemented
  design note: deadline は scheduler event 化せず定義点検査 (pop 後 / tick 境界) — event 化は pop 自体が live を変え snapshot-commit と衝突するため (SUB_TASKS E)。Q37 は event 化を要求しない。
  major files:
    - addons/event_queue_manager/runtime/eq_window.gd (new), eq_reservation_runtime.gd (+window stack), eq_transaction.gd (+clock 無視比較), eq_error.gd (+4 codes)
    - docs/design/ERROR_CONTRACT.md (+4), test_project/tests/transaction/test_eq_window.gd (new)
```

Dependency sweep: EQM-114 COMPLETE → EQM-115 READY (ordering hook)。Current pointer → EQM-115。

### EQM-115 — COMPLETE (2026-07-02)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-115_ordering_hook/
  review: docs/review/autopilot/EQM-115_SELF_REVIEW_2026-07-02.md
  pattern: P0 (orchestrator-direct); repair 1/3 (test: dev halt する fault を SHIPPED で観測するよう setup 順序修正)
  tests:
    - ./tools/test.sh -> RESULT: PASS; files=56 checks=894 failures=0; [api-surface] ok; [contract-coverage] violations=0
  gate: §4 core (既定 = 発行順 / TO 型 hook 並べ替え / 不正 permutation fault + fallback / view serializable (contains_live_object false) / fired reactions への適用 / 2-run byte 同一 trace)
  surface: api_surface.json re-baselined (+EQReservationRuntime.set_order_hook; EQTransaction は EQM-114 分に含む) via explicit --update
  coverage: ordering-hook -> implemented
  deviations: EQConfig への hook 保持は不採用 (Callable は Resource serialize 不能; named registry 群と同じ起動時登録で統一, SUB_TASKS E)。composite atomic bundle は SEM §7.1 staging どおり defer。golden 被覆は 2-run byte 同一性で保証し、fixture 化は EQM-118 の product 経路 golden に含める。
  major files:
    - addons/event_queue_manager/runtime/eq_reservation_runtime.gd (+set_order_hook/_order_candidates + 2 適用点), eq_error.gd (+1 code)
    - docs/design/ERROR_CONTRACT.md (+1), test_project/tests/core/test_eq_order_hook.gd (new)
```

Dependency sweep: EQM-115 COMPLETE → EQM-116 READY (race pattern)。Current pointer → EQM-116。

### EQM-116 — COMPLETE (2026-07-02)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-116_race_pattern/
  review: docs/review/autopilot/EQM-116_SELF_REVIEW_2026-07-02.md
  pattern: P0 (orchestrator-direct); repair 0 (Godot 初回 green)
  tests:
    - ./tools/test.sh -> RESULT: PASS; files=57 checks=910 failures=0; [api-surface] ok; [contract-coverage] violations=0
  gate: §4 trigger (先着勝者 / 同時成立 = 発行順・専用規則なし / 効果単一適用 / 敗者 closed_by: race_lost + race_group / gid 決定性 + 2-run byte 同一) + UI (overlay 候補群集約 group_rows)
  surface: api_surface.json re-baselined (+EQReservationRuntime.submit_race; +EQDebugOverlay.group_rows) via explicit --update
  coverage: race-pattern -> implemented
  design note: 3 表示分離の最小実装 = trace 全候補可視 (EQM debug) + overlay 集約 (game-dev debug) + in-game は勝者の効果のみが presentation へ流れる構造で既に充足。
  major files:
    - addons/event_queue_manager/runtime/eq_reservation_runtime.gd (+submit_race/_settle_race), runtime/ui/eq_debug_overlay.gd (+race_group 集約)
    - test_project/tests/trigger/test_eq_race_pattern.gd (new)
```

Dependency sweep: EQM-116 COMPLETE → EQM-117 READY (snapshot v2 + save 境界 enforcement)。Current pointer → EQM-117。

### EQM-117 — COMPLETE (2026-07-02)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-117_snapshot_v2/
  review: docs/review/autopilot/EQM-117_SELF_REVIEW_2026-07-02.md
  pattern: P0 (orchestrator-direct); repair 0 (Godot 初回 green)
  tests:
    - ./tools/test.sh -> RESULT: PASS; files=58 checks=938 failures=0; [api-surface] ok; [contract-coverage] violations=0
  gate: §4 transaction/core (save gate: chunk 非空 / window open で eqm.save.blocked + 空 bundle; bundle v2 shape + live object 不含;
      v1 migrator (欠落 = 空) + 未知 version 拒否; verify-before-mutate (未登録 effect/predicate/sweep rule = 安定 error + 無変更);
      lines/conditional/armed(+expiry link)/scheduled を跨ぐ roundtrip → 同一継続 resolution 列)
  surface: api_surface.json re-baselined (+EQSaveAdapter save/load の pipeline 引数; +EQReservationRuntime save_state/verify_state/apply_state;
      +EQTriggerEngine.armed_entries; +EQEventLines.restore_values; +EQCondition to_dict/from_dict; SCHEMA_VERSION 1→2) via explicit --update
  coverage: snapshot-v2 + save-enforcement -> implemented
  limitations (POLICY 記録): windows table は boundary gate により常に空 (schema shape として保持) / open race 帳簿は非 serialize (member は保存、敗者一掃のみ非継続) / EQManager への save API は不採用 (L0 に gate 対象なし)
  major files:
    - addons/event_queue_manager/runtime/eq_save_adapter.gd (v2), eq_reservation_runtime.gd (+state 三対), eq_event_lines.gd (+restore_values), eq_trigger_engine.gd (+armed_entries), eq_error.gd (+1)
    - addons/event_queue_manager/resources/eq_condition.gd (+serialize), docs/design/SNAPSHOT_COMPAT_V1.md (v2 追記), docs/design/ERROR_CONTRACT.md (+1)
    - test_project/tests/transaction/test_eq_snapshot_v2.gd (new)
```

Dependency sweep: EQM-117 COMPLETE → EQM-118 READY (reducibility 再証明)。Current pointer → EQM-118。

### EQM-118 — COMPLETE (2026-07-02)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-118_reducibility_reproof/
  review: docs/review/autopilot/EQM-118_SELF_REVIEW_2026-07-02.md
  pattern: P0 (orchestrator-direct); repair 0 (等価 7 case 全て初回成立)
  tests:
    - ./tools/test.sh -> RESULT: PASS; files=59 checks=947 failures=0; [contract-coverage] violations=0
    - ./tools/test.sh --update-golden reducibility_ctb_pipeline -> 初回 baseline (新規 fixture, DETERMINISM_TRACE_TEST_POLICY §2 手続き)
  gate: §4 policy — CTB(3 case 含非約数 speed) / Energy(2) / Wait-Turn(2) を product の conditions + event-line pipeline で構成し、
      dedicated policy と canonical trace の resolved 部分列 (tick, actor, priority) が完全一致。EQM-053 の縮小 (test 内手書き sim / order 配列) を解消。
  golden: tests/golden/reducibility_ctb_pipeline.trace.jsonl (new — product 経路 CTB の全 trace fixture)
  product 変更: submit 時点も評価点 (level 意味論の帰結; SEM §5.4 追記) — wait 0 の初期 ready が dedicated seed (due 0) と一致するための意味論補完。既存 tests 無変更 green。
  coverage: reducibility-product-proof -> implemented
  major files:
    - test_project/tests/policy/test_eq_reducibility_product.gd (new), tests/golden/reducibility_ctb_pipeline.trace.jsonl (new)
    - addons/event_queue_manager/runtime/eq_reservation_runtime.gd (submit 時点評価), docs/design/EVENT_MODEL_SEMANTICS.md (§5.4 追記)
```

Dependency sweep: EQM-118 COMPLETE → EQM-119 READY (authoring surface + dogfood/manual)。Current pointer → EQM-119。

### EQM-119 — COMPLETE (2026-07-03) — closes Phase 11 (v1.1 event-model implementation round)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-119_authoring_surface/
  review: docs/review/autopilot/EQM-119_SELF_REVIEW_2026-07-03.md
  pattern: P0 (orchestrator-direct); repair 0 (手書き .tres 含め初回 green)
  tests:
    - ./tools/test.sh -> RESULT: PASS; files=60 checks=964 failures=0; [api-surface] ok; [contract-coverage] rows=21 implemented=21 reserved=0 violations=0
    - ./tools/test.sh --update-golden authoring_counterattack -> 初回 baseline (新規 fixture)
  gate: §4 resource (SEM §5.6 凍結基準: 反撃準備 = .tres 1 個・GDScript 0 行、3回 or 5ターン、deadline ∞ 変種は expiry event 非 schedule;
      閉路の可視性 = closed_by reaction_count / duration / already_closed が golden trace 上で判別可能; 3 fires 厳密)
  golden: tests/golden/authoring_counterattack.trace.jsonl (new — dogfood L2 natural path の全 trace)
  dogfood: run_l2_trace() を additive 追加 (既存 run_trace() と golden は不変 — L0 手動配線との対照として存置)
  manual: docs/manual/{reservations,action_resolution}.md + docs/ja/manual mirror に条件宣言 / closed_by 語彙 / natural path / save 境界の節を追記
  Q35 再評価: effect grouping は defer 確定 (EQEffectRecord.tags + classification で表現可能、実需要待ち — coverage doc 記録)
  coverage: authoring-acceptance -> implemented。**21/21 — SEM v1.1 凍結契約は全て実装・test 済み**
  major files:
    - dogfood/action_resolution/counterattack_preparation.tres (new, authored), dogfood/action_resolution/battle.gd (+run_l2_trace)
    - test_project/tests/resource/test_eq_authoring_acceptance.gd (new), tests/golden/authoring_counterattack.trace.jsonl (new)
    - docs/manual/reservations.md, docs/manual/action_resolution.md, docs/ja/manual/ mirror
```

Dependency sweep: EQM-119 COMPLETE → **Phase 11 milestone reached** (EQM-110..119 COMPLETE)。queue に READY/BACKLOG task なし。Current pointer → none。2026-07-02 の監査 (`EVENT_MODEL_DESIGN_GAP_AUDIT`) が確定した「凍結契約の宣言のみ」問題は、本 round で全 21 契約 implemented + coverage gate による再発防止まで含めて解消。

### EQM-120 — COMPLETE (2026-07-05) — opens Phase 12 (v1.2 EBS 拡張ラウンド)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-120_semantics_round3/
  review: docs/review/autopilot/EQM-120_SELF_REVIEW_2026-07-05.md
  pattern: P0 (orchestrator-direct, decision-depth docs; 相談ラウンド2・3 は対話でユーザー決定)
  tests:
    - ./tools/test.sh -> RESULT: PASS (docs/queue のみ; contract-coverage: implemented=21 reserved=10 violations=0)
  gate: docs-only contract consistency (SEM v1.2 additive、Q01–Q43 決定不変; 逸脱 5 点は synthesis に明示)
  inputs:
    - EBS_EXTENSION_REQUEST_2026-07-05.md (受領原本、R01–R12)
    - 相談ラウンド2 (fork 8: メタレベル 3 点 / inv 規則 / modifier-stack / 関係 sweep / premature close 範囲 / ループ方式)
    - 相談ラウンド3 (fork 8: 連鎖 = デコレータ型 / 直列縫合のみ / provenance = event 側 / pipeline 修正 2 点 +
      変換パラメータ型 / 相殺 = 符号付き 1 本 / 加算 + override / 離脱連動 / sub-checkpoint)
  major files:
    - docs/design/EVENT_MODEL_SEMANTICS.md (v1.2: §4.8/§5.7/§6.4–6.5/§7.2/§8.2–8.4/§10.1/§11/§13.1/§16.2)
    - docs/design/EVENT_MODEL_OPEN_QUESTIONS.md (拡張ラウンド finalization + 相談ラウンド3 表)
    - docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md (reserved 10 行 + Deferred 更新)
    - docs/review/EVENT_MODEL_OPEN_QUESTIONS_SYNTHESIS_2026-07-05.md (new)
    - (EBS repo) docs/design/EQM_EXTENSION_REQUEST.md 相談記録同期
```

Dependency sweep: EQM-120 COMPLETE → EQM-121 READY (EQM-122..128 BACKLOG、線形鎖)。Current pointer → CHECKPOINT (実装 run 承認待ち、§8.3)。

### EQM-121 — COMPLETE (2026-07-05)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-121_state_algebra/
  review: docs/review/autopilot/EQM-121_SELF_REVIEW_2026-07-05.md
  pattern: P2 (codex GPT-5.5 委譲 2 run; 初回 run は context 枯渇で仕切り直し; orchestrator 検収で 2 修正)
  tests:
    - ./tools/test.sh -> RESULT: PASS ×2 (files=61 checks=1049 failures=0; api-surface ok;
      contract-coverage rows=31 implemented=23 reserved=8 violations=0)
    - ./tools/test.sh --update-golden reducibility_ctb_pipeline (非決定性修正の再 baseline、順序のみの差を機械検証)
  gate: §4 core (golden + property; 新規 golden lifetime_composition = 寿命 3 種 closed_by + CANCEL 相殺)
  repair-now: StringName sort が intern 順で replay 決定性を破る既存 bug (EQM-112 起源) を発見・修正
    (line_ids / run_sweep_rules を内容順 sort 化)。詳細と差分検証は self-review。
  golden: tests/golden/lifetime_composition.trace.jsonl (new baseline),
          tests/golden/reducibility_ctb_pipeline.trace.jsonl (再 baseline、poll 記録の並び正規化のみ),
          tests/golden/api_surface.json (EQStateAlgebra L3 追加)
  major files:
    - addons/event_queue_manager/runtime/eq_state_algebra.gd (new, L3)
    - addons/event_queue_manager/runtime/eq_event_lines.gd (modifier-stack + 決定性 sort 修正)
    - test_project/tests/core/{test_eq_state_algebra.gd (new), test_eq_event_lines.gd}
```

Dependency sweep: EQM-121 COMPLETE → EQM-122 READY (EQM-123..128 BACKLOG)。Current pointer → EQM-122。

### EQM-122 — COMPLETE (2026-07-05)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-122_relation_graph/
  review: docs/review/autopilot/EQM-122_SELF_REVIEW_2026-07-05.md
  pattern: P2 (codex GPT-5.5 委譲 1 run; orchestrator 検収で 1 修正 + 配線追加)
  tests:
    - ./tools/test.sh -> RESULT: PASS ×2 (files=62 checks=1103 failures=0; api-surface ok;
      contract-coverage rows=31 implemented=24 reserved=7 violations=0)
  gate: §4 core (trace 内容 test — relation_bound/dissolved/rebound/inverted; TREE 拒否; 直列縫合;
        maintenance sweep = EQConditionEval 流用; 月/星 acceptance 例)
  repair-now: run_maintenance の typed-null 代入が maintenance 無し型で engine error + 誤 fault
    (orchestrator 検収 probe で発見) → untyped 化 + 隔離 regression test
  wiring: EQReservationRuntime.relations (optional) + invalidate_actor が incident 関係を
    解消時規則経由で dissolve (配線 test 含む)
  golden: tests/golden/api_surface.json (EQRelationGraph L3 追加、明示 --update + doc note)
  major files:
    - addons/event_queue_manager/runtime/eq_relation_graph.gd (new, L3)
    - addons/event_queue_manager/runtime/eq_reservation_runtime.gd (relations 配線)
    - test_project/tests/core/test_eq_relation_graph.gd (new)
```

Dependency sweep: EQM-122 COMPLETE → EQM-123 READY (EQM-124..128 BACKLOG)。Current pointer → EQM-123。

### EQM-123 — COMPLETE (2026-07-05)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-123_resolution_rewrites/
  review: docs/review/autopilot/EQM-123_SELF_REVIEW_2026-07-05.md
  pattern: P2 (codex GPT-5.5 委譲 1 run; orchestrator 検収で 1 修正 — 複数 rule 展開の union 化)
  tests:
    - ./tools/test.sh -> RESULT: PASS ×2 (files=63 checks=1154 failures=0; api-surface ok;
      contract-coverage rows=31 implemented=26 reserved=5 violations=0)
  gate: §4 core (golden expansion_transform = 鑑波型展開 + 対戦術 retarget; 既存 golden 全 green =
        宣言なしで v1.1 挙動不変)
  key contracts: 2a 展開 (BFS 関係 id 昇順、停止 = hop_cost/budget — visited set でない)、
    2b 変換 (retarget = provenance 段選択 + meta reach / state_inv = inv pair 書き換え、
    メタ降順→priority→登録順、多重 round + max_transform_rounds fault)、
    provenance 自動継承 (OPERATION 経由、[{actor, event_id, meta_level}])、
    sweep は素の view のまま (trigger 挙動不変)
  golden: tests/golden/expansion_transform.trace.jsonl (new baseline),
          tests/golden/api_surface.json (新 public member、明示 --update + doc note)
  major files:
    - addons/event_queue_manager/runtime/eq_reservation_runtime.gd (+450 行 additive)
    - addons/event_queue_manager/runtime/eq_reservation.gd (provenance)
    - addons/event_queue_manager/resources/eq_action_definition.gd (meta_level / state_name)
    - test_project/tests/core/test_eq_resolution_rewrites.gd (new)
```

Dependency sweep: EQM-123 COMPLETE → EQM-124 READY (EQM-125..128 BACKLOG)。Current pointer → EQM-124。

### EQM-124 — COMPLETE (2026-07-05)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-124_atomic_bundle/
  review: docs/review/autopilot/EQM-124_SELF_REVIEW_2026-07-05.md
  pattern: P2 (codex GPT-5.5 委譲 1 run; 検収指摘なし — bundle 帳簿の invalidation/race 経路掃除まで自発対応)
  tests:
    - ./tools/test.sh -> RESULT: PASS ×2 (files=64 checks=1179 failures=0;
      contract-coverage rows=31 implemented=27 reserved=4 violations=0)
  gate: §4 core (golden fairness_bundle = 公平の二段構え: bundle_resolved →
        単一 sweep 後の reaction_fired → 個別解決; member 間 sweep なしを trace で証明)
  key contracts: submit_bundle (全員 valid 時のみ発行・WAIT/READY/OPERATION 拒否)、
    member 順 = §7.1 hook → 発行順、invalidation-wins は member 単位、
    単一 sweep + 単一 drain (save 境界整合)、bundle 帳簿は非永続 (同 tick 完結)
  golden: tests/golden/fairness_bundle.trace.jsonl (new baseline),
          tests/golden/api_surface.json (submit_bundle、明示 --update + doc note)
  major files:
    - addons/event_queue_manager/runtime/eq_reservation_runtime.gd (+225 行 additive)
    - test_project/tests/core/test_eq_atomic_bundle.gd (new)
```

Dependency sweep: EQM-124 COMPLETE → EQM-125 READY (EQM-126..128 BACKLOG)。Current pointer → EQM-125。

### EQM-125 — COMPLETE (2026-07-05)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-125_meta_premature_close/
  review: docs/review/autopilot/EQM-125_SELF_REVIEW_2026-07-05.md
  pattern: P2 (codex GPT-5.5 委譲 1 run; orchestrator 検収で golden シナリオを凍結 acceptance 形へ強化 +
           golden env var の repo 標準統一)
  tests:
    - ./tools/test.sh -> RESULT: PASS ×2 (files=65 checks=1207 failures=0;
      contract-coverage rows=31 implemented=28 reserved=3 violations=0)
    - ./tools/test.sh --update-golden interception_close (シナリオ強化後の再 baseline)
  gate: §4 core/runtime (golden interception_close = 迎撃: 5 歩中 2 歩解決済み維持 +
        pending 3 歩 closed_by: intervention + window_closed 両メタ値; 同値メタ = 介入成功;
        回避 = intervention_avoided + window 維持)
  key contracts: EQWindow.meta_level (宣言 int、window_opened へ非 0 のみ掲載 = 既存 golden 保護)、
    window 帰属帳簿 (open 中に schedule された pending が member)、nest 上位も同時 close、
    解決済み効果は無操作 (巻き戻し機構を追加していない)
  repair (orchestrator): 委任 contract 側の誤指定だった golden env var (EQ_UPDATE_GOLDEN) を
    repo 標準 GODOT_UPDATE_GOLDEN へ 3 file 統一 (test.sh --update-golden が機能する形に)
  golden: tests/golden/interception_close.trace.jsonl (new baseline),
          tests/golden/api_surface.json (intervene_close / meta_level、明示 --update + doc note)
  SEM: §11 に intervention_avoided kind を additive 追記 (同 commit、re-freeze 整合)
  major files:
    - addons/event_queue_manager/runtime/eq_window.gd (meta_level)
    - addons/event_queue_manager/runtime/eq_reservation_runtime.gd (intervene_close + 帰属帳簿)
    - test_project/tests/transaction/test_eq_premature_close.gd (new)
```

Dependency sweep: EQM-125 COMPLETE → EQM-126 READY (EQM-127..128 BACKLOG)。Current pointer → EQM-126。

### EQM-126 — COMPLETE (2026-07-05)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-126_phase_recursion/
  review: docs/review/autopilot/EQM-126_SELF_REVIEW_2026-07-05.md
  pattern: P2 (codex GPT-5.5 委譲 1 run; 検収指摘なし — snapshot restore 後の帳簿 reconcile を
           全 table (window/inv/bundle/by_event/expiry) に自発配線)
  tests:
    - ./tools/test.sh -> RESULT: PASS ×2 (files=66 checks=1240 failures=0;
      contract-coverage rows=31 implemented=29 reserved=2 violations=0)
  gate: §4 core/transaction (golden mirror_loop_rollback = 水鏡: phase_opened ×3 →
        同名再訪で phase_rolled_back (rolled_back_from + cleared_inputs 内容順);
        checkpoint restore で confirm 中の pending が scheduler から消える)
  key contracts: open_phase/close_phase (top 明示 window 上の順序付き checkpoint =
    scheduler snapshot + 宣言 inputs)、同名再訪 = 最小 cycle 検出、ループ開始点へ restore +
    上位 checkpoint pop、入力解除は cleared 一覧の trace 記録 (再入力 UX はゲーム側)、
    window close (通常/deadline/intervention) で stack 破棄
  golden: tests/golden/mirror_loop_rollback.trace.jsonl (new baseline),
          tests/golden/api_surface.json (open_phase/close_phase/current_window、--update + doc note)
  major files:
    - addons/event_queue_manager/runtime/eq_reservation_runtime.gd (+131 行 additive)
    - addons/event_queue_manager/runtime/eq_window.gd (phase_checkpoints)
    - test_project/tests/transaction/test_eq_phase_rollback.gd (new)
```

Dependency sweep: EQM-126 COMPLETE → EQM-127 READY (EQM-128 BACKLOG)。Current pointer → EQM-127。

### EQM-127 — COMPLETE (2026-07-05)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-127_snapshot_v3/
  review: docs/review/autopilot/EQM-127_SELF_REVIEW_2026-07-05.md
  pattern: P2 (codex GPT-5.5 委譲 1 run; 検収で既存 v2 test の version 固定 assert 2 件を昇格対応 —
           うち 1 件は「新 schema 拒否」の検体が 3 のままでは偽陽性化するため 4 へ)
  tests:
    - ./tools/test.sh -> RESULT: PASS ×2 (files=67 checks=1270 failures=0;
      contract-coverage rows=31 implemented=30 reserved=1 violations=0)
  gate: §4 transaction (v3 roundtrip = relations + state_algebra + modifier + provenance を跨ぎ
        同一状態; v2/v1 互換 load; v4 安定拒否; verify-before-mutate = 未接続 instance /
        未登録 predicate で何も適用しない; load 経路の state_wrapped 無発火 = restore() 使用証明)
  key contracts: schema_version 3 (additive tables relations / state_algebra; line modifiers は
    event_lines 内包・provenance は reservation dict 内包・phase checkpoints は boundary save で
    常に空 — table 不要を doc comment に明記)、EQReservationRuntime.state_algebra optional 接続
  docs: SNAPSHOT_COMPAT_V1.md v3 節 additive
  major files:
    - addons/event_queue_manager/runtime/eq_save_adapter.gd (v3)
    - addons/event_queue_manager/runtime/eq_reservation_runtime.gd (state_algebra + verify/apply)
    - test_project/tests/transaction/test_eq_snapshot_v3.gd (new)
```

Dependency sweep: EQM-127 COMPLETE → EQM-128 READY (最終 task)。Current pointer → EQM-128。

### EQM-128 — COMPLETE (2026-07-05) — closes Phase 12 (v1.2 EBS 拡張ラウンド)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-128_ebs_acceptance_suite/
  review: docs/review/autopilot/EQM-128_SELF_REVIEW_2026-07-05.md
  pattern: P2 (codex GPT-5.5 委譲; 初回 run は context 枯渇 → API 署名を contract へ貼り込み +
           runtime 読取り禁止で再委任し成功。manual は orchestrator 直筆 P0)
  tests:
    - ./tools/test.sh -> RESULT: PASS ×2 (files=68 checks=1304 failures=0;
      contract-coverage rows=31 implemented=31 reserved=0 violations=0)
  gate: §4 core (確認系 6 項目すべて「既存宣言のみ・runtime 変更ゼロ」で証明 — Q54/Q46 の仮説成立):
    R04 normalized spatial event tag + EQCondition trigger standard form
    R06 相互反撃の停止 golden mutual_counter_stop (closed_by: reaction_count で必ず停止)
    R08 スタック順 = set_order_hook 適用例 (order_hook_applied)
    R09 公平の視界非対称 = bundle + 片側 arm (bundle 後の個別誘発が片側のみ)
    R11 ready_reservation_for + invalidate→issue の原子性 (trace 間に他 resolved なし)
    R12 発行時修飾 = EQM 変更不要の証明 (発行前 delay 修飾)
  manual: docs/ja/manual/reservations.md + docs/manual/reservations.md に v1.2 章 (ja 正文)、
    dogfood README に参照追記
  golden: tests/golden/mutual_counter_stop.trace.jsonl (new baseline)
  major files:
    - test_project/tests/core/test_eq_ebs_acceptance.gd (new — runtime 変更ゼロ)
    - docs/ja/manual/reservations.md, docs/manual/reservations.md
```

Historical close record (2026-07-05): EQM-128完了時はPhase 12 milestone / contract
coverage 31/31 implementedと判定した。**2026-07-18 EQM-137監査でR04 named solve gateの
false-greenを検出し、この主張を訂正**。normalized event triggerは実装済み、reaction
FIRE condition gateはcoverage reserved / EQM-141 BACKLOG。EBS側のメタレベル値付け・
変換validationは従来どおりconsumer責務。


### EQM-129 — COMPLETE (2026-07-05) — repair (意図監査 A1)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-129_wrapper_semantics/
  review: docs/review/autopilot/EQM-129_SELF_REVIEW_2026-07-05.md
  pattern: P2 (codex 委譲 1 run; 検収で 1 修正 — 不活性 wrapper への applied-trace 誤発火を抑止)
  tests:
    - ./tools/test.sh -> RESULT: PASS ×2 (files=69 checks=1319 failures=0)
  gate: §4 core (golden wrapper_chains = 透徹連鎖 (relation_chain 伝播) + 反転連鎖 (inv_chain 対合);
        expansion_transform golden green = BFS 共通化 (EQRelationGraph.expand) の同値性証明)
  key contracts: 相談3 決定「包まれた状態の意味論を修飾」の実装 — inv_chain (grant を dual へ、
    二重で恒等) / relation_chain (grant 時の関係沿い連鎖付与、cost 停止、単層・再帰なし、
    連鎖先の inv_chain は局所適用)。未知 kind = 不活性 (無 trace、互換)。state_wrapper_applied trace。
  SEM: §5.7 標準 2 種 + §11 state_wrapper_applied を additive 改訂 (同 commit)
  major files:
    - addons/event_queue_manager/runtime/eq_state_algebra.gd (grant 時適用)
    - addons/event_queue_manager/runtime/eq_relation_graph.gd (expand 公開)
    - addons/event_queue_manager/runtime/eq_reservation_runtime.gd (_bfs 委譲)
    - test_project/tests/core/test_eq_wrapper_semantics.gd (new)
```

Dependency sweep: EQM-129 COMPLETE → EQM-130 READY。Current pointer → EQM-130。

### EQM-130 — COMPLETE (2026-07-05) — repair (意図監査 A2/C1/C2)

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-130_maintenance_autodrive/
  review: docs/review/autopilot/EQM-130_SELF_REVIEW_2026-07-05.md
  pattern: P2 (codex 委譲 1 run; 検収指摘なし)
  tests:
    - ./tools/test.sh -> RESULT: PASS ×2 (files=70 checks=1342 failures=0)
  gate: §4 core (自動駆動 test = predicate false が step_tick だけで解消 / カスタム sweep 連動 /
        未接続不変; golden fairness_relation_chain = 公平関係 → targets_expanded → 事後の片側反射)
  key contracts: 相談4「EQM が評価タイミングを固定」の実装 — 既定 sweep は step_tick で自動評価、
    カスタム sweep 名は §4.7 sweep rule 実行と連動 (同 tick 重複抑止)。predicates は named registry
    から自動供給。迎撃標準形 (effect handler 内 intervene_close) を例示 test 化 (C2 消化)。
  golden: tests/golden/fairness_relation_chain.trace.jsonl (new baseline)
  major files:
    - addons/event_queue_manager/runtime/eq_reservation_runtime.gd (step_tick 統合)
    - test_project/tests/core/test_eq_fairness_relation.gd (new)
```

Dependency sweep: EQM-130 COMPLETE → EQM-131 READY。Current pointer → EQM-131。

### EQM-131 — COMPLETE (2026-07-05) — repair (意図監査 B1/B2 + EBS A-R08-1)、repair round 終端

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-131_acceptance_repair/
  review: docs/review/autopilot/EQM-131_SELF_REVIEW_2026-07-05.md
  pattern: P2 (codex 委譲 1 run; 検収で scope 外回帰 1 件を修正 — targets_expanded 記録の
           インデント外し (展開ゼロでも記録される) を guard 内へ復帰 + regression test)
  tests:
    - ./tools/test.sh -> RESULT: PASS ×2 (files=70 checks=1356 failures=0)
  gate: §4 core (golden focus_cost_counter_stop = 焦点 counter line の閉包で停止、
        closed_by: focus_exhausted — 依頼原文「コスト述語の閉包で必ず止まる」の証明;
        既存 mutual_counter_stop は回数系変種として不変)
  key contracts: retarget params.stage に int (provenance index、reach 検査、範囲外 = no-op) を
    additive 追加 — 「root/中間/直接のどれにするか調整」の中間段が宣言可能に。
    R08 例を EBS A-R08-1 (メタレベル昇順・同率付与順 = index tiebreak) に整合。
    旧 R06 の常真 assert 2 本を実質化。
  golden: tests/golden/focus_cost_counter_stop.trace.jsonl (new baseline)
  major files:
    - addons/event_queue_manager/runtime/eq_reservation_runtime.gd (stage int + 回帰修正)
    - test_project/tests/core/test_eq_ebs_acceptance.gd, test_eq_resolution_rewrites.gd
```

Dependency sweep: EQM-131 COMPLETE → **repair round (EQM-129..131) 完了**。意図監査の重大 2・中 3・acceptance 2 はすべて消化 (B3 は EBS 文書で確定のため変更なし)。残る記録 4 件 (D1 modifier 寿命の宣言束ね / D2 phase 巻き戻しの対象範囲 / D3 bundle kind 制限 / D4 provenance の反応連鎖非継承) は EBS 側のスキル執筆で実需要が出た時点で再評価。queue pointer → none。

### EQM-132 — COMPLETE (2026-07-15) — reaction FIRE occurrence context v1

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-132_reaction_fire_context/
  review: docs/review/autopilot/EQM-132_SELF_REVIEW_2026-07-15.md
  tests:
    - ./tools/test.sh -> RESULT: PASS (files=72 checks=1518 failures=0)
  docs:
    - docs/devflow/TEST.md
    - docs/design/EVENT_MODEL_SEMANTICS.md
    - docs/design/SNAPSHOT_COMPAT_V1.md
    - docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md
  golden:
    - authoring_counterattack / fairness_bundle / fairness_relation_chain
    - focus_cost_counter_stop / lifetime_composition / mutual_counter_stop
    - accepted additive cause + reaction_fire_resolved records; order unchanged
  major files:
    - addons/event_queue_manager/runtime/eq_reaction_fire_context.gd
    - addons/event_queue_manager/runtime/eq_trigger_engine.gd
    - addons/event_queue_manager/runtime/eq_reservation_runtime.gd
    - addons/event_queue_manager/runtime/eq_save_adapter.gd
    - test_project/tests/trigger/test_eq_reaction_fire_context.gd
```

Dependency sweep: EQM-132 COMPLETE → dynamic follow-up closed。queue に READY/BACKLOG task なし。Current pointer → none。

### EQM-133 — COMPLETE (2026-07-15) — reaction-expiry checkpoint

```text
proof:
  plan: docs/plan/2026-06-09_event_queue_manager/EQM-133_reaction_expiry_checkpoint/
  review: docs/review/autopilot/EQM-133_SELF_REVIEW_2026-07-15.md
  tests:
    - ./tools/test.sh -> RESULT: PASS (files=72 checks=1566 failures=0)
  docs:
    - docs/devflow/TEST.md
    - docs/design/EVENT_MODEL_SEMANTICS.md
    - docs/design/SNAPSHOT_COMPAT_V1.md
    - docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md
    - docs/design/API_SURFACE.md
    - docs/design/ERROR_CONTRACT.md
  golden:
    - tests/golden/api_surface.json (enum + exact one-event method + stable error)
    - deterministic trace fixtures unchanged
  major files:
    - addons/event_queue_manager/runtime/eq_reservation_runtime.gd
    - addons/event_queue_manager/runtime/eq_save_adapter.gd
    - addons/event_queue_manager/runtime/eq_error.gd
    - test_project/tests/trigger/test_eq_reaction_fire_context.gd
    - test_project/tests/transaction/test_eq_snapshot_v2.gd
```

Dependency sweep: EQM-133 COMPLETE → checkpoint blocker closed。queue に READY/BACKLOG task なし。Current pointer → none。

### EQM-134 — COMPLETE (2026-07-16) — state/relation work-scale repair

```text
source: Amberground state/passive/perception implementation audit
acceptance:
  - state/relation/trigger scales are recorded as engineering evidence, never gameplay slots
  - state_inv is one-shot per effect and does not oscillate into the round guard
  - 64 tokens × 8 actors, 1,024 relations, and 200 actual triggers round-trip/resolve
plan: docs/plan/2026-06-09_event_queue_manager/EQM-134_state_relation_work_scale/
tests: ./tools/test.sh PASS (files=73, checks=1617, failures=0; run 20260716-092734-47551)
review: docs/review/autopilot/EQM-134_SELF_REVIEW_2026-07-16.md
```

Current pointer → none。EQM-134 COMPLETE; gameplay state capacity remains consumer-owned。

### EQM-135 — COMPLETE (2026-07-18) — reservation meta intervention

```text
source: Amberground interception tranche / game-planner API confirmation 4ee78ee
acceptance:
  - accepted submit samples reservation meta exactly once; schema v7 persists it
  - equal-or-greater intervention invalidates one ordinary PREPARED singleton without effect execution
  - lower meta records intervention_avoided and leaves scheduler/save state unchanged
  - unknown, wrong-kind, bundle, race, and reaction FIRE targets reject without mutation
  - success trace reuses event_invalidated + closed_by: intervention with both metas and optional intervener id
plan: docs/plan/2026-06-09_event_queue_manager/EQM-135_reservation_intervention/
tests: ./tools/test.sh PASS (files=74, checks=1682, failures=0; run 20260718-040730-15535)
review: docs/review/autopilot/EQM-135_SELF_REVIEW_2026-07-18.md
```

Current pointer → none。EQM-135 COMPLETE; group intervention generalization and game-side damage/range/presentation remain consumer-owned or demand-gated。

### EQM-136 — COMPLETE (2026-07-18) — production trigger index + independent performance lane

```text
acceptance:
  - canonical armed tableから再構築可能なtarget/wildcard indexをproduction engineへ透明に統合
  - 1,000 arms fixtureでcandidate/full-match 75、旧full-scan相当の925 callsを構造的に除去
  - arm order、shared-condition retarget、duplicate slot、rumination、expiry境界、disarm、save/load不変
  - standard regressionとperformance discoveryを排他化し、unknown/zero-file/golden misuseはfail-closed
  - Amberground test/scene/timingをbaselineまたはoracleに使用せず、EQM headless範囲だけを主張
plan: docs/plan/2026-06-09_event_queue_manager/EQM-136_trigger_index_runtime/
tests:
  - ./tools/test.sh -> PASS (regression only; files=74 checks=1705 failures=0; run 20260718-210518-25827)
  - ./tools/test.sh --performance -> PASS (performance only; files=4 checks=16 failures=0; run 20260718-210344-16925)
performance:
  - trigger fixture: total=1000 candidates=75 matches_calls=75 fired=0 retained=1000
  - elapsed=181 usec (Godot 4.7 stable, Darwin arm64, one headless sweep; advisory only)
compatibility:
  - API surface golden unchanged; snapshot schema v7 and deterministic trace goldens unchanged
review: docs/review/autopilot/EQM-136_SELF_REVIEW_2026-07-18.md
profile: docs/design/RUNTIME_PERFORMANCE_PROFILE.md
```

Current pointer → none。EQM-136 COMPLETE; event-line/relation/scheduler/traceの次最適化は新しいEQM-local evidenceが出た場合だけ起票する。

### EQM-137 — COMPLETE_WITH_BACKLOG (2026-07-18) — reaction-condition contract hardening

```text
acceptance:
  - reaction_condition is EQCondition|null; wrong types reject before issuance mutation
  - dev and shipped record eqm.reaction.condition_type_invalid + reservation_rejected
  - direct engine/index reject without consuming status, arm slot, or sequence
  - valid null/EQCondition lifecycle and normal trace/golden behavior remain unchanged
  - EBS corrects R04 to normalized event tag + EQCondition trigger and fails on SCRIPT ERROR
plan: docs/plan/2026-06-09_event_queue_manager/EQM-137_reaction_condition_contract/
tests:
  - ./tools/test.sh -> PASS (regression only; files=74 checks=1757 failures=0; run 20260718-223514-52656; coverage 34 implemented + 1 reserved, violations=0)
  - ./tools/test.sh --performance -> PASS (performance only; files=4 checks=16 failures=0; run 20260718-223533-53363)
  - EBS ./tools/test.sh -> PASS (166/166; 574 asserts; runner guard also converted the prior SCRIPT ERROR false-green to exit 1 before repair)
  - EBS ./tools/test_performance.sh -> PASS (5/5; 16 asserts); ./tools/package_addon.sh --check -> PASS
api:
  - EQTriggerEngine.arm return void -> bool (explicit low-level rejection result)
  - EQError append-only REACTION_CONDITION_TYPE_INVALID
review: docs/review/autopilot/EQM-137_SELF_REVIEW_2026-07-18.md
```

Dependency sweep: EQM-137 COMPLETE_WITH_BACKLOG → EQM-138 READY。named solve gateは
consumer proofから除外し、EQM-141へ分離。addon `754f905`をEBS `DEPS.md` / development
logsへ記録し、EBS current symlinkでregression/performance/packageを再検証済み。

### EQM-138 — COMPLETE (2026-07-18) — stable trigger candidate merge

```text
acceptance:
  - target/wildcard derived buckets stay sequence-sorted across add/remove/retarget
  - candidates are exact global arm order; single-bucket paths return fresh arrays
  - production candidates() has no full-result sort; mixed assembly is O(t+w)
  - public API/schema/trace unchanged
tests:
  - ./tools/test.sh -> PASS (regression only; files=74 checks=1761 failures=0; run 20260718-224934-81074)
  - ./tools/test.sh --performance -> PASS x3 (performance only; files=4 checks=22 failures=0;
    runs 20260718-224906-80604, 20260718-224950-81434, 20260718-225017-81801)
performance (candidate-array assembly only; advisory):
  - sparse 75 candidates: 4.43–4.65x / 77.4–78.5% time reduction
  - wildcard-heavy 275 candidates: 9.93–10.24x / 89.9–90.2% time reduction
review: docs/review/autopilot/EQM-138_SELF_REVIEW_2026-07-18.md
profile: docs/design/RUNTIME_PERFORMANCE_PROFILE.md
```

Dependency sweep: EQM-138 COMPLETE → EQM-139 READY。Current pointer → EQM-139。
