# EQM-085 Self-Review 2026-06-18

Pattern: P0 (orchestrator-direct — runtime/Godot integration). Repair: 0. Completes Phase 8b (EQM-083/084/085).

## Execution summary

Built `EQSaveAdapter` (node-free save/load with rebind) and `EQNodeBridge` (scene-local actor↔node binding, actor-deletion via the Q05 invalidation path, and a multi-domain signal bridge). The bridge's `notify_*` signals are the dogfood-F2 follow-up (consumers subscribe instead of hand-driving effects/presentation/reservation/trigger).

## Changed files

- `addons/event_queue_manager/runtime/eq_save_adapter.gd`, `eq_node_bridge.gd` (new).
- `tools/check_api_surface.py` + `docs/design/API_SURFACE.md` (L0 +EQSaveAdapter +EQNodeBridge).
- `tests/golden/api_surface.json` — re-baselined (explicit `--update`).
- `test_project/tests/runtime/test_eq_save_adapter.gd`, `test_eq_node_bridge.gd`.

## Acceptance result — met

| acceptance | result |
|---|---|
| save stores actor_id + Resources, never live Nodes | `save()` bundles scheduler snapshot + actor `to_dict` (actor_id + data); `contains_live_object(save)` is false even after an actor is weak-bound to an Object |
| rebinds on load | `load(fresh, save, {hero: node})` re-registers actors, restores data, rebinds via the map; the restored schedule reproduces pop order (orc@3 before hero@5) |
| actor deletion routes pending events through the Q05 invalidation path | `on_actor_freed(orc)` unregisters orc → its orphaned turn is skipped (not resolved, not a crash) under shipped mode; `event_invalidated` emitted |
| optional autoload installer is opt-in (scene-local default) | `EQNodeBridge.new(manager)` works scene-local with no autoload / no SceneTree; autoload is documented as opt-in |
| signal bridge covers turn/reservation/trigger/effect/presentation/invalid | 6 signals; `turn_ready` + `event_invalidated` forwarded from the manager; reservation/trigger/effect/presentation emitted via `notify_*`; all six asserted |
| tests cover scene-local manager, actor deletion, save/load rebind | all three tested |

## Test summary

```text
./tools/test.sh -> RESULT: PASS (exit 0); files=40 checks=530 failures=0; [api-surface] ok
```

## Design notes (no shrink)

- **Node-free save** proven by a recursive `contains_live_object` check over the bundle (not just absence of an obvious key) — the Adapter rule is mechanically verified.
- **Actor deletion = unregister = invalidation**: reuses the EQM-022 shipped-mode skip path rather than inventing a new deletion mechanism; the deleted actor's events are skipped deterministically.
- **Multi-domain signals**: turn/invalid are forwarded automatically; the other domains are `notify_*` seams the consumer drives — this resolves dogfood F2 (subscribe vs hand-drive) without forcing the addon to know a game's effect semantics.
- Autoload is genuinely opt-in (scene-local default per profile); the bridge needs no autoload.

## UX path reduction

- Added: `EQSaveAdapter`, `EQNodeBridge` (L0). Narrowed: save is actor_id+data only (no Node); actor deletion goes through the single invalidation path. Residual: none.

## Deviations

- None beyond the planned L0 additions.

## Repair-now / follow-up

None. **Phase 8b (runtime order surface + dogfood) complete.** Next: EQM-086 (editor UI contract + state matrix — UI metric adoption M0, docs-only), the first Phase 9 task. Orchestrator-direct (UI contract = design).
