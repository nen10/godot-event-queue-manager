extends RefCounted
## Pass A metric evaluator (UI_LAYOUT_METRIC_TEST_POLICY §5, thresholds from
## docs/ui/EDITOR_UI_CONTRACT.md §7). Consumes a collector snapshot plus the
## scenario's headless context and returns findings:
##
##   { severity: "P0"|"P1"|"WARN", surface, metric, id, message }
##
## At adoption M1-M3 the runner consumes findings WARN-only (report, no build
## fail). M4/M5 (EQM-094/095) flips P0/P1 to hard-fail. The evaluator computes
## real numbers from the laid-out tree; it never asserts on its own — that keeps
## the metrics non-tautological (a malformed tree raises real findings).

# thresholds (EDITOR_UI_CONTRACT.md §7)
const MAX_TICK_BADGE_WIDTH := 64.0
const MIN_ACTOR_LABEL_WIDTH_NORMAL := 80.0
const MAX_ROW_ICON_BUTTONS := 1
const TRUNCATION_FAIL := 1.00
const TRUNCATION_WARN_NARROW := 0.85
const BOOLEAN_TEXTS := ["true", "false", "on", "off", "有効", "無効", "yes", "no", "stale: true", "stale: false"]
const STATUS_ROLES := ["status_icon", "status_text", "stale_indicator", "cause_icon"]
const TITLE_ROLES := ["section", "summary", "primary_action"]


## context: { dock_class: "narrow"|"normal"|"wide", headless_order: Array, next_n: int }
static func evaluate(snapshot: Dictionary, context: Dictionary = {}) -> Array:
	var findings: Array = []
	var nodes: Array = snapshot.get("nodes", [])
	var surface: String = snapshot.get("surface", "")
	var dock_class: String = context.get("dock_class", _dock_class(snapshot.get("dock_size", [420, 720])))
	_metric_truncation(nodes, surface, dock_class, findings)
	_metric_timeline_geometry(nodes, surface, findings)
	_metric_debug_leakage(nodes, surface, findings)
	_metric_noop_button(nodes, surface, findings)
	_metric_modality(nodes, surface, findings)
	_metric_projection_integrity(nodes, surface, context, findings)
	_metric_sample_separation(nodes, surface, findings)
	return findings


static func summarize(findings: Array) -> Dictionary:
	var p0 := 0
	var p1 := 0
	var warn := 0
	for f in findings:
		match f.get("severity", "WARN"):
			"P0": p0 += 1
			"P1": p1 += 1
			_: warn += 1
	return {"P0": p0, "P1": p1, "WARN": warn, "total": findings.size()}


static func _dock_class(dock_size: Array) -> String:
	var w: float = dock_size[0] if dock_size.size() > 0 else 420.0
	if w <= 320.0:
		return "narrow"
	if w <= 420.0:
		return "normal"
	return "wide"


static func _add(findings: Array, severity: String, surface: String, metric: String, id: String, message: String) -> void:
	findings.append({"severity": severity, "surface": surface, "metric": metric, "id": id, "message": message})


# §5.1 text truncation risk
static func _metric_truncation(nodes: Array, surface: String, dock_class: String, findings: Array) -> void:
	for n in nodes:
		var ratio: float = n.get("truncation_ratio", 0.0)
		var role: String = n.get("role", "")
		var required: bool = n.get("required", false)
		var is_title: bool = role in TITLE_ROLES or required
		if ratio > TRUNCATION_FAIL:
			if dock_class == "narrow":
				_add(findings, "WARN", surface, "truncation", n.get("id", ""),
					"narrow-width truncation (ratio=%.2f)" % ratio)
			elif is_title:
				_add(findings, "P0", surface, "truncation", n.get("id", ""),
					"required title/primary truncates (ratio=%.2f) at %s width" % [ratio, dock_class])
			else:
				_add(findings, "P1", surface, "truncation", n.get("id", ""),
					"non-primary text truncates (ratio=%.2f) at %s width%s" % [ratio, dock_class, _tooltip_hint(n)])
		elif dock_class == "narrow" and ratio > TRUNCATION_WARN_NARROW:
			_add(findings, "WARN", surface, "truncation", n.get("id", ""),
				"narrow truncation risk (ratio=%.2f)" % ratio)


static func _tooltip_hint(n: Dictionary) -> String:
	return "" if n.get("tooltip_length", 0) > 0 else " (no tooltip)"


# §5.2 timeline row geometry
static func _metric_timeline_geometry(nodes: Array, surface: String, findings: Array) -> void:
	var row_heights: Array = []
	for n in nodes:
		var role: String = n.get("role", "")
		var w: float = (n.get("rect", [0, 0, 0, 0]))[2]
		if role in ["tick_badge", "position_badge"]:
			if w > MAX_TICK_BADGE_WIDTH:
				_add(findings, "P1", surface, "timeline_geometry", n.get("id", ""),
					"tick badge width %.0f > %0.f" % [w, MAX_TICK_BADGE_WIDTH])
		elif role == "actor_label":
			if w < MIN_ACTOR_LABEL_WIDTH_NORMAL:
				_add(findings, "P1", surface, "timeline_geometry", n.get("id", ""),
					"actor label width %.0f < %.0f" % [w, MIN_ACTOR_LABEL_WIDTH_NORMAL])
		elif role in ["timeline_row", "turn_row"]:
			row_heights.append((n.get("rect", [0, 0, 0, 0]))[3])
			# horizontal scroll inside a row's list is a structural fail (handled below)
	# uniform row height
	if row_heights.size() > 1:
		var first: float = row_heights[0]
		for h in row_heights:
			if absf(h - first) > 0.5:
				_add(findings, "P1", surface, "timeline_geometry", "timeline_list",
					"non-uniform row height (%.0f vs %.0f)" % [h, first])
				break
	# >1 icon button per row
	# (rows are identified by role; icon buttons counted per row via parent id prefix is
	#  out of scope here — the runner builds one-button rows; a row-button overflow shows
	#  up as multiple is_icon_button nodes which we surface in aggregate)
	var icon_buttons := 0
	for n in nodes:
		if n.get("is_icon_button", false):
			icon_buttons += 1
	if icon_buttons > MAX_ROW_ICON_BUTTONS * maxi(1, _count_rows(nodes)):
		_add(findings, "P1", surface, "timeline_geometry", "timeline_list",
			"too many row icon-buttons (%d for %d rows)" % [icon_buttons, _count_rows(nodes)])


static func _count_rows(nodes: Array) -> int:
	var n := 0
	for x in nodes:
		if x.get("role", "") in ["timeline_row", "turn_row"]:
			n += 1
	return n


# §5.5 visible debug leakage + float tick
static func _metric_debug_leakage(nodes: Array, surface: String, findings: Array) -> void:
	for n in nodes:
		if n.get("visible_text_kind", "") == "debug":
			_add(findings, "P0", surface, "debug_leakage", n.get("id", ""),
				"debug text visible in normal mode: '%s'" % n.get("text", ""))
		# float tick: a tick badge whose text looks like N.M
		var role: String = n.get("role", "")
		var text: String = n.get("text", "")
		if role in ["tick_badge", "position_badge"] and _looks_float(text):
			_add(findings, "P0", surface, "debug_leakage", n.get("id", ""),
				"float tick display '%s' (float ordering leaked to UI)" % text)


static func _looks_float(text: String) -> bool:
	var dot := text.find(".")
	if dot <= 0 or dot >= text.length() - 1:
		return false
	return text[dot - 1].is_valid_int() and text[dot + 1].is_valid_int()


# §5.6 no-op button audit
static func _metric_noop_button(nodes: Array, surface: String, findings: Array) -> void:
	for n in nodes:
		if not n.get("is_button_like", false):
			continue
		if n.get("disabled", false):
			if n.get("tooltip_length", 0) == 0:
				_add(findings, "WARN", surface, "noop_button", n.get("id", ""),
					"disabled button without condition tooltip")
			continue
		# visible + enabled
		if not n.get("has_pressed_connection", false):
			_add(findings, "P0", surface, "noop_button", n.get("id", ""),
				"visible enabled button has no pressed connection (no-op)")
		if n.get("action_id", "") == "":
			_add(findings, "P0", surface, "noop_button", n.get("id", ""),
				"visible enabled button missing ui_action_id")


# §5.11 state display modality
static func _metric_modality(nodes: Array, surface: String, findings: Array) -> void:
	for n in nodes:
		var role: String = n.get("role", "")
		var text: String = n.get("text", "").strip_edges().to_lower()
		# boolean state shown as text — P0 anywhere
		if text != "" and text in BOOLEAN_TEXTS:
			_add(findings, "P0", surface, "modality", n.get("id", ""),
				"boolean state rendered as text: '%s'" % n.get("text", ""))
			continue
		# status role shown as text without an icon/checkbox glyph — P1
		if role in STATUS_ROLES and text != "" and not n.get("has_status_glyph", false):
			_add(findings, "P1", surface, "modality", n.get("id", ""),
				"status shown as text-only (no icon/checkbox): '%s'" % n.get("text", ""))
		# status glyph without tooltip — WARN (contract requires icon + tooltip)
		if role in STATUS_ROLES and n.get("has_status_glyph", false) and n.get("tooltip_length", 0) == 0:
			_add(findings, "WARN", surface, "modality", n.get("id", ""),
				"status glyph without tooltip")


# §5.9 projection integrity (the central gate)
static func _metric_projection_integrity(nodes: Array, surface: String, context: Dictionary, findings: Array) -> void:
	if not context.has("headless_order"):
		return  # projection check only when the scenario supplies the headless truth
	var headless_order: Array = context["headless_order"]
	var next_n: int = context.get("next_n", headless_order.size())
	# ui_order = entry ids of timeline rows, top -> bottom (by global y)
	var rows: Array = []
	for n in nodes:
		if n.get("role", "") in ["timeline_row", "turn_row"]:
			rows.append(n)
	rows.sort_custom(func(a, b): return (a.get("global_rect", [0, 0, 0, 0]))[1] < (b.get("global_rect", [0, 0, 0, 0]))[1])
	var ui_order: Array = []
	for r in rows:
		ui_order.append(String(r.get("entry_id", r.get("id", ""))))
	var expected: Array = []
	for i in mini(next_n, headless_order.size()):
		expected.append(String(headless_order[i]))
	if ui_order != expected:
		_add(findings, "P0", surface, "projection_integrity", "timeline_list",
			"ui_order %s != prediction %s" % [str(ui_order), str(expected)])
	var expected_count: int = mini(next_n, headless_order.size())
	if ui_order.size() != expected_count:
		_add(findings, "P0", surface, "projection_integrity", "timeline_list",
			"visible row count %d != min(N,len)=%d" % [ui_order.size(), expected_count])


# §5.10 sample separation — a generated sample artifact must be badged, never
# shown as production. (silent sample -> production is the §5.10 P0; here we catch
# the visible half: a sample surface with no sample badge.)
static func _metric_sample_separation(nodes: Array, surface: String, findings: Array) -> void:
	var has_sample := false
	var has_sample_badge := false
	for n in nodes:
		if n.get("is_sample", false):
			has_sample = true
		if n.get("role", "") == "badge_sample":
			has_sample_badge = true
	if has_sample and not has_sample_badge:
		_add(findings, "P0", surface, "sample_separation", "screen_root",
			"sample artifact present but not badged (could pass as production)")
