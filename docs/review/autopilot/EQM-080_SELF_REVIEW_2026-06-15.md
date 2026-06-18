# EQM-080 Self-Review 2026-06-15

Pattern: P0 (orchestrator-direct — simulation/presentation split foundation; design forks pre-agreed in the approved Phase 8 plan). Repair: 0.

## Execution summary

Built the simulation/presentation record split: `EQEffectRecord` (simulation truth, immediate, deterministic, trace-bound) accumulated in `EQEffectChunk` (chunk-empty = save boundary, §10/§22), and `EQPresentationEvent` (queued visual request carrying actor_id + a queue-time position value snapshot + the consumer-supplied classification + barrier dependency lists). Per the agreed decisions: chunk + `is_save_allowed` are in EQM-080; presentation refs are value snapshots; classification is a supplied field.

## Changed files

- `addons/event_queue_manager/runtime/eq_effect_record.gd` — `EQEffectRecord` (core): kind/source/target/stat/delta(int)/tags/classification; `CLASS_IMPORTANT/SENSED/OFFSCREEN`; `to_trace_record` (open-kind schema); `to_dict`/`from_dict`.
- `addons/event_queue_manager/runtime/eq_effect_chunk.gd` — `EQEffectChunk` (core): add/records/size/is_empty/clear/drain; `is_save_allowed() = is_empty`.
- `addons/event_queue_manager/runtime/eq_presentation_event.gd` — `EQPresentationEvent` (presentation): actor_id/position(value)/classification/tags/changes_position_of/depends_on; transient `bind`/`bound`; `to_dict`/`from_dict` (no live ref).
- `tools/check_api_surface.py` (+`presentation` layer; EffectRecord/Chunk=core, PresentationEvent=presentation) + `docs/design/API_SURFACE.md` + `tests/golden/api_surface.json`.
- `test_project/tests/presentation/test_eq_effect_record.gd`, `test_eq_presentation_event.gd` (new dir).

## Acceptance result — met

| acceptance | result |
|---|---|
| status effects record immediately | `EQEffectRecord` constructed with its fields at resolution; added to the chunk; available immediately |
| presentation requests queued separately, with actor/position references | `EQPresentationEvent` carries actor_id + a position value snapshot, kept apart from the simulation record |

Plus (agreed decisions): effect-processing-chunk with `is_save_allowed` (= chunk empty, §10/§22); classification is a consumer-supplied field; `to_trace_record` is canonical with int delta; `to_dict` carries no live node.

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=34 checks=438 failures=0; [api-surface] ok
```

New `presentation` API-surface layer added (EQPresentationEvent); EffectRecord/Chunk in `core`; no L3 leak into L0/L1.

## Design notes (no shrink — per approved plan)

- **EffectRecord is the neutrality anchor**: immediate + deterministic + trace-bound; presentation can defer the visual but never the record.
- **Chunk = save boundary** (§10/§22) established here, not deferred — `is_save_allowed()` is the concrete mechanism.
- **Position is a queue-time value snapshot** so the EQM-082 barrier can compare assumed vs changed positions; the live node is a transient WeakRef, never serialized.
- **Classification is supplied, not computed** (Q12): the addon has no spatial data; the flush policy (EQM-081) reads the field.

## UX path reduction

- Added: EQEffectRecord/EQEffectChunk (core), EQPresentationEvent (presentation). Narrowed: presentation refs are value snapshots / transient WeakRef (no live node in save form); classification is an explicit supplied field. Residual: none.

## Deviations

- None (built to the approved plan).

## Repair-now / follow-up

None. Next: EQM-081 (importance/sensing/offscreen flush policy) — `EQPresentationPolicy` + `EQPresentationBuffer`, with the presentation-neutrality property test (flush-policy variation → identical simulation trace). Orchestrator-direct.
