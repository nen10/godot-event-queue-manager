class_name EQVersion
extends RefCounted
## Addon version and minimum supported Godot version (roadmap §3.2).
##
## The minimum is the addon's intended public floor; the standard harness
## (tools/test.sh) records the actual engine it ran on (currently 4.6).

const ADDON_VERSION := "0.0.1"
const MIN_GODOT_MAJOR := 4
const MIN_GODOT_MINOR := 2


static func is_supported_engine() -> bool:
	var info := Engine.get_version_info()
	var major := int(info["major"])
	var minor := int(info["minor"])
	if major != MIN_GODOT_MAJOR:
		return major > MIN_GODOT_MAJOR
	return minor >= MIN_GODOT_MINOR


static func engine_string() -> String:
	var info := Engine.get_version_info()
	return "%s.%s.%s" % [info["major"], info["minor"], info["patch"]]
