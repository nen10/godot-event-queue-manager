extends RefCounted
## EQM-087 — state matrix assertions (UI_LAYOUT_METRIC_TEST_POLICY §5.8/§5.9/§5.11
## against docs/ui/EDITOR_STATE_MATRIX.md). Projection integrity (§5.9) is the
## central gate: ui_order MUST equal the headless prediction; a mis-ordered tree
## MUST be caught. Boolean-text state MUST be caught.

static func run(t, results: Array) -> void:
	# projection integrity holds on well-formed scenarios (ui_order == prediction)
	for name in ["good_small_queue_3_actors", "good_large_queue_windowed", "good_tie_break_same_tick"]:
		var r: Dictionary = _find(results, name, "normal")
		t.ok(not _has(r, "projection_integrity", "P0"), "%s: ui_order == prediction (projection holds)" % name)

	# windowing: 500 predicted, 10 rendered, still equal to the first 10 -> no violation
	var large: Dictionary = _find(results, "good_large_queue_windowed", "normal")
	t.ok(not large.is_empty(), "large-queue scenario evaluated")
	t.ok(not _has(large, "projection_integrity", "P0"), "windowed large queue keeps projection integrity")

	# a mis-ordered timeline MUST raise the projection P0 (non-tautology)
	var misorder: Dictionary = _find(results, "broken_projection_misorder", "normal")
	t.ok(_has(misorder, "projection_integrity", "P0"), "mis-ordered rows -> projection_integrity P0")

	# boolean state rendered as text MUST raise a modality P0
	var bool_text: Dictionary = _find(results, "broken_boolean_text_state", "normal")
	t.ok(_has(bool_text, "modality", "P0"), "boolean state as text -> modality P0")

	# clean config-empty state has no P0 (no contradiction, icon+tooltip status)
	var empty: Dictionary = _find(results, "good_no_config_selected", "normal")
	t.eq(_count(empty, "P0"), 0, "no_config_selected well-formed -> 0 P0")


static func _find(results: Array, name: String, dock_class: String) -> Dictionary:
	for r in results:
		if r["name"] == name and r["dock_class"] == dock_class:
			return r
	return {}


static func _has(r: Dictionary, metric: String, severity: String) -> bool:
	for f in r.get("findings", []):
		if f["metric"] == metric and f["severity"] == severity:
			return true
	return false


static func _count(r: Dictionary, severity: String) -> int:
	var n := 0
	for f in r.get("findings", []):
		if f["severity"] == severity:
			n += 1
	return n
