# EQM-014.02 IMPLEMENTATION_PLAN

Design resolution lives in the umbrella `../EQM-014_event_model_semantics/SUB_TASKS.md`. This plan covers the coverage-matrix slice.

## Scope

Author `docs/design/ORDERING_MODEL_COVERAGE.md`: map ≥8 ordering systems onto the v1 semantics (`EVENT_MODEL_SEMANTICS.md`), proving the model's generality (without mandating every system reduce). Each row resolves to **mapped** or **queue-candidate**. Verify the two flagged points: 4X concurrent theaters (Q13) and 行動解決ターン制 (the core test case). Record grouped/micro-event-line (Q24) deferred and sync-barrier (Q25) support. Any unmappable case becomes a Phase-2-freeze-gating queue candidate.

## 変更対象ファイル

- `docs/design/ORDERING_MODEL_COVERAGE.md` (new).

## 実装 steps

1. For each system, state: event-line representation (first-class / sweep), solve/invalidation conditions, comparator-hook usage, window/deadline, tie-break, and verdict.
2. Verify CTB, Energy, WT(TO/FFT-CT), FE phase, 4X, Stack/LIFO, Pokémon-speed, ATB, 行動解決ターン制.
3. Record Q24 deferred / Q25 support.
4. Collect any unmappable case as a queue candidate (none expected; confirm).
5. `./tools/test.sh` remains green.

## Test path / gate

- docs-only: every matrix row mapped-or-queue-candidate; 4X and 行動解決ターン制 shown mappable.
- `./tools/test.sh` green.

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| `EVENT_MODEL_SEMANTICS.md` (014.01) | mapping uses an undefined contract | each row cites the semantics section it uses |
| Q13 4X | concurrent theaters need multiple timelines | 4X row maps via N event-lines + shared primary tick; desyncable timelines explicitly out of scope |
| 行動解決ターン制 | core case unmappable | AP-recovery event-line + ready reservation + reaction-count decremental invalidation |
| reducibility (EQM-053) | next-threshold advance ≠ per-tick trace | flagged as a deferred proof owned by EQM-053, not a new candidate |

## Completion checklist

- [ ] ≥8 systems mapped; every row has a verdict.
- [ ] 4X (Q13) and 行動解決ターン制 shown mappable.
- [ ] Q24 deferred / Q25 support recorded.
- [ ] unmappable cases (if any) recorded as Phase-2-freeze-gating queue candidates.
- [ ] `./tools/test.sh` green.
