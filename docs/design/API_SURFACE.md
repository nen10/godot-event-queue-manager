# API Surface (v1)

status: authoritative for v1 (EQM-023, 2026-06-15). The public API surface, tagged by layer, gated by `tools/check_api_surface.py` against `tests/golden/api_surface.json`.

---

## 1. Public / internal convention

- **public** member: a `func` or `var` whose name has **no leading underscore**. `const` members are public when `UPPER_CASE`. `enum` / `signal` are public.
- **internal** member: a leading underscore (`_handle_fault`, `_binding`, `_META`). Not part of the surface; may change freely.
- Only files with a `class_name` contribute to the surface.
- Annotations are part of the public form: `@abstract func` and `@export var` are extracted; a signature change (param/return/var type) is a surface diff.

## 2. Layers (roadmap §3.1)

The user-facing surface is layered so a simple-path user never meets deep machinery. **An L3 symbol must not appear in an L0/L1 public signature** — the gate fails on such a leak.

| layer | meaning | classes |
|---|---|---|
| `core` | foundational infra below the user layers | EQEntry, EQOrdering, EQScheduler, EQBackend, EQSortedArrayBackend, EQBinaryHeapBackend, EQSnapshot, EQTrace, EQError, EQValidation, EQVersion, EQRng, EQEffectRecord, EQEffectChunk, EQEffectCommitResult, EQOrderExplanation |
| `L0` | turn order ("who acts next") | EQRuntime, EQActorRegistry, EQActorState, EQActionResult, EQManager, EQPrediction, EQSaveAdapter, EQNodeBridge |
| `L1` | policy selection | EQConfig, EQPolicy, EQFixedRoundPolicy, EQCTBPolicy, EQEnergyPolicy, EQWaitTurnPolicy |
| `L2` | reservation / prepared actions | EQActionDefinition, EQReservation, EQReservationRuntime, EQActionResolutionPolicy, EQCondition, EQTagMatcher, EQTriggerEngine, EQTransaction, EQTriggerIndex, EQConditionSpec (EQM-111), EQConditionEval (EQM-111), EQWindow (EQM-114), EQReactionFireContext (EQM-132) |
| `L3` | event-line internals | EQEventLines (EQM-112), EQStateAlgebra (EQM-121), EQRelationGraph (EQM-122) |

EQM-129 surface note: `EQRelationGraph.expand` (決定的 BFS の公開 helper — pipeline 2a と wrapper 連鎖が共用) / `EQStateAlgebra.relations` (optional 接続) / wrapper dict の optional `kind` (標準 2 種: inv_chain / relation_chain, SEM v1.2 §5.7)。

Transactional effect-result v1 surface note: `EQEffectCommitResult` is a core value contract with `make_success(records, event_views)` / `make_failure(diagnostic)`, `validate()`, and read-only projections. `EQRuntime.register_effect_commit(name, handler, result_version=1)` marks a named handler as typed while `register_effect` stays the legacy Array path; `effect_commit_result_version(name)` distinguishes them. `EQReservationRuntime.last_effect_commit_outcome()` returns a deep-copy value snapshot of the most recent single-reservation attempt. `EQReservation.effect_commit_result_version` / `expiry_effect_commit_result_version` are instance bindings: -1 before first submission, then frozen to 0 legacy or 1 typed. Save-bundle schema v4 introduced both fields for every serialized reservation; v4+ writers retain them, the reader migrates missing v1-v3 fields to legacy 0, rejects explicit nonzero bindings under v1-v3, and rejects a v4+ payload missing either field before mutation. Typed v1 is rejected for bundle and expiry contexts (SEM §6.1, §10.2).

EQM-132 reaction occurrence surface note: `EQReactionFireContext` validates and copies the version-1 JSON-safe cause value; `EQTriggerEngine.on_event_resolved_occurrences()` exposes 1-based fire indices while preserving the legacy reservation projection; `EQReservationRuntime.reaction_fire_context_for_event(event_id)` returns an isolated pending-FIRE context. The same value reaches the effect handler and save/trace projections. Save-bundle schema v5 requires the scheduled-row field and refuses to invent a cause for a historical pending FIRE (SEM §6.2, §10.3).

EQM-133 reaction-expiry checkpoint surface note: save-bundle schema v6 adds `reaction_expiries`, an event-id-keyed value table independent of armed membership. `EQReservationRuntime.ScheduledEventOutcome` and `resolve_one_scheduled_event()` expose one exact scheduler-pop boundary as `{advanced, event_id, event_kind, outcome, reservation}`; this makes an expiry observable without consuming the following reservation. Existing `resolve_next()` behavior is unchanged (SEM §6.3, §10.4).

EQM-135 reservation-intervention surface note: `EQReservationRuntime.intervene_reservation(event_id, intervener)` targets one ordinary scheduled PREPARED singleton. Reservation meta is sampled at accepted submission, persisted as `issued_meta_level` by save-bundle schema v7, and compared with tie-success semantics. Success invalidates without executing the effect; avoid keeps the target; unsupported group/context targets fail closed (SEM §8.3.1, §10.5).

EQM-141 reaction-gate surface note: `EQTriggerEngine.preview_event_resolved_occurrences()` returns non-mutating opaque candidate tokens (expired candidates are filtered without closing them); `commit_occurrence()` and `invalidate_occurrence()` accept only a still-current token and reject stale reuse. `armed_entries()` exposes `{reservation, condition, owner, armed_at, duration, authored_ruminations, remaining_ruminations, slot_id}`; `slot_id` is the exact engine-slot identity and is stable for that slot's armed lifetime, while the three lifecycle values are its arm-time/continuation snapshot. `on_event_resolved_occurrences()` remains the commit-all compatibility wrapper and applies standalone expiry. Save-bundle schema v8 persists arm-bound solve/invalidation state plus generated-counter provenance (SEM §6.2, §10.6). `EQError.CONDITION_COUNTER_SOLVE_UNSUPPORTED` makes the invalidation-only COUNTER authoring rule explicit.

EQM-142/143/144/145 scheduler hot-path surface note (Phase 15, 2026-07-19):

- **Consumer action required — none for EQM-142/143.** `EQScheduler.peek_next()` (live-peek fast path, EQM-142) and `reschedule()` (O(1) live-entry lookup, EQM-143) are pure internal performance changes: identical return values, ordering, trace `decided_by`, and snapshot behavior. Amberground needs no code change and should observe identical goldens.
- **New API — EQM-144.** `EQScheduler.has_event(event_id: int) -> bool` returns O(1) scheduler liveness (true only for live events; cancelled/rescheduled stale backend artifacts are invisible). Consumers that previously scanned `peek(size())` to test whether an event id is still scheduled should migrate to `has_event()`; `peek(n)` remains for ordered previews. This is a `core`/L0-visible additive method with no layer leak; the API surface golden is re-baselined for it under the explicit approval procedure.
- **New config — EQM-145.** `EQConfig.SchedulerBackend` and exported `scheduler_backend` add a setup-time backend choice: `SORTED_ARRAY = 0` (default / legacy .tres value) or `BINARY_HEAP = 1` (large-queue opt-in). Consumers such as Amberground should set `scheduler_backend = EQConfig.SchedulerBackend.BINARY_HEAP` on the project config **before** `EQManager.configure()` / seeding if they want heap behavior. Configuring a backend after live events exist records `eqm.runtime.scheduler_backend_reconfigure_nonempty` and keeps the existing scheduler. Unknown enum values produce `eqm.config.scheduler_backend_unknown`. Backend choice is not part of scheduler snapshots; save files remain portable across backends.

Ownership boundary: these mutation methods are the standalone `EQTriggerEngine`
surface. For an engine obtained as `EQReservationRuntime.engine`, they are
inspection-only to consumers; reaction commit/invalidate/disarm must occur through
the runtime pipeline so gate, declared-counter, watched-line, and expiry state
change atomically.

EQM-127 historical schema note: save-bundle schema_version 3 introduced the additive `relations` / `state_algebra` tables via optional `EQReservationRuntime.state_algebra` attachment; current schema v8 retains those tables unchanged (SEM v1.2 §10.1)。

EQM-126 surface note: `EQReservationRuntime.open_phase` / `close_phase` / `current_window` (操作フェーズ sub-checkpoint, SEM v1.2 §8.4)。

EQM-125 surface note: `EQReservationRuntime.intervene_close` (介入の標準効果) / `open_window` の `meta_level` 末尾 param / `EQWindow.meta_level` (SEM v1.2 §8.2–8.3)。

EQM-124 surface note: `EQReservationRuntime.submit_bundle` (atomic bundle 発行, SEM v1.2 §7.2)。

EQM-123 surface note: `EQReservationRuntime` gains `declare_expansion_rule` / `register_transform` / `max_transform_rounds` / `relations` (L2 面、引数は serializable Dictionary のみ); `EQReservation.provenance`, `EQActionDefinition.meta_level` / `state_name` は additive な宣言 field (SEM v1.2 §6.4–6.5, §8.2)。
| `presentation` | simulation/presentation split (must not leak into L0/L1) | EQPresentationEvent, EQPresentationPolicy, EQPresentationBuffer |
| `ui` | runtime/editor UI projections (must not leak into L0/L1) | EQTimelineHud, EQDebugOverlay, EQTimelineDock, EQDebugInspector, EQTemplateGenerator |

A public class absent from the layer map (`LAYER_MAP` in `tools/check_api_surface.py`) fails the gate: every public class must be assigned exactly one layer. Update this table and `LAYER_MAP` together.

## 3. The gate

`./tools/test.sh` runs `python3 tools/check_api_surface.py` (and `--self-test`). It fails when:

1. the extracted surface differs from `tests/golden/api_surface.json` (any undocumented API change);
2. a public class has no layer assigned;
3. an L3 class name appears in an L0/L1 public signature (layer leak).

`--self-test` verifies the leak detector on synthetic data every run, so the leak gate cannot silently rot before L2/L3 classes exist.

## 4. Updating the golden (explicit approval)

A surface change is deliberate. To re-baseline:

```sh
python3 tools/check_api_surface.py --update      # or: ./tools/test.sh --update-golden api_surface
```

Then record the diff and reason in the task's self-review. Never update on a normal run (mirrors DETERMINISM_TRACE_TEST_POLICY §2).

## 5. References

- Layering rationale: `ROADMAP.md` §3.1, `EVENT_MODEL_SEMANTICS.md` §2.2
- Determinism / golden approval: `docs/devflow/policy/DETERMINISM_TRACE_TEST_POLICY.md`
