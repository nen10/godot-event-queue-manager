extends Node
## LEARNING-PATH SAMPLE — not production. A minimal Tactics Ogre / FFT-style
## wait-turn battle built with the public API only (EQManager / EQConfig /
## EQWaitTurnPolicy / EQActionResult). A real game creates its own EQConfig; this
## is not a hidden default (UX_PATH_REDUCTION). See docs/manual/quickstart.md.
##
## Verified headless by test_project/tests/debug_scene/test_wait_turn_demo.gd
## against a golden trace.

const EQManager := preload("res://addons/event_queue_manager/runtime/eq_manager.gd")
const EQConfig := preload("res://addons/event_queue_manager/resources/eq_config.gd")
const EQWaitTurnPolicy := preload("res://addons/event_queue_manager/resources/policies/eq_wait_turn_policy.gd")
const EQActionResult := preload("res://addons/event_queue_manager/runtime/eq_action_result.gd")


static func build() -> EQManager:
	var config := EQConfig.new()
	config.policy = EQWaitTurnPolicy.new()
	var manager := EQManager.new()
	manager.configure(config)
	# wait = initial readiness (lower acts sooner); agility breaks equal-wait ties.
	_unit(manager, &"knight", 6, 4)
	_unit(manager, &"archer", 4, 7)
	_unit(manager, &"golem", 9, 2)
	manager.seed()
	return manager


static func _unit(manager: EQManager, id: StringName, wait: int, agility: int) -> void:
	var s := manager.register_actor(id)
	s.data["wait"] = wait
	s.data["agility"] = agility


## Runs `turns` turns with normal actions (each sets a normal next wait) and
## returns the canonical trace.
static func run_trace(turns: int) -> String:
	var manager := build()
	manager.advance_frame(turns)
	var jsonl := manager.trace_jsonl()
	manager.free()
	return jsonl


func _ready() -> void:
	var manager := build()
	for _i in 6:
		var e := manager.step()
		if e == null:
			break
		print("[wait_turn] tick=%d acts=%s" % [manager.runtime().scheduler.current_tick, e.actor_id])
		manager.finish_action(e.actor_id, EQActionResult.new(0, 0))
	manager.free()
