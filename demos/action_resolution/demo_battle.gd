extends RefCounted
## Action Resolution Turn-Based demo (EQM-092) — the shipped, public-API-only
## slice the template generator points at. Productized from the EQM-084 dogfood:
## AP-recovery turns (EQActionResolutionPolicy via EQManager), an armed counter
## reaction (EQTriggerEngine + EQCondition on a reaction-preparation reservation),
## simulation effects + queued/flushed visuals (EQEffectRecord / EQEffectChunk /
## EQPresentationBuffer), deterministic randomness (EQRng), one canonical trace
## (EQTrace). Uses NO runtime internals — it is the consumer's view.

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

## The addon subsystems this demo exercises (used by the template manifest/tests).
const USES_APIS: Array[StringName] = [&"reservation", &"trigger", &"presentation", &"effect", &"rng"]


## The demo's config — a concrete EQActionResolutionPolicy (never a base instance).
static func build_config() -> EQConfig:
	var config := EQConfig.new()
	config.policy = EQActionResolutionPolicy.new()
	config.tie_break = &"actor_id"
	return config


## Runs a fixed slice and returns the canonical trace (deterministic). Each ready
## turn: the attacker hits the foe (seeded EQRng roll) producing an effect record +
## a queued visual; the foe's armed counter fires on incoming damage; visuals are
## flushed at the turn boundary (presentation OUTPUT, not just enqueue).
static func run_trace(turns: int) -> String:
	var manager := EQManager.new()
	manager.configure(build_config())
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

		# simulation truth first (deterministic roll)
		var dmg: int = rng.randi_range(5, 12)
		var effect := EQEffectRecord.new(&"damage", foe, &"hp", -dmg)
		effect.source = attacker
		effect.tags = [&"damage"]
		effect.classification = EQEffectRecord.CLASS_IMPORTANT
		chunk.add(effect)
		trace.record(effect.to_trace_record())

		# queue the visual; the policy decides defer/coalesce/skip
		visuals.enqueue(EQPresentationEvent.new(foe, Vector2.ZERO, effect.classification))

		# sweep point: the foe's reactions evaluate the resolved effect
		var view := {"kind": &"hit", "source": attacker, "target": foe, "tags": [&"damage"]}
		for fired in trigger.on_event_resolved(view, manager.runtime().scheduler.current_tick):
			trace.record({"kind": "reaction_fired", "owner": String(fired.actor_id), "vs": String(attacker)})

		# flush visuals at the turn boundary — presentation OUTPUT (neutral: never
		# writes back to the simulation/effect trace).
		visuals.flush()
		trace.record({"kind": "presentation_flush", "shown": visuals.flushed().size()})

		# close the turn (manager-driven loop — see DOGFOOD_FRICTION F1).
		manager.finish_action(attacker, EQActionResult.new(100, 0))

	manager.free()
	return trace.to_jsonl()
