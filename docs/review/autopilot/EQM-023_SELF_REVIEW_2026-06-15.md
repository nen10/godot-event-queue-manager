# EQM-023 Self-Review 2026-06-15

Pattern: P0 (orchestrator-direct). Repair: 0. Terminal Phase 2 task — its completion is the Phase 2 (resource/API) milestone.

## Execution summary

Built the layer-aware public API surface gate. `tools/check_api_surface.py` extracts the addon's public surface (class_name + non-underscore members, including `@abstract func` / `@export var`), tags each class by layer via `LAYER_MAP` (core/L0/L1/L2/L3), serializes deterministically, and gates three ways: surface diff vs golden, unassigned public class, and an L3 symbol leaking into an L0/L1 public signature. `tools/test.sh` runs it (plus `--self-test`); `docs/design/API_SURFACE.md` documents the convention, layer table, and explicit-update procedure.

## Changed files

- `tools/check_api_surface.py` (new) — extraction, layer map, golden compare, leak detection, untagged detection, `--update`, `--self-test`.
- `tests/golden/api_surface.json` (new) — surface golden (16 classes: core 10, L0 4, L1 2), created via `--update`.
- `docs/design/API_SURFACE.md` (new) — public/internal convention, layer table, gate description, update procedure.
- `tools/test.sh` — python-checks section runs `--self-test` + check; `--update-golden api_surface` routes to `--update`.

## Acceptance result — met

| acceptance | result |
|---|---|
| public/internal naming documented | API_SURFACE.md §1 (public = no leading underscore; const UPPER_CASE; class_name files only) |
| surface tagged by layer (L0/L1/L2/L3 per §3.1) | `LAYER_MAP` + golden grouped by layer (core/L0/L1; L2/L3 reserved for Phase 5) |
| deterministic export | sorted JSON; `--update` re-emits byte-identically |
| L3 leak into L0/L1 fails ./tools/test.sh | `find_leaks` flags it; verified by `--self-test` and a source-free negative check (faked L3 → leak fires) |
| surface diff without doc note fails | golden exact-compare; any diff → exit 1 → `PY_FAIL` → test.sh FAIL |
| golden update via explicit procedure | `--update` only; normal run is read-only |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=12 checks=191 failures=0
  [api-surface] self-test ok (leak detector verified)
  [api-surface] ok (surface matches golden; no untagged class; no L3 leak)
Negative checks (source-unmodified): dropping EQConfig from the map -> untagged fires;
  faking EQActorState as L3 referenced by EQRuntime -> leak fires.
```

Gate (§4 resource/API): layer-aware surface + leak gate green; the detector is proven live (`--self-test`), not merely trivially-passing while no L3 exists.

## Design notes

- **Layer map in the tool + doc, not per-file source tags.** Lower churn than tagging 14 files; a renamed/new class still surfaces as a golden diff (forcing review) or an untagged FAIL (forcing layer assignment). API_SURFACE.md is the human-authoritative table kept in sync with `LAYER_MAP`.
- **`--self-test` keeps the leak gate honest** before any L3 class exists, so the forward-looking check cannot silently rot.
- `@abstract func` / `@export var` are extracted (verified: EQBackend's 7 abstract methods appear in the golden).

## Deviations

- Golden lives at repo-root `tests/golden/api_surface.json` (python-consumed), distinct from the Godot-consumed trace goldens under `test_project/tests/golden/` — matching the queue's target path and the EQM-013 path-convention note.

## No sample-only completion

The gate runs against the real addon surface; the leak/untagged detectors are proven by self-test + a source-free negative check.

## Repair-now / follow-up

None. **Phase 2 (resource/API) milestone reached.** Next frontier is Phase 3 (EQM-030 fixed round policy) — concrete policies, the first to add ordering rules and (eventually) L2 surface; L2/L3 layer entries and the leak gate go live as EQM-050+ land. Pausing the autonomous run at this milestone for user direction.
