class_name EQReservationRuntime
extends RefCounted
## L2 reservation scheduling/resolution pipeline over an EQRuntime.
##
## submit() places a reservation on the queue according to its kind; resolve_next()
## pops the next ready reservation, marks it resolved, and applies its effect:
##   immediate  -> resolves at delay 0
##   prepared   -> resolves after delay
##   ready      -> the turn-grant (delay = AP recovery; the AP model is EQM-052)
##   wait       -> schedules a READY reservation (the actor's next turn)
##   operation  -> on resolution, causes a reservation on the target
##   reaction_preparation -> armed (no scheduled event); the trigger that fires it
##                           is EQM-061
##
## Conditions (EQM-060) and trigger firing / rumination cycle guard (EQM-061/062)
## build on this skeleton. Resolution events flow through EQRuntime.advance, so
## they appear in the canonical trace (kind = "reservation").

const EQRuntime := preload("eq_runtime.gd")
const EQReservation := preload("eq_reservation.gd")
const EQActionDefinition := preload("../resources/eq_action_definition.gd")

var runtime: EQRuntime
var _by_event: Dictionary = {}        # event_id -> EQReservation
var _armed: Array[EQReservation] = []  # reaction preparations awaiting a trigger


func _init(p_runtime = null) -> void:
	runtime = p_runtime if p_runtime != null else EQRuntime.new()


## Schedules (or arms) a reservation per its kind. Returns the scheduler event_id,
## or -1 for a reaction preparation (armed, not scheduled) or a rejected schedule.
func submit(res: EQReservation) -> int:
	var kind := res.definition.kind
	match kind:
		EQActionDefinition.Kind.IMMEDIATE:
			return _schedule(res, 0)
		EQActionDefinition.Kind.PREPARED, EQActionDefinition.Kind.READY, EQActionDefinition.Kind.OPERATION:
			return _schedule(res, res.definition.delay)
		EQActionDefinition.Kind.WAIT:
			# ending the turn schedules the actor's next turn as a READY reservation
			res.status = EQReservation.Status.RESOLVED
			var ready_def := EQActionDefinition.new()
			ready_def.kind = EQActionDefinition.Kind.READY
			ready_def.delay = res.definition.delay
			return submit(EQReservation.new(res.actor_id, ready_def))
		EQActionDefinition.Kind.REACTION_PREPARATION:
			res.status = EQReservation.Status.ARMED
			_armed.append(res)
			return -1
	return -1


func _schedule(res: EQReservation, delay: int) -> int:
	var id := runtime.schedule(res.actor_id, runtime.scheduler.current_tick + delay, 0, &"reservation")
	if id > 0:
		res.event_id = id
		res.status = EQReservation.Status.PENDING
		_by_event[id] = res
	return id


## Resolves the next ready reservation, applying its effect. Returns the resolved
## reservation, or null when the next event is not a tracked reservation / queue
## is empty.
func resolve_next() -> EQReservation:
	var e := runtime.advance()
	if e == null:
		return null
	var res = _by_event.get(e.event_id, null)
	if res == null:
		return null
	_by_event.erase(e.event_id)
	res.status = EQReservation.Status.RESOLVED
	if res.definition.kind == EQActionDefinition.Kind.OPERATION:
		_cause_target_reservation(res)
	# rumination: a resolved reservation with ruminations left decrements and
	# reschedules itself (count-bounded, so it cannot loop forever).
	if res.remaining_ruminations > 0:
		res.remaining_ruminations -= 1
		submit(res)
	return res


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
	return _armed.filter(func(r): return r.actor_id == actor_id)


## Reservations scheduled (pending) but not yet resolved, optionally filtered by kind.
func pending() -> Array:
	return _by_event.values()
