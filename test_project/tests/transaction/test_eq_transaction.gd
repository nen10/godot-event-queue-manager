extends RefCounted
## EQM-070: player-turn draft transaction — draft actions apply to a working copy
## and can be inspected, rolled back, or committed; the live scheduler is
## unchanged before commit.

const EQScheduler := preload("res://addons/event_queue_manager/runtime/eq_scheduler.gd")
const EQTransaction := preload("res://addons/event_queue_manager/runtime/eq_transaction.gd")


static func _live_with(initial: int) -> EQScheduler:
	var s := EQScheduler.new()
	for i in initial:
		s.push(10 + i, 0, &"seed", &"u%d" % i)
	return s


static func run(t) -> void:
	_test_draft_and_inspect(t)
	_test_rollback(t)
	_test_commit(t)


static func _test_draft_and_inspect(t) -> void:
	var live := _live_with(2)
	var tx := EQTransaction.new(live)
	t.ok(tx.is_live_unchanged(), "live unchanged at begin")
	t.eq(tx.working().size(), 2, "working starts as a clone of live")

	var id := tx.draft_push(3, 5, &"strike", &"hero")
	t.ok(id > 0, "draft_push returns a working event id")
	t.eq(tx.working().size(), 3, "draft applied to the working copy")
	t.eq(live.size(), 2, "live scheduler still has only its seeded events")
	t.ok(tx.is_live_unchanged(), "live unchanged after a draft (before commit)")
	t.eq(tx.draft().size(), 1, "draft log records the action")
	t.eq(tx.draft()[0]["op"], &"push", "draft log op recorded")


static func _test_rollback(t) -> void:
	var live := _live_with(2)
	var tx := EQTransaction.new(live)
	tx.draft_push(1, 0, &"a", &"hero")
	tx.draft_push(2, 0, &"b", &"hero")
	t.eq(tx.working().size(), 4, "two drafts applied")
	tx.rollback()
	t.eq(tx.working().size(), 2, "rollback restores the working copy to base")
	t.eq(tx.draft().size(), 0, "rollback clears the draft log")
	t.ok(tx.is_live_unchanged(), "live still unchanged after rollback")
	t.ok(not tx.is_committed(), "rolled-back transaction is not committed")


static func _test_commit(t) -> void:
	var live := _live_with(1)
	var tx := EQTransaction.new(live)
	tx.draft_push(2, 9, &"commit_me", &"hero")
	t.ok(tx.is_live_unchanged(), "live unchanged just before commit")
	tx.commit()
	t.ok(tx.is_committed(), "committed flag set")
	t.eq(live.size(), 2, "commit promotes the draft to live (1 seeded + 1 drafted)")
	# the drafted event is now resolvable on live in order (priority 9, tick 2 first)
	t.eq(live.peek_next().actor_id, &"hero", "drafted event is live and ordered")
	t.eq(String(live.peek_next().kind), "commit_me", "the committed draft is the next event")
