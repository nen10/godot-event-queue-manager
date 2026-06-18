class_name EQTimelineHud
extends VBoxContainer
## Player-facing runtime timeline HUD (EQM-083). Projection-first: it renders an
## INJECTED prediction verbatim and never recomputes order on the UI side
## (UI_TESTABILITY_POLICY L4 projection integrity). Order/state use non-text
## modality (a position badge + a stale icon) so they are colorblind/screen-
## reader safe; labels are localizable. While presentation is deferred the HUD
## shows an explicit stale state — never a silent guess.
##
## set_state(order, stale) is the only render input (pure injection, headless-
## testable). bind(manager, depth) is a convenience that re-injects the
## prediction on queue_changed — the prediction (EQM-033) is the headless source
## of truth, not a UI-side re-sort.

const EQPrediction := preload("../eq_prediction.gd")

var _order: Array = []
var _stale: bool = false
var _stale_indicator: Control
var _manager = null
var _depth: int = 5


func _init() -> void:
	_stale_indicator = HBoxContainer.new()
	_stale_indicator.set_meta(&"ui_metric_id", &"timeline_stale_indicator")
	_stale_indicator.set_meta(&"ui_metric_role", &"stale_indicator")
	_stale_indicator.set_meta(&"ui_metric_surface", &"timeline_hud")
	var icon := Label.new()  # non-text-color modality: a glyph badge, not just colour
	icon.text = "⏳"     # ⏳
	icon.set_meta(&"ui_metric_id", &"timeline_stale_icon")
	_stale_indicator.add_child(icon)
	var label := Label.new()
	label.text = "EQ_TIMELINE_STALE"  # localizable key (tr() at display)
	_stale_indicator.add_child(label)
	add_child(_stale_indicator)
	_stale_indicator.visible = false


## The only render input: an injected order (actor_ids/labels) and the deferred-
## presentation flag. Rebuilds the projection; never touches a scheduler/policy.
func set_state(order: Array, stale: bool = false) -> void:
	_order = order.duplicate()
	_stale = stale
	_rebuild()


## Optional convenience: re-inject the prediction whenever the queue changes.
## Uses EQPrediction (the headless source), not a UI-side recomputation.
func bind(manager, depth: int = 5) -> void:
	_manager = manager
	_depth = depth
	if manager.has_signal(&"queue_changed"):
		manager.queue_changed.connect(_on_queue_changed)
	refresh()


func refresh() -> void:
	if _manager != null:
		set_state(EQPrediction.predict_turns(_manager.runtime(), _depth), _stale)


func set_stale(stale: bool) -> void:
	set_state(_order, stale)


## Projected order (== the injected order; for projection-integrity tests).
func order() -> Array:
	return _order.duplicate()


func is_stale() -> bool:
	return _stale


## Whether the HUD is showing the explicit empty state.
func is_empty_state() -> bool:
	return _order.is_empty()


## The row Controls (each carries ui_metric_id / ui_metric_role metadata).
func rows() -> Array:
	var out: Array = []
	for c in get_children():
		if c.has_meta(&"ui_metric_role") and c.get_meta(&"ui_metric_role") == &"turn_row":
			out.append(c)
	return out


func _on_queue_changed() -> void:
	refresh()


func _rebuild() -> void:
	for c in get_children():
		if c == _stale_indicator:
			continue
		remove_child(c)
		c.free()
	_stale_indicator.visible = _stale
	if _order.is_empty():
		var empty := Label.new()
		empty.text = "EQ_TIMELINE_EMPTY"  # explicit empty state (localizable), not a silent fallback
		empty.set_meta(&"ui_metric_id", &"timeline_empty_state")
		empty.set_meta(&"ui_metric_role", &"empty_state")
		add_child(empty)
		return
	for i in _order.size():
		add_child(_make_row(i, _order[i]))


func _make_row(index: int, entry) -> Control:
	var row := HBoxContainer.new()
	row.set_meta(&"ui_metric_id", StringName("timeline_row_%d" % index))
	row.set_meta(&"ui_metric_role", &"turn_row")
	row.set_meta(&"ui_metric_surface", &"timeline_hud")
	# Position badge: a NUMBER (non-text-colour modality), not a colour cue.
	var badge := Label.new()
	badge.text = str(index + 1)
	badge.set_meta(&"ui_metric_id", StringName("timeline_row_%d_badge" % index))
	badge.set_meta(&"ui_metric_role", &"position_badge")
	row.add_child(badge)
	# Actor label: localizable text (the value is the actor id).
	var label := Label.new()
	label.text = String(entry)
	label.set_meta(&"ui_metric_id", StringName("timeline_row_%d_label" % index))
	row.add_child(label)
	return row
