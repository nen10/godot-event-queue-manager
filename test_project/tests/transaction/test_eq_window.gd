extends RefCounted
## EQM-114: the window object model (SEM §8.1/§9) — implicit root, LIFO stack,
## meta-cost budget (paid, never refunded, Q02), deadline default rollback+close
## with the pre-close explicit-commit hook (Q37), window traces, commit guard.

const EQReservationRuntime := preload("res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd")
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQActionDefinition := preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQWindow := preload("res://addons/event_queue_manager/runtime/eq_window.gd")
const EQError := preload("res://addons/event_queue_manager/runtime/eq_error.gd")


static func run(t) -> void:
	_test_stack_and_traces(t)
	_test_draft_subordination(t)
	_test_budget(t)
	_test_depth_backstop(t)
	_test_close_invalid(t)
	_test_deadline_default_rollback(t)
	_test_deadline_pre_close_commit(t)
	_test_commit_conflict(t)
	_test_save_boundary(t)


static func _rr(actors: Array = [&"hero"]) -> EQReservationRuntime:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	for a in actors:
		rr.runtime.register_actor(a)
	return rr


static func _test_stack_and_traces(t) -> void:
	var rr := _rr()
	t.eq(rr.window_depth(), 0, "the implicit root window is depth 0 (the L0 await boundary)")
	t.eq(rr.current_window().kind, &"base-operator", "root is the base-operator level (Q01)")
	t.ok(not ('"kind":"window_opened"' in rr.runtime.trace_jsonl()), "the implicit root is never traced (L0 goldens unchanged)")

	var w1 := rr.open_window(&"hero", &"command")
	t.eq(w1.nest_level, 1, "first explicit window nests at level 1")
	t.ok(w1.is_frozen(), "default window is frozen (deadline = ∞)")
	var w2 := rr.open_window(&"hero", &"counter-choice")
	t.eq(w2.nest_level, 2, "windows nest LIFO")
	t.eq(rr.window_depth(), 2, "depth counts explicit windows")

	rr.close_window()
	t.eq(rr.window_depth(), 1, "close pops the top window")
	var jsonl := rr.runtime.trace_jsonl()
	t.ok('"kind":"window_opened"' in jsonl and '"window_kind":"command"' in jsonl, "window_opened is traced with its kind")
	t.ok('"kind":"window_closed"' in jsonl and '"cause":"closed"' in jsonl, "window_closed is traced with its cause")


static func _test_draft_subordination(t) -> void:
	var rr := _rr()
	var w := rr.open_window(&"hero", &"command")
	var id: int = w.draft.draft_push(4, 0, &"turn", &"hero")
	t.ok(id > 0, "the window's draft accepts operations (1 window = 1 draft)")
	t.ok(rr.runtime.scheduler.is_empty(), "drafting never touches the live scheduler")
	rr.close_window(true)
	t.eq(rr.runtime.scheduler.size(), 1, "close(commit) promotes the draft to live")

	var rr2 := _rr()
	var w2 := rr2.open_window(&"hero", &"command")
	w2.draft.draft_push(4, 0, &"turn", &"hero")
	rr2.close_window()
	t.ok(rr2.runtime.scheduler.is_empty(), "close() (default) rolls the draft back")


static func _test_budget(t) -> void:
	var rr := _rr()
	rr.runtime.registry.get_state(&"hero").data["meta"] = 10
	var w1 := rr.open_window(&"hero", &"command", EQWindow.DEADLINE_UNLIMITED, 4, &"meta")
	t.eq(w1.budget_paid, 4, "meta-cost recorded on the window")
	t.eq(int(rr.runtime.registry.get_state(&"hero").data["meta"]), 6, "cost paid from the owner's budget key")
	rr.open_window(&"hero", &"nested", EQWindow.DEADLINE_UNLIMITED, 4, &"meta")
	rr.close_window()
	rr.close_window()
	t.eq(int(rr.runtime.registry.get_state(&"hero").data["meta"]), 2, "closing never refunds within a chain (Q02 non-replenishing)")

	var rejected := rr.open_window(&"hero", &"command", EQWindow.DEADLINE_UNLIMITED, 3, &"meta")
	t.eq(rejected, null, "insufficient budget rejects the open")
	t.eq(rr.runtime.faults.back()["code"], EQError.WINDOW_BUDGET_INSUFFICIENT, "budget rejection is a stable fault")
	t.eq(rr.window_depth(), 0, "no window was opened on rejection")


static func _test_depth_backstop(t) -> void:
	var rr := _rr()
	rr.max_window_depth = 2
	rr.open_window(&"hero", &"a")
	rr.open_window(&"hero", &"b")
	t.eq(rr.open_window(&"hero", &"c"), null, "absolute max depth is an engineering backstop (SEM §8)")
	t.eq(rr.runtime.faults.back()["code"], EQError.WINDOW_DEPTH_LIMIT, "depth rejection is a stable fault")


static func _test_close_invalid(t) -> void:
	var rr := _rr()
	t.ok(not rr.close_window(), "the implicit root never closes")
	t.eq(rr.runtime.faults.back()["code"], EQError.WINDOW_CLOSE_INVALID, "root close is a contract violation")


static func _test_deadline_default_rollback(t) -> void:
	var rr := _rr()
	var w := rr.open_window(&"hero", &"atb-turn", 5)
	w.draft.draft_push(9, 0, &"turn", &"hero")
	t.ok(not w.is_frozen(), "a deadline window lets the tick flow (ATB active)")
	for _i in 5:
		rr.step_tick()
	t.ok(w.closed, "reaching the deadline closes the window")
	t.eq(rr.window_depth(), 0, "the stack unwound to the base level")
	t.ok(rr.runtime.scheduler.is_empty(), "the default is DRAFT ROLLBACK — no silent default action (Q37)")
	t.ok('"cause":"deadline"' in rr.runtime.trace_jsonl(), "window_closed carries cause: deadline")


static func _test_deadline_pre_close_commit(t) -> void:
	var rr := _rr()
	var w := rr.open_window(&"hero", &"atb-turn", 3)
	w.draft.draft_push(7, 0, &"turn", &"hero")
	w.pre_close = func(_win) -> void:
		rr.close_window(true, &"deadline_commit")  # the EXPLICIT time-out commit
	for _i in 3:
		rr.step_tick()
	t.ok(w.closed, "the hook closed the window before the default applied")
	t.eq(rr.runtime.scheduler.size(), 1, "the pre-close hook committed the draft explicitly")
	t.ok('"cause":"deadline_commit"' in rr.runtime.trace_jsonl(), "the explicit commit is distinguishable in the trace")


static func _test_commit_conflict(t) -> void:
	var rr := _rr()
	var w := rr.open_window(&"hero", &"command")
	w.draft.draft_push(4, 0, &"turn", &"hero")
	# live drifts while the window is open (ATB-style resolution during a draft)
	var d := EQActionDefinition.new()
	d.kind = EQActionDefinition.Kind.IMMEDIATE
	rr.submit(EQReservation.new(&"hero", d))
	rr.resolve_next()
	rr.close_window(true)
	t.eq(rr.runtime.faults.back()["code"], EQError.WINDOW_COMMIT_CONFLICT, "commit over drifted live is refused (would clobber)")
	t.ok(rr.runtime.scheduler.is_empty(), "the conflicting draft rolled back instead of clobbering live")


static func _test_save_boundary(t) -> void:
	var rr := _rr()
	t.ok(rr.is_save_boundary(), "base level + empty chunk = save boundary (Q01/Q22)")
	rr.open_window(&"hero", &"command")
	t.ok(not rr.is_save_boundary(), "an open explicit window blocks the save boundary")
	rr.close_window()
	t.ok(rr.is_save_boundary(), "closing restores the boundary")
