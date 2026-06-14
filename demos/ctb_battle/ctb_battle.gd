extends Node
## LEARNING-PATH SAMPLE — not production. A minimal Charge Time Battle built
## with the public Event Queue Manager API only (EQManager / EQConfig /
## EQCTBPolicy / EQActionResult / EQPrediction). It never touches runtime
## internals and is not a hidden default for any project (UX_PATH_REDUCTION):
## a real game creates its own EQConfig. See docs/manual/quickstart.md.
##
## Play this scene to print a few turns; the same logic is verified headless by
## test_project/tests/debug_scene/test_ctb_battle_demo.gd against a golden trace.

const EQManager := preload("res://addons/event_queue_manager/runtime/eq_manager.gd")
const EQConfig := preload("res://addons/event_queue_manager/resources/eq_config.gd")
const EQCTBPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_ctb_policy.gd")
const EQActionResult := preload("res://addons/event_queue_manager/runtime/eq_action_result.gd")
const EQPrediction := preload("res://addons/event_queue_manager/runtime/eq_prediction.gd")


## Builds a CTB-configured manager with three combatants (project-created config,
## not a bundled default).
static func build() -> EQManager:
	var config := EQConfig.new()
	config.policy = EQCTBPolicy.new()
	var manager := EQManager.new()
	manager.configure(config)
	manager.register_actor(&"hero").data["speed"] = 15
	manager.register_actor(&"rogue").data["speed"] = 22
	manager.register_actor(&"golem").data["speed"] = 8
	manager.seed()
	return manager


## Runs `turns` turns with normal actions and returns the canonical trace.
static func run_trace(turns: int) -> String:
	var manager := build()
	manager.advance_frame(turns)
	var jsonl := manager.trace_jsonl()
	manager.free()
	return jsonl


func _ready() -> void:
	# Playing the scene prints the first turns and the next-3 prediction.
	var manager := build()
	print("[ctb_battle] next 3 (prediction): ", EQPrediction.predict_turns(manager, 3))
	for _i in 6:
		var e := manager.step()
		if e == null:
			break
		print("[ctb_battle] tick=%d turn=%s" % [manager.runtime().scheduler.current_tick, e.actor_id])
		manager.finish_action(e.actor_id, EQActionResult.new(0, 0))
	manager.free()
