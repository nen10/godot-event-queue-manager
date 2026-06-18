# EQM-085 IMPLEMENTATION_PLAN

## Scope

EQSaveAdapter (save/load rebind) + EQNodeBridge (actor↔node, 削除 invalidation, multi-domain signals) を実装。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_save_adapter.gd` — `EQSaveAdapter` (L0)。
- `addons/event_queue_manager/runtime/eq_node_bridge.gd` — `EQNodeBridge` (Node, L0)。
- `tools/check_api_surface.py` / `docs/design/API_SURFACE.md` — L0 に 2 class。
- `tests/golden/api_surface.json` — `--update`。
- `test_project/tests/runtime/test_eq_save_adapter.gd`, `test_eq_node_bridge.gd`。

## 実装 steps

1. EQSaveAdapter: save/load/contains_live_node helper。
2. EQNodeBridge: 6 signal + bind_actor/node_for/on_actor_freed/prune_freed/notify_*。
3. LAYER_MAP + API_SURFACE。
4. tests: save/load rebind + no-Node + actor deletion invalidation + signal bridge + scene-local。
5. `python3 tools/check_api_surface.py --update`。
6. `./tools/test.sh` PASS。

## Test path / gate

- §4 runtime/integration: save/load rebind (no live Node, pop 順再現) + actor 削除 invalidation + signal bridge + scene-local。
- 期待: 既存 510 + 新 checks、api-surface ok、exit 0。

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| EQ snapshot (EQM-012) / actor registry (EQM-021) | save 不整合 | load + rebind で pop 順再現 |
| Q05 invalidation (EQM-022 shipped) | 削除 crash / 幽霊 | freed → unregister → advance skip |
| Adapter 原則 | Node 漏洩 | save dict に Node なし |
| profile (scene-local 既定) | autoload 強制 | bridge 単体動作 |
| API surface gate | 無断変更 | 明示 --update、L0 |

## Completion checklist

- [ ] save に actor_id+Resources+scheduler、live Node なし。
- [ ] load + rebind で actor 再束縛 + pop 順再現。
- [ ] actor 削除 → pending invalidation skip (shipped)。
- [ ] 6 domain signal bridge (turn/reservation/trigger/effect/presentation/invalid)。
- [ ] scene-local 動作 (autoload opt-in)。
- [ ] golden 明示更新、`./tools/test.sh` PASS。
