# EQM-122 IMPLEMENTATION_PLAN — 関係グラフ backend

## Scope

SEM v1.2 §13.1 の backend 実装 (coverage row: relation-graph)。§6.4 の展開消費は EQM-123、snapshot v3 table は EQM-127。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_relation_graph.gd` (new, L3)
- `addons/event_queue_manager/runtime/eq_runtime.gd` (invalidate_actor 連動)
- `test_project/tests/core/test_eq_relation_graph.gd` (new)
- `test_project/tests/run_all.gd` (登録)
- API surface golden (L3 追加、明示 --update + doc note)
- `docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md` (row flip — orchestrator)

## 実装 steps (P2 委譲)

1. 関係型宣言 (name / 分類 tag / inv 反転形 / TREE|GRAPH 制約 / 維持条件 spec / 評価 sweep 宣言 / 解消時規則 NONE|SERIAL_SUTURE)。
2. 関係 instance table (決定的採番 id) + bind/dissolve/invert/rebind + TREE violation = 安定 error (dev fail-fast / shipped skip+log)。
3. 維持条件 sweep (宣言 sweep 名で駆動、EQConditionEval 流用) — 失効は解消時規則経由。
4. invalidate_actor 連動 (incident 関係を解消時規則経由で解消)。
5. trace kinds: relation_bound/dissolved/rebound/inverted。serialize roundtrip。
6. 月/星 acceptance 例 (召喚 tree + 直列縫合 + 解析 loop 許容) の test。

## Test path

`./tools/test.sh`。golden は api_surface のみ (明示 --update)。
