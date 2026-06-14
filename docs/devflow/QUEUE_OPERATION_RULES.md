# Queue Operation Rules

## Purpose

`IMPLEMENTATION_QUEUE.md` による作業管理規則を status、proof、dependency sweep として定める。

Queue の作成方針は `docs/devflow/policy/IMPLEMENTATION_QUEUE_DESIGN_POLICY.md`、実行 loop は `docs/devflow/LINEAR_AUTOPILOT_QUEUE.md` に従う。

## Status

| status | meaning |
|---|---|
| `BACKLOG` | 依存未完了。まだ選ばない。 |
| `READY` | 依存が満たされた。次に実装してよい。 |
| `RUNNING` | 現在作業中。 |
| `VERIFYING` | test / review 中。 |
| `REPAIR_NOW` | acceptance 未達。修正してから再検証する。 |
| `COMPLETE` | acceptance と proof を満たす。 |
| `COMPLETE_WITH_BACKLOG` | acceptance は満たし、非blocking follow-up がある。 |
| `BLOCKED_BY_TEST_ENV` | 環境不足で検証できない。 |
| `SPLIT_REQUIRED` | task が大きすぎるため分割が必要。 |
| `SUPERSEDED` | 他 task に吸収された。 |


## Completion proof

Task 完了処理:

### 1. Scheduled task の追加

Task 実行中に作成された `SUB_TASKS.md` 内のすべての Scheduled task について、割り込んだ位置に追加する。
- 通常の task と同様に `IMPLEMENTATION_QUEUE_DESIGN_POLICY.md` 記載の table format に従う。
- Scheduled task の追加は、既存task の依存関係を妨害しない。
- Scheduled task に紐づく依存関係は、未実施の他 task / Phase との依存を評価して、1つまで追加することができる。

### 2. Proof log の記載

```text
proof:
  plan: docs/plan/<roadmap>/<TASK_ID>_<slug>/
  review: docs/review/autopilot/<TASK_ID>_SELF_REVIEW_<date>.md
  tests:
    - <standard verification command>
  docs:
    - docs/devflow/TEST.md if changed
  major files:
    - ...
```

## Execution patterns

既定は単独・線形 (`LINEAR_AUTOPILOT_QUEUE.md`)。並列 / 委譲 / 競争 / 探索の非線形実行は `QUEUE_EXECUTION_PATTERNS.md` に従う。非線形実行でも本 file の status・proof・dependency sweep をそのまま使い、queue / proof / golden の編集は orchestrator のみが行う。

## Dependency sweep

Task を閉じたら、queue 全体を一度確認する。

1. `COMPLETE` と `COMPLETE_WITH_BACKLOG` だけを完了 dependency とみなす。
2. `BACKLOG` task の dependencies を確認する。
3. すべて満たされた task を `READY` にする。
4. dependencies を満たさない `READY` は `BACKLOG` に戻し、理由を記録する。
5. Current pointer を先頭の `READY` task に合わせる。

## Follow-up

`follow-up-ready` は Dynamic follow-up area に追加する。現 task の acceptance を満たしているなら、次 task へ進んでよい。
