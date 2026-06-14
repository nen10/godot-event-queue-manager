# EQM-001 UX

User: autopilot agent と addon 開発者 (process の利用者)。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| test.sh: Godot 欠如時に silent 成功 (exit 0) | low | high | low | reject | 環境不足を成功と誤認、sample-only completion を誘発 |
| test.sh: Godot 欠如時に明確メッセージ + 専用 exit code (BLOCKED) | high | low | low | adopt | autopilot が `BLOCKED_BY_TEST_ENV` を機械判定できる |
| test.sh: Godot 欠如時に crash (set -e で曖昧終了) | low | high | low | reject | failure と env-block を区別できない |
| profile を example file への pointer だけにする | low | medium | low | reject | 1 file で判断できず read 順が増える |
| profile を自己完結の EQM 版に書き換え | high | low | medium | adopt | autopilot が 1 file で原則・gate・停止条件を得る |

## Operation steps

1. agent が `docs/devflow/PROJECT_PROFILE.md` を読み、原則・gate・停止条件・commit 可否を判断する。
2. agent が `docs/devflow/TEST.md` で標準コマンドと環境要件を確認する。
3. agent が `./tools/test.sh` を実行する。
   - Godot あり: headless test 群を実行。
   - Godot なし: `BLOCKED_BY_TEST_ENV` を明示し専用 exit code で終了。
4. 非線形実行が要るときは `QUEUE_EXECUTION_PATTERNS.md` を参照する。

## 採用 / 廃止

- 採用: 自己完結 profile、明確な env-block exit。
- 廃止: silent 成功、example-only pointer。
