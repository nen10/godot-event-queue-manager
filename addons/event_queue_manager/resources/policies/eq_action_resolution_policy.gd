class_name EQActionResolutionPolicy
extends EQPolicy
## Action Resolution Turn-Based (the roadmap's core test case). A turn is a
## "ready reservation" granted when an actor's AP has recovered: the resolution
## time of "N" means "until AP recovers by N" (the per-entity AP-recovery
## progression, EVENT_MODEL_SEMANTICS §4 / COVERAGE row 9). The turn closes
## through wait — finishing spends AP and schedules the next ready reservation
## after the AP-recovery delay.
##
## L2 (the deep reservation/AP path); the base EQPolicy stays L1. AP spend and
## recovery are integer and deterministic. Reducing this to the reservation +
## event-line model (reproducing the dedicated policies' goldens) is EQM-053.

@export var ap_key: StringName = &"ap"
@export var recovery_key: StringName = &"ap_recovery"   ## per-actor AP recovered per tick
@export var ap_max: int = 100                            ## AP at which a turn is ready
@export var recovery_per_tick: int = 10                  ## default recovery when unset on the actor
@export var action_ap_cost: int = 100                    ## default AP spent when a finish gives no cost


func _recovery(runtime, actor_id: StringName) -> int:
	var s = runtime.registry.get_state(actor_id)
	if s == null:
		return maxi(1, recovery_per_tick)
	return maxi(1, int(s.data.get(recovery_key, recovery_per_tick)))


## Ticks to recover `deficit` AP at `recovery` per tick (ceil, >= 1).
func _recovery_delay(deficit: int, recovery: int) -> int:
	var rec := maxi(1, recovery)
	return 1 if deficit <= 0 else maxi(1, (deficit + rec - 1) / rec)


func seed(runtime, actor_ids: Array) -> void:
	for actor_id in actor_ids:
		var s = runtime.registry.get_state(actor_id)
		if s != null:
			s.data[ap_key] = 0   # charges up to ap_max before the first ready turn
		runtime.schedule(actor_id, _recovery_delay(ap_max, _recovery(runtime, actor_id)), 0, &"turn")


## The turn closes (wait): spend AP, then schedule the next ready reservation for
## when the spent AP has recovered.
func on_turn_finished(runtime, actor_id: StringName, result) -> void:
	if not runtime.registry.is_registered(actor_id):
		return
	var s = runtime.registry.get_state(actor_id)
	var spent: int = result.cost if (result != null and result.cost > 0) else action_ap_cost
	s.data[ap_key] = ap_max - spent   # AP held right after the turn (deficit from max)
	var delay := _recovery_delay(spent, _recovery(runtime, actor_id))
	runtime.schedule(actor_id, runtime.scheduler.current_tick + delay, 0, &"turn")


## The turn closes through wait: commit the player's drafted immediate actions
## (if a transaction is given) to the live scheduler, then schedule the ready
## reservation for the next turn (after AP recovery). Drafting is rollbackable up
## to this point (EQM-070); wait is the commit boundary.
func wait_close(runtime, actor_id: StringName, result, transaction = null) -> void:
	if transaction != null:
		transaction.commit()
	on_turn_finished(runtime, actor_id, result)


## The actor's next turn as a concrete READY reservation (EQM-050 READY kind),
## with the delay set to the AP-recovery time for `spent` AP. Lets a consumer
## treat the ready turn as a reservation object without driving the policy.
func ready_reservation_for(runtime, actor_id: StringName, spent: int = -1) -> EQReservation:
	var cost := spent if spent > 0 else action_ap_cost
	var def := EQActionDefinition.new()
	def.kind = EQActionDefinition.Kind.READY
	def.delay = _recovery_delay(cost, _recovery(runtime, actor_id))
	return EQReservation.new(actor_id, def)
