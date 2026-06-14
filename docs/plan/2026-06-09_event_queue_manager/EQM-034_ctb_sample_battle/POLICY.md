# EQM-034 POLICY

## 採用判断

- **demos/ctb_battle**: `ctb_battle.gd` (extends Node, class_name なし、path load) + `ctb_battle.tscn` (root に script)。public API のみ (EQManager/EQConfig/EQCTBPolicy/EQActionResult/EQPrediction)。冒頭に LEARNING-PATH 明記。
- **demo golden trace**: `tests/golden/demo_ctb_battle.trace.jsonl`。demo を headless で run_trace し exact 比較。更新は `--update-golden demo_ctb_battle` のみ (DETERMINISM §2/§5)。
- **quickstart.md**: project-created config の手順。bundled sample default に依存しない。
- **symlink**: `test_project/demos -> ../demos` で res://demos 到達 (addon symlink と同様)。
- demo は class_name を持たない → API surface に出ない。

## 不採用判断

- sample preset を production 既定化 (sample-only completion 禁止)。
- demo が runtime internal (`_` prefix) に触れる。
- 通常 run での demo golden 自動更新。

## Invariants

- demo は public API のみ使用 (runtime internal 不参照)。
- demo trace は決定的 (golden 一致)、faster actor が先行。
- quickstart は project-created config 経路 (silent default なし)。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| demo trace | 決定的・golden 一致 | 非決定 / regression | demo_ctb_battle.trace.jsonl exact 比較 |
| demo API 使用 | public のみ | internal 依存 | demo は preload public class のみ |
| quickstart | project-created config | sample default 依存 | docs レビュー (code 例が config 作成) |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| demo golden 不一致 | FAIL + 再 baseline 手順 | regression 検出 | — | exact 比較 |
| Godot 不在 | (本 env では在) | — | — | BLOCKED_BY_TEST_ENV は不要 (Godot 4.6.2 在) |
