extends Node
## DOGFOOD — a minimal playable Action Resolution Turn-Based slice built with the
## PUBLIC Event Queue Manager API only (no runtime internals). It exercises, end
## to end: AP-recovery turns (EQActionResolutionPolicy via EQManager), a counter
## reaction (EQTriggerEngine + EQCondition on a reaction-preparation reservation),
## simulation effects + queued visuals (EQEffectRecord / EQEffectChunk /
## EQPresentationBuffer), and deterministic randomness (EQRng). It emits one
## canonical trace (EQTrace, open-kind schema) proven against a golden.
##
## This is the consumer's view: the addon provides the primitives; this slice
## wires them. Ergonomics findings are recorded in
## docs/review/DOGFOOD_FRICTION_2026-06-18.md.

const EQManager := preload("res://addons/event_queue_manager/runtime/eq_manager.gd")
const EQConfig := preload("res://addons/event_queue_manager/resources/eq_config.gd")
const EQActionResolutionPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_action_resolution_policy.gd")
const EQActionResult := preload("res://addons/event_queue_manager/runtime/eq_action_result.gd")
const EQActionDefinition := preload("res://addons/event_queue_manager/resources/eq_action_definition.gd")
const EQReservation := preload("res://addons/event_queue_manager/runtime/eq_reservation.gd")
const EQCondition := preload("res://addons/event_queue_manager/resources/eq_condition.gd")
const EQTriggerEngine := preload("res://addons/event_queue_manager/runtime/eq_trigger_engine.gd")
const EQEffectRecord := preload("res://addons/event_queue_manager/runtime/eq_effect_record.gd")
const EQEffectChunk := preload("res://addons/event_queue_manager/runtime/eq_effect_chunk.gd")
const EQPresentationPolicy := preload("res://addons/event_queue_manager/resources/eq_presentation_policy.gd")
const EQPresentationBuffer := preload("res://addons/event_queue_manager/runtime/eq_presentation_buffer.gd")
const EQPresentationEvent := preload("res://addons/event_queue_manager/runtime/eq_presentation_event.gd")
const EQRng := preload("res://addons/event_queue_manager/runtime/eq_rng.gd")
const EQTrace := preload("res://addons/event_queue_manager/runtime/eq_trace.gd")
const EQReservationRuntime := preload("res://addons/event_queue_manager/runtime/eq_reservation_runtime.gd")


## Runs a fixed slice and returns the canonical trace. `turns` ready-turns are
## resolved; each attacker hits the foe (a deterministic EQRng damage roll),
## producing an effect record + a queued visual; the foe's armed counter fires on
## incoming damage.
static func run_trace(turns: int) -> String:
	var config := EQConfig.new()
	config.policy = EQActionResolutionPolicy.new()
	var manager := EQManager.new()
	manager.configure(config)
	manager.register_actor(&"hero").data["ap_recovery"] = 12
	manager.register_actor(&"orc").data["ap_recovery"] = 9
	manager.seed()

	# hero arms a counterattack: triggers on incoming damage targeting hero.
	var trigger := EQTriggerEngine.new()
	var counter_def := EQActionDefinition.new()
	counter_def.kind = EQActionDefinition.Kind.REACTION_PREPARATION
	counter_def.duration = EQActionDefinition.DURATION_UNLIMITED
	counter_def.tags = [&"counter"]
	counter_def.rumination = 1   # hero may counter twice
	var counter_cond := EQCondition.new()
	counter_cond.match_target = &"hero"
	counter_cond.require_tags = [&"damage"]
	trigger.arm(EQReservation.new(&"hero", counter_def), counter_cond, 0)

	var chunk := EQEffectChunk.new()
	var visuals := EQPresentationBuffer.new(EQPresentationPolicy.new())
	var rng := EQRng.new(20260618)
	var trace := EQTrace.new()

	for _i in turns:
		var e = manager.step()
		if e == null:
			break
		var attacker: StringName = e.actor_id
		var foe: StringName = &"orc" if attacker == &"hero" else &"hero"
		trace.record({"kind": "turn", "actor": String(attacker), "tick": manager.runtime().scheduler.current_tick})

		# the attacker hits the foe — simulation truth first (deterministic roll)
		var dmg: int = rng.randi_range(5, 12)
		var effect := EQEffectRecord.new(&"damage", foe, &"hp", -dmg)
		effect.source = attacker
		effect.tags = [&"damage"]
		effect.classification = EQEffectRecord.CLASS_IMPORTANT
		chunk.add(effect)
		trace.record(effect.to_trace_record())

		# queue the visual (deferred/skipped by the presentation policy)
		visuals.enqueue(EQPresentationEvent.new(foe, Vector2.ZERO, effect.classification))

		# sweep point: the foe's reactions evaluate the resolved effect
		var view := {"kind": &"hit", "source": attacker, "target": foe, "tags": [&"damage"]}
		for fired in trigger.on_event_resolved(view, manager.runtime().scheduler.current_tick):
			trace.record({"kind": "reaction_fired", "owner": String(fired.actor_id), "vs": String(attacker)})

		# close the turn: EQManager.finish_action clears the turn_ready suspend AND
		# delegates to the policy to schedule the next ready turn. (Driving
		# policy.wait_close on the runtime directly would bypass the manager's
		# suspend — see DOGFOOD_FRICTION; that path is for the explicit-transaction
		# flow, not the manager-driven loop.)
		manager.finish_action(attacker, EQActionResult.new(100, 0))

	manager.free()
	return trace.to_jsonl()


## DOGFOOD (EQM-119) — the L2 NATURAL PATH (SEM §5.6/§6.1), contrasted with the
## hand-wired run_trace() above. The counterattack preparation is a CHECKED-IN
## .tres (zero GDScript in the declaration: 3 uses OR 5 ticks, whichever comes
## first); the game registers the named effect once and submits the loaded
## asset. Closure is explained by the trace, never silent:
##   closed_by: reaction_count  — the 3rd use consumed the preparation
##   closed_by: duration        — an unused preparation timed out (its expiry EVENT)
##   closed_by: already_closed  — a stale expiry after a count-closure
static func run_l2_trace() -> String:
	var rr := EQReservationRuntime.new()
	rr.runtime.emit_engine_diagnostics = false
	rr.runtime.register_actor(&"hero")
	rr.runtime.register_actor(&"orc")
	# declared linkage: the .tres names the effect; the game wires it ONCE.
	rr.runtime.register_effect(&"counterattack", func(view: Dictionary) -> Array:
		var rec := EQEffectRecord.new(&"damage", &"orc", &"hp", -6)
		rec.source = StringName(view["source"])
		rec.tags = [&"damage", &"counter"]
		rec.classification = EQEffectRecord.CLASS_IMPORTANT
		return [rec])
	var counter_cond := EQCondition.new()
	counter_cond.match_target = &"hero"
	counter_cond.require_tags = [&"damage"]

	# phase 1 — COUNT closure: three incoming hits use the preparation up.
	var prep_a = load("res://dogfood/action_resolution/counterattack_preparation.tres")
	rr.submit(EQReservation.new(&"hero", prep_a), counter_cond)
	for _hit in 3:
		var atk := EQActionDefinition.new()
		atk.kind = EQActionDefinition.Kind.IMMEDIATE
		atk.tags = [&"damage"]
		var attack := EQReservation.new(&"orc", atk)
		attack.target_id = &"hero"
		rr.submit(attack)
		rr.resolve_next()  # the hit resolves -> the counter fires (SCHEDULED, §6.2)
		rr.resolve_next()  # the scheduled counter resolves through the named effect

	# phase 2 — DURATION closure: a fresh preparation is armed and never used;
	# its expiry EVENT closes it at armed_at + 5 (Q40 — never a silent removal).
	var prep_b = load("res://dogfood/action_resolution/counterattack_preparation.tres").duplicate()
	rr.submit(EQReservation.new(&"hero", prep_b), counter_cond)
	rr.resolve_next()  # drains the expiry events (already_closed for A, duration for B)
	return rr.runtime.trace_jsonl()


func _ready() -> void:
	print(run_trace(8))
