# EQM-090 Design Review

Policy: `docs/devflow/policy/DESIGN_REVIEW_POLICY.md`  
Review date: 2026-06-19  
Tests: not rerun per user instruction; this review uses queue proof, self-review, and codebase file inspection.

| 項目 | 記録 |
|---|---|
| 対象 | `docs/plan/2026-06-09_event_queue_manager/EQM-090_timeline_dock_mvp/` |
| 主分類 | editor UI / UX |
| 判断 | `needs_design_update` |
| queue status | `COMPLETE` |
| 採用判断 | Timeline Preview Dock MVP for basic policies. |
| 棄却 / 延期判断 | 旧UX/暫定contractは設計内の reject/defer/self-review に従う。追加の互換維持要求は見つからない。 |
| 実装固定点 | User selects project config; dock shows next events or explicit unset/validation state; no silent sample default; controls carry ui_metric_id metadata; displayed order equals headless prediction (projection integrity); metric WARN report cited in self-review. |
| control surface | queue target files と public API surface に限定。 |
| test gate | テスト再実行なし。queue proof log / self-review の `./tools/test.sh` PASS または docs-only gate を参照。 |
| product proof gate | User selects project config; dock shows next events or explicit unset/validation state; no silent sample default; controls carry ui_metric_id metadata; displayed order equals headless prediction (projection integrity); metric WARN report cited in self-review. |
| proof grade | `editor_projection_verified` |
| provisional contract | provisional contract の互換維持要求なし。置換/延期は packet または self-review の記録どおり。 |

## Design Artifact Review

- Source files before this review: IMPLEMENTATION_PLAN.md.
- Complexity: 未記載.
- Artifact gaps: SUB_TASKS.md, UX.md, POLICY.md.
- Policy-format follow-ups: none.

## Codebase Confirmation

- self-review: docs/review/autopilot/EQM-090_SELF_REVIEW_2026-06-18.md; target files present: editor/timeline_dock.tscn, editor/timeline_dock.gd, tests/ui_headless/; target files missing: none detected by path scan.
- Implementation follow-ups: editor surface は headless Controls として実装/検証済みだが、EditorPlugin live dock mounting は未実装.

## 追加要件 / 未解決リスク

- 欠落 planning artifact を補完する: SUB_TASKS.md, UX.md, POLICY.md
- editor surface は headless Controls として実装/検証済みだが、EditorPlugin live dock mounting は未実装
