# Reservations

A **reservation** is an event with an action-intent field — an action that is
*prepared*, *reacting*, *waiting*, *ready*, or *operating on a target* rather than
resolving immediately. This is L2; the simple turn-order path (L0/L1) never needs it.

Classes: `EQActionDefinition` (the intent), `EQReservation` (the live instance),
`EQTriggerEngine` + `EQCondition` (arming + firing). All public API; examples below
use it directly (no sample resource is assumed).

---

## 1. EQActionDefinition.Kind

```text
IMMEDIATE              resolves now (delay 0)
PREPARED               resolves after `delay` ticks (preparation)
REACTION_PREPARATION   armed for `duration`; fires on a matching event (a counter/interrupt)
WAIT                   ends the turn; schedules a READY reservation
READY                  the turn-grant after AP recovery (see action_resolution.md)
OPERATION              causes a reservation on the target (operate-on-target)
```

Fields:

```text
kind                 EQActionDefinition.Kind
delay                ticks before a PREPARED action resolves
duration             ticks a REACTION_PREPARATION stays armed; DURATION_UNLIMITED (-1) = no tick deadline
rumination           extra times a reaction may fire after the first (0 = fires once)
tags                 StringName tags carried by the action
operation_target_tag for OPERATION: which target the reservation lands on
```

`EQActionDefinition.validate()` returns an `EQValidation`; an inconsistent definition
(e.g. a negative delay, or a duration on a non-reaction) is an explicit error, never
a silent default.

## 2. EQReservation

```gdscript
var def := EQActionDefinition.new()
def.kind = EQActionDefinition.Kind.REACTION_PREPARATION
def.duration = EQActionDefinition.DURATION_UNLIMITED
def.rumination = 1            # may counter twice (first + 1)
def.tags = [&"counter"]

var reservation := EQReservation.new(&"hero", def)   # actor_id + intent
```

`EQReservation.Status` moves `PENDING → ARMED → RESOLVED | INVALIDATED`. A
reservation is serializable (`to_dict` / `from_dict`) and carries no live Node.

## 3. Arming and firing a reaction

`EQTriggerEngine` arms a reservation behind an `EQCondition` and fires the matching
ones when an event resolves at a sweep point.

```gdscript
var trigger := EQTriggerEngine.new()

var cond := EQCondition.new()
cond.match_target = &"hero"        # the reaction watches incoming events on hero
cond.require_tags = [&"damage"]    # ...tagged damage

trigger.arm(reservation, cond, 0)  # arm at tick 0

# later, when an attack on hero resolves (the sweep point):
var view := {"kind": &"hit", "source": &"orc", "target": &"hero", "tags": [&"damage"]}
for fired in trigger.on_event_resolved(view, current_tick):
    # Standalone engine compatibility projection: the matching armed reservation.
    pass
```

`rumination` controls how many times the same armed reaction may fire before it is
spent; `duration` (or `DURATION_UNLIMITED`) controls how long it stays armed by tick.

In the reservation pipeline, matching never resolves in place. Each match creates
an independent scheduled FIRE reservation. Its handler view contains
`reaction_fire_context` version 1, including `fire_event_id`, 1-based
`fire_index`, and the triggering event id/tick/view/source/target/cell plus the
open consumer event-view copy. Read a pending copy with
`reaction_fire_context_for_event(event_id)`. The armed slot remains separate so
remaining uses and expiry survive a pending FIRE and a save/load boundary.

## 4. Worked example

The shipped demo `demos/action_resolution/demo_battle.gd` arms exactly this counter
(hero reacts to incoming damage, `rumination = 1`) on top of the AP-recovery loop,
using only the public API. It is the canonical, non-sample example — run
`DemoBattle.run_trace(8)` to see the reservation fire in the trace
(`reaction_fired` records).

## 5. Determinism

Reservations resolve through the same total-order comparator as plain events
(`(due_tick, priority, sequence)`), and firing is driven by resolved-event sweep
points — so a reaction's effect on order is deterministic and shows up in the
canonical trace. Removing the trace records never changes the outcome (see
`concepts.md` §2.3).

---

## Declarative conditions & closure (v1.1)

Since v1.1 a reservation can carry full condition sets (SEM §5.4–§5.6):

```text
solve_conditions          Array[EQConditionSpec] — AND, level-triggered; empty = no gate
invalidation_conditions   Array[EQConditionSpec] — OR; invalidation-wins on a tie
```

An `EQConditionSpec` is one serializable term: `LINE_THRESHOLD` (an event-line
value vs a threshold), `COUNTER` (a decremental use counter), or
`NAMED_PREDICATE` (a name registered via `runtime.register_predicate`; only the
NAME crosses a save). The `duration` / `rumination` fields above are **sugar**
over this: `duration` becomes the expiry closure, `rumination` the use counter.

The most common case therefore needs no spec at all — one checked-in `.tres`
declares a counterattack that closes on 3 uses OR 5 ticks, whichever first
(`dogfood/action_resolution/counterattack_preparation.tres`, zero script lines):

```text
kind = REACTION_PREPARATION
duration = 5          # OR-closure: 5 ticks (set -1 for deadline ∞)
rumination = 2        # OR-closure: 3 total uses
effect_name = &"counterattack"   # declared linkage — wired by register_effect
```

Every closure is explained in the canonical trace via `closed_by`:
condition ids you declared, or the reserved causes `duration`,
`reaction_count`, `already_closed`, `actor_removed`, `race_lost`.
Nothing closes silently.

## v1.2: state algebra, relations, interventions (EQM-121..127)

Declarations added by the EBS extension round (SEM v1.2). All are L2/L3 opt-in — with no declarations the runtime behaves exactly as before.

- **Inv pairs**: `EQStateAlgebra.declare_inv_pair(a, b, Rule.CANCEL | EXCLUDE | COEXIST)`; CANCEL keeps one signed axis per pair, so cancellation is arithmetic. Rate suspensions are modifiers (`add_rate_modifier(line, "override", 0)` = freeze); removing one restores the remaining effective rate automatically. Attach via `rr.state_algebra`; its save tables were introduced by schema v3 and remain in current schema v6.
- **Relations & rewrites**: declare relation types (`TREE`/`GRAPH`, `SERIAL_SUTURE` on dissolve), `bind` instances, then `declare_expansion_rule` (tag-gated target expansion along relations, cost-bounded) and `register_transform` (`retarget` to a provenance stage / `state_inv`). Transforms may apply repeatedly; validating the application structure is the consumer's job — the core guarantees deterministic order, per-application trace, and a bounded-rounds backstop.
- **Meta-level & interventions**: `EQActionDefinition.meta_level` (int, default 0) is carried by events and windows. `intervene_close(window_id, {"meta_level": n})` closes prematurely when `n >= window meta` (tie succeeds): resolved effects stay, pending members close with `closed_by: intervention`. `submit_bundle` resolves same-tick members atomically (single sweep after all members). `open_phase`/`close_phase` add sub-checkpoints inside a window; revisiting a phase name detects the minimal loop and rolls back to its start, tracing `cleared_inputs`.
- **Saving**: schema v3 introduced the `relations` / `state_algebra` tables used above; schema v4 added both effect-result mode bindings; schema v5 added the scheduled reaction-FIRE context. Current schema v6 retains them and adds `reaction_expiries`, so a duration event survives even after its armed slot closes by count. Loading verifies names, bindings, occurrence and expiry identity first and applies nothing on a stable error. A historical pending FIRE, or a historical orphan expiry whose reservation was never stored, is rejected rather than guessed; ordinary historical scheduled work and still-armed expiries migrate.
