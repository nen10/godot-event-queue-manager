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
