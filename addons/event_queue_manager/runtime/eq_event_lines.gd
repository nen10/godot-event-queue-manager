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
## (issued / advanced / poll / re_rated / sweep_rule) — SEM §11. Faults
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

var _lines: Dictionary = {}          # id -> {"value": int, "rate": int}
var _counter_seq: int = 0
var _sweep_rules: Array[Dictionary] = []  # [{"name": StringName, "callable": Callable}] in registration order
var _trace = null                    # EQTrace or null (observation only)


func _init(trace = null) -> void:
	_trace = trace
	_lines[PRIMARY_LINE_ID] = {"value": 0, "rate": 0}


func set_trace(trace) -> void:
	_trace = trace


# --- lines ----------------------------------------------------------------

## Issues a new line. Returns false (and records nothing) when the id already
## exists — issuance is not an update path.
func issue(id: StringName, value: int = 0, rate: int = 0) -> bool:
	if id == &"" or _lines.has(id):
		return false
	_lines[id] = {"value": value, "rate": rate}
	_record({"kind": "event_line_progressed", "cause": "issued", "line": String(id), "to": value, "rate": rate})
	return true


## Issues a decremental/incremental counter line with a deterministic id
## (`eqm.counter.<seq>`). Issuance order is unique (Q20), so ids are stable
## across replay.
func issue_counter(start: int) -> StringName:
	_counter_seq += 1
	var id := StringName("eqm.counter.%d" % _counter_seq)
	issue(id, start, 0)
	return id


func has_line(id: StringName) -> bool:
	return _lines.has(id)


func value_of(id: StringName) -> int:
	return int(_lines[id]["value"]) if _lines.has(id) else 0


func rate_of(id: StringName) -> int:
	return int(_lines[id]["rate"]) if _lines.has(id) else 0


func line_ids() -> Array:
	var ids := _lines.keys()
	ids.sort()
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
	_record({"kind": "event_line_progressed", "cause": "re_rated", "line": String(id), "rate_from": from, "rate_to": new_rate})
	return true


## One tick of sparse polling (path (a)): only lines that are watched AND
## non-frozen (rate != 0) advance, in line-id ascending order (determinism).
## `watched` is a set-shaped Dictionary (id -> true), e.g. from derive_watched().
func poll_tick(watched: Dictionary) -> void:
	for id in line_ids():
		if not watched.has(id):
			continue
		var rate := int(_lines[id]["rate"])
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
	actor_ids.sort()
	for entry in _sweep_rules:
		var rule: Callable = entry["callable"]
		for actor_id in actor_ids:
			rule.call(actor_id, registry.get_state(actor_id).data, self)
		_record({"kind": "event_line_progressed", "cause": "sweep_rule", "rule": String(entry["name"]), "actors": actor_ids.size()})


# --- serialization (callables excluded; names only) ------------------------

func to_dict() -> Dictionary:
	var lines := []
	for id in line_ids():
		lines.append({"id": String(id), "value": int(_lines[id]["value"]), "rate": int(_lines[id]["rate"])})
	return {
		"lines": lines,
		"counter_seq": _counter_seq,
		"sweep_rules": sweep_rule_names().map(func(n): return String(n)),
	}


## Restores values/rates/counter_seq. Sweep-rule callables must be re-registered
## by acceptance; the stored names let the loader verify registration (EQM-117).
static func from_dict(d: Dictionary, trace = null) -> EQEventLines:
	var el := EQEventLines.new(trace)
	el._lines.clear()
	el._lines[PRIMARY_LINE_ID] = {"value": 0, "rate": 0}
	for line in d.get("lines", []):
		el._lines[StringName(line["id"])] = {"value": int(line["value"]), "rate": int(line["rate"])}
	el._counter_seq = int(d.get("counter_seq", 0))
	return el


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
