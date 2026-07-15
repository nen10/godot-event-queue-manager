class_name EQReservationRuntime
extends RefCounted
## L2 resolution pipeline over an EQRuntime — THE one integration contract
## (SEM §6.1, EQM-113). One resolution is exactly:
##
##   1. pop    — runtime.advance() (lazy invalidation: level-evaluated
##               invalidation terms drop the event with `closed_by`)
##   2. effect — the declared named effect handler (legacy Array or versioned
##               EQEffectCommitResult; empty = effect-less; set-but-
##               unregistered = stable error, never a silent skip)
##   3. chunk  — successful returned EQEffectRecords append to the effect chunk
##   4. sweep  — successful ordered event views are swept at one outer batch
##               boundary; triggers are SCHEDULED (never resolved in place,
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
const EQCondition := preload("../resources/eq_condition.gd")
const EQConditionEval := preload("eq_condition_eval.gd")
const EQEventLines := preload("eq_event_lines.gd")
const EQEffectChunk := preload("eq_effect_chunk.gd")
const EQEffectCommitResult := preload("eq_effect_commit_result.gd")
const EQReactionFireContext := preload("eq_reaction_fire_context.gd")
const EQTriggerEngine := preload("eq_trigger_engine.gd")
const EQSnapshot := preload("eq_snapshot.gd")
const EQWindow := preload("eq_window.gd")
const EQTransaction := preload("eq_transaction.gd")

## Outcome of one exact scheduler-pop boundary. `resolve_next()` preserves its
## compatibility behavior by continuing across EXPIRY / INVALIDATED / FAULT.
enum ScheduledEventOutcome {
	EMPTY,
	EXPIRY,
	RESERVATION,
	INVALIDATED,
	FAULT,
	UNTRACKED,
}

var runtime: EQRuntime
var lines: EQEventLines
var chunk: EQEffectChunk
var engine: EQTriggerEngine
## Optional relation graph (EQRelationGraph, L3 — SEM §13.1). When attached,
## actor departure dissolves its incident relations through the declared
## on_dissolve rules (EQM-122); the §6.4 expansion consumes it (EQM-123).
var relations = null
## Optional state algebra (EQStateAlgebra, L3 — SEM §5.7). Runtime holds this as
## an optional reference only; save/load uses in-place restore to avoid wrapper
## replay and keeps state transitions stable.
var state_algebra = null

## Records drained by the last resolve_next() or resolve_one_scheduled_event()
## call (§6.1 step 5).
var last_drained: Array = []
## Ephemeral value projection of the most recently attempted single-reservation
## effect commit. Read through last_effect_commit_outcome(); it is intentionally
## outside snapshot state and empty before / when no reservation was attempted.
var _last_effect_commit_outcome: Dictionary = {}
## Engineering backstop for same-tick reaction cascades (§6.2 bounded rounds).
var max_cascade_rounds: int = 8
## Absolute window-nest backstop (SEM §8 engineering max depth, EQM-114).
var max_window_depth: int = 16

var _order_hook: Callable = Callable()


## Deep-copy inspection surface. SUCCESS contains version/status plus value
## records and ordered event_views; FAILURE contains version/status/diagnostic.
func last_effect_commit_outcome() -> Dictionary:
	return _last_effect_commit_outcome.duplicate(true)


## Deep-copy inspection of one scheduled reaction FIRE occurrence. Empty means
## the event is not a reaction FIRE (or no longer pending).
func reaction_fire_context_for_event(event_id: int) -> Dictionary:
	var context = _reaction_fire_context_by_event.get(event_id, {})
	return EQReactionFireContext.copy(context) if context is Dictionary else {}


## Registers the acceptance ordering hook (SEM §7.1, Q20/Q38, EQM-115):
## `func(candidates: Array[Dictionary]) -> Array[int]` — a permutation of
## candidate indices. Candidates are EQM-built serializable views (index /
## actor / stats / tags / priority / nest_level / lines); float may appear in
## stats (the §7 scoped exception) but the output is ints only. Unset = the
## final fallback, issuance order. The hook must be deterministic (its output
## participates in the canonical trace).
func set_order_hook(hook: Callable) -> void:
	_order_hook = hook


## Orders simultaneously-resolvable entries through the hook (identity when
## unset or singleton). An invalid permutation is a stable fault and falls back
## to issuance order — never silently adopted.
func _order_candidates(entries: Array, get_res: Callable) -> Array:
	if entries.size() <= 1 or not _order_hook.is_valid():
		return entries
	var line_values := lines.ctx_lines()
	var views: Array = []
	for i in range(entries.size()):
		var res: EQReservation = get_res.call(entries[i])
		var stats := {}
		if runtime.registry.is_registered(res.actor_id):
			stats = (runtime.registry.get_state(res.actor_id).data as Dictionary).duplicate(true)
		views.append({
			"index": i,
			"actor": String(res.actor_id),
			"stats": stats,
			"tags": Array(res.definition.tags).map(func(x): return String(x)) if res.definition != null else [],
			"priority": res.definition.priority if res.definition != null else 0,
			"nest_level": window_depth(),
			"lines": line_values,
		})
	var out = _order_hook.call(views)
	var ok := out is Array and (out as Array).size() == entries.size()
	if ok:
		var seen := {}
		for v in out:
			var idx := int(v)
			if idx < 0 or idx >= entries.size() or seen.has(idx):
				ok = false
				break
			seen[idx] = true
	if not ok:
		runtime._fault(EQError.ORDER_HOOK_INVALID, "order hook returned an invalid permutation", {"count": entries.size()}, true)
		return entries
	var ordered: Array = []
	var order_ints: Array = []
	for v in out:
		ordered.append(entries[int(v)])
		order_ints.append(int(v))
	runtime.trace().record({"kind": "order_hook_applied", "count": entries.size(), "order": order_ints})
	return ordered


## EQM-123: register or replace a target expansion rule for an effect-tagged action.
## Rule: {"relation_type": StringName, "effect_tag": StringName, "hop_cost": int (>0), "budget": int (>0)}
func declare_expansion_rule(rule: Dictionary) -> bool:
	if typeof(rule) != TYPE_DICTIONARY:
		runtime._fault(EQError.CONDITION_LINE_UNKNOWN, "expansion rule must be a Dictionary", {}, false)
		return false
	if not _is_serializable(rule):
		runtime._fault(EQError.CONDITION_LINE_UNKNOWN, "expansion rule must be serializable", {}, false)
		return false
	var relation_type := StringName(rule.get("relation_type", ""))
	if relation_type == &"":
		runtime._fault(EQError.POLICY_NAME_EMPTY, "expansion rule relation_type must not be empty", {"relation_type": ""}, false)
		return false
	var effect_tag := StringName(rule.get("effect_tag", ""))
	if effect_tag == &"":
		runtime._fault(EQError.POLICY_NAME_EMPTY, "expansion rule effect_tag must not be empty", {"effect_tag": ""}, false)
		return false
	var hop_cost := rule.get("hop_cost", 0)
	if typeof(hop_cost) != TYPE_INT or hop_cost <= 0:
		runtime._fault(EQError.CONDITION_COUNTER_START_INVALID, "expansion rule hop_cost must be a positive int", {"relation_type": String(relation_type), "effect_tag": String(effect_tag)}, false)
		return false
	var budget := rule.get("budget", 0)
	if typeof(budget) != TYPE_INT or budget <= 0:
		runtime._fault(EQError.CONDITION_COUNTER_START_INVALID, "expansion rule budget must be a positive int", {"relation_type": String(relation_type), "effect_tag": String(effect_tag)}, false)
		return false
	_expansion_rules[_expansion_key(relation_type, effect_tag)] = {
		"relation_type": relation_type,
		"effect_tag": effect_tag,
		"hop_cost": int(hop_cost),
		"budget": int(budget),
	}
	return true


## EQM-123: register or replace a transform declaration.
## Declaration shape:
## {"name": StringName, "match_tags": Array[StringName], "kind": "retarget"|"state_inv",
##  "params": Dictionary, "meta_level": int, "priority": int}
func register_transform(decl: Dictionary) -> bool:
	if typeof(decl) != TYPE_DICTIONARY:
		runtime._fault(EQError.CONDITION_LINE_UNKNOWN, "transform declaration must be a Dictionary", {}, false)
		return false
	if not _is_serializable(decl):
		runtime._fault(EQError.CONDITION_LINE_UNKNOWN, "transform declaration must be serializable", {}, false)
		return false
	var name := String(decl.get("name", ""))
	if name == &"":
		runtime._fault(EQError.POLICY_NAME_EMPTY, "transform name must not be empty", {}, false)
		return false

	var match_tags: Array = decl.get("match_tags", [])
	if match_tags is not Array or match_tags.is_empty():
		runtime._fault(EQError.CONDITION_PREDICATE_NAME_EMPTY, "transform match_tags must be a non-empty array", {"transform": String(name)}, false)
		return false
	for t in match_tags:
		if typeof(t) != TYPE_STRING and typeof(t) != TYPE_STRING_NAME:
			runtime._fault(EQError.CONDITION_PREDICATE_NAME_EMPTY, "transform match_tags must be StringName", {"transform": String(name)}, false)
			return false

	var kind := String(decl.get("kind", ""))
	if kind != "retarget" and kind != "state_inv":
		runtime._fault(EQError.CONDITION_LINE_UNKNOWN, "unknown transform kind: %s" % kind, {"transform": String(name), "kind": kind}, false)
		return false

	var params := decl.get("params", {})
	if params is not Dictionary:
		runtime._fault(EQError.CONDITION_LINE_UNKNOWN, "transform params must be a Dictionary", {"transform": String(name)}, false)
		return false
	var meta_level := decl.get("meta_level", 0)
	if typeof(meta_level) != TYPE_INT:
		runtime._fault(EQError.CONDITION_COUNTER_START_INVALID, "transform meta_level must be an int", {"transform": String(name)}, false)
		return false
	var priority := decl.get("priority", 0)
	if typeof(priority) != TYPE_INT:
		runtime._fault(EQError.CONDITION_COUNTER_START_INVALID, "transform priority must be an int", {"transform": String(name)}, false)
		return false

	if kind == "retarget":
		var stage = params.get("stage", "")
		if typeof(stage) == TYPE_STRING or typeof(stage) == TYPE_STRING_NAME:
			var stage_name := str(stage)
			if stage_name != "root" and stage_name != "direct":
				runtime._fault(EQError.CONDITION_LINE_UNKNOWN, "retarget params.stage must be root|direct", {"transform": String(name), "stage": stage_name}, false)
				return false
		elif typeof(stage) != TYPE_INT:
			runtime._fault(EQError.CONDITION_LINE_UNKNOWN, "retarget params.stage must be root|direct|int", {"transform": String(name), "stage": str(stage)}, false)
			return false
	else:
		var pair: Array = params.get("pair", [])
		if pair is not Array or pair.size() != 2:
			runtime._fault(EQError.CONDITION_LINE_UNKNOWN, "state_inv params must be pair: [StringName, StringName]", {"transform": String(name)}, false)
			return false
		for p in pair:
			if typeof(p) != TYPE_STRING and typeof(p) != TYPE_STRING_NAME:
				runtime._fault(EQError.CONDITION_PREDICATE_NAME_EMPTY, "state_inv pair entries must be StringName", {"transform": String(name)}, false)
				return false
			if StringName(p) == &"":
				runtime._fault(EQError.POLICY_NAME_EMPTY, "state_inv pair entries must not be empty", {"transform": String(name)}, false)
				return false

	var entry := {
		"name": name,
		"match_tags": match_tags.map(func(x): return StringName(x)),
		"kind": kind,
		"params": params.duplicate(true),
		"meta_level": int(meta_level),
		"priority": int(priority),
	}
	if _transforms.has(name):
		entry["order"] = _transforms[name].get("order", 0)
	else:
		_transform_seq += 1
		_transform_order.append(String(name))
		entry["order"] = _transform_seq
	_transforms[name] = entry
	return true


func _expansion_key(relation_type: StringName, effect_tag: StringName) -> String:
	return String(relation_type) + "|" + String(effect_tag)


func _matching_expansion_rules(tags: Array) -> Array:
	var tag_set := {}
	for t in tags:
		tag_set[String(t)] = true
	var out: Array = []
	for r in _expansion_rules.values():
		if tag_set.has(String(r.get("effect_tag", ""))):
			out.append(r)
	if out.is_empty():
		return out
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if String(a.get("effect_tag", "")) == String(b.get("effect_tag", "")):
			return String(a.get("relation_type", "")) < String(b.get("relation_type", ""))
		return String(a.get("effect_tag", "")) < String(b.get("effect_tag", ""))
	)
	return out


func _matching_transforms(res: EQReservation) -> Array:
	var tags := res.definition.tags if res.definition != null else []
	var out: Array = []
	for name in _transform_order:
		if not _transforms.has(name):
			continue
		var transform: Dictionary = _transforms[name]
		if _transform_matches(transform, tags):
			out.append(transform)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("meta_level", 0)) != int(b.get("meta_level", 0)):
			return int(a.get("meta_level", 0)) > int(b.get("meta_level", 0))
		if int(a.get("priority", 0)) != int(b.get("priority", 0)):
			return int(a.get("priority", 0)) > int(b.get("priority", 0))
		return int(a.get("order", 0)) < int(b.get("order", 0))
	)
	return out


func _transform_matches(transform: Dictionary, tags: Array) -> bool:
	for t in transform.get("match_tags", []):
		for tag in tags:
			if String(tag) == String(t):
				return true
	return false

var _by_event: Dictionary = {}          # event_id -> EQReservation (scheduled)
var _bound_inv: Dictionary = {}         # event_id -> Array bound invalidation terms
var _expiry_by_event: Dictionary = {}   # expiry event_id -> EQReservation
## scheduled FIRE event_id -> immutable/versioned cause value
var _reaction_fire_context_by_event: Dictionary = {}
var _pending_conditional: Array[Dictionary] = []  # {res, solve, inv, view} in submit order
var _cascade_tick: int = -1
var _cascade_round: int = 0
var _windows: Array = []   # LIFO; [0] is the implicit root (nest 0, never traced/closed)
var _window_seq: int = 0
## event_id -> explicit window_id (scheduled at submit-time, if top is explicit).
var _window_of_event: Dictionary = {}
var _race_groups: Dictionary = {}   # race_group id -> Array[EQReservation]
var _race_of: Dictionary = {}       # reservation instance_id -> race_group id
var _race_seq: int = 0
## 2a expansion declarations keyed by "<relation_type>|<effect_tag>".
var _expansion_rules: Dictionary = {}
## 2b transform declarations keyed by name.
var _transforms: Dictionary = {}
var _transform_order: Array[String] = []
var _transform_seq: int = 0
## Bundle bookkeeping (ephemeral, intra-tick).
var _bundle_seq: int = 0
var _bundle_of: Dictionary = {}          # event_id -> bundle id
var _bundle_members: Dictionary = {}      # bundle id -> Array[event_id]
## Safety bound for recursive transform rounds.
var max_transform_rounds: int = 8
## Deterministic phase checkpoint sequence.
var _phase_seq: int = 0


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
func open_window(owner: StringName, kind: StringName, deadline: int = EQWindow.DEADLINE_UNLIMITED, cost: int = 0, budget_key: StringName = &"", meta_level: int = 0) -> EQWindow:
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
	w.meta_level = meta_level
	w.draft = EQTransaction.new(runtime.scheduler)
	_windows.append(w)
	var opened := {
		"kind": "window_opened",
		"window_id": w.window_id,
		"owner": String(owner),
		"window_kind": String(kind),
		"nest_level": w.nest_level,
		"deadline": deadline,
	}
	if meta_level != 0:
		opened["meta_level"] = meta_level
	runtime.trace().record(opened)
	return w


func _as_string_array(values: Array) -> Array:
	var out: Array = []
	for v in values:
		out.append(String(v))
	return out


## Opens a phase checkpoint inside the top explicit window. `inputs` are mirrored
## mirror-input slots for loop rollback.
func open_phase(name: StringName, inputs: Array = []) -> bool:
	if window_depth() <= 0:
		runtime._fault(EQError.WINDOW_CLOSE_INVALID, "open_phase requires an explicit window", {}, true)
		return false
	if name == &"":
		runtime._fault(EQError.POLICY_NAME_EMPTY, "open_phase name must not be empty", {}, true)
		return false
	var w: EQWindow = current_window()
	if w == null:
		runtime._fault(EQError.WINDOW_CLOSE_INVALID, "open_phase target window does not exist", {}, true)
		return false
	var history: Array = w.phase_checkpoints
	var reopening := -1
	for i in range(history.size()):
		if String(history[i].get("name", "")) == String(name):
			reopening = i
			break
	if reopening >= 0:
		var replay_from: Dictionary = history[reopening]
		var rolled_back_from: Array = []
		var cleared_inputs: Array = _as_string_array(replay_from.get("inputs", []))
		while history.size() > reopening + 1:
			var cp: Dictionary = history.pop_back()
			rolled_back_from.append(String(cp.get("name", "")))
			cleared_inputs.append_array(_as_string_array(cp.get("inputs", [])))
		if runtime.scheduler.restore(replay_from.get("snapshot", {})) != EQSnapshot.Load.OK:
			runtime._fault(EQError.CONDITION_LINE_UNKNOWN, "phase checkpoint restore failed", {"phase": String(name)}, true)
			return false
		_reconcile_runtime_state_after_snapshot_restore()
		cleared_inputs.sort()
		runtime.trace().record({
			"kind": "phase_rolled_back",
			"window_id": w.window_id,
			"phase": String(name),
			"rolled_back_from": rolled_back_from,
			"cleared_inputs": cleared_inputs,
		})
		return false
	_phase_seq += 1
	var cp := {
		"name": name,
		"snapshot": runtime.scheduler.snapshot(),
		"inputs": _as_string_array(inputs),
		"seq": _phase_seq,
	}
	history.append(cp)
	runtime.trace().record({
		"kind": "phase_opened",
		"window_id": w.window_id,
		"phase": String(name),
		"seq": _phase_seq,
	})
	return true


## Closes the top phase checkpoint in the explicit window.
## commit=true: discard the checkpoint only. commit=false: restore snapshot.
func close_phase(commit: bool = true) -> bool:
	if window_depth() <= 0:
		runtime._fault(EQError.WINDOW_CLOSE_INVALID, "close_phase has no explicit window", {}, true)
		return false
	var w: EQWindow = current_window()
	if w == null or w.phase_checkpoints.is_empty():
		runtime._fault(EQError.WINDOW_CLOSE_INVALID, "close_phase requires an open phase", {}, true)
		return false
	var cp: Dictionary = w.phase_checkpoints.pop_back()
	if not commit:
		if runtime.scheduler.restore(cp.get("snapshot", {})) != EQSnapshot.Load.OK:
			runtime._fault(EQError.CONDITION_LINE_UNKNOWN, "phase checkpoint restore failed", {"phase": String(cp.get("name", ""))}, true)
			return false
		_reconcile_runtime_state_after_snapshot_restore()
	runtime.trace().record({
		"kind": "phase_closed",
		"window_id": w.window_id,
		"phase": String(cp.get("name", "")),
		"committed": commit,
	})
	return true


## Attempts an intervention close on a target explicit window. Insufficient meta
## levels only avoid the close (non-fault); equal-or-greater levels close the
## target and all explicitly nested windows above it.
func intervene_close(window_id: int, intervener: Dictionary) -> bool:
	if _windows.size() <= 1:
		runtime._fault(EQError.WINDOW_CLOSE_INVALID, "intervene_close has no explicit windows to close", {"window_id": window_id}, true)
		return false
	var target_idx := -1
	var target_meta := 0
	for i in range(1, _windows.size()):
		var w: EQWindow = _windows[i]
		if not w.closed and w.window_id == window_id:
			target_idx = i
			target_meta = w.meta_level
			break
	if target_idx < 0:
		runtime._fault(EQError.WINDOW_CLOSE_INVALID, "intervene_close target window does not exist or is already closed", {"window_id": window_id}, true)
		return false
	var intervener_meta := int(intervener.get("meta_level", 0))
	if intervener_meta < target_meta:
		var avoided := {
			"kind": "intervention_avoided",
			"window_id": window_id,
			"window_meta": target_meta,
			"intervener_meta": intervener_meta,
		}
		if intervener.has("event_id"):
			avoided["intervener_event_id"] = int(intervener.get("event_id", -1))
		runtime.trace().record(avoided)
		return false
	var intervener_event_id := int(intervener.get("event_id", -1))
	while _windows.size() > target_idx:
		var top: EQWindow = _windows.back()
		if top.closed:
			_windows.pop_back()
			continue
		if top.pre_close.is_valid():
			top.pre_close.call(top)
		_cancel_window_pending_members(top.window_id)
		if top.draft != null:
			top.draft.rollback()
		top.phase_checkpoints = []
		top.closed = true
		_windows.pop_back()
		var closed := {
			"kind": "window_closed",
			"window_id": top.window_id,
			"nest_level": top.nest_level,
			"cause": "intervention",
			"window_meta": top.meta_level,
			"intervener_meta": intervener_meta,
		}
		if intervener_event_id > -1:
			closed["intervener_event_id"] = intervener_event_id
		runtime.trace().record(closed)
	return true


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
	w.phase_checkpoints = []
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


func _reconcile_runtime_state_after_snapshot_restore() -> void:
	var live_event_ids: Dictionary = {}
	for e in runtime.scheduler.peek(runtime.scheduler.size()):
		live_event_ids[int(e.event_id)] = true
	for event_id in _window_of_event.keys():
		if not live_event_ids.has(int(event_id)):
			_window_of_event.erase(event_id)
	for event_id in _bound_inv.keys():
		if not live_event_ids.has(int(event_id)):
			_bound_inv.erase(event_id)
	for event_id in _bundle_of.keys():
		if not live_event_ids.has(int(event_id)):
			_bundle_of.erase(event_id)
	for event_id in _by_event.keys():
		if not live_event_ids.has(int(event_id)):
			_by_event.erase(event_id)
			_reaction_fire_context_by_event.erase(event_id)
			_clear_bundle_event_link(int(event_id))
			_window_of_event.erase(event_id)
			_bound_inv.erase(event_id)
	for event_id in _reaction_fire_context_by_event.keys():
		if not live_event_ids.has(int(event_id)) or not _by_event.has(event_id):
			_reaction_fire_context_by_event.erase(event_id)
	var dead_bundles: Array[StringName] = []
	for bid in _bundle_members.keys():
		var members: Array = _bundle_members[bid]
		var kept: Array = []
		for raw in members:
			if live_event_ids.has(int(raw)):
				kept.append(int(raw))
		if kept.is_empty():
			dead_bundles.append(bid)
		else:
			_bundle_members[bid] = kept
	for bid in dead_bundles:
		_bundle_members.erase(bid)
	for event_id in _expiry_by_event.keys():
		if not live_event_ids.has(int(event_id)):
			_expiry_by_event.erase(event_id)


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


# --- snapshot v2 pipeline tables (SEM §10, EQM-117) -------------------------
# The save bundle carries these ADDITIVE tables next to the scheduler snapshot.
# Callables are never serialized; the loader verifies name registrations before
# mutating anything (verify-before-mutate). Open race groups are NOT persisted
# (POLICY: members are; only the winner's bulk loser-sweep is lost across a
# save — losers still close by their own invalidation conditions).

func save_state() -> Dictionary:
	var expiry_of := {}
	var expiry_event_ids: Array = _expiry_by_event.keys()
	expiry_event_ids.sort()
	var reaction_expiries: Array = []
	for event_id in expiry_event_ids:
		expiry_of[(_expiry_by_event[event_id] as EQReservation).get_instance_id()] = event_id
		reaction_expiries.append({
			"event_id": int(event_id),
			"reservation": (_expiry_by_event[event_id] as EQReservation).to_dict(),
		})
	var armed: Array = []
	for entry in engine.armed_entries():
		var res: EQReservation = entry["reservation"]
		armed.append({
			"reservation": res.to_dict(),
			"condition": entry["condition"].to_dict() if entry["condition"] != null else {},
			"armed_at": int(entry["armed_at"]),
			"expiry_event_id": int(expiry_of.get(res.get_instance_id(), -1)),
		})
	var conditional: Array = []
	for p in _pending_conditional:
		conditional.append({
			"reservation": (p["res"] as EQReservation).to_dict(),
			"solve": (p["solve"] as Array).duplicate(true),
			"inv": (p["inv"] as Array).duplicate(true),
			"view": (p["view"] as Dictionary).duplicate(true),
		})
	var scheduled: Array = []
	for event_id in _by_event:
		scheduled.append({
			"event_id": int(event_id),
			"reservation": (_by_event[event_id] as EQReservation).to_dict(),
			"inv": (_bound_inv.get(event_id, []) as Array).duplicate(true),
			"reaction_fire_context": reaction_fire_context_for_event(int(event_id)),
		})
	return {
		"event_lines": lines.to_dict(),
		"relations": relations.to_dict() if relations != null else {},
		"state_algebra": state_algebra.to_dict() if state_algebra != null else {},
		"windows": [],  # boundary-gated saves always have depth 0 (POLICY)
		"armed_triggers": armed,
		"reaction_expiries": reaction_expiries,
		"pending_conditional": conditional,
		"scheduled_reservations": scheduled,
	}


## Verify-before-mutate (SEM §5.5/§6.1): every name the bundle references must
## already be registered on THIS instance, and every saved legacy/typed handler
## mode must match that registry. Returns true when safe to apply.
func verify_state(data: Dictionary) -> bool:
	var save_schema_version := int(data.get("schema_version", -1))
	var require_effect_result_bindings := save_schema_version >= 4
	var lines_d: Dictionary = data.get("event_lines", {})
	var relations_d: Dictionary = data.get("relations", {})
	var state_algebra_d: Dictionary = data.get("state_algebra", {})
	var registered := lines.sweep_rule_names()
	if not (relations_d is Dictionary):
		runtime._fault(EQError.CONDITION_LINE_UNKNOWN, "relations table must be a Dictionary", {}, true)
		return false
	if not (state_algebra_d is Dictionary):
		runtime._fault(EQError.CONDITION_LINE_UNKNOWN, "state_algebra table must be a Dictionary", {}, true)
		return false
	if not relations_d.is_empty() and relations == null:
		runtime._fault(EQError.CONDITION_LINE_UNKNOWN, "relations were saved, but this runtime has no relation graph", {}, true)
		return false
	if not state_algebra_d.is_empty() and state_algebra == null:
		runtime._fault(EQError.CONDITION_LINE_UNKNOWN, "state_algebra was saved, but this runtime has no state algebra", {}, true)
		return false
	for decl in relations_d.get("relation_types", []):
		if decl is not Dictionary:
			continue
		var maintenance := (decl as Dictionary).get("maintenance", null)
		if maintenance is Dictionary and int(maintenance.get("type", -1)) == EQConditionSpec.Type.NAMED_PREDICATE:
			var predicate_name := StringName(maintenance.get("predicate_name", ""))
			if predicate_name == &"" or not runtime.has_predicate(predicate_name):
				runtime._fault(EQError.CONDITION_PREDICATE_UNREGISTERED, "maintenance predicate '%s' in the save is not registered" % predicate_name, {"predicate": String(predicate_name)}, true)
				return false
	for name in lines_d.get("sweep_rules", []):
		if not registered.has(StringName(name)):
			runtime._fault(EQError.CONDITION_PREDICATE_UNREGISTERED, "sweep rule '%s' in the save is not registered" % name, {"name": String(name)}, true)
			return false
	var term_sets: Array = []
	for c in data.get("pending_conditional", []):
		term_sets.append(c.get("solve", []))
		term_sets.append(c.get("inv", []))
	for s in data.get("scheduled_reservations", []):
		term_sets.append(s.get("inv", []))
	for terms in term_sets:
		for term in terms:
			if int(term.get("type", -1)) == EQConditionSpec.Type.NAMED_PREDICATE and not runtime.has_predicate(StringName(term.get("predicate_name", ""))):
				runtime._fault(EQError.CONDITION_PREDICATE_UNREGISTERED, "predicate '%s' in the save is not registered" % term.get("predicate_name", ""), {}, true)
				return false
	var live_scheduler_event_ids := {}
	var scheduler_entries_by_event := {}
	var scheduler_table = data.get("scheduler", {})
	if scheduler_table is Dictionary:
		for entry_value in (scheduler_table as Dictionary).get("entries", []):
			if entry_value is Dictionary:
				var scheduler_event_id := int(
					(entry_value as Dictionary).get("event_id", -1)
				)
				live_scheduler_event_ids[scheduler_event_id] = true
				scheduler_entries_by_event[scheduler_event_id] = entry_value
	var seen_scheduled_event_ids := {}
	for scheduled_value in data.get("scheduled_reservations", []):
		if typeof(scheduled_value) != TYPE_DICTIONARY:
			runtime._fault(
				EQError.REACTION_FIRE_CONTEXT_INVALID,
				"scheduled reservation row must be a Dictionary",
				{"reason": "row_type"},
				true
			)
			return false
		var scheduled: Dictionary = scheduled_value
		var scheduled_event_id := int(scheduled.get("event_id", -1))
		if (
			scheduled_event_id < 1
			or seen_scheduled_event_ids.has(scheduled_event_id)
			or not live_scheduler_event_ids.has(scheduled_event_id)
		):
			runtime._fault(
				EQError.REACTION_FIRE_CONTEXT_INVALID,
				"scheduled reservation event identity is duplicate or orphaned",
				{"event_id": scheduled_event_id, "reason": "event_identity"},
				true
			)
			return false
		seen_scheduled_event_ids[scheduled_event_id] = true
		var reservation_value = scheduled.get("reservation", {})
		if typeof(reservation_value) != TYPE_DICTIONARY:
			runtime._fault(
				EQError.REACTION_FIRE_CONTEXT_INVALID,
				"scheduled reservation payload must be a Dictionary",
				{"reason": "reservation_type"},
				true
			)
			return false
		var definition_value = (reservation_value as Dictionary).get("definition", {})
		var is_reaction_fire := (
			definition_value is Dictionary
			and int((definition_value as Dictionary).get("kind", -1))
			== EQActionDefinition.Kind.REACTION_PREPARATION
		)
		if save_schema_version >= 5 and not scheduled.has("reaction_fire_context"):
			runtime._fault(
				EQError.REACTION_FIRE_CONTEXT_MISSING,
				"schema 5 scheduled reservation is missing reaction_fire_context",
				{"event_id": int(scheduled.get("event_id", -1)), "reason": "missing_field"},
				true
			)
			return false
		var fire_context = scheduled.get("reaction_fire_context", {})
		if is_reaction_fire and save_schema_version < 5:
			runtime._fault(
				EQError.REACTION_FIRE_CONTEXT_MISSING,
				"historical save cannot represent a pending reaction FIRE cause",
				{
					"event_id": int(scheduled.get("event_id", -1)),
					"schema_version": save_schema_version,
					"reason": "context_not_supported_by_schema",
				},
				true
			)
			return false
		if is_reaction_fire:
			if typeof(fire_context) != TYPE_DICTIONARY or (fire_context as Dictionary).is_empty():
				runtime._fault(
					EQError.REACTION_FIRE_CONTEXT_MISSING,
					"pending reaction FIRE is missing its cause context",
					{"event_id": int(scheduled.get("event_id", -1))},
					true
				)
				return false
			var context_validation := EQReactionFireContext.validate(fire_context)
			if not context_validation.is_valid():
				runtime._fault(
					EQError.REACTION_FIRE_CONTEXT_INVALID,
					"pending reaction FIRE has an invalid cause context",
					{
						"event_id": int(scheduled.get("event_id", -1)),
						"issues": context_validation.codes().map(func(code): return String(code)),
					},
					true
				)
				return false
			if int((fire_context as Dictionary).get("fire_event_id", -1)) != scheduled_event_id:
				runtime._fault(
					EQError.REACTION_FIRE_CONTEXT_INVALID,
					"reaction FIRE context event id does not match its scheduled row",
					{
						"event_id": scheduled_event_id,
						"context_event_id": int(
							(fire_context as Dictionary).get("fire_event_id", -1)
						),
						"reason": "event_id_mismatch",
					},
					true
				)
				return false
		elif fire_context is Dictionary and not (fire_context as Dictionary).is_empty():
			runtime._fault(
				EQError.REACTION_FIRE_CONTEXT_INVALID,
				"non-reaction reservation must not carry reaction_fire_context",
				{"event_id": int(scheduled.get("event_id", -1)), "reason": "wrong_kind"},
				true
			)
			return false
	if not _verify_reaction_expiry_state(
		data, save_schema_version, scheduler_entries_by_event
	):
		return false
	var reservation_dicts: Array = []
	for a in data.get("armed_triggers", []):
		reservation_dicts.append(a.get("reservation", {}))
	for c in data.get("pending_conditional", []):
		reservation_dicts.append(c.get("reservation", {}))
	for s in data.get("scheduled_reservations", []):
		reservation_dicts.append(s.get("reservation", {}))
	if save_schema_version >= 6:
		for expiry in data.get("reaction_expiries", []):
			reservation_dicts.append(expiry.get("reservation", {}))
	for rd in reservation_dicts:
		var def: Dictionary = rd.get("definition", {})
		for binding in [
			{
				"slot": "main",
				"definition_key": "effect_name",
				"reservation_key": "effect_commit_result_version",
			},
			{
				"slot": "expiry",
				"definition_key": "expiry_effect_name",
				"reservation_key": "expiry_effect_commit_result_version",
			},
		]:
			var name := StringName(def.get(binding["definition_key"], ""))
			if require_effect_result_bindings and not rd.has(binding["reservation_key"]):
				runtime._fault(
					EQError.EFFECT_COMMIT_RESULT_VERSION_UNSUPPORTED,
					"schema 4+ reservation is missing a required effect commit result binding",
					{
						"slot": binding["slot"],
						"effect": String(name),
						"schema_version": save_schema_version,
						"reason": "missing_binding",
					},
					true
				)
				return false
			var raw_bound = rd.get(binding["reservation_key"], 0)
			if typeof(raw_bound) != TYPE_INT or int(raw_bound) < 0 or int(raw_bound) > 1:
				runtime._fault(
					EQError.EFFECT_COMMIT_RESULT_VERSION_UNSUPPORTED,
					"saved effect commit result binding version is unsupported",
					{
						"slot": binding["slot"],
						"effect": String(name),
						"bound_version": raw_bound,
					},
					true
				)
				return false
			if save_schema_version < 4 and int(raw_bound) != 0:
				runtime._fault(
					EQError.EFFECT_COMMIT_RESULT_VERSION_UNSUPPORTED,
					"historical save schema cannot represent typed effect result bindings",
					{
						"slot": binding["slot"],
						"effect": String(name),
						"bound_version": raw_bound,
						"schema_version": save_schema_version,
						"reason": "binding_not_supported_by_schema",
					},
					true
				)
				return false
			if name != &"" and not runtime.has_effect(name):
				runtime._fault(EQError.EFFECT_UNREGISTERED, "effect '%s' in the save is not registered" % name, {"effect": String(name)}, true)
				return false
			var bound := int(raw_bound)
			var current := runtime.effect_commit_result_version(name)
			if bound != current:
				runtime._fault(
					EQError.EFFECT_COMMIT_RESULT_BINDING_MISMATCH,
					"saved effect commit result binding does not match the registry",
					{
						"slot": binding["slot"],
						"effect": String(name),
						"bound_version": bound,
						"registered_version": current,
						"context": "load",
					},
					true
				)
				return false
	return true


func _verify_reaction_expiry_state(
	data: Dictionary, save_schema_version: int, scheduler_entries_by_event: Dictionary
) -> bool:
	var armed_value = data.get("armed_triggers", [])
	if typeof(armed_value) != TYPE_ARRAY:
		return _reaction_expiry_state_fault(
			"armed_triggers must be an Array", {"reason": "armed_table_type"}
		)
	var armed_by_expiry := {}
	for armed_value_entry in armed_value as Array:
		if typeof(armed_value_entry) != TYPE_DICTIONARY:
			return _reaction_expiry_state_fault(
				"armed trigger row must be a Dictionary", {"reason": "armed_row_type"}
			)
		var armed := armed_value_entry as Dictionary
		var reservation_value = armed.get("reservation", {})
		if typeof(reservation_value) != TYPE_DICTIONARY:
			return _reaction_expiry_state_fault(
				"armed trigger reservation must be a Dictionary",
				{"reason": "armed_reservation_type"}
			)
		var reservation := reservation_value as Dictionary
		var definition_value = reservation.get("definition", {})
		if typeof(definition_value) != TYPE_DICTIONARY:
			return _reaction_expiry_state_fault(
				"armed trigger definition must be a Dictionary",
				{"reason": "armed_definition_type"}
			)
		var definition := definition_value as Dictionary
		var duration := int(definition.get("duration", 0))
		var expiry_event_id := int(armed.get("expiry_event_id", -1))
		if duration > 0:
			if expiry_event_id < 1 or armed_by_expiry.has(expiry_event_id):
				return _reaction_expiry_state_fault(
					"duration-limited armed trigger has an invalid expiry identity",
					{"event_id": expiry_event_id, "reason": "armed_expiry_identity"}
				)
			if not scheduler_entries_by_event.has(expiry_event_id):
				return _reaction_expiry_state_fault(
					"armed trigger expiry is absent from the scheduler",
					{"event_id": expiry_event_id, "reason": "armed_expiry_orphan"}
				)
			var scheduler_entry := scheduler_entries_by_event[expiry_event_id] as Dictionary
			var armed_at := int(armed.get("armed_at", -1))
			if (
				StringName(scheduler_entry.get("kind", &"")) != &"expiry"
				or String(scheduler_entry.get("actor_id", ""))
				!= String(reservation.get("actor_id", ""))
				or typeof(scheduler_entry.get("payload", {})) != TYPE_DICTIONARY
				or not (scheduler_entry.get("payload", {}) as Dictionary).is_empty()
				or armed_at < 0
				or int(scheduler_entry.get("due_tick", -1)) != armed_at + duration
				or int(reservation.get("status", -1)) != EQReservation.Status.ARMED
			):
				return _reaction_expiry_state_fault(
					"armed trigger expiry does not match its scheduler entry",
					{"event_id": expiry_event_id, "reason": "armed_expiry_mismatch"}
				)
			armed_by_expiry[expiry_event_id] = armed
		elif expiry_event_id > 0:
			return _reaction_expiry_state_fault(
				"unlimited reaction must not reference an expiry event",
				{"event_id": expiry_event_id, "reason": "unexpected_expiry"}
			)

	var scheduler_expiry_ids: Array[int] = []
	for event_id_value in scheduler_entries_by_event:
		var event_id := int(event_id_value)
		var scheduler_entry := scheduler_entries_by_event[event_id] as Dictionary
		if StringName(scheduler_entry.get("kind", &"")) == &"expiry":
			scheduler_expiry_ids.append(event_id)
	scheduler_expiry_ids.sort()

	if save_schema_version < 6:
		if data.has("reaction_expiries"):
			var historical_table = data["reaction_expiries"]
			if (
				typeof(historical_table) != TYPE_ARRAY
				or not (historical_table as Array).is_empty()
			):
				return _reaction_expiry_state_fault(
					"historical schema cannot carry reaction_expiries",
					{
						"schema_version": save_schema_version,
						"reason": "table_not_supported_by_schema",
					}
				)
		var historical_expiry_ids: Array[int] = []
		for event_id_value in armed_by_expiry:
			historical_expiry_ids.append(int(event_id_value))
		historical_expiry_ids.sort()
		if historical_expiry_ids != scheduler_expiry_ids:
			return _reaction_expiry_state_fault(
				"historical save has an expiry event without reconstructable state",
				{
					"schema_version": save_schema_version,
					"scheduler_event_ids": scheduler_expiry_ids,
					"armed_event_ids": historical_expiry_ids,
					"reason": "historical_orphan_expiry",
				}
			)
		return true

	if not data.has("reaction_expiries") or typeof(data["reaction_expiries"]) != TYPE_ARRAY:
		return _reaction_expiry_state_fault(
			"schema 6 requires the reaction_expiries Array",
			{"schema_version": save_schema_version, "reason": "missing_table"}
		)
	var expiry_rows_by_event := {}
	for row_value in data["reaction_expiries"] as Array:
		if typeof(row_value) != TYPE_DICTIONARY:
			return _reaction_expiry_state_fault(
				"reaction expiry row must be a Dictionary", {"reason": "row_type"}
			)
		var row := row_value as Dictionary
		if row.size() != 2 or not row.has("event_id") or not row.has("reservation"):
			return _reaction_expiry_state_fault(
				"reaction expiry row has an invalid shape", {"reason": "row_shape"}
			)
		if typeof(row["event_id"]) != TYPE_INT or int(row["event_id"]) < 1:
			return _reaction_expiry_state_fault(
				"reaction expiry event_id must be a positive int",
				{"reason": "event_id_type"}
			)
		var event_id := int(row["event_id"])
		if expiry_rows_by_event.has(event_id) or not scheduler_entries_by_event.has(event_id):
			return _reaction_expiry_state_fault(
				"reaction expiry identity is duplicate or orphaned",
				{"event_id": event_id, "reason": "event_identity"}
			)
		if typeof(row["reservation"]) != TYPE_DICTIONARY:
			return _reaction_expiry_state_fault(
				"reaction expiry reservation must be a Dictionary",
				{"event_id": event_id, "reason": "reservation_type"}
			)
		var reservation := row["reservation"] as Dictionary
		var definition_value = reservation.get("definition", {})
		var scheduler_entry := scheduler_entries_by_event[event_id] as Dictionary
		if (
			typeof(definition_value) != TYPE_DICTIONARY
			or int((definition_value as Dictionary).get("kind", -1))
			!= EQActionDefinition.Kind.REACTION_PREPARATION
			or int((definition_value as Dictionary).get("duration", 0)) <= 0
			or StringName(scheduler_entry.get("kind", &"")) != &"expiry"
			or String(scheduler_entry.get("actor_id", ""))
			!= String(reservation.get("actor_id", ""))
			or typeof(scheduler_entry.get("payload", {})) != TYPE_DICTIONARY
			or not (scheduler_entry.get("payload", {}) as Dictionary).is_empty()
		):
			return _reaction_expiry_state_fault(
				"reaction expiry row does not match its scheduler event",
				{"event_id": event_id, "reason": "scheduler_mismatch"}
			)
		var expected_status := (
			EQReservation.Status.ARMED
			if armed_by_expiry.has(event_id)
			else EQReservation.Status.RESOLVED
		)
		if int(reservation.get("status", -1)) != expected_status:
			return _reaction_expiry_state_fault(
				"reaction expiry reservation status disagrees with armed membership",
				{
					"event_id": event_id,
					"expected_status": expected_status,
					"reason": "status_mismatch",
				}
			)
		if (
			armed_by_expiry.has(event_id)
			and reservation != (armed_by_expiry[event_id] as Dictionary)["reservation"]
		):
			return _reaction_expiry_state_fault(
				"armed and expiry tables disagree about the reservation revision",
				{"event_id": event_id, "reason": "reservation_mismatch"}
			)
		if (
			not armed_by_expiry.has(event_id)
			and int(reservation.get("remaining_ruminations", -1)) != 0
		):
			return _reaction_expiry_state_fault(
				"count-closed expiry must have no remaining reaction fires",
				{"event_id": event_id, "reason": "remaining_count_mismatch"}
			)
		expiry_rows_by_event[event_id] = row
	var expiry_row_ids: Array[int] = []
	for event_id_value in expiry_rows_by_event:
		expiry_row_ids.append(int(event_id_value))
	expiry_row_ids.sort()
	if expiry_row_ids != scheduler_expiry_ids:
		return _reaction_expiry_state_fault(
			"reaction expiry table must be a bijection with scheduler expiry events",
			{
				"scheduler_event_ids": scheduler_expiry_ids,
				"reaction_expiry_event_ids": expiry_row_ids,
				"reason": "event_set_mismatch",
			}
		)
	return true


func _reaction_expiry_state_fault(message: String, context: Dictionary) -> bool:
	runtime._fault(EQError.REACTION_EXPIRY_STATE_INVALID, message, context, true)
	return false


## Applies the verified tables (call verify_state first; the adapter does).
func apply_state(data: Dictionary) -> void:
	lines.restore_values(data.get("event_lines", {}))
	if relations != null:
		relations.restore(data.get("relations", {}))
	if state_algebra != null:
		state_algebra.restore(data.get("state_algebra", {}))
	var save_schema_version := int(data.get("schema_version", -1))
	var restored_expiries := {}
	if save_schema_version >= 6:
		for expiry_value in data.get("reaction_expiries", []):
			var expiry := expiry_value as Dictionary
			var expiry_event_id := int(expiry["event_id"])
			var expiry_reservation := EQReservation.from_dict(expiry["reservation"])
			restored_expiries[expiry_event_id] = expiry_reservation
			_expiry_by_event[expiry_event_id] = expiry_reservation
	for a in data.get("armed_triggers", []):
		var expiry_id := int(a.get("expiry_event_id", -1))
		var res: EQReservation = (
			restored_expiries[expiry_id]
			if expiry_id > 0 and restored_expiries.has(expiry_id)
			else EQReservation.from_dict(a.get("reservation", {}))
		)
		var cond = null
		var cd: Dictionary = a.get("condition", {})
		if not cd.is_empty():
			cond = EQCondition.from_dict(cd)
		res.status = EQReservation.Status.ARMED
		engine.arm(res, cond, int(a.get("armed_at", 0)))
		if expiry_id > 0 and save_schema_version < 6:
			_expiry_by_event[expiry_id] = res
	for c in data.get("pending_conditional", []):
		_pending_conditional.append({
			"res": EQReservation.from_dict(c.get("reservation", {})),
			"solve": c.get("solve", []),
			"inv": c.get("inv", []),
			"view": c.get("view", {}),
		})
	for s in data.get("scheduled_reservations", []):
		var res := EQReservation.from_dict(s.get("reservation", {}))
		var event_id := int(s.get("event_id", -1))
		_by_event[event_id] = res
		var inv: Array = s.get("inv", [])
		if not inv.is_empty():
			_bound_inv[event_id] = inv
		var fire_context = s.get("reaction_fire_context", {})
		if fire_context is Dictionary and not (fire_context as Dictionary).is_empty():
			_reaction_fire_context_by_event[event_id] = EQReactionFireContext.copy(
				fire_context
			)


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
	if not runtime.registry.is_registered(res.actor_id):
		runtime._fault(
			EQError.RUNTIME_SCHEDULE_UNREGISTERED_ACTOR,
			"submit for unregistered actor",
			{"actor_id": String(res.actor_id)},
			true
		)
		return -1
	if kind == EQActionDefinition.Kind.OPERATION:
		if res.target_id == &"":
			runtime._fault(
				EQError.RESERVATION_OPERATION_NEEDS_TARGET,
				"OPERATION submit requires a non-empty target_id",
				{"actor_id": String(res.actor_id), "target_id": ""},
				true
			)
			return -1
		if not runtime.registry.is_registered(res.target_id):
			runtime._fault(
				EQError.RUNTIME_SCHEDULE_UNREGISTERED_ACTOR,
				"OPERATION target is not registered at submit",
				{
					"actor_id": String(res.target_id),
					"source_actor_id": String(res.actor_id),
					"role": "operation_target",
				},
				true
			)
			return -1
	if kind == EQActionDefinition.Kind.REACTION_PREPARATION:
		var declared_expiry_effect := res.definition.expiry_effect_name
		if (
			declared_expiry_effect != &""
			and runtime.effect_commit_result_version(declared_expiry_effect) > 0
		):
			runtime._fault(
				EQError.EFFECT_COMMIT_RESULT_CONTEXT_UNSUPPORTED,
				"transactional effect handlers are unsupported for expiry effects",
				{"effect": String(declared_expiry_effect), "context": "expiry"},
				true
			)
			return -1
	if not _bind_effect_commit_versions(res, &"submit"):
		return -1
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
				# Issuance is itself an evaluation point (level semantics, SEM
				# §5.4): a set already holding at submit acts NOW — it never
				# waits for a later sweep to notice an already-true level.
				var ctx := _ctx(_view_of(res))
				var solve := EQConditionEval.solve_holds(bound["solve"], ctx)
				var inv := EQConditionEval.invalidation_check(bound["inv"], ctx)
				match EQConditionEval.decide(solve, inv):
					EQConditionEval.Outcome.INVALIDATE:
						res.status = EQReservation.Status.INVALIDATED
						_trace_invalidated(-1, res.actor_id, StringName(inv["closed_by"]))
						return -1
					EQConditionEval.Outcome.RESOLVE:
						var ready_id := _schedule(res, 0)
						if ready_id > 0 and not (bound["inv"] as Array).is_empty():
							_bound_inv[ready_id] = bound["inv"]
						return ready_id
					EQConditionEval.Outcome.FAULT:
						var f: Dictionary = (inv["fault"] if inv["fault"] != null else solve["fault"])
						runtime._fault(f["code"], f["message"], f.get("context", {}), true)
						return -1
					_:
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


## Submits multiple reservations as one deterministic atomic bundle. All bundled
## members are scheduled for the same due_tick (current_tick + delay) and a
## deterministic bundle id is returned.
func submit_bundle(reservations: Array, delay: int = 0) -> StringName:
	if reservations == null or reservations.is_empty():
		runtime._fault(EQError.CONDITION_LINE_UNKNOWN, "submit_bundle requires a non-empty reservation array", {}, true)
		return &""
	if delay < 0:
		runtime._fault(EQError.CONDITION_LINE_UNKNOWN, "submit_bundle delay must be >= 0", {"delay": delay}, true)
		return &""
	var planned: Array = []
	for item in reservations:
		if item == null or not (item is EQReservation):
			runtime._fault(EQError.CONDITION_LINE_UNKNOWN, "submit_bundle accepts only EQReservation entries", {}, true)
			_rollback_bundle_plan(planned)
			return &""
		var res: EQReservation = item
		var v := res.validate()
		if not v.is_valid():
			var issue = v.errors()[0] if not v.errors().is_empty() else v.issues[0]
			runtime._fault(issue["code"], issue["message"], {"actor_id": String(res.actor_id)}, true)
			_rollback_bundle_plan(planned)
			return &""
		for effect_name in [res.definition.effect_name, res.definition.expiry_effect_name]:
			if effect_name != &"" and runtime.effect_commit_result_version(effect_name) > 0:
				runtime._fault(
					EQError.EFFECT_COMMIT_RESULT_CONTEXT_UNSUPPORTED,
					"transactional effect handlers are unsupported in atomic bundles",
					{"effect": String(effect_name), "context": "bundle"},
					true
				)
				_rollback_bundle_plan(planned)
				return &""
		if not runtime.registry.is_registered(res.actor_id):
			runtime._fault(EQError.RUNTIME_SCHEDULE_UNREGISTERED_ACTOR, "submit_bundle actor is not registered", {"actor_id": String(res.actor_id)}, true)
			_rollback_bundle_plan(planned)
			return &""
		var kind := res.definition.kind
		if (
			kind == EQActionDefinition.Kind.WAIT
			or kind == EQActionDefinition.Kind.READY
			or kind == EQActionDefinition.Kind.OPERATION
			or kind == EQActionDefinition.Kind.REACTION_PREPARATION
		):
			runtime._fault(
				EQError.CONDITION_LINE_UNKNOWN,
				"submit_bundle rejects WAIT/READY/OPERATION/REACTION_PREPARATION members",
				{"actor_id": String(res.actor_id), "kind": str(kind)},
				true
			)
			_rollback_bundle_plan(planned)
			return &""
		var bound := _bind_conditions(res)
		if not (bound["solve"] as Array).is_empty():
			var ctx := _ctx(_view_of(res))
			var solve := EQConditionEval.solve_holds(bound["solve"], ctx)
			var inv := EQConditionEval.invalidation_check(bound["inv"], ctx)
			match EQConditionEval.decide(solve, inv):
				EQConditionEval.Outcome.RESOLVE:
					pass
				EQConditionEval.Outcome.INVALIDATE:
					runtime._fault(EQError.CONDITION_LINE_UNKNOWN, "bundle member is currently invalid and cannot be bundled", {"actor_id": String(res.actor_id), "closed_by": String(inv["closed_by"])}, true)
					_rollback_bundle_plan(planned)
					return &""
				EQConditionEval.Outcome.FAULT:
					var f: Dictionary = (inv["fault"] if inv["fault"] != null else solve["fault"])
					runtime._fault(f["code"], f["message"], f.get("context", {}), true)
					_rollback_bundle_plan(planned)
					return &""
				_:
					runtime._fault(EQError.CONDITION_LINE_UNKNOWN, "bundle member is pending and cannot be bundled", {"actor_id": String(res.actor_id)}, true)
					_rollback_bundle_plan(planned)
					return &""
		var original_main_version := res.effect_commit_result_version
		var original_expiry_version := res.expiry_effect_commit_result_version
		if not _bind_effect_commit_versions(res, &"bundle_submit"):
			_rollback_bundle_plan(planned)
			return &""
		var id := _schedule(res, delay)
		if id <= 0:
			res.effect_commit_result_version = original_main_version
			res.expiry_effect_commit_result_version = original_expiry_version
			runtime._fault(EQError.CONDITION_LINE_UNKNOWN, "submit_bundle failed to schedule a member", {"actor_id": String(res.actor_id)}, true)
			_rollback_bundle_plan(planned)
			return &""
		if not (bound["inv"] as Array).is_empty():
			_bound_inv[id] = bound["inv"]
		plan_append_bundle_member(planned, id, res)
		planned.back()["original_main_version"] = original_main_version
		planned.back()["original_expiry_version"] = original_expiry_version
	var bundle_id := StringName("eqm.bundle.%d" % (_bundle_seq + 1))
	_bundle_seq += 1
	var members: Array = []
	for p in planned:
		members.append(int(p.get("event_id", -1)))
		_bundle_of[p.get("event_id", -1)] = bundle_id
	_bundle_members[bundle_id] = members
	return bundle_id


func plan_append_bundle_member(planned: Array, event_id: int, _res: EQReservation) -> void:
	planned.append({"event_id": event_id, "reservation": _res})


func _rollback_bundle_plan(planned: Array) -> void:
	for p in planned:
		var event_id := int(p.get("event_id", -1))
		var res: EQReservation = p.get("reservation", null)
		if res != null:
			res.effect_commit_result_version = int(
				p.get("original_main_version", res.effect_commit_result_version)
			)
			res.expiry_effect_commit_result_version = int(
				p.get("original_expiry_version", res.expiry_effect_commit_result_version)
			)
		if event_id > 0 and runtime.scheduler.cancel(event_id):
			_by_event.erase(event_id)
			_reaction_fire_context_by_event.erase(event_id)
			_window_of_event.erase(event_id)
			_bound_inv.erase(event_id)
			_clear_bundle_event_link(event_id)


## OR-resolution race (SEM §5.2, Q18/Q28): several reservations for the SAME
## effect, each with different solve_conditions, usually racing on shared
## lines. Each member goes through the normal pipeline; the first to resolve
## wins and the rest are swept with `closed_by: race_lost` (their OR
## invalidation). Simultaneous arrivals are ordered by the §7.1 hook →
## issuance order — no race-specific rule. Returns the deterministic
## race-group id (`eqm.race.<seq>`). All candidates stay visible in the trace
## (`race_opened` / `race_resolved` / race-tagged invalidations) — the
## EQM-debug display; the overlay aggregates them (game-dev debug); in-game
## presentation only ever receives the winner's effect.
func submit_race(members: Array) -> StringName:
	_race_seq += 1
	var gid := StringName("eqm.race.%d" % _race_seq)
	var group: Array = []
	for m in members:
		var res: EQReservation = m
		group.append(res)
		_race_of[res.get_instance_id()] = gid
		submit(res)
	_race_groups[gid] = group
	runtime.trace().record({"kind": "race_opened", "race_group": String(gid), "members": group.size()})
	return gid


## The winner resolved: sweep the losers (only those not already closed by
## another path) and record the settlement.
func _settle_race(gid: StringName, winner: EQReservation, winner_event_id: int) -> void:
	for member in _race_groups.get(gid, []):
		var res: EQReservation = member
		if res == winner or res.status == EQReservation.Status.RESOLVED or res.status == EQReservation.Status.INVALIDATED:
			continue
		# pending conditional loser
		var still: Array[Dictionary] = []
		for p in _pending_conditional:
			if p["res"] == res:
				continue
			still.append(p)
		_pending_conditional = still
		# scheduled loser
		if res.event_id > 0 and _by_event.has(res.event_id):
			runtime.scheduler.cancel(res.event_id)
			_clear_bundle_event_link(res.event_id)
			_by_event.erase(res.event_id)
			_reaction_fire_context_by_event.erase(res.event_id)
			_window_of_event.erase(res.event_id)
			_bound_inv.erase(res.event_id)
		res.status = EQReservation.Status.INVALIDATED
		_trace_invalidated(res.event_id, res.actor_id, &"race_lost", gid)
	_race_groups.erase(gid)
	runtime.trace().record({"kind": "race_resolved", "race_group": String(gid), "winner": String(winner.actor_id), "event_id": winner_event_id})


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
		if window_depth() > 0:
			var current := current_window()
			if current != null and not current.closed:
				_window_of_event[id] = current.window_id
	return id


## Applies target expansion declarations for matching effect tags before effect transforms.
func _apply_target_expansion(res: EQReservation, view: Dictionary) -> Dictionary:
	if relations == null or view == null:
		return view
	var tags := res.definition.tags if res.definition != null else []
	if tags.is_empty():
		return view
	var matching := _matching_expansion_rules(tags)
	if matching.is_empty():
		return view
	var has_expanded := false
	var base_target := StringName(view.get("target", ""))
	if base_target == &"":
		return view
	# Multiple matching rules (multi-tag actions) UNION their expansions:
	# origin first, then per-rule BFS order in the deterministic rule order.
	var final_targets: Array[StringName] = [base_target]
	for rule in matching:
		var expanded := _bfs_expand_targets(base_target, StringName(rule.get("relation_type", "")), int(rule.get("hop_cost", 0)), int(rule.get("budget", 0)))
		if expanded.size() > 1:
			has_expanded = true
			for actor in expanded:
				if not final_targets.has(actor):
					final_targets.append(actor)
			# Recorded ONLY when something actually expanded (§6.4 2a) — a
			# matching rule over an unrelated target stays silent.
			runtime.trace().record({
				"kind": "targets_expanded",
				"actor": String(res.actor_id),
				"origin": String(base_target),
				"expanded": _string_array(expanded),
				"rule": String(rule.get("effect_tag", "")),
			})
	if has_expanded:
		view["targets"] = final_targets
	return view


## Applies chained transforms until a fixed point (bounded by max_transform_rounds).
func _apply_effect_transforms(res: EQReservation, view: Dictionary) -> Dictionary:
	var transformed := view.duplicate(true)
	var round := 0
	while true:
		round += 1
		if round > max_transform_rounds:
			runtime._fault(EQError.CONDITION_LINE_UNKNOWN, "transform rounds exceeded max_transform_rounds (%d)" % max_transform_rounds, {"actor": String(res.actor_id), "round": round}, false)
			break
		var matching := _matching_transforms(res)
		if matching.is_empty():
			break
		var changed := false
		for transform in matching:
			var before := transformed.duplicate(true)
			match String(transform.get("kind", "")):
				"retarget":
					var next_target := _apply_retarg_transform(res, transformed, transform)
					if next_target != null:
						transformed = next_target
						if _view_target(transformed) != before.get("target", &""):
							changed = true
							runtime.trace().record({
								"kind": "effect_transformed",
								"transform": String(transform.get("name", "")),
								"actor": String(res.actor_id),
								"round": round,
								"param": "target",
							})
				"state_inv":
					var next_state := _apply_state_transform(transformed, transform)
					if next_state != null:
						transformed = next_state
						if String(_view_state(transformed)) != String(before.get("state", "")):
							changed = true
							runtime.trace().record({
								"kind": "effect_transformed",
								"transform": String(transform.get("name", "")),
								"actor": String(res.actor_id),
								"round": round,
								"param": "state",
							})
		if not changed:
			break
	return transformed


func _apply_retarg_transform(res: EQReservation, view: Dictionary, transform: Dictionary) -> Variant:
	var params := transform.get("params", {})
	if params is not Dictionary:
		return null
	var stage = params.get("stage", "direct")
	var actor := _pick_stage_actor(res, transform, stage)
	if actor == &"":
		return null
	if view.has("targets") and view["targets"] is Array and (view["targets"] as Array).size() > 0:
		var expanded := view["targets"] as Array
		if expanded.size() > 0:
			expanded[0] = actor
		view["targets"] = expanded
	view["target"] = actor
	return view


func _apply_state_transform(view: Dictionary, transform: Dictionary) -> Variant:
	if not view.has("state"):
		return null
	var params := transform.get("params", {})
	if params is not Dictionary:
		return null
	var pair: Array = params.get("pair", [])
	if pair is not Array or pair.size() != 2:
		return null
	var state := _normalize_state_token(view.get("state", ""))
	var a := _normalize_state_token(pair[0])
	var b := _normalize_state_token(pair[1])
	if state == a:
		view["state"] = StringName(b)
		return view
	if state == b:
		view["state"] = StringName(a)
		return view
	return null


func _normalize_state_token(value) -> String:
	if typeof(value) == TYPE_STRING_NAME or typeof(value) == TYPE_STRING:
		return String(value)
	return ""


func _pick_stage_actor(res: EQReservation, transform: Dictionary, stage) -> StringName:
	var params := transform.get("params", {})
	if params is not Dictionary:
		return &""
	var meta_level := int(transform.get("meta_level", 0))
	var provenance := res.provenance if res != null else []
	if provenance.is_empty():
		if typeof(stage) == TYPE_INT:
			return &""
		if stage == "direct" or stage == "root":
			return res.actor_id
		return &""
	var chain := provenance as Array
	var stage_actor := &""
	if typeof(stage) == TYPE_INT:
		var stage_idx := int(stage)
		if stage_idx < 0 or stage_idx >= chain.size():
			return &""
		var entry: Dictionary = chain[stage_idx]
		var entry_meta: int = int(entry.get("meta_level", 0))
		if meta_level >= entry_meta:
			stage_actor = StringName(entry.get("actor", ""))
		return stage_actor
	if stage == "direct":
		var entry: Dictionary = chain.back()
		var entry_meta: int = int(entry.get("meta_level", 0))
		if meta_level >= entry_meta:
			stage_actor = StringName(entry.get("actor", ""))
	elif stage == "root":
		for i in range(chain.size()):
			var entry: Dictionary = chain[i]
			var entry_meta: int = int(entry.get("meta_level", 0))
			if meta_level >= entry_meta:
				stage_actor = StringName(entry.get("actor", ""))
				break
	return stage_actor


func _bfs_expand_targets(origin: StringName, relation_type: StringName, hop_cost: int, budget: int) -> Array:
	if relations == null:
		return [origin]
	return relations.expand(origin, relation_type, hop_cost, budget)


func _view_target(view: Dictionary) -> StringName:
	if view.has("targets") and view["targets"] is Array:
		var targets: Array = view.get("targets", [])
		return StringName(targets[0]) if not targets.is_empty() else StringName(view.get("target", ""))
	return StringName(view.get("target", ""))


func _view_state(view: Dictionary) -> StringName:
	return StringName(view.get("state", ""))


func _string_array(values: Array) -> Array:
	var out: Array = []
	for v in values:
		if typeof(v) == TYPE_STRING_NAME:
			out.append(String(v))
		else:
			out.append(String(v))
	return out


func _is_serializable(value) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME, TYPE_ARRAY, TYPE_DICTIONARY:
			pass
		TYPE_OBJECT:
			return false
		_:
			return false
	if typeof(value) == TYPE_ARRAY:
		for v in (value as Array):
			if not _is_serializable(v):
				return false
	if typeof(value) == TYPE_DICTIONARY:
		for k in (value as Dictionary).keys():
			if typeof(k) != TYPE_STRING and typeof(k) != TYPE_STRING_NAME:
				return false
			if not _is_serializable((value as Dictionary)[k]):
				return false
	return true


func _effect_commit_binding_entries(res: EQReservation) -> Array:
	return [
		{
			"slot": &"main",
			"effect": res.definition.effect_name,
			"bound": res.effect_commit_result_version,
		},
		{
			"slot": &"expiry",
			"effect": res.definition.expiry_effect_name,
			"bound": res.expiry_effect_commit_result_version,
		},
	]


## First submission freezes the registry mode onto the reservation instance.
## Resubmitting the same instance (rumination) verifies rather than rebinds it.
func _bind_effect_commit_versions(res: EQReservation, context: StringName) -> bool:
	var updates := {}
	for entry in _effect_commit_binding_entries(res):
		var slot := StringName(entry["slot"])
		var effect := StringName(entry["effect"])
		var bound := int(entry["bound"])
		var current := runtime.effect_commit_result_version(effect)
		if bound == -1:
			updates[slot] = current
			continue
		if bound != current:
			_fault_effect_commit_binding_mismatch(res, slot, effect, bound, current, context)
			return false
	if updates.has(&"main"):
		res.effect_commit_result_version = int(updates[&"main"])
	if updates.has(&"expiry"):
		res.expiry_effect_commit_result_version = int(updates[&"expiry"])
	return true


## Resolution/load-restored instances must already be bound. This detects a
## legacy <-> typed registry replacement after issuance and before invocation.
func _verify_effect_commit_versions(res: EQReservation, context: StringName) -> bool:
	for entry in _effect_commit_binding_entries(res):
		var slot := StringName(entry["slot"])
		var effect := StringName(entry["effect"])
		var bound := int(entry["bound"])
		var current := runtime.effect_commit_result_version(effect)
		if bound < 0 or bound != current:
			_fault_effect_commit_binding_mismatch(res, slot, effect, bound, current, context)
			return false
	return true


func _fault_effect_commit_binding_mismatch(
	res: EQReservation,
	slot: StringName,
	effect: StringName,
	bound: int,
	current: int,
	context: StringName
) -> void:
	runtime._fault(
		EQError.EFFECT_COMMIT_RESULT_BINDING_MISMATCH,
		"effect commit result registry mode changed after reservation submission",
		{
			"actor": String(res.actor_id),
			"slot": String(slot),
			"effect": String(effect),
			"bound_version": bound,
			"registered_version": current,
			"context": String(context),
		},
		true
	)


func _reject_effect_commit_binding(
	res: EQReservation, event_id: int, context: StringName
) -> void:
	res.status = EQReservation.Status.INVALIDATED
	_trace_invalidated(event_id, res.actor_id, &"effect_commit_binding")
	_last_effect_commit_outcome = EQEffectCommitResult.make_failure(
		{
			"code": String(EQError.EFFECT_COMMIT_RESULT_BINDING_MISMATCH),
			"actor": String(res.actor_id),
			"context": String(context),
		}
	).to_dict()


## Resolves the next ready reservation through the §6.1 pipeline. Returns the
## resolved reservation; null when the queue is empty or the next event is not
## a tracked reservation (the L0 path). Expiry events are consumed internally.
func resolve_next() -> EQReservation:
	last_drained = []
	_last_effect_commit_outcome = {}
	while true:
		var result := _resolve_one_scheduled_event()
		match int(result["outcome"]):
			ScheduledEventOutcome.EXPIRY, ScheduledEventOutcome.INVALIDATED, ScheduledEventOutcome.FAULT:
				continue
			ScheduledEventOutcome.RESERVATION:
				return result["reservation"] as EQReservation
			_:
				return null
	return null


## Processes at most one scheduler pop through the complete reservation
## pipeline. Unlike resolve_next(), an expiry is returned as its own boundary
## and can therefore be checkpointed/interleaved without reaching into private
## expiry bookkeeping. The exact result fields are:
## `{advanced, event_id, event_kind, outcome, reservation}`.
func resolve_one_scheduled_event() -> Dictionary:
	last_drained = []
	_last_effect_commit_outcome = {}
	return _resolve_one_scheduled_event()


func _resolve_one_scheduled_event() -> Dictionary:
	var e := runtime.advance()
	if e == null:
		return _scheduled_event_result(false, -1, &"", ScheduledEventOutcome.EMPTY, null)
	lines.sync_primary(runtime.scheduler.current_tick)
	_check_deadlines()
	if _expiry_by_event.has(e.event_id):
		var expiry_res := _expiry_by_event[e.event_id] as EQReservation
		_resolve_expiry(e)
		return _scheduled_event_result(
			true, e.event_id, e.kind, ScheduledEventOutcome.EXPIRY, expiry_res
		)
	var res = _by_event.get(e.event_id, null)
	if res == null:
		return _scheduled_event_result(
			true, e.event_id, e.kind, ScheduledEventOutcome.UNTRACKED, null
		)
	var bundle_id := _bundle_of.get(e.event_id, &"")
	var inv_terms_bundle := _bound_inv.get(e.event_id, [])
	var raw_view := _view_of(res)
	var fire_context := reaction_fire_context_for_event(e.event_id)
	var invalidation_view := raw_view.duplicate(true)
	if not fire_context.is_empty():
		invalidation_view["reaction_fire_context"] = fire_context.duplicate(true)
	_by_event.erase(e.event_id)
	_bound_inv.erase(e.event_id)
	_window_of_event.erase(e.event_id)
	_reaction_fire_context_by_event.erase(e.event_id)
	if bundle_id != &"":
		var bundle_res := _resolve_bundle(e.event_id, res, inv_terms_bundle, bundle_id)
		return _scheduled_event_result(
			true, e.event_id, e.kind, ScheduledEventOutcome.RESERVATION, bundle_res
		)
	_clear_bundle_event_link(e.event_id)
	# step 1b — lazy invalidation at reference time (level semantics)
	if not inv_terms_bundle.is_empty():
		var inv := EQConditionEval.invalidation_check(
			inv_terms_bundle, _ctx(invalidation_view)
		)
		if int(inv["result"]) == EQConditionEval.Result.YES:
			res.status = EQReservation.Status.INVALIDATED
			_trace_invalidated(e.event_id, res.actor_id, StringName(inv["closed_by"]))
			return _scheduled_event_result(
				true, e.event_id, e.kind, ScheduledEventOutcome.INVALIDATED, res
			)
		if int(inv["result"]) == EQConditionEval.Result.FAULT:
			var f: Dictionary = inv["fault"]
			runtime._fault(f["code"], f["message"], f.get("context", {}), true)
			return _scheduled_event_result(
				true, e.event_id, e.kind, ScheduledEventOutcome.FAULT, res
			)
	if not _verify_effect_commit_versions(res, &"single_resolution"):
		_reject_effect_commit_binding(res, e.event_id, &"single_resolution")
		return _scheduled_event_result(
			true, e.event_id, e.kind, ScheduledEventOutcome.RESERVATION, res
		)
	res.status = EQReservation.Status.RESOLVED
	if not fire_context.is_empty():
		runtime.trace().record(
			{
				"kind": "reaction_fire_resolved",
				"actor": String(res.actor_id),
				"event_id": e.event_id,
				"reaction_fire_context": fire_context.duplicate(true),
			}
		)
	var race_gid: StringName = _race_of.get(res.get_instance_id(), &"")
	if race_gid != &"" and _race_groups.has(race_gid):
		_settle_race(race_gid, res, e.event_id)
	# step 2/3 — declared effect into the chunk
	var transformed_view := _apply_effect_transforms(
		res, _apply_target_expansion(res, raw_view.duplicate(true))
	)
	if not fire_context.is_empty():
		# Cause is occurrence metadata, not an effect operand: inject after
		# expansion/transforms so a retarget cannot rewrite trigger truth.
		transformed_view["reaction_fire_context"] = fire_context.duplicate(true)
	var commit_result := _apply_single_effect_commit(
		res.definition.effect_name, transformed_view, raw_view
	)
	_last_effect_commit_outcome = commit_result.to_dict()
	if commit_result.is_failure():
		# FAILURE is an ordinary consumer-owned transaction outcome. It adds
		# no chunk records and deliberately has no reaction sweep fallback.
		return _scheduled_event_result(
			true, e.event_id, e.kind, ScheduledEventOutcome.RESERVATION, res
		)
	for r in commit_result.records():
		chunk.add(r)
	if res.definition.kind == EQActionDefinition.Kind.OPERATION:
		_cause_target_reservation(res)
	# rumination reschedule (count-bounded; reactions re-arm in the ENGINE
	# at fire time instead — re-submitting here would double-arm them)
	if (
		res.definition.kind != EQActionDefinition.Kind.REACTION_PREPARATION
		and res.remaining_ruminations > 0
	):
		_resubmit_rumination(res)
	# step 4 — exactly one outer batch boundary over the declared order.
	_sweep_bundle(_event_view_occurrences(commit_result.event_views(), e.event_id))
	# step 5 — drain; chunk-empty = save boundary
	last_drained.append_array(chunk.drain())
	return _scheduled_event_result(
		true, e.event_id, e.kind, ScheduledEventOutcome.RESERVATION, res
	)


func _scheduled_event_result(
	advanced: bool,
	event_id: int,
	event_kind: StringName,
	outcome: ScheduledEventOutcome,
	reservation: EQReservation
) -> Dictionary:
	return {
		"advanced": advanced,
		"event_id": event_id,
		"event_kind": event_kind,
		"outcome": int(outcome),
		"reservation": reservation,
	}


func _resolve_bundle(event_id: int, first: EQReservation, first_inv_terms: Array, bundle_id: StringName) -> EQReservation:
	var member_ids := (_bundle_members.get(bundle_id, []) as Array).duplicate(true)
	if member_ids.is_empty():
		_clear_bundle_group(bundle_id)
		return first
	var candidates: Array = []
	var resolved_occurrences: Array = []
	for id_val in member_ids:
		var rid := int(id_val)
		var res: EQReservation
		var inv_terms: Array = []
		if rid == event_id:
			res = first
			inv_terms = first_inv_terms.duplicate(true)
		elif _by_event.has(rid):
			res = _by_event[rid]
			inv_terms = (_bound_inv.get(rid, []) as Array).duplicate(true)
			_by_event.erase(rid)
			_reaction_fire_context_by_event.erase(rid)
			_window_of_event.erase(rid)
			_bound_inv.erase(rid)
			_clear_bundle_event_link(rid)
			runtime.scheduler.cancel(rid)
		else:
			continue
		candidates.append({"event_id": rid, "res": res, "inv_terms": inv_terms})
	if candidates.is_empty():
		_clear_bundle_group(bundle_id)
		return first
	# Registration may have changed after submit_bundle(). Preflight every
	# candidate before invoking the first handler: a later typed member cannot
	# be discovered after an earlier legacy member has already published.
	for entry in candidates:
		var candidate: EQReservation = entry["res"]
		if not _verify_effect_commit_versions(candidate, &"bundle_resolution"):
			var binding_diagnostic := {
				"code": String(EQError.EFFECT_COMMIT_RESULT_BINDING_MISMATCH),
				"actor": String(candidate.actor_id),
				"context": "bundle",
			}
			_last_effect_commit_outcome = EQEffectCommitResult.make_failure(
				binding_diagnostic
			).to_dict()
			for rejected in candidates:
				var rejected_res: EQReservation = rejected["res"]
				rejected_res.status = EQReservation.Status.INVALIDATED
				_trace_invalidated(
					int(rejected["event_id"]),
					rejected_res.actor_id,
					&"effect_commit_binding"
				)
			_clear_bundle_group(bundle_id)
			return first
		for effect_name in [
			candidate.definition.effect_name, candidate.definition.expiry_effect_name
		]:
			if effect_name != &"" and runtime.effect_commit_result_version(effect_name) > 0:
				var diagnostic := {
					"code": String(EQError.EFFECT_COMMIT_RESULT_CONTEXT_UNSUPPORTED),
					"effect": String(effect_name),
					"context": "bundle",
				}
				_last_effect_commit_outcome = EQEffectCommitResult.make_failure(
					diagnostic
				).to_dict()
				runtime._fault(
					EQError.EFFECT_COMMIT_RESULT_CONTEXT_UNSUPPORTED,
					"transactional effect handlers are unsupported in atomic bundles",
					diagnostic,
					true
				)
				for rejected in candidates:
					var rejected_res: EQReservation = rejected["res"]
					rejected_res.status = EQReservation.Status.INVALIDATED
					_trace_invalidated(
						int(rejected["event_id"]),
						rejected_res.actor_id,
						&"effect_commit_context"
					)
				_clear_bundle_group(bundle_id)
				return first
	var ordered := _order_candidates(candidates, func(x): return x["res"])
	var ordered_event_ids: Array = []
	for entry in ordered:
		var rid := int(entry.get("event_id", -1))
		ordered_event_ids.append(rid)
		var res: EQReservation = entry["res"]
		var inv_terms: Array = entry.get("inv_terms", [])
		if not inv_terms.is_empty():
			var inv := EQConditionEval.invalidation_check(inv_terms, _ctx(_view_of(res)))
			if int(inv["result"]) == EQConditionEval.Result.YES:
				res.status = EQReservation.Status.INVALIDATED
				_trace_invalidated(rid, res.actor_id, StringName(inv["closed_by"]))
				continue
			if int(inv["result"]) == EQConditionEval.Result.FAULT:
				var f: Dictionary = inv["fault"]
				runtime._fault(f["code"], f["message"], f.get("context", {}), true)
				continue
		var race_gid: StringName = _race_of.get(res.get_instance_id(), &"")
		if race_gid != &"" and _race_groups.has(race_gid):
			_settle_race(race_gid, res, rid)
		res.status = EQReservation.Status.RESOLVED
		var raw_view := _view_of(res)
		var transformed_view := _apply_effect_transforms(res, _apply_target_expansion(res, raw_view.duplicate(true)))
		for r in _apply_effect(res.definition.effect_name, transformed_view, &"bundle"):
			chunk.add(r)
		resolved_occurrences.append_array(_event_view_occurrences([raw_view], rid))
		if res.definition.kind == EQActionDefinition.Kind.OPERATION:
			_cause_target_reservation(res)
		if res.definition.kind != EQActionDefinition.Kind.REACTION_PREPARATION and res.remaining_ruminations > 0:
			_resubmit_rumination(res)
		_clear_bundle_event_link(rid)
	# 1) bundle trace
	runtime.trace().record({"kind": "bundle_resolved", "bundle": String(bundle_id), "members": ordered_event_ids})
	# 2) single bundle boundary sweep
	_sweep_bundle(resolved_occurrences)
	# 3) single drain after the bundle
	last_drained.append_array(chunk.drain())
	_clear_bundle_group(bundle_id)
	return first


func _event_view_occurrences(views: Array, trigger_event_id: int) -> Array:
	var out: Array = []
	for view_index in range(views.size()):
		out.append(
			{
				"event_id": trigger_event_id,
				"view_index": view_index,
				"view": (views[view_index] as Dictionary).duplicate(true),
			}
		)
	return out


func _reaction_fire_reservation(armed: EQReservation) -> EQReservation:
	var occurrence := EQReservation.from_dict(armed.to_dict())
	occurrence.event_id = -1
	occurrence.status = EQReservation.Status.PENDING
	return occurrence


func _sweep_bundle(trigger_occurrences: Array) -> void:
	var tick := runtime.scheduler.current_tick
	var fired: Array = []
	for trigger_occurrence in trigger_occurrences:
		var view: Dictionary = trigger_occurrence["view"]
		var producer_view := EQReactionFireContext.canonical_event_view(view)
		var chunk_fired := engine.on_event_resolved_occurrences(view.duplicate(true), tick)
		for fire in chunk_fired:
			fire["trigger_event_id"] = int(trigger_occurrence["event_id"])
			fire["trigger_view_index"] = int(trigger_occurrence["view_index"])
			fire["trigger_view"] = producer_view
			fired.append(fire)
	if fired.is_empty():
		_recheck_scheduled_invalidation()
		_evaluate_pending_conditional()
		return
	if tick == _cascade_tick:
		_cascade_round += 1
	else:
		_cascade_tick = tick
		_cascade_round = 1
	if _cascade_round > max_cascade_rounds:
		runtime._fault(EQError.TRIGGER_CHAIN_LIMIT, "same-tick reaction cascade exceeded %d rounds" % max_cascade_rounds, {"tick": tick}, true)
		return
	for fire in _order_candidates(fired, func(x): return x["reservation"]):
		var armed: EQReservation = fire["reservation"]
		var closes_arm := bool(fire["closes_arm"])
		var occurrence := _reaction_fire_reservation(armed)
		var id := _schedule(occurrence, 0)
		if id <= 0:
			continue
		var context := EQReactionFireContext.capture(
			id,
			int(fire["trigger_event_id"]),
			int(fire["trigger_view_index"]),
			tick,
			int(fire["fire_index"]),
			fire["trigger_view"]
		)
		if context.is_empty():
			runtime.scheduler.cancel(id)
			_by_event.erase(id)
			_window_of_event.erase(id)
			_bound_inv.erase(id)
			occurrence.status = EQReservation.Status.INVALIDATED
			runtime._fault(
				EQError.REACTION_FIRE_CONTEXT_INVALID,
				"matching trigger could not produce a reaction FIRE context",
				{
					"actor": String(armed.actor_id),
					"trigger_event_id": int(fire["trigger_event_id"]),
				},
				true
			)
			continue
		if closes_arm:
			# Exactly the occurrence which exhausted the armed slot records
			# count closure; later status mutation cannot duplicate it.
			_trace_invalidated(-1, armed.actor_id, &"reaction_count")
		_reaction_fire_context_by_event[id] = context
		if occurrence.definition != null:
			var bound_inv := _bind_conditions(occurrence).get("inv", [])
			if not bound_inv.is_empty():
				_bound_inv[id] = bound_inv
		runtime.trace().record(
			{
				"kind": "reaction_fired",
				"round": _cascade_round,
				"actor": String(occurrence.actor_id),
				"event_id": id,
				"reaction_fire_context": context.duplicate(true),
			}
		)
	_recheck_scheduled_invalidation()
	_evaluate_pending_conditional()
func _clear_bundle_event_link(event_id: int) -> void:
	var bundle_id := _bundle_of.get(event_id, &"")
	if bundle_id == &"":
		return
	_bundle_of.erase(event_id)
	if not _bundle_members.has(bundle_id):
		return
	var members: Array = _bundle_members[bundle_id]
	members.erase(event_id)
	if members.is_empty():
		_bundle_members.erase(bundle_id)
	else:
		_bundle_members[bundle_id] = members


func _cancel_window_pending_members(window_id: int) -> void:
	var event_ids := _window_of_event.keys()
	for event_id in event_ids:
		if int(_window_of_event[event_id]) != window_id:
			continue
		var res: EQReservation = _by_event.get(event_id, null)
		runtime.scheduler.cancel(event_id)
		_window_of_event.erase(event_id)
		_by_event.erase(event_id)
		_reaction_fire_context_by_event.erase(event_id)
		_bound_inv.erase(event_id)
		_clear_bundle_event_link(event_id)
		if res != null:
			res.status = EQReservation.Status.INVALIDATED
			_trace_invalidated(int(event_id), res.actor_id, &"intervention")


## Optional maintenance pass for a declared relation graph sweep. If no relation
## graph is attached, this is a strict no-op (compatibility behavior).
func _run_relation_maintenance(sweep: StringName) -> void:
	if relations == null:
		return
	relations.run_maintenance(sweep, {"lines": lines.ctx_lines(), "view": {}}, runtime.predicates())


func _clear_bundle_group(bundle_id: StringName) -> void:
	if not _bundle_members.has(bundle_id):
		return
	for id in _bundle_members[bundle_id]:
		_bundle_of.erase(int(id))
	_bundle_members.erase(bundle_id)


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
	var sweep := &"eqm.sweep.primary_threshold"
	if relations != null:
		sweep = relations.DEFAULT_SWEEP
	_run_relation_maintenance(sweep)
	var sweep_names := {}
	sweep_names[String(sweep)] = true
	for sweep_name in lines.sweep_rule_names():
		if sweep_names.has(String(sweep_name)):
			continue
		sweep_names[String(sweep_name)] = true
		_run_relation_maintenance(sweep_name)
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
			_clear_bundle_event_link(event_id)
			_by_event.erase(event_id)
			_reaction_fire_context_by_event.erase(event_id)
			_window_of_event.erase(event_id)
			_bound_inv.erase(event_id)
	for event_id in _expiry_by_event.keys():
		if (_expiry_by_event[event_id] as EQReservation).actor_id == actor_id:
			_expiry_by_event.erase(event_id)
	if relations != null:
		relations.invalidate_actor(actor_id)
	return runtime.invalidate_actor(actor_id, cause)


# --- pipeline internals ----------------------------------------------------

## §6.3 — an expiry event resolves: still armed -> close with `closed_by:
## duration` (+ optional expiry effect, through the pipeline); already closed
## -> a lightweight `closed_by: already_closed` record.
func _resolve_expiry(e) -> void:
	var res: EQReservation = _expiry_by_event[e.event_id]
	_expiry_by_event.erase(e.event_id)
	# Armed membership is authoritative. A scheduled FIRE occurrence is a
	# distinct reservation instance, so its status can never mask this slot;
	# this membership check also repairs historical status drift safely.
	if engine.disarm(res):
		res.status = EQReservation.Status.INVALIDATED
		_trace_invalidated(e.event_id, res.actor_id, &"duration")
		if not _verify_effect_commit_versions(res, &"expiry_resolution"):
			_last_effect_commit_outcome = EQEffectCommitResult.make_failure(
				{
					"code": String(EQError.EFFECT_COMMIT_RESULT_BINDING_MISMATCH),
					"actor": String(res.actor_id),
					"context": "expiry",
				}
			).to_dict()
			return
		var expiry_effect := res.definition.expiry_effect_name
		if expiry_effect != &"" and runtime.effect_commit_result_version(expiry_effect) > 0:
			var diagnostic := {
				"code": String(EQError.EFFECT_COMMIT_RESULT_CONTEXT_UNSUPPORTED),
				"effect": String(expiry_effect),
				"context": "expiry",
			}
			_last_effect_commit_outcome = EQEffectCommitResult.make_failure(
				diagnostic
			).to_dict()
			runtime._fault(
				EQError.EFFECT_COMMIT_RESULT_CONTEXT_UNSUPPORTED,
				"transactional effect handlers are unsupported for expiry effects",
				diagnostic,
				true
			)
			return
		for r in _apply_effect(expiry_effect, _view_of(res), &"expiry"):
			chunk.add(r)
		_sweep(_view_of(res), e.event_id)
		last_drained.append_array(chunk.drain())
	else:
		_trace_invalidated(e.event_id, res.actor_id, &"already_closed")


## Single-reservation transactional linkage. Legacy handlers are normalized to
## SUCCESS(records, [raw reservation view]) so their sweep behaviour is byte-
## compatible. A typed FAILURE (including an invalid typed return) carries no
## records and is never given a raw-view fallback sweep.
func _apply_single_effect_commit(
	name: StringName, handler_view: Dictionary, legacy_event_view: Dictionary
) -> EQEffectCommitResult:
	var result_version := runtime.effect_commit_result_version(name)
	if result_version <= 0:
		return EQEffectCommitResult.make_success(
			_apply_effect(name, handler_view, &"single"), [legacy_event_view]
		)
	if not runtime.has_effect(name):
		runtime._fault(
			EQError.EFFECT_UNREGISTERED,
			"effect '%s' has no registered handler" % name,
			{"effect": String(name)},
			true
		)
		return _invalid_effect_commit_failure(name, EQError.EFFECT_UNREGISTERED)
	var value = (runtime.effects()[name] as Callable).call(handler_view)
	if not (value is EQEffectCommitResult):
		runtime._fault(
			EQError.EFFECT_COMMIT_RESULT_INVALID,
			"transactional effect handler must return EQEffectCommitResult",
			{"effect": String(name), "result_version": result_version},
			true
		)
		return _invalid_effect_commit_failure(name, EQError.EFFECT_COMMIT_RESULT_INVALID)
	var result := value as EQEffectCommitResult
	if result.version() != result_version:
		runtime._fault(
			EQError.EFFECT_COMMIT_RESULT_VERSION_UNSUPPORTED,
			"transactional effect result version does not match its registration",
			{
				"effect": String(name),
				"registered_version": result_version,
				"actual_version": result.version(),
			},
			true
		)
		return _invalid_effect_commit_failure(
			name, EQError.EFFECT_COMMIT_RESULT_VERSION_UNSUPPORTED
		)
	var validation := result.validate()
	if not validation.is_valid():
		runtime._fault(
			EQError.EFFECT_COMMIT_RESULT_INVALID,
			"transactional effect handler returned an invalid result",
			{
				"effect": String(name),
				"issues": validation.codes().map(func(code): return String(code)),
			},
			true
		)
		return _invalid_effect_commit_failure(name, EQError.EFFECT_COMMIT_RESULT_INVALID)
	return result


func _invalid_effect_commit_failure(name: StringName, code: StringName) -> EQEffectCommitResult:
	return EQEffectCommitResult.make_failure({"code": String(code), "effect": String(name)})


## §6.1 legacy linkage: empty = effect-less; set-but-unregistered = stable
## error (dev halt / shipped skip), never a silent skip. A transactional
## handler is never invoked through this helper in an unsupported context.
func _apply_effect(name: StringName, view: Dictionary, context: StringName = &"legacy") -> Array:
	if name == &"":
		return []
	if not runtime.has_effect(name):
		runtime._fault(EQError.EFFECT_UNREGISTERED, "effect '%s' has no registered handler" % name, {"effect": String(name)}, true)
		return []
	if runtime.effect_commit_result_version(name) > 0:
		runtime._fault(
			EQError.EFFECT_COMMIT_RESULT_CONTEXT_UNSUPPORTED,
			"transactional effect handler reached an unsupported context",
			{"effect": String(name), "context": String(context)},
			true
		)
		return []
	var out = (runtime.effects()[name] as Callable).call(view)
	return out if out is Array else []


## §6.2/§6.1 step 4 — the sweep point: fire triggers (fired reactions are
## SCHEDULED at the current tick with their declared priority, bounded by
## same-tick rounds), re-check numeric invalidation, evaluate pending
## conditions.
func _sweep(view: Dictionary, trigger_event_id: int) -> void:
	_sweep_bundle(_event_view_occurrences([view], trigger_event_id))


## §5.3 numeric "eager": invalidation terms of scheduled reservations are
## re-evaluated at every sweep; a holding term cancels the event with its
## `closed_by` — looks eager, evaluated at a defined point.
func _recheck_scheduled_invalidation() -> void:
	for event_id in _bound_inv.keys():
		var res: EQReservation = _by_event.get(event_id, null)
		if res == null:
			_bound_inv.erase(event_id)
			_reaction_fire_context_by_event.erase(event_id)
			continue
		var scheduled_view := _view_of(res)
		var fire_context := reaction_fire_context_for_event(int(event_id))
		if not fire_context.is_empty():
			scheduled_view["reaction_fire_context"] = fire_context
		var inv := EQConditionEval.invalidation_check(
			_bound_inv[event_id], _ctx(scheduled_view)
		)
		if int(inv["result"]) == EQConditionEval.Result.YES:
			runtime.scheduler.cancel(event_id)
			res.status = EQReservation.Status.INVALIDATED
			_clear_bundle_event_link(event_id)
			_window_of_event.erase(event_id)
			_by_event.erase(event_id)
			_reaction_fire_context_by_event.erase(event_id)
			_bound_inv.erase(event_id)
			_trace_invalidated(event_id, res.actor_id, StringName(inv["closed_by"]))


## §5.4 — pending condition-gated reservations: a held solve set pushes the
## event at the detection tick (fresh sequence, declared priority); a held
## invalidation drops it (invalidation-wins).
func _evaluate_pending_conditional() -> void:
	var still: Array[Dictionary] = []
	var to_push: Array = []
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
				to_push.append(p)
			EQConditionEval.Outcome.FAULT:
				var f: Dictionary = (inv["fault"] if inv["fault"] != null else solve["fault"])
				runtime._fault(f["code"], f["message"], f.get("context", {}), true)
			_:
				still.append(p)
	_pending_conditional = still
	# simultaneous arrivals: the §7.1 hook decides the order; fallback = issuance
	for p in _order_candidates(to_push, func(x): return x["res"]):
		var res: EQReservation = p["res"]
		var id := _schedule(res, 0)
		if id > 0 and not (p["inv"] as Array).is_empty():
			_bound_inv[id] = p["inv"]


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
	var out := {
		"kind": &"reservation",
		"source": res.actor_id,
		"target": res.target_id,
		"tags": res.definition.tags if res.definition != null else [],
	}
	if res.definition != null:
		out["meta_level"] = int(res.definition.meta_level)
		if String(res.definition.state_name) != "":
			out["state"] = res.definition.state_name
	if not res.provenance.is_empty():
		var trail: Array = []
		for p in res.provenance:
			var entry := {
				"actor": StringName(p.get("actor", "")),
				"event_id": int(p.get("event_id", -1)),
				"meta_level": int(p.get("meta_level", 0)),
			}
			trail.append(entry)
		out["provenance"] = trail
	return out


func _trace_invalidated(event_id: int, actor_id: StringName, closed_by: StringName, race_group: StringName = &"") -> void:
	var fields := {
		"kind": "event_invalidated",
		"actor": String(actor_id),
		"closed_by": String(closed_by),
	}
	if event_id > 0:
		fields["event_id"] = event_id
	if race_group != &"":
		fields["race_group"] = String(race_group)
	runtime.trace().record(fields)


## An OPERATION reservation, on resolving, makes its target hold a reaction
## reservation tagged with the operation's target tag.
func _cause_target_reservation(op_res: EQReservation) -> void:
	# The effect handler may have removed/defeated the target through the normal
	# actor lifecycle. Do not arm a reservation owned by an absent actor; this is
	# local scheduling hygiene, not a game-level rule about what defeat means.
	if not runtime.registry.is_registered(op_res.target_id):
		_trace_invalidated(-1, op_res.target_id, &"actor_removed")
		return
	var def := EQActionDefinition.new()
	def.kind = EQActionDefinition.Kind.REACTION_PREPARATION
	def.duration = EQActionDefinition.DURATION_UNLIMITED
	def.tags = [op_res.definition.operation_target_tag]
	var caused := EQReservation.new(op_res.target_id, def)
	caused.provenance = op_res.provenance.duplicate(true)
	caused.provenance.append({
		"actor": op_res.actor_id,
		"event_id": op_res.event_id,
		"meta_level": int(op_res.definition.meta_level if op_res.definition != null else 0),
	})
	submit(caused)


func _resubmit_rumination(res: EQReservation) -> void:
	# A successful effect remains successful even when it removes its source.
	# Only the implicit future repetitions are cancelled; current records and
	# the current outer sweep continue normally.
	if not runtime.registry.is_registered(res.actor_id):
		res.remaining_ruminations = 0
		_trace_invalidated(-1, res.actor_id, &"actor_removed")
		return
	res.remaining_ruminations -= 1
	submit(res)


## Reaction preparations currently armed for an actor.
func armed_for(actor_id: StringName) -> Array:
	return engine.armed_for(actor_id).map(func(a): return a["reservation"])


## Reservations scheduled (pending) but not yet resolved.
func pending() -> Array:
	return _by_event.values()


## Condition-gated reservations awaiting their solve conditions (SEM §5.4).
func pending_conditional() -> Array:
	return _pending_conditional.map(func(p): return p["res"])
