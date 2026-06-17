extends RefCounted
## EQM-071: wait/end-turn commit boundary — a player's immediate actions are
## rollbackable before wait; wait commits the draft and schedules the ready
## reservation. After commit, the draft boundary is closed.

const EQRuntime := preload("res://addons/event_queue_manager/runtime/eq_runtime.gd")
const EQTransaction := preload("res://addons/event_queue_manager/runtime/eq_transaction.gd")
const EQActionResult := preload("res://addons/event_queue_manager/runtime/eq_action_result.gd")
const EQActionResolutionPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_action_resolution_policy.gd")


static func _runtime() -> EQRuntime:
	var rt := EQRuntime.new()
	rt.register_actor(&"hero").data["ap_recovery"] = 10  # ap_max 100 -> ready delay ceil(100/10)
	return rt


static func run(t) -> void:
	_test_rollbackable_before_wait(t)
	_test_wait_commits_and_schedules_ready(t)
	_test_commit_closes_draft(t)
	_test_wait_close_without_transaction(t)


static func _test_rollbackable_before_wait(t) -> void:
	var rt := _runtime()
	var tx := EQTransaction.new(rt.scheduler)
	tx.draft_push(0, 0, &"strike", &"hero")   # an immediate action, drafted
	t.eq(tx.working().size(), 1, "immediate action drafted on the working copy")
	t.eq(rt.scheduler.size(), 0, "live scheduler still empty before wait")
	t.ok(tx.is_live_unchanged(), "live unchanged before wait")
	tx.rollback()                              # player changes their mind
	t.eq(tx.working().size(), 0, "rollback discards the immediate action")
	t.eq(rt.scheduler.size(), 0, "live still untouched after rollback")


static func _test_wait_commits_and_schedules_ready(t) -> void:
	var rt := _runtime()
	var pol := EQActionResolutionPolicy.new()
	var tx := EQTransaction.new(rt.scheduler)
	tx.draft_push(0, 9, &"strike", &"hero")    # immediate action this turn
	t.eq(rt.scheduler.size(), 0, "not yet committed")
	pol.wait_close(rt, &"hero", EQActionResult.new(100, 0), tx)   # WAIT closes the turn
	t.ok(tx.is_committed(), "wait committed the transaction")
	# live now holds the committed immediate action AND the scheduled ready turn
	t.eq(rt.scheduler.size(), 2, "wait commits the draft and schedules the ready reservation")
	var kinds: Array = rt.scheduler.peek(10).map(func(e): return String(e.kind))
	t.ok(kinds.has("strike"), "the committed immediate action is on live")
	t.ok(kinds.has("turn"), "a ready reservation (next turn) was scheduled")


static func _test_commit_closes_draft(t) -> void:
	var rt := _runtime()
	var tx := EQTransaction.new(rt.scheduler)
	tx.draft_push(0, 0, &"a", &"hero")
	tx.commit()
	t.eq(tx.draft_push(1, 0, &"late", &"hero"), -1, "draft_push is a no-op after commit")
	t.ok(not tx.draft_cancel(1), "draft_cancel is a no-op after commit")


static func _test_wait_close_without_transaction(t) -> void:
	var rt := _runtime()
	var pol := EQActionResolutionPolicy.new()
	# policy-only wait_close (no transaction) just schedules the ready reservation
	pol.wait_close(rt, &"hero", EQActionResult.new(100, 0))
	t.eq(rt.scheduler.size(), 1, "wait_close without a transaction schedules only the ready turn")
	t.eq(String(rt.scheduler.peek_next().kind), "turn", "the scheduled event is the ready turn")
