# Project Profile: Event Queue Manager

This file specializes the reusable addon devflow for the Event Queue Manager Godot addon. It is the authoritative profile; `examples/PROJECT_PROFILE_EVENT_QUEUE_MANAGER.md` is kept only as a porting reference.

## Project identity

| item | value |
|---|---|
| project kind | Godot addon (event / turn / action order management) |
| primary user | Godot game developers needing deterministic turn/event ordering |
| primary workflow | add a turn-order system, swap policies, model reservations/reactions, debug ordering |
| main runtime / framework | Godot 4.x (GDScript; core behind a backend-portable contract) |
| standard test command | `./tools/test.sh` |
| independent performance command | `./tools/test.sh --performance` |
| review output directory | `docs/review/autopilot/` |
| development role | the addon is the deliverable; the gameplay-unproven Action Resolution Turn-Based system is a demanding test case, not a product to ship (roadmap §1.1) |

## Domain boundaries

| 領域 | 責務 | 判断基準 |
|---|---|---|
| Core Scheduler | tick、priority、sequence、event lifecycle、deterministic ordering、snapshot。 | Godot scene なしで動く。順序が再現可能で、同tick衝突が明示規則で解ける。 |
| Resource / API | EQConfig、EQPolicy、EQEventTemplate、EQActionDefinition、condition、tag、validation。 | canonical schema、typed Resource、明確な public API。暗黙default/sample-only を通常導線にしない。 |
| Policy | Fixed round、CTB、Energy、Wait Turn、Action Resolution、Tactics、Phase、Stack の順序規則。 | Core を汚さず差し替え可能。policy ごとに検証可能な契約を持つ。 |
| Progression (event-line) | global tick / WT・CT / AP 回復 / 効果回数を統一する進行指標。 | event-line = 進行入力、master timeline = 解決順。両者を分離する (`docs/design/EVENT_MODEL_CONCEPTS.md`)。 |
| Trigger / Reaction | 条件成立、イベント監視、反応準備、持続時間、反芻、cancel/expire。 | 条件評価と効果実行を混ぜない。無限反応や循環予約を検出できる。 |
| Simulation Transaction | player turn 中の仮行動、rollback、commit、snapshot、deterministic RNG。 | 試行錯誤を許しつつ commit 後の event order を再現可能にする。 |
| Presentation Pipeline | status 反映と画面エフェクト反映の分離、visibility、importance、flush barrier。 | simulation correctness を UI 都合で歪めない。表示矛盾を flush policy で防ぐ。 |
| Adapter / Integration | Core/Resource と Godot Node/Scene/signal/Autoload(任意) を接続する。 | Node 参照を保存形式に混ぜない。WeakRef / actor_id / event_id で橋渡しする。 |
| Editor UI | Timeline Preview、Config editor、Debug inspector、template generator。 | injected headless state の projection。project asset selection を主導線にし、sample は learning path へ隔離する。 |
| Tests | 採用した API / policy / UX が壊れていないことを確認する。 | test 都合で UX/API を歪めない。sample preset だけで完了扱いにしない。 |
| Docs / Demos | 判断、使い方、制約、demo scene を残す。 | manual は採用済み UX/API の説明であり、仕様決定の代替ではない。 |

## Product principles

- Event-first / order-first: actor turn は event の一種。tick・priority・condition・phase・sequence で順序を決める。time-first にしない。
- Deterministic order: 順序 key は int (tick, priority, sequence)。float を ordering key に使わない。同順は明示規則で解く。暗黙 random 禁止。
- Progression vs order separation: event-line は進行入力、master timeline は単一 comparator の全順序 (`docs/design/EVENT_MODEL_CONCEPTS.md`)。`due_tick` 直接書換禁止 (reschedule のみ)。
- Headless / serializable core: core は scene 無しで test 可能、snapshot 可能。
- Simulation/presentation split: status 反映と画面エフェクト反映を分離する。
- Transactional player turns: wait/end-turn commit 前の rollback を first-class とする。
- Projection-first editor UI: editor は injected headless state の projection。UI acceptance は metric/state/interaction contract であり screenshot ではない。
- Layered API (L0-L3): 簡易 turn-order と深層 reservation/event-line を両方 first-class にし、L3 を L0/L1 surface に leak させない (roadmap §3.1)。
- Resilience modes: dev fail-fast / shipped fail-safe。shipped は consumer の game を crash させない。正常 trace は mode 不変。
- No sample-only completion: sample scene は learning path。production 完了は project asset selection か明示 unset/validation state で判断する。
- Autoload は任意。標準導線は scene-local `EQManager` node。
- 旧互換は新規 addon では原則扱わない。必要時のみ roadmap source で明示する。
- 負の価値を生む UX 経路 (hack path) は fallback として温存せず削除する。
- Performance evidence separation: correctness / determinism の回帰と速度測定を同時収集しない。algorithmic work-count は portable hard gate、EQM-136 の生elapsedは環境付き advisory とする。既存の明示budget guardはdeterministic workload sentinelと組にしてperformance lane内だけで実行する。

### Referenced policies

- 進行 / 意味論: `docs/design/EVENT_MODEL_CONCEPTS.md`, `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md`
- 順序決定性: `docs/devflow/policy/DETERMINISM_TRACE_TEST_POLICY.md`
- UI: `docs/devflow/policy/UI_TESTABILITY_POLICY.md`, `UI_LAYOUT_METRIC_TEST_POLICY.md`, `UI_LAYOUT_CALIBRATION_POLICY.md`
- 入力縮約: `docs/devflow/policy/UX_PATH_REDUCTION_POLICY.md`
- runtime 堅牢性: `docs/devflow/policy/RUNTIME_RESILIENCE_POLICY.md`

## Implementation policy

### Scope control

- task の acceptance を満たすために必要な code / tests / docs を同じ作業で更新する。
- task 外の大規模 redesign は sub-task に分ける。
- より清潔な仕様が必要だと判明したら、互換維持ではなく plan/queue を更新して進める。

### Compatibility policy

新規 addon の既定は `replace`。saved snapshot は `schema_version` を持ち、未知 version は stable load error にする。pre-1.0 migration は `defer` (roadmap deferred)。

### UI / workflow policy

- UI work は operation steps で記述する (widget 列挙でない)。
- visual feel / 操作観察は analog test として捕捉してよいが、標準検証コマンドの代替にしない。
- 旧 UI test が変更を妨げる場合、新 UX の state contract へ更新する。

## Test categories

| category | 責務 |
|---|---|
| Core Scheduler | push/pop/peek/cancel/reschedule/tie-break/snapshot。 |
| Determinism trace | canonical trace 出力、golden fixture、permutation/replay/prediction purity の property tests。 |
| Policy | Fixed/CTB/Energy/Wait Turn/Action Resolution の順序契約、reducibility 証明。 |
| Resource/API | `.tres` roundtrip、validation、public method contract、layer-aware API surface。 |
| Trigger/Reaction | condition matching、reaction arming、duration、rumination、cycle guard。 |
| Transaction | rollback/commit、player turn draft、snapshot restore、deterministic random。 |
| Presentation | visibility classification、importance barrier、effect flush ordering。 |
| UI headless / metric | editor dock state、selected asset、validation state、layout metric P0、state matrix、interaction contract。 |
| Runtime / integration | node bridge、save/load rebind、dev/shipped resilience 二相。 |
| Debug scene | sample battle / wait-turn / action-resolution scene の状態切替。 |
| Package | addon-only manifest、clean project load、sample asset isolation。 |
| Performance (independent) | EQM 内の scale fixture、candidate / full-match 回数、elapsed の観測。通常回帰の correctness proof を所有しない。 |

## Verification

- Standard regression command: `./tools/test.sh`。`tests/performance/` を収集せず、correctness / determinism / lifecycle / serialization / UI / package gate を所有する。
- Independent performance command: `./tools/test.sh --performance`。performance suite のみ収集し、通常回帰、UI/Python static audit、golden、package gate は実行しない。
- Performance task の完了には両 command の証拠が必要。performance run は standard regression の代替ではない。
- Test docs: `docs/devflow/TEST.md`。
- Test output は run 固有の ignored directory (`.godot_user/test-runs/<run-id>/`) へ。
- 必須環境 (Godot 等) が無い場合、product implementation を完了扱いにせず `BLOCKED_BY_TEST_ENV` と正確な command/error を記録する。`tools/test.sh` は env 欠如を専用 exit code (3) で示す。

## Test Design Policy

### Regression / performance suite separation

- `./tools/test.sh` と `./tools/test.sh --performance` の discovery 集合は排他。同一 run で混ぜない。unknown suite や selected suite 0 files は green にせず fail-closed する。
- Regression は「正しいか」を証明する。performance は「EQM 内でどれだけ仕事をしたか」を測る。performance 側の結果だけで API / trace / snapshot / lifecycle の完了を主張しない。
- Deterministic work-count (candidate 数、`condition.matches()` 呼出数、fired 数など) は portable な hard gate。新しい生elapsedは Godot version/build、OS、CPU、run id と一緒に advisory 記録し、単独の pass/fail や機種横断 SLA にしない。EQM-102/112由来の粗いbudget guardは、宣言済みworkloadの完全実行assertと組にし、独立performance laneから通常回帰へ戻さない。
- Consumer 情報は fixture の軸・規模を選ぶ入力にのみ使う。Amberground の repository、test、scene、実測値を EQM の比較対象、baseline、oracle にしない。
- EQM が検証できる範囲は headless runtime 内の scheduling / trigger candidate filtering / condition evaluation / lifecycle / serialization に限る。consumer 側の rendering、AI、pathfinding、effect handler、asset I/O、frame pacing は EQM performance claim に含めない。

### Parallel execution

2 つの並列を区別する:

- **task 並列** (`QUEUE_EXECUTION_PATTERNS.md` P1): task ごとに worktree を分け、各々が独立に `./tools/test.sh` を回す。queue/proof/golden は orchestrator のみが書く。
- **test 内並列** (sharded multi-process): 1 回の `./tools/test.sh` 内で suite を複数プロセスへ分割する。下記前提を満たすときのみ。

共通の出力規律:

- test 出力は `.godot_user/test-runs/<run-id>/` 以下へ置く。
- 固定 resource path や共有 log へ直接書き込まない。

test 内並列の前提 (EQM 固有):

- **shard 分離**: 同一 project dir に複数 Godot プロセスを同時起動すると `.godot/` import cache を競合し race/破損し得る。shard ごとに project を分離する (worktree/コピー、または分離 cache dir)。run-id 出力分離だけでは不十分。in-process thread 並列は使わない (SceneTree は単一スレッド)。
- **hermeticity**: 各 test は自分の scheduler/seed/snapshot/output を持ち、global 可変状態 (static / autoload / singleton) を共有しない。test は isolation・serial・parallel で同一結果になること。
- **golden は通常 read-only**: 比較のみなら並列安全。`--update-golden` は serial・単一プロセスで、異なる golden file のみを書く (`policy/DETERMINISM_TRACE_TEST_POLICY.md`)。
- **parallel == serial 不変**: 並列結果は serial と同じ pass/fail・同じ golden diff。並列でだけ落ちる test は flake ではなく hermeticity bug。retry で隠さず修正する。
- **決定的 sharding**: sorted test id でパーティションし、どの shard が何を走らせたか記録する。個別 test は単独再現可能にする。
- **適用条件**: total test time が `Godot 起動 × shard 数` を上回るときのみ採用。小規模 suite は serial 既定。
- **実装の段階**: `tools/test.sh` の `--jobs`/`--shard` 化は suite が育ってから追加する (現状は premature)。それまで本節は契約のみ。

## Autopilot commit policy

### Commit allowed

| status | commit |
|---|---|
| `COMPLETE` | product completion commit |
| `COMPLETE_WITH_BACKLOG` | product completion commit |
| `BLOCKED_BY_TEST_ENV` | docs/state commit only |
| `SPLIT_REQUIRED` | docs/state commit only |
| `SUPERSEDED` | docs/state commit only |

`RUNNING`、`VERIFYING`、`REPAIR_NOW`、`BACKLOG`、`READY` の間は product work を commit しない。

### Before commit

- queue status が commit 可能状態。
- task 実行中に作成した Scheduled task が `IMPLEMENTATION_QUEUE.md` に追加済み。
- self-review がある。
- test result または environment-blocking result がある。
- `repair-now` が残っていない。
- queue proof が更新されている。
- unrelated dirty files を含めない。

### Commit message

```text
autopilot(<TASK_ID>): <summary>
```

docs/state commit:

```text
autopilot-state(<TASK_ID>): <summary>

Status: BLOCKED_BY_TEST_ENV | SPLIT_REQUIRED | SUPERSEDED
```

### Rollback

履歴 rewrite ではなく revert commit を使い、queue と review log に記録する。

## Stop conditions

Stop only for:

- 必須の Godot / test / build 環境が無い。
- 外部 credential、secret、署名、deploy、公開 upload。
- repo 外の破壊的操作。
- ユーザー指示と active roadmap/profile の直接矛盾。
