extends RefCounted
## EQM-082: moving-target consistency barrier in EQPresentationBuffer.
## Barrier: when enqueuing E, pending events whose changes_position_of intersects
## E.depends_on are flushed first — precise tracking (not flush-all).

const EQPresentationPolicy := preload("res://addons/event_queue_manager/resources/eq_presentation_policy.gd")
const EQPresentationBuffer := preload("res://addons/event_queue_manager/runtime/eq_presentation_buffer.gd")
const EQPresentationEvent := preload("res://addons/event_queue_manager/runtime/eq_presentation_event.gd")
const EQEffectRecord := preload("res://addons/event_queue_manager/runtime/eq_effect_record.gd")
const EQEffectChunk := preload("res://addons/event_queue_manager/runtime/eq_effect_chunk.gd")


static func _make_buf() -> EQPresentationBuffer:
	return EQPresentationBuffer.new(EQPresentationPolicy.new())


static func run(t) -> void:
	_test_selective_barrier_flush(t)
	_test_no_dependency_no_flush(t)
	_test_barrier_then_classification(t)
	_test_barrier_neutrality(t)
	_test_ordering_preserved(t)


static func _test_selective_barrier_flush(t) -> void:
	var buf := _make_buf()
	# ev1 moves "orc", ev2 moves "troll" — both deferred (sensed)
	var ev1 := EQPresentationEvent.new(&"orc", Vector2(1, 0), &"sensed")
	ev1.changes_position_of = [&"orc"]
	var ev2 := EQPresentationEvent.new(&"troll", Vector2(2, 0), &"sensed")
	ev2.changes_position_of = [&"troll"]
	buf.enqueue(ev1)
	buf.enqueue(ev2)
	t.eq(buf.pending().size(), 2, "both events deferred before barrier")

	# New event depends on "orc" — should barrier-flush ev1 only
	var ev3 := EQPresentationEvent.new(&"hero", Vector2.ZERO, &"sensed")
	ev3.depends_on = [&"orc"]
	buf.enqueue(ev3)

	var pend: Array = buf.pending()
	var fl: Array = buf.flushed()
	t.eq(fl.size(), 1, "barrier flushed exactly 1 event (the orc mover)")
	t.eq((fl[0] as EQPresentationEvent).actor_id, &"orc", "orc-mover flushed first")
	t.eq(pend.size(), 2, "troll-mover and hero remain pending (hero = deferred sensed, troll = unrelated)")
	# Confirm the troll-mover is still in pending (not the orc-mover)
	var pending_ids: Array = pend.map(func(e): return (e as EQPresentationEvent).actor_id)
	t.ok(pending_ids.has(&"troll"), "troll-mover still pending (not affected by orc barrier)")
	t.ok(pending_ids.has(&"hero"), "incoming hero event deferred after barrier")


static func _test_no_dependency_no_flush(t) -> void:
	var buf := _make_buf()
	var ev1 := EQPresentationEvent.new(&"orc", Vector2.ZERO, &"sensed")
	ev1.changes_position_of = [&"orc"]
	buf.enqueue(ev1)
	t.eq(buf.pending().size(), 1, "orc-mover deferred")

	# Event with no depends_on — barrier should not fire
	var ev2 := EQPresentationEvent.new(&"hero", Vector2.ONE, &"sensed")
	# depends_on defaults to [] — no barrier
	buf.enqueue(ev2)
	t.eq(buf.flushed().size(), 0, "no barrier flush when depends_on is empty")
	t.eq(buf.pending().size(), 2, "both events still pending")


static func _test_barrier_then_classification(t) -> void:
	var buf := _make_buf()
	var ev_mover := EQPresentationEvent.new(&"orc", Vector2(1, 0), &"sensed")
	ev_mover.changes_position_of = [&"orc"]
	buf.enqueue(ev_mover)

	# Incoming important event that also depends on "orc":
	# barrier fires first (flushes ev_mover), then the important classification fires (flushes remaining pending + self)
	var ev_important := EQPresentationEvent.new(&"hero", Vector2.ZERO, &"important")
	ev_important.depends_on = [&"orc"]
	buf.enqueue(ev_important)

	var fl: Array = buf.flushed()
	t.eq(fl.size(), 2, "barrier flushed orc-mover; important classification emitted self (total 2)")
	t.eq((fl[0] as EQPresentationEvent).actor_id, &"orc", "orc-mover flushed first (barrier)")
	t.eq((fl[1] as EQPresentationEvent).actor_id, &"hero", "important event follows (classification)")
	t.eq(buf.pending().size(), 0, "no pending remaining")


static func _test_barrier_neutrality(t) -> void:
	# Barrier flushes only move PresentationEvents; EQEffectChunk contents are unchanged.
	var chunk := EQEffectChunk.new()
	var r := EQEffectRecord.new(&"damage", &"orc", &"hp", -5)
	r.classification = &"sensed"
	chunk.add(r)

	var buf := _make_buf()
	var ev_mover := EQPresentationEvent.new(&"orc", Vector2.ZERO, &"sensed")
	ev_mover.changes_position_of = [&"orc"]
	buf.enqueue(ev_mover)

	# Barrier fires
	var ev_dep := EQPresentationEvent.new(&"hero", Vector2.ONE, &"sensed")
	ev_dep.depends_on = [&"orc"]
	buf.enqueue(ev_dep)

	# Simulation truth is untouched
	var recs: Array = chunk.drain()
	t.eq(recs.size(), 1, "simulation chunk has 1 record (neutrality: barrier did not alter chunk)")
	t.eq((recs[0] as EQEffectRecord).delta, -5, "delta unchanged by barrier")


static func _test_ordering_preserved(t) -> void:
	var buf := _make_buf()
	# Three events that all move "orc" — different actors so no coalescing
	var ev_a := EQPresentationEvent.new(&"orc_1", Vector2(1, 0), &"sensed")
	ev_a.changes_position_of = [&"orc"]
	var ev_b := EQPresentationEvent.new(&"orc_2", Vector2(2, 0), &"sensed")
	ev_b.changes_position_of = [&"orc"]
	var ev_c := EQPresentationEvent.new(&"orc_3", Vector2(3, 0), &"sensed")
	ev_c.changes_position_of = [&"orc"]
	buf.enqueue(ev_a)
	buf.enqueue(ev_b)
	buf.enqueue(ev_c)
	t.eq(buf.pending().size(), 3, "three orc-movers deferred")

	# Barrier fires for all three
	var ev_dep := EQPresentationEvent.new(&"hero", Vector2.ZERO, &"sensed")
	ev_dep.depends_on = [&"orc"]
	buf.enqueue(ev_dep)

	var fl: Array = buf.flushed()
	t.eq(fl.size(), 3, "all three orc-movers barrier-flushed")
	t.eq((fl[0] as EQPresentationEvent).actor_id, &"orc_1", "insertion order preserved: first flushed is orc_1")
	t.eq((fl[1] as EQPresentationEvent).actor_id, &"orc_2", "orc_2 second")
	t.eq((fl[2] as EQPresentationEvent).actor_id, &"orc_3", "orc_3 third")
