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

### 1.1 Development role and scope reframe (2026-06-14)

The addon is the deliverable. The gameplay-unproven Action Resolution Turn-Based system is adopted as a demanding **test case** that drives the addon's feasibility forward in small, verifiable steps; the test-case/demo games are not products to ship on their own (`No sample-only completion`). Two consequences:

- A milestone is "done" when it produces a **verifiable capability** (golden trace / metric / contract), not when it ships a game.
- Reducibility (EQM-053) proves the common genres *can* be expressed through the reservation + event-line model, validating its generality. It does **not** mandate that every ordering model be implemented by reduction — independent per-model implementations as `EQPolicy` are permitted (the core stays genre-agnostic; policies may be standalone).

### 1.2 Positioning / differentiation

The killer differentiators over hand-rolled turn loops and existing addons are: deterministic total order with a canonical, replayable trace; the event-line progression substrate that unifies tick / WT / CT / AP / counters without `due_tick` recalculation; and projection-first, screenshot-free editor testability. These shape priority: anything that protects determinism, trace, or the simple-path experience ranks above breadth.

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
15. Layered, progressively disclosed API: the simple turn-order path (L0/L1) and the deep reservation/event-line path (L2/L3) are both first-class; the simple path is not a hack, and the deep path is not subordinate (see §3.1). When the simple path cannot avoid a tax, classify it explicitly as a cost (payable) vs a design impossibility, and manage the two distinctly.
16. Resilience modes: a dev assertion mode fails fast; a shipped resilient mode never crashes the consumer's game, skipping/logging instead (`docs/devflow/policy/RUNTIME_RESILIENCE_POLICY.md`).
17. Prediction as a pure hypothetical API: prediction branches a snapshot, advances virtually, and is discarded, so AI and players can evaluate "act now vs wait" without mutating live state.
18. Multiplayer non-preclusion: the deterministic, serializable, seeded, replayable core must not foreclose future lockstep, even though netcode is out of v1 scope.
19. Language-agnostic core: the scheduler is defined by a backend-portable contract so the ordering backend can move (sorted-array → binary heap → future native/GDExtension) without a public API break.

### 3.1 Layering and public boundaries

```text
L0 turn order  : register actor → turn_ready signal → finish. Usable without knowing event-lines or reservations.
L1 policy      : Fixed / CTB / Energy / Wait-Turn via Resource swap.
L2 reservation : reservations, AP, resolution delay; opt-in, does not break L0/L1.
L3 event-line / window / reentrancy : full Action Resolution semantics.
```

Each milestone declares the highest layer that stays simple to use. EQM-023 (API surface gate) is layer-aware: a change that leaks L3 complexity into the L0/L1 surface fails. The A1 decision (L3 contracts reserved in Phase1/2, implemented in Phase4/5) is what keeps early milestones from being held hostage by deep semantics.

### 3.2 Target runtime and version

- Godot 4.x; the exact minimum is declared in `addons/event_queue_manager/plugin.cfg` and `project.godot`, and the clean-load smoke test pins it.
- Default implementation is GDScript. The core ordering backend is isolated behind a contract so a native/GDExtension backend can be substituted later for large-battle / recursive-summoning scale (connects to Q17/Q26 polling cost and EQM-102).

## 4. Rejected or deferred principles

### Rejected

- Actor-only turn queues as the core abstraction.
- Float time as the primary ordering key.
- Implicit random tie-breaking.
- Editor UI that silently relies on bundled sample presets.
- Treating visual effect playback as the source of truth for simulation order.
- メタレベルの部分順序 (カテゴリ比較) — 単一 int の全順序を採用し「比較不能」ケース自体を排除する (Q51, 2026-07-05)。

### Deferred

- Network rollback / multiplayer lockstep — deferred as implementation, but kept as a non-preclusion constraint (principle 18): the determinism/serialization work must not foreclose it.
- Full visual scripting graph editor for action definitions.
- Asset Library release automation.
- Binary heap optimization beyond the first scalable backend milestone.
- Native / GDExtension ordering backend — deferred, but the core contract must allow it without a public API break (principle 19).
- Grouped / micro-event-line for RTS-scale entity counts (`EVENT_MODEL_OPEN_QUESTIONS.md` Q24) — deferred; the v1 model must not preclude it.
- Formal migration support for pre-1.0 schemas (but `schema_version` and a stable unknown-version load error ship from v0.x).

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
| Event-line | An acceptance-defined incremental integer progression variable. The global tick is the primary event-line; WT/CT, AP recovery, and effect-count counters are additional event-lines. Progression input only — never the resolution order itself. |
| Master timeline | The single deterministic total order of resolved events produced by the int comparator (tick/priority/sequence). Event-lines feed it; it is the output. |
| Solve / Invalidation conditions | A reservation resolves when its `solve_conditions` hold (AND default) and is dropped when any `invalidation_conditions` hold (OR default). OR-resolution is expressed as a race of event-lines; AND-invalidation as a decremental counter event-line. |
| Composite resolution comparator | An acceptance-provided deterministic ordering key (from serializable state) for member/effect order inside a composite resolution. Out of the core ordering key; float allowed here only. |
| Effect-processing chunk | The set of resolved-but-not-yet-flushed effects. A save is allowed only when it is empty; that empty point coincides with a sync barrier. |

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
- Snapshot `schema_version` field; unknown versions fail with a stable load error.

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
- Error taxonomy: stable error codes, recoverability classes, and game/editor surfacing rules (`docs/design/ERROR_CONTRACT.md`).
- Public API surface gate: public/internal naming convention and a deterministic API surface snapshot diffed in tests.

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
- Policy reducibility proofs: CTB, energy, and wait-turn expressed as reservation-model configurations reproduce the dedicated policies' golden traces.

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
- Game-loop driver contract: who advances the queue, suspend semantics awaiting player input, await boundary for action presentation.
- Player-facing runtime timeline HUD rendering injected prediction (projection integrity in-game), with explicit stale state during deferred presentation.
- Dogfood consumer slice: a minimal playable Action Resolution game built only on the public API, shipping its own golden trace and a friction report.

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
- Declared numeric performance budgets (actors, events, per-advance cost) that benchmarks are judged against.
- Large simulation benchmarks.
- Package manifest checks.
- Clean project load smoke test.
- Godot Asset Library candidate package.
- v1.0 review report.

Why last: Optimization and release packaging should follow stable semantics.

### Phase 13 — EBS 拡張ラウンド: 状態・関係サブシステムと解決パイプライン拡張 *(additive, 2026-07-05)*

Purpose: v1.1 完了後に受領した初の外部実需要 — consumer プロジェクト EBS (godot-editable-battleskill-system) の拡張依頼 R01–R12 — に応える。受領原本: `EBS_EXTENSION_REQUEST_2026-07-05.md` (同 plan dir)。設計質問は `EVENT_MODEL_OPEN_QUESTIONS.md` 拡張ラウンド Q44–Q54 に起票済みで、相談ラウンド2・3 (2026-07-05) により意味論 fork 16 点すべて DECIDED(user) (推奨からの逸脱 5 点は synthesis 2026-07-05 に明示)。

Produces:

- 設計ラウンド task (**EQM-120, 2026-07-05 完了**): Q44–Q54 の確定 → SEM **v1.2** additive 節 + contract coverage reserved 行 + queue Phase 12 起票 (Phase 11 の EQM-110 と同型)。
- A系 (状態・関係サブシステム): inv 双対ペア宣言 + 共存規則 (Q44)、event-line rate modifier-stack (Q45)、寿命合成の acceptance 例 (Q46)、関係グラフ first-class 化 (Q47)、効果対象の展開規則 (Q48)。
- B系 (解決パイプライン拡張): composite atomic bundle 前倒し (Q49)、window premature close + メタレベル判定 (Q50/Q51)、効果パターン変換フック + 発行連鎖メタデータ (Q52)、操作フェーズ再帰とループ解消 (Q53)。
- 確認系 applicative case / golden trace 群 (Q54): オーラ・地点効果 / 相互反撃停止 / 防御スタック順 / 公平並列 / 蘇生・追加ターン / 発行時修飾不要の確認。EBS スキル群を acceptance instance として添える (個別ゲーム固有機構としてではなく抽象構造 + インスタンス例の形で)。
- snapshot v2 への additive table (modifier / relation) と trace record kind の追加。

Why now: v1.1 の凍結契約が全て実装済みで、queue が空 (需要待ち) の状態に最初の確定需要が届いたため。責務の線引き (EQM = 状態・関係・順序・トリガ意味論 / ゲーム側 = 空間述語と効果実行 / EBS = スキル記述と型検査) は依頼文書で合意済み。

Layer note: 本 phase は全て L2/L3 拡張であり、L0/L1 surface への非漏出 (§3.1) を維持する。メタレベル・関係グラフ・変換フックはいずれも opt-in。

### Phase 14 — Consumer-driven runtime performance evidence *(additive, 2026-07-18)*

Purpose: Amberground から得た実行規模の情報を、GAME 上限や意味論変更へ変換せず、EQM 内で再現可能な runtime 改善へ落とす。

Produces:

- correctness / serialization の回帰証拠と排他的に実行される performance test lane。
- `EQTriggerIndex` の production `EQTriggerEngine` への透明な統合。
- wall-clock だけに依存しない deterministic work-count gate と、環境情報付きの時間測定。
- arm / fire / rumination / expiry / disarm / actor invalidation / save-load を跨ぐ parity proof。
- 残存 hot path を測定結果とともに記録し、次の最適化は evidence がある場合だけ queue 化する規律。

Adopted principles:

- 通常回帰は correctness / order / lifecycle / serialization を所有し、速度閾値を所有しない。
- performance lane は通常回帰と同時収集せず、独立 command で明示実行する。
- index は候補 filter であり、最終判定は従来どおり `condition.matches()` が所有する。
- index / expiry cache は armed table から再構築可能な派生状態であり、snapshot の第二の真実にしない。

Rejected / deferred:

- consumer が index を別管理する API。
- engineering rung を gameplay cap として扱うこと。
- event-line、relation、scheduler、native backend を同じ task で一括最適化すること。各 hot path は計測後に個別判断する。

Why now: EQM-134 が consumer-informed work scale と既知 hot path を確立し、EQM-102 の target index は parity proof 済みだが production engine に未接続で、queue が空になっているため。

Layer note: L2 内部最適化。既存 caller API、snapshot schema、trace semantics、L0/L1 surface は変更しない。

### Phase 15 — Evidence-driven runtime hardening *(additive, 2026-07-18)*

Purpose: Phase 14 の実測と EBS integration 再検証で見つかった correctness gap と
選択性依存の性能退行を、契約境界から順に閉じる。性能改善より先に ghost arm と
false-green を排除し、その後は EQM 内で再現できた hot path だけを個別 task として
最適化する。

Produces:

- `reaction_condition` を `EQCondition | null` に限定する fail-closed submit/arm 契約と、
  dev/shipped の構造化 rejection proof。
- target bucket と wildcard bucket の既存順序を利用した stable linear merge。候補が
  wildcard-heavy でも不要な全候補 sort を行わない。
- relation graph の既存 actor adjacency を production query/expand/invalidation へ接続し、
  canonical relation table と relation-id 順を維持したまま全表走査を除く。
- event-line polling を watched 集合へ限定し、effective rate の派生 cache を canonical
  modifier state から再構築可能な形で管理する。
- consumer integration の誤契約は consumer repo 自身で修正・文書化し、EQM は consumer
  test や timing を自身の oracle にしない。

Adopted principles:

- `EQConditionSpec` (pending solve/invalidation) を trigger matcher の互換入力として扱わない。
- invalid input は status/index/scheduler/expiry を一切変えず、明示的に拒否する。
- armed table、relation table、event-line data が canonical。index/cache は派生状態に限る。
- elapsed は環境付き advisory。correctness、順序、work-count は通常回帰または portable
  performance gate で別々に証明する。

Rejected / deferred:

- transient `Callable` を暗黙に serializable named trigger へ昇格する互換層。
- wildcard-heavy の退行を平均値で隠すこと。
- scheduler backend、trace retention、consumer frame rateを本 phase の完了条件へ混ぜること。

Why now: EQM-136 の follow-up benchmark が通常 fixture で約 5.1 倍の改善を示す一方、
wildcard 25% 以上で退行を実測した。また EBS 再検証により、誤った reaction condition が
GUT の成功表示を通過して ghost arm を作る契約欠陥が判明した。correctness boundary を
先に直すことで、後続の性能値を信頼できる状態にする。

Layer note: L2/L3 runtime contract と内部派生 index の hardening。正常入力の trace、
snapshot schema、L0/L1 surface は不変。

## 8. Milestones

| Milestone | Main value | Included phases |
|---|---|---|
| v0.1 Core MVP | Fixed round / CTB turn order works in a scene. | Phase 0-3 |
| v0.2 Time Models | Energy and Wait Turn models work. | Phase 4 |
| v0.3 Reservation MVP | Immediate/prepared/wait/ready reservations work. | Phase 5 |
| v0.4 Reaction & Rollback | Reaction preparation, rumination, rollback, deterministic prediction. | Phase 6-7 |
| v0.5 Presentation Control | Important/sensed/offscreen visual flush semantics. | Phase 8 |
| v0.6 Dogfood Slice | Runtime timeline HUD and a real consumer slice prove API ergonomics. | Phase 9 (HUD, dogfood) |
| v0.7 Godot Tooling | Editor timeline/debug/config workflows. | Phase 9-10 |
| v0.9 Demo & Docs | Multiple genre demos and manual coverage. | Phase 11 |
| v1.0 Release Candidate | Performance, packaging, release proof. | Phase 12 |
| v1.2 EBS Extension | 状態・関係サブシステム、メタレベル介入、変換フック (queue Phase 12 として実行予定)。 | Phase 13 |
| Consumer Runtime Performance | Production trigger sweep has measured work reduction with unchanged order, trace, API, and save continuation. | Phase 14 |
| Runtime Performance Hardening | Invalid reaction inputs fail closed and measured trigger/relation/event-line hot paths improve without changing deterministic semantics. | Phase 15 |

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
- A dogfood consumer slice built only on the public API ships with its own golden trace and friction report.
- The L0/L1 simple turn-order path is usable without touching reservations or event-lines, and the API surface gate proves no L3 leakage into it (§3.1).
- Prediction can evaluate hypothetical branches (act-now vs wait) without mutating live state, supporting AI and player planning.
- In shipped resilient mode, injected runtime anomalies skip-and-log instead of crashing, while normal-input traces stay byte-identical across modes (`RUNTIME_RESILIENCE_POLICY.md`).
- Production trigger matching evaluates only target-bucket + wildcard candidates while preserving exact occurrence order, lifecycle state, trace, and save/load continuation.
- Runtime performance evidence separates deterministic work-count gates from environment-sensitive wall-clock measurements and never turns an engineering rung into a gameplay cap.
- Invalid reaction-condition inputs cannot create ghost arms or false-green integration runs, and wildcard-heavy trigger workloads no longer pay an avoidable full candidate sort.

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
