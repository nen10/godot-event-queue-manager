extends Node
## LEARNING-PATH SAMPLE — not production. A minimal energy/threshold battle built
## with the public Event Queue Manager API only (EQManager / EQConfig /
## EQEnergyPolicy / EQActionResult). Each actor accrues energy by speed and acts
## when it crosses the threshold; carried energy (post-spend) is user-inspectable.
## A real game creates its own EQConfig — this is not a bundled default
## (UX_PATH_REDUCTION). Verified headless against a golden by
## test_project/tests/debug_scene/test_energy_battle_demo.gd.

const EQManager := preload("res://addons/event_queue_manager/runtime/eq_manager.gd")
const EQConfig := preload("res://addons/event_queue_manager/resources/eq_config.gd")
const EQEnergyPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_energy_policy.gd")
const EQActionResult := preload("res://addons/event_queue_manager/runtime/eq_action_result.gd")
const EQPrediction := preload("res://addons/event_queue_manager/runtime/eq_prediction.gd")


static func build() -> EQManager:
	var config := EQConfig.new()
	config.policy = EQEnergyPolicy.new()
	var manager := EQManager.new()
	manager.configure(config)
	manager.register_actor(&"hero").data["speed"] = 15
	manager.register_actor(&"rogue").data["speed"] = 22
	manager.register_actor(&"golem").data["speed"] = 8
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
	print("[energy_battle] next 3 (prediction): ", EQPrediction.predict_turns(manager, 3))
	for _i in 6:
		var e := manager.step()
		if e == null:
			break
		print("[energy_battle] tick=%d turn=%s" % [manager.runtime().scheduler.current_tick, e.actor_id])
		manager.finish_action(e.actor_id, EQActionResult.new(0, 0))
	manager.free()
