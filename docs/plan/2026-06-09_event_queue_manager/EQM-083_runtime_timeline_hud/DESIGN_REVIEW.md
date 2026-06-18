# EQM-083 Design Review

Policy: `docs/devflow/policy/DESIGN_REVIEW_POLICY.md`  
Review date: 2026-06-19  
Tests: not rerun per user instruction; this review uses queue proof, self-review, and codebase file inspection.

| 項目 | 記録 |
|---|---|
| 対象 | `docs/plan/2026-06-09_event_queue_manager/EQM-083_runtime_timeline_hud/` |
| 主分類 | runtime UI / UX |
| 判断 | `needs_design_update` |
| queue status | `COMPLETE` |
| 採用判断 | Player-facing runtime timeline HUD + consumer runtime debug overlay. |
| 棄却 / 延期判断 | 旧UX/暫定contractは設計内の reject/defer/self-review に従う。追加の互換維持要求は見つからない。 |
| 実装固定点 | HUD renders injected prediction (projection integrity in-game); updates on queue_changed; shows explicit stale state while presentation is deferred; controls carry ui_metric_id metadata; no UI-side order recomputation; HUD labels are localizable and order/state uses non-text modality (icon/badge) for colorblind/screen-reader safety; a separate opt-in debug overlay/log hook lets a developer inspect the live order and "why next" in their own game. |
| control surface | queue target files と public API surface に限定。 |
| test gate | テスト再実行なし。queue proof log / self-review の `./tools/test.sh` PASS または docs-only gate を参照。 |
| product proof gate | HUD renders injected prediction (projection integrity in-game); updates on queue_changed; shows explicit stale state while presentation is deferred; controls carry ui_metric_id metadata; no UI-side order recomputation; HUD labels are localizable and order/state uses non-text modality (icon/badge) for colorblind/screen-reader safety; a separate opt-in debug overlay/log hook lets a developer inspect the live order and "why next" in their own game. |
| proof grade | `editor_projection_verified` |
| provisional contract | provisional contract の互換維持要求なし。置換/延期は packet または self-review の記録どおり。 |

## Design Artifact Review

- Source files before this review: IMPLEMENTATION_PLAN.md, POLICY.md, SUB_TASKS.md.
- Complexity: C3.
- Artifact gaps: UX.md.
- Policy-format follow-ups: none.

## Codebase Confirmation

- self-review: docs/review/autopilot/EQM-083_SELF_REVIEW_2026-06-18.md; target files present: runtime/ui/eq_timeline_hud.gd, runtime/ui/eq_timeline_hud.tscn, runtime/ui/eq_debug_overlay.gd, tests/ui_headless/; target files missing: none detected by path scan.
- Implementation follow-ups: none.

## 追加要件 / 未解決リスク

- 欠落 planning artifact を補完する: UX.md
