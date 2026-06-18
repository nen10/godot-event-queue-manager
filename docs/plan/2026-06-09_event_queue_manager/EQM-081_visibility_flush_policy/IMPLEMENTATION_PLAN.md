# EQM-081 Implementation Plan

## Files

### New
- `addons/event_queue_manager/resources/eq_presentation_policy.gd` — EQPresentationPolicy (presentation layer Resource)
- `addons/event_queue_manager/runtime/eq_presentation_buffer.gd` — EQPresentationBuffer (presentation layer RefCounted)
- `test_project/tests/presentation/test_eq_presentation_buffer.gd`

### Modified
- `addons/event_queue_manager/runtime/eq_error.gd` — +PRESENTATION_POLICY_CLASS_CONFLICT
- `tools/check_api_surface.py` — LAYER_MAP +EQPresentationPolicy, +EQPresentationBuffer
- `docs/design/API_SURFACE.md` — presentation row updated
- `tests/golden/api_surface.json` — re-baselined via --update

## EQPresentationPolicy (Resource, presentation)

```
class_name EQPresentationPolicy extends Resource
@export var immediate_classes: Array[StringName] = [&"important"]
@export var skip_classes: Array[StringName] = [&"offscreen"]
@export var flush_on_player_turn: bool = true
func validate() -> EQValidation  # PRESENTATION_POLICY_CLASS_CONFLICT on overlap
```

## EQPresentationBuffer (RefCounted, presentation)

```
class_name EQPresentationBuffer extends RefCounted
func _init(policy: EQPresentationPolicy)
func enqueue(event: EQPresentationEvent) -> void
    # skip_classes → no-op
    # immediate_classes → flush pending first, emit self
    # else → defer; remove prior same-actor_id pending; append
func flush() -> void           # move all pending → flushed
func flush_player_turn() -> void  # flush if policy.flush_on_player_turn
func flushed() -> Array        # copy of emitted events
func pending() -> Array        # copy of pending deferred events
func clear_flushed() -> void
```

## Tests (test_eq_presentation_buffer.gd)

1. policy_default_classes — defaults: important=immediate, offscreen=skip, flush_on_player_turn=true
2. policy_validate_no_conflict — default policy passes validate()
3. policy_validate_conflict — class in both immediate+skip → PRESENTATION_POLICY_CLASS_CONFLICT
4. buffer_important_flushes_pending — sensed deferred; important flushes priors first
5. buffer_offscreen_skips — offscreen → no pending, no flushed
6. buffer_sensed_deferred_coalesced — two sensed for same actor → coalesced (latest position)
7. buffer_flush_player_turn — flush_player_turn empties pending → flushed
8. neutrality_property — two different policies → identical EQEffectRecord/chunk, different flushed output
