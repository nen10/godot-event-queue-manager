# EQM-014.01 IMPLEMENTATION_PLAN

Design resolution (task resolution / adopted-rejected / contract groups) lives in the umbrella `../EQM-014_event_model_semantics/SUB_TASKS.md` (user-reviewed 2026-06-15). This plan covers only the spec-authoring slice.

## Scope

Author `docs/design/EVENT_MODEL_SEMANTICS.md` as the authoritative v1 semantics that Phase 2/5 build on. Records the 7 contract groups + driver/await + Q03 deadline window + numeric/lifecycle/guardrails + L0–L3 layering, consistent with `EVENT_MODEL_CONCEPTS.md` and the 2026-06-14 registry decisions. **Contracts/schema/trace-kinds are reserved in Phase1/2; backend impl is deferred to Phase4/5 with no later backward-incompat break.** No coverage matrix (014.02), no registry edits (014.03).

## 変更対象ファイル

- `docs/design/EVENT_MODEL_SEMANTICS.md` (new).

## Doc structure (sections)

1. Status / scope / inputs.
2. Three-plane model recap + L0–L3 layering.
3. Master timeline & ordering (int comparator, immutability, reschedule-only).
4. Event-line contract (primary tick; event-side issuance; per-entity not built-in; two progression representations; watched/sparse polling; identity & lifecycle Q26; advance method Q17, N deferred).
5. Conditions (solve AND / invalidation OR; AND-invalidation = decremental counter; OR-resolution = race pattern + race-group id + 3-display separation; eager = trigger-type invalidation).
6. Sweep point (post-resolution collection window).
7. Composite events & comparator hook (atomic; member order via hook; float allowed here only; fallback = issuance order; parallel forbidden).
8. Reentrancy spec (window nest meta-cost budget + trigger nest bounded round/cycle guard, unified; crossing provisional).
9. Window & deadline (Q03; frozen = deadline ∞).
10. Save boundary (empty effect-processing-chunk; chunk at resolution; window-open clears; = allowed sync barrier).
11. Trace record kinds (event_line_progressed / window_opened / window_closed / closed_by; ties to EQM-013 open schema).
12. Numeric domain (int only; float never in core ordering).
13. Actor lifecycle (no actor_id reuse).
14. Driver / await contract (EQM-032 reference; suspend; await boundary; frame-budget advance).
15. Over-generalization guardrails (Q23).
16. Phase1/2 reservation vs Phase4/5 implementation boundary.
17. References.

## Test path / gate

- docs-only acceptance: contract consistency (no Godot run required for content).
- `./tools/test.sh` must remain green (docs change must not break the build/tests).

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| `EVENT_MODEL_CONCEPTS.md` 三面モデル | spec が concepts と矛盾 | 各面の責務・one-way valve を spec が踏襲、用語一致 |
| registry 2026-06-14 decisions | 決定の取りこぼし/改変 | 7 契約群 + Q03/Q10/Q11/Q23 を網羅、決定値と一致 |
| EQM-010/011/012/013 core | 契約が実装と乖離 | ordering key/ reschedule-only/ snapshot schema/ trace-kind open を spec が参照整合 |
| Phase2/5 後方互換 | freeze 後に破壊的変更 | 「予約 vs 実装」境界節で何が契約・何が deferred かを明記 |

## Completion checklist

- [ ] 7 契約群すべてを矛盾なく記述。
- [ ] L0–L3 layering と「L3 を L0/L1 surface に leak させない」を明記。
- [ ] Phase1/2 予約 / Phase4/5 実装の境界を明記 (後方互換破壊なし)。
- [ ] CONCEPTS と用語・不変条件が一致。
- [ ] `./tools/test.sh` green (docs change 後)。
