# EQM-050 IMPLEMENTATION_PLAN

## Scope

reservation schema (EQActionDefinition + EQReservation) と validation を実装する。pipeline は EQM-051、condition は EQM-060。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_error.gd` — reservation code 7 つ append。
- `addons/event_queue_manager/resources/eq_action_definition.gd` — `EQActionDefinition` (L2)。
- `addons/event_queue_manager/runtime/eq_reservation.gd` — `EQReservation` (L2)。
- `docs/design/ERROR_CONTRACT.md` — code 表に reservation 行追記。
- `tools/check_api_surface.py` — LAYER_MAP に `EQActionDefinition: L2`, `EQReservation: L2`。
- `docs/design/API_SURFACE.md` — L2 表を埋める。
- `tests/golden/api_surface.json` — `--update`。
- `test_project/tests/resource/test_eq_action_definition.gd` — kind 別 validation + .tres roundtrip。
- `test_project/tests/resource/test_eq_reservation.gd` — runtime instance validate + to_dict/from_dict。

## 実装 steps

1. EQError に 7 reservation code append + ERROR_CONTRACT.md。
2. EQActionDefinition (enum + fields + validate + to_dict/from_dict)。
3. EQReservation (instance + validate + to_dict/from_dict)。
4. LAYER_MAP (L2) + API_SURFACE.md。
5. tests。
6. `python3 tools/check_api_surface.py --update`。
7. `./tools/test.sh` PASS。

## Test path / gate

- §4 gate (resource/API): kind 別 validation + roundtrip + layer-aware surface (L2 populated, no L3 leak)。
- 期待: 既存 256 + 新 checks、api-surface ok、exit 0。

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| SEMANTICS §5-§7 (reservation/conditions) | schema が契約と乖離 | kind/duration/operation を §5-§7 に整合 |
| EQM-020 EQError/EQValidation | code 不整合 | 7 code の recoverability/severity assert |
| EQM-012 直列化規律 | live ref 漏洩 | to_dict に Node なし、roundtrip |
| API surface gate (EQM-023) | L2 未登録 / L3 leak | L2 列に 2 class、leak なし、明示 --update |

## Completion checklist

- [ ] 6 kind の validation 制約 (immediate/prepared/reaction/wait/ready/operation)。
- [ ] tags/duration/rumination field の validation (duration -1=∞)。
- [ ] EQActionDefinition `.tres` roundtrip、EQReservation to_dict/from_dict (live ref なし)。
- [ ] 7 reservation code が EQError + ERROR_CONTRACT に存在。
- [ ] L2 surface 2 class、L3 leak なし、golden 明示更新。
- [ ] `./tools/test.sh` PASS。
