# EQM-145 — Scheduler backend selection — SUB_TASKS

## Complexity

Class: C4
Reason:
- Consumer-facing Resource/API addition with runtime configuration behavior.
- Must preserve sorted-array default while exposing binary heap opt-in safely after EQM-142.
- Requires API surface, error contract, snapshot/API docs, regression, and performance proof.

Required artifacts:
- SUB_TASKS.md
- UX.md
- POLICY.md
- IMPLEMENTATION_PLAN.md

## Task resolution candidate matrix

| candidate | goal / UX | decision | reason |
|---|---|---|---|
| A. `EQConfig.scheduler_backend` enum with sorted default and heap opt-in | Consumer selects backend declaratively | Adopt | Fits Resource/API layer and scene-local config UX. |
| B. Runtime constructor-only backend injection | Internal/test only | Reject | Already possible; does not help Amberground notice or configure. |
| C. Auto-switch to heap by queue size | Zero-config speed | Reject | Hidden policy/fallback changes determinism debugging and makes performance less explicit. |
| D. Allow configure() to rebuild a non-empty scheduler | Dynamic backend switch | Reject | Would risk losing or reordering live events; setup-time only is safer. |

## Scheduled Task Audit

No new scheduled tasks. Phase 15 closes if EQM-145 completes.

## Task resolution

Implement candidate A. Add an exported enum-backed `scheduler_backend` field to `EQConfig`, validate it, and let `EQRuntime.apply_config_scheduler_backend()` rebuild the scheduler only while it is empty. `EQManager.configure()` calls that setup hook before validation/start. The default remains sorted-array for compatibility; binary heap is explicit opt-in.
