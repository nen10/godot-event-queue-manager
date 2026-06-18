extends RefCounted
## EQM-080: simulation effect record + effect-processing-chunk (save boundary).

const EQEffectRecord := preload("res://addons/event_queue_manager/runtime/eq_effect_record.gd")
const EQEffectChunk := preload("res://addons/event_queue_manager/runtime/eq_effect_chunk.gd")


static func run(t) -> void:
	_test_record_immediate(t)
	_test_trace_record_canonical(t)
	_test_chunk_save_boundary(t)
	_test_record_roundtrip(t)


static func _test_record_immediate(t) -> void:
	var r := EQEffectRecord.new(&"damage", &"hero", &"hp", -12)
	r.source = &"orc"
	r.classification = EQEffectRecord.CLASS_IMPORTANT
	t.eq(r.target, &"hero", "effect record carries its target immediately")
	t.eq(r.delta, -12, "delta is an integer effect amount")
	t.eq(r.classification, EQEffectRecord.CLASS_IMPORTANT, "classification (consumer-supplied) is held")


static func _test_trace_record_canonical(t) -> void:
	var r := EQEffectRecord.new(&"damage", &"hero", &"hp", -12)
	r.source = &"orc"
	var tr := r.to_trace_record()
	t.eq(tr["kind"], "effect", "trace record kind is 'effect' (open-kind schema)")
	t.eq(tr["delta"], -12, "delta is int in the trace record (no float in sim truth)")
	t.eq(tr["target"], "hero", "target serialized")
	t.eq(typeof(tr["delta"]), TYPE_INT, "delta is an integer")


static func _test_chunk_save_boundary(t) -> void:
	var chunk := EQEffectChunk.new()
	t.ok(chunk.is_empty(), "fresh chunk is empty")
	t.ok(chunk.is_save_allowed(), "save allowed when the chunk is empty")
	chunk.add(EQEffectRecord.new(&"damage", &"hero", &"hp", -5))
	chunk.add(EQEffectRecord.new(&"status", &"hero", &"poison", 1))
	t.eq(chunk.size(), 2, "records accumulate at resolution")
	t.ok(not chunk.is_save_allowed(), "save NOT allowed while effects are pending in the chunk")
	var drained := chunk.drain()
	t.eq(drained.size(), 2, "drain returns the accumulated records")
	t.ok(chunk.is_save_allowed(), "save allowed again after the chunk drains (boundary)")


static func _test_record_roundtrip(t) -> void:
	var r := EQEffectRecord.new(&"status", &"mage", &"mp", 8)
	r.source = &"mage"
	r.tags = [&"buff", &"regen"]
	r.classification = EQEffectRecord.CLASS_SENSED
	var back := EQEffectRecord.from_dict(r.to_dict())
	t.eq(back.kind, &"status", "kind roundtrips")
	t.eq(back.delta, 8, "delta roundtrips")
	t.eq(back.tags, [&"buff", &"regen"] as Array[StringName], "tags roundtrip")
	t.eq(back.classification, EQEffectRecord.CLASS_SENSED, "classification roundtrips")
