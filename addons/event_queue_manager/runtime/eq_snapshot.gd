class_name EQSnapshot
extends RefCounted
## Format and version authority for serialized scheduler state.
##
## EQScheduler owns capturing/applying its own state; this class owns the wire
## format: the schema version constant and the validation that turns an
## arbitrary Dictionary into a stable load result. Unknown versions never crash
## (shipped fail-safe, RUNTIME_RESILIENCE_POLICY); they return UNKNOWN_VERSION so
## a developer can assert OK (dev fail-fast) and a shipped game can degrade.
##
## Snapshots are plain Dictionaries (no Node references) so they round-trip
## through JSON or .tres (serializable core). The full error taxonomy and the
## two resilience modes are formalized later (EQM-020 / EQM-022); the Load codes
## here are the minimal stable seam those tasks build on.

const SCHEMA_VERSION := 1

enum Load {
	OK,               ## supported version, well-formed
	UNKNOWN_VERSION,  ## schema_version is absent-as-version or not supported
	MALFORMED,        ## supported version but required structure is missing
}


static func is_supported_version(v: int) -> bool:
	return v == SCHEMA_VERSION


## Classifies a candidate snapshot without mutating anything. Version is checked
## before structure: an unknown version may have an entirely different shape, so
## structural assumptions only hold once the version is known-supported.
static func validate(data) -> int:
	if typeof(data) != TYPE_DICTIONARY or not data.has("schema_version"):
		return Load.MALFORMED
	if not is_supported_version(int(data["schema_version"])):
		return Load.UNKNOWN_VERSION
	if not (data.has("entries") and typeof(data["entries"]) == TYPE_ARRAY \
			and data.has("current_tick") \
			and data.has("next_event_id") \
			and data.has("next_sequence")):
		return Load.MALFORMED
	return Load.OK


## Deep value-equality of two snapshots. Used to assert prediction purity
## (live snapshot before == after). snapshot() emits entries in deterministic
## order, so a recursive Dictionary compare is exact.
static func equals(a, b) -> bool:
	return a == b


static func describe(code: int) -> String:
	match code:
		Load.OK:
			return "ok"
		Load.UNKNOWN_VERSION:
			return "unknown snapshot schema_version"
		Load.MALFORMED:
			return "malformed snapshot"
		_:
			return "unrecognized load code"
