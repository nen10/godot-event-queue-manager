# State / Relation Engineering Work Scale

Status: **version 1 / regression-tested engineering profile** (2026-07-16).

This profile records a reproducible scale at which EQM state algebra,
relations, triggers, and serialization must remain correct.  These numbers are
**not gameplay caps, equipment slots, or balance defaults**.  A consuming game
owns those meanings independently.

## Verified v1 rung

| axis | verified scale | exercised path |
|---|---:|---|
| algebraic state tokens | 64 per actor × 8 actors | 32 inverse pairs, signed CANCEL axes, grant, exact line/algebra round-trip |
| state wrappers | 16 per actor × 8 actors | serializable wrapper stacks and exact restore |
| relation graph | 1,024 directed GRAPH edges over 200 actor IDs | bind, one-hop bounded expand, exact graph restore |
| armed reactions | 200 simultaneously matching declarations | actual linear `EQTriggerEngine` arm and resolution |
| watched event-lines | 300 | existing sparse-poll regression profile |
| actor sweep | 200 | existing registered-sweep regression profile |
| scheduler backend | 10,000 insertions and removals | existing binary-heap parity and throughput profile |

The executable proof is
`test_project/tests/performance/test_eq_state_relation_work_scale.gd`, together
with the pre-existing event-line, trigger-index, and scheduler performance
tests.  `./tools/test.sh` runs all of them.

## Meaning of the numbers

- Passing a rung records deterministic correctness, serialization continuity,
  and a coarse regression budget on the current CI-class environment.
- It does not authorize silent truncation above the rung.  A caller that needs
  a defensive work cap declares its own versioned realization profile and must
  return a deterministic fault on overflow.
- `max_transform_rounds`, `max_cascade_rounds`, and window depth are runaway
  guards.  They are not state-instance or relation-slot limits.
- Gameplay cost and engine work are separate namespaces.  Increasing the
  number of states must not invent AP/MP cost, and cheaper content must not
  bypass a finite engine work budget.
- Passive equipment, unary state manifestations, relation instances, armed
  reactions, expiry reservations, and event-lines are separate axes.  A game
  must not derive one capacity from another.

## Known hot paths and next ladder

The current profile deliberately exposes, rather than hides, these scaling
risks:

- the production trigger engine still scans every armed reaction;
- event-line polling sorts the complete line set before selecting watched IDs;
- relation expansion and maintenance scan the relation table;
- the default scheduler remains the sorted-array backend.

The next evidence ladder is 128 state tokens per actor across 16 actors, 2,048
relation edges, 400 armed reactions, expiry churn, and full save-adapter round-trip.  It is a
future engineering task, not an implicit promise or a reason to cap gameplay at
the v1 rung.

## Inversion safety

`state_inv` is an involutive one-shot transform for one resolved effect.  The
same declaration runs at most once during that effect's transform chain;
otherwise a dual pair would oscillate until the general transform-round guard
faulted.  Distinct inversion declarations still run once each in deterministic
transform order.  Game-specific strengthening/weakening/neutral classification
does not belong to EQM and must be validated by the consuming game's exact
semantic catalog before lowering opaque state tokens here.
