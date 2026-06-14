# EQM-001 POLICY

## 採用判断

- `docs/devflow/PROJECT_PROFILE.md` を EQM 専用・自己完結にする。追加 policy 群 (UI testability / metric / calibration, UX path reduction, determinism trace, runtime resilience) と roadmap 原則を参照する。
- `examples/PROJECT_PROFILE_EVENT_QUEUE_MANAGER.md` は porting reference として保持 (削除しない)。
- `docs/devflow/TEST.md` の標準コマンドは `./tools/test.sh`。
- `tools/test.sh` の exit code 規約: `0` pass / `1` test fail / `3` `BLOCKED_BY_TEST_ENV` (Godot 等の必須環境不足)。
- 出力先は `.godot_user/test-runs/<run-id>/` 固定 path。共有 log へ書かない。

## 不採用判断

- silent fallback (Godot 欠如を成功扱い) を通常導線にしない。
- profile を example への単純 pointer にしない。

## Resource / API / UI 境界

本 task は process 文書と harness script のみ。runtime/API には触れない。

## Invariants

- 標準検証コマンドは 1 つ (`./tools/test.sh`)。
- 環境不足は成功と区別される (専用 exit code)。
- profile は仕様根拠であり、fallback/legacy を仕様根拠にしない。

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| Godot 欠如時の挙動 | BLOCKED で exit (fallback 実行しない) | env-block と pass の区別 | — | `./tools/test.sh` の exit code 観測 |
| 既存 example profile | 保持 (mirror ではなく reference) | porting 用途 | 他 project へ pack を移したとき不要なら削除 | — |

## Compatibility stance

`replace`: 旧汎用 template は新 addon の public contract ではないため、EQM 専用へ置換する。
