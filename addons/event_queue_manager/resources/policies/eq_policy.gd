class_name EQPolicy
extends Resource
## Base extension point for ordering policies (Fixed round / CTB / Energy /
## Wait-Turn / Action-Resolution, delivered Phase 3+).
##
## This base is an EXTENSION POINT (UX_PATH_REDUCTION §4), not a usable policy:
## a concrete subclass defines the actual ordering rule. A raw base instance
## assigned to EQConfig.policy is a contract violation (EQConfig.validate flags
## POLICY_BASE_INSTANCE) — the slot accepts exactly one class family, the
## concrete subclass, with no "works for now" base fallback.

## Human-facing identifier for editor/debug surfaces; not an ordering key.
@export var policy_name: StringName = &""
