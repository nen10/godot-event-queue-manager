extends RefCounted
## EQM-092 — the shipped demo exercises the reservation/trigger/presentation APIs
## and is deterministic. (No golden fixture: this asserts the demo's structure and
## determinism, not a frozen byte trace.)

const DemoBattle := preload("res://demos/action_resolution/demo_battle.gd")


static func run(t) -> void:
	_test_uses_apis(t)
	_test_trace_exercises_subsystems(t)
	_test_deterministic(t)
	_test_config_concrete(t)


static func _test_uses_apis(t) -> void:
	var uses := DemoBattle.USES_APIS
	for api in [&"reservation", &"trigger", &"presentation"]:
		t.ok(uses.has(api), "demo declares it uses the %s API" % api)


static func _test_trace_exercises_subsystems(t) -> void:
	var jsonl: String = DemoBattle.run_trace(8)
	# turns resolved
	t.ok(jsonl.contains("\"kind\":\"turn\""), "demo resolves turns")
	# trigger/reservation: the armed counter fires on incoming damage
	t.ok(jsonl.contains("reaction_fired"), "armed reaction (reservation + trigger) fires")
	# presentation: visuals are flushed (presentation OUTPUT, not just enqueue)
	t.ok(jsonl.contains("presentation_flush"), "presentation buffer is flushed")
	# effect: damage records are produced
	t.ok(jsonl.contains("damage"), "simulation effect records produced")


static func _test_deterministic(t) -> void:
	t.eq(DemoBattle.run_trace(8), DemoBattle.run_trace(8), "demo trace is deterministic (seeded RNG)")


static func _test_config_concrete(t) -> void:
	var config = DemoBattle.build_config()
	t.ok(config.validate().is_valid(), "demo config validates (concrete policy, not a base instance)")
