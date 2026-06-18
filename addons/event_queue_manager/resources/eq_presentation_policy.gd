class_name EQPresentationPolicy
extends Resource
## Flush rules for EQPresentationBuffer (EQM-081).
##
## immediate_classes: enqueuing one of these flushes all pending priors first, then emits self.
## skip_classes: the visual is discarded; the simulation record (EQEffectRecord) is untouched.
## Everything else (e.g. "sensed" by default): deferred and coalesced per actor_id.
## flush_on_player_turn: whether flush_player_turn() auto-flushes all pending.
##
## validate() rejects overlap between immediate_classes and skip_classes.

@export var immediate_classes: Array[StringName] = [&"important"]
@export var skip_classes: Array[StringName] = [&"offscreen"]
@export var flush_on_player_turn: bool = true


func validate() -> EQValidation:
	var v := EQValidation.new()
	for cls in immediate_classes:
		if skip_classes.has(cls):
			v.add(EQError.PRESENTATION_POLICY_CLASS_CONFLICT,
				"class '%s' appears in both immediate_classes and skip_classes" % String(cls))
	return v
