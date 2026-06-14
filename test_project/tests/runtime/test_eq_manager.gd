extends RefCounted
## EQM-032: EQManager node — signal flow, turn suspend/resume, frame-budget
## determinism, and invalid-policy validation. Runs headless (bare Node).

const EQManager := preload("res://addons/event_queue_manager/runtime/eq_manager.gd")
const EQActionResult := preload("res://addons/event_queue_manager/runtime/eq_action_result.gd")
const EQConfig := preload("res://addons/event_queue_manager/resources/eq_config.gd")
const EQPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_policy.gd")
const EQFixedRoundPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_fixed_round_policy.gd")
const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")


static func run(t) -> void:
	_test_signal_flow_and_suspend(t)
	_test_frame_budget_determinism(t)
	_test_invalid_policy(t)
	_test_shipped_skip_signal(t)


static func _make(mode := -1):
	var m = EQManager.new()
	if mode >= 0:
		m.set_mode(mode)
	var pol := EQFixedRoundPolicy.new()
	m.set_policy(pol)
	return m


static func _test_signal_flow_and_suspend(t) -> void:
	var m = _make()
	var log: Array = []
	m.turn_ready.connect(func(aid, _e): log.append("turn:%s" % aid))
	m.event_resolved.connect(func(_e): log.append("resolved"))
	m.timeline_advanced.connect(func(tick): log.append("tick:%d" % tick))
	m.register_actor(&"fast").data["initiative"] = 9
	m.register_actor(&"slow").data["initiative"] = 1
	m.seed()

	var e = m.step()
	t.eq(e.actor_id, &"fast", "first turn is the higher-initiative actor")
	t.ok(m.is_awaiting_turn(), "node suspends after turn_ready")
	t.ok(m.step() == null, "suspended: step() returns null until finish_action")
	t.ok(log.has("turn:fast") and log.has("resolved") and log.has("tick:1"), "signals fired: turn_ready, event_resolved, timeline_advanced")

	m.finish_action(&"fast", EQActionResult.new(0, 0))
	t.ok(not m.is_awaiting_turn(), "finish_action clears the suspend")
	t.eq(m.step().actor_id, &"slow", "next step resolves the next actor")
	m.free()


static func _test_frame_budget_determinism(t) -> void:
	# budget=1 (12 calls) vs budget=12 (1 call) must yield the same trace.
	var a = _make()
	a.register_actor(&"a").data["initiative"] = 5
	a.register_actor(&"b").data["initiative"] = 3
	a.register_actor(&"c").data["initiative"] = 1
	a.seed()
	for _i in 12:
		a.advance_frame(1)
	var trace_sliced := a.trace_jsonl()
	a.free()

	var b = _make()
	b.register_actor(&"a").data["initiative"] = 5
	b.register_actor(&"b").data["initiative"] = 3
	b.register_actor(&"c").data["initiative"] = 1
	b.seed()
	b.advance_frame(12)
	var trace_bulk := b.trace_jsonl()
	b.free()

	t.eq(trace_sliced, trace_bulk, "frame-budget does not change the trace (time-slicing preserves determinism)")
	t.ok(trace_sliced.length() > 0, "produced a non-trivial trace")


static func _test_invalid_policy(t) -> void:
	var m = EQManager.new()
	m.set_mode(1)  # SHIPPED so the invalid config does not assert-halt the test
	m.runtime().emit_engine_diagnostics = false
	var cfg := EQConfig.new()
	cfg.policy = EQPolicy.new()  # raw base instance -> invalid
	var v = m.configure(cfg)
	t.ok(not v.is_valid(), "invalid policy config is reported by configure/validate")
	t.ok(v.has_code(EQError.POLICY_BASE_INSTANCE), "base policy -> POLICY_BASE_INSTANCE")
	m.free()


static func _test_shipped_skip_signal(t) -> void:
	var m = EQManager.new()
	m.set_mode(1)  # SHIPPED
	m.runtime().emit_engine_diagnostics = false
	var pol := EQFixedRoundPolicy.new()
	m.set_policy(pol)
	var skipped: Array = []
	m.invalid_event_skipped.connect(func(f): skipped.append(f))
	m.register_actor(&"a").data["initiative"] = 9
	m.register_actor(&"b").data["initiative"] = 1
	m.seed()
	m.step()                       # a resolves
	m.finish_action(&"a", EQActionResult.new(0, 0))
	m.runtime().registry.unregister(&"b")  # orphan b's pending turn
	m.step()                       # hits b's orphaned event -> shipped skip
	t.ok(skipped.size() >= 1, "invalid_event_skipped signal fired on a shipped skip")
	m.free()
