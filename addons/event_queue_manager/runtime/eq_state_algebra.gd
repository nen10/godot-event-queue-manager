class_name EQStateAlgebra extends RefCounted
## L3 state stack algebra over EQEventLines (SEM §5.7).
## The stack body is stored in EQEventLines only; this class stores only
## declarative pair rules + wrapper stacks (serializable data only).

const EQEventLines := preload("eq_event_lines.gd")
const EQError := preload("eq_error.gd")

enum Rule { CANCEL, EXCLUDE, COEXIST }

## Structured runtime errors, mirroring EQEventLines fault behavior.
var faults: Array[Dictionary] = []

var lines: EQEventLines
var relations = null

## declaration key -> {state_a: StringName, state_b: StringName, rule: Rule}
var _pair_rules: Dictionary = {}
## state token -> sorted declaration keys containing that token.  Pair lookup is
## on the grant/query hot path, so declarations maintain this deterministic
## index instead of rescanning the complete rule table for every state token.
var _pair_rule_keys_by_state: Dictionary = {}
## actor -> state -> [{name: StringName, params: Dictionary}]
var _wrappers: Dictionary = {}

var _trace = null


func _init(p_lines: EQEventLines, p_trace = null, p_relations = null) -> void:
	lines = p_lines if p_lines != null else EQEventLines.new(p_trace)
	_trace = p_trace
	relations = p_relations
	if p_trace != null:
		lines.set_trace(p_trace)


func _pair_key(state_a: StringName, state_b: StringName) -> String:
	return String(state_a) + "|" + String(state_b)


func _axis_line(actor: StringName, state_a: StringName, state_b: StringName) -> StringName:
	return StringName("eqm.axis.%s.%s__%s" % [actor, state_a, state_b])


func _state_line(actor: StringName, state: StringName) -> StringName:
	return StringName("eqm.state.%s.%s" % [actor, state])


func _is_valid_target(actor: StringName, state: StringName, context: StringName) -> bool:
	if actor == &"" or state == &"":
		_fault("%s requires non-empty actor and state" % context, EQError.CONDITION_LINE_ID_EMPTY)
		return false
	return true


## Declares or replaces a pair-level relation.
## Idempotent on the same ordered pair.
func declare_inv_pair(state_a: StringName, state_b: StringName, rule: int) -> bool:
	if state_a == &"" or state_b == &"":
		_fault("state pair elements must not be empty", EQError.CONDITION_LINE_ID_EMPTY)
		return false
	if rule < Rule.CANCEL or rule > Rule.COEXIST:
		_fault("unknown state pair rule: %d" % rule, EQError.CONDITION_LINE_UNKNOWN)
		return false
	_store_pair_rule(state_a, state_b, rule)
	return true


func _pair_for_state(state: StringName) -> Dictionary:
	var indexed_keys: Array = _pair_rule_keys_by_state.get(String(state), [])
	if indexed_keys.is_empty():
		return {}
	if indexed_keys.size() > 1:
		_fault("state %s is declared in multiple pair rules" % state, EQError.CONDITION_LINE_UNKNOWN)
	return _pair_rules[indexed_keys[0]]


func _store_pair_rule(state_a: StringName, state_b: StringName, rule: int) -> void:
	var key := _pair_key(state_a, state_b)
	_pair_rules[key] = {"state_a": state_a, "state_b": state_b, "rule": int(rule)}
	_index_pair_state(state_a, key)
	_index_pair_state(state_b, key)


func _index_pair_state(state: StringName, key: String) -> void:
	var state_key := String(state)
	var indexed_keys: Array = _pair_rule_keys_by_state.get(state_key, [])
	if indexed_keys.has(key):
		return
	indexed_keys.append(key)
	indexed_keys.sort()
	_pair_rule_keys_by_state[state_key] = indexed_keys


func _rule_for_state(state: StringName) -> int:
	var p := _pair_for_state(state)
	return int(p.get("rule", Rule.COEXIST))


func _line_for_state(actor: StringName, state: StringName) -> StringName:
	var pair := _pair_for_state(state)
	if pair.is_empty():
		return _state_line(actor, state)
	var rule := int(pair.get("rule", Rule.COEXIST))
	if rule == Rule.CANCEL:
		return _axis_line(actor, pair["state_a"], pair["state_b"])
	return _state_line(actor, state)


func _clear_to_zero(line_id: StringName) -> void:
	if not lines.has_line(line_id):
		return
	var current := lines.value_of(line_id)
	if current == 0:
		return
	lines.advance(line_id, -current)


## Grant adds or subtracts from the state's visible stack.
## For CANCEL, the pair declaration decides sign by declaration order.
func grant_state(actor: StringName, state: StringName, amount: int = 1) -> void:
	_grant_state(actor, state, amount, true)


func _grant_state(actor: StringName, state: StringName, amount: int, allow_relation_chain: bool) -> void:
	if not _is_valid_target(actor, state, &"grant_state"):
		return

	var current_state: StringName = state
	var actor_key := String(actor)
	var state_key := String(state)
	var state_wrappers: Array = []
	if _wrappers.has(actor_key) and (_wrappers[actor_key] as Dictionary).has(state_key):
		state_wrappers = _wrappers[actor_key][state_key]

	var relation_chain_wrappers: Array = []
	for w in state_wrappers:
		var wrapper: Dictionary = w
		var wrapper_name := StringName(wrapper.get("name", ""))
		var wrapper_kind := StringName(wrapper.get("kind", ""))
		match String(wrapper_kind):
			"inv_chain":
				current_state = _dual_of(current_state)
				_record_state_wrapper_applied(actor, current_state, wrapper_name, wrapper_kind)
			"relation_chain":
				if allow_relation_chain:
					relation_chain_wrappers.append({"state": current_state, "wrapper": wrapper})
				# Suppressed on chained grants (single level, no transitivity):
				# nothing applied, so nothing is traced.
			_:
				# Unknown/absent kind = inert declarative data (acceptance
				# vocabulary room) — never traced as an application.
				pass

	_apply_state_delta(actor, current_state, amount)
	for entry in relation_chain_wrappers:
		var wrapper: Dictionary = entry["wrapper"]
		var target_state: StringName = entry["state"]
		var wrapped := _apply_relation_chain(actor, target_state, amount, wrapper)
		var wrapper_name := StringName(wrapper.get("name", ""))
		var params := wrapper.get("params", {})
		if not (params is Dictionary):
			continue
		_record_state_wrapper_applied(actor, target_state, wrapper_name, &"relation_chain", wrapped)


func _dual_of(state: StringName) -> StringName:
	var pair := _pair_for_state(state)
	if pair.is_empty():
		_fault("inv_chain wrapper requires a declared pair for state: %s" % state, EQError.CONDITION_LINE_UNKNOWN)
		return state
	if pair["state_a"] == state:
		return pair["state_b"]
	if pair["state_b"] == state:
		return pair["state_a"]
	return state


func _apply_relation_chain(actor: StringName, state: StringName, amount: int, wrapper: Dictionary) -> Array:
	if relations == null:
		_fault("relation_chain wrapper requires relations to expand state grants", EQError.CONDITION_LINE_UNKNOWN)
		return []
	var params := wrapper.get("params", {})
	if not (params is Dictionary):
		return []
	var relation_type := StringName(params.get("relation_type", ""))
	var hop_cost := int(params.get("hop_cost", 0))
	var budget := int(params.get("budget", 0))
	var expanded: Array = relations.expand(actor, relation_type, hop_cost, budget)
	var chained: Array = []
	for target in expanded:
		if String(target) == String(actor):
			continue
		_grant_state(target, state, amount, false)
		chained.append(target)
	return chained


func _apply_state_delta(actor: StringName, state: StringName, amount: int) -> void:
	var pair := _pair_for_state(state)
	var rule := int(pair.get("rule", Rule.COEXIST))
	match rule:
		Rule.CANCEL:
			var axis := _axis_line(actor, pair["state_a"], pair["state_b"])
			if not lines.has_line(axis):
				lines.issue(axis, 0, 0)
			var delta := amount if state == pair["state_a"] else -amount
			lines.advance(axis, delta)
		Rule.EXCLUDE:
			var self_line := _state_line(actor, state)
			if not lines.has_line(self_line):
				lines.issue(self_line, 0, 0)
			var dual_state : StringName = pair["state_a"] if pair["state_b"] == state else pair["state_b"]
			_clear_to_zero(_state_line(actor, dual_state))
			lines.advance(self_line, amount)
		_:
			var line := _state_line(actor, state)
			if not lines.has_line(line):
				lines.issue(line, 0, 0)
			lines.advance(line, amount)


func _record_state_wrapper_applied(actor: StringName, state: StringName, wrapper: StringName, kind: StringName, chained: Array = []) -> void:
	if _trace == null:
		return
	var row := {
		"kind": "state_wrapper_applied",
		"actor": String(actor),
		"state": String(state),
		"wrapper": String(wrapper),
		"wrapper_kind": String(kind),
	}
	if not chained.is_empty() or kind == &"relation_chain":
		row["chained"] = _string_array(chained)
	_trace.record(row)


func _string_array(values: Array) -> Array:
	var out: Array = []
	for value in values:
		out.append(String(value))
	return out


## Sets the state's resolved stack to 0.
func clear_state(actor: StringName, state: StringName) -> void:
	if not _is_valid_target(actor, state, &"clear_state"):
		return
	_clear_to_zero(_line_for_state(actor, state))


## Returns the current active state for this pair.
## - CANCEL: axis sign (+ -> state_a, - -> state_b, 0 -> empty)
## - COEXIST/EXCLUDE/unknown: positive self stack -> self
func active_state(actor: StringName, state: StringName) -> StringName:
	if not _is_valid_target(actor, state, &"active_state"):
		return &""
	var pair := _pair_for_state(state)
	var rule := int(pair.get("rule", Rule.COEXIST))
	if rule == Rule.CANCEL:
		var axis := _axis_line(actor, pair["state_a"], pair["state_b"])
		var value := lines.value_of(axis)
		if value > 0:
			return pair["state_a"]
		if value < 0:
			return pair["state_b"]
		return &""
	return state if stacks_of(actor, state) > 0 else &""


## Returns directional stack only (CANCEL: reversed side = 0).
func stacks_of(actor: StringName, state: StringName) -> int:
	if not _is_valid_target(actor, state, &"stacks_of"):
		return 0
	var pair := _pair_for_state(state)
	var rule := int(pair.get("rule", Rule.COEXIST))
	if rule == Rule.CANCEL:
		var axis := _axis_line(actor, pair["state_a"], pair["state_b"])
		var value := lines.value_of(axis)
		if state == pair["state_a"]:
			return max(0, value)
		if state == pair["state_b"]:
			return max(0, -value)
		return 0
	var line := _state_line(actor, state)
	return max(0, lines.value_of(line))


## wrapper = {"name": StringName, "params": Dictionary, "kind": StringName (optional)}
## Params must be serializable data (no float / no callable).
func wrap_state(actor: StringName, state: StringName, wrapper: Dictionary) -> void:
	if not _is_valid_target(actor, state, &"wrap_state"):
		return
	if not _is_serializable_wrapper(wrapper):
		_fault("wrap_state wrapper must be {name: StringName, params: Dictionary[, kind: StringName]} and serializable", EQError.CONDITION_LINE_UNKNOWN)
		return
	var wrapper_kind := StringName(wrapper.get("kind", ""))
	if wrapper_kind == &"relation_chain" and not _is_valid_relation_chain_params(wrapper.get("params", {})):
		_fault("relation_chain wrapper params must be {relation_type: StringName, hop_cost: int > 0, budget: int > 0}", EQError.CONDITION_LINE_UNKNOWN)
		return
	var actor_key := String(actor)
	var state_key := String(state)
	if not _wrappers.has(actor_key):
		_wrappers[actor_key] = {}
	var actor_wrappers: Dictionary = _wrappers[actor_key]
	if not actor_wrappers.has(state_key):
		actor_wrappers[state_key] = []
	var entry := {"name": StringName(wrapper["name"]), "params": wrapper["params"].duplicate(true)}
	if wrapper.has("kind"):
		entry["kind"] = StringName(wrapper["kind"])
	actor_wrappers[state_key].append(entry)
	_wrappers[actor_key] = actor_wrappers
	if _trace != null:
		_trace.record({
			"kind": "state_wrapped",
			"actor": String(actor),
			"state": String(state),
			"wrapper": String(entry["name"]),
			"depth": int(actor_wrappers[state_key].size()),
		})


## Pops one wrapper from LIFO and returns it. Empty stack => fault + {}.
func unwrap_state(actor: StringName, state: StringName) -> Dictionary:
	if not _is_valid_target(actor, state, &"unwrap_state"):
		return {}
	var actor_key := String(actor)
	var state_key := String(state)
	if not _wrappers.has(actor_key) or not (_wrappers[actor_key] as Dictionary).has(state_key):
		_fault("unwrap_state on empty wrapper stack", EQError.CONDITION_LINE_UNKNOWN)
		return {}
	var state_wrappers: Array = _wrappers[actor_key][state_key]
	if state_wrappers.is_empty():
		_fault("unwrap_state on empty wrapper stack", EQError.CONDITION_LINE_UNKNOWN)
		return {}
	var depth := state_wrappers.size()
	var out := state_wrappers.pop_back()
	if _trace != null:
		_trace.record({
			"kind": "state_unwrapped",
			"actor": String(actor),
			"state": String(state),
			"wrapper": String(out["name"]),
			"depth": depth,
		})
	return out


func wrappers_of(actor: StringName, state: StringName) -> Array:
	if not _is_valid_target(actor, state, &"wrappers_of"):
		return []
	var actor_key := String(actor)
	var state_key := String(state)
	if not _wrappers.has(actor_key):
		return []
	var actor_wrappers : Dictionary = _wrappers[actor_key]
	if not actor_wrappers.has(state_key):
		return []
	return (actor_wrappers[state_key] as Array).duplicate(true)


func to_dict() -> Dictionary:
	var pair_ids: Array = []
	for key in _pair_rules.keys():
		pair_ids.append(String(key))
	pair_ids.sort()
	var pairs: Array = []
	for pair_id in pair_ids:
		var p: Dictionary = _pair_rules[pair_id]
		pairs.append({"state_a": String(p["state_a"]), "state_b": String(p["state_b"]), "rule": int(p["rule"])})

	var actor_ids: Array = _wrappers.keys()
	actor_ids.sort()
	var wrappers: Array = []
	for actor_key in actor_ids:
		var by_state: Dictionary = _wrappers[actor_key]
		var state_ids: Array = by_state.keys()
		state_ids.sort()
		for state_key in state_ids:
			var stack: Array = by_state[state_key]
			if stack.is_empty():
				continue
			var serialized: Array = []
			for w in stack:
				serialized.append({
					"name": String(w["name"]),
					"params": (w["params"] as Dictionary).duplicate(true),
				})
				if w.has("kind"):
					serialized[serialized.size() - 1]["kind"] = String(w["kind"])
			wrappers.append({"actor": actor_key, "state": state_key, "stack": serialized})
	return {
		"inv_pairs": pairs,
		"wrappers": wrappers,
	}


static func from_dict(d: Dictionary, lines: EQEventLines, trace = null) -> RefCounted:
	var script := load("res://addons/event_queue_manager/runtime/eq_state_algebra.gd")
	if script == null:
		return null
	var out := (script as GDScript).new(lines, trace)
	for p in d.get("inv_pairs", []):
		var pair := p as Dictionary
		out.declare_inv_pair(StringName(pair.get("state_a", "")), StringName(pair.get("state_b", "")), int(pair.get("rule", Rule.COEXIST)))
	for w in d.get("wrappers", []):
		var entry := w as Dictionary
		var actor := StringName(entry.get("actor", ""))
		var state := StringName(entry.get("state", ""))
		for sw in entry.get("stack", []):
			var wrapper := sw as Dictionary
			var payload := {
				"name": StringName(wrapper.get("name", "")),
				"params": wrapper.get("params", {}),
			}
			if wrapper.has("kind"):
				payload["kind"] = wrapper.get("kind", "")
			out.wrap_state(actor, state, payload)
	return out


func restore(d: Dictionary) -> void:
	_pair_rules.clear()
	_pair_rule_keys_by_state.clear()
	_wrappers.clear()
	for p in d.get("inv_pairs", []):
		var pair := p as Dictionary
		_store_pair_rule(
			StringName(pair.get("state_a", "")),
			StringName(pair.get("state_b", "")),
			int(pair.get("rule", Rule.COEXIST)),
		)
	for w in d.get("wrappers", []):
		var entry := w as Dictionary
		var actor_key := String(entry.get("actor", ""))
		var state_key := String(entry.get("state", ""))
		if actor_key == "" or state_key == "":
			continue
		var stack: Array = []
		for sw in entry.get("stack", []):
			var wrapper := sw as Dictionary
			var wrapped := {"name": StringName(wrapper.get("name", "")), "params": wrapper.get("params", {}).duplicate(true)}
			if wrapper.has("kind"):
				wrapped["kind"] = StringName(wrapper.get("kind", ""))
			stack.append(wrapped)
		if not _wrappers.has(actor_key):
			_wrappers[actor_key] = {}
		(_wrappers[actor_key] as Dictionary)[state_key] = stack


func _is_serializable_wrapper(wrapper: Dictionary) -> bool:
	if wrapper.size() < 2 or wrapper.size() > 3:
		return false
	if not wrapper.has("name") or not wrapper.has("params"):
		return false
	if typeof(wrapper.get("name", "")) != TYPE_STRING and typeof(wrapper.get("name", "")) != TYPE_STRING_NAME:
		return false
	if StringName(wrapper.get("name", "")) == &"":
		return false
	if typeof(wrapper["params"]) != TYPE_DICTIONARY:
		return false
	if not _is_serializable(wrapper["params"]):
		return false
	if wrapper.has("kind"):
		if typeof(wrapper.get("kind", "")) != TYPE_STRING and typeof(wrapper.get("kind", "")) != TYPE_STRING_NAME:
			return false
	return true


func _is_valid_relation_chain_params(params) -> bool:
	if not (params is Dictionary):
		return false
	var relation_type: Variant = params.get("relation_type", "")
	if typeof(relation_type) != TYPE_STRING and typeof(relation_type) != TYPE_STRING_NAME:
		return false
	if StringName(relation_type) == &"":
		return false
	if typeof(params.get("hop_cost", 0)) != TYPE_INT or int(params.get("hop_cost", 0)) <= 0:
		return false
	if typeof(params.get("budget", 0)) != TYPE_INT or int(params.get("budget", 0)) <= 0:
		return false
	return true


func _is_serializable(v) -> bool:
	match typeof(v):
		TYPE_NIL:
			return true
		TYPE_BOOL:
			return true
		TYPE_INT:
			return true
		TYPE_STRING:
			return true
		TYPE_STRING_NAME:
			return true
		TYPE_ARRAY:
			for x in v:
				if not _is_serializable(x):
					return false
			return true
		TYPE_DICTIONARY:
			for key in v:
				if typeof(key) != TYPE_STRING and typeof(key) != TYPE_STRING_NAME:
					return false
				if not _is_serializable(v[key]):
					return false
			return true
		TYPE_FLOAT:
			return false
		_:
			return false


func _fault(message: String, code: StringName = EQError.CONDITION_LINE_UNKNOWN) -> void:
	faults.append({
		"code": code,
		"recoverability": EQError.recoverability_of(code),
		"message": message,
		"context": {},
	})
