extends RefCounted
## EQM-033: prediction is a pure hypothetical — it returns the next-N order,
## matches what actually happens, and never mutates live state; branching lets
## "act now vs wait" be compared without side effects.

const EQRuntime := preload("res://addons/event_queue_manager/runtime/eq_runtime.gd")
const EQActionResult := preload("res://addons/event_queue_manager/runtime/eq_action_result.gd")
const EQPrediction := preload("res://addons/event_queue_manager/runtime/eq_prediction.gd")
const EQSnapshot := preload("res://addons/event_queue_manager/runtime/eq_snapshot.gd")
const EQConfig := preload("res://addons/event_queue_manager/resources/eq_config.gd")
const EQCTBPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_ctb_policy.gd")


static func run(t) -> void:
	_test_purity_and_match(t)
	_test_branch_independence(t)
	_test_act_now_vs_wait(t)
	_test_short_when_empty(t)


static func _ctb_runtime() -> EQRuntime:
	var cfg := EQConfig.new()
	cfg.policy = EQCTBPolicy.new()
	var rt := EQRuntime.new(cfg)
	rt.register_actor(&"fast").data["speed"] = 20
	rt.register_actor(&"slow").data["speed"] = 10
	cfg.policy.seed(rt, rt.registry.actor_ids())
	return rt


static func _test_purity_and_match(t) -> void:
	var rt := _ctb_runtime()
	var before := rt.scheduler.snapshot()
	var predicted := EQPrediction.predict_turns(rt, 5)
	var after := rt.scheduler.snapshot()
	t.ok(EQSnapshot.equals(before, after), "prediction does not mutate live state (snapshot before == after)")
	t.eq(predicted.size(), 5, "predicts the requested count")

	# prediction matches what actually happens under the same default actions
	var actual: Array = []
	var pol = rt.config.policy
	for _i in 5:
		var e = rt.advance()
		if e == null:
			break
		actual.append(e.actor_id)
		pol.on_turn_finished(rt, e.actor_id, EQActionResult.new(0, 0))
	t.eq(predicted, actual, "prediction order equals the actual resolved order")
	t.ok(predicted[0] == &"fast", "faster actor predicted first (CTB)")


static func _test_branch_independence(t) -> void:
	var rt := _ctb_runtime()
	var live_speed: int = rt.registry.get_state(&"fast").data["speed"]
	var b := EQPrediction.branch(rt)
	# mutate the branch's actor data and advance it
	b.registry.get_state(&"fast").data["speed"] = 999
	b.advance()
	t.eq(rt.registry.get_state(&"fast").data["speed"], live_speed, "branch data change does not leak to live")
	t.ok(not rt.scheduler.is_empty(), "live queue untouched by branch advance")


static func _test_act_now_vs_wait(t) -> void:
	var rt := _ctb_runtime()
	# branch A: fast takes a heavy action first; branch B: a light one
	var heavy := EQPrediction.branch(rt)
	var light := EQPrediction.branch(rt)
	var pol = rt.config.policy
	var he = heavy.advance()
	pol.on_turn_finished(heavy, he.actor_id, EQActionResult.new(400, 0))   # heavy
	var le = light.advance()
	pol.on_turn_finished(light, le.actor_id, EQActionResult.new(20, 0))    # light
	var heavy_next = heavy.advance().actor_id
	var light_next = light.advance().actor_id
	# a heavy first action cedes the next turn; a light one keeps initiative
	t.eq(heavy_next, &"slow", "heavy first action -> opponent acts next")
	t.eq(light_next, &"fast", "light first action -> same actor acts again")
	t.ok(heavy_next != light_next, "branches explore genuinely different futures")
	# live unchanged by either branch
	t.eq(rt.scheduler.size(), 2, "live queue size intact after branching")
	t.eq(rt.scheduler.current_tick, 0, "live clock intact after branching")


static func _test_short_when_empty(t) -> void:
	var rt := _ctb_runtime()
	var got := EQPrediction.predict_turns(rt, 1000)  # far more than will be produced before reschedule loop
	t.ok(got.size() == 1000, "policy keeps rescheduling, so prediction fills the requested depth")
	# with no policy, prediction only sees already-queued events
	var rt2 := EQRuntime.new()
	rt2.register_actor(&"a")
	rt2.schedule(&"a", 5)
	t.eq(EQPrediction.predict_turns(rt2, 10).size(), 1, "without a policy, only already-queued events are predicted")
