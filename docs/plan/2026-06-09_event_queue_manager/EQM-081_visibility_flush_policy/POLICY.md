# EQM-081 Policy

## Flush rules (per Phase 8 approved plan, decision 3)

| classification | behavior |
|---|---|
| in `immediate_classes` (default: `important`) | flush all pending priors into flushed, then emit self |
| in `skip_classes` (default: `offscreen`) | discard — no visual; simulation record untouched |
| everything else (incl. `sensed` by default) | defer into pending queue; coalesce same-target (replace prior) |
| player-turn boundary | flush all pending if `flush_on_player_turn = true` |

## Presentation-neutrality invariant

- `EQPresentationBuffer.enqueue()` and `flush()` NEVER write to EQEffectRecord, EQEffectChunk, or the trace.
- The buffer and policy operate on PresentationEvents only.
- The property test verifies: two different policies → identical simulation trace, different flushed output.
