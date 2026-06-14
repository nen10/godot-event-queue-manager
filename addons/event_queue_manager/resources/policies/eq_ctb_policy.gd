class_name EQCTBPolicy
extends EQPolicy
## Charge Time Battle: an actor's next turn comes after a delay inversely
## proportional to its speed; a faster actor therefore acts more often. A heavy
## action costs a longer delay, a wait costs a shorter one. Haste/slow are
## expressed as changes to the actor's `data[speed]`, read fresh on each
## reschedule, so they affect the next turn.
##
## The delay is integer (no float in the ordering keys, EVENT_MODEL_SEMANTICS
## §12): delay = ceil(cost * scale / speed). At equal due_tick, priority = speed
## breaks the tie in favour of the faster actor, then registration order.

@export var speed_key: StringName = &"speed"
## Default action cost used for the initial charge and for a finish with cost <= 0.
@export var base_cost: int = 100
## Tick resolution: larger scale gives finer distinction between speeds.
@export var scale: int = 100


func _speed(runtime, actor_id: StringName) -> int:
	var s = runtime.registry.get_state(actor_id)
	if s == null:
		return 1
	return maxi(1, int(s.data.get(speed_key, 1)))


## ceil(cost * scale / speed), clamped to >= 1 so the queue always progresses.
func delay_of(cost: int, speed: int) -> int:
	var c := cost if cost > 0 else base_cost
	var sp := maxi(1, speed)
	return maxi(1, (c * scale + sp - 1) / sp)


func seed(runtime, actor_ids: Array) -> void:
	for actor_id in actor_ids:
		var sp := _speed(runtime, actor_id)
		runtime.schedule(actor_id, delay_of(base_cost, sp), sp, &"turn")


func on_turn_finished(runtime, actor_id: StringName, result) -> void:
	if not runtime.registry.is_registered(actor_id):
		return
	var sp := _speed(runtime, actor_id)
	var cost: int = result.cost if result != null else base_cost
	runtime.schedule(actor_id, runtime.scheduler.current_tick + delay_of(cost, sp), sp, &"turn")
