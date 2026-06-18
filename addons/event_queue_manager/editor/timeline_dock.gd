class_name EQTimelineDock
extends VBoxContainer
## Timeline Preview Dock (EQM-090) — a projection of injected headless state.
##
## The dock NEVER invents a sample roster: state arrives through set_preview().
## Three states (docs/ui/EDITOR_STATE_MATRIX.md):
##   config == null            -> empty_state ("Select a config")
##   config.validate() errors  -> validation rows (icon + message), no timeline
##   valid                     -> next-N turns from EQPrediction (order projection)
##
## The displayed order equals the headless prediction (projection integrity, the
## central UI gate). The editor EditorResourcePicker is a thin adapter that calls
## set_preview; headless tests inject config + runtime directly. Every control
## carries ui_metric_id/role/surface metadata for the layout metric harness.

const EQPrediction := preload("res://addons/event_queue_manager/runtime/eq_prediction.gd")

const SURFACE := &"timeline_dock"
const DEFAULT_NEXT_N := 10

var _config: EQConfig = null
var _runtime = null
var _next_n: int = DEFAULT_NEXT_N

var _count_badge: Label
var _status_icon: TextureRect
var _list: VBoxContainer
var _empty: Label
var _validation_list: VBoxContainer
var _refresh_btn: Button

var _order: Array = []          # rendered actor_ids, top -> bottom
var _validation_messages: Array = []


func _init() -> void:
	set_meta(&"ui_metric_id", &"timeline_dock_root")
	set_meta(&"ui_metric_role", &"screen_root")
	set_meta(&"ui_metric_surface", SURFACE)
	_build_static()


func _build_static() -> void:
	# summary: count badge + freshness status icon (non-text modality)
	var summary := HBoxContainer.new()
	summary.set_meta(&"ui_metric_id", &"timeline_summary")
	summary.set_meta(&"ui_metric_role", &"summary")
	summary.set_meta(&"ui_metric_surface", SURFACE)
	_count_badge = Label.new()
	_count_badge.set_meta(&"ui_metric_id", &"timeline_count_badge")
	_count_badge.set_meta(&"ui_metric_role", &"badge_count")
	_count_badge.set_meta(&"ui_metric_surface", SURFACE)
	summary.add_child(_count_badge)
	_status_icon = TextureRect.new()
	_status_icon.texture = PlaceholderTexture2D.new()
	_status_icon.custom_minimum_size = Vector2(16, 16)
	_status_icon.set_meta(&"ui_metric_id", &"timeline_status_icon")
	_status_icon.set_meta(&"ui_metric_role", &"status_icon")
	_status_icon.set_meta(&"ui_metric_surface", SURFACE)
	summary.add_child(_status_icon)
	add_child(summary)

	# empty state (shown when no config selected — never a sample default)
	_empty = Label.new()
	_empty.text = "Select a config"
	_empty.set_meta(&"ui_metric_id", &"timeline_empty_state")
	_empty.set_meta(&"ui_metric_role", &"empty_state")
	_empty.set_meta(&"ui_metric_surface", SURFACE)
	add_child(_empty)

	# validation list (shown when config is invalid)
	_validation_list = VBoxContainer.new()
	_validation_list.set_meta(&"ui_metric_id", &"timeline_validation_list")
	_validation_list.set_meta(&"ui_metric_role", &"validation_list")
	_validation_list.set_meta(&"ui_metric_surface", SURFACE)
	add_child(_validation_list)

	# timeline list (the projected order)
	_list = VBoxContainer.new()
	_list.set_meta(&"ui_metric_id", &"timeline_list")
	_list.set_meta(&"ui_metric_role", &"timeline_list")
	_list.set_meta(&"ui_metric_surface", SURFACE)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_list)

	# primary action: refresh prediction
	_refresh_btn = Button.new()
	_refresh_btn.text = "Refresh"
	_refresh_btn.set_meta(&"ui_metric_id", &"timeline_refresh")
	_refresh_btn.set_meta(&"ui_metric_role", &"primary_action")
	_refresh_btn.set_meta(&"ui_metric_surface", SURFACE)
	_refresh_btn.set_meta(&"ui_action_id", &"timeline.refresh_prediction")
	_refresh_btn.set_meta(&"ui_action_effect", "rebuild prediction from current snapshot")
	_refresh_btn.pressed.connect(_on_refresh_pressed)
	add_child(_refresh_btn)

	_apply_empty_state()


## Inject the preview state. `runtime` is an EQRuntime whose config carries the
## ordering policy; `config` is validated for the unset/invalid states.
func set_preview(config: EQConfig, runtime, next_n: int = DEFAULT_NEXT_N) -> void:
	_config = config
	_runtime = runtime
	_next_n = maxi(1, next_n)
	_rebuild()


## Rendered order (actor_ids, top -> bottom). Equals the headless prediction.
func order() -> Array:
	return _order.duplicate()


func is_empty_state() -> bool:
	return _empty.visible


func is_validation_state() -> bool:
	return _validation_list.visible and not _validation_list.get_children().is_empty()


func validation_messages() -> Array:
	return _validation_messages.duplicate()


func row_count() -> int:
	return _list.get_child_count()


func _on_refresh_pressed() -> void:
	_rebuild()


func _rebuild() -> void:
	_clear(_list)
	_clear(_validation_list)
	_order.clear()
	_validation_messages.clear()

	if _config == null:
		_apply_empty_state()
		return

	var validation: EQValidation = _config.validate()
	if validation != null and not validation.is_valid():
		_apply_validation_state(validation)
		return

	_apply_order_state()


func _apply_empty_state() -> void:
	_empty.visible = true
	_validation_list.visible = false
	_list.visible = false
	_count_badge.text = "0"
	_status_icon.tooltip_text = "no config selected"


func _apply_validation_state(validation: EQValidation) -> void:
	_empty.visible = false
	_validation_list.visible = true
	_list.visible = false
	_status_icon.tooltip_text = "config invalid"
	for issue in validation.errors():
		var msg: String = _issue_message(issue)
		_validation_messages.append(msg)
		_validation_list.add_child(_make_validation_row(msg))
	_count_badge.text = "0"


func _apply_order_state() -> void:
	_empty.visible = false
	_validation_list.visible = false
	_list.visible = true
	_status_icon.tooltip_text = "prediction fresh"
	var entries: Array = EQPrediction.predict_entries(_runtime, _next_n)
	for i in entries.size():
		var actor_id: StringName = entries[i]["actor_id"]
		var tick: int = int(entries[i]["tick"])
		_order.append(actor_id)
		_list.add_child(_make_row(i, actor_id, tick))
	_count_badge.text = str(entries.size())


func _make_row(index: int, actor_id: StringName, tick: int) -> Control:
	var hb := HBoxContainer.new()
	hb.set_meta(&"ui_metric_id", StringName("timeline_row_%d" % index))
	hb.set_meta(&"ui_metric_role", &"timeline_row")
	hb.set_meta(&"ui_metric_surface", SURFACE)
	hb.set_meta(&"ui_entry_id", String(actor_id))

	var order_index := Label.new()
	order_index.text = str(index + 1)
	order_index.custom_minimum_size = Vector2(24, 0)
	order_index.set_meta(&"ui_metric_role", &"order_index")
	hb.add_child(order_index)

	var tick_badge := Label.new()
	tick_badge.text = str(tick)  # integer tick — float ordering never reaches the UI
	tick_badge.custom_minimum_size = Vector2(32, 0)
	tick_badge.set_meta(&"ui_metric_role", &"tick_badge")
	hb.add_child(tick_badge)

	var actor_label := Label.new()
	actor_label.text = String(actor_id)
	actor_label.custom_minimum_size = Vector2(80, 0)
	actor_label.clip_text = true
	actor_label.set_meta(&"ui_metric_role", &"actor_label")
	hb.add_child(actor_label)

	var action_label := Label.new()
	action_label.text = "turn"
	action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_label.clip_text = true
	action_label.set_meta(&"ui_metric_role", &"action_label")
	hb.add_child(action_label)
	return hb


func _make_validation_row(message: String) -> Control:
	var hb := HBoxContainer.new()
	hb.set_meta(&"ui_metric_role", &"validation_row")
	hb.set_meta(&"ui_metric_surface", SURFACE)
	var icon := TextureRect.new()
	icon.texture = PlaceholderTexture2D.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.tooltip_text = message
	icon.set_meta(&"ui_metric_role", &"status_icon")
	hb.add_child(icon)
	var label := Label.new()
	label.text = message
	label.clip_text = true
	label.set_meta(&"ui_metric_role", &"validation_message")
	hb.add_child(label)
	return hb


func _issue_message(issue) -> String:
	if issue is Dictionary:
		return String(issue.get("message", issue.get("code", "invalid")))
	if typeof(issue) == TYPE_STRING or typeof(issue) == TYPE_STRING_NAME:
		return String(issue)
	return str(issue)


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
