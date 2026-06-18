extends RefCounted
## EQM-085: save/load stores actor_id + state, never live Nodes, and rebinds on
## load reproducing the schedule.

const EQRuntime := preload("res://addons/event_queue_manager/runtime/eq_runtime.gd")
const EQSaveAdapter := preload("res://addons/event_queue_manager/runtime/eq_save_adapter.gd")


static func run(t) -> void:
	_test_save_has_no_live_node(t)
	_test_load_rebinds_and_reproduces(t)
	_test_unknown_schema(t)


static func _build() -> EQRuntime:
	var rt := EQRuntime.new()
	rt.register_actor(&"hero").data["speed"] = 12
	rt.register_actor(&"orc").data["speed"] = 8
	rt.schedule(&"hero", 5, 0, &"turn")
	rt.schedule(&"orc", 3, 0, &"turn")
	return rt


static func _test_save_has_no_live_node(t) -> void:
	var rt := _build()
	# bind a live object to an actor — it must NOT end up in the save
	var node := Object.new()
	rt.registry.get_state(&"hero").bind(node)
	var save := EQSaveAdapter.save(rt)
	t.ok(not EQSaveAdapter.contains_live_object(save), "save bundle contains no live Object (Adapter rule)")
	t.eq((save["actors"] as Array).size(), 2, "save stores actor states")
	node.free()


static func _test_load_rebinds_and_reproduces(t) -> void:
	var rt := _build()
	var save := EQSaveAdapter.save(rt)

	var node := Object.new()
	var fresh := EQRuntime.new()
	t.ok(EQSaveAdapter.load(fresh, save, {&"hero": node}), "load succeeds")
	t.ok(fresh.registry.is_registered(&"hero") and fresh.registry.is_registered(&"orc"), "actors re-registered on load")
	t.eq(fresh.registry.get_state(&"hero").data["speed"], 12, "actor data restored")
	t.ok(fresh.registry.get_state(&"hero").bound() == node, "actor rebound to its live node via the rebind map")
	# the schedule is reproduced (orc at tick 3 pops before hero at tick 5)
	t.eq(fresh.advance().actor_id, &"orc", "restored schedule reproduces pop order (orc first)")
	t.eq(fresh.advance().actor_id, &"hero", "then hero")
	node.free()


static func _test_unknown_schema(t) -> void:
	var rt := EQRuntime.new()
	t.ok(not EQSaveAdapter.load(rt, {"schema_version": 999, "scheduler": {}, "actors": []}), "unknown save schema -> load returns false")
