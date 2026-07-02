class_name EQReservationRuntime
extends RefCounted
## L2 resolution pipeline over an EQRuntime — THE one integration contract
## (SEM §6.1, EQM-113). One resolution is exactly:
##
##   1. pop    — runtime.advance() (lazy invalidation: level-evaluated
##               invalidation terms drop the event with `closed_by`)
##   2. effect — the declared named effect handler (empty = effect-less;
##               set-but-unregistered = stable error, never a silent skip)
##   3. chunk  — returned EQEffectRecords append to the effect chunk
##   4. sweep  — triggers fire and are SCHEDULED (never resolved in place,
##               §6.2), numeric invalidation is re-checked, pending
##               condition-gated reservations are pushed at the detection
##               tick (Q27 key assignment)
##   5. trace/drain — the chunk drains into `last_drained`; chunk-empty =
##               the save boundary (§10)
##
## Reservation kinds behave as EQM-051/052 defined (immediate/prepared/ready/
## wait/operation/rumination). Duration expiry is an expiry EVENT on the master
## timeline (§6.3): `closed_by: duration / reaction_count / already_closed`.
## Actor departure is the normal path `invalidate_actor` (§13, Q39) — mode-
## neutral, `closed_by: actor_removed`.
##
## This class owns the L3 EQEventLines; it never appears in an L0/L1 signature.

const EQRuntime := preload("eq_runtime.gd")
const EQReservation := preload("eq_reservation.gd")
const EQActionDefinition := preload("../resources/eq_action_definition.gd")
const EQConditionSpec := preload("../resources/eq_condition_spec.gd")
const EQConditionEval := preload("eq_condition_eval.gd")
const EQEventLines := preload("eq_event_lines.gd")
const EQEffectChunk := preload("eq_effect_chunk.gd")
const EQTriggerEngine := preload("eq_trigger_engine.gd")
const EQWindow := preload("eq_window.gd")
const EQTransaction := preload("eq_transaction.gd")

var runtime: EQRuntime
var lines: EQEventLines
var chunk: EQEffectChunk
var engine: EQTriggerEngine

## Records drained from the chunk by the last resolve_next() call (§6.1 step 5).
var last_drained: Array = []
## Engineering backstop for same-tick reaction cascades (§6.2 bounded rounds).
var max_cascade_rounds: int = 8
## Absolute window-nest backstop (SEM §8 engineering max depth, EQM-114).
var max_window_depth: int = 16

var _by_event: Dictionary = {}          # event_id -> EQReservation (scheduled)
var _bound_inv: Dictionary = {}         # event_id -> Array bound invalidation terms
var _expiry_by_event: Dictionary = {}   # expiry event_id -> EQReservation
var _pending_conditional: Array[Dictionary] = []  # {res, solve, inv, view} in submit order
var _cascade_tick: int = -1
var _cascade_round: int = 0
var _windows: Array = []   # LIFO; [0] is the implicit root (nest 0, never traced/closed)
var _window_seq: int = 0


func _init(p_runtime = null) -> void:
	runtime = p_runtime if p_runtime != null else EQRuntime.new()
	lines = EQEventLines.new(runtime.trace())
	chunk = EQEffectChunk.new()
	engine = EQTriggerEngine.new()
	var root := EQWindow.new()
	root.kind = &"base-operator"
	_windows = [root]


# --- windows (SEM §8.1/§9, EQM-114) ----------------------------------------

## Explicit window depth (the implicit root is 0).
func window_depth() -> int:
	return _windows.size() - 1


func current_window() -> EQWindow:
	return _windows.back()


## Opens an explicit window above the current one. `deadline` is an absolute
## global tick (DEADLINE_UNLIMITED = frozen). `cost` (Q02 meta-cost, computed
## by acceptance as a monotonic function of nest level) is paid from the
## owner's `data[budget_key]` and is NOT refunded on close (non-replenishing
## within a chain). Returns the window, or null (depth/budget rejection).
func open_window(owner: StringName, kind: StringName, deadline: int = EQWindow.DEADLINE_UNLIMITED, cost: int = 0, budget_key: StringName = &"") -> EQWindow:
	if window_depth() + 1 > max_window_depth:
		runtime._fault(EQError.WINDOW_DEPTH_LIMIT, "window depth would exceed max_window_depth (%d)" % max_window_depth, {"owner": String(owner)}, true)
		return null
	if cost > 0:
		if not runtime.registry.is_registered(owner):
			runtime._fault(EQError.RUNTIME_SCHEDULE_UNREGISTERED_ACTOR, "open_window for unregistered actor", {"actor_id": String(owner)}, true)
			return null
		var state = runtime.registry.get_state(owner)
		var budget := int(state.data.get(budget_key, 0))
		if budget < cost:
			runtime._fault(EQError.WINDOW_BUDGET_INSUFFICIENT, "window meta-cost %d exceeds remaining budget %d" % [cost, budget], {"owner": String(owner)}, true)
			return null
		state.data[budget_key] = budget - cost
	_window_seq += 1
	var w := EQWindow.new()
	w.window_id = _window_seq
	w.owner_actor = owner
	w.nest_level = window_depth() + 1
	w.kind = kind
	w.deadline = deadline
	w.budget_paid = cost
	w.draft = EQTransaction.new(runtime.scheduler)
	_windows.append(w)
	runtime.trace().record({
		"kind": "window_opened",
		"window_id": w.window_id,
		"owner": String(owner),
		"window_kind": String(kind),
		"nest_level": w.nest_level,
		"deadline": deadline,
	})
	return w


## Closes the TOP explicit window. commit=true promotes its draft to the live
## scheduler — only legal while live is unchanged since open (a drifted commit
## would clobber live state, WINDOW_COMMIT_CONFLICT -> rollback instead).
## Closing the implicit root is invalid.
func close_window(commit: bool = false, cause: StringName = &"closed") -> bool:
	if _windows.size() <= 1:
		runtime._fault(EQError.WINDOW_CLOSE_INVALID, "no explicit window to close (the implicit root never closes)", {}, true)
		return false
	return _close_top(commit, cause)


func _close_top(commit: bool, cause: StringName) -> bool:
	var w: EQWindow = _windows.pop_back()
	w.closed = true
	if w.draft != null:
		if commit:
			# The clock may flow during a deadline window; only entry/counter
			# drift is a conflict. The live clock survives the commit.
			if w.draft.is_live_unchanged_ignoring_clock():
				var live_tick := runtime.scheduler.current_tick
				w.draft.commit()
				runtime.scheduler.current_tick = maxi(live_tick, runtime.scheduler.current_tick)
			else:
				runtime._fault(EQError.WINDOW_COMMIT_CONFLICT, "live scheduler changed since window open; commit would clobber — rolled back", {"window_id": w.window_id}, true)
				w.draft.rollback()
		else:
			w.draft.rollback()
	runtime.trace().record({
		"kind": "window_closed",
		"window_id": w.window_id,
		"nest_level": w.nest_level,
		"cause": String(cause),
	})
	return true


## Deadline check at the deterministic points (post-pop and tick boundary,
## Q37): a reached deadline first offers the pre_close hook (explicit commit
## happens there or not at all), then applies the default draft rollback +
## close — including any windows nested above the deadlined one.
func _check_deadlines() -> void:
	var tick := runtime.scheduler.current_tick
	var idx := _windows.size() - 1
	while idx >= 1:
		var w: EQWindow = _windows[idx]
		if not w.is_frozen() and tick >= w.deadline and not w.closed:
			if w.pre_close.is_valid():
				w.pre_close.call(w)
			while _windows.size() > idx:  # the deadlined window and everything nested above
				if (_windows.back() as EQWindow).closed:
					_windows.pop_back()
					continue
				_close_top(false, &"deadline")
			idx = _windows.size() - 1
			continue
		idx -= 1


## Q01/Q22 save boundary helper (wired into the save path by EQM-117): the
## effect chunk is empty AND no explicit window is open above the base level.
func is_save_boundary() -> bool:
	return chunk.is_save_allowed() and window_depth() == 0


## Schedules (or arms) a reservation per its kind. A reservation with solve
## conditions is condition-gated: it stays pending and is pushed at the tick
## its conditions are detected to hold (Q27). For a REACTION_PREPARATION,
## `reaction_condition` (EQCondition) selects the triggering events; a
## duration > 0 schedules its expiry event (§6.3). Returns the scheduler
## event_id, or -1 (armed / condition-gated / rejected).
func submit(res: EQReservation, reaction_condition = null) -> int:
	var v := res.validate()
	if not v.is_valid():
		var issue = v.errors()[0] if not v.errors().is_empty() else v.issues[0]
		runtime._fault(issue["code"], issue["message"], {"actor_id": String(res.actor_id)}, true)
		return -1
	var kind := res.definition.kind
	match kind:
		EQActionDefinition.Kind.WAIT:
			# ending the turn schedules the actor's next turn as a READY reservation
			res.status = EQReservation.Status.RESOLVED
			var ready_def := EQActionDefinition.new()
			ready_def.kind = EQActionDefinition.Kind.READY
			ready_def.delay = res.definition.delay
			return submit(EQReservation.new(res.actor_id, ready_def))
		EQActionDefinition.Kind.REACTION_PREPARATION:
			res.status = EQReservation.Status.ARMED
			engine.arm(res, reaction_condition, runtime.scheduler.current_tick)
			if res.definition.duration > 0:
				var expiry_id := runtime.schedule(res.actor_id, runtime.scheduler.current_tick + res.definition.duration, 0, &"expiry")
				if expiry_id > 0:
					_expiry_by_event[expiry_id] = res
			return -1
		_:
			var bound := _bind_conditions(res)
			if not (bound["solve"] as Array).is_empty():
				res.status = EQReservation.Status.PENDING
				_pending_conditional.append({
					"res": res, "solve": bound["solve"], "inv": bound["inv"], "view": _view_of(res),
				})
				return -1
			var id := _schedule(res, res.definition.delay if kind != EQActionDefinition.Kind.IMMEDIATE else 0)
			if id > 0 and not (bound["inv"] as Array).is_empty():
				_bound_inv[id] = bound["inv"]
			return id
	return -1


## Binds the normalized condition sets (SEM §5.6 sugar folded in) into
## evaluator terms. Declared COUNTER specs get their runtime counter line here
## (deterministic issuance). The rumination sugar keeps its runtime store
## (`remaining_ruminations`, POLICY.md) and the duration sugar for reactions is
## realized as an expiry event — both are skipped from polled terms.
func _bind_conditions(res: EQReservation) -> Dictionary:
	var n: Dictionary = res.definition.normalized_conditions()
	var ctx := {"lines": lines.ctx_lines()}
	var solve: Array = []
	var seq := 0
	for spec in n["solve"]:
		solve.append(_bind_one(spec, "solve", seq, ctx))
		seq += 1
	var inv: Array = []
	seq = 0
	for spec in n["invalidation"]:
		if spec.condition_id == &"reaction_count":
			seq += 1
			continue
		inv.append(_bind_one(spec, "invalidation", seq, ctx))
		seq += 1
	return {"solve": solve, "inv": inv}


func _bind_one(spec: EQConditionSpec, group: String, index: int, ctx: Dictionary) -> Dictionary:
	if spec.type == EQConditionSpec.Type.COUNTER:
		return EQConditionEval.bind(spec, group, index, ctx, lines.issue_counter(spec.counter_start))
	return EQConditionEval.bind(spec, group, index, ctx)


func _schedule(res: EQReservation, delay: int) -> int:
	var id := runtime.schedule(res.actor_id, runtime.scheduler.current_tick + delay, res.definition.priority, &"reservation")
	if id > 0:
		res.event_id = id
		res.status = EQReservation.Status.PENDING
		_by_event[id] = res
	return id


## Resolves the next ready reservation through the §6.1 pipeline. Returns the
## resolved reservation; null when the queue is empty or the next event is not
## a tracked reservation (the L0 path). Expiry events are consumed internally.
func resolve_next() -> EQReservation:
	last_drained = []
	while true:
		var e := runtime.advance()
		if e == null:
			return null
		lines.sync_primary(runtime.scheduler.current_tick)
		_check_deadlines()
		if _expiry_by_event.has(e.event_id):
			_resolve_expiry(e)
			continue
		var res = _by_event.get(e.event_id, null)
		if res == null:
			return null
		_by_event.erase(e.event_id)
		# step 1b — lazy invalidation at reference time (level semantics)
		var inv_terms = _bound_inv.get(e.event_id, [])
		_bound_inv.erase(e.event_id)
		if not inv_terms.is_empty():
			var inv := EQConditionEval.invalidation_check(inv_terms, _ctx(_view_of(res)))
			if int(inv["result"]) == EQConditionEval.Result.YES:
				res.status = EQReservation.Status.INVALIDATED
				_trace_invalidated(e.event_id, res.actor_id, StringName(inv["closed_by"]))
				continue
			if int(inv["result"]) == EQConditionEval.Result.FAULT:
				var f: Dictionary = inv["fault"]
				runtime._fault(f["code"], f["message"], f.get("context", {}), true)
				continue
		res.status = EQReservation.Status.RESOLVED
		if res.definition.kind == EQActionDefinition.Kind.OPERATION:
			_cause_target_reservation(res)
		# step 2/3 — declared effect into the chunk
		for r in _apply_effect(res.definition.effect_name, _view_of(res)):
			chunk.add(r)
		# rumination reschedule (count-bounded; reactions re-arm in the ENGINE
		# at fire time instead — re-submitting here would double-arm them)
		if res.definition.kind != EQActionDefinition.Kind.REACTION_PREPARATION and res.remaining_ruminations > 0:
			res.remaining_ruminations -= 1
			submit(res)
		# step 4 — sweep
		_sweep(_view_of(res))
		# step 5 — drain; chunk-empty = save boundary
		last_drained.append_array(chunk.drain())
		return res
	return null


## Advances time by one tick when no event is due: syncs the primary line,
## polls watched lines, runs the pattern-(2) sweep rules, and evaluates pending
## conditions (a held condition pushes its event at THIS tick — Q27).
func step_tick() -> void:
	runtime.scheduler.current_tick += 1
	var tick := runtime.scheduler.current_tick
	lines.sync_primary(tick)
	_check_deadlines()
	lines.poll_tick(_watched())
	lines.run_sweep_rules(runtime.registry)
	_recheck_scheduled_invalidation()
	_evaluate_pending_conditional()


## Normal-path departure (SEM §13, Q39): disarms the actor's reactions, drops
## its pending condition-gated reservations, cancels its scheduled events (via
## EQRuntime.invalidate_actor), all with `closed_by: <cause>` traces. Mode-
## neutral. Returns the number of cancelled scheduler events.
func invalidate_actor(actor_id: StringName, cause: StringName = &"actor_removed") -> int:
	for r in engine.disarm_for(actor_id):
		(r as EQReservation).status = EQReservation.Status.INVALIDATED
		_trace_invalidated(-1, actor_id, cause)
	var still: Array[Dictionary] = []
	for p in _pending_conditional:
		if (p["res"] as EQReservation).actor_id == actor_id:
			(p["res"] as EQReservation).status = EQReservation.Status.INVALIDATED
			_trace_invalidated(-1, actor_id, cause)
		else:
			still.append(p)
	_pending_conditional = still
	for event_id in _by_event.keys():
		if (_by_event[event_id] as EQReservation).actor_id == actor_id:
			(_by_event[event_id] as EQReservation).status = EQReservation.Status.INVALIDATED
			_by_event.erase(event_id)
			_bound_inv.erase(event_id)
	for event_id in _expiry_by_event.keys():
		if (_expiry_by_event[event_id] as EQReservation).actor_id == actor_id:
			_expiry_by_event.erase(event_id)
	return runtime.invalidate_actor(actor_id, cause)


# --- pipeline internals ----------------------------------------------------

## §6.3 — an expiry event resolves: still armed -> close with `closed_by:
## duration` (+ optional expiry effect, through the pipeline); already closed
## -> a lightweight `closed_by: already_closed` record.
func _resolve_expiry(e) -> void:
	var res: EQReservation = _expiry_by_event[e.event_id]
	_expiry_by_event.erase(e.event_id)
	if res.status == EQReservation.Status.ARMED:
		engine.disarm(res)
		res.status = EQReservation.Status.INVALIDATED
		_trace_invalidated(e.event_id, res.actor_id, &"duration")
		for r in _apply_effect(res.definition.expiry_effect_name, _view_of(res)):
			chunk.add(r)
		_sweep(_view_of(res))
		last_drained.append_array(chunk.drain())
	else:
		_trace_invalidated(e.event_id, res.actor_id, &"already_closed")


## §6.1 step 2 — declared linkage: empty = effect-less; set-but-unregistered =
## stable error (dev halt / shipped skip), never a silent skip.
func _apply_effect(name: StringName, view: Dictionary) -> Array:
	if name == &"":
		return []
	if not runtime.has_effect(name):
		runtime._fault(EQError.EFFECT_UNREGISTERED, "effect '%s' has no registered handler" % name, {"effect": String(name)}, true)
		return []
	var out = (runtime.effects()[name] as Callable).call(view)
	return out if out is Array else []


## §6.2/§6.1 step 4 — the sweep point: fire triggers (fired reactions are
## SCHEDULED at the current tick with their declared priority, bounded by
## same-tick rounds), re-check numeric invalidation, evaluate pending
## conditions.
func _sweep(view: Dictionary) -> void:
	var tick := runtime.scheduler.current_tick
	var fired := engine.on_event_resolved(view, tick)
	if not fired.is_empty():
		if tick == _cascade_tick:
			_cascade_round += 1
		else:
			_cascade_tick = tick
			_cascade_round = 1
		if _cascade_round > max_cascade_rounds:
			runtime._fault(EQError.TRIGGER_CHAIN_LIMIT, "same-tick reaction cascade exceeded %d rounds" % max_cascade_rounds, {"tick": tick}, true)
		else:
			for res in fired:
				var consumed: bool = (res as EQReservation).status == EQReservation.Status.RESOLVED
				if consumed:
					# the armed slot closed by count exhaustion (its final
					# resolution still happens through the schedule below)
					_trace_invalidated(-1, (res as EQReservation).actor_id, &"reaction_count")
				var id := _schedule(res, 0)
				runtime.trace().record({
					"kind": "reaction_fired",
					"round": _cascade_round,
					"actor": String((res as EQReservation).actor_id),
					"event_id": id,
				})
	_recheck_scheduled_invalidation()
	_evaluate_pending_conditional()


## §5.3 numeric "eager": invalidation terms of scheduled reservations are
## re-evaluated at every sweep; a holding term cancels the event with its
## `closed_by` — looks eager, evaluated at a defined point.
func _recheck_scheduled_invalidation() -> void:
	for event_id in _bound_inv.keys():
		var res: EQReservation = _by_event.get(event_id, null)
		if res == null:
			_bound_inv.erase(event_id)
			continue
		var inv := EQConditionEval.invalidation_check(_bound_inv[event_id], _ctx(_view_of(res)))
		if int(inv["result"]) == EQConditionEval.Result.YES:
			runtime.scheduler.cancel(event_id)
			res.status = EQReservation.Status.INVALIDATED
			_by_event.erase(event_id)
			_bound_inv.erase(event_id)
			_trace_invalidated(event_id, res.actor_id, StringName(inv["closed_by"]))


## §5.4 — pending condition-gated reservations: a held solve set pushes the
## event at the detection tick (fresh sequence, declared priority); a held
## invalidation drops it (invalidation-wins).
func _evaluate_pending_conditional() -> void:
	var still: Array[Dictionary] = []
	for p in _pending_conditional:
		var res: EQReservation = p["res"]
		var ctx := _ctx(p["view"])
		var solve := EQConditionEval.solve_holds(p["solve"], ctx)
		var inv := EQConditionEval.invalidation_check(p["inv"], ctx)
		match EQConditionEval.decide(solve, inv):
			EQConditionEval.Outcome.INVALIDATE:
				res.status = EQReservation.Status.INVALIDATED
				_trace_invalidated(-1, res.actor_id, StringName(inv["closed_by"]))
			EQConditionEval.Outcome.RESOLVE:
				var id := _schedule(res, 0)
				if id > 0 and not (p["inv"] as Array).is_empty():
					_bound_inv[id] = p["inv"]
			EQConditionEval.Outcome.FAULT:
				var f: Dictionary = (inv["fault"] if inv["fault"] != null else solve["fault"])
				runtime._fault(f["code"], f["message"], f.get("context", {}), true)
			_:
				still.append(p)
	_pending_conditional = still


func _watched() -> Dictionary:
	var term_sets: Array = []
	for p in _pending_conditional:
		term_sets.append(p["solve"])
		term_sets.append(p["inv"])
	for event_id in _bound_inv:
		term_sets.append(_bound_inv[event_id])
	return EQEventLines.derive_watched(term_sets)


func _ctx(view: Dictionary) -> Dictionary:
	return {"lines": lines.ctx_lines(), "predicates": runtime.predicates(), "view": view}


func _view_of(res: EQReservation) -> Dictionary:
	return {
		"kind": &"reservation",
		"source": res.actor_id,
		"target": res.target_id,
		"tags": res.definition.tags if res.definition != null else [],
	}


func _trace_invalidated(event_id: int, actor_id: StringName, closed_by: StringName) -> void:
	var fields := {
		"kind": "event_invalidated",
		"actor": String(actor_id),
		"closed_by": String(closed_by),
	}
	if event_id > 0:
		fields["event_id"] = event_id
	runtime.trace().record(fields)


## An OPERATION reservation, on resolving, makes its target hold a reaction
## reservation tagged with the operation's target tag.
func _cause_target_reservation(op_res: EQReservation) -> void:
	var def := EQActionDefinition.new()
	def.kind = EQActionDefinition.Kind.REACTION_PREPARATION
	def.duration = EQActionDefinition.DURATION_UNLIMITED
	def.tags = [op_res.definition.operation_target_tag]
	submit(EQReservation.new(op_res.target_id, def))


## Reaction preparations currently armed for an actor.
func armed_for(actor_id: StringName) -> Array:
	return engine.armed_for(actor_id).map(func(a): return a["reservation"])


## Reservations scheduled (pending) but not yet resolved.
func pending() -> Array:
	return _by_event.values()


## Condition-gated reservations awaiting their solve conditions (SEM §5.4).
func pending_conditional() -> Array:
	return _pending_conditional.map(func(p): return p["res"])
