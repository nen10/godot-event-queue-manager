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


func _rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.free()
	for i in _order.size():
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
		var exp := explanation_for(i)
		why.text = "why=%s" % String(exp.get("decided_by", &"")) if not exp.is_empty() else ""
		why.set_meta(&"ui_metric_id", StringName("debug_row_%d_why" % i))
		why.set_meta(&"ui_metric_role", &"explanation")
		row.add_child(why)
		add_child(row)
