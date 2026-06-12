# ROADMAP: Event Queue Manager

Roadmap ID: `event_queue_manager`
Date: 2026-06-09
Target: Godot addon for generic event / turn / action order management

## 1. Why this roadmap exists

Event Queue Manager is not merely a turn-order list. It is a reusable scheduling layer for games where future actions, actor readiness, conditional reactions, status ticks, phase transitions, cooldowns, and visual effect timing must be resolved in a deterministic and observable order.

The immediate goal is to ship a Godot addon that covers the MVP described earlier:

- `EQManager`
- `EQScheduler`
- `EQEntry`
- `EQActorState`
- `EQConfig`
- `EQFixedRoundPolicy`
- `EQCTBPolicy`
- signal integration
- next-N preview
- sample battle

The expanded goal is to support both common game systems and the specific target use case:

- Wait Turn system inspired by Tactics Ogre-style per-unit wait consumption.
- Action Resolution Turn-Based system where entities reserve actions with AP, time, condition triggers, reaction preparation, wait, ready reservation, rollback, and staged visual effects.
- RPG, roguelike, tactics, 4X, card/board game, cooldown/status, and stack-like event ordering.

## 2. User and developer workflows improved

### Workflow A: Add a normal turn-order system to a Godot game

A developer adds `EQManager`, selects an `EQPolicy` Resource, registers actors, receives `turn_ready` signals, finishes actions with `EQActionResult`, and optionally shows a timeline preview.

### Workflow B: Build CTB / energy / wait-turn combat without rewriting the scheduler

A developer changes only the policy and action cost model while keeping the same scheduling, snapshot, prediction, and debug tooling.

### Workflow C: Build Action Resolution Turn-Based gameplay

A developer defines action reservations such as immediate action, prepared action, reaction preparation, wait, ready reservation, operation action, and rumination. The scheduler resolves these reservations by tick, priority, and trigger conditions.

### Workflow D: Separate simulation correctness from presentation timing

Game state effects are applied deterministically as events resolve. Visual effects can be flushed, deferred, batched, or skipped depending on importance, player sensing, target movement dependencies, and offscreen classification.

### Workflow E: Author and debug ordering rules in the editor

A developer previews next events, validates configuration Resources, inspects why a tie-breaker chose one event over another, and loads demo templates for common genres.

### Workflow F: Calibrate editor layout with structured feedback

The addon author enables a debug-only calibration tab, adjusts layout parameters directly on a dock, and copies a structured layout feedback JSON. Development bakes accepted values back into code, contract thresholds, and tests. Controls untouched across calibration iterations accumulate history and become quality review candidates.

## 3. Adopted principles

1. Event-first: actor turns, status ticks, cooldown completions, reactions, phase changes, and visual flush barriers are all events.
2. Deterministic order: event ordering uses integer tick, priority, explicit tie-breaker, and sequence.
3. Policy separation: genre-specific behavior belongs in `EQPolicy` subclasses or policy Resources, not in the core scheduler.
4. Resource-driven configuration: Godot developers should save and reuse turn-order rules as `.tres` Resources.
5. Headless core first: core scheduling must be testable without a running scene tree.
6. Simulation/presentation split: state effects resolve independently from animation/effect playback.
7. Transactional player turns: rollback before committing wait/end-turn is a first-class design requirement.
8. Observable behavior: prediction, debug snapshots, and timeline explanation are part of the product, not optional polish.
9. No sample-only completion: sample scenes teach usage but do not prove production readiness.
10. Autoload optional: scene-local `EQManager` is the default; global service is opt-in.
11. Projection-first editor UI: editor surfaces render injected headless state (snapshot, validation, prediction), so every UI state can be constructed and tested without editor selection.
12. Structural UI acceptance: editor UI is gated by layout metric, state matrix, and interaction contract tests, not screenshots (`docs/devflow/policy/UI_TESTABILITY_POLICY.md`).
13. Trace as artifact: resolved event order is exported as a canonical trace and approval-tested against golden fixtures (`docs/devflow/policy/DETERMINISM_TRACE_TEST_POLICY.md`).
14. Path reduction: input classes for primary features are narrowed so that no flow can be entered but not completed (`docs/devflow/policy/UX_PATH_REDUCTION_POLICY.md`).

## 4. Rejected or deferred principles

### Rejected

- Actor-only turn queues as the core abstraction.
- Float time as the primary ordering key.
- Implicit random tie-breaking.
- Editor UI that silently relies on bundled sample presets.
- Treating visual effect playback as the source of truth for simulation order.

### Deferred

- Network rollback / multiplayer lockstep.
- Full visual scripting graph editor for action definitions.
- Asset Library release automation.
- Binary heap optimization beyond the first scalable backend milestone.
- Formal migration support for pre-1.0 schemas.

## 5. Vocabulary

| Term | Meaning |
|---|---|
| Entity / Actor | A game participant that can own events or reservations. |
| Event | A scheduled or triggered occurrence to resolve. |
| Reservation | An event-like action intent with AP cost, delay, condition, tags, duration, and payload. |
| Ready reservation | A special reservation that grants an entity its next turn when resolved. |
| Wait reservation | A special reaction preparation that closes a turn and schedules ready reservation on resolution. |
| Trigger | A condition that resolves or schedules a reservation outside normal time countdown. |
| Rumination | Re-scheduling the same reservation after resolution while a count remains. |
| Effect | The simulation-side result of a resolved event. |
| Presentation event | The visual/audio representation of an effect. |
| Flush barrier | A rule that forces deferred presentation events to play before continuing. |
| Snapshot | Serializable scheduler and actor/reservation state for save/load, prediction, or rollback. |
| Trace | Canonical, replayable record of resolved events used as an approval-tested artifact. |
| Projection integrity | The editor UI displays exactly the values derived from injected headless state, never recomputed UI-side. |

## 6. Target architecture

```text
addons/event_queue_manager/
  runtime/
    core scheduler, entries, heap/sorted backend, snapshots
  resources/
    config, policies, action definitions, condition definitions
  policies/
    fixed round, CTB, energy, wait turn, action resolution, tactics, phase, stack
  adapters/
    actor adapter, Godot node bridge, visibility/sensing bridge, animation bridge
  editor/
    timeline dock, config inspector, debug inspector, template generator
    testing/
      ui snapshot collector, metric evaluator, scenario builder, calibration tab
  demos/
    ctb_battle, roguelike_energy, wait_turn_tactics, action_resolution, phase_4x, stack_cards
  tests/
    core, policy, resource, trigger, transaction, presentation, ui headless, golden traces, package

tools/
  test.sh, ui_static_audit.py

docs/ui/
  EDITOR_UI_CONTRACT.md, EDITOR_STATE_MATRIX.md, LAYOUT_CALIBRATION_LEDGER.md
```

## 7. Phase roadmap

### Phase 0 — Devflow specialization and test harness

Purpose: make the repository safe for Codex/autopilot execution before product work grows.

Produces:

- Event Queue Manager-specific `PROJECT_PROFILE.md`.
- Filled `docs/devflow/TEST.md`.
- `tools/test.sh` skeleton.
- Initial `docs/plan/2026-06-09_event_queue_manager/ROADMAP.md` and `IMPLEMENTATION_QUEUE.md`.
- Test/UX policy pack under `docs/devflow/policy/` (added 2026-06-13): `UI_TESTABILITY_POLICY.md`, `UI_LAYOUT_METRIC_TEST_POLICY.md`, `UI_LAYOUT_CALIBRATION_POLICY.md`, `UX_PATH_REDUCTION_POLICY.md`, `DETERMINISM_TRACE_TEST_POLICY.md`.

Why first: Without project-specific principles and test gates, the autopilot loop cannot judge completion cleanly.

### Phase 1 — Deterministic core scheduler MVP

Purpose: create the smallest useful event-first scheduler.

Produces:

- `EQEntry`, `EQScheduler`, sorted-array backend, comparator, push/pop/peek/cancel/reschedule.
- Stable ordering by `due_tick ASC`, `priority DESC`, `sequence ASC`.
- `EQSnapshot` for current tick, sequence counter, actors, and entries.
- Core tests for ordering, cancellation, invalidation, and snapshot roundtrip.
- Canonical trace export and determinism harness: golden trace fixtures, insertion-permutation and snapshot-replay property tests per `DETERMINISM_TRACE_TEST_POLICY.md`.

Why now: All later policies and reservations depend on this contract.

### Phase 2 — Resource/API contract and validation

Purpose: expose clean Godot-facing configuration without binding the core to scene state.

Produces:

- `docs/design/EVENT_MODEL_SEMANTICS.md`: ordering key, tick advancement, phase/insertion-window model (turn-as-event), reentrancy, simultaneous-trigger resolution, and AP accounting, decided before the public contracts freeze.
- `docs/design/ORDERING_MODEL_COVERAGE.md`: a matrix mapping known ordering systems (CTB, energy, wait-turn, FE phase, 4X phase, stack/LIFO, Pokemon-style speed turn, 行動解決ターン制) onto the model, so missing primitives surface before the API hardens.
- `EQConfig` Resource.
- `EQPolicy` base Resource.
- `EQActorState` and actor registration contract.
- `EQActionResult` and event finish contract.
- Validation errors for missing policy, invalid actor id, negative delay, and ambiguous tie-breaker.

Why now: Policies and editor tooling need stable public contracts.

### Phase 3 — Basic policy MVP

Purpose: cover the original MVP use cases.

Produces:

- `EQFixedRoundPolicy`.
- `EQCTBPolicy`.
- `EQManager` Node with signals: `queue_changed`, `event_ready`, `turn_ready`, `event_resolved`, `timeline_advanced`, `invalid_event_skipped`.
- Next-N prediction for round and CTB.
- Minimal CTB sample battle.
- v0.1 milestone evaluation: API friction and semantics drift audit feeding queue adjustments.

Why now: This delivers the first playable addon slice.

### Phase 4 — Energy and Wait Turn policies

Purpose: support roguelike speed/energy and Tactics Ogre-style per-unit wait consumption.

Produces:

- `EQEnergyPolicy` with threshold and action cost.
- `EQWaitTurnPolicy` where each unit's wait value decreases virtually, and the next unit is selected instantly by minimum readiness time.
- Actor wait modifiers for speed, equipment weight, status effects, and action cost.
- Tests comparing expected order under equal wait, different speed, delay, and tie-breaker cases.

Why now: Wait Turn is the bridge between simple CTB and the user's Action Resolution model.

### Phase 5 — Action Reservation model

Purpose: represent actions as reservations rather than direct function calls.

Produces:

- `EQReservation` / `EQActionReservation` model.
- Action categories: immediate, prepared, reaction preparation, wait, ready reservation, operation action.
- AP cost, resolution delay, tags, target descriptor, duration, rumination count, source actor, owner actor, and payload.
- Action result pipeline that can schedule zero, one, or many follow-up reservations.
- Tests for immediate action, prepared action, wait scheduling ready reservation, and operation action that causes another entity to reserve.

Why now: This is the core of Action Resolution Turn-Based gameplay.

### Phase 6 — Trigger and reaction engine

Purpose: allow reservations to resolve from conditions, not only time.

Produces:

- `EQCondition` Resource / callable adapter.
- Event tags such as `<探索>`, `<損害>`, `<移動>`, `<支援>`, custom tags.
- Reaction subscription index.
- Reaction preparation matching rules: source, target, tag, range, sensing, duration.
- Rumination support with cycle guard and max-reschedule limit.
- Tests for counterattack preparation, duration expiry, one-shot vs repeated reaction, and loop prevention.

Why now: Reactions are the hardest part of the user's design and must be isolated before UI grows.

### Phase 7 — Transaction, rollback, and deterministic prediction

Purpose: support player turn experimentation before committing wait/end-turn.

Produces:

- Draft transaction for player-controlled action selection.
- Snapshot-based rollback before wait reservation is committed.
- Commit boundary at wait/end-turn.
- Deterministic random stream inside snapshot.
- Prediction that can simulate future events without mutating live scheduler.
- Tests for rollback, commit, deterministic replay, and prediction purity.

Why now: Player-facing action reservation systems need rollback as a core guarantee, not editor polish.

### Phase 8 — Effect and presentation pipeline

Purpose: separate status changes from screen effect playback and solve visibility-related contradictions.

Produces:

- `EQEffectRecord` for simulation-side effects.
- `EQPresentationEvent` for animation/audio/VFX requests.
- Visibility classes: important/player-involved, sensed, offscreen.
- Flush policies:
  - important event: flush prior pending presentation before resolving/displaying it.
  - sensed non-important event: apply status immediately, defer presentation until player turn or barrier.
  - offscreen event: apply status, skip presentation.
  - moving-target dependency: flush prior presentation before resolving an event that refers to moved targets.
- Tests for effect order, flush barrier, sensed deferred playback, offscreen skip, and moving target consistency.

Why now: This is what makes the user's system usable in an actual game rather than merely correct internally.

### Phase 9 — Godot runtime integration

Purpose: make the headless model convenient inside real Godot scenes.

Produces:

- `EQManager` production Node.
- Actor binding by `actor_id` and WeakRef.
- Optional Autoload installer setting.
- Signal bridge for turn, reservation, trigger, effect, presentation, and invalid event.
- Save/load adapter that stores ids and Resources, not live Nodes.
- Tests or debug scenes for scene-local manager, actor deletion, and save/load rebind.

Why now: Runtime integration should stabilize after the core semantics are proven.

### Phase 10 — Editor tooling

Purpose: turn the addon into a designer-friendly tool.

Produces:

- Timeline Preview Dock.
- Config Resource editor helpers.
- Debug inspector explaining order decisions, rendered from explanation-as-data.
- Template generator for CTB, energy, wait turn, action resolution, phase, and stack.
- Validation UI with explicit unset/error states.
- UI headless tests for project asset selection and validation state.
- `docs/ui/EDITOR_UI_CONTRACT.md` and `docs/ui/EDITOR_STATE_MATRIX.md` as UI test source of truth.
- UI static audit, layout snapshot collector, and metric evaluator with staged gates (WARN -> P0 -> P1).
- Projection integrity tests: displayed timeline order equals headless prediction order.
- Layout Calibration Loop: debug-only calibration tab, layout feedback JSON, calibration ledger, cold-control review candidates.

Why now: Editor UX depends on stable APIs and must not become sample-only.

### Phase 11 — Demo suite and documentation

Purpose: provide learning paths without making demos the product contract.

Produces:

- Demos:
  - CTB battle.
  - Roguelike energy dungeon loop.
  - Wait Turn tactics board.
  - Action Resolution Turn-Based prototype.
  - 4X phase order.
  - Stack/card reaction sample.
- Manual pages:
  - Quick start.
  - Policy selection guide.
  - Reservation guide.
  - Trigger/reaction guide.
  - Presentation pipeline guide.
  - Save/load and rollback guide.
- Analog test docs for editor operation, if requested.

Why now: Documentation should explain adopted behavior after the implementation exists.

### Phase 12 — Performance, package, and release readiness

Purpose: make the addon credible beyond small battles.

Produces:

- Binary heap backend.
- Trigger subscription indexing.
- Large simulation benchmarks.
- Package manifest checks.
- Clean project load smoke test.
- Godot Asset Library candidate package.
- v1.0 review report.

Why last: Optimization and release packaging should follow stable semantics.

## 8. Milestones

| Milestone | Main value | Included phases |
|---|---|---|
| v0.1 Core MVP | Fixed round / CTB turn order works in a scene. | Phase 0-3 |
| v0.2 Time Models | Energy and Wait Turn models work. | Phase 4 |
| v0.3 Reservation MVP | Immediate/prepared/wait/ready reservations work. | Phase 5 |
| v0.4 Reaction & Rollback | Reaction preparation, rumination, rollback, deterministic prediction. | Phase 6-7 |
| v0.5 Presentation Control | Important/sensed/offscreen visual flush semantics. | Phase 8 |
| v0.7 Godot Tooling | Editor timeline/debug/config workflows. | Phase 9-10 |
| v0.9 Demo & Docs | Multiple genre demos and manual coverage. | Phase 11 |
| v1.0 Release Candidate | Performance, packaging, release proof. | Phase 12 |

## 9. Success criteria

The roadmap succeeds when:

- A developer can add the addon to a clean Godot project and run a simple CTB battle.
- A developer can switch to energy or wait-turn policy without rewriting game logic.
- A developer can model immediate, prepared, reaction, wait, ready reservation, operation action, and rumination.
- Player-controlled action selection can be rolled back before committing wait/end-turn.
- Simulation effects and visual effects can be handled separately without order contradictions.
- Timeline preview explains why the next event is next.
- Save/load restores event order without storing live Node references.
- Tests cover core ordering, policies, resources, triggers, rollback, presentation flush, and package smoke.
- Same-seed replays, insertion permutations, and prediction purity tests prove deterministic order; demos ship golden traces.
- Editor UI passes layout metric P0 gates across the dock size / scale / locale / state scenario matrix without screenshot review.

## 10. First queue-designed scope

The first implementation queue should cover Phase 0 through Phase 3:

1. Devflow specialization and test harness.
2. Deterministic core scheduler.
3. Canonical trace export and determinism harness.
4. Resource/API contract.
5. Fixed round policy.
6. CTB policy.
7. Runtime `EQManager` signal integration.
8. Next-N prediction.
9. Minimal sample battle.

Phase 4 and later should remain BACKLOG until the MVP contracts are complete.
