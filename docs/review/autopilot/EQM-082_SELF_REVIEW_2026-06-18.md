# EQM-082 Self-Review 2026-06-18

Pattern: P0 (orchestrator-direct). Repair: 0.

## Execution summary

Extended `EQPresentationBuffer.enqueue()` with the moving-target consistency barrier: before the classification-based dispatch, if the incoming event's `depends_on` is non-empty, `_barrier_flush()` flushes exactly the pending events whose `changes_position_of` intersects `depends_on` — in insertion order — leaving unrelated pending events untouched. This is precise dependency tracking (not flush-all, per Phase 8 approved plan, decision 4).

## Changed files

- `addons/event_queue_manager/runtime/eq_presentation_buffer.gd` — added `_barrier_flush()` helper; added barrier check at the start of `enqueue()`.
- `test_project/tests/presentation/test_eq_moving_target_barrier.gd` (new).
- `docs/plan/2026-06-09_event_queue_manager/EQM-082_moving_target_barrier/` (new plan dir).

No API-surface change (no new class_name; `_barrier_flush` is internal). Golden not re-baselined.

## Acceptance result — met

| acceptance | result |
|---|---|
| event depending on moved entity flushes prior visuals that move it | `_barrier_flush` selectively removes and emits conflicting pending events |
| event with no dependency does not force a flush | `depends_on.is_empty()` guard — barrier skipped entirely |
| non-conflicting pending events remain deferred | `remaining` list preserves unrelated events; only `to_flush` is moved |
| simulation trace unchanged by barrier flushes | EQEffectChunk only touched by EffectRecord accumulation; buffer never writes to it |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=36 checks=489 failures=0; [api-surface] ok
```

5 new barrier tests: selective flush (orc-mover flushed; troll-mover stays pending); no-dependency no-flush; barrier-then-classification (barrier fires, then important classification follows); neutrality (chunk unchanged); insertion-order preservation (3 orc-movers flushed in order).

## Design notes

- **Precise tracking preserves deferral** for unrelated visuals: a troll-movement event pending while an orc-dependent visual arrives stays in the deferred queue. Flush-all would break coalescing behavior for actors not involved in the dependency.
- **Barrier before classification**: the barrier fires unconditionally before the classification dispatch. This ensures that even if E itself is `important` (which would drain all pending anyway), the barrier has already semantically enforced the ordering constraint as a distinct step.
- **Insertion order**: `_pending` is iterated forward; `to_flush` is accumulated in order and appended to `_flushed` in the same order. The `remaining` list also preserves insertion order for non-conflicting events.

## Deviations

None.

## Repair-now / follow-up

None. Phase 8 complete (EQM-080 → EQM-081 → EQM-082). Next: **Phase 8/9 milestone checkpoint** — autonomous run pauses for user direction.
