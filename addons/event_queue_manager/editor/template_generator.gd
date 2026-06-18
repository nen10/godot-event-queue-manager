class_name EQTemplateGenerator
extends VBoxContainer
## Template generator (EQM-092) — the template_generator surface. Authors the
## Action Resolution Turn-Based demo as PROJECT ASSETS, never a hidden sample
## default. Two explicit steps (docs/ui/EDITOR_UI_CONTRACT.md §5, §5.10):
##   generate()              -> a SAMPLE artifact (scratch), badged, NOT in project
##   duplicate_to_project()  -> the explicit bridge that writes the project assets
## A sample never silently satisfies a production config slot — only the duplicate
## step does. The generated demo uses the reservation/trigger/presentation APIs.

const DemoBattle := preload("res://demos/action_resolution/demo_battle.gd")
const EQConfig := preload("res://addons/event_queue_manager/resources/eq_config.gd")

const SURFACE := &"template_generator"
const TEMPLATE_ID := &"action_resolution_turn_based"
const DEMO_ENTRY := "res://demos/action_resolution/demo_battle.gd"

var _summary: Label
var _generate_btn: Button
var _duplicate_btn: Button
var _sample_badge: TextureRect

var _manifest: Dictionary = {}
var _is_sample: bool = false


func _init() -> void:
	set_meta(&"ui_metric_id", &"template_generator_root")
	set_meta(&"ui_metric_role", &"screen_root")
	set_meta(&"ui_metric_surface", SURFACE)

	var section := Label.new()
	section.text = "Action Resolution (Turn-Based)"
	section.set_meta(&"ui_metric_role", &"section")
	section.set_meta(&"ui_metric_surface", SURFACE)
	add_child(section)

	var preview := HBoxContainer.new()
	_summary = Label.new()
	_summary.text = "reservation · trigger · presentation"
	_summary.set_meta(&"ui_metric_role", &"summary")
	_summary.set_meta(&"ui_metric_surface", SURFACE)
	preview.add_child(_summary)
	_sample_badge = TextureRect.new()
	_sample_badge.texture = PlaceholderTexture2D.new()
	_sample_badge.custom_minimum_size = Vector2(16, 16)
	_sample_badge.tooltip_text = "sample (not in project)"
	_sample_badge.set_meta(&"ui_metric_role", &"badge_sample")
	_sample_badge.set_meta(&"ui_metric_surface", SURFACE)
	_sample_badge.visible = false
	preview.add_child(_sample_badge)
	add_child(preview)

	_generate_btn = Button.new()
	_generate_btn.text = "Generate"
	_generate_btn.set_meta(&"ui_metric_role", &"primary_action")
	_generate_btn.set_meta(&"ui_metric_surface", SURFACE)
	_generate_btn.set_meta(&"ui_action_id", &"template.generate")
	_generate_btn.set_meta(&"ui_action_effect", "produce the sample artifact in scratch")
	_generate_btn.pressed.connect(func(): generate())
	add_child(_generate_btn)

	_duplicate_btn = Button.new()
	_duplicate_btn.text = "Duplicate To Project"
	_duplicate_btn.set_meta(&"ui_metric_role", &"secondary_action")
	_duplicate_btn.set_meta(&"ui_metric_surface", SURFACE)
	_duplicate_btn.set_meta(&"ui_action_id", &"template.duplicate_to_project")
	_duplicate_btn.set_meta(&"ui_action_effect", "explicit bridge: write the demo assets into the project")
	_duplicate_btn.disabled = true
	_duplicate_btn.tooltip_text = "generate a sample first"
	_duplicate_btn.pressed.connect(func(): duplicate_to_project())
	add_child(_duplicate_btn)


## Produce the SAMPLE artifact (scratch, in memory). Badged; does not enter the
## project. Returns the manifest.
func generate() -> Dictionary:
	_manifest = {
		"template_id": String(TEMPLATE_ID),
		"demo_entry": DEMO_ENTRY,
		"uses_apis": _uses_apis(),
		"assets": [
			{"path": DEMO_ENTRY, "kind": "demo_script", "sample": true},
			{"path": "<scratch>/action_resolution_config.tres", "kind": "config", "sample": true},
		],
		"sample": true,
	}
	_is_sample = true
	set_meta(&"ui_is_sample", true)
	_sample_badge.visible = true
	_duplicate_btn.disabled = false
	_duplicate_btn.tooltip_text = ""
	return _manifest.duplicate(true)


## The explicit bridge to production: writes the demo's config into the project at
## `target_dir` and returns the production manifest (sample = false). Requires a
## prior generate() (no silent path from sample to production).
func duplicate_to_project(target_dir: String = "user://eq_demo_action_resolution") -> Dictionary:
	if not _is_sample:
		return {}  # nothing generated — no silent production default
	DirAccess.make_dir_recursive_absolute(target_dir)
	var config_path: String = target_dir.path_join("action_resolution_config.tres")
	var config: EQConfig = DemoBattle.build_config()
	ResourceSaver.save(config, config_path)
	_manifest = {
		"template_id": String(TEMPLATE_ID),
		"demo_entry": DEMO_ENTRY,
		"uses_apis": _uses_apis(),
		"assets": [
			{"path": DEMO_ENTRY, "kind": "demo_script", "sample": false},
			{"path": config_path, "kind": "config", "sample": false},
		],
		"sample": false,
	}
	_is_sample = false
	set_meta(&"ui_is_sample", false)
	_sample_badge.visible = false
	return _manifest.duplicate(true)


func manifest() -> Dictionary:
	return _manifest.duplicate(true)


func is_sample() -> bool:
	return _is_sample


## A sample artifact NEVER satisfies a production config slot — only an artifact
## that has been duplicated into the project does.
func satisfies_production_slot() -> bool:
	return not _manifest.is_empty() and not _is_sample


func _uses_apis() -> Array:
	var out: Array = []
	for api in DemoBattle.USES_APIS:
		out.append(String(api))
	return out
