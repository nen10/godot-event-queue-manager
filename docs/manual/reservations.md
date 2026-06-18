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
    # `fired` is the reservation whose condition matched — resolve the counter here
    pass
```

`rumination` controls how many times the same armed reaction may fire before it is
spent; `duration` (or `DURATION_UNLIMITED`) controls how long it stays armed by tick.

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
