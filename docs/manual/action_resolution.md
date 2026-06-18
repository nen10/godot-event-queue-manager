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
