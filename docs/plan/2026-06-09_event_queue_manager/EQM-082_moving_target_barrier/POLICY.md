# EQM-082 Policy

## Moving-target barrier (Phase 8 approved plan, decision 4)

When `enqueue(E)` is called:
1. If `E.depends_on` is non-empty, check all pending events whose `changes_position_of` intersects `E.depends_on`.
2. Flush exactly those conflicting pending events (preserve their original insertion order); leave non-conflicting pending events in place.
3. Then apply the normal classification-based dispatch (immediate/skip/defer-coalesce) for E itself.

This is **precise dependency tracking** — not flush-all. A visual that moves entity X is only flushed when a new visual that depends on X is enqueued. Unrelated pending visuals remain deferred.

## Neutrality preservation

- Barrier flushes only move EQPresentationEvents between _pending and _flushed.
- EQEffectRecord / EQEffectChunk / trace: untouched. The property tests from EQM-081 continue to hold.

## No API-surface change

EQM-082 extends EQPresentationBuffer internally; no new public class_name. Golden re-baseline not required (surface unchanged). The `_barrier_flush` helper has a leading underscore → internal.
