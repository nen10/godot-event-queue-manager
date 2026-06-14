extends RefCounted
## EQM-022: headless facade flow + dev/shipped resilience two modes + mode
## neutrality (normal-input trace byte-identical across modes) + shipped-skip
## keeps the scheduler consistent.

const EQRuntime := preload("res://addons/event_queue_manager/runtime/eq_runtime.gd")
const EQActionResult := preload("res://addons/event_queue_manager/runtime/eq_action_result.gd")
const EQSnapshot := preload("res://addons/event_queue_manager/runtime/eq_snapshot.gd")
const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")


static func run(t) -> void:
	_test_basic_flow(t)
	_test_mode_neutrality(t)
	_test_dev_halts_on_anomaly(t)
	_test_shipped_skips_and_continues(t)
	_test_finish_rejects_bad_result(t)


## Runs a fixed interactive scenario (schedule, advance, finish→reschedule) for a
## bounded number of steps and returns the trace. No anomalies.
static func _run_scenario(rt) -> String:
	rt.register_actor(&"hero")
	rt.register_actor(&"orc")
	rt.register_actor(&"mage")
	rt.schedule(&"hero", 1)
	rt.schedule(&"orc", 2)
	rt.schedule(&"mage", 3)
	var delays := {&"hero": 4, &"orc": 5, &"mage": 6}
	for _i in 8:
		var e = rt.advance()
		if e == null:
			break
		rt.finish_action(e.actor_id, EQActionResult.new(1, delays[e.actor_id]))
	return rt.trace_jsonl()


static func _test_basic_flow(t) -> void:
	var rt := EQRuntime.new()
	t.ok(rt.register_actor(&"hero") != null, "register actor without a scene tree")
	t.ok(rt.start().is_valid(), "start with no config is valid (config optional)")
	var id := rt.schedule(&"hero", 5)
	t.ok(id > 0, "schedule returns an event id")
	var e = rt.advance()
	t.ok(e != null and e.actor_id == &"hero", "advance resolves the ready event")
	t.eq(rt.scheduler.current_tick, 5, "clock advanced to the resolved tick")
	var nxt := rt.finish_action(&"hero", EQActionResult.new(1, 3))
	t.ok(nxt > 0, "finish_action schedules the next event")
	t.eq(rt.advance().due_tick, 8, "next event scheduled at current_tick + delay")


static func _test_mode_neutrality(t) -> void:
	var dev := _run_scenario(EQRuntime.new(null, EQRuntime.Mode.DEV))
	var shipped := _run_scenario(EQRuntime.new(null, EQRuntime.Mode.SHIPPED))
	t.eq(shipped, dev, "normal-input trace is byte-identical across dev/shipped (mode neutrality)")
	t.ok(dev.length() > 0, "scenario produced a non-trivial trace")


static func _test_dev_halts_on_anomaly(t) -> void:
	var rt := EQRuntime.new(null, EQRuntime.Mode.DEV)
	rt.emit_engine_diagnostics = false  # keep the test log clean; faults still recorded
	rt.register_actor(&"hero")
	rt.register_actor(&"orc")
	rt.schedule(&"hero", 1)
	rt.schedule(&"orc", 2)
	t.ok(rt.advance().actor_id == &"hero", "hero resolves first")
	rt.registry.unregister(&"orc")          # remove orc mid-flight
	var e = rt.advance()                     # hits orc's now-orphaned event
	t.ok(e == null, "dev advance returns null on the anomaly")
	t.ok(rt.halted, "dev mode halted")
	t.eq(rt.faults.size(), 1, "anomaly recorded as a fault")
	t.ok(rt.faults[0]["code"] == EQError.RUNTIME_UNREGISTERED_ACTOR_EVENT, "fault has the runtime code")
	t.ok(rt.advance() == null, "stays halted on subsequent advance")


static func _test_shipped_skips_and_continues(t) -> void:
	var rt := EQRuntime.new(null, EQRuntime.Mode.SHIPPED)
	rt.emit_engine_diagnostics = false
	rt.register_actor(&"hero")
	rt.register_actor(&"orc")
	rt.register_actor(&"mage")
	rt.schedule(&"hero", 1)
	rt.schedule(&"orc", 2)
	rt.schedule(&"mage", 3)
	t.ok(rt.advance().actor_id == &"hero", "hero resolves")
	rt.registry.unregister(&"orc")
	var e = rt.advance()                     # skips orc, continues to mage
	t.ok(e != null and e.actor_id == &"mage", "shipped skips the orphaned event and continues")
	t.ok(not rt.halted, "shipped does not halt")
	t.eq(rt.faults.size(), 1, "anomaly still recorded (no silent swallow)")
	t.ok(rt.trace_jsonl().contains("invalid_event_skipped"), "skip recorded in the trace")
	# scheduler stays consistent after a shipped skip: snapshot roundtrips
	rt.schedule(&"hero", 10)
	var snap := rt.scheduler.snapshot()
	var rt2 := EQRuntime.new(null, EQRuntime.Mode.SHIPPED)
	t.eq(rt2.scheduler.restore(snap), EQSnapshot.Load.OK, "scheduler snapshot still valid after a shipped skip")


static func _test_finish_rejects_bad_result(t) -> void:
	var rt := EQRuntime.new(null, EQRuntime.Mode.SHIPPED)
	rt.emit_engine_diagnostics = false
	rt.register_actor(&"hero")
	rt.schedule(&"hero", 1)
	rt.advance()
	var before := rt.scheduler.size()
	var nxt := rt.finish_action(&"hero", EQActionResult.new(0, -5))  # negative delay
	t.eq(nxt, -1, "finish with a bad result schedules nothing")
	t.eq(rt.scheduler.size(), before, "no next event created from an invalid result")
	t.ok(rt.faults.size() >= 1, "bad result recorded as a fault")
