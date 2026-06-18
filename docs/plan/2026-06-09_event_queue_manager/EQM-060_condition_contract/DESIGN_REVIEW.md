# EQM-060 Design Review

Policy: `docs/devflow/policy/DESIGN_REVIEW_POLICY.md`  
Review date: 2026-06-19  
Tests: not rerun per user instruction; this review uses queue proof, self-review, and codebase file inspection.

| 項目 | 記録 |
|---|---|
| 対象 | `docs/plan/2026-06-09_event_queue_manager/EQM-060_condition_contract/` |
| 主分類 | trigger / reaction |
| 判断 | `needs_design_update` |
| queue status | `COMPLETE` |
| 採用判断 | Condition and tag matching contract. |
| 棄却 / 延期判断 | 旧UX/暫定contractは設計内の reject/defer/self-review に従う。追加の互換維持要求は見つからない。 |
| 実装固定点 | Conditions can match event type, source, target, tags, range/sensing adapter placeholder, and custom predicate. |
| control surface | queue target files と public API surface に限定。 |
| test gate | テスト再実行なし。queue proof log / self-review の `./tools/test.sh` PASS または docs-only gate を参照。 |
| product proof gate | Conditions can match event type, source, target, tags, range/sensing adapter placeholder, and custom predicate. |
| proof grade | `contract_tested` |
| provisional contract | provisional contract の互換維持要求なし。置換/延期は packet または self-review の記録どおり。 |

## Design Artifact Review

- Source files before this review: IMPLEMENTATION_PLAN.md, SUB_TASKS.md.
- Complexity: C2.
- Artifact gaps: UX.md, POLICY.md.
- Policy-format follow-ups: none.

## Codebase Confirmation

- self-review: docs/review/autopilot/EQM-060_SELF_REVIEW_2026-06-15.md; target files present: resources/eq_condition.gd, runtime/eq_tag_matcher.gd, tests/trigger/; target files missing: none detected by path scan.
- Implementation follow-ups: none.

## 追加要件 / 未解決リスク

- 欠落 planning artifact を補完する: UX.md, POLICY.md
