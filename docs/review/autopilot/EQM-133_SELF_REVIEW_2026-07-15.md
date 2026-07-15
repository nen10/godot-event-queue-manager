# EQM-133 Self Review — reaction-expiry checkpoint

date: 2026-07-15 / pattern: P0 repair + checkpoint continuation review

## Acceptance check

- [x] **Independent ownership**: schema v6 serializes every live scheduler expiry in sorted `reaction_expiries` rows, even when count exhaustion removed the armed slot.
- [x] **Strict verification**: expiry rows are a bijection with scheduler expiry events; actor, payload, reaction definition, duration, armed membership/status, remaining count, and matching armed value are checked before mutation.
- [x] **Identity restore**: a still-armed expiry and armed row reuse one restored `EQReservation` instance; a count-closed expiry restores its exact `RESOLVED` revision.
- [x] **Historical boundary**: v1-v5 still-armed expiry links migrate. A historical orphan expiry rejects with `eqm.reaction.expiry_state_invalid` rather than inventing reservation state.
- [x] **Continuation**: after two FIRE occurrences exhaust the arm, save-load-save is value-identical and FIRE/FIRE/expiry resolution has identical event identity, reservation values, cause views, and normalized trace including `closed_by: already_closed`.
- [x] **Exact boundary**: `resolve_one_scheduled_event()` processes at most one pop and distinguishes `EMPTY`, `EXPIRY`, `RESERVATION`, `INVALIDATED`, `FAULT`, and `UNTRACKED`; an expiry call leaves following work pending.
- [x] **Compatibility**: `resolve_next()` remains a wrapper that consumes expiry/invalidation/fault internally. Existing deterministic trace fixtures did not change.
- [x] **Gate**: `./tools/test.sh` — files=72, checks=1566, failures=0.

## Review notes

- The lost state was not the scheduled event itself; the scheduler already preserved it. The missing contract was the reservation revision keyed by that event after armed membership disappeared. Keeping a fake armed row would have changed trigger availability, so ownership was split instead.
- Cancelling the stale event was rejected because SEM §6.3 freezes its lightweight `already_closed` observation. The repair preserves game-neutral event meaning and introduces no count/AP/cost coupling.
- Verification deliberately compares complete armed/expiry reservation values. This avoids two serialized authorities drifting while load still reconstructs one live object.
- The exact-one-event method returns the same live reservation kind that `resolve_next()` already exposes. It adds an observable boundary without exposing `_expiry_by_event` or changing the compatibility method's stopping rule.
- No repair-now item remains.

## Golden diff approval

`python3 tools/check_api_surface.py --update` explicitly re-baselined only:

- `EQReservationRuntime.ScheduledEventOutcome`
- `EQReservationRuntime.resolve_one_scheduled_event() -> Dictionary`
- `EQError.REACTION_EXPIRY_STATE_INVALID`

No deterministic trace golden changed; the new continuation is asserted structurally in the focused test.

## Follow-up boundary

Expiry presentation, typed expiry transactions, and consumer game policy for defeated actors remain out of scope. They are not required for checkpoint fidelity or exact event interleaving.
