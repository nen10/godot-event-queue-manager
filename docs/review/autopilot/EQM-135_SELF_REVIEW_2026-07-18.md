# EQM-135 Self Review — reservation meta intervention

date: 2026-07-18 / pattern: dynamic consumer follow-up + additive L2 primitive

## Outcome

PASS. `intervene_reservation(event_id, intervener)` now closes one ordinary scheduled PREPARED singleton before its effect, without reusing or changing explicit-window semantics. The comparison uses a reservation-instance value sampled once at accepted submission.

## Acceptance check

- [x] **Success / tie**: equal-or-greater intervener meta succeeds; the scheduler and runtime pending table lose the target together, status becomes `INVALIDATED`, and its effect never runs.
- [x] **Avoid**: lower meta is normal gameplay, emits `intervention_avoided`, and leaves scheduler snapshot, reservation save state, and pending status unchanged.
- [x] **Trace**: success emits one immediate `event_invalidated` with `closed_by: intervention`, target event/actor, both meta values, and optional intervener event id; it precedes later unrelated resolution.
- [x] **Fail-closed scope**: unknown id, wrong kind, bundle member, race member, and reaction FIRE occurrence return the stable `eqm.reservation.intervention_invalid` fault without state mutation.
- [x] **Issuance sampling**: accepted submit fixes meta once. Runtime event views and causal provenance read that issued value rather than a later declaration value.
- [x] **Checkpoint**: schema v7 requires `issued_meta_level` on every serialized reservation. v1-v6 migrate from inline definition meta and reject a differing value those formats cannot represent.
- [x] **Compatibility**: `intervene_close`, window lifecycle, tick freeze, comparator, bundle/race/FIRE semantics, and existing deterministic trace fixtures remain unchanged.

## Review findings and repairs

1. Reading `definition.meta_level` at intervention time would let later authoring mutation rewrite pending work. The sample now lives on the reservation instance and is bound only after submit preflight succeeds.
2. Persisting a possibly different issued value under schema v6 would let a v6 reader silently ignore it. The save bundle was therefore bumped to schema v7 with verify-before-mutate migration/rejection rules.
3. Bundle planning can roll back after partially scheduling members. Its rollback journal now restores the pre-submit issuance sample alongside the existing effect-handler bindings.
4. Successful cancellation validates scheduler liveness before mutation, then removes scheduler, pending, window-membership, bound-condition, and reaction-context links before tracing the invalidation.

## API golden approval

`python3 tools/check_api_surface.py --update` explicitly re-baselined only:

- `EQReservationRuntime.intervene_reservation(event_id, intervener) -> bool`
- `EQError.RESERVATION_INTERVENTION_INVALID`
- `EQError.RESERVATION_ISSUED_META_LEVEL_INVALID`

No deterministic trace golden changed. The new trace order and fields are asserted structurally in `test_eq_reservation_intervention.gd`.

## Verification

- `./tools/test.sh`
  - run id: `20260718-040730-15535`
  - result: PASS
  - files: 74
  - checks: 1,682
  - failures: 0
- API surface: documented and explicitly re-baselined; no L3 leak.
- Contract coverage: 34/34 implemented, no violations.
- `git diff --check`: PASS.

The first sandboxed run could not create Godot's `user://logs` path and the engine aborted before tests; the same standard command was rerun with user-data write access and passed. No repair-now item remains.

## Follow-up boundary

Bundle/race/reaction-FIRE intervention generalization is demand-gated. Interception damage, sensing/range, target selection, presentation, and future game-side meta corrections remain consumer-owned. A future issued meta value that differs from the definition can use the same runtime API and schema-v7 field.
