# EQM-132 Self Review — reaction FIRE occurrence context v1

date: 2026-07-15 / pattern: P0 implementation + independent read-only design review

## Acceptance check

- [x] **Occurrence identity**: an armed reaction and every scheduled FIRE are separate `EQReservation` instances. Multiple matches receive distinct scheduler event ids and 1-based `fire_index` values.
- [x] **Cause transport**: one versioned JSON-safe value is captured before condition evaluation, then projected by deep copy to inspection, the effect handler, trace, and save/load. Expansion or retarget transforms cannot rewrite the trigger cause.
- [x] **Lifecycle**: only the armed slot owns remaining ruminations and expiry. Count closure is traced once; an intermediate FIRE leaves the arm live until duration closure.
- [x] **Checkpoint**: schema v5 writes `reaction_fire_context` on every scheduled row. Pending reaction FIRE rows require a valid cause bound to the same event id; historical pending FIRE rows reject rather than inventing a cause. Save-load-save and continuation are equal.
- [x] **Boundary**: EQM transports source/target/cell as opaque value data and introduces no relation between reaction count/duration and consumer AP/cost.
- [x] **Compatibility**: standalone `EQTriggerEngine.on_event_resolved()` remains as a projection of the new occurrence API. Ordinary historical scheduled rows migrate with an empty context.
- [x] **Gate**: `./tools/test.sh` — files=72, checks=1518, failures=0.

## Review notes

- Independent design review found that retaining the armed reservation as the scheduled instance would corrupt expiry, multi-FIRE identity, and checkpoint idempotence. The implementation therefore uses a fresh occurrence plus an event-id keyed context sidecar; no mutable `last_cause` mirror exists.
- Every `_by_event.erase` path was audited with the corresponding sidecar cleanup. Snapshot reconciliation also removes orphan context rows.
- `submit_bundle()` now rejects `REACTION_PREPARATION`, because a bundle member has no triggering occurrence from which a FIRE cause could be captured. This is an explicit contract rejection rather than a context-free scheduled reaction.
- No `repair-now` item remains.

## Golden diff approval

Explicitly re-baselined six affected traces:

- `authoring_counterattack`
- `fairness_bundle`
- `fairness_relation_chain`
- `focus_cost_counter_stop`
- `lifetime_composition`
- `mutual_counter_stop`

The event ordering, scheduler ids, priorities, and closure causes are unchanged. Each `reaction_fired` record now carries its exact version-1 context, and each resolved FIRE adds the corresponding `reaction_fire_resolved` record; later canonical `i` values shift only because those additive trace records are now present.

## Follow-up boundary

Reaction-chain fuel/cycle game policy, source-defeated meaning, refunds, typed expiry transactions, and editor presentation remain consumer-owned or deferred. None is required to preserve one FIRE occurrence and its cause.
