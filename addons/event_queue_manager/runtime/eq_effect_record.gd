class_name EQEffectRecord
extends RefCounted
## Simulation-side effect truth (the simulation/presentation split, Phase 8).
##
## An EffectRecord is created immediately and deterministically when an event
## resolves (a status change, damage, etc.), recorded into the canonical trace,
## and accumulated in an EQEffectChunk. It is the neutrality anchor: presentation
## may defer/skip the *visual*, but never the record. `classification`
## (important/sensed/offscreen) is supplied by the consumer/adapter — the addon
## does no spatial/sensing computation (Q12) — and the flush policy (EQM-081)
## reads it. delta is int (no float in the simulation truth).

## Sensing/importance classes (consumer-supplied; the flush policy acts on these).
const CLASS_IMPORTANT := &"important"
const CLASS_SENSED := &"sensed"
const CLASS_OFFSCREEN := &"offscreen"

var kind: StringName = &""
var source: StringName = &""
var target: StringName = &""
var stat: StringName = &""
var delta: int = 0
var tags: Array[StringName] = []
var classification: StringName = &""


func _init(p_kind: StringName = &"", p_target: StringName = &"", p_stat: StringName = &"", p_delta: int = 0) -> void:
	kind = p_kind
	target = p_target
	stat = p_stat
	delta = p_delta


## A canonical trace record (for EQTrace.record, the open-kind schema, EQM-013).
func to_trace_record() -> Dictionary:
	return {
		"kind": "effect",
		"effect_kind": String(kind),
		"source": String(source),
		"target": String(target),
		"stat": String(stat),
		"delta": delta,
		"classification": String(classification),
		"tags": tags.map(func(x): return String(x)),
	}


func to_dict() -> Dictionary:
	return {
		"kind": String(kind),
		"source": String(source),
		"target": String(target),
		"stat": String(stat),
		"delta": delta,
		"tags": tags.map(func(x): return String(x)),
		"classification": String(classification),
	}


static func from_dict(d: Dictionary) -> EQEffectRecord:
	var r := EQEffectRecord.new(StringName(d.get("kind", "")), StringName(d.get("target", "")), StringName(d.get("stat", "")), int(d.get("delta", 0)))
	r.source = StringName(d.get("source", ""))
	r.classification = StringName(d.get("classification", ""))
	var t: Array[StringName] = []
	for s in d.get("tags", []):
		t.append(StringName(s))
	r.tags = t
	return r
