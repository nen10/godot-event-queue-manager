extends RefCounted
## EQM-087 — interaction/leakage assertions (UI_LAYOUT_METRIC_TEST_POLICY
## §5.5/§5.6). No-op buttons and debug leakage MUST be caught; well-formed
## actions (pressed connection + ui_action_id) MUST NOT be flagged.

static func run(t, results: Array) -> void:
	# well-formed action buttons are not flagged as no-op
	for name in ["good_small_queue_3_actors", "good_tie_break_same_tick"]:
		var r: Dictionary = _find(results, name, "normal")
		t.ok(not _has(r, "noop_button", "P0"), "%s: wired buttons are not no-op" % name)

	# a button with no pressed connection / no ui_action_id MUST be flagged
	var noop: Dictionary = _find(results, "broken_noop_button", "normal")
	t.ok(_has(noop, "noop_button", "P0"), "unwired button -> noop_button P0 (non-tautology)")

	# debug text leak (res:// path in a visible label) MUST be flagged
	var leak: Dictionary = _find(results, "broken_debug_leak", "normal")
	t.ok(_has(leak, "debug_leakage", "P0"), "res:// in a visible label -> debug_leakage P0")

	# float tick display MUST be flagged (float ordering must never reach the UI)
	var float_tick: Dictionary = _find(results, "broken_float_tick", "normal")
	t.ok(_has(float_tick, "debug_leakage", "P0"), "float tick text -> debug_leakage P0")

	# well-formed timeline has no debug leakage
	var clean: Dictionary = _find(results, "good_small_queue_3_actors", "normal")
	t.ok(not _has(clean, "debug_leakage", "P0"), "well-formed timeline -> no debug leakage")


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
