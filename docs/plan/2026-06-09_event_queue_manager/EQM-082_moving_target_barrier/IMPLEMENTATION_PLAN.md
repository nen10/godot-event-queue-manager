# EQM-082 Implementation Plan

## Files

### Modified
- `addons/event_queue_manager/runtime/eq_presentation_buffer.gd` — add barrier check in enqueue(); add _barrier_flush(depends_on) helper

### New
- `test_project/tests/presentation/test_eq_moving_target_barrier.gd`

No new class_names → no API-surface / golden change needed.

## Barrier in enqueue() (extends EQM-081 logic)

```
func enqueue(event):
    # Step 0: barrier check (before classification dispatch)
    if not event.depends_on.is_empty():
        _barrier_flush(event.depends_on)
    # Step 1: classification dispatch (unchanged from EQM-081)
    ...

func _barrier_flush(depends_on):
    # collect pending events whose changes_position_of ∩ depends_on ≠ ∅
    # flush them in insertion order; leave others in pending
    var to_flush = []
    var remaining = []
    for ev in _pending:
        var conflict = ev.changes_position_of has any element in depends_on
        if conflict: to_flush.append(ev)
        else: remaining.append(ev)
    _pending = remaining
    _flushed.extend(to_flush)
```

## Tests (test_eq_moving_target_barrier.gd)

1. selective_barrier_flush — pending: ev1 moves "orc", ev2 moves "troll" (unrelated). New event depends_on "orc" → ev1 flushed; ev2 stays pending.
2. no_dependency_no_flush — event with empty depends_on enqueued; existing pending events unchanged.
3. barrier_then_classification — barrier fires, then the incoming event itself goes through normal classification (e.g. sensed → deferred after barrier).
4. barrier_neutrality — sim chunk contents unchanged after barrier flush (presentation neutrality holds).
5. ordering_preserved — multiple pending events all conflict; they flush in insertion order.
