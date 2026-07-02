extends RefCounted
## EQM-118 — reducibility re-proof through the PRODUCT model (SEM §16.1):
## CTB / Energy / Wait-Turn built from the implemented conditions + event-line
## pipeline (EQM-111/112/113) must produce the same resolution subsequence
## (tick, actor, priority — extracted from the canonical trace, not a hand-kept
## order array) as the dedicated policies. This replaces EQM-053's test-local
## simulation with the shipped machinery; the old test remains as the
## dedicated↔abstract-sim layer. A golden fixture pins the pipeline CTB trace.

const EQRuntime := preload("res://addons/event_queue_manager/runtime/eq_runtime.gd")
const EQReservationRuntime := preload("res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd")
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition := preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQConditionSpec := preload("res://addons/event_queue_manager/resources/eq_condition_spec.gd")
const EQActionResult := preload("res://addons/event_queue_manager/runtime/eq_action_result.gd")
const EQCTBPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_ctb_policy.gd")
const EQEnergyPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_energy_policy.gd")
const EQWaitTurnPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_wait_turn_policy.gd")

const SCALE := 100
const BASE := 100
const GOLDEN_CASE := "reducibility_ctb_pipeline"
const GOLDEN_PATH := "res://tests/golden/reducibility_ctb_pipeline.trace.jsonl"

# The EQM-053 matrices, verbatim (incl. non-divisor speeds and equal-key ties).
const CTB_CASES := [
	{"name": "speed/cost matrix", "turns": 18, "actors": [
		{"id": &"quick", "speed": 25, "costs": [100, 75, 150]},
		{"id": &"steady", "speed": 10, "costs": [100, 200, 50]},
		{"id": &"heavy", "speed": 40, "costs": [200, 100, 50]}]},
	{"name": "equal due/priority -> sequence", "turns": 12, "actors": [
		{"id": &"first", "speed": 20, "costs": [100]},
		{"id": &"second", "speed": 20, "costs": [100]},
		{"id": &"slow", "speed": 10, "costs": [100]}]},
	{"name": "non-divisor speeds", "turns": 15, "actors": [
		{"id": &"odd", "speed": 30, "costs": [100, 150]},
		{"id": &"prime", "speed": 7, "costs": [100]},
		{"id": &"mid", "speed": 13, "costs": [100, 50]}]},
]
const ENERGY_CASES := [
	{"name": "speed/cost/carry matrix", "turns": 20, "actors": [
		{"id": &"swift", "speed": 17, "costs": [100, 50, 150]},
		{"id": &"even", "speed": 10, "costs": [100, 200, 50]},
		{"id": &"slow", "speed": 7, "costs": [75, 125, 100]}]},
	{"name": "equal threshold -> sequence", "turns": 12, "actors": [
		{"id": &"first", "speed": 10, "costs": [100]},
		{"id": &"second", "speed": 10, "costs": [100]},
		{"id": &"third", "speed": 20, "costs": [200]}]},
]
const WAIT_CASES := [
	{"name": "wait/cost/agility matrix", "turns": 18, "actors": [
		{"id": &"quick", "wait": 3, "agility": 5, "costs": [6, 2, 5]},
		{"id": &"heavy", "wait": 5, "agility": 7, "costs": [4, 8, 3]},
		{"id": &"late", "wait": 8, "agility": 1, "costs": [3, 9]}]},
	{"name": "equal wait -> agility -> sequence", "turns": 12, "actors": [
		{"id": &"low_first", "wait": 4, "agility": 2, "costs": [4]},
		{"id": &"high", "wait": 4, "agility": 9, "costs": [4]},
		{"id": &"low_second", "wait": 4, "agility": 2, "costs": [4]}]},
]


static func run(t) -> void:
	for c in CTB_CASES:
		var dedicated := _dedicated_pairs(_ctb_dedicated(c["actors"], c["turns"]))
		var product := _resolved_pairs(_ctb_pipeline(c["actors"], c["turns"]))
		t.eq(product, dedicated, "CTB via the product model matches the dedicated trace (%s)" % c["name"])
	for c in ENERGY_CASES:
		var dedicated := _dedicated_pairs(_energy_dedicated(c["actors"], c["turns"]))
		var product := _resolved_pairs(_energy_pipeline(c["actors"], c["turns"]))
		t.eq(product, dedicated, "Energy via the product model matches the dedicated trace (%s)" % c["name"])
	for c in WAIT_CASES:
		var dedicated := _dedicated_pairs(_wait_dedicated(c["actors"], c["turns"]))
		var product := _resolved_pairs(_wait_pipeline(c["actors"], c["turns"]))
		t.eq(product, dedicated, "Wait-Turn via the product model matches the dedicated trace (%s)" % c["name"])
	_golden(t)


# --- trace projection (the comparison is trace-derived on BOTH sides) --------

static func _resolved_pairs(rr: EQReservationRuntime) -> Array:
	return _pairs_from(rr.runtime.trace())


static func _dedicated_pairs(rt: EQRuntime) -> Array:
	return _pairs_from(rt.trace())


static func _pairs_from(trace) -> Array:
	var out := []
	for r in trace.records():
		if String(r.get("kind", "")) == "resolved":
			out.append([int(r["tick"]), String(r["actor"]), int(r["priority"])])
	return out


static func _next_cost(counts: Dictionary, actor: Dictionary) -> int:
	var costs: Array = actor.get("costs", [BASE])
	var i := int(counts.get(actor["id"], 0))
	counts[actor["id"]] = i + 1
	return int(costs[i % costs.size()]) if not costs.is_empty() else BASE


# --- dedicated drivers (the EQM-053 runtime loop) ----------------------------

static func _dedicated(policy, actors: Array, turns: int, seed_stats: Callable) -> EQRuntime:
	var rt := EQRuntime.new()
	rt.emit_engine_diagnostics = false
	for a in actors:
		var state = rt.register_actor(a["id"])
		seed_stats.call(state, a)
	policy.seed(rt, rt.registry.actor_ids())
	var counts := {}
	var by_id := {}
	for a in actors:
		by_id[a["id"]] = a
	for _i in range(turns):
		var e = rt.advance()
		if e == null:
			break
		policy.on_turn_finished(rt, e.actor_id, EQActionResult.new(_next_cost(counts, by_id[e.actor_id]), 0))
	return rt


static func _ctb_dedicated(actors: Array, turns: int) -> EQRuntime:
	return _dedicated(EQCTBPolicy.new(), actors, turns, func(state, a): state.data["speed"] = int(a["speed"]))


static func _energy_dedicated(actors: Array, turns: int) -> EQRuntime:
	return _dedicated(EQEnergyPolicy.new(), actors, turns, func(state, a): state.data["speed"] = int(a["speed"]))


static func _wait_dedicated(actors: Array, turns: int) -> EQRuntime:
	return _dedicated(EQWaitTurnPolicy.new(), actors, turns, func(state, a):
		state.data["wait"] = int(a["wait"])
		state.data["agility"] = int(a["agility"]))


# --- product drivers (conditions + event-lines through the pipeline) ---------

static func _gated(actor: StringName, line: StringName, threshold: int, cmp: int, priority: int) -> EQReservation:
	var d := EQActionDefinition.new()
	d.kind = EQActionDefinition.Kind.IMMEDIATE
	d.priority = priority
	var spec := EQConditionSpec.new()
	spec.type = EQConditionSpec.Type.LINE_THRESHOLD
	spec.line_id = line
	spec.threshold = threshold
	spec.comparison = cmp
	d.solve_conditions = [spec]
	return EQReservation.new(actor, d)


static func _drive(rr: EQReservationRuntime, turns: int, on_act: Callable) -> void:
	var resolved := 0
	var safety := 0
	while resolved < turns and safety < 100000:
		var res = rr.resolve_next()
		if res == null:
			rr.step_tick()
			safety += 1
			continue
		resolved += 1
		on_act.call(res)


## CTB: per-entity CT line at rate = speed; act at cost*scale; NO-CARRY reset
## (the dedicated policy reschedules from scratch — ceil(cost*scale/speed)).
static func _ctb_pipeline(actors: Array, turns: int) -> EQReservationRuntime:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	var counts := {}
	var by_id := {}
	for a in actors:
		by_id[a["id"]] = a
		rr.runtime.register_actor(a["id"])
		rr.lines.issue(StringName("ct.%s" % a["id"]), 0, int(a["speed"]))
		rr.submit(_gated(a["id"], StringName("ct.%s" % a["id"]), BASE * SCALE, EQConditionSpec.Comparison.GE, int(a["speed"])))
	_drive(rr, turns, func(res) -> void:
		var a: Dictionary = by_id[res.actor_id]
		var line := StringName("ct.%s" % a["id"])
		rr.lines.advance(line, -rr.lines.value_of(line))  # no-carry reset
		var cost := _next_cost(counts, a)
		var spend := cost if cost > 0 else BASE
		rr.submit(_gated(a["id"], line, spend * SCALE, EQConditionSpec.Comparison.GE, int(a["speed"]))))
	return rr


## Energy: per-entity energy line at rate = speed; act at 100; CARRY (spend).
static func _energy_pipeline(actors: Array, turns: int) -> EQReservationRuntime:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	var counts := {}
	var by_id := {}
	for a in actors:
		by_id[a["id"]] = a
		rr.runtime.register_actor(a["id"])
		rr.lines.issue(StringName("en.%s" % a["id"]), 0, int(a["speed"]))
		rr.submit(_gated(a["id"], StringName("en.%s" % a["id"]), 100, EQConditionSpec.Comparison.GE, 0))
	_drive(rr, turns, func(res) -> void:
		var a: Dictionary = by_id[res.actor_id]
		var line := StringName("en.%s" % a["id"])
		var cost := _next_cost(counts, a)
		rr.lines.advance(line, -(cost if cost > 0 else BASE))  # carry-over
		rr.submit(_gated(a["id"], line, 100, EQConditionSpec.Comparison.GE, 0)))
	return rr


## Wait-Turn: per-entity WT line counting DOWN (rate -1); act at <= 0; the act
## re-sets the wait to maxi(1, cost). wait 0 actors are ready at submit
## (issuance is an evaluation point, SEM §5.4).
static func _wait_pipeline(actors: Array, turns: int) -> EQReservationRuntime:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	var counts := {}
	var by_id := {}
	for a in actors:
		by_id[a["id"]] = a
		rr.runtime.register_actor(a["id"])
		rr.lines.issue(StringName("wt.%s" % a["id"]), int(a["wait"]), -1)
		rr.submit(_gated(a["id"], StringName("wt.%s" % a["id"]), 0, EQConditionSpec.Comparison.LE, int(a["agility"])))
	_drive(rr, turns, func(res) -> void:
		var a: Dictionary = by_id[res.actor_id]
		var line := StringName("wt.%s" % a["id"])
		var cost := _next_cost(counts, a)
		var next_wait: int = maxi(1, cost if cost > 0 else BASE)
		rr.lines.advance(line, next_wait - rr.lines.value_of(line))
		rr.submit(_gated(a["id"], line, 0, EQConditionSpec.Comparison.LE, int(a["agility"]))))
	return rr


# --- golden fixture for the product-path CTB trace ---------------------------

static func _golden(t) -> void:
	var jsonl: String = _ctb_pipeline(CTB_CASES[0]["actors"], int(CTB_CASES[0]["turns"])).runtime.trace_jsonl()
	var update := OS.get_environment("GODOT_UPDATE_GOLDEN")
	if update == GOLDEN_CASE:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GOLDEN_PATH.get_base_dir()))
		var f := FileAccess.open(GOLDEN_PATH, FileAccess.WRITE)
		if f == null:
			t.ok(false, "could not open golden for write: %s" % GOLDEN_PATH)
			return
		f.store_string(jsonl)
		f.close()
		t.ok(true, "golden re-baselined for %s via --update-golden (record in self-review)" % GOLDEN_CASE)
		return
	var exists := FileAccess.file_exists(GOLDEN_PATH)
	t.ok(exists, "golden fixture exists: %s (create via ./tools/test.sh --update-golden %s)" % [GOLDEN_PATH, GOLDEN_CASE])
	if not exists:
		return
	var want := FileAccess.get_file_as_string(GOLDEN_PATH)
	if jsonl != want:
		var out := OS.get_environment("EQ_RUN_OUT")
		if out != "":
			DirAccess.make_dir_recursive_absolute(out + "/traces")
			var f := FileAccess.open(out + "/traces/%s.actual.jsonl" % GOLDEN_CASE, FileAccess.WRITE)
			if f != null:
				f.store_string(jsonl)
				f.close()
	t.eq(jsonl, want, "product-path CTB trace matches golden (re-baseline: ./tools/test.sh --update-golden %s)" % GOLDEN_CASE)
