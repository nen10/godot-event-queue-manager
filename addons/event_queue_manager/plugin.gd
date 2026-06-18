@tool
extends EditorPlugin
## Event Queue Manager editor entry point.
##
## Registers the scene-local EQManager node type. The editor surfaces
## (EQTimelineDock, EQDebugInspector, EQTemplateGenerator) are implemented as
## projection-first Controls under editor/ and verified by the headless UI metric
## harness (tests/ui_headless/); interactively mounting them as editor docks
## (add_control_to_dock + EditorResourcePicker wiring) is editor-only glue tracked
## as a v1.x follow-up — it is intentionally separate from the testable Controls
## (UI_TESTABILITY_POLICY: the editor UI is a projection of injected state).

const _MANAGER_SCRIPT := preload("runtime/eq_manager.gd")


func _enter_tree() -> void:
	add_custom_type("EQManager", "Node", _MANAGER_SCRIPT, null)


func _exit_tree() -> void:
	remove_custom_type("EQManager")
