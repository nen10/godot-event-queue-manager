# EQM-032 Design Review

Policy: `docs/devflow/policy/DESIGN_REVIEW_POLICY.md`  
Review date: 2026-06-19  
Tests: not rerun per user instruction; this review uses queue proof, self-review, and codebase file inspection.

| 項目 | 記録 |
|---|---|
| 対象 | `docs/plan/2026-06-09_event_queue_manager/EQM-032_eq_manager_node/` |
| 主分類 | runtime / integration |
| 判断 | `pass` |
| queue status | `COMPLETE` |
| 採用判断 | Godot `EQManager` Node, signal integration, and game-loop driver contract. |
| 棄却 / 延期判断 | 旧UX/暫定contractは設計内の reject/defer/self-review に従う。追加の互換維持要求は見つからない。 |
| 実装固定点 | Scene-local manager emits queue_changed, event_ready, turn_ready, event_resolved; invalid actor policy tested; game-loop driver contract (who advances the queue, suspend semantics awaiting player input, await boundary for action presentation) documented in EVENT_MODEL_SEMANTICS.md and covered by tests; the driver offers a frame-budget / time-sliced advance mode (resolve up to a per-frame budget to avoid large-battle hitches) and coexists with Godot idioms (SceneTree pause, and EditorUndoRedoManager for editor-side mutations) without breaking determinism. |
| control surface | queue target files と public API surface に限定。 |
| test gate | テスト再実行なし。queue proof log / self-review の `./tools/test.sh` PASS または docs-only gate を参照。 |
| product proof gate | Scene-local manager emits queue_changed, event_ready, turn_ready, event_resolved; invalid actor policy tested; game-loop driver contract (who advances the queue, suspend semantics awaiting player input, await boundary for action presentation) documented in EVENT_MODEL_SEMANTICS.md and covered by tests; the driver offers a frame-budget / time-sliced advance mode (resolve up to a per-frame budget to avoid large-battle hitches) and coexists with Godot idioms (SceneTree pause, and EditorUndoRedoManager for editor-side mutations) without breaking determinism. |
| proof grade | `contract_tested` |
| provisional contract | provisional contract の互換維持要求なし。置換/延期は packet または self-review の記録どおり。 |

## Design Artifact Review

- Source files before this review: IMPLEMENTATION_PLAN.md, POLICY.md, SUB_TASKS.md, UX.md.
- Complexity: C3.
- Artifact gaps: none.
- Policy-format follow-ups: none.

## Codebase Confirmation

- self-review: docs/review/autopilot/EQM-032_SELF_REVIEW_2026-06-15.md; target files present: runtime/eq_manager.gd, addons/event_queue_manager/plugin.gd, tests/runtime/; target files missing: none detected by path scan.
- Implementation follow-ups: none.

## 追加要件 / 未解決リスク

- なし
