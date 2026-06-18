extends RefCounted
## EQM-085: node bridge — scene-local actor↔node binding, actor-deletion routed
## through the invalidation path, and the multi-domain signal bridge.

const EQManager := preload("res://addons/event_queue_manager/runtime/eq_manager.gd")
const EQNodeBridge := preload("res://addons/event_queue_manager/runtime/eq_node_bridge.gd")
const EQActionResult := preload("res://addons/event_queue_manager/runtime/eq_action_result.gd")
const EQFixedRoundPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_fixed_round_policy.gd")


static func run(t) -> void:
	_test_scene_local_bind(t)
	_test_actor_deletion_invalidates(t)
	_test_signal_bridge(t)


static func _make() -> Array:
	var m = EQManager.new()
	m.set_mode(1)  # SHIPPED so a deleted actor's event is skipped (not halted)
	m.runtime().emit_engine_diagnostics = false
	m.set_policy(EQFixedRoundPolicy.new())
	var bridge = EQNodeBridge.new(m)  # scene-local: no autoload, no SceneTree needed
	return [m, bridge]


static func _test_scene_local_bind(t) -> void:
	var pair = _make()
	var m = pair[0]
	var bridge = pair[1]
	m.register_actor(&"hero")
	var node := Object.new()
	bridge.bind_actor(&"hero", node)
	t.ok(bridge.node_for(&"hero") == node, "actor bound to its live node (scene-local, no autoload)")
	t.ok(m.runtime().registry.get_state(&"hero").bound() == node, "actor state weak-bound to the node")
	node.free()
	bridge.free()
	m.free()


static func _test_actor_deletion_invalidates(t) -> void:
	var pair = _make()
	var m = pair[0]
	var bridge = pair[1]
	m.register_actor(&"hero").data["initiative"] = 9
	m.register_actor(&"orc").data["initiative"] = 1
	m.policy.seed(m.runtime(), m.runtime().registry.actor_ids())
	t.eq(m.step().actor_id, &"hero", "hero acts first")
	m.finish_action(&"hero", EQActionResult.new(0, 0))
	# orc is deleted mid-round: its pending turn must be invalidated, not crash
	var invalidated: Array = []
	bridge.event_invalidated.connect(func(aid): invalidated.append(aid))
	bridge.on_actor_freed(&"orc")
	t.ok(not m.runtime().registry.is_registered(&"orc"), "deleted actor unregistered (Q05 invalidation path)")
	t.ok(invalidated.has(&"orc"), "event_invalidated emitted for the deleted actor")
	var e = m.step()  # hits orc's orphaned turn -> shipped skip -> continues
	t.ok(e == null or e.actor_id != &"orc", "deleted actor's pending turn is skipped, not resolved")
	bridge.free()
	m.free()


static func _test_signal_bridge(t) -> void:
	var pair = _make()
	var m = pair[0]
	var bridge = pair[1]
	var seen: Array = []
	bridge.turn_ready.connect(func(aid): seen.append("turn:%s" % aid))
	bridge.effect_recorded.connect(func(_r): seen.append("effect"))
	bridge.presentation_flushed.connect(func(_e): seen.append("presentation"))
	bridge.reservation_resolved.connect(func(_r): seen.append("reservation"))
	bridge.trigger_fired.connect(func(_r): seen.append("trigger"))
	# turn domain: forwarded from the manager
	m.register_actor(&"hero")
	m.set_policy(EQFixedRoundPolicy.new())
	m.policy.seed(m.runtime(), m.runtime().registry.actor_ids())
	m.step()  # emits manager.turn_ready -> bridge.turn_ready
	# other domains: the consumer notifies through the bridge (dogfood F2)
	bridge.notify_effect_recorded(null)
	bridge.notify_presentation_flushed(null)
	bridge.notify_reservation_resolved(null)
	bridge.notify_trigger_fired(null)
	t.ok(seen.has("turn:hero"), "turn signal bridged from the manager")
	for dom in ["effect", "presentation", "reservation", "trigger"]:
		t.ok(seen.has(dom), "%s domain signal bridged" % dom)
	bridge.free()
	m.free()
