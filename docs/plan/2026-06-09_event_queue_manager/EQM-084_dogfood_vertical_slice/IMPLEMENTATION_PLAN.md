# EQM-084 IMPLEMENTATION_PLAN

## Scope

public API のみの Action Resolution dogfood slice + golden + friction report。runtime internal 不参照。

## 変更対象ファイル

- `dogfood/action_resolution/battle.gd` — slice (public API のみ)。
- `dogfood/action_resolution/README.md` — dogfood 説明。
- `test_project/dogfood` — symlink (作成済み)。
- `tests/golden/dogfood_action_resolution.trace.jsonl` — golden (`--update-golden`)。
- `docs/review/DOGFOOD_FRICTION_2026-06-18.md` — friction findings (candidate / no-change)。
- `test_project/tests/debug_scene/test_dogfood_action_resolution.gd` — headless run + golden 比較 + public-API-only 確認。

## 実装 steps

1. battle.gd: AP policy で turns、1 reservation (prepared)、1 reaction (counter via trigger engine + condition)、effect record + presentation event、RNG (deterministic damage)。combined canonical trace を EQTrace で出力。
2. README + friction report。
3. golden test。
4. `./tools/test.sh --update-golden dogfood_action_resolution`。
5. 通常 `./tools/test.sh` PASS。

## Test path / gate

- §4 demo/dogfood: headless golden trace。public API のみ (preload が public class のみ)。
- 期待: 既存 504 + 新 checks、api-surface ok (battle.gd は class_name なし→surface 不変)、exit 0。

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| public API (Phase 1-8) | internal 依存 | battle.gd は public class のみ preload |
| Phase 8 records 結線 | 未結線 (review 観察) | battle が EffectRecord/PresentationBuffer を実生成 |
| DETERMINISM §5 | 非決定 | golden exact + RNG seeded |
| friction recording | 隠蔽 | 各 finding を candidate/no-change 明記 |

## Completion checklist

- [ ] slice が public API のみで AR battle を構成 (reservation/trigger/transaction-opt/presentation/AP/RNG)。
- [ ] golden trace 一致、決定的。
- [ ] friction report が findings を candidate / no-change として記録。
- [ ] Phase 8 records が実 consumer flow で生成される。
- [ ] `./tools/test.sh` PASS。
