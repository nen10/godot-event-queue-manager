class_name EQSaveAdapter
extends RefCounted
## Save/load for an EQRuntime that stores actor_ids + serializable state, never
## live Nodes (the Adapter rule), and rebinds actors to live nodes on load.
##
## The save bundle is the scheduler snapshot (EQM-012) plus each active actor's
## serializable state (actor_id + acceptance data — no WeakRef/Node). On load
## into a fresh runtime, actors are re-registered, their data restored, and each
## is rebound to a live node via the `rebind` map (actor_id -> node). The node
## bridge (EQNodeBridge) is the usual source of that map.

const SCHEMA_VERSION := 1


## A plain, node-free save bundle.
static func save(runtime) -> Dictionary:
	var actors: Array = []
	for actor_id in runtime.registry.actor_ids():
		actors.append(runtime.registry.get_state(actor_id).to_dict())
	return {
		"schema_version": SCHEMA_VERSION,
		"scheduler": runtime.scheduler.snapshot(),
		"actors": actors,
	}


## Restores into `into_runtime` (expected fresh): scheduler state, re-registered
## actors with their data, and live-node rebinding via `rebind` (actor_id ->
## node). Returns false on an unknown schema (runtime left as-is).
static func load(into_runtime, data: Dictionary, rebind: Dictionary = {}) -> bool:
	if int(data.get("schema_version", -1)) != SCHEMA_VERSION:
		return false
	into_runtime.scheduler.restore(data.get("scheduler", {}))
	for actor_dict in data.get("actors", []):
		var actor_id := StringName(actor_dict.get("actor_id", ""))
		var state = into_runtime.register_actor(actor_id)
		if state != null:
			state.data = (actor_dict.get("data", {}) as Dictionary).duplicate(true)
			if rebind.has(actor_id):
				state.bind(rebind[actor_id])
	return true


## Diagnostic: true if a save bundle contains a live Object reference anywhere
## (it must not). Used by tests to prove the Adapter rule.
static func contains_live_object(value) -> bool:
	match typeof(value):
		TYPE_OBJECT:
			return value != null
		TYPE_DICTIONARY:
			for k in value:
				if contains_live_object(value[k]):
					return true
			return false
		TYPE_ARRAY:
			for e in value:
				if contains_live_object(e):
					return true
			return false
		_:
			return false
