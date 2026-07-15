# Action Resolution (AP-recovery turns)

`EQActionResolutionPolicy` (L1 policy, L2-aware) drives an action-point loop: each
actor recovers AP per tick and acts when it reaches `ap_max`. This chapter covers the
turn loop, **wait / ready / end-turn** semantics, and **rollback** via `EQTransaction`.

---

## 1. The policy

```text
ap_key          = &"ap"            per-actor AP field
recovery_key    = &"ap_recovery"   per-actor recovery per tick (falls back to recovery_per_tick)
ap_max          = 100              AP at which a turn is ready
recovery_per_tick = 10             default recovery when the actor has no recovery_key
action_ap_cost  = 100              AP spent when a finish reports no cost
```

Set per-actor recovery on the actor's data; faster actors reach `ap_max` sooner and
act more often.

## 2. The turn loop (manager-driven)

```gdscript
var config := EQConfig.new()
config.policy = EQActionResolutionPolicy.new()      # concrete policy, never a base instance

var manager := EQManager.new()
manager.configure(config)
manager.register_actor(&"hero").data["ap_recovery"] = 12
manager.register_actor(&"orc").data["ap_recovery"] = 9
manager.seed()

while true:
    var e = manager.step()                          # the next ready turn (or null)
    if e == null:
        break
    var actor: StringName = e.actor_id
    # ... resolve the actor's action (effects, reactions, visuals) ...
    manager.finish_action(actor, EQActionResult.new(100, 0))   # cost=100, delay=0
```

`EQActionResult.new(cost, delay)`: `cost` is AP spent (default-cost = `action_ap_cost`
when 0), `delay` shifts the next grant.

### 2.1 finish_action vs wait_close (read this)

`manager.step()` **suspends** the manager on the acted actor (`is_awaiting_turn()`
becomes true). Only `manager.finish_action(actor, result)` clears that suspend *and*
delegates to the policy to schedule the next ready turn.

Driving `policy.wait_close(runtime, actor, result)` directly on the runtime **does
not** clear the manager's suspend — in a manager-driven loop that deadlocks after one
turn. `wait_close` is for the **explicit-transaction flow** (you hold the runtime and
the transaction yourself), not the manager loop. This was a real dogfood friction
finding (`docs/review/DOGFOOD_FRICTION_2026-06-18.md`, F1):

```text
manager-driven loop      -> manager.finish_action(actor, result)
explicit-transaction flow -> policy.wait_close(runtime, actor, result, transaction)
```

## 3. Wait / ready / end-turn

The reservation kinds that shape the loop (see `reservations.md`):

- **WAIT** — ends the current turn early and schedules a **READY** reservation; the
  actor will be granted its next turn after AP recovery. `wait_close` performs this
  at the **wait/end-turn commit boundary** (the working changes are committed exactly
  at the turn close, EQM-071), so a half-applied wait can never be observed.
- **READY** — the turn-grant produced by the wait/AP recovery; resolving it hands the
  actor its turn. `EQActionResolutionPolicy.ready_reservation_for(runtime, actor_id,
  spent)` builds the READY reservation for an actor.

The order these resolve in is the same total order as any event — `(due_tick,
priority, sequence)` — so wait/ready never breaks determinism.

## 4. Rollback with EQTransaction

`EQTransaction` stages schedule changes on a **working copy** so an action can be
previewed and either committed or discarded with the live queue untouched.

```gdscript
var txn := EQTransaction.new(runtime.scheduler)   # working copy of the live scheduler
txn.draft_push(due_tick, priority, &"turn", &"hero")  # stage a scheduled event
txn.draft_cancel(some_event_id)                       # stage a cancellation

if txn.is_live_unchanged():
    pass                          # nothing staged yet
# decide:
txn.commit()                      # apply the working copy to the live scheduler
# or
txn.rollback()                    # discard; the live scheduler is exactly as before
```

Guarantees:

- `working()` is the staged scheduler; `draft()` lists staged events.
- `rollback()` leaves the live scheduler byte-identical to before the transaction —
  nothing partial is applied.
- `commit()` applies atomically; `is_committed()` reports it.

This is how "act now vs wait" previews, undo, and the wait/end-turn boundary are all
built on one working-copy primitive — no ad-hoc snapshotting in consumer code.

## 5. Worked example

`demos/action_resolution/demo_battle.gd` is the end-to-end, public-API-only slice:
AP turns via this policy, an armed counter (reservation + trigger), simulation
effects, flushed visuals, and a deterministic trace. It is the reference to copy
from — and it uses `manager.finish_action` (the manager-driven path) exactly as §2.1
prescribes.

---

## The L2 natural path (v1.1)

With the v1.1 pipeline (`EQReservationRuntime`, SEM §6.1) the wiring above
collapses into three declarations — this is the recommended shape once you use
conditions, reactions, or effects:

```gdscript
var rr := EQReservationRuntime.new()
rr.runtime.register_effect(&"counterattack", func(view): return [ ...EQEffectRecord... ])
rr.submit(load("res://.../counterattack_preparation.tres") as EQActionDefinition ...)
```

- **Declared linkage**: `effect_name` on the `.tres` names the handler; a set-but-
  unregistered name is a stable error (`eqm.effect.unregistered`) — never a silent skip.
- **One resolution cycle**: pop → effect → chunk → sweep → drain (`last_drained`).
  Between resolutions the chunk is empty, so `EQSaveAdapter.save(rr.runtime, rr)`
  succeeds exactly at the save boundary (`is_save_boundary()`; off-boundary saves
  are the stable error `eqm.save.blocked`).
- **Fired reactions are scheduled**, never resolved in place — the master timeline
  stays the only resolution authority, and every step is in the trace.

Use the transactional result v1 when one handler must publish external state
once and then expose several ordered event views at one outer sweep boundary:

```gdscript
rr.runtime.register_effect_commit(&"transactional", func(view):
    var candidate := EQEffectCommitResult.make_success(records, ordered_event_views)
    var validation := candidate.validate() # pure gate before the world swap
    if not validation.is_valid():
        return EQEffectCommitResult.make_failure({"code": "consumer.invalid_candidate"})
    commit_candidate_state_once()
    return candidate
)
```

Only SUCCESS appends records and sweeps its ordered views as one batch. FAILURE
has zero records and zero sweeps; inspect a deep-copy snapshot through
`last_effect_commit_outcome()`. Version 1 is limited to one reservation's main
effect and is explicitly rejected for atomic bundle members and
`expiry_effect_name`; those contexts retain the legacy Array handler contract.
The first accepted submit stores both handler modes on the reservation (0 legacy
/ 1 typed). Save/load and resolution verify those bindings, so changing a named
handler from legacy to typed or vice versa cannot reinterpret pending work; use
the stable `eqm.effect.commit_result_binding_mismatch` to surface that setup
error. Schema v1-v3 saves with no binding fields remain legacy.
Schema v4 introduced both binding fields and the current schema-v6 writer
retains them. Its reader
migrates missing fields only for schema v1-v3 bundles (to legacy 0); a v4
or newer reservation missing either field is rejected before load mutation with
`eqm.effect.commit_result_version_unsupported`. A v3 reader rejects the v4
bundle at the top-level version boundary, so it cannot silently ignore typed
bindings. The current reader also rejects any explicit nonzero binding under a
v1-v3 top-level version (`reason: binding_not_supported_by_schema`), so changing
only that version cannot bypass the boundary.

For a scheduled reaction FIRE, the handler view also carries
`reaction_fire_context` version 1. The context identifies the FIRE event and
1-based use, and preserves the exact trigger event id/tick/ordered view and its
consumer-owned value copy. Schema v5 saves this per scheduled row. Armed state
and pending FIRE are separate reservation instances; a historical pending FIRE
without a stored cause is rejected instead of being reconstructed from current
world state. Schema v6 retains that row context and also stores every live
reaction expiry independently from armed membership. This keeps the eventual
`closed_by: already_closed` event deterministic after count exhaustion and
save/load; a historical orphan expiry that cannot be reconstructed is rejected.

For consumers that need checkpoint or interleaving control at the exact master
timeline boundary, call `resolve_one_scheduled_event()`. It processes at most
one scheduler pop and returns `{advanced, event_id, event_kind, outcome,
reservation}`; an `EXPIRY` outcome never consumes the following reservation.
Continue using `resolve_next()` when expiry/invalidated/fault events should stay
internal and the next tracked reservation is the desired boundary.

An OPERATION target must be non-empty and registered when submitted. After that
valid issuance, an effect may remove an actor and still finish its current
records and outer sweep. EQM only cancels implicit future work that would
otherwise have an absent owner: non-reaction rumination resubmission and
OPERATION-caused target arms for a target that has since departed.
This guard does not define "defeated" for the game; keep an entity registered if
the game's defeat rules still need it to participate.

The hand-wired `run_trace()` in the dogfood slice predates this path and remains
as a contrast; `run_l2_trace()` in the same file is the natural-path reference.
