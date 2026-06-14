# EQM-034 Self-Review 2026-06-15

Pattern: P0 (orchestrator-direct). Repair: 0.

## Execution summary

Added the first learning-path sample — a minimal CTB battle built with the public API only — plus a quickstart that uses a project-created config (never a bundled default). The demo's behaviour is proven headless against a golden trace, and `test_project/demos` symlinks the repo `demos/` so the sample is reachable as `res://demos/...`.

## Changed files

- `demos/ctb_battle/ctb_battle.gd` — `build()` / `run_trace(turns)` + a `_ready()` playable demo, using EQManager/EQConfig/EQCTBPolicy/EQActionResult/EQPrediction only (no class_name → not in the API surface).
- `demos/ctb_battle/ctb_battle.tscn` — playable scene (a Node running the script).
- `demos/ctb_battle/README.md` — learning-path note.
- `docs/manual/quickstart.md` — register → turn_ready → finish with a project-created config; prediction preview.
- `test_project/demos` → `../demos` (symlink; tracked).
- `tests/golden/demo_ctb_battle.trace.jsonl` — demo golden (created via `--update-golden demo_ctb_battle`).
- `test_project/tests/debug_scene/test_ctb_battle_demo.gd` — runs the demo headless, golden compare + fastest-acts-first.

## Acceptance result — met

| acceptance | result |
|---|---|
| sample is explicitly learning path | header + README state "learning path, not production, not a default"; demo has no class_name (absent from the API surface) |
| quickstart uses project-created config | quickstart.md builds `EQConfig` in code (or `.tres`), no bundled default |
| sample scene runs (or BLOCKED_BY_TEST_ENV with proof) | Godot 4.6.2 present → the demo runs headless; golden trace generated and matched (no BLOCKED needed) |

Demo golden (DETERMINISM §5): rogue(22)→455, hero(15)→667, rogue→910, golem(8)→1250, … — the faster combatant acts more often; exact ceil(cost·scale/speed) values verified.

## Test summary

```text
./tools/test.sh --update-golden demo_ctb_battle -> golden written, PASS
./tools/test.sh -> RESULT: PASS (exit 0); files=17 checks=234 failures=0; [api-surface] ok
```

API surface unchanged (demo has no class_name) — the golden didn't move.

## Design notes

- **Public-API-only** by construction (preloads only L0/L1 public classes); a real game's config is project-created, so the sample is never a hidden default (UX_PATH_REDUCTION §1.3).
- **Reachability via symlink** mirrors the addon symlink, keeping `demos/` a repo-level artifact while letting the test load it at `res://demos/`.

## No sample-only completion

The sample is the deliverable here, but its acceptance is a golden trace + structural checks, and it is explicitly isolated as a learning path — not used to claim any other feature complete.

## Deviations

- Demo golden lives under `test_project/tests/golden/` (Godot-readable), consistent with the EQM-013 trace-golden path convention.

## Repair-now / follow-up

None. Next: EQM-035 (v0.1 milestone evaluation) — audits API friction and semantics drift across EQM-010..034, baselines north-star metrics, and confirms or adjusts the roadmap. Its completion is the v0.1 MVP milestone (a §8.3 checkpoint).
