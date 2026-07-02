extends RefCounted
## EQM-112 — progression performance budgets (SEM §12.1, Q43): the polling +
## sweep machinery must stay within the declared per-advance budget at the v1.x
## target scale (watched lines <= 300, actors <= 200, +0.5ms per advance()).
## Like EQM-102, this is a coarse regression guard (declared budget with CI
## headroom), not a microbenchmark.

const EQEventLines := preload("res://addons/event_queue_manager/runtime/eq_event_lines.gd")
const EQActorRegistry := preload("res://addons/event_queue_manager/runtime/eq_actor_registry.gd")
const EQTrace := preload("res://addons/event_queue_manager/runtime/eq_trace.gd")

const WATCHED_LINES := 300
const ACTORS := 200
const POLLS := 200
## Declared budget: 0.5 ms per poll step at target scale (SEM §12.1) -> 100 ms
## for 200 polls; guard at 4x for CI variance (same stance as EQM-102).
const POLL_BUDGET_MS := 400
const SWEEPS := 50
## Sweep budget shares the same 0.5 ms/advance envelope -> 25 ms for 50 sweeps; 4x headroom.
const SWEEP_BUDGET_MS := 100


static func run(t) -> void:
	_test_poll_budget(t)
	_test_sweep_budget(t)


static func _test_poll_budget(t) -> void:
	var el := EQEventLines.new(EQTrace.new())  # trace attached: the honest cost
	var watched := {}
	for i in WATCHED_LINES:
		var id := StringName("line.%03d" % i)
		el.issue(id, 0, 1 + (i % 3))
		watched[id] = true
	var start := Time.get_ticks_usec()
	for _p in POLLS:
		el.poll_tick(watched)
	var ms := (Time.get_ticks_usec() - start) / 1000.0
	t.ok(ms <= POLL_BUDGET_MS, "%d polls of %d watched lines within %dms budget (took %.1fms)" % [POLLS, WATCHED_LINES, POLL_BUDGET_MS, ms])
	t.eq(el.value_of(&"line.000"), POLLS, "budget run advanced correctly (rate 1 x %d polls)" % POLLS)


static func _test_sweep_budget(t) -> void:
	var el := EQEventLines.new(EQTrace.new())
	var reg := EQActorRegistry.new()
	for i in ACTORS:
		var id := StringName("actor.%03d" % i)
		reg.register(id)
		reg.get_state(id).data["speed"] = 1 + (i % 5)
		el.issue(StringName("ct.%s" % id), 0, 0)
	el.register_sweep_rule(&"ct_charge", func(actor_id: StringName, data: Dictionary, lines) -> void:
		lines.advance(StringName("ct.%s" % actor_id), int(data["speed"])))
	var start := Time.get_ticks_usec()
	for _s in SWEEPS:
		el.run_sweep_rules(reg)
	var ms := (Time.get_ticks_usec() - start) / 1000.0
	t.ok(ms <= SWEEP_BUDGET_MS, "%d sweeps over %d actors within %dms budget (took %.1fms)" % [SWEEPS, ACTORS, SWEEP_BUDGET_MS, ms])
	t.eq(el.value_of(&"ct.actor.000"), SWEEPS, "sweep advanced per-entity params correctly")
