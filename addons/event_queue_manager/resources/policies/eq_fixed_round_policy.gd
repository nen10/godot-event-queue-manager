class_name EQFixedRoundPolicy
extends EQPolicy
## Fixed round: every actor acts once per round in initiative order; when a
## round ends a new one begins (refresh). Higher initiative acts first; equal
## initiative resolves in registration order. Removed actors are skipped.
##
## Mapping onto the core (no new ordering machinery): round N is `due_tick = N`,
## an actor's turn carries `priority = initiative`, and EQOrdering already gives
## priority-DESC then sequence-ASC (registration order) at equal tick. Each actor
## re-enters the next round by scheduling at current_tick + 1 when it finishes,
## so the round boundary is implicit and deterministic.

## Which key in EQActorState.data holds the initiative value (acceptance-defined
## per-entity datum, not a built-in field; Q16).
@export var initiative_key: StringName = &"initiative"


func _initiative(runtime, actor_id: StringName) -> int:
	var s = runtime.registry.get_state(actor_id)
	if s == null:
		return 0
	return int(s.data.get(initiative_key, 0))


func seed(runtime, actor_ids: Array) -> void:
	# Round 1: everyone, at due_tick 1, ordered by initiative (priority DESC),
	# ties by registration order (sequence ASC, from seed/registration order).
	for actor_id in actor_ids:
		runtime.schedule(actor_id, 1, _initiative(runtime, actor_id), &"turn")


func on_turn_finished(runtime, actor_id: StringName, _result) -> void:
	# A removed actor does not re-enter; its pending event is skipped by the
	# runtime (shipped) / halts (dev).
	if not runtime.registry.is_registered(actor_id):
		return
	runtime.schedule(actor_id, runtime.scheduler.current_tick + 1, _initiative(runtime, actor_id), &"turn")
