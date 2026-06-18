# EQM-014 Design Review

Policy: `docs/devflow/policy/DESIGN_REVIEW_POLICY.md`  
Review date: 2026-06-19  
Tests: not rerun per user instruction; this review uses queue proof, self-review, and codebase file inspection.

| 項目 | 記録 |
|---|---|
| 対象 | `docs/plan/2026-06-09_event_queue_manager/EQM-014_event_model_semantics/` |
| 主分類 | policy / progression design |
| 判断 | `pass_with_followups` |
| queue status | `COMPLETE` |
| 採用判断 | Event model semantics spec, progression (event-line) model, and ordering coverage matrix. |
| 棄却 / 延期判断 | 旧UX/暫定contractは設計内の reject/defer/self-review に従う。追加の互換維持要求は見つからない。 |
| 実装固定点 | Builds on the confirmed three-plane model (docs/design/EVENT_MODEL_CONCEPTS.md: event-line = progression input / event = ordered output / event_line_progressed = trace observation) and records adopted/rejected for all EVENT_MODEL_OPEN_QUESTIONS.md items per the 2026-06-14 decisions (docs/review/EVENT_MODEL_OPEN_QUESTIONS_SYNTHESIS_2026-06-14.md), including the Q26 event-line identity/granularity/lifecycle resolution. Reserves these contracts in Phase1/2 (backend impl may defer to Phase4/5 with no later backward-incompat break): (1) **event-line** = acceptance-defined incremental integer progression; global tick = primary event-line; event-side issuance allowed; per-entity event-line is acceptance-defined, not a built-in required field; invariant: event-line = progression input, master timeline = resolution output via single int comparator (tick/priority/sequence), due_tick rewrite forbidden (reschedule-only). (2) **solve_conditions (AND default) / invalidation_conditions (OR default)**; AND-invalidation via decremental counter event-line; OR-resolution via race pattern with a race-group id and the 3-display separation concept contract (EQM debug / game-dev debug / presentation). (3) **composite resolution comparator hook**: acceptance-provided deterministic key from serializable state (float allowed here only, never in core ordering key; live-object refs forbidden; golden-covered); final fallback = event issuance order on the default event-line; simultaneous/parallel issuance forbidden. (4) **sweep point** = post-event-resolution collection window; eager = trigger-type invalidation condition. (5) **reentrancy spec** unifying window nest (meta-cost budget, Q02) and trigger nest (bounded round + cycle guard, EQM-062), crossing cases in scope with provisional cost design. (6) **save boundary** = empty effect-processing-chunk (chunk added at resolution not issuance; window-open clears); equals an allowed sync barrier. (7) trace record kinds incl. event_line_progressed, window_opened, window_closed, invalidation closed_by. Coverage matrix maps >= 8 systems (CTB, energy, wait-turn TO/FFT-CT, FE phase, 4X phase, stack/LIFO, Pokemon-style speed turn, ATB, 行動解決ターン制); grouped/micro-event-line (Q24) and sync-barrier naming (Q25) recorded as deferred/support; unmappable cases become queue candidates before the Phase 2 API freeze. Planning note: this is a C5 task — split into SUB_TASKS at planning time (e.g. event-line + conditions contract / reentrancy + save + trace-kind / coverage matrix) per docs/devflow/TASK_PACKET.md. **Split 2026-06-15 (user-approved) into EQM-014.01/.02/.03** (umbrella row; COMPLETE via the three sub-tasks, all COMPLETE 2026-06-15). |
| control surface | queue target files と public API surface に限定。 |
| test gate | テスト再実行なし。queue proof log / self-review の `./tools/test.sh` PASS または docs-only gate を参照。 |
| product proof gate | Builds on the confirmed three-plane model (docs/design/EVENT_MODEL_CONCEPTS.md: event-line = progression input / event = ordered output / event_line_progressed = trace observation) and records adopted/rejected for all EVENT_MODEL_OPEN_QUESTIONS.md items per the 2026-06-14 decisions (docs/review/EVENT_MODEL_OPEN_QUESTIONS_SYNTHESIS_2026-06-14.md), including the Q26 event-line identity/granularity/lifecycle resolution. Reserves these contracts in Phase1/2 (backend impl may defer to Phase4/5 with no later backward-incompat break): (1) **event-line** = acceptance-defined incremental integer progression; global tick = primary event-line; event-side issuance allowed; per-entity event-line is acceptance-defined, not a built-in required field; invariant: event-line = progression input, master timeline = resolution output via single int comparator (tick/priority/sequence), due_tick rewrite forbidden (reschedule-only). (2) **solve_conditions (AND default) / invalidation_conditions (OR default)**; AND-invalidation via decremental counter event-line; OR-resolution via race pattern with a race-group id and the 3-display separation concept contract (EQM debug / game-dev debug / presentation). (3) **composite resolution comparator hook**: acceptance-provided deterministic key from serializable state (float allowed here only, never in core ordering key; live-object refs forbidden; golden-covered); final fallback = event issuance order on the default event-line; simultaneous/parallel issuance forbidden. (4) **sweep point** = post-event-resolution collection window; eager = trigger-type invalidation condition. (5) **reentrancy spec** unifying window nest (meta-cost budget, Q02) and trigger nest (bounded round + cycle guard, EQM-062), crossing cases in scope with provisional cost design. (6) **save boundary** = empty effect-processing-chunk (chunk added at resolution not issuance; window-open clears); equals an allowed sync barrier. (7) trace record kinds incl. event_line_progressed, window_opened, window_closed, invalidation closed_by. Coverage matrix maps >= 8 systems (CTB, energy, wait-turn TO/FFT-CT, FE phase, 4X phase, stack/LIFO, Pokemon-style speed turn, ATB, 行動解決ターン制); grouped/micro-event-line (Q24) and sync-barrier naming (Q25) recorded as deferred/support; unmappable cases become queue candidates before the Phase 2 API freeze. Planning note: this is a C5 task — split into SUB_TASKS at planning time (e.g. event-line + conditions contract / reentrancy + save + trace-kind / coverage matrix) per docs/devflow/TASK_PACKET.md. **Split 2026-06-15 (user-approved) into EQM-014.01/.02/.03** (umbrella row; COMPLETE via the three sub-tasks, all COMPLETE 2026-06-15). |
| proof grade | `schema_only` |
| provisional contract | provisional contract の互換維持要求なし。置換/延期は packet または self-review の記録どおり。 |

## Design Artifact Review

- Source files before this review: SUB_TASKS.md.
- Complexity: 未記載.
- Artifact gaps: UX.md, POLICY.md, IMPLEMENTATION_PLAN.md.
- Policy-format follow-ups: SUB_TASKS.md に Complexity header がない.

## Codebase Confirmation

- self-review: docs/review/autopilot/EQM-014.01_SELF_REVIEW_2026-06-15.md, docs/review/autopilot/EQM-014.02_SELF_REVIEW_2026-06-15.md, docs/review/autopilot/EQM-014.03_SELF_REVIEW_2026-06-15.md; target files present: docs/design/EVENT_MODEL_SEMANTICS.md, docs/design/ORDERING_MODEL_COVERAGE.md, docs/design/EVENT_MODEL_OPEN_QUESTIONS.md, docs/design/EVENT_MODEL_CONCEPTS.md; target files missing: none detected by path scan.
- Implementation follow-ups: umbrella task は EQM-014.01/.02/.03 で解決済み。umbrella 自身の UX/POLICY/IMPLEMENTATION_PLAN はない.

## 追加要件 / 未解決リスク

- 欠落 planning artifact を補完する: UX.md, POLICY.md, IMPLEMENTATION_PLAN.md
- SUB_TASKS.md に Complexity header がない
- umbrella task は EQM-014.01/.02/.03 で解決済み。umbrella 自身の UX/POLICY/IMPLEMENTATION_PLAN はない
