# EQM-081 Self-Review 2026-06-18

Pattern: P0 (orchestrator-direct). Repair: 0.

## Execution summary

Built the presentation flush layer: `EQPresentationPolicy` (Resource — authoring flush rules: immediate_classes / skip_classes / flush_on_player_turn) and `EQPresentationBuffer` (runtime queue — enqueue with policy-driven immediate-flush/skip/defer-coalesce, flush(), flush_player_turn(), flushed()/pending()). Added `PRESENTATION_POLICY_CLASS_CONFLICT` error code (class appears in both immediate_classes and skip_classes). Key property: the buffer NEVER writes to EQEffectRecord/EQEffectChunk/trace — presentation neutrality.

## Changed files

- `addons/event_queue_manager/resources/eq_presentation_policy.gd` — `EQPresentationPolicy` (presentation): immediate_classes/skip_classes/flush_on_player_turn; validate() rejects class-in-both-lists.
- `addons/event_queue_manager/runtime/eq_presentation_buffer.gd` — `EQPresentationBuffer` (presentation): enqueue with policy rules; coalesce same-actor_id deferred events (keep latest); _drain_pending(); flush()/flush_player_turn()/flushed()/pending()/clear_flushed().
- `addons/event_queue_manager/runtime/eq_error.gd` — +PRESENTATION_POLICY_CLASS_CONFLICT (eqm.presentation.policy_class_conflict; RESOURCE_INVALID/ERROR).
- `tools/check_api_surface.py` (+EQPresentationPolicy, +EQPresentationBuffer to presentation layer).
- `docs/design/API_SURFACE.md` — presentation row updated.
- `tests/golden/api_surface.json` — re-baselined (presentation layer +EQPresentationPolicy/EQPresentationBuffer).
- `test_project/tests/presentation/test_eq_presentation_buffer.gd` (new).

## Acceptance result — met

| acceptance | result |
|---|---|
| important event flushes previous visuals | `immediate_classes` trigger _drain_pending() before self-emit |
| sensed non-important defers | deferred into _pending; same-actor_id coalesced (latest wins) |
| offscreen skips | `skip_classes` → return immediately; _flushed/_pending unchanged |
| player turn flush tested | flush_player_turn() respects flush_on_player_turn flag |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=35 checks=469 failures=0; [api-surface] ok
```

New tests: 8 checks in test_eq_presentation_buffer.gd. Neutrality property test confirmed: identical EQEffectChunk contents under two different policies; flushed output differs.

## API surface diff (golden re-baselined)

Added to `presentation` layer: `EQPresentationPolicy`, `EQPresentationBuffer`. New error code in `EQError` surface.

## Design notes

- **Coalescing**: when a deferred event arrives for an actor_id that already has a pending event, the prior is removed and the new event takes its place. This preserves order-of-insertion for other actors while ensuring the latest position snapshot is the one that gets displayed.
- **`flush_player_turn()` is a no-op when flush_on_player_turn = false** — the consumer can opt out of auto-flush by setting the flag.
- **Neutrality**: the buffer holds no reference to any EQEffectRecord or EQEffectChunk. These are passed in separately by the consumer (or adapter) and are never accessible to the buffer/policy. The neutrality property test proves this structurally.

## Deviations

None (built to the approved plan and IMPLEMENTATION_PLAN.md).

## Repair-now / follow-up

None. Next: EQM-082 (moving-target consistency barrier — precise dependency tracking in EQPresentationBuffer). Orchestrator-direct.
