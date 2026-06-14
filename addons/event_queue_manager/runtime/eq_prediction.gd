class_name EQPrediction
extends RefCounted
## Pure hypothetical prediction over a live runtime (roadmap principle 17).
##
## A prediction never mutates live state: it branches a snapshot, advances the
## branch virtually, and discards it. So a HUD can show the next N turns and an
## AI can compare "act now vs wait" without touching the real queue. The branch
## is advanced one step at a time (pop → policy reschedule → repeat), so the
## next event is re-derived each step rather than precomputed — when event-lines
## land (Phase 4/5) this makes the watched-set per-step and independent of the
## prediction depth N (Q26).

const EQRuntime := preload("eq_runtime.gd")
const EQActionResult := preload("eq_action_result.gd")


## A disposable copy of `runtime`: the live scheduler snapshot restored into a
## fresh runtime, with active actors re-registered carrying copied data. Mutating
## or discarding the branch never affects `runtime`.
static func branch(runtime) -> EQRuntime:
	var b := EQRuntime.new(runtime.config, runtime.mode)
	b.emit_engine_diagnostics = false  # a hypothetical must stay quiet
	b.scheduler.restore(runtime.scheduler.snapshot())
	for actor_id in runtime.registry.actor_ids():
		var src = runtime.registry.get_state(actor_id)
		var dst := b.register_actor(actor_id)
		if dst != null and src != null:
			dst.data = src.data.duplicate(true)
	return b


## Predicts the actor order of the next `n` turns assuming each acts with a
## default-cost action. Live state is unchanged. Returns up to `n` actor_ids
## (fewer if the queue empties).
static func predict_turns(runtime, n: int, default_cost: int = 0) -> Array:
	var b := branch(runtime)
	var pol = runtime.config.policy if runtime.config != null else null
	var out: Array = []
	while out.size() < n:
		var e := b.advance()
		if e == null:
			break
		out.append(e.actor_id)
		if pol != null:
			pol.on_turn_finished(b, e.actor_id, EQActionResult.new(default_cost, 0))
	return out
