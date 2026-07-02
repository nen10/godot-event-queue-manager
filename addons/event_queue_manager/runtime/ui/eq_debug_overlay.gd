class_name EQDebugOverlay
extends VBoxContainer
## Opt-in consumer debug overlay (EQM-083): lets a developer inspect the live
## order and the "why next" reason in their own game. Projection-first like the
## HUD — it renders an injected order + explanation data (explanation-as-data,
## EQM-091 / EQTrace decided_by), never recomputing order on the UI side.
##
## set_state(order, explanations): `order` is the live actor/turn order;
## `explanations[i]` is a Dictionary such as {"decided_by": "priority",
## "actor": "hero"} describing why entry i is where it is.

var _order: Array = []
var _explanations: Array = []


func set_state(order: Array, explanations: Array = []) -> void:
	_order = order.duplicate()
	_explanations = explanations.duplicate()
	_rebuild()


func order() -> Array:
	return _order.duplicate()


func explanation_for(index: int) -> Dictionary:
	if index >= 0 and index < _explanations.size():
		return _explanations[index]
	return {}


func rows() -> Array:
	var out: Array = []
	for c in get_children():
		if c.has_meta(&"ui_metric_role") and c.get_meta(&"ui_metric_role") == &"debug_row":
			out.append(c)
	return out


## Race-candidate group rows (EQM-116, SEM §5.2 game-dev debug display):
## consecutive entries whose explanation carries the same "race_group" are
## aggregated into ONE candidate-group row, so the same effect racing as
## several events never reads as the effect happening multiple times.
func group_rows() -> Array:
	var out: Array = []
	for c in get_children():
		if c.has_meta(&"ui_metric_role") and c.get_meta(&"ui_metric_role") == &"race_group_row":
			out.append(c)
	return out


func _rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.free()
	var i := 0
	while i < _order.size():
		var exp := explanation_for(i)
		var gid := String(exp.get("race_group", ""))
		if gid != "":
			var members := 0
			while i + members < _order.size() and String(explanation_for(i + members).get("race_group", "")) == gid:
				members += 1
			var group_row := HBoxContainer.new()
			group_row.set_meta(&"ui_metric_id", StringName("race_group_row_%d" % i))
			group_row.set_meta(&"ui_metric_role", &"race_group_row")
			group_row.set_meta(&"ui_metric_surface", &"debug_overlay")
			var pos := Label.new()
			pos.text = str(i + 1)
			group_row.add_child(pos)
			var label := Label.new()
			label.text = "%s (%d candidates)" % [gid, members]
			label.set_meta(&"ui_metric_id", StringName("race_group_row_%d_label" % i))
			label.set_meta(&"ui_metric_role", &"explanation")
			group_row.add_child(label)
			add_child(group_row)
			i += members
			continue
		var row := HBoxContainer.new()
		row.set_meta(&"ui_metric_id", StringName("debug_row_%d" % i))
		row.set_meta(&"ui_metric_role", &"debug_row")
		row.set_meta(&"ui_metric_surface", &"debug_overlay")
		var pos := Label.new()
		pos.text = str(i + 1)
		row.add_child(pos)
		var actor := Label.new()
		actor.text = String(_order[i])
		row.add_child(actor)
		# why-next: explanation-as-data (rendered, not re-derived in the UI)
		var why := Label.new()
		var exp2 := explanation_for(i)
		why.text = "why=%s" % String(exp2.get("decided_by", &"")) if not exp2.is_empty() else ""
		why.set_meta(&"ui_metric_id", StringName("debug_row_%d_why" % i))
		why.set_meta(&"ui_metric_role", &"explanation")
		row.add_child(why)
		add_child(row)
		i += 1
