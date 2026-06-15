class_name EQWaitTurnPolicy
extends EQPolicy
## Tactics Ogre / FFT wait-turn: each unit has a wait value (ticks until ready);
## the next-ready unit (smallest wait) acts, and the action's cost sets its next
## wait. There is no idle stepping — the scheduler pops the minimum due_tick and
## the clock jumps straight to the next ready unit ("instant resolve").
##
## A unit's turn is scheduled at `due_tick = wait`, `priority = agility`. At equal
## wait (equal due_tick) the tie-break is: higher agility acts first (a faster
## unit goes first, the Q09 "lower base WT first" rule expressed via agility),
## and equal agility falls back to registration order (sequence) — a fully
## deterministic total order.

@export var wait_key: StringName = &"wait"
@export var agility_key: StringName = &"agility"   ## equal-wait tie-break (higher first)
@export var base_cost: int = 100


func _agility(runtime, actor_id: StringName) -> int:
	var s = runtime.registry.get_state(actor_id)
	return 0 if s == null else int(s.data.get(agility_key, 0))


func seed(runtime, actor_ids: Array) -> void:
	for actor_id in actor_ids:
		var s = runtime.registry.get_state(actor_id)
		var wait := 1 if s == null else maxi(0, int(s.data.get(wait_key, 0)))
		runtime.schedule(actor_id, wait, _agility(runtime, actor_id), &"turn")


func on_turn_finished(runtime, actor_id: StringName, result) -> void:
	if not runtime.registry.is_registered(actor_id):
		return
	var next_wait: int = result.cost if (result != null and result.cost > 0) else base_cost
	next_wait = maxi(1, next_wait)
	runtime.schedule(actor_id, runtime.scheduler.current_tick + next_wait, _agility(runtime, actor_id), &"turn")
