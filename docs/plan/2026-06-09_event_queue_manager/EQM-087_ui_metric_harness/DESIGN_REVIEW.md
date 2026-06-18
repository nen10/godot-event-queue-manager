# EQM-087 Design Review

Policy: `docs/devflow/policy/DESIGN_REVIEW_POLICY.md`  
Review date: 2026-06-19  
Tests: not rerun per user instruction; this review uses queue proof, self-review, and codebase file inspection.

| 項目 | 記録 |
|---|---|
| 対象 | `docs/plan/2026-06-09_event_queue_manager/EQM-087_ui_metric_harness/` |
| 主分類 | editor UI / UX |
| 判断 | `needs_design_update` |
| queue status | `COMPLETE` |
| 採用判断 | UI static audit + layout snapshot collector + WARN-only metric report (adoption M1-M3). |
| 棄却 / 延期判断 | 旧UX/暫定contractは設計内の reject/defer/self-review に従う。追加の互換維持要求は見つからない。 |
| 実装固定点 | Static audit runs inside ./tools/test.sh; collector produces snapshot JSON for a synthetic scenario Control tree; evaluator reports metrics WARN-only; report written under .godot_user/test-runs/. |
| control surface | queue target files と public API surface に限定。 |
| test gate | テスト再実行なし。queue proof log / self-review の `./tools/test.sh` PASS または docs-only gate を参照。 |
| product proof gate | Static audit runs inside ./tools/test.sh; collector produces snapshot JSON for a synthetic scenario Control tree; evaluator reports metrics WARN-only; report written under .godot_user/test-runs/. |
| proof grade | `editor_projection_verified` |
| provisional contract | provisional contract の互換維持要求なし。置換/延期は packet または self-review の記録どおり。 |

## Design Artifact Review

- Source files before this review: IMPLEMENTATION_PLAN.md, SUB_TASKS.md.
- Complexity: C5.
- Artifact gaps: UX.md, POLICY.md.
- Policy-format follow-ups: C5 だが dependency / test matrix がない.

## Codebase Confirmation

- self-review: docs/review/autopilot/EQM-087_SELF_REVIEW_2026-06-18.md; target files present: tools/ui_static_audit.py, addons/event_queue_manager/editor/testing/, tests/ui_headless/; target files missing: none detected by path scan.
- Implementation follow-ups: none.

## 追加要件 / 未解決リスク

- 欠落 planning artifact を補完する: UX.md, POLICY.md
- C5 だが dependency / test matrix がない
