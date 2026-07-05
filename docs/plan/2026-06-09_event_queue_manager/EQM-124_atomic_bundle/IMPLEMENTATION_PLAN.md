# EQM-124 IMPLEMENTATION_PLAN — composite atomic bundle

## Scope
SEM v1.2 §7.2 (coverage: atomic-bundle)。§7.1 staging の deferral 解除。

## 変更対象ファイル
- `addons/event_queue_manager/runtime/eq_reservation_runtime.gd` (bundle 解決単位)
- `test_project/tests/core/test_eq_atomic_bundle.gd` (new)
- `tests/golden/fairness_bundle.trace.jsonl` (new — 公平: bundle + 事後個別反射)
- coverage row flip (orchestrator)

## 実装 steps (P2 委譲)
1. bundle API: 同 tick member 群を 1 解決単位に (member 全 effect 適用 → 単一 sweep、member 順 = §7.1 hook → 発行順)。
2. `bundle_resolved` trace (bundle id + member 列)。chunk drain は bundle 完了後 (save 境界と整合)。
3. 公平 golden: composite 解決 + 事後の個別 state トリガ発火 (相談3 の二段構え)。

## Test path
`./tools/test.sh`。新規 golden は --update-golden fairness_bundle。
