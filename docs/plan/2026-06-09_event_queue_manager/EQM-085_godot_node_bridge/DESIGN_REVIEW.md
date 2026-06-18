# EQM-085 Design Review

Policy: `docs/devflow/policy/DESIGN_REVIEW_POLICY.md`  
Review date: 2026-06-19  
Tests: not rerun per user instruction; this review uses queue proof, self-review, and codebase file inspection.

| 項目 | 記録 |
|---|---|
| 対象 | `docs/plan/2026-06-09_event_queue_manager/EQM-085_godot_node_bridge/` |
| 主分類 | runtime / integration |
| 判断 | `needs_design_update` |
| queue status | `COMPLETE` |
| 採用判断 | Godot node bridge: save/load rebind adapter, optional autoload installer, actor-deletion handling, full multi-domain signal bridge. |
| 棄却 / 延期判断 | 旧UX/暫定contractは設計内の reject/defer/self-review に従う。追加の互換維持要求は見つからない。 |
| 実装固定点 | Save/load stores actor_id + Resources, never live Nodes, and rebinds on load; actor deletion routes pending events through the Q05 invalidation path; optional autoload installer is opt-in (scene-local default per profile); signal bridge covers turn/reservation/trigger/effect/presentation/invalid; tests cover scene-local manager, actor deletion, and save/load rebind (roadmap Phase 9 "Godot runtime integration"). |
| control surface | queue target files と public API surface に限定。 |
| test gate | テスト再実行なし。queue proof log / self-review の `./tools/test.sh` PASS または docs-only gate を参照。 |
| product proof gate | Save/load stores actor_id + Resources, never live Nodes, and rebinds on load; actor deletion routes pending events through the Q05 invalidation path; optional autoload installer is opt-in (scene-local default per profile); signal bridge covers turn/reservation/trigger/effect/presentation/invalid; tests cover scene-local manager, actor deletion, and save/load rebind (roadmap Phase 9 "Godot runtime integration"). |
| proof grade | `contract_tested` |
| provisional contract | provisional contract の互換維持要求なし。置換/延期は packet または self-review の記録どおり。 |

## Design Artifact Review

- Source files before this review: IMPLEMENTATION_PLAN.md, POLICY.md, SUB_TASKS.md.
- Complexity: C3.
- Artifact gaps: UX.md.
- Policy-format follow-ups: none.

## Codebase Confirmation

- self-review: docs/review/autopilot/EQM-085_SELF_REVIEW_2026-06-18.md; target files present: runtime/eq_node_bridge.gd, runtime/eq_save_adapter.gd, tests/runtime/; target files missing: none detected by path scan.
- Implementation follow-ups: none.

## 追加要件 / 未解決リスク

- 欠落 planning artifact を補完する: UX.md
