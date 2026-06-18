class_name EQPresentationBuffer
extends RefCounted
## Queue of presentation events, drained according to an EQPresentationPolicy (EQM-081).
##
## Presentation-neutrality: this buffer NEVER writes to EQEffectRecord, EQEffectChunk, or the
## trace. The simulation truth is determined before enqueue() is ever called; the buffer only
## decides which visuals are shown, deferred, or skipped.
##
## Flush rules (per policy):
##   immediate_classes (default: "important") — flush all pending priors, then emit self.
##   skip_classes (default: "offscreen") — discard (no visual output; sim record unchanged).
##   all others — defer; coalesce by actor_id (keep only the latest pending per actor).

const EQPresentationEvent := preload("eq_presentation_event.gd")

var _policy: EQPresentationPolicy
var _pending: Array[EQPresentationEvent] = []
var _flushed: Array[EQPresentationEvent] = []


func _init(p_policy: EQPresentationPolicy) -> void:
	_policy = p_policy


## Enqueue an event; applies the moving-target barrier (EQM-082) then policy flush rules.
func enqueue(event: EQPresentationEvent) -> void:
	# Moving-target barrier: flush only the pending events whose changes_position_of
	# overlaps this event's depends_on — precise tracking, not flush-all (EQM-082).
	if not event.depends_on.is_empty():
		_barrier_flush(event.depends_on)

	var cls: StringName = event.classification
	if _policy.skip_classes.has(cls):
		return
	if _policy.immediate_classes.has(cls):
		_drain_pending()
		_flushed.append(event)
		return
	# Deferred/coalesced: remove prior pending for the same actor_id, then append.
	var i: int = _pending.size() - 1
	while i >= 0:
		if _pending[i].actor_id == event.actor_id:
			_pending.remove_at(i)
		i -= 1
	_pending.append(event)


## Move all pending events into flushed (explicit flush point).
func flush() -> void:
	_drain_pending()


## Flush pending if the policy requests it at a player-turn boundary.
func flush_player_turn() -> void:
	if _policy.flush_on_player_turn:
		_drain_pending()


## All events emitted since the last clear_flushed(), in deterministic order.
func flushed() -> Array:
	return _flushed.duplicate()


## Current deferred events (not yet flushed).
func pending() -> Array:
	return _pending.duplicate()


func clear_flushed() -> void:
	_flushed.clear()


func _drain_pending() -> void:
	for e: EQPresentationEvent in _pending:
		_flushed.append(e)
	_pending.clear()


## Flush exactly the pending events whose changes_position_of intersects depends_on.
## Non-conflicting pending events remain in place; insertion order is preserved.
func _barrier_flush(depends_on: Array[StringName]) -> void:
	var to_flush: Array[EQPresentationEvent] = []
	var remaining: Array[EQPresentationEvent] = []
	for ev: EQPresentationEvent in _pending:
		var conflict: bool = false
		for actor: StringName in ev.changes_position_of:
			if depends_on.has(actor):
				conflict = true
				break
		if conflict:
			to_flush.append(ev)
		else:
			remaining.append(ev)
	_pending = remaining
	for ev: EQPresentationEvent in to_flush:
		_flushed.append(ev)
