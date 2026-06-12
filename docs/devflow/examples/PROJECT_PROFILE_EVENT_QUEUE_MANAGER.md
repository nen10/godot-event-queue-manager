# Project Profile: Event Queue Manager

This file specializes the reusable addon devflow for the Event Queue Manager Godot addon.

## Domain boundaries

| 領域 | 責務 | 判断基準 |
|---|---|---|
| Core Scheduler | tick、priority、sequence、event lifecycle、deterministic ordering、snapshot。 | Godot scene なしで動くこと。順序が再現可能で、同tick衝突が明示規則で解けること。 |
| Resource / API | EQConfig、EQPolicy、EQEventTemplate、EQActionDefinition、condition、tag、validation。 | canonical schema、typed Resource、明確な public API。暗黙defaultやsample-only挙動を通常導線にしない。 |
| Policy | Fixed round、CTB、Energy、Wait Turn、Action Resolution、Tactics、Phase、Stack などの順序規則。 | Coreを汚さず差し替え可能。policyごとに検証可能な契約を持つ。 |
| Trigger / Reaction | 条件成立、イベント監視、反応準備、持続時間、反芻、cancel/expire。 | 条件評価と効果実行を混ぜない。無限反応や循環予約を検出できる。 |
| Simulation Transaction | player turn中の仮行動、rollback、commit、snapshot、deterministic RNG。 | プレイヤーの試行錯誤を許しつつ、commit後のevent orderを再現可能にする。 |
| Presentation Pipeline | status反映と画面エフェクト反映の分離、visibility、importance、flush barrier。 | simulation correctnessをUI都合で歪めない。表示矛盾をflush policyで防ぐ。 |
| Adapter | Core / Resource と Godot Node / Scene / signal / Autoload optional を接続する。 | Node参照を保存形式に混ぜない。WeakRef / actor_id / event_idで橋渡しする。 |
| Editor UI | Timeline Preview、Config editor、Debug inspector、template generator。 | project asset selectionを主導線にし、sampleはlearning pathへ隔離する。raw JSONやnumeric fallbackを通常導線にしない。 |
| Tests | 採用した API / policy / UX が壊れていないことを確認する。 | test都合でUX/APIを歪めない。sample presetだけで完了扱いにしない。 |
| Docs / Demos | 判断、使い方、制約、demo sceneを残す。 | manualは採用済みUX/APIの説明であり、仕様決定の代替ではない。 |

## Test categories

| category | 責務 |
|---|---|
| Core Scheduler | push/pop/peek/cancel/reschedule/tie-break/snapshot。 |
| Policy | Fixed round、CTB、Energy、Wait Turn、Action Resolution の順序契約。 |
| Resource/API | `.tres` Resource roundtrip、validation、public method contract。 |
| Trigger/Reaction | condition matching、reaction arming、duration、rumination、cycle guard。 |
| Transaction | rollback/commit、player turn draft、snapshot restore、deterministic random。 |
| Presentation | visibility classification、importance barrier、effect flush ordering。 |
| UI headless | Editor dock state、selected project asset、validation state、timeline preview state。 |
| Debug scene | sample battle / wait-turn / action-resolution scene の状態切替。 |
| Package | addon-only manifest、clean project load、sample asset isolation。 |

## Product principles

- Event-first design。Actor turn は event の一種として扱う。
- Time-firstではなく order-first。tick、priority、condition、phase、stack depth、sequenceを統合して event order を決める。
- Runtime Core は headless / deterministic / serializable にする。
- tick は原則 int。float timeを順序決定の主軸にしない。
- 同順の決定規則は必ず明示する。暗黙randomは禁止。
- Policy Resourceでジャンル差を吸収し、Core Schedulerにはジャンル固有処理を入れない。
- status反映と画面エフェクト反映を分離する。
- player turnのrollbackは simulation transactionとして扱い、UIだけのundoにしない。
- sample-only completionは禁止。sample sceneはlearning pathであり、production featureの証明ではない。
- Autoloadは任意。標準導線はscene-local EQManager node。
- 旧互換は新規addonでは原則扱わない。必要になった場合のみroadmap sourceで明示する。

## Standard verification

Recommended default command:

```bash
./tools/test.sh
```

`tools/test.sh` should eventually run:

```bash
# examples; adapt to repository layout
godot --headless --path test_project --script res://tests/run_all.gd
python3 tools/check_addon_manifest.py
python3 tools/check_docs_links.py
```

If Godot is not installed, the task may be marked `BLOCKED_BY_TEST_ENV` only when code/review proof is otherwise complete.

## Stop conditions

Stop only for:

- Missing required Godot/test/build environment.
- External credentials or public release upload.
- Destructive action outside the repository.
- Direct contradiction between user instruction and active roadmap/profile.
