# Addon Devflow

この directory は開発を Roadmap -> Queue -> Task iteration で進めるための開発プロセスを定義する。

## Layers

| layer | role |
|---|---|
| Skill | Agent の短い入口。mode 選択と読む順序だけを書く。 |
| Project Profile | project 固有の価値観、test command、禁止default、停止条件。 |
| Policy | Roadmap と Queue をどう判断して作るか。 |
| Task Packet | task ごとの `SUB_TASKS.md` / `UX.md` / `POLICY.md` / `IMPLEMENTATION_PLAN.md` の作成規則。 |


## Files

| file | 責務 |
|---|---|
| `docs/devflow/LINEAR_AUTOPILOT_QUEUE.md` | implementation queue を連続実行する手順。 |
| `docs/devflow/PROJECT_PROFILE.md` | project 固有の価値観、test command、禁止default、停止条件。 |
| `docs/devflow/QUEUE_OPERATION_RULES.md` | queue status、proof、dependency sweep の規則。 |
| `docs/devflow/TASK_PACKET.md` | queue task ごとの `UX.md` / `POLICY.md` / `IMPLEMENTATION_PLAN.md` の書き方。 |
| `docs/devflow/TEST.md` | 標準検証コマンド、環境要件、自動テストの方法・一覧。 |
| `docs/devflow/policy/ROADMAP_POLICY.md` | Roadmap 作成の判断基準。 |
| `docs/devflow/policy/IMPLEMENTATION_QUEUE_DESIGN_POLICY.md` | Roadmap を implementation queue に変換する判断基準。 |
| `docs/devflow/policy/ANALOG_TEST_POLICY.md` | アナログテスト作成指針。 |
| `docs/devflow/policy/UI_TESTABILITY_POLICY.md` | UI テスト層 (L0-L6) の全体方針と projection-first UI 要件。 |
| `docs/devflow/policy/UI_LAYOUT_METRIC_TEST_POLICY.md` | Control tree 数値評価による UI 構造 acceptance gate。 |
| `docs/devflow/policy/UI_LAYOUT_CALIBRATION_POLICY.md` | 人間 layout feedback の構造化取り込み (tweak-and-bake)。 |
| `docs/devflow/policy/UX_PATH_REDUCTION_POLICY.md` | 負価値 UX 経路と入力クラス過剰一般化の排除基準。 |
| `docs/devflow/policy/DETERMINISM_TRACE_TEST_POLICY.md` | golden trace / property test による順序決定性の証明。 |
| `docs/devflow/PORTING_CHECKLIST.md` | 他プロジェクトへ移植するときの初期設定チェックリスト。 |


## Flow

```text
concept / request / feedback / evaluation
  -> docs/plan/<YYYY-MM-DD>_<ROADMAP_ID>/ROADMAP.md
  -> docs/plan/<YYYY-MM-DD>_<ROADMAP_ID>/IMPLEMENTATION_QUEUE.md
  -> READY iteration, docs/devflow/TASK_PACKET.md
    -> UX.md
    -> POLICY.md
    -> IMPLEMENTATION_PLAN.md
    -> implementation
    -> tests
    -> self-review / repair
    -> queue update
    -> completion commit
  -> next READY task
```
