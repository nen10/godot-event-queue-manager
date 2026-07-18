class_name EQEventLines
extends RefCounted
## L3 event-line backend (SEM §4.3/§4.6/§4.7, EQM-112).
##
## A line is DATA ONLY: `{id: StringName, value: int, rate: int}` (Q33). Two
## advance paths exist and no others: (a) per-tick polling of watched, non-frozen
## lines (`poll_tick`); (b) explicit `advance(line, amount)` from a resolving
## event's effect. Rate changes are re-rates, never `due_tick` rewrites.
##
## The primary line (global tick) is a MIRROR of `EQScheduler.current_tick`,
## synced via `sync_primary` (rate 0 — the scheduler owns tick truth; the
## pipeline (EQM-113) is the single sync point).
##
## Every change records an `event_line_progressed` trace line with a `cause`
## (issued / advanced / poll / re_rated / sweep_rule / modifier_added /
## modifier_removed) — SEM §11. Faults
## (unknown line) are recorded in `faults`, never thrown; acting on them is the
## resilience mode's job (EQM-113).
##
## Scan orders are fixed for determinism: poll = line id ascending; sweep rules
## = registration order × actor_id ascending. to_dict writes ids sorted, so a
## restored table scans identically. Sweep-rule callables are never serialized —
## only their names (same rule as named predicates, SEM §5.5).

## Canonical primary-line id. Must equal EQActionDefinition.PRIMARY_LINE_ID
## (L2 sugar references it); the equality is test-enforced instead of a
## preload dependency from L3 onto L2 resources.
const PRIMARY_LINE_ID := &"eqm.line.primary"

var faults: Array[Dictionary] = []

var _lines: Dictionary = {}          # id -> {"value": int, "rate": int, "modifiers": Array[Dictionary]}
var _effective_rates: Dictionary = {}  # id -> derived effective rate (never serialized)
var _counter_seq: int = 0
var _counter_ids: Dictionary = {}     # generated counter id -> true (serialized provenance)
var _modifier_seq: int = 0
var _sweep_rules: Array[Dictionary] = []  # [{"name": StringName, "callable": Callable}] in registration order
var _trace = null                    # EQTrace or null (observation only)


func _init(trace = null) -> void:
	_trace = trace
	_lines[PRIMARY_LINE_ID] = {"value": 0, "rate": 0, "modifiers": []}
	_effective_rates[PRIMARY_LINE_ID] = 0


func set_trace(trace) -> void:
	_trace = trace


# --- lines ----------------------------------------------------------------

## Issues a new line. Returns false (and records nothing) when the id already
## exists — issuance is not an update path.
func issue(id: StringName, value: int = 0, rate: int = 0) -> bool:
	# The generated-counter namespace is runtime-owned. Reserving it prevents a
	# consumer line from being silently captured by a later COUNTER bind.
	if String(id).begins_with("eqm.counter."):
		return false
	return _issue_line(id, value, rate)


func _issue_line(id: StringName, value: int, rate: int) -> bool:
	if id == &"" or _lines.has(id):
		return false
	_lines[id] = {"value": value, "rate": rate, "modifiers": []}
	_refresh_effective_rate(id)
	_record({"kind": "event_line_progressed", "cause": "issued", "line": String(id), "to": value, "rate": rate})
	return true


## Issues a decremental/incremental counter line with a deterministic id
## (`eqm.counter.<seq>`). Issuance order is unique (Q20), so ids are stable
## across replay.
func issue_counter(start: int) -> StringName:
	while true:
		_counter_seq += 1
		var id := StringName("eqm.counter.%d" % _counter_seq)
		if _issue_line(id, start, 0):
			_counter_ids[id] = true
			return id
	return &""


func has_line(id: StringName) -> bool:
	return _lines.has(id)


func value_of(id: StringName) -> int:
	return int(_lines[id]["value"]) if _lines.has(id) else 0


func rate_of(id: StringName) -> int:
	return int(_lines[id]["rate"]) if _lines.has(id) else 0


## Returns the effective rate for an id: latest override if present, else base + add stack sum.
func effective_rate_of(id: StringName) -> int:
	if not _lines.has(id):
		return 0
	return int(_effective_rates[id])


func line_ids() -> Array:
	var ids := _lines.keys()
	# StringName's own sort is intern/address order (nondeterministic across
	# processes — verified on 4.7); order by CONTENT for replay determinism.
	ids.sort_custom(func(a, b): return String(a) < String(b))
	return ids


## Explicit advance from an event effect (path (b)). Unknown line -> recorded
## fault, no silent no-op.
func advance(id: StringName, amount: int) -> bool:
	if not _lines.has(id):
		_fault(id, "advance on unknown line")
		return false
	var from := int(_lines[id]["value"])
	_lines[id]["value"] = from + amount
	_record({"kind": "event_line_progressed", "cause": "advanced", "line": String(id), "from": from, "to": from + amount})
	return true


## Re-rate (rate change absorbed as data, SEM §4.6). Unknown line -> fault.
func re_rate(id: StringName, new_rate: int) -> bool:
	if not _lines.has(id):
		_fault(id, "re_rate on unknown line")
		return false
	var from := int(_lines[id]["rate"])
	_lines[id]["rate"] = new_rate
	_refresh_effective_rate(id)
	_record({"kind": "event_line_progressed", "cause": "re_rated", "line": String(id), "rate_from": from, "rate_to": new_rate})
	return true


## Adds a rate modifier and returns the new modifier id (`eqm.mod.<seq>`).
## Returns empty StringName on failure.
func add_rate_modifier(line_id: StringName, kind: String, value: int) -> StringName:
	if not _lines.has(line_id):
		_fault(line_id, "add_rate_modifier on unknown line")
		return &""
	if kind != "add" and kind != "override":
		_fault(line_id, "add_rate_modifier with unsupported kind")
		return &""
	var effective_from := effective_rate_of(line_id)
	_modifier_seq += 1
	var modifier_id := StringName("eqm.mod.%d" % _modifier_seq)
	var modifier := {"id": modifier_id, "kind": kind, "value": int(value)}
	_lines[line_id]["modifiers"].append(modifier)
	_refresh_effective_rate(line_id)
	var effective_to := effective_rate_of(line_id)
	_record({"kind": "event_line_progressed", "cause": "modifier_added", "line": String(line_id), "modifier_id": String(modifier_id), "effective_from": effective_from, "effective_to": effective_to})
	return modifier_id


## Removes a rate modifier by id. Unknown line / missing modifier are faults.
func remove_rate_modifier(line_id: StringName, modifier_id: StringName) -> bool:
	if not _lines.has(line_id):
		_fault(line_id, "remove_rate_modifier on unknown line")
		return false
	var modifiers: Array = _lines[line_id].get("modifiers", [])
	var removed_idx := -1
	for i in range(modifiers.size()):
		var modifier: Dictionary = modifiers[i]
		if modifier["id"] == modifier_id:
			removed_idx = i
			break
	if removed_idx == -1:
		_fault(line_id, "remove_rate_modifier on unknown modifier", EQError.CONDITION_LINE_UNKNOWN)
		return false
	var effective_from := effective_rate_of(line_id)
	modifiers.remove_at(removed_idx)
	_lines[line_id]["modifiers"] = modifiers
	_refresh_effective_rate(line_id)
	var effective_to := effective_rate_of(line_id)
	_record({"kind": "event_line_progressed", "cause": "modifier_removed", "line": String(line_id), "modifier_id": String(modifier_id), "effective_from": effective_from, "effective_to": effective_to})
	return true


## One tick of sparse polling (path (a)): only lines that are watched AND
## non-frozen (rate != 0) advance, in line-id ascending order (determinism).
## `watched` is a set-shaped Dictionary (id -> true), e.g. from derive_watched().
func poll_tick(watched: Dictionary) -> void:
	for id in _live_watched_ids(watched):
		var rate := effective_rate_of(id)
		if rate == 0:
			continue
		var from := int(_lines[id]["value"])
		_lines[id]["value"] = from + rate
		_record({"kind": "event_line_progressed", "cause": "poll", "line": String(id), "from": from, "to": from + rate})


## Mirrors the primary line to the scheduler's current tick (the scheduler owns
## tick truth; the pipeline is the single caller). Records NOTHING: the tick's
## advancement is already canonical in resolved records — a mirror sync is
## derivative observation, and tracing it would perturb existing goldens
## (EQM-113 decision, POLICY.md).
func sync_primary(tick: int) -> void:
	_lines[PRIMARY_LINE_ID]["value"] = tick


## Watched set derived from pending conditions (SEM §4.3): the union of line
## ids referenced by the given bound-term arrays (EQConditionEval.bind output).
static func derive_watched(bound_term_sets: Array) -> Dictionary:
	var watched := {}
	for terms in bound_term_sets:
		for term in terms:
			if term is Dictionary and term.has("line_id"):
				watched[term["line_id"]] = true
	return watched


## Evaluation-context view (EQConditionEval ctx["lines"]). A copy — cache per
## sweep, do not mutate.
func ctx_lines() -> Dictionary:
	var out := {}
	for id in _lines:
		out[id] = int(_lines[id]["value"])
	return out


# --- sweep rules (pattern (2), SEM §4.7) -----------------------------------

## Registers (or replaces — idempotent setup) a named sweep rule. The callable
## shape is `func(actor_id: StringName, data: Dictionary, lines: EQEventLines)`.
## Only the NAME is ever serialized.
func register_sweep_rule(name: StringName, rule: Callable) -> bool:
	if name == &"":
		_fault(name, "sweep rule name must not be empty", EQError.CONDITION_PREDICATE_NAME_EMPTY)
		return false
	for entry in _sweep_rules:
		if entry["name"] == name:
			entry["callable"] = rule
			return true
	_sweep_rules.append({"name": name, "callable": rule})
	return true


func sweep_rule_names() -> Array:
	var out := []
	for entry in _sweep_rules:
		out.append(entry["name"])
	return out


## Runs every registered rule as the primary-tick system event: registration
## order, actor_id ascending within a rule (SEM §4.7 determinism).
func run_sweep_rules(registry) -> void:
	var actor_ids: Array = registry.actor_ids()
	# Content order, not StringName intern order (same determinism fix as line_ids).
	actor_ids.sort_custom(func(a, b): return String(a) < String(b))
	for entry in _sweep_rules:
		var rule: Callable = entry["callable"]
		for actor_id in actor_ids:
			rule.call(actor_id, registry.get_state(actor_id).data, self)
		_record({"kind": "event_line_progressed", "cause": "sweep_rule", "rule": String(entry["name"]), "actors": actor_ids.size()})


# --- serialization (callables excluded; names only) ------------------------

func to_dict() -> Dictionary:
	var lines := []
	for id in line_ids():
		var line := {"id": String(id), "value": int(_lines[id]["value"]), "rate": int(_lines[id]["rate"])}
		var modifiers: Array = _lines[id].get("modifiers", [])
		if modifiers.size() > 0:
			var serialized_modifiers := []
			for i in range(modifiers.size()):
				var m: Dictionary = modifiers[i]
				serialized_modifiers.append({"id": String(m["id"]), "kind": String(m["kind"]), "value": int(m["value"])})
			line["modifiers"] = serialized_modifiers
		lines.append(line)
	var counter_ids := _counter_ids.keys()
	counter_ids.sort_custom(func(a, b): return String(a) < String(b))
	return {
		"lines": lines,
		"counter_seq": _counter_seq,
		"counter_ids": counter_ids.map(func(id): return String(id)),
		"modifier_seq": _modifier_seq,
		"sweep_rules": sweep_rule_names().map(func(n): return String(n)),
	}


## Restores values/rates/counter_seq. Sweep-rule callables must be re-registered
## by acceptance; the stored names let the loader verify registration (EQM-117).
static func from_dict(d: Dictionary, trace = null) -> EQEventLines:
	var el := EQEventLines.new(trace)
	el.restore_values(d)
	return el


## In-place restore that PRESERVES the registered sweep rules and the attached
## trace (the load path, EQM-117: acceptance re-registers rules on the live
## instance before loading; only the data is replaced).
func restore_values(d: Dictionary) -> void:
	_lines.clear()
	_effective_rates.clear()
	_counter_ids.clear()
	_lines[PRIMARY_LINE_ID] = {"value": 0, "rate": 0, "modifiers": []}
	for i in range(d.get("lines", []).size()):
		var line_payload: Dictionary = d.get("lines", [])[i]
		var modifiers: Array = []
		var serialized_modifiers: Array = line_payload.get("modifiers", [])
		for j in range(serialized_modifiers.size()):
			var modifier_payload: Dictionary = serialized_modifiers[j]
			modifiers.append({
				"id": StringName(modifier_payload["id"]),
				"kind": String(modifier_payload["kind"]),
				"value": int(modifier_payload["value"]),
			})
		_lines[StringName(line_payload["id"])] = {"value": int(line_payload["value"]), "rate": int(line_payload["rate"]), "modifiers": modifiers}
	_counter_seq = int(d.get("counter_seq", 0))
	var counter_values = d.get("counter_ids", null)
	if counter_values is Array:
		for id_value in counter_values:
			var counter_id := StringName(id_value)
			if _lines.has(counter_id):
				_counter_ids[counter_id] = true
	else:
		# Historical event-line payloads predate explicit provenance. Only the
		# deterministic generated namespace at or below counter_seq can migrate.
		for id in _lines:
			var text := String(id)
			if not text.begins_with("eqm.counter."):
				continue
			var suffix := text.trim_prefix("eqm.counter.")
			if suffix.is_valid_int() and int(suffix) >= 1 and int(suffix) <= _counter_seq:
				_counter_ids[id] = true
	_modifier_seq = int(d.get("modifier_seq", 0))
	_rebuild_effective_rates()


func _live_watched_ids(watched: Dictionary) -> Array:
	var ids: Array = []
	var seen := {}
	for raw_id in watched:
		if typeof(raw_id) != TYPE_STRING and typeof(raw_id) != TYPE_STRING_NAME:
			continue
		var id := StringName(raw_id)
		if not _lines.has(id):
			continue
		var content := String(id)
		if seen.has(content):
			continue
		seen[content] = true
		ids.append(id)
	ids.sort_custom(func(a, b): return String(a) < String(b))
	return ids


func _calculate_effective_rate(line: Dictionary) -> int:
	var override_value := 0
	var has_override := false
	var add_value := 0
	var modifiers: Array = line.get("modifiers", [])
	for modifier in modifiers:
		var kind := String((modifier as Dictionary).get("kind", ""))
		if kind == "override":
			override_value = int((modifier as Dictionary).get("value", 0))
			has_override = true
		elif kind == "add":
			add_value += int((modifier as Dictionary).get("value", 0))
	return override_value if has_override else int(line.get("rate", 0)) + add_value


func _refresh_effective_rate(id: StringName) -> void:
	_effective_rates[id] = _calculate_effective_rate(_lines[id])


func _rebuild_effective_rates() -> void:
	_effective_rates.clear()
	for id in _lines:
		_refresh_effective_rate(StringName(id))


func _record(fields: Dictionary) -> void:
	if _trace != null:
		_trace.record(fields)


func _fault(id: StringName, message: String, code: StringName = EQError.CONDITION_LINE_UNKNOWN) -> void:
	faults.append({
		"code": code,
		"recoverability": EQError.recoverability_of(code),
		"message": message,
		"context": {"line": String(id)},
	})
