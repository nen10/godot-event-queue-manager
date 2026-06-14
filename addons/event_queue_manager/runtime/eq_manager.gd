class_name EQManager
extends Node
## Scene-local Node facade over EQRuntime, exposing the L0 flow
## (register → turn_ready → finish) as Godot signals. Autoload is optional; the
## default is a scene-local node (PROJECT_PROFILE).
##
## Game-loop driver contract (EVENT_MODEL_SEMANTICS §14):
##   who advances — the consumer calls step() / advance_frame(); the node does
##     not implicitly drive every frame.
##   suspend — after turn_ready the node suspends (step() returns null) until the
##     consumer calls finish_action: the player-input await boundary.
##   await boundary — between event_resolved and the next step() the consumer
##     presents the action.
##   frame-budget — advance_frame(budget) resolves up to `budget` events per call
##     (auto-finishing turns) to avoid large-battle hitches; the order/trace is
##     invariant to the budget (time-slicing never changes determinism).
##
## Production node bridge (save/load rebind, autoload installer, full
## multi-domain signal set) is EQM-085.

const EQRuntime := preload("eq_runtime.gd")
const EQActionResult := preload("eq_action_result.gd")
const EQEntry := preload("eq_entry.gd")

signal queue_changed()
signal event_ready(entry)
signal turn_ready(actor_id, entry)
signal event_resolved(entry)
signal timeline_advanced(tick)
signal invalid_event_skipped(fault)

var policy   # EQPolicy or null
var _rt: EQRuntime
var _awaiting_turn: bool = false


func _init() -> void:
	_rt = EQRuntime.new()


## The wrapped runtime (for snapshot / scheduler inspection).
func runtime() -> EQRuntime:
	return _rt


func set_mode(mode: int) -> void:
	_rt.set_mode(mode)


## Sets a config (and its policy) and validates it, surfacing faults per mode.
func configure(config) -> EQValidation:
	_rt.config = config
	policy = config.policy if config != null else null
	return _rt.start()


func set_policy(p) -> void:
	policy = p


func validate() -> EQValidation:
	if _rt.config != null:
		return _rt.config.validate()
	return EQValidation.new()


func register_actor(actor_id: StringName) -> EQActorState:
	return _rt.register_actor(actor_id)


## Schedules the initial turns via the policy.
func seed() -> void:
	if policy != null:
		policy.seed(_rt, _rt.registry.actor_ids())
		queue_changed.emit()


## Resolves the next event and emits the matching signals. Returns the entry, or
## null when the queue is empty or the node is suspended awaiting finish_action.
func step() -> EQEntry:
	if _awaiting_turn:
		return null
	var before_tick: int = _rt.scheduler.current_tick
	var pre_faults: int = _rt.faults.size()
	var e := _rt.advance()
	if _rt.faults.size() > pre_faults:
		invalid_event_skipped.emit(_rt.faults.back())
	if e == null:
		return null
	if _rt.scheduler.current_tick != before_tick:
		timeline_advanced.emit(_rt.scheduler.current_tick)
	event_resolved.emit(e)
	queue_changed.emit()
	if e.kind == &"turn":
		_awaiting_turn = true
		turn_ready.emit(e.actor_id, e)
	else:
		event_ready.emit(e)
	return e


func is_awaiting_turn() -> bool:
	return _awaiting_turn


## Finishes an action: delegates to the policy (if set) to schedule the next
## turn, clears the suspend, and signals the queue change.
func finish_action(actor_id: StringName, result) -> void:
	_awaiting_turn = false
	if policy != null:
		policy.on_turn_finished(_rt, actor_id, result)
	else:
		_rt.finish_action(actor_id, result)
	queue_changed.emit()


## Resolves up to `budget` events this frame, auto-finishing turns with
## `auto_result` (default: a normal 0/0 action). For non-interactive / batched
## advancing. The resulting trace is invariant to `budget`.
func advance_frame(budget: int, auto_result = null) -> int:
	var res = auto_result if auto_result != null else EQActionResult.new(0, 0)
	var resolved := 0
	while resolved < budget and not _rt.scheduler.is_empty():
		var e := step()
		if e == null:
			break
		resolved += 1
		if _awaiting_turn:
			finish_action(e.actor_id, res)
	return resolved


func trace_jsonl() -> String:
	return _rt.trace_jsonl()
