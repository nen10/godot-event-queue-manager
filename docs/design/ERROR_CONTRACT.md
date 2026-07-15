# Error Contract (v1)

status: authoritative for v1 (EQM-020, 2026-06-15). The error taxonomy that validation and the runtime resilience modes (EQM-022) build on.

Upstream: `docs/devflow/policy/RUNTIME_RESILIENCE_POLICY.md` (dev/shipped two modes). Code home: `addons/event_queue_manager/runtime/eq_error.gd` (`EQError`). Result type: `EQValidation`.

---

## 1. Principles

- **Stable, namespaced codes.** Each error has a `StringName` code `eqm.<area>.<name>`. Codes are **append-only**: never removed, never repurposed. A code stays valid across versions and is byte-safe in the canonical trace.
- **Recoverability over ad-hoc handling.** Every code maps to one of four recoverability classes (below), which — not the call site — decides dev vs shipped behaviour.
- **Report, then act.** `EQValidation` only *reports* (a list of issues). Acting on them is the resilience mode toggle (EQM-022): dev asserts/stops; shipped degrades per the class. Validation itself never crashes or skips.
- **No silent swallow.** In any mode an anomaly is either stopped (dev) or logged + trace-recorded (shipped). Never silently ignored (RUNTIME_RESILIENCE_POLICY §2).

## 2. Recoverability classes (mirror RUNTIME_RESILIENCE_POLICY §1)

| class | examples | dev (fail-fast) | shipped (fail-safe) |
|---|---|---|---|
| `CONTRACT_VIOLATION` | dead-actor reservation, unknown schema_version, raw base policy | assert / stop | skip event + `invalid_event_skipped` trace + log |
| `BUDGET_EXCEEDED` | reentrancy depth (Q02 backstop), reaction-chain limit (EQM-062) | assert / stop | truncate chain + stable error event + log |
| `RESOURCE_INVALID` | missing policy, ambiguous tie-break | assert / stop | degrade to empty/unset state + log |
| `EXTERNAL_STATE` | actor node freed, WeakRef expired | warn + skip | skip + log (Q05 invalidation path) |

Determinism holds in both modes: skip/degrade appears in the trace and reproduces under the same input (RUNTIME_RESILIENCE_POLICY §2). Normal-path results are mode-invariant.

## 3. Severity & surfacing

- **Severity**: `WARNING` (does not invalidate) / `ERROR` (invalidates). `EQValidation.is_valid()` is true iff no ERROR issue is present.
- **Surfacing**: subset of `{editor, game}` — where the issue is meant to appear. Config-validation codes surface in both; an editor-only authoring hint surfaces in `editor` only. Editor surfaces (EQM-090+) render `EQValidation` as a projection; they do not re-derive messages.

## 4. Codes (v1)

| code | recoverability | severity | surfaces | meaning |
|---|---|---|---|---|
| `eqm.config.policy_missing` | RESOURCE_INVALID | ERROR | editor, game | `EQConfig.policy` is null |
| `eqm.config.policy_base_instance` | CONTRACT_VIOLATION | ERROR | editor, game | policy is a raw `EQPolicy` base instance (need a concrete subclass) |
| `eqm.config.tie_break_ambiguous` | RESOURCE_INVALID | ERROR | editor, game | `tie_break` is unset (no deterministic total tie-break chosen) |
| `eqm.config.tie_break_unknown` | CONTRACT_VIOLATION | ERROR | editor, game | `tie_break` names an unrecognised rule |
| `eqm.policy.name_empty` | RESOURCE_INVALID | WARNING | editor | `policy_name` is empty (authoring hint) |
| `eqm.actor.duplicate_id` | CONTRACT_VIOLATION | ERROR | editor, game | registering an already-active actor_id |
| `eqm.actor.id_reused` | CONTRACT_VIOLATION | ERROR | editor, game | re-registering a retired actor_id (reuse forbidden, §13) |
| `eqm.actor.empty_id` | RESOURCE_INVALID | ERROR | editor, game | registering an empty actor_id |
| `eqm.action.negative_delay` | CONTRACT_VIOLATION | ERROR | editor, game | `EQActionResult.delay < 0` (would schedule into the past) |
| `eqm.action.negative_cost` | RESOURCE_INVALID | ERROR | editor, game | `EQActionResult.cost < 0` without `allow_negative_cost` (§12 policy-declared) |
| `eqm.runtime.unregistered_actor_event` | CONTRACT_VIOLATION | ERROR | editor, game | advancing an event whose actor was removed (dev halts; shipped skips + `invalid_event_skipped`) |
| `eqm.runtime.schedule_unregistered_actor` | CONTRACT_VIOLATION | ERROR | editor, game | schedule / finish_action for an unregistered actor |
| `eqm.reservation.negative_delay` | CONTRACT_VIOLATION | ERROR | editor, game | `EQActionDefinition.delay < 0` |
| `eqm.reservation.immediate_nonzero_delay` | RESOURCE_INVALID | ERROR | editor, game | IMMEDIATE kind with non-zero delay |
| `eqm.reservation.prepared_zero_delay` | RESOURCE_INVALID | ERROR | editor, game | PREPARED kind with delay <= 0 |
| `eqm.reservation.negative_rumination` | RESOURCE_INVALID | ERROR | editor, game | `rumination < 0` |
| `eqm.reservation.invalid_duration` | RESOURCE_INVALID | ERROR | editor, game | `duration < -1` (-1 = unlimited) |
| `eqm.reservation.reaction_needs_duration` | RESOURCE_INVALID | ERROR | editor, game | REACTION_PREPARATION with duration 0 |
| `eqm.reservation.operation_needs_target` | RESOURCE_INVALID | ERROR | editor, game | OPERATION with empty definition `operation_target_tag`, or an empty reservation `target_id` at submit |
| `eqm.reservation.missing_definition` | RESOURCE_INVALID | ERROR | editor, game | `EQReservation` has no definition |
| `eqm.trigger.chain_limit` | BUDGET_EXCEEDED | ERROR | editor, game | a trigger cascade exceeded `EQTriggerEngine.max_chain` (chain truncated, recorded) |
| `eqm.presentation.policy_class_conflict` | RESOURCE_INVALID | ERROR | editor, game | a classification appears in both immediate and skip classes (EQM-081; row backfilled by EQM-111) |
| `eqm.condition.line_id_empty` | RESOURCE_INVALID | ERROR | editor, game | LINE_THRESHOLD spec without a `line_id` (EQM-111) |
| `eqm.condition.predicate_name_empty` | RESOURCE_INVALID | ERROR | editor, game | NAMED_PREDICATE spec / registration without a name |
| `eqm.condition.counter_start_invalid` | RESOURCE_INVALID | ERROR | editor, game | COUNTER spec with `counter_start < 1` |
| `eqm.condition.predicate_unregistered` | CONTRACT_VIOLATION | ERROR | editor, game | evaluating / loading a condition whose predicate name is not registered (SEM §5.5 stable error) |
| `eqm.condition.line_unknown` | CONTRACT_VIOLATION | ERROR | editor, game | a condition reads an event-line absent from the evaluation context |
| `eqm.effect.unregistered` | CONTRACT_VIOLATION | ERROR | editor, game | a reservation declares `effect_name` but no handler is registered (SEM §6.1 declared linkage — never a silent skip; EQM-113) |
| `eqm.window.depth_limit` | BUDGET_EXCEEDED | ERROR | editor, game | opening a window past `max_window_depth` (SEM §8 engineering backstop; EQM-114) |
| `eqm.window.budget_insufficient` | BUDGET_EXCEEDED | ERROR | editor, game | opening a window whose meta-cost exceeds the owner's remaining budget (Q02) |
| `eqm.window.close_invalid` | CONTRACT_VIOLATION | ERROR | editor, game | closing a non-top window or the implicit root |
| `eqm.window.commit_conflict` | CONTRACT_VIOLATION | ERROR | editor, game | close_window(commit) while the live scheduler changed since open — commit would clobber; the draft rolls back instead (EQM-114 POLICY) |
| `eqm.order.hook_invalid` | CONTRACT_VIOLATION | ERROR | editor, game | the ordering hook returned a non-permutation (wrong length / duplicate / out of range); issuance order is used and the fault recorded (SEM §7.1, EQM-115) |
| `eqm.save.blocked` | CONTRACT_VIOLATION | ERROR | editor, game | save requested off the boundary (effect chunk non-empty or an explicit window open) — SEM §10, no force flag (EQM-117) |
| `eqm.effect.commit_result_invalid` | CONTRACT_VIOLATION | ERROR | editor, game | a handler registered through `register_effect_commit` returned a non-`EQEffectCommitResult` value or a result whose records / event views / diagnostic failed value validation |
| `eqm.effect.commit_result_version_unsupported` | CONTRACT_VIOLATION | ERROR | editor, game | transactional effect-result registration/return used an unsupported version; schema-v4+ reservation omitted a required binding (`reason: missing_binding`); or schema v1-v3 carried a nonzero binding (`reason: binding_not_supported_by_schema`); load rejects before mutation |
| `eqm.effect.commit_result_context_unsupported` | CONTRACT_VIOLATION | ERROR | editor, game | transactional effect-result v1 was declared or encountered in an atomic bundle or expiry-effect context, where rollback cannot be guaranteed |
| `eqm.effect.commit_result_binding_mismatch` | CONTRACT_VIOLATION | ERROR | editor, game | an issued or loaded reservation's bound main/expiry handler mode (0 legacy / 1 typed) differs from the current named-effect registry; the replacement handler is not invoked |
| `eqm.reaction.fire_context_invalid` | CONTRACT_VIOLATION | ERROR | editor, game | a reaction FIRE cause is malformed, non-JSON-safe, bound to a different/duplicate/orphan event id, or attached to non-reaction work |
| `eqm.reaction.fire_context_missing` | CONTRACT_VIOLATION | ERROR | editor, game | schema v5 omitted the scheduled-row context field, or a pending reaction FIRE has no reconstructable cause (including historical v1-v4) |

Codes are added by later tasks (snapshot/actor/reservation/trigger) under the same rules. The snapshot load codes (EQM-012 `EQSnapshot.Load`) predate this taxonomy and stay as their own enum for now; EQM-022 may fold them in without renaming.

## 5. Usage

```gdscript
var v := config.validate()          # -> EQValidation, no side effects
if not v.is_valid():
    for issue in v.errors():
        # issue: { code, severity, recoverability, message, context }
        ...
```

- An unknown code passed to `EQValidation.add` defaults to the strictest classification (CONTRACT_VIOLATION / ERROR / surfaces everywhere) — an unclassified anomaly is never silently downgraded.
- Stability promise: removing or repurposing a code is a breaking change; the pre-1.0 stance is `defer` per `PROJECT_PROFILE.md`.

## 6. References

- Resilience modes: `docs/devflow/policy/RUNTIME_RESILIENCE_POLICY.md`
- Input narrowing (why missing/base/ambiguous are explicit errors): `docs/devflow/policy/UX_PATH_REDUCTION_POLICY.md`
- Semantics (numeric domain, over-cap): `docs/design/EVENT_MODEL_SEMANTICS.md` §12
