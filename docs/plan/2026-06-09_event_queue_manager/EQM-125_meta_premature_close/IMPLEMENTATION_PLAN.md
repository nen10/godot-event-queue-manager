# EQM-125 IMPLEMENTATION_PLAN — メタレベル + window premature close

## Scope
SEM v1.2 §8.2/§8.3 (coverage: meta-level-premature-close)。meta_level 運搬は EQM-123 で導入済み (EQActionDefinition.meta_level / provenance)。

## 変更対象ファイル
- `addons/event_queue_manager/runtime/eq_window.gd` (meta_level field + premature close)
- `addons/event_queue_manager/runtime/eq_reservation_runtime.gd` (介入 API + pending 一掃)
- `test_project/tests/transaction/test_eq_premature_close.gd` (new)
- `tests/golden/interception_close.trace.jsonl` (new — 迎撃: 5 歩移動の 2 歩目)
- coverage row flip (orchestrator)

## 実装 steps (P2 委譲)
1. EQWindow.meta_level (open 時に宣言値を運ぶ、既定 0)。
2. `intervene_close(window_id, intervener_view) -> bool`: meta(介入) >= meta(window) で成立 (同値 = 介入成功)。解決済み効果は維持、window の pending members を invalidation で一掃 (`closed_by`)、`window_closed(cause: intervention)` + 両メタ値 + intervener event id。
3. 回避 (メタ不足) は close せず trace に記録 (説明可能性)。pre-close hook は既存 deadline hook と対称。
4. 迎撃 golden: 移動 window 5 step の 2 step 目で介入 → 2 step 分の効果維持・残り打ち切り。

## Test path
`./tools/test.sh`。新規 golden は --update-golden interception_close。
