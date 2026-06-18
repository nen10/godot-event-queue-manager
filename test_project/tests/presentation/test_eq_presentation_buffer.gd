extends RefCounted
## EQM-081: EQPresentationPolicy + EQPresentationBuffer flush rules.
## Key property: flush-policy variation never alters the simulation truth
## (EQEffectRecord / EQEffectChunk) — only the flushed-visual output differs.

const EQPresentationPolicy := preload("res://addons/event_queue_manager/resources/eq_presentation_policy.gd")
const EQPresentationBuffer := preload("res://addons/event_queue_manager/runtime/eq_presentation_buffer.gd")
const EQPresentationEvent := preload("res://addons/event_queue_manager/runtime/eq_presentation_event.gd")
const EQEffectRecord := preload("res://addons/event_queue_manager/runtime/eq_effect_record.gd")
const EQEffectChunk := preload("res://addons/event_queue_manager/runtime/eq_effect_chunk.gd")


static func run(t) -> void:
	_test_policy_default_classes(t)
	_test_policy_validate_no_conflict(t)
	_test_policy_validate_conflict(t)
	_test_buffer_important_flushes_pending(t)
	_test_buffer_offscreen_skips(t)
	_test_buffer_sensed_deferred_coalesced(t)
	_test_buffer_flush_player_turn(t)
	_test_neutrality_property(t)


static func _test_policy_default_classes(t) -> void:
	var policy := EQPresentationPolicy.new()
	t.ok(policy.immediate_classes.has(&"important"), "default immediate_classes includes 'important'")
	t.ok(policy.skip_classes.has(&"offscreen"), "default skip_classes includes 'offscreen'")
	t.ok(policy.flush_on_player_turn, "flush_on_player_turn defaults to true")


static func _test_policy_validate_no_conflict(t) -> void:
	var policy := EQPresentationPolicy.new()
	var v := policy.validate()
	t.ok(v.is_valid(), "default policy validates without error")


static func _test_policy_validate_conflict(t) -> void:
	var policy := EQPresentationPolicy.new()
	# put 'offscreen' (which is in skip_classes) into immediate_classes too
	policy.immediate_classes = [&"important", &"offscreen"]
	var v := policy.validate()
	t.ok(not v.is_valid(), "class in both immediate and skip fails validation")
	t.ok(v.has_code(&"eqm.presentation.policy_class_conflict"),
		"PRESENTATION_POLICY_CLASS_CONFLICT code present")


static func _test_buffer_important_flushes_pending(t) -> void:
	var policy := EQPresentationPolicy.new()
	var buf := EQPresentationBuffer.new(policy)
	var e_sensed := EQPresentationEvent.new(&"orc", Vector2.ZERO, &"sensed")
	var e_important := EQPresentationEvent.new(&"hero", Vector2.ONE, &"important")
	buf.enqueue(e_sensed)
	t.eq(buf.pending().size(), 1, "sensed event is deferred (pending)")
	t.eq(buf.flushed().size(), 0, "nothing flushed yet")
	buf.enqueue(e_important)
	t.eq(buf.pending().size(), 0, "important event flushed all pending")
	t.eq(buf.flushed().size(), 2, "prior sensed and important are both flushed")
	var fl: Array = buf.flushed()
	t.eq((fl[0] as EQPresentationEvent).actor_id, &"orc", "prior (sensed) flushed first")
	t.eq((fl[1] as EQPresentationEvent).actor_id, &"hero", "immediate event follows priors")


static func _test_buffer_offscreen_skips(t) -> void:
	var policy := EQPresentationPolicy.new()
	var buf := EQPresentationBuffer.new(policy)
	buf.enqueue(EQPresentationEvent.new(&"shadow", Vector2.ZERO, &"offscreen"))
	t.eq(buf.pending().size(), 0, "offscreen produces no pending event")
	t.eq(buf.flushed().size(), 0, "offscreen produces no flushed event (visual skipped; sim record untouched)")


static func _test_buffer_sensed_deferred_coalesced(t) -> void:
	var policy := EQPresentationPolicy.new()
	var buf := EQPresentationBuffer.new(policy)
	var e1 := EQPresentationEvent.new(&"orc", Vector2(1, 0), &"sensed")
	var e2 := EQPresentationEvent.new(&"orc", Vector2(2, 0), &"sensed")
	buf.enqueue(e1)
	t.eq(buf.pending().size(), 1, "first sensed event deferred")
	buf.enqueue(e2)
	t.eq(buf.pending().size(), 1, "second sensed for same actor coalesces (replaces prior)")
	var pend: Array = buf.pending()
	t.eq((pend[0] as EQPresentationEvent).position, Vector2(2, 0), "coalesced: latest position held")


static func _test_buffer_flush_player_turn(t) -> void:
	var policy := EQPresentationPolicy.new()
	policy.flush_on_player_turn = true
	var buf := EQPresentationBuffer.new(policy)
	buf.enqueue(EQPresentationEvent.new(&"hero", Vector2.ZERO, &"sensed"))
	t.eq(buf.pending().size(), 1, "sensed pending before player-turn")
	buf.flush_player_turn()
	t.eq(buf.pending().size(), 0, "player-turn flush empties pending")
	t.eq(buf.flushed().size(), 1, "event emitted at player-turn boundary")


static func _test_neutrality_property(t) -> void:
	# The same sequence of EffectRecords accumulated under two very different
	# PresentationPolicies must be byte-identical. The buffer must never alter the
	# simulation truth (the chunk); only the flushed-visual output may differ.

	var chunk_a := EQEffectChunk.new()
	var chunk_b := EQEffectChunk.new()

	# Policy A: default (important=immediate, offscreen=skip, sensed=deferred)
	var policy_a := EQPresentationPolicy.new()
	# Policy B: suppress all visuals (skip every classification)
	var policy_b := EQPresentationPolicy.new()
	policy_b.immediate_classes = []
	policy_b.skip_classes = [&"important", &"sensed", &"offscreen"]

	var buf_a := EQPresentationBuffer.new(policy_a)
	var buf_b := EQPresentationBuffer.new(policy_b)

	# Simulation truth: identical records regardless of presentation policy
	var r1 := EQEffectRecord.new(&"damage", &"orc", &"hp", -10)
	r1.classification = &"important"
	var r2 := EQEffectRecord.new(&"status", &"hero", &"mp", -3)
	r2.classification = &"sensed"
	var r3 := EQEffectRecord.new(&"damage", &"shadow", &"hp", -1)
	r3.classification = &"offscreen"

	for r: EQEffectRecord in [r1, r2, r3]:
		chunk_a.add(r)
		chunk_b.add(r)

	# Presentation events (queued separately; the enqueue never touches the chunks)
	var ev1 := EQPresentationEvent.new(&"orc", Vector2.ZERO, &"important")
	var ev2 := EQPresentationEvent.new(&"hero", Vector2.ONE, &"sensed")
	var ev3 := EQPresentationEvent.new(&"shadow", Vector2.ZERO, &"offscreen")

	for ev: EQPresentationEvent in [ev1, ev2, ev3]:
		buf_a.enqueue(ev)
		buf_b.enqueue(ev)

	# -- neutrality: simulation truth is identical across policies --
	var recs_a: Array = chunk_a.drain()
	var recs_b: Array = chunk_b.drain()
	t.eq(recs_a.size(), 3, "chunk A: 3 effect records (neutrality anchor)")
	t.eq(recs_b.size(), 3, "chunk B: 3 effect records (identical to A)")
	for i: int in range(3):
		var ra: EQEffectRecord = recs_a[i]
		var rb: EQEffectRecord = recs_b[i]
		t.eq(ra.kind, rb.kind, "record[%d].kind identical across policies" % i)
		t.eq(ra.delta, rb.delta, "record[%d].delta identical across policies" % i)
	t.ok(chunk_a.is_empty() and chunk_b.is_empty(), "both chunks drained to empty (save boundary)")

	# -- flushed-visual output DOES differ between policies --
	buf_a.flush()  # flush any remaining deferred (sensed) in policy A
	var fl_a: Array = buf_a.flushed()
	var fl_b: Array = buf_b.flushed()
	t.ok(fl_a.size() > 0, "policy A emits visuals")
	t.eq(fl_b.size(), 0, "policy B suppresses all visuals (different output — proves policy is real)")
