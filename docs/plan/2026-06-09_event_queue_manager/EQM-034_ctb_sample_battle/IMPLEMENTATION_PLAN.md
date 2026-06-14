# EQM-034 IMPLEMENTATION_PLAN

## Scope

CTB sample battle (learning path) + quickstart + demo golden trace を作る。multi-genre demo suite は EQM-101。

## 変更対象ファイル

- `demos/ctb_battle/ctb_battle.gd` — Node script、public API のみ、build()/run_trace() static + _ready デモ実行。
- `demos/ctb_battle/ctb_battle.tscn` — root に script。
- `demos/ctb_battle/README.md` — learning-path 説明。
- `docs/manual/quickstart.md` — project-created config の手順。
- `test_project/demos` — symlink (作成済み)。
- `tests/golden/demo_ctb_battle.trace.jsonl` — demo golden (`--update-golden demo_ctb_battle`)。
- `test_project/tests/debug_scene/test_ctb_battle_demo.gd` — demo を headless run、golden 比較 + faster-leads。

## 実装 steps

1. demo script + .tscn + README。
2. quickstart.md。
3. debug_scene test (golden 比較、EQM-013 と同機構)。
4. `./tools/test.sh --update-golden demo_ctb_battle` で golden 生成。
5. 通常 `./tools/test.sh` で exact 一致確認。

## Test path / gate

- §4 gate (demo): headless golden trace。
- 期待: 既存 230 + demo checks、api-surface ok (demo は class_name なしで surface 不変)、exit 0。

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| public API (EQM-032/031/033) | demo が internal 依存 | demo は public class のみ preload |
| DETERMINISM §5 (demo golden) | 非決定 demo | golden exact 比較、faster leads |
| symlink | res://demos 不達 | test が demo を load 成功 |
| api surface (EQM-023) | demo が surface 汚染 | demo class_name なし、golden 不変 |

## Completion checklist

- [ ] demo は public API のみで CTB battle を構成。
- [ ] demo golden trace 一致 (faster actor 先行)、更新は明示 flag。
- [ ] quickstart は project-created config 経路。
- [ ] sample は learning-path 明記、production 既定にしない。
- [ ] `./tools/test.sh` PASS。
