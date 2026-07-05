# EQM-127 IMPLEMENTATION_PLAN — snapshot v3 + replay 証明拡張
## Scope
SEM v1.2 §10.1 (coverage: snapshot-v3)。
## 変更対象ファイル
- `addons/event_queue_manager/runtime/eq_snapshot.gd` / `eq_save_adapter.gd` / `eq_reservation_runtime.gd` (v3 tables)
- `docs/design/SNAPSHOT_COMPAT_V1.md` (v3 stance)
- `test_project/tests/transaction/test_eq_snapshot_v3.gd` (new)
- coverage row flip (orchestrator)
## 実装 steps (P2 委譲)
1. schema_version 3: additive tables `line_modifiers` (§4.8 は event_lines 内包で達成済みなら記録のみ) / `relations` (EQRelationGraph.to_dict) / `state_algebra` (宣言 + wrappers) / provenance は reservation dict 内包 (確認)。
2. v2→v3 migrator (欠落 = 空)。v3-in-v2 = 安定 error (SNAPSHOT_COMPAT 準拠)。
3. load 経路: relations/state_algebra は `restore()` (無 trace) を使用 (EQM-121 申し送り)。
4. replay 証明: modifier/relation/provenance を跨ぐ roundtrip → 同一 pop 順 + 同一 trace。
## Test path
`./tools/test.sh`。
