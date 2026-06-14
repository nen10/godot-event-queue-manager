extends RefCounted
## EQM-021: actor registration, duplicate/reuse/empty rejection, and the weak
## binding placeholder (never serialized, freed -> null).

const EQActorRegistry := preload("res://addons/event_queue_manager/runtime/eq_actor_registry.gd")
const EQActorState := preload("res://addons/event_queue_manager/runtime/eq_actor_state.gd")
const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")


static func run(t) -> void:
	_test_register(t)
	_test_duplicate(t)
	_test_empty_id(t)
	_test_no_reuse(t)
	_test_weak_binding(t)
	_test_state_serialization(t)


static func _test_register(t) -> void:
	var reg := EQActorRegistry.new()
	var s := reg.register(&"hero")
	t.ok(s != null, "register returns a state")
	t.eq(s.actor_id, &"hero", "state carries the actor_id")
	t.ok(reg.is_registered(&"hero"), "is_registered true after register")
	t.ok(reg.get_state(&"hero") == s, "get_state returns the same state")
	t.eq(reg.size(), 1, "size reflects one actor")


static func _test_duplicate(t) -> void:
	var reg := EQActorRegistry.new()
	reg.register(&"hero")
	var dup := reg.register(&"hero")
	t.ok(dup == null, "duplicate register returns null")
	t.ok(reg.validate_register(&"hero").has_code(EQError.ACTOR_DUPLICATE_ID), "duplicate -> ACTOR_DUPLICATE_ID")
	t.eq(reg.size(), 1, "duplicate does not change registry size")


static func _test_empty_id(t) -> void:
	var reg := EQActorRegistry.new()
	var s := reg.register(&"")
	t.ok(s == null, "empty id register returns null")
	t.ok(reg.validate_register(&"").has_code(EQError.ACTOR_EMPTY_ID), "empty id -> ACTOR_EMPTY_ID")
	t.eq(reg.size(), 0, "empty id does not register")


static func _test_no_reuse(t) -> void:
	var reg := EQActorRegistry.new()
	reg.register(&"orc")
	t.ok(reg.unregister(&"orc"), "unregister returns true for active actor")
	t.ok(not reg.is_registered(&"orc"), "no longer registered after unregister")
	var reused := reg.register(&"orc")
	t.ok(reused == null, "retired id cannot be reused")
	t.ok(reg.validate_register(&"orc").has_code(EQError.ACTOR_ID_REUSED), "reuse -> ACTOR_ID_REUSED")
	t.ok(not reg.unregister(&"orc"), "unregister of unknown id returns false")


static func _test_weak_binding(t) -> void:
	var reg := EQActorRegistry.new()
	var s := reg.register(&"hero")
	t.ok(not s.is_bound(), "unbound state is not bound")
	var obj := Object.new()
	s.bind(obj)
	t.ok(s.is_bound(), "bound after bind")
	t.ok(s.bound() == obj, "bound() returns the object")
	obj.free()
	t.ok(not s.is_bound(), "freed object -> not bound (weak)")
	t.ok(s.bound() == null, "bound() is null after free")


static func _test_state_serialization(t) -> void:
	var s := EQActorState.new(&"hero")
	s.data = {"speed": 12}
	var obj := Object.new()
	s.bind(obj)
	var d := s.to_dict()
	t.ok(not d.has("_binding") and not d.has("binding"), "to_dict omits the weak binding (no live ref in save form)")
	t.eq(String(d["actor_id"]), "hero", "to_dict carries actor_id")
	t.eq(d["data"]["speed"], 12, "to_dict carries acceptance data")
	var back := EQActorState.from_dict(d)
	t.eq(back.actor_id, &"hero", "from_dict restores actor_id")
	t.eq(back.data["speed"], 12, "from_dict restores data")
	t.ok(not back.is_bound(), "restored state is unbound (binding never serialized)")
	obj.free()
