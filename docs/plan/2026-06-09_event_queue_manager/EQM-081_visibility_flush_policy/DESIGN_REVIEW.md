# EQM-081 Design Review

Policy: `docs/devflow/policy/DESIGN_REVIEW_POLICY.md`  
Review date: 2026-06-19  
Tests: not rerun per user instruction; this review uses queue proof, self-review, and codebase file inspection.

| 項目 | 記録 |
|---|---|
| 対象 | `docs/plan/2026-06-09_event_queue_manager/EQM-081_visibility_flush_policy/` |
| 主分類 | transaction / presentation |
| 判断 | `needs_design_update` |
| queue status | `COMPLETE` |
| 採用判断 | Importance/sensing/offscreen presentation policy. |
| 棄却 / 延期判断 | 旧UX/暫定contractは設計内の reject/defer/self-review に従う。追加の互換維持要求は見つからない。 |
| 実装固定点 | Important event flushes previous visuals; sensed non-important defers; offscreen skips; player turn flush tested. |
| control surface | queue target files と public API surface に限定。 |
| test gate | テスト再実行なし。queue proof log / self-review の `./tools/test.sh` PASS または docs-only gate を参照。 |
| product proof gate | Important event flushes previous visuals; sensed non-important defers; offscreen skips; player turn flush tested. |
| proof grade | `contract_tested` |
| provisional contract | provisional contract の互換維持要求なし。置換/延期は packet または self-review の記録どおり。 |

## Design Artifact Review

- Source files before this review: IMPLEMENTATION_PLAN.md, POLICY.md, SUB_TASKS.md, UX.md.
- Complexity: 未記載.
- Artifact gaps: none.
- Policy-format follow-ups: SUB_TASKS.md に Complexity header がない, UX.md に UX Candidate Matrix がない, POLICY.md に Fallback / Mirror Handling がない.

## Codebase Confirmation

- self-review: docs/review/autopilot/EQM-081_SELF_REVIEW_2026-06-18.md; target files present: resources/eq_presentation_policy.gd, runtime/eq_presentation_buffer.gd, tests/presentation/; target files missing: none detected by path scan.
- Implementation follow-ups: none.

## 追加要件 / 未解決リスク

- SUB_TASKS.md に Complexity header がない
- UX.md に UX Candidate Matrix がない
- POLICY.md に Fallback / Mirror Handling がない
