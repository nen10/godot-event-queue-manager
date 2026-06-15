# EQM-051 IMPLEMENTATION_PLAN

## Scope

reservation の scheduling/resolution pipeline (EQReservationRuntime) を実装する。condition/trigger は EQM-060/061。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_reservation.gd` — `target_id` 追加 + to_dict/from_dict。
- `addons/event_queue_manager/runtime/eq_reservation_runtime.gd` — `EQReservationRuntime` (L2)。
- `tools/check_api_surface.py` — LAYER_MAP に `EQReservationRuntime: L2`。
- `docs/design/API_SURFACE.md` — L2 表に追記。
- `tests/golden/api_surface.json` — `--update`。
- `test_project/tests/core/test_eq_reservation_runtime.gd` — immediate/prepared/wait/operation/reaction-arm。

## 実装 steps

1. EQReservation に target_id 追加 (+ roundtrip)。
2. EQReservationRuntime (submit kind 別 + resolve_next + _cause_target_reservation + armed_for)。
3. LAYER_MAP + API_SURFACE.md。
4. test。
5. `python3 tools/check_api_surface.py --update`。
6. `./tools/test.sh` PASS。

## Test path / gate

- §4 gate (core): immediate=delay0 / prepared=delay / wait→ready / operation→target reservation / reaction arm。
- §4 gate (API surface): EQReservationRuntime L2、target_id。
- 期待: 既存 291 + 新 checks、api-surface ok、exit 0。

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| EQM-050 schema | kind 解釈ずれ | 各 kind の scheduling/resolution |
| EQRuntime (EQM-022) | wrap 不整合 | submit が runtime.schedule、resolve が advance |
| SEMANTICS §5-§7 | 意味論逸脱 | wait→ready, operation→target を §5-§7 に整合 |
| API surface gate | 無断変更 | 明示 --update、L2、no L3 leak |

## Completion checklist

- [ ] immediate が delay 0 で解決。
- [ ] prepared が delay 後に解決。
- [ ] wait が ready 予約を schedule。
- [ ] operation が target に reservation を起こす。
- [ ] reaction-prep が arm (schedule されない)。
- [ ] EQReservationRuntime L2 + target_id、golden 明示更新。
- [ ] `./tools/test.sh` PASS。
