class_name EQActionResult
extends RefCounted
## Typed result of finishing an action: how much the action cost and when the
## actor's next event is due. finish_action takes this type, never a raw
## Dictionary (UX_PATH_REDUCTION §2).
##
## delay is ticks until the next scheduled event; it must be >= 0 (a negative
## delay would schedule into the past and break the timeline's forward order —
## always a contract violation). cost is the progression/AP spent; negative cost
## (a refund) is only valid when the policy declares it (allow_negative_cost),
## matching the "negative AP is policy-declared" rule (EVENT_MODEL_SEMANTICS §12).

var cost: int = 0
var delay: int = 0
## Policy-declared: whether a negative cost (refund) is permitted.
var allow_negative_cost: bool = false


func _init(p_cost: int = 0, p_delay: int = 0) -> void:
	cost = p_cost
	delay = p_delay


func validate() -> EQValidation:
	var v := EQValidation.new()
	if delay < 0:
		v.add(EQError.ACTION_NEGATIVE_DELAY, "delay must be >= 0 (got %d)" % delay)
	if cost < 0 and not allow_negative_cost:
		v.add(EQError.ACTION_NEGATIVE_COST, "negative cost requires allow_negative_cost (got %d)" % cost)
	return v
