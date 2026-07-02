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

## v2 (EQM-117, SEM §10): additive pipeline tables (event_lines / windows /
## armed_triggers / pending_conditional / scheduled_reservations) next to the
## v1 keys. A v1 bundle loads via the migrator (missing tables = empty); an
## unknown/newer version is rejected (SNAPSHOT_COMPAT_V1.md fail-safe).
const SCHEMA_VERSION := 2


## A plain, node-free save bundle. With a pipeline (EQReservationRuntime), the
## save is GATED on the boundary (SEM §10: chunk empty, no explicit window) —
## off-boundary saves record `eqm.save.blocked` and return {} (no force flag).
static func save(runtime, pipeline = null) -> Dictionary:
	if pipeline != null and not pipeline.is_save_boundary():
		runtime._fault(EQError.SAVE_BLOCKED, "save requested off the boundary (chunk non-empty or a window is open)", {}, true)
		return {}
	var actors: Array = []
	for actor_id in runtime.registry.actor_ids():
		actors.append(runtime.registry.get_state(actor_id).to_dict())
	var bundle := {
		"schema_version": SCHEMA_VERSION,
		"scheduler": runtime.scheduler.snapshot(),
		"actors": actors,
	}
	if pipeline != null:
		bundle.merge(pipeline.save_state())
	else:
		bundle.merge({
			"event_lines": {}, "windows": [], "armed_triggers": [],
			"pending_conditional": [], "scheduled_reservations": [],
		})
	return bundle


## Restores into `into_runtime` (expected fresh): scheduler state, re-registered
## actors with their data, and live-node rebinding via `rebind` (actor_id ->
## node). With a pipeline, its tables are restored too — after a
## verify-before-mutate pass (unregistered predicate/effect/sweep-rule names =
## stable error, nothing applied). Returns false on an unknown schema or a
## failed verification (runtime left as-is). v1 bundles load with empty tables.
static func load(into_runtime, data: Dictionary, rebind: Dictionary = {}, pipeline = null) -> bool:
	var version := int(data.get("schema_version", -1))
	if version < 1 or version > SCHEMA_VERSION:
		return false
	if pipeline != null and not pipeline.verify_state(data):
		return false
	into_runtime.scheduler.restore(data.get("scheduler", {}))
	for actor_dict in data.get("actors", []):
		var actor_id := StringName(actor_dict.get("actor_id", ""))
		var state = into_runtime.register_actor(actor_id)
		if state != null:
			state.data = (actor_dict.get("data", {}) as Dictionary).duplicate(true)
			if rebind.has(actor_id):
				state.bind(rebind[actor_id])
	if pipeline != null:
		pipeline.apply_state(data)
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
