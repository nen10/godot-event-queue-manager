# Planning Format

## Purpose

running 選択された Queue task slice および `docs/devflow/PROJECT_PROFILE.md` 記載の原則をもとに実装前の planning を行う。
SUB_TASKS ->UX -> POLICY -> IMPLEMENTATION_PLAN の順に実施し、後段で決定できない判断事項は前段にescalationして基準を具体化する。
実装中に判断しきれない事象は、SUB_TASKS.md を追加編集して責務分割することが可能。

前提条件: Roadmap 決定は `docs/devflow/policy/ROADMAP_POLICY.md`、queue 作成は `docs/devflow/policy/IMPLEMENTATION_QUEUE_DESIGN_POLICY.md` に従う。

## Plan directory

```text
docs/plan/<YYYY-MM-DD>_<ROADMAP_ID>/<TASK_ID>_<slug>/
  SUB_TASKS.md
  UX.md
  POLICY.md
  IMPLEMENTATION_PLAN.md
```

大きい task のみ `TEST_PLAN.md` を追加してよい。

## Task Complexity Class

各 `SUB_TASKS.md` は task の complexity class を明記する。complexity は「作業量」だけでなく、UX/API影響範囲、状態数、fallback/mirror有無、test proof の広さで決める。

| class | scope | required planning artifacts |
|---|---|---|
| `C1` | 1文書または1箇所の小修正。既存方針に従うだけで判断余地が少ない。 | Complexity header、短い task resolution、test/proof path。 |
| `C2` | 1つのUX/API slice。複数候補の採否はあるが、状態境界は小さい。 | Complexity header、Task Resolution、Scheduled Task Audit、UX Candidate Matrix、fallback/mirror有無の確認。 |
| `C3` | 複数ファイルまたは複数画面にまたがる slice。既存状態やtestsとの干渉がある。 | C2 artifacts + dependency/test matrix + state/invariant table。 |
| `C4` | 画面再設計、architecture split、process gate、performance pathなど、複数の実装フローを含む大きい task。 | C3 artifacts + fallback/mirror table必須 + rejected/deferred itemのqueue化判定必須。 |
| `C5` | roadmap/phase級。複数の完了境界を含み、このまま実装すると proof が曖昧になる task。 | C4 artifacts + `SUB_TASKS.md` で task分解し、必要なら queue に scheduled task を追加する。 |

### Complexity header template

`SUB_TASKS.md` の先頭に以下を置く。

```md
## Complexity

Class: C<n>
Reason:
- ...

Required artifacts:
- ...
```

### C4/C5 mandatory tables

C4/C5 task では次を必須にする。

- `SUB_TASKS.md`: task resolution candidate matrix。
- `SUB_TASKS.md`: Scheduled Task Audit。
- `UX.md`: UX Candidate Matrix。
- `POLICY.md`: Fallback / Mirror Handling table。
- `POLICY.md`: State / Invariant Table。
- `IMPLEMENTATION_PLAN.md`: dependency / test matrix。

C5 task は、1つの completion commit で説明できない場合、implementation へ進む前に sub-task を queue 化する。`RESOLUTED` 系 status を使う場合は、`docs/devflow/QUEUE_OPERATION_RULES.md` に従い、分離 task の完了状態を proof に含める。

## 0. SUB_TASKS.md

目標の完結と価値最大化に向けて task resolution を行う

### planning for sub-tasks

task resolution : [
  task 候補 : { 目標/UX, 採否, 概要 },
  ...
]

- 今回task の 目標が定める範囲が実装上曖昧な場合、目標に該当する新規の小目標を数多く提案し、採否の判断を任意の数だけ記載する。
- 今回task の 目標が発散的な場合、目標に該当する新規 UX を数多く提案し、採否の判断を任意の数だけ記載する。
- 今回task の 目標が大きく、小目標,UX 自体が複数の実装フローから構成される必要がある場合、実装計画候補を必要なだけ提案・検討し、採否の判断を任意の数だけ記載する。
- 今回task が 設計判断の場合、目標を実現する設計と複数のtaskから構成される採否の判断を任意の数だけ記載する。
- 今回task が 計画を作成することを目標にする場合、本質的な価値を実現する新規の目標を数多く提案し、採否の判断を任意の数だけ記載する。

### plan scheduling

Scheduled task : {
  `id` : <今回task id>.<%dd> ,
  `dependency` : ...,
  概要 : ...
}

- 採用した複数の新規小目標, 新規 UX, 実装計画候補 については、実装上の依存関係を評価し Scheduled task として記載する。
- 設計を行うための状況調査、調査実験用test作成等、task完了がプロダクトの本質的な価値を伴う段階に至らない目標の場合 "<今回task run の成果物> をもとに計画を作成する task" を Scheduled task として記載する。依存関係は 今回task自身 に紐付ける。
- 今回task が目標の本質的な価値を実現するに及ばない場合 "<今回task run の成果物> をもとに計画を作成する task" を Scheduled task として記載する。依存関係は 今回task自身 に紐付ける。
- 今回task の実装中に高度な設計判断が必要になり、良いところで task を分解する場合、現在目標を実現する設計計画の必要性を Scheduled task として記載して task 分離できる。

### add sub-tasks rules

- `SUB_TASKS.md` 内の Scheduled task は 今回task 完了処理時に `docs/plan/<YYYY-MM-DD>_<ROADMAP_ID>/IMPLEMENTATION_QUEUE.md` に追加する。
  - 記載の format は通常の task と同様とし、詳細は `docs/devflow/QUEUE_OPERATION_RULES.md` に従う。


## 1. UX.md

UX Candidate Matrixを作成し、その後目標を experience steps として具体化する。

### UX Candidate Matrix

```
| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. keep in Paint | low | high | low | reject | mixes resource context and brush work |
| B. move to Catalog | high | medium | medium | adopt | aligns tab with user task |
| C. duplicate in both | medium | high | high | reject | two sources of truth |
```


以下を含む:

- user goal。
- operation steps。
- { 採用, 維持 }する UX。
- { 廃止, 保留 }する UX。
- hack 扱いとして廃止または backlog残置する UX
- 既存 UX との干渉。

## 2. POLICY.md

目標を実現するため、採用UXを基準に必要な設計を判断する。

以下を含む:

- 採用判断。
- 不採用判断。
- 破壊的変更の理由。
- legacy 扱いとして廃止または backlog残置する設計
- Resource / API / UI の境界。
- 未確定だが task 内で決めてよい事項。

### Invariants

- Workspace context has one selected-node source.
- Sample Learning never becomes production source.
- Manual Override must not silently write back unless policy says so.

### Fallback / Mirror Handling

```
| item | decision | why | removal condition | test |
|---|---|---|---|---|
```

### State / Invariant Table

C3以上、または状態遷移・UI表示・fallback/mirror を扱う task では、必要に応じて以下を追加する。C4/C5では必須。

```
| state/source | invariant | risk | proof/test |
|---|---|---|---|
```

## 3. IMPLEMENTATION_PLAN.md

目標を実現するため、採用設計を基準に実装を計画する。

以下を含む:

- Scope。
- 変更対象ファイル。
- 実装 steps。
- fallback 扱いとして廃止または backlog残置する step
- Test path。
- docs 更新。
- completion checklist。

### Plan / Execution Boundary

| artifact | owns | must not own |
|---|---|---|
| `IMPLEMENTATION_PLAN.md` | intended scope, target files, planned steps, planned tests, planned completion criteria | post-execution status, final changed-file audit, executed checklist, deviation record |
| `SELF_REVIEW_<date>.md` | execution summary, changed files, acceptance result, deviation table, repair-now audit, test summary | new unreviewed scope decisions |
| optional `EXECUTION_LOG.md` | detailed execution trace for C4/C5 or long tasks | replacement for self-review |

If implementation reveals a scope/design change before the change is made, update the plan as planning input. If the change is discovered during or after implementation, record it as a deviation in self-review or `EXECUTION_LOG.md`.

### Dependency / Test Matrix

C3以上で、複数の依存や test proof がある場合に追加する。C4/C5では必須。

```
| dependency / area | risk | proof / test |
|---|---|---|
```

## Review before implementation

`UX.md`, `POLICY.md`, `IMPLEMENTATION_PLAN.md` を確認する:

- Roadmap と矛盾しないか。
- task の完了状態が test または review で確認できるか。
- 旧互換や旧 UI を理由なく守っていないか。
- まだ決まらない未決事項を`SUB_TASKS.md`に計画し、責務分割できているか。

`SUB_TASKS.md` が存在する場合確認する:

- task 分割が進捗の確実さに貢献しているか。
- 目標価値を最大化する提案・採否判断ができているか。
