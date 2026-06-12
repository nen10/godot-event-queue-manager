# Project Profile: <Addon Name>

This file contains project-specific settings.

## Domain boundaries

| 領域 | 責務 | 判断基準 |
|---|---|---|
| Core | Hex 座標、map data、generation、query などの構造的機能。 | 汎用性と正確性。UI で使わない実行パスも価値があれば保持できる。 |
| Resource / API | ゲーム開発者が保存・参照・再利用する contract。 | canonical schema、typed resource、明確な責務。v1/v2 互換語彙を増やさない。 |
| Adapter | Core / Resource と Godot scene / UI を接続する。 | UI に raw 内部値を露出させず、変換責務をここに置く。 |
| UI | ユーザーの作業目的を表示・操作へ変換する。 | project asset selection を主導線にし、sample は明示的な learning / onboarding path に隔離する。path text、raw JSON、numeric fallback を通常導線にしない。 |
| Tests | 採用した UX / API が壊れていないことを確認する。 | test しやすさで UX を歪めない。sample preset success だけで feature complete と判定しない。 |
| Docs | 判断、使い方、完了根拠を残す。 | policy / process / plan / review / manual の責務を混ぜない。 |


### Test categories

| category | 責務 |
|---|---|
| Core / Adapter | データ構造、変換、query、validation の機能契約。 |
| Resource/API | canonical save/load/validation。 |
| UI headless | 画面の内部形状ではなく、ユーザー目的に接続する state。 |
| Debug scene | debug scene の状態切替と表示対象データ。 |
| Package | addon-only manifest、sample asset、clean project load。Committed `dist` freshness は final process step で確認し、通常 task の test gate にはしない。 |

## Product Principles

- clean Resource / clean API / clean UI を優先する。
  - コードベースやドキュメント記載の fallback / hack / legacy / compatibility は仕様根拠にしない。
- ゲーム開発上の UX合理性を UI / API 設計の根拠にする。
  - headless API availability だけで UI task を完了扱いにしない。 UI 設計をの根拠をheadless test の都合で決めない
  - manual は仕様書ではなく、採用済み UX を使うための説明である。
  - No sample-only completion: sample preset だけで成立する editor-facing 機能は `sample-only prototype` と分類し、production feature completion とは扱わない。
  - production feature completion は、任意 project asset selection または明示的な未設定/validation state を持つことで判断する。bundled sample は learning / onboarding path であり、silent default ではない。
- 自動テストを、採用した UX / API の完了判断に使える Test path として設計する。
  - 原則に反する機能を温存するテストは更新または削除する。
  - Core / Adapter tests は機能契約を守る。
  - UI tests はユーザー目的に接続する state transition を見る。
  - テストを追加・変更したら `docs/devflow/TEST.md` を更新する。
- Commit は作業途中の保存ではなく、task completion proof である。

## Implementation Policy

### Scope control

- task の acceptance を満たすために必要な code / tests / docs を同じ作業で更新する。
- task 外の大規模 redesign は follow-up に分ける。
- 作業中により清潔な仕様が必要だと判明した場合、互換維持ではなく plan / queue を更新して進める。

### Resource / API changes

- 清潔な schema を優先する。
- v1/v2 migration、compatibility は Roadmap Source が直接明示した場合だけ扱う。

### UI changes

- UI は詳細な operation step ごとに整理する。
- 古い UI test が変更を妨げる場合、test を新 UX の state contract へ更新する。

### Verification

- `docs/devflow/TEST.md` に接続する自動テストを基本根拠にする。
- UI feature の headless test は sample mode OFF または user-selected project asset state を確認し、sample mode ON/OFF は別 contract として扱う。
- UI の視認性・操作感は headless test で固定しない。

### Completion review

- acceptance を満たしたか。
- sample-only prototype を complete と誤判定していないか。
- `repair-now` が残っていないか。
- Test path と self-review があるか。
- follow-up が必要なら queue に追加できる形で整理したか。


## Test Design Policy

### Parallel execution

- test output は `.godot_user/test-runs/<run-id>/` 以下へ置く。
- 固定 resource path や共有 log へ直接書き込まない。


## Autopilot Commit Policy

### Commit allowed

| status | commit |
|---|---|
| `COMPLETE` | product completion commit |
| `COMPLETE_WITH_BACKLOG` | product completion commit |
| `BLOCKED_BY_TEST_ENV` | docs-only state commit |
| `SPLIT_REQUIRED` | docs-only state commit |
| `SUPERSEDED` | docs-only state commit |

Commit しない状態:

- `RUNNING`
- `VERIFYING`
- `REPAIR_NOW`
- `BACKLOG`
- `READY`

### Before commit

- task 実行中に作成した Scheduled task が `IMPLEMENTATION_QUEUE.md` に追加済み。
- queue status が commit 可能状態である。
- self-review がある。
- test result または environment-blocking result がある。
- `repair-now` が残っていない。
- queue proof が更新されている。
- unrelated dirty files を含めない。

### Product commit message

```text
autopilot(<TASK_ID>): <summary>
```

### State commit message

```text
autopilot-state(<TASK_ID>): <summary>

Status: BLOCKED_BY_TEST_ENV | SPLIT_REQUIRED | SUPERSEDED
```

### Rollback

History rewrite ではなく revert commit を使う。rollback も queue / review に記録する。


## Stop Conditions

Stop only for:

- Missing required test/build environment.
- External credentials or public release upload.
- Destructive action outside the repository.
- Direct contradiction between user instruction and active roadmap/profile.
