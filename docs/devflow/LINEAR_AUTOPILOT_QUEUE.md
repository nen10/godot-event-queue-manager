# Codex Autopilot Orchestration

## Purpose

作成済み `IMPLEMENTATION_QUEUE.md` を、Codex が人間承認待ちで止めずに実装するための手順を定める。

Roadmap 作成は `docs/devflow/policy/ROADMAP_POLICY.md`、queue 作成は `docs/devflow/policy/IMPLEMENTATION_QUEUE_DESIGN_POLICY.md` に従う。

これは単独・線形の既定パターン (P0)。並列 / 委譲 / 競争 / 探索の非線形実行は `docs/devflow/QUEUE_EXECUTION_PATTERNS.md` を参照する。

## Inputs

- `docs/plan/<YYYY-MM-DD>_<ROADMAP_ID>/ROADMAP.md`
- `docs/plan/<YYYY-MM-DD>_<ROADMAP_ID>/IMPLEMENTATION_QUEUE.md`
- `docs/devflow/PROJECT_PROFILE.md`
- `docs/devflow/TEST.md`

## Autopilot loop

1. Queue から先頭の `READY` task を選ぶ。
2. task を `RUNNING` にする。
3. `docs/devflow/TASK_PACKET.md`に従い、実装計画を作成する。`ROADMAP.md` 内の該当 taskも参照する。
4. plan 後に承認待ちで止まらず、同じ run で実装する。
5. code / tests / docs を更新する。cf.`PROJECT_PROFILE.md`
6. `docs/devflow/PROJECT_PROFILE.md` と `docs/devflow/TEST.md` に定義された標準検証コマンドを実行する。
7. 失敗や不足を分類し、`repair-now` は同じ task で修正する。
8. task 実行中に作成した Scheduled task を `IMPLEMENTATION_QUEUE.md` に追加する。
9. `docs/review/autopilot/<TASK_ID>_SELF_REVIEW_<date>.md` を作り、sample-only success を completion proof にしていないことを確認する。
10. `docs/devflow/QUEUE_OPERATION_RULES.md` に従って queue を更新する。
11. 完了状態なら `PROJECT_PROFILE.md` に従って commit する。
12. 次の `READY` task へ進む。

## Failure classes

| class | handling |
|---|---|
| `repair-now` | acceptance 未達。次 task に進まず修正する。 |
| `follow-up-ready` | 現 task は完了できるが、後続 task にする。 |
| `known-env-failure` | 必須 runtime / build / test tool など環境不足。`BLOCKED_BY_TEST_ENV` にする。 |
| `accepted-risk` | 理由と解除条件を self-review に残す。 |
| `manual-optional` | 自動 loop を止めない。必要に応じて analog test 候補へ記録し、標準自動 loop は止めない。 |

## Stop conditions

Codex が止まってよいのは以下だけ。

- completion proof に必要な runtime / build / test 環境がない。
- 外部 credential、公開 upload、署名など repo 外の操作が必要。
- repo 外の破壊的操作が必要。
- Roadmap とユーザー指針が直接矛盾し、合理的な解釈で進められない。
