extends RefCounted
## EQM-080: presentation event — queued separately with actor/position references,
## no live node in the save form.

const EQPresentationEvent := preload("res://addons/event_queue_manager/runtime/eq_presentation_event.gd")


static func run(t) -> void:
	_test_fields_and_position_snapshot(t)
	_test_weak_binding_not_serialized(t)
	_test_roundtrip(t)


static func _test_fields_and_position_snapshot(t) -> void:
	var e := EQPresentationEvent.new(&"hero", Vector2(3, 4), &"important")
	e.tags = [&"hit_spark"]
	e.changes_position_of = [&"hero"]
	e.depends_on = [&"orc"]
	t.eq(e.actor_id, &"hero", "presentation event carries actor_id")
	t.eq(e.position, Vector2(3, 4), "position is a value snapshot captured at queue time")
	t.eq(e.classification, &"important", "classification held for the flush policy")
	t.eq(e.changes_position_of, [&"hero"] as Array[StringName], "records which entities it moves (barrier producer)")
	t.eq(e.depends_on, [&"orc"] as Array[StringName], "records which entities it assumes (barrier consumer)")


static func _test_weak_binding_not_serialized(t) -> void:
	var e := EQPresentationEvent.new(&"hero", Vector2.ZERO)
	var obj := Object.new()
	e.bind(obj)
	t.ok(e.bound() == obj, "transient bind links the live render node")
	var d := e.to_dict()
	t.ok(not d.has("_binding") and not d.has("binding"), "to_dict carries no live reference (Adapter rule)")
	t.ok(d.has("position"), "to_dict carries the position value")
	obj.free()
	t.ok(e.bound() == null, "freed node -> not bound (weak)")


static func _test_roundtrip(t) -> void:
	var e := EQPresentationEvent.new(&"hero", Vector2(1, 2), &"sensed")
	e.tags = [&"a"]
	e.changes_position_of = [&"hero"]
	e.depends_on = [&"b", &"c"]
	var back := EQPresentationEvent.from_dict(e.to_dict())
	t.eq(back.actor_id, &"hero", "actor_id roundtrips")
	t.eq(back.position, Vector2(1, 2), "position value roundtrips")
	t.eq(back.classification, &"sensed", "classification roundtrips")
	t.eq(back.depends_on, [&"b", &"c"] as Array[StringName], "depends_on roundtrips")
	t.ok(back.bound() == null, "restored event has no binding")
