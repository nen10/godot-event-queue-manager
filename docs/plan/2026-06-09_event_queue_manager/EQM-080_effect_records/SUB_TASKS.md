# EQM-080 SUB_TASKS

## Complexity

Class: C3 (orchestrator-direct — simulation/presentation 分離の基盤)
Reason:
- EffectRecord (simulation truth, trace) / PresentationEvent (visual request) の分離と effect-processing-chunk (§10/§22 save 境界) を確立。EQM-081/082 が乗る。
- 設計分岐は plan (phase-8-glimmering-wren.md) で user 合意済み。

Required artifacts: Complexity header / Task Resolution / UX (最小) / POLICY / IMPLEMENTATION_PLAN。承認済み plan が設計の上位ソース。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQEffectRecord (core) | simulation 側の即時・決定的 effect | adopt | kind/source/target/stat/delta(int)/tags/classification + to_trace_record + to_dict/from_dict。 |
| EQEffectChunk (core) | 解決時 effect 蓄積 + save 境界 | adopt | add/records/is_empty/clear/drain + `is_save_allowed()=is_empty` (§10/§22)。 |
| EQPresentationEvent (presentation) | 視覚要求 (queue 分離) | adopt | actor_id + position snapshot(値) + classification + tags + changes_position_of/depends_on + transient bind。to_dict は live ref なし。 |
| classification = consumer 供給 field | Q12 simulation 側 deterministic | adopt | CLASS_IMPORTANT/SENSED/OFFSCREEN 定数。addon は spatial 計算せず。 |
| chunk を EQM-085 へ defer | — | reject | user 決定: EQM-080 で chunk + is_save_allowed を確立 (縮小回避)。 |

## Scheduled Task Audit

新規 scheduled task なし。次の依存解放は EQM-081 (flush policy)。effect-chunk の save adapter 連携は EQM-085。
