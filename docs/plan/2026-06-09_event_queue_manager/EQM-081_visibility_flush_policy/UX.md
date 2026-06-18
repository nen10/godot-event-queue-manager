# EQM-081 UX

## Inputs accepted (narrowed per UX_PATH_REDUCTION_POLICY)

- `EQPresentationPolicy`: a Godot Resource. Slots: `immediate_classes`, `skip_classes`
  (both `Array[StringName]`); `flush_on_player_turn` (bool). Validate before use.
- `EQPresentationBuffer.enqueue()`: accepts `EQPresentationEvent` only.
- Unknown classification (not in immediate_classes or skip_classes): deferred/coalesced — no
  silent drop, no crash. This is the safe default for consumer-defined classifications.

## Rejection

- Policy with a class in both `immediate_classes` and `skip_classes`:
  `validate()` → `PRESENTATION_POLICY_CLASS_CONFLICT` (ERROR severity).
