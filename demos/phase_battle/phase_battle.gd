extends Node
## LEARNING-PATH SAMPLE — not production. A team-phased turn order built with the
## public API only (EQManager / EQConfig / EQFixedRoundPolicy). Phases are
## expressed as initiative bands: the whole ally band acts before the whole enemy
## band each round (EQFixedRoundPolicy orders a round by initiative, priority DESC).
## This shows "phase" turn order without a dedicated phase policy — composition on
## the existing primitive. Verified headless against a golden by
## test_project/tests/debug_scene/test_phase_battle_demo.gd.

const EQManager := preload("res://addons/event_queue_manager/runtime/eq_manager.gd")
const EQConfig := preload("res://addons/event_queue_manager/resources/eq_config.gd")
const EQFixedRoundPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_fixed_round_policy.gd")
const EQActionResult := preload("res://addons/event_queue_manager/runtime/eq_action_result.gd")

# initiative bands: allies 100+, enemies < 50 -> all allies precede all enemies
const ALLY_BAND := 100
const ENEMY_BAND := 20


static func build() -> EQManager:
	var config := EQConfig.new()
	config.policy = EQFixedRoundPolicy.new()
	var manager := EQManager.new()
	manager.configure(config)
	# ally phase (higher initiative band)
	manager.register_actor(&"knight").data["initiative"] = ALLY_BAND + 2
	manager.register_actor(&"cleric").data["initiative"] = ALLY_BAND + 1
	# enemy phase (lower initiative band)
	manager.register_actor(&"orc").data["initiative"] = ENEMY_BAND + 2
	manager.register_actor(&"goblin").data["initiative"] = ENEMY_BAND + 1
	manager.seed()
	return manager


static func run_trace(turns: int) -> String:
	var manager := build()
	manager.advance_frame(turns)
	var jsonl := manager.trace_jsonl()
	manager.free()
	return jsonl


func _ready() -> void:
	var manager := build()
	for _i in 8:
		var e := manager.step()
		if e == null:
			break
		print("[phase_battle] tick=%d turn=%s" % [manager.runtime().scheduler.current_tick, e.actor_id])
		manager.finish_action(e.actor_id, EQActionResult.new(0, 0))
	manager.free()
