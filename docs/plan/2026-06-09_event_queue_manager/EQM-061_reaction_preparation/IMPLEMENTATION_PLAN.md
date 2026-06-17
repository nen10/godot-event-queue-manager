# EQM-061 IMPLEMENTATION_PLAN

## Scope

EQTriggerEngine (arm / sweep-point fire / duration expire / owner-source matching) を実装する。rumination + cycle guard は EQM-062。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_trigger_engine.gd` — `EQTriggerEngine` (L2)。
- `tools/check_api_surface.py` — LAYER_MAP に `EQTriggerEngine: L2`。
- `docs/design/API_SURFACE.md` — L2 表に追記。
- `tests/golden/api_surface.json` — `--update`。
- `test_project/tests/trigger/test_eq_trigger_engine.gd` — fire-on-damage / duration expire / owner-source / one-shot / sweep。

## 実装 steps

1. EQTriggerEngine: _armed[] {reservation, condition, owner, armed_at, duration}; arm; on_event_resolved (expire→fire→fired); _expire; armed_count。
2. LAYER_MAP + API_SURFACE.md。
3. test。
4. `python3 tools/check_api_surface.py --update`。
5. `./tools/test.sh` PASS。

## Test path / gate

- §4 gate (trigger): counterattack on incoming damage / duration expiry prevents trigger / owner-source matching / one-shot / sweep-point-only。
- §4 gate (API surface): EQTriggerEngine L2、no L3 leak。
- 期待: 既存 344 + 新 checks、api-surface ok、exit 0。

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| EQCondition (EQM-060) | 照合誤り | condition.matches で発火判定 |
| EQReservation REACTION_PREPARATION (EQM-050) | 武装対象不整合 | arm が ARMED 化、duration/ruminations 参照 |
| SEMANTICS §5/§6 (invalidation/sweep) | 意味論逸脱 | expire 先・fire 後、sweep point 発火 |
| API surface gate | 無断変更 | 明示 --update、L2、no L3 leak |

## Completion checklist

- [ ] counterattack が incoming `<損害>` reservation/event の解決後に発火。
- [ ] duration expiry が発火を防ぐ (expired は撃たない)。
- [ ] owner/source matching (target=owner 発火、自傷/他者 target 非発火)。
- [ ] one-shot (二重発火なし)、sweep point のみ。
- [ ] EQTriggerEngine L2、golden 明示更新、self-review に diff。
- [ ] `./tools/test.sh` PASS。
