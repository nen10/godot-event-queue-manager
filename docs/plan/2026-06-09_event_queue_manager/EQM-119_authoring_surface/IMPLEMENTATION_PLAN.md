# EQM-119 IMPLEMENTATION_PLAN — L2 authoring surface

## Scope

SEM §5.6 凍結基準の証明 (coverage row: authoring-acceptance、最終 flip → 21/21)。product code 変更なし。

## 変更対象ファイル

- `dogfood/action_resolution/counterattack_preparation.tres` (new, 手書き)
- `dogfood/action_resolution/battle.gd` (+run_l2_trace, additive)
- `test_project/tests/resource/test_eq_authoring_acceptance.gd` (new)
- `test_project/tests/golden/authoring_counterattack.trace.jsonl` (new fixture, 明示 --update-golden)
- `docs/manual/reservations.md` / `docs/manual/action_resolution.md` (+節)
- `docs/ja/manual/reservations.md` / `docs/ja/manual/action_resolution.md` (mirror)
- coverage flip / queue (Phase 11 完了記録 + pointer → none) / self-review

## 実装 steps

1. .tres 手書き → load/validate test で構文確認。
2. dogfood run_l2_trace (決定的 scenario: 反撃 3 回消尽 → count 閉路、別 arm を 5 ターン放置 → duration 閉路)。
3. 受け入れ test + ∞ 変種 + golden 初回 baseline (明示 flag)。
4. manual EN/JA 追記。
5. `./tools/test.sh` green → coverage flip → queue 完了処理 → self-review (Q35 defer 確定を記録) → commit。

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| 手書き .tres 構文 | Godot parse 失敗 | load test (CACHE_MODE_IGNORE) |
| 既存 dogfood golden | 波及 | 既存 test green (run_trace 不変) |
| golden 手続き | 黙示 baseline | --update-golden + self-review 記載 |

## Completion checklist (planned)

- [ ] .tres + dogfood + test + golden + manual (EN/JA) / coverage 21/21 / queue Phase 11 完了 / self-review / commit
