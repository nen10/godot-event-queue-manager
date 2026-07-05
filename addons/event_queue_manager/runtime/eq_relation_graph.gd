class_name EQRelationGraph
extends RefCounted
## L3 relation graph backend (SEM §13.1).
##
## Stores relation type declarations and relation instances, evaluates maintenance
## conditions in a fixed order, and keeps deterministic id/replay behaviour.
## Violations are recorded as faults, never thrown.

const EQConditionEval := preload("eq_condition_eval.gd")
const EQConditionSpec := preload("../resources/eq_condition_spec.gd")
const EQError := preload("eq_error.gd")

enum Structure { TREE, GRAPH }
enum Dissolve { NONE, SERIAL_SUTURE }

const DEFAULT_SWEEP := &"eqm.sweep.primary_threshold"

var faults: Array[Dictionary] = []

## relation type name -> declaration dict
var _type_declarations: Dictionary = {}
## relation_id -> relation dict
var _relations: Dictionary = {}
## actor -> Array[StringName] of relation ids touching that actor
var _actor_relations: Dictionary = {}
## next relation id seed
var _relation_seq: int = 0

var _trace = null


func _init(trace = null) -> void:
	_trace = trace


func set_trace(trace) -> void:
	_trace = trace


# --- declarations --------------------------------------------------------------

func declare_relation_type(decl: Dictionary) -> bool:
	if typeof(decl) != TYPE_DICTIONARY:
		_fault(EQError.CONDITION_LINE_UNKNOWN, "relation type declaration must be a Dictionary", {})
		return false

	var name := StringName(decl.get("name", ""))
	if name == &"":
		_fault(EQError.POLICY_NAME_EMPTY, "relation type name must not be empty", {"relation_type": ""})
		return false

	var structure := int(decl.get("structure", Structure.TREE))
	if structure < Structure.TREE or structure > Structure.GRAPH:
		_fault(EQError.CONDITION_LINE_UNKNOWN, "unknown relation structure: %d" % structure, {"relation_type": String(name)})
		return false

	var dissolve := int(decl.get("on_dissolve", Dissolve.NONE))
	if dissolve < Dissolve.NONE or dissolve > Dissolve.SERIAL_SUTURE:
		_fault(EQError.CONDITION_LINE_UNKNOWN, "unknown on_dissolve strategy: %d" % dissolve, {"relation_type": String(name)})
		return false

	var maintenance := decl.get("maintenance", null)
	if maintenance != null and typeof(maintenance) != TYPE_DICTIONARY:
		_fault(EQError.CONDITION_LINE_UNKNOWN, "maintenance must be null or Dictionary", {"relation_type": String(name)})
		return false
	if maintenance != null:
		var maintenance_spec := EQConditionSpec.from_dict(maintenance as Dictionary)
		var validation := maintenance_spec.validate()
		if not validation.is_valid():
			for issue in validation.errors():
				_fault(issue["code"], issue["message"], {"relation_type": String(name)})
			return false
		var mtype := int(maintenance.get("type", EQConditionSpec.Type.LINE_THRESHOLD))
		if mtype < EQConditionSpec.Type.LINE_THRESHOLD or mtype > EQConditionSpec.Type.NAMED_PREDICATE:
			_fault(EQError.CONDITION_LINE_UNKNOWN, "unknown maintenance condition type: %d" % mtype, {"relation_type": String(name)})
			return false
		if mtype == EQConditionSpec.Type.COUNTER:
			_fault(EQError.CONDITION_PREDICATE_NAME_EMPTY, "COUNTER maintenance is not supported in relation graph", {"relation_type": String(name)})
			return false

	_type_declarations[String(name)] = {
		"name": name,
		"category": StringName(decl.get("category", "")),
		"inverse": StringName(decl.get("inverse", "")),
		"structure": structure,
		"maintenance": maintenance,
		"sweep": StringName(decl.get("sweep", DEFAULT_SWEEP)),
		"on_dissolve": dissolve,
	}
	return true


# --- relation instances --------------------------------------------------------

func bind(type: StringName, from_actor: StringName, to_actor: StringName) -> StringName:
	if type == &"" or from_actor == &"" or to_actor == &"":
		_fault(EQError.CONDITION_LINE_UNKNOWN, "relation bind requires non-empty type/from/to", {"type": String(type), "from": String(from_actor), "to": String(to_actor)})
		return &""
	if not _type_declarations.has(String(type)):
		_fault(EQError.CONDITION_LINE_UNKNOWN, "bind of undeclared relation type: %s" % type, {"type": String(type)})
		return &""

	if int(_type_declarations[String(type)]["structure"]) == Structure.TREE:
		if _has_parent_of_type(type, to_actor):
			_fault(EQError.CONDITION_LINE_UNKNOWN, "TREE relation constraint violated for %s -> %s" % [String(from_actor), String(to_actor)], {"type": String(type), "to": String(to_actor)})
			return &""

	var relation_id := _next_relation_id()
	var rel := {
		"relation_id": relation_id,
		"type": type,
		"from_actor": from_actor,
		"to_actor": to_actor,
	}
	_add_relation(relation_id, rel)
	_record({"kind": "relation_bound", "relation": String(relation_id), "type": String(type), "from": String(from_actor), "to": String(to_actor)})
	return relation_id


func dissolve(relation_id: StringName, cause: StringName = &"dissolved") -> bool:
	if relation_id == &"" or not _relations.has(relation_id):
		_fault(EQError.CONDITION_LINE_UNKNOWN, "unknown relation id", {"relation_id": String(relation_id)})
		return false

	var rel: Dictionary = _relations[relation_id].duplicate(true)
	_remove_relation(relation_id)
	_record({
		"kind": "relation_dissolved",
		"relation": String(relation_id),
		"type": String(rel["type"]),
		"from": String(rel["from_actor"]),
		"to": String(rel["to_actor"]),
		"cause": String(cause),
	})
	var on_dissolve := int(_type_declarations.get(String(rel["type"])) .get("on_dissolve", Dissolve.NONE))
	if on_dissolve == Dissolve.SERIAL_SUTURE:
		var rebound := _try_serial_rebound(rel)
		if rebound != &"":
			_record({
				"kind": "relation_rebound",
				"new_relation": String(rebound),
				"type": String(rel["type"]),
				"from": String(_relations[rebound]["from_actor"]),
				"to": String(_relations[rebound]["to_actor"]),
				"via": String(relation_id),
			})
	return true


func invert(relation_id: StringName) -> bool:
	if relation_id == &"" or not _relations.has(relation_id):
		_fault(EQError.CONDITION_LINE_UNKNOWN, "unknown relation id", {"relation_id": String(relation_id)})
		return false

	var current: Dictionary = _relations[relation_id]
	var current_decl: Dictionary = _type_declarations.get(String(current["type"]), {})
	if current_decl.is_empty():
		_fault(EQError.CONDITION_LINE_UNKNOWN, "relation type is not declared", {"type": String(current["type"])})
		return false
	var inverse_type: StringName = StringName(current_decl.get("inverse", ""))
	if inverse_type == &"":
		_fault(EQError.CONDITION_LINE_UNKNOWN, "relation type has no inverse", {"type": String(current["type"])})
		return false
	if not _type_declarations.has(String(inverse_type)):
		_fault(EQError.CONDITION_LINE_UNKNOWN, "inverse relation type is not declared: %s" % inverse_type, {"type": String(current["type"])})
		return false

	var inverse_decl: Dictionary = _type_declarations[String(inverse_type)]
	var from_type := StringName(current["type"])
	var next: Dictionary = current.duplicate(true)
	next["relation_id"] = relation_id
	next["type"] = inverse_type
	next["from_actor"] = current["to_actor"]
	next["to_actor"] = current["from_actor"]

	# Exclude this relation while validating TREE parent constraints.
	_remove_relation(relation_id)
	if int(inverse_decl.get("structure", Structure.TREE)) == Structure.TREE:
		if _has_parent_of_type(inverse_type, next["to_actor"]):
			_add_relation(relation_id, current)
			_fault(EQError.CONDITION_LINE_UNKNOWN, "TREE relation constraint violated by invert", {"relation_id": String(relation_id), "type": String(inverse_type), "to": String(next["to_actor"])})
			return false
	_add_relation(relation_id, next)
	_record({"kind": "relation_inverted", "relation": String(relation_id), "from_type": String(from_type), "to_type": String(inverse_type)})
	return true


func invalidate_actor(actor_id: StringName) -> int:
	if actor_id == &"":
		_fault(EQError.CONDITION_LINE_ID_EMPTY, "invalidate_actor requires non-empty actor id", {"actor": ""})
		return 0
	var impacted: Array = []
	for rel_id in _relations:
		var rel: Dictionary = _relations[rel_id]
		if rel["from_actor"] == actor_id or rel["to_actor"] == actor_id:
			impacted.append(rel_id)
	var count := 0
	impacted.sort_custom(func(a, b): return String(a) < String(b))
	for rel_id in impacted:
		if dissolve(rel_id, &"actor_removed"):
			count += 1
	return count


# --- query --------------------------------------------------------------------

func relations_of(actor: StringName) -> Array:
	var ids := relation_ids()
	var out: Array = []
	for rid in ids:
		var rel: Dictionary = _relations[rid]
		if rel["from_actor"] == actor or rel["to_actor"] == actor:
			out.append(rel.duplicate(true))
	return out


func relation(relation_id: StringName) -> Dictionary:
	if not _relations.has(relation_id):
		return {}
	return (_relations[relation_id] as Dictionary).duplicate(true)


func relation_ids() -> Array:
	var ids := _relations.keys()
	ids.sort_custom(func(a, b): return String(a) < String(b))
	return ids


# --- maintenance ---------------------------------------------------------------

func run_maintenance(sweep: StringName, ctx: Dictionary, predicates: Dictionary) -> int:
	if sweep == &"":
		_fault(EQError.POLICY_NAME_EMPTY, "run_maintenance requires non-empty sweep name", {"sweep": ""})
		return 0
	var count := 0
	var lines := ctx.get("lines", {})
	var view := ctx.get("view", {})
	for rel_id in relation_ids():
		if not _relations.has(rel_id):
			continue
		var rel: Dictionary = _relations[rel_id]
		var decl: Dictionary = _type_declarations.get(String(rel["type"]), {})
		if decl.is_empty():
			continue
		if String(decl.get("sweep", DEFAULT_SWEEP)) != String(sweep):
			continue
		# Untyped on purpose: a maintenance-less type stores null, and a typed
		# Dictionary local would raise an engine error on the null assignment.
		var maintenance = decl.get("maintenance", null)
		if maintenance == null:
			continue

		var spec := EQConditionSpec.from_dict(maintenance as Dictionary)
		var validation := spec.validate()
		if not validation.is_valid():
			for issue in validation.errors():
				_fault(issue["code"], issue["message"], {"relation_id": String(rel_id), "relation_type": String(rel["type"])})
			continue

		var bound_term := EQConditionEval.bind(spec, "maintenance", 0, {"lines": lines}, &"")
		if bound_term.has("fault"):
			var f: Dictionary = bound_term["fault"]
			var code := f.get("code", EQError.CONDITION_LINE_UNKNOWN)
			var msg := String(f.get("message", "maintenance bind fault"))
			_fault(code, msg, {"relation_id": String(rel_id), "relation_type": String(rel["type"]), "sweep": String(sweep)})
			continue
		var eval_ctx := {"lines": lines, "view": view, "predicates": predicates}
		var result := EQConditionEval.term_holds(bound_term, eval_ctx)
		if int(result["result"]) == EQConditionEval.Result.FAULT:
			var f: Dictionary = result.get("fault", {})
			var code := f.get("code", EQError.CONDITION_LINE_UNKNOWN)
			var msg := String(f.get("message", "maintenance evaluation fault"))
			_fault(code, msg, {"relation_id": String(rel_id), "relation_type": String(rel["type"]), "sweep": String(sweep)})
			continue
		if int(result["result"]) != EQConditionEval.Result.YES:
			if dissolve(rel_id, &"maintenance_failed"):
				count += 1
	return count


# --- serialize / restore -------------------------------------------------------

func to_dict() -> Dictionary:
	var relation_types: Array = []
	var type_ids := _type_declarations.keys()
	type_ids.sort_custom(func(a, b): return String(a) < String(b))
	for type_name in type_ids:
		var d: Dictionary = _type_declarations[type_name]
		relation_types.append({
			"name": String(d.get("name", "")),
			"category": String(d.get("category", "")),
			"inverse": String(d.get("inverse", "")),
			"structure": int(d.get("structure", Structure.TREE)),
			"maintenance": d.get("maintenance", null),
			"sweep": String(d.get("sweep", DEFAULT_SWEEP)),
			"on_dissolve": int(d.get("on_dissolve", Dissolve.NONE)),
		}
		)

	var relations: Array = []
	for rel_id in relation_ids():
		var rel: Dictionary = _relations[rel_id]
		relations.append({
			"relation_id": String(rel_id),
			"type": String(rel["type"]),
			"from": String(rel["from_actor"]),
			"to": String(rel["to_actor"]),
		})

	return {
		"relation_types": relation_types,
		"relations": relations,
		"relation_seq": _relation_seq,
	}


func restore(d: Dictionary) -> void:
	_type_declarations.clear()
	_relations.clear()
	_actor_relations.clear()
	faults.clear()
	_relation_seq = 0

	for raw in d.get("relation_types", []):
		var decl: Dictionary = raw as Dictionary
		# avoid trace side effects during restore
		if not _load_relation_type(decl):
			continue

	var declared_seq := int(d.get("relation_seq", 0))

	var rel_payloads: Array = d.get("relations", [])
	for entry in rel_payloads:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var rel: Dictionary = entry as Dictionary
		var rel_id := StringName(rel.get("relation_id", rel.get("id", "")))
		if rel_id == &"":
			continue
		var r_type := StringName(rel.get("type", ""))
		if r_type == &"" or not _type_declarations.has(String(r_type)):
			_fault(EQError.CONDITION_LINE_UNKNOWN, "relation refers to undeclared type", {"relation_id": String(rel_id)})
			continue
		var from_actor: StringName = StringName(rel.get("from", ""))
		var to_actor: StringName = StringName(rel.get("to", ""))
		if from_actor == &"" or to_actor == &"":
			_fault(EQError.CONDITION_LINE_UNKNOWN, "relation endpoint must not be empty", {"relation_id": String(rel_id)})
			continue
		if int(_type_declarations[String(r_type)]["structure"]) == Structure.TREE and _has_parent_of_type(r_type, to_actor):
			_fault(EQError.CONDITION_LINE_UNKNOWN, "TREE relation constraint violated while restoring", {"relation_id": String(rel_id), "type": String(r_type), "to": String(to_actor)})
			continue
		_add_relation(rel_id, {
			"relation_id": rel_id,
			"type": r_type,
			"from_actor": from_actor,
			"to_actor": to_actor,
		})

	var parsed_seq := _parse_relation_seq_from_payload(rel_payloads)
	_relation_seq = max(declared_seq, parsed_seq)


# --- internals -----------------------------------------------------------------

func _load_relation_type(decl: Dictionary) -> bool:
	if typeof(decl) != TYPE_DICTIONARY:
		return false
	var name := StringName(decl.get("name", ""))
	if name == &"":
		return false
	var structure := int(decl.get("structure", Structure.TREE))
	if structure < Structure.TREE or structure > Structure.GRAPH:
		return false
	var dissolve := int(decl.get("on_dissolve", Dissolve.NONE))
	if dissolve < Dissolve.NONE or dissolve > Dissolve.SERIAL_SUTURE:
		return false
	_type_declarations[String(name)] = {
		"name": name,
		"category": StringName(decl.get("category", "")),
		"inverse": StringName(decl.get("inverse", "")),
		"structure": structure,
		"maintenance": decl.get("maintenance", null),
		"sweep": StringName(decl.get("sweep", DEFAULT_SWEEP)),
		"on_dissolve": dissolve,
	}
	return true


func _next_relation_id() -> StringName:
	_relation_seq += 1
	return StringName("eqm.rel.%d" % _relation_seq)


func _add_relation(relation_id: StringName, payload: Dictionary) -> void:
	_relations[relation_id] = {
		"relation_id": relation_id,
		"type": payload["type"],
		"from_actor": payload["from_actor"],
		"to_actor": payload["to_actor"],
	}
	var actor_list := _actor_relations.get(String(payload["from_actor"]), [])
	if not (actor_list as Array).has(relation_id):
		actor_list.append(relation_id)
		actor_list.sort_custom(func(a, b): return String(a) < String(b))
		_actor_relations[String(payload["from_actor"])] = actor_list
	actor_list = _actor_relations.get(String(payload["to_actor"]), [])
	if not (actor_list as Array).has(relation_id):
		actor_list.append(relation_id)
		actor_list.sort_custom(func(a, b): return String(a) < String(b))
		_actor_relations[String(payload["to_actor"])] = actor_list


func _remove_relation(relation_id: StringName) -> void:
	if not _relations.has(relation_id):
		return
	var rel: Dictionary = _relations[relation_id]
	_relations.erase(relation_id)
	var from_key := String(rel["from_actor"])
	var to_key := String(rel["to_actor"])
	var from_list: Array = _actor_relations.get(from_key, [])
	var from_idx := from_list.find(relation_id)
	if from_idx != -1:
		from_list.remove_at(from_idx)
		if from_list.is_empty():
			_actor_relations.erase(from_key)
		else:
			_actor_relations[from_key] = from_list
	var to_list: Array = _actor_relations.get(to_key, [])
	var to_idx := to_list.find(relation_id)
	if to_idx != -1:
		to_list.remove_at(to_idx)
		if to_list.is_empty():
			_actor_relations.erase(to_key)
		else:
			_actor_relations[to_key] = to_list


func _has_parent_of_type(type: StringName, actor: StringName) -> bool:
	for rel_id in relation_ids():
		var rel: Dictionary = _relations[rel_id]
		if rel["type"] == type and rel["to_actor"] == actor:
			return true
	return false


func _incoming_of_type(type: StringName, actor: StringName) -> Array:
	var out: Array = []
	for rel_id in relation_ids():
		var rel: Dictionary = _relations[rel_id]
		if rel["type"] == type and rel["to_actor"] == actor:
			out.append(rel_id)
	return out


func _outgoing_of_type(type: StringName, actor: StringName) -> Array:
	var out: Array = []
	for rel_id in relation_ids():
		var rel: Dictionary = _relations[rel_id]
		if rel["type"] == type and rel["from_actor"] == actor:
			out.append(rel_id)
	return out


func _try_serial_rebound(rel: Dictionary) -> StringName:
	var type_name := StringName(rel["type"])
	var incoming := _incoming_of_type(type_name, rel["from_actor"])
	var outgoing := _outgoing_of_type(type_name, rel["to_actor"])
	if incoming.size() > 1 or outgoing.size() > 1:
		return &""
	if incoming.size() == 0 and outgoing.size() == 0:
		return &""
	if rel["from_actor"] == rel["to_actor"]:
		return &""
	var from_actor: StringName
	var to_actor: StringName
	if incoming.size() == 1 and outgoing.size() == 1:
		var left: Dictionary = _relations[incoming[0]]
		var right: Dictionary = _relations[outgoing[0]]
		from_actor = left["from_actor"]
		to_actor = right["to_actor"]
	elif incoming.size() == 1:
		var left: Dictionary = _relations[incoming[0]]
		from_actor = left["from_actor"]
		to_actor = rel["to_actor"]
	else:
		var right: Dictionary = _relations[outgoing[0]]
		from_actor = rel["from_actor"]
		to_actor = right["to_actor"]
	var rebound := _next_relation_id()
	_add_relation(rebound, {"type": type_name, "from_actor": from_actor, "to_actor": to_actor})
	return rebound


func _parse_relation_seq_from_payload(payloads: Array) -> int:
	var max_seq := 0
	for entry in payloads:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var payload := entry as Dictionary
		var rel_id := String(payload.get("relation_id", payload.get("id", "")))
		if rel_id.begins_with("eqm.rel."):
			var parts := rel_id.split(".")
			if parts.size() == 3:
				var seq := int(parts[2])
				if seq > max_seq:
					max_seq = seq
	return max_seq


func _record(fields: Dictionary) -> void:
	if _trace != null:
		_trace.record(fields)


func _fault(code: StringName, message: String, context: Dictionary = {}) -> void:
	faults.append({
		"code": code,
		"recoverability": EQError.recoverability_of(code),
		"message": message,
		"context": context,
	})
