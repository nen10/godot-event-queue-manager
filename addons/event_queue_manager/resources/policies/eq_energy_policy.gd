class_name EQEnergyPolicy
extends EQPolicy
## Roguelike energy: each actor accumulates energy by speed; when it reaches the
## threshold the actor acts, spends the action's cost, and **carries over** the
## remainder — so a cheap action leaves energy banked and the next turn comes
## sooner. A faster actor fills the threshold more often.
##
## Integer mapping (no float in ordering, EVENT_MODEL_SEMANTICS §12): from the
## carried energy, the delay to refill is ceil((threshold - carry) / speed); the
## energy the actor will hold at that turn is stored so the next finish can
## subtract its cost. carry can go negative (an expensive action runs a deficit,
## lengthening the next refill).

@export var speed_key: StringName = &"speed"
@export var energy_key: StringName = &"energy"   ## carried energy (post-spend), user-inspectable
@export var threshold: int = 100
@export var base_cost: int = 100

const _AT_TURN := &"_eq_energy_at_turn"


func _speed(runtime, actor_id: StringName) -> int:
	var s = runtime.registry.get_state(actor_id)
	if s == null:
		return 1
	return maxi(1, int(s.data.get(speed_key, 1)))


## Schedules the actor's turn for when its carried energy refills to threshold,
## recording the energy it will hold at that turn.
func _arm(runtime, actor_id: StringName, from_tick: int) -> void:
	var s = runtime.registry.get_state(actor_id)
	if s == null:
		return
	var speed := _speed(runtime, actor_id)
	var carry: int = int(s.data.get(energy_key, 0))
	var deficit := threshold - carry
	var delay := 1 if deficit <= 0 else maxi(1, (deficit + speed - 1) / speed)
	s.data[_AT_TURN] = carry + speed * delay
	runtime.schedule(actor_id, from_tick + delay, 0, &"turn")


func seed(runtime, actor_ids: Array) -> void:
	for actor_id in actor_ids:
		var s = runtime.registry.get_state(actor_id)
		if s != null:
			s.data[energy_key] = 0
		_arm(runtime, actor_id, 0)


func on_turn_finished(runtime, actor_id: StringName, result) -> void:
	if not runtime.registry.is_registered(actor_id):
		return
	var s = runtime.registry.get_state(actor_id)
	var cost: int = result.cost if (result != null and result.cost > 0) else base_cost
	var at_turn: int = int(s.data.get(_AT_TURN, threshold))
	s.data[energy_key] = at_turn - cost   # carry-over (may be negative)
	_arm(runtime, actor_id, runtime.scheduler.current_tick)
