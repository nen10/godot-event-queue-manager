# EQM-001 IMPLEMENTATION_PLAN

## Scope

devflow を EQM 専用化し、標準検証 harness の skeleton を用意する。runtime/API には触れない。

## 変更対象ファイル

- `docs/devflow/PROJECT_PROFILE.md` — EQM 専用・自己完結へ書き換え。
- `docs/devflow/TEST.md` — 標準コマンド・環境要件・test path・proof rule を確定。
- `tools/test.sh` — env 検出 + run-id 出力先 + Godot 欠如時 BLOCKED exit の skeleton。
- `.agents/skills/roadmap-autopilot/SKILL.md` — description の project wording + 非線形 pattern 入口。

## 実装 steps

1. `tools/` を作成し `tools/test.sh` を実装 (実行権限付与)。
2. `PROJECT_PROFILE.md` を EQM 版へ書き換え (identity / domain / principles / verification / commit policy / stop conditions)。
3. `TEST.md` を埋める (standard command / environment / test paths / proof rules / result log format)。
4. `roadmap-autopilot/SKILL.md` の description と read order を更新。
5. cross-ref が実ファイルを指すことを確認。

## Test path

- `./tools/test.sh` を実行し、Godot 欠如環境で `BLOCKED_BY_TEST_ENV` を明示して exit code 3 で終了することを観測する (これが本 task の acceptance 検証)。
- docs-only 部分は cross-ref 整合で確認。

## docs 更新

- queue proof log と self-review に結果を記す。

## Completion checklist

- [ ] PROJECT_PROFILE.md が EQM 専用・自己完結で Hex 等の無関係 domain を参照しない。
- [ ] TEST.md が標準コマンドと環境要件を定義。
- [ ] tools/test.sh が Godot 欠如時に明確に exit (code 3, BLOCKED メッセージ)。
- [ ] SKILL.md の wording が EQM。
- [ ] self-review に missing-process-file 確認結果を記載。
