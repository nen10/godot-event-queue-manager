# EQM-014.03 IMPLEMENTATION_PLAN

Design resolution lives in the umbrella `../EQM-014_event_model_semantics/SUB_TASKS.md`. This plan covers the registry/concepts finalization slice. Terminal task of the EQM-014 group — its completion gates the Phase 2 API freeze and unblocks EQM-020.

## Scope

Finalize the decision record so the registry is unambiguous at freeze:

- `EVENT_MODEL_OPEN_QUESTIONS.md`: add a finalization banner (semantics confirmed 2026-06-15 in SEMANTICS + COVERAGE) and the **adopted/rejected → SEMANTICS section pointer map** for Q01–Q26 (closing the doc's own stated purpose: "本 file の項目は決定への pointer に置き換える"). Sharpen Q17 (prediction-depth-N deferred to EQM-033/102). Confirm Q24 deferred / Q25 support.
- `EVENT_MODEL_CONCEPTS.md`: reconcile the Q26 pointer — Q26 is now `DECIDED(user)`, so the "未決の identity/scaling は Q26 が持つ" lines point to the settled decision (SEMANTICS §4.2/§4.5) instead of "unresolved".

The index status table (already settled) is the status-of-record; no per-Q header rewrite needed beyond the pointer map and the two reconciliations.

## 変更対象ファイル

- `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md` — finalization banner + pointer map + Q17 defer note.
- `docs/design/EVENT_MODEL_CONCEPTS.md` — Q26 pointer reconciliation.

## Test path / gate

- docs-only: Q01–Q26 each at a settled status with a pointer to where the decision is recorded; Q17/Q24/Q25 defer/support explicit; CONCEPTS no longer calls Q26 unresolved.
- `./tools/test.sh` green.

## Completion checklist

- [ ] finalization banner added (semantics confirmed; SEMANTICS + COVERAGE authoritative).
- [ ] adopted/rejected → SEMANTICS pointer map for all Q01–Q26.
- [ ] Q17 prediction-depth-N defer to EQM-033/102 explicit; Q24 deferred / Q25 support confirmed.
- [ ] CONCEPTS Q26 pointer reconciled to the settled decision.
- [ ] Phase 2 API freeze recorded as unblocked (EQM-020 dep satisfied).
- [ ] `./tools/test.sh` green.
