@tool
extends EditorPlugin
## Event Queue Manager editor entry point.
##
## Registers the scene-local EQManager node type. Editor docks (timeline
## preview, config inspector, debug inspector, template generator) are added in
## later phases.

const _MANAGER_SCRIPT := preload("runtime/eq_manager.gd")


func _enter_tree() -> void:
	add_custom_type("EQManager", "Node", _MANAGER_SCRIPT, null)


func _exit_tree() -> void:
	remove_custom_type("EQManager")
