# EQM-116 IMPLEMENTATION_PLAN — race pattern

## Scope

SEM §5.2 実装 (coverage row: race-pattern)。表示分離は trace + overlay 集約の最小実装。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_reservation_runtime.gd` (+submit_race / 勝者確定・敗者一掃 / trace)
- `addons/event_queue_manager/runtime/ui/eq_debug_overlay.gd` (+race_group 集約 row)
- `test_project/tests/trigger/test_eq_race_pattern.gd` (new)
- surface golden (明示 --update) / coverage flip / queue / self-review

## 実装 steps

1. race 帳簿 + submit_race + _settle_race (+_trace_invalidated の race_group field)。
2. overlay 集約。
3. tests (単独勝者 / 同時成立 = 発行順 / hook 勝者 / 敗者 trace / gid 決定性 / overlay 集約 / 2-run byte 同一)。
4. `./tools/test.sh` → surface --update → coverage flip → queue → self-review → commit。

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| §7.1 hook との合成 | race 側での二重順序付け | hook 勝者 test (専用規則なし) |
| 効果の単一適用 | 勝者確定前に複数 push | 同時成立で 1 効果 test |
| UI metric 群 | overlay 変更での既存 metric 退行 | ui_headless 群 green |

## Completion checklist (planned)

- [ ] submit_race + 一掃 + trace / overlay 集約 / tests green / surface ok / coverage flip / queue / self-review / commit
