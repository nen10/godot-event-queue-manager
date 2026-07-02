class_name EQNodeBridge
extends Node
## Scene-local bridge between an EQManager/EQRuntime and Godot Nodes (EQM-085).
## Binds actor_ids to live nodes by WeakRef (never storing a node in the save
## form), routes actor deletion through the Q05 invalidation path, and exposes a
## multi-domain signal bridge so a consumer subscribes to events instead of hand-
## driving them (the dogfood F2 follow-up).
##
## Autoload is OPT-IN: the default is scene-local (add this as a child node). The
## bridge requires no autoload to function.

signal turn_ready(actor_id)
signal reservation_resolved(reservation)
signal trigger_fired(reservation)
signal effect_recorded(record)
signal presentation_flushed(event)
signal event_invalidated(actor_id)

var _manager = null
var _nodes: Dictionary = {}   # actor_id -> WeakRef(node)


func _init(manager = null) -> void:
	_manager = manager
	if manager != null:
		if manager.has_signal(&"turn_ready"):
			manager.turn_ready.connect(_on_manager_turn_ready)
		if manager.has_signal(&"invalid_event_skipped"):
			manager.invalid_event_skipped.connect(_on_manager_invalid)


func _runtime():
	return _manager.runtime() if _manager != null else null


## Binds an actor to its live node (WeakRef; also sets the actor state's weak
## binding when the actor is registered).
func bind_actor(actor_id: StringName, node: Object) -> void:
	_nodes[actor_id] = weakref(node)
	var rt = _runtime()
	if rt != null and rt.registry.is_registered(actor_id):
		rt.registry.get_state(actor_id).bind(node)


func node_for(actor_id: StringName) -> Object:
	var w = _nodes.get(actor_id, null)
	return w.get_ref() if w != null else null


## Routes a deleted actor through the NORMAL invalidation path (SEM §13, Q39,
## EQM-113): `invalidate_actor` cancels its pending events with
## `closed_by: actor_removed` traces and unregisters it — mode-neutral (death
## mid-battle is normal gameplay, not an anomaly).
func on_actor_freed(actor_id: StringName) -> void:
	var rt = _runtime()
	if rt != null and rt.registry.is_registered(actor_id):
		rt.invalidate_actor(actor_id)
	_nodes.erase(actor_id)
	event_invalidated.emit(actor_id)


## Sweeps bound actors whose node has been freed and invalidates them.
func prune_freed() -> void:
	for actor_id in _nodes.keys():
		if node_for(actor_id) == null:
			on_actor_freed(actor_id)


# --- domain notifications (the consumer emits these as it drives the subsystems) ---
func notify_reservation_resolved(reservation) -> void:
	reservation_resolved.emit(reservation)


func notify_trigger_fired(reservation) -> void:
	trigger_fired.emit(reservation)


func notify_effect_recorded(record) -> void:
	effect_recorded.emit(record)


func notify_presentation_flushed(event) -> void:
	presentation_flushed.emit(event)


func _on_manager_turn_ready(actor_id, _entry) -> void:
	turn_ready.emit(actor_id)


func _on_manager_invalid(fault) -> void:
	var actor_id := StringName(fault.get("context", {}).get("actor_id", "")) if fault is Dictionary else &""
	event_invalidated.emit(actor_id)
