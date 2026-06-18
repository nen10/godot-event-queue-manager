extends RefCounted
## EQM-087 — layout metric assertions (UI_LAYOUT_METRIC_TEST_POLICY §5.1/§5.2).
## Invoked by run_ui_metrics.gd with the per-evaluation results (NOT auto-
## discovered; needs frame-flushed snapshots). Non-tautology: well-formed trees
## yield no P0, a deliberately-starved title DOES raise a truncation P0.

static func run(t, results: Array) -> void:
	# collector actually produced laid-out nodes
	var small: Dictionary = _find(results, "good_small_queue_3_actors", "normal")
	t.ok(not small.is_empty() and small["node_count"] > 0, "collector produced a laid-out node snapshot")

	# well-formed timeline scenarios carry no P0 at normal width
	for name in ["good_small_queue_3_actors", "good_large_queue_windowed", "good_tie_break_same_tick"]:
		var r: Dictionary = _find(results, name, "normal")
		t.ok(not r.is_empty(), "scenario evaluated: %s" % name)
		t.eq(_count(r, "P0"), 0, "%s well-formed -> 0 P0 findings" % name)

	# a starved required title MUST be flagged at normal width (metric can fail)
	var broken: Dictionary = _find(results, "broken_truncation_title", "normal")
	t.ok(_has(broken, "truncation", "P0"), "starved required title -> truncation P0 (non-tautology)")
	# ...and at narrow width it downgrades to WARN, not P0 (severity is width-aware)
	var broken_narrow: Dictionary = _find(results, "broken_truncation_title", "narrow")
	t.ok(not _has(broken_narrow, "truncation", "P0"), "narrow truncation is WARN, not P0")


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
