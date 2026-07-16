# EQM-134 Self Review — 2026-07-16

## Outcome

PASS.  EQM now distinguishes a reproducible engineering work scale from any
consumer gameplay cap.  The v1 rung covers 64 algebraic state tokens per actor
across 8 actors, 128 serializable wrappers, 1,024 relation edges, and 200
simultaneously matching reactions.

## Review findings and repairs

1. `state_inv` was implemented as an unconstrained fixed-point rewrite.  A
   paired state therefore oscillated until `max_transform_rounds` faulted.
   The declaration is now one-shot for each resolved effect; distinct
   declarations retain deterministic order and each apply once.
2. Pair resolution rescanned every inverse-pair declaration for every state
   grant and query.  A deterministic state-to-pair index now preserves the
   prior duplicate-declaration fault behavior while removing the full scan
   from the hot path.
3. A cyclic multi-hop graph can grow path work independently of stored edge
   count.  The daily rung therefore proves one-hop traversal over the complete
   1,024-edge table.  Cyclic multi-hop expansion is explicitly retained as a
   separate next-ladder axis rather than hidden by a loose timing threshold.

## Compatibility and determinism

- No public method, resource schema, or snapshot version changed.
- The pair index is reconstructed from serialized declarations and is never
  serialized as competing truth.
- Work-scale overflow is not truncated.  Any consumer defensive budget must
  use its own versioned realization profile and deterministic fault.
- Strengthening, weakening, neutral, perception, and relation meanings remain
  consumer-owned; EQM continues to operate on opaque state/relation tokens.

## Verification

- `./tools/test.sh`
  - run id: `20260716-092734-47551`
  - result: PASS
  - files: 73
  - checks: 1,617
  - failures: 0
- API surface: unchanged and accepted.
- Contract coverage: 33/33 implemented, no violations.
- `git diff --check`: PASS.

No repair-now item remains.  Multi-hop cyclic relation expansion and the next
larger state/reaction rung are future measured optimization tasks, not gameplay
limits.
