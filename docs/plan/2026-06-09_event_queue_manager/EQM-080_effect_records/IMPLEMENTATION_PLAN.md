# EQM-080 IMPLEMENTATION_PLAN

## Scope

EQEffectRecord + EQEffectChunk (core) と EQPresentationEvent (presentation) を実装。flush policy は EQM-081、barrier は EQM-082。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_effect_record.gd` — `EQEffectRecord` (core)。
- `addons/event_queue_manager/runtime/eq_effect_chunk.gd` — `EQEffectChunk` (core)。
- `addons/event_queue_manager/runtime/eq_presentation_event.gd` — `EQPresentationEvent` (presentation)。
- `tools/check_api_surface.py` — LAYER_MAP に EffectRecord/Chunk=core, PresentationEvent=presentation; LAYERS に "presentation" 追加。
- `docs/design/API_SURFACE.md` — presentation layer 行追加。
- `tests/golden/api_surface.json` — `--update`。
- `test_project/tests/presentation/test_eq_effect_record.gd`, `test_eq_presentation_event.gd` — record/chunk/save-boundary + presentation event refs。

## 実装 steps

1. EQEffectRecord (fields + CLASS_* 定数 + to_trace_record + to_dict/from_dict)。
2. EQEffectChunk (add/records/is_empty/clear/drain/is_save_allowed)。
3. EQPresentationEvent (fields + bind/bound transient + to_dict/from_dict)。
4. LAYER_MAP (+LAYERS "presentation") + API_SURFACE.md。
5. tests。
6. `python3 tools/check_api_surface.py --update`。
7. `./tools/test.sh` PASS。

## Test path / gate

- §4 gate (presentation/resource): 即時記録 / chunk save-boundary / presentation event 分離 + actor/position ref / trace canonical。
- §4 gate (API surface): new classes layer 付与、no L3 leak。
- 期待: 既存 407 + 新 checks、api-surface ok、exit 0。

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| EQTrace open-kind (EQM-013) | trace record 非 canonical | to_trace_record が sorted-key で安定 |
| §10/§22 save 境界 | chunk-save 結線漏れ | is_save_allowed=is_empty |
| Adapter 原則 | live ref 漏洩 | to_dict に Node なし、position 値 |
| Q12 classification | addon 内計算 | classification は供給 field |
| API surface gate | layer 未付与/leak | presentation layer、no L3 leak、明示 --update |

## Completion checklist

- [ ] EffectRecord 即時・決定的、to_trace_record canonical。
- [ ] EQEffectChunk: add/drain/is_save_allowed (=is_empty)。
- [ ] PresentationEvent: actor_id + position 値 + classification + changes/depends, live ref なし。
- [ ] presentation layer を api-surface に追加、golden 明示更新、no L3 leak。
- [ ] `./tools/test.sh` PASS。
