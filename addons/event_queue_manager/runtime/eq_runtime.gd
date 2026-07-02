class_name EQRuntime
extends RefCounted
## Headless facade coordinating scheduler, actors, action finish, and (optional)
## config — with no Godot scene tree. EQManager (EQM-032) is a thin node wrapper
## over this.
##
## Resilience is a two-mode toggle (RUNTIME_RESILIENCE_POLICY):
##   dev      — surface anomalies loudly and halt the current advance (fail-fast).
##   shipped  — skip the offending event, log it, record an invalid_event_skipped
##              trace, and continue, never crashing the consumer's game (fail-safe).
## Crucially this only diverges on anomalies: with normal input the two modes
## produce a byte-identical trace (mode neutrality). dev does NOT hard-assert —
## it sets `halted` (observable) and optionally emits an engine diagnostic — so a
## stop is testable and never takes the consumer down.

const EQEntry := preload("eq_entry.gd")
const EQScheduler := preload("eq_scheduler.gd")
const EQActorRegistry := preload("eq_actor_registry.gd")
const EQActionResult := preload("eq_action_result.gd")
const EQTrace := preload("eq_trace.gd")

enum Mode { DEV, SHIPPED }

var mode: int = Mode.DEV
## Whether faults also emit an engine diagnostic (push_error/warning). The
## structured `faults` log is always written regardless; tests turn this off to
## keep the log clean while still asserting on faults/halted/trace.
var emit_engine_diagnostics: bool = true

var scheduler: EQScheduler
var registry: EQActorRegistry
var config   # EQConfig or null

## Structured fault log: each {code, recoverability, message, context}. Written
## in both modes — anomalies are never silently swallowed.
var faults: Array[Dictionary] = []
## dev mode set this when it stops on an anomaly during advance.
var halted: bool = false

var _trace: EQTrace


func _init(p_config = null, p_mode: int = Mode.DEV) -> void:
	config = p_config
	mode = p_mode
	scheduler = EQScheduler.new()
	registry = EQActorRegistry.new()
	_trace = EQTrace.new()


func set_mode(m: int) -> void:
	mode = m


# --- named predicate registry (SEM §5.5, EQM-111) -------------------------
# Predicate-type conditions serialize a name, never a Callable, so pending
# conditions survive save/load. Instance-scoped (scene-local rule); the
# predicate input is a serializable view dict only.

var _predicates: Dictionary = {}


## Registers (or replaces — idempotent setup) a named predicate. An empty name
## is rejected as a fault. Returns whether the predicate was registered.
func register_predicate(name: StringName, predicate: Callable) -> bool:
	if name == &"":
		_fault(EQError.CONDITION_PREDICATE_NAME_EMPTY, "predicate name must not be empty", {}, true)
		return false
	_predicates[name] = predicate
	return true


func has_predicate(name: StringName) -> bool:
	return _predicates.has(name)


## Evaluation-context view (EQConditionEval ctx["predicates"]). A copy: register
## through register_predicate, never by mutating the returned dict.
func predicates() -> Dictionary:
	return _predicates.duplicate()


# --- named effect registry (SEM §6.1, EQM-113) -----------------------------
# Declared linkage: a reservation whose definition sets `effect_name` resolves
# through the registered handler (view -> Array[EQEffectRecord]); set-but-
# unregistered is a stable error (never a silent skip). Empty = effect-less.

var _effects: Dictionary = {}


## Registers (or replaces — idempotent setup) a named effect handler.
func register_effect(name: StringName, handler: Callable) -> bool:
	if name == &"":
		_fault(EQError.CONDITION_PREDICATE_NAME_EMPTY, "effect name must not be empty", {}, true)
		return false
	_effects[name] = handler
	return true


func has_effect(name: StringName) -> bool:
	return _effects.has(name)


## A copy (same read-only rule as predicates()).
func effects() -> Dictionary:
	return _effects.duplicate()


## Normal-path actor departure (SEM §13, Q39; Q05 是正). Cancels the actor's
## pending events with an `event_invalidated` trace (`closed_by: <cause>`),
## then unregisters. MODE-NEUTRAL: death/leave mid-battle is normal gameplay,
## not an anomaly — identical behaviour and trace in dev and shipped. Returns
## the number of cancelled events. (L2 extends this: EQReservationRuntime
## also disarms reactions and drops pending conditional reservations.)
func invalidate_actor(actor_id: StringName, cause: StringName = &"actor_removed") -> int:
	var cancelled := 0
	for e in scheduler.peek(scheduler.size()):
		if e.actor_id == actor_id and scheduler.cancel(e.event_id):
			_trace.record({
				"kind": "event_invalidated",
				"event_id": e.event_id,
				"actor": String(actor_id),
				"closed_by": String(cause),
			})
			cancelled += 1
	if registry.is_registered(actor_id):
		registry.unregister(actor_id)
	return cancelled


## Validates the config (if any) and reports it. A missing config is not an
## anomaly (scene-local default is config-less); an invalid config is surfaced
## per mode. Returns the config's EQValidation (empty when no config).
func start() -> EQValidation:
	var v := EQValidation.new()
	if config != null:
		v = config.validate()
		for issue in v.errors():
			_fault(issue["code"], issue["message"], {}, false)
	return v


## Registers an actor; returns its EQActorState or null on rejection (the
## rejection code is surfaced as a fault per mode).
func register_actor(actor_id: StringName) -> EQActorState:
	var rv := registry.validate_register(actor_id)
	if not rv.is_valid():
		var issue = rv.errors()[0]
		_fault(issue["code"], issue["message"], {"actor_id": String(actor_id)}, false)
		return null
	return registry.register(actor_id)


## Schedules an event for a registered actor. Returns the event_id, or -1 if the
## actor is not registered (anomaly, per mode).
func schedule(actor_id: StringName, due_tick: int, priority: int = 0, kind: StringName = &"turn") -> int:
	if not registry.is_registered(actor_id):
		_fault(EQError.RUNTIME_SCHEDULE_UNREGISTERED_ACTOR, "schedule for unregistered actor", {"actor_id": String(actor_id)}, true)
		return -1
	return scheduler.push(due_tick, priority, kind, actor_id)


## Resolves and returns the next ready event, recording it to the trace. An event
## whose actor was removed mid-flight is an anomaly: dev halts and returns null;
## shipped skips it (invalid_event_skipped trace) and continues to the next.
func advance() -> EQEntry:
	if halted:
		return null
	while not scheduler.is_empty():
		var e := scheduler.pop()
		if e == null:
			return null
		if e.actor_id == &"" or registry.is_registered(e.actor_id):
			_trace.record_resolved(e, "timer", EQTrace._decided_by(e, scheduler.peek_next()))
			return e
		# anomaly: event for a removed/unregistered actor
		_fault(EQError.RUNTIME_UNREGISTERED_ACTOR_EVENT, "event for unregistered actor", {"actor_id": String(e.actor_id), "event_id": e.event_id}, true)
		if mode == Mode.DEV:
			return null
		# shipped: record the skip in the trace and continue
		_trace.record({"kind": "invalid_event_skipped", "event_id": e.event_id, "actor": String(e.actor_id), "cause": "contract_violation"})
	return null


## Finishes an action and schedules the actor's next event at current_tick +
## delay. The result must validate; an invalid result schedules nothing in either
## mode (dev also halts). Returns the new event_id, or -1.
func finish_action(actor_id: StringName, result: EQActionResult) -> int:
	var rv := result.validate()
	if not rv.is_valid():
		var issue = rv.errors()[0]
		_fault(issue["code"], issue["message"], {"actor_id": String(actor_id)}, true)
		return -1
	if not registry.is_registered(actor_id):
		_fault(EQError.RUNTIME_SCHEDULE_UNREGISTERED_ACTOR, "finish_action for unregistered actor", {"actor_id": String(actor_id)}, true)
		return -1
	return scheduler.push(scheduler.current_tick + result.delay, 0, &"turn", actor_id)


func trace() -> EQTrace:
	return _trace


func trace_jsonl() -> String:
	return _trace.to_jsonl()


## Records a fault (always) and applies the mode behaviour. `in_loop` marks
## anomalies during the resolve loop, where dev halts.
func _fault(code: StringName, message: String, context: Dictionary, in_loop: bool) -> void:
	faults.append({
		"code": code,
		"recoverability": EQError.recoverability_of(code),
		"message": message,
		"context": context,
	})
	if emit_engine_diagnostics:
		var line := "EQRuntime[%s]: %s (%s)" % ["dev" if mode == Mode.DEV else "shipped", message, String(code)]
		if mode == Mode.DEV:
			push_error(line)
		else:
			push_warning(line)
	if mode == Mode.DEV and in_loop:
		halted = true
