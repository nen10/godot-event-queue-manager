# EQM-123 IMPLEMENTATION_PLAN — pipeline 拡張 (展開・変換・provenance)

## Scope

SEM v1.2 §6.4 (2a 展開 / 2b 変換) + §6.5 (provenance 連鎖) の pipeline 統合 (coverage rows: expansion-transform, provenance-chain)。メタレベル比較の window close 消費は EQM-125。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_reservation_runtime.gd` (pipeline step 2 の 2a/2b/2c 分割)
- `addons/event_queue_manager/runtime/eq_trace.gd` (必要なら kind 追記なし — open schema)
- `test_project/tests/core/test_eq_resolution_rewrites.gd` (new)
- `test_project/tests/run_all.gd` (登録)
- `tests/golden/expansion_transform.trace.jsonl` (new golden: 鑑波の損害波及 + 対戦術 target 差し替え)
- `docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md` (2 rows flip — orchestrator)

## 実装 steps (P2 委譲)

1. 2a 展開: 宣言 (関係型 ↔ 効果 tag) data + EQRelationGraph 入力 + BFS 関係 id 昇順 + メタ/コスト停止 (§8 語彙: hop cost を acceptance 宣言、予算尽きで決定的停止) + `targets_expanded` trace。
2. 2b 変換: named 変換宣言 (パラメータ別型: target 差し替え = provenance 段選択 / 状態代数 inv 適用) + 適用順 = メタ降順 → priority → sequence + 多重適用 + 有界 round 安全弁 (dev fail-fast) + `effect_transformed` trace (適用ごと)。
3. provenance: event 発行時の自動継承・追記 `[{actor, event_id, meta_level}]` (操作/window 経由発行)。event view に公開。
4. 2c: effect handler へ展開・変換済み view。
5. golden: 鑑波型シナリオ (星に損害 → 月へ展開) + 対戦術 (target を root へ差し替え)。

## Test path

`./tools/test.sh`。新規 golden は --update-golden expansion_transform (baseline 1 回)。
