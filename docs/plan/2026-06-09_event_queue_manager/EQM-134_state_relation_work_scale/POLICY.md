# EQM-134 POLICY — state/relation engineering work scale

## Adopted contract

- State, relation, trigger, expiry, and scheduler counts are independent
  engineering axes, not gameplay slots.
- EQM publishes a reproducible green regression rung.  It never silently
  truncates above that rung; a consumer-owned defensive cap must fault
  deterministically and be versioned separately from gameplay cost.
- `state_inv` is an involutive one-shot transform per declaration and resolved
  effect.  It does not participate as an endlessly repeatable fixed-point
  rewrite.
- Strengthening, weakening, neutral, visibility, and relation meaning remain
  consumer-owned.  EQM receives only opaque state/relation tokens and rules.

## Rejected

- Reusing actor 200, trigger 200, or Amberground state 64 as a gameplay state
  limit.
- Increasing the generic transform-round guard to hide `state_inv` oscillation.
- Claiming latency support beyond the exact test rung.

## Acceptance

- Default-round `state_inv` changes A to B exactly once and emits no fault.
- 64 algebraic state tokens per actor across 8 actors, 1,024 relation edges,
  and 200 actual matching triggers pass deterministic round-trip/count gates.
- Standard test suite and existing trace goldens remain green.
