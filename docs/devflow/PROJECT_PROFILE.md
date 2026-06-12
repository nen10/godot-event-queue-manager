# Project Profile: <Project Name>

This file contains project-specific settings. Replace placeholders before running Autopilot in a real repository.

## Project identity

| item | value |
|---|---|
| project kind | `<addon / app / library / game / tool / service>` |
| primary user | `<who this project serves>` |
| primary workflow | `<workflow the roadmap should improve>` |
| main runtime / framework | `<Godot / Unity / Web / Python / ...>` |
| standard test command | `<for example: ./tools/test.sh>` |
| review output directory | `docs/review/autopilot/` |

## Recommended Domain 

| 領域 | 現在の責務 |
|---|---|
| Core | -- |
| Resource / API | -- |
| Adapter / Integration | -- |
| UI / Workflow | -- |
| Tests | -- |
| Docs | -- |

## Product principles

- clean Resource / clean API / clean UI を優先する。
  - コードベースやドキュメント記載の fallback / hack / legacy / compatibility は仕様根拠にしない。
- ゲーム開発上の UX合理性を UI / API 設計の根拠にする。
  - headless API availability だけで UI task を完了扱いにしない。 UI 設計をの根拠をheadless test の都合で決めない
  - manual は仕様書ではなく、採用済み UX を使うための説明である。
  - No sample-only completion: sample preset だけで成立する editor-facing 機能は `sample-only prototype` と分類し、production feature completion とは扱わない。
  - production feature completion は、任意 project asset selection または明示的な未設定/validation state を持つことで判断する。bundled sample は learning / onboarding path であり、silent default ではない。
- 自動テストを、採用した UX / API の完了判断に使える Test path として設計する。
  - 原則に反する機能を温存するテストは更新または削除する。
- Commit は作業途中の保存ではなく、task completion proof である。

## Implementation policy

### Scope control

- task の acceptance を満たすために必要な code / tests / docs を同じ作業で更新する。
- task 外の大規模 redesign は sub-task に分ける。
- 作業中により清潔な仕様が必要だと判明した場合、互換維持ではなく plan / queue を更新して進める。

### Compatibility policy

Choose one per roadmap or task packet:

| stance | use when |
|---|---|
| `preserve` | Existing saved data/API is a public contract. Add migration or compatibility tests. |
| `migrate` | Old data/API should load but be rewritten or normalized into the new contract. |
| `replace` | The old behavior is not a public contract or blocks the accepted product direction. |
| `defer` | Compatibility is not in scope; document as a follow-up-ready task. |

### UI / workflow policy

- Describe UI work as operation steps, not widget lists.
- Visual feel and manual operation observations can be captured as analog tests, but analog tests do not replace the standard verification command.
- 古い UI test が変更を妨げる場合、test を新 UX の state contract へ更新する。

## Test categories

| category | responsibility |
|---|---|
| Unit / Core | Domain logic, algorithms, data contracts. |
| Resource / API | Save/load, schema, compatibility, public methods. |
| Integration | Framework/runtime/editor/CLI integration. |
| UI headless / workflow | User-goal state transitions, not pixel-perfect layout. |
| Package / release | Manifest, distribution artifact, clean consumer project. |
| Performance / scale | Measured behavior and visible progress where relevant. |
| Analog / manual | Human-observed usability, viewport, visual, or multi-tool flow. |
## Verification

- Standard verification command: `<fill from project, e.g. ./tools/test.sh>`.
- Test docs: `docs/devflow/TEST.md`.
- Test output should go under an ignored, run-specific directory when possible.
- If the required environment is missing, record `BLOCKED_BY_TEST_ENV` and the exact command/error instead of marking product implementation complete.

## Test Design Policy

### Parallel execution

- test output は `.godot_user/test-runs/<run-id>/` 以下へ置く。
- 固定 resource path や共有 log へ直接書き込まない。

## Autopilot commit policy

### Commit allowed

| status | commit |
|---|---|
| `COMPLETE` | product completion commit |
| `COMPLETE_WITH_BACKLOG` | product completion commit |
| `BLOCKED_BY_TEST_ENV` | docs/state commit only |
| `SPLIT_REQUIRED` | docs/state commit only |
| `SUPERSEDED` | docs/state commit only |

Do not commit product work while status is `RUNNING`, `VERIFYING`, `REPAIR_NOW`, `BACKLOG`, or `READY`.

### Before commit

- queue status が commit 可能状態である。
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

For docs/state commits:

```text
autopilot-state(<TASK_ID>): <summary>

Status: BLOCKED_BY_TEST_ENV | SPLIT_REQUIRED | SUPERSEDED
```

### Rollback

Use a revert commit rather than history rewrite. Record rollback in the queue and review log.

## Stop conditions

Stop only for:

- Missing required test/build/runtime environment.
- External credentials, secrets, signing, deployment, or public release upload.
- Destructive action outside the repository.
- Direct contradiction between the user instruction and active roadmap/profile.
