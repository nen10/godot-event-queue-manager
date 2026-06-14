# Queue Execution Patterns

目的: `IMPLEMENTATION_QUEUE.md` を実行する方法を、単独・線形 (`LINEAR_AUTOPILOT_QUEUE.md`) 以外にも用意する。並列・委譲・競争・探索の各パターンを定義し、すべて同一の status machine (`QUEUE_OPERATION_RULES.md`) と gate (`PROJECT_PROFILE.md` + policy gates) の上で動かす。

参考起源: `godot-hex-map-lab` の orchestrate-hex-agents (orchestrator が contract と gate を所有し、実装は executor に委譲、completion は gate 判定)。本 doc は EQM の客観 gate に適応したもの。

---

## 0. 核となる原理

- **completion は gate 判定であり、self-attestation ではない**。`./tools/test.sh` が当該 task type の policy gate を満たすことだけが `COMPLETE` への扉。
- **orchestrator だけが shared state を書く**。`IMPLEMENTATION_QUEUE.md`・proof log・golden fixture・統合ブランチへの merge は orchestrator が行う。executor/explorer は自分の worktree 内 draft のみ。
- **risky な実装は isolation する**。探索的 agent は worktree に隔離し、gate を通るまで draft 扱い。
- **billed/external agent run と protected branch への merge は事前にユーザー確認**。

## 1. 役割

| 役割 | 担当 | 責務 |
|---|---|---|
| Orchestrator | 駆動セッション (this Opus) | contract を書く / route する / gate を回す / queue・proof・merge を所有する。実装そのものはしない。 |
| Executor | 信頼実行体 | bounded task を autonomous に実装。保守的で忠実。 |
| Explorer | 探索実行体 | spike / maximal version / 頑固な UI。遠くへ届くが overclaim/under-test しがち → 隔離 + 全 gate 必須。 |

実装手段は tool-agnostic (環境依存):

- Claude Code subagent (`Agent` tool, `isolation: "worktree"`, 並列時は `run_in_background: true`)。
- 外部 CLI agent (Codex / opencode 等)。external run はユーザー確認後。

## 2. Contract (どの agent を動かす前にも orchestrator が書く)

1. **acceptance**: 当該 queue row の acceptance / test path をそのまま literal pass condition にする。
2. **depth**: `surface` (見える範囲だけ) / `integrated` (既存と結線) / `decision` (設計判断を含む)。depth 曖昧さが executor を臆病に見せる主因。`decision` は委譲せず orchestrator 主導。
3. **scope**: 触ってよい正確なファイル (queue の target files 列)。「他 task の queue row を編集しない / 何も COMPLETE にしない / golden を勝手に更新しない」。
4. **tests required**: 下記 §4 の task-type 別 gate。
5. **isolation**: explorer・並列時は worktree。

## 3. パターン

### P0. Linear autopilot (既定)

`LINEAR_AUTOPILOT_QUEUE.md`。先頭 `READY` を 1 つ、同一 run で実装→test→self-review→queue 更新→commit。v0.1 の線形 spine (EQM-001→002→010→…→014) はほぼ純粋に線形なのでこれが既定。

### P1. Parallel frontier (独立 task の並列)

条件: 2 つ以上の `READY` task が (a) 相互に依存せず、(b) target files が disjoint。

手順:

1. orchestrator が並列可能集合を選ぶ。target files が重なる READY は serialize する。
2. 各 task を worktree に分けて executor を並列起動 (`Agent` の `isolation:"worktree"` + `run_in_background:true`)。
3. 各ブランチを個別に gate (§4)。`ACCEPT` のみ merge。
4. merge 順は dependency 順 (独立集合なので任意でよいが、golden に触れる task は serialize)。
5. merge ごとに dependency sweep を回し、新たな `READY` を出す。

EQM の fork 点 (parallel が効く所): EQM-022 後に `EQM-023 ∥ EQM-030`、EQM-034 後に `Phase4(energy/wait) ∥ EQM-086(editor contract)`、editor tooling 群、demo suite 群。v0.1 spine では効かない。

### P2. Orchestrated delegation (委譲)

bounded だが手数のある task を executor に委譲。orchestrator は contract + gate を所有し、`REJECT` 時は findings を executor に返して self-repair させる。completion は gate 判定。

### P3. Competitive dual-run (競争 + 裁定)

high-value かつ ambiguous な task を 2 つの worktree で別 agent / 別アプローチに実装させ、両方を gate して `ACCEPT` を採る。

EQM の利点: **core/policy/trace task は golden trace が客観 gate**なので裁定が機械的。両者が同じ golden を出すか、片方が誤り。負けブランチに良い着想 (例: backend 結線) があれば `follow-up-ready` task に harvest し、未検証ブランチは ship しない。

### P4. Exploratory sparring / spike (探索)

頑固な UI、maximal version、未知の contract を詰めるとき。explorer を隔離して走らせ、出力で contract や候補を発見してから、production 版は executor に再 route する。

EQM の利点: **UI task は UI metric P0 が客観 gate** (`UI_LAYOUT_METRIC_TEST_POLICY.md`)。UI sparring を「見た目の感想」でなく metric で裁定できる。calibration loop (`UI_LAYOUT_CALIBRATION_POLICY.md`) はこの探索の人間版。

## 4. Gate (task type 別、絶対にスキップしない)

`./tools/test.sh` が当該 type の gate を緑にすること。

| task type | gate |
|---|---|
| core / policy / scheduler | golden trace + property/metamorphic (`DETERMINISM_TRACE_TEST_POLICY.md`) |
| resource / API | roundtrip + validation + layer-aware API surface (EQM-023, leak fail) |
| UI / editor | UI metric P0 (`UI_LAYOUT_METRIC_TEST_POLICY.md`) + state matrix + interaction contract |
| runtime / integration | dev/shipped 二相 resilience test (`RUNTIME_RESILIENCE_POLICY.md`) + node-bridge save/load rebind |
| demo | headless golden trace (`DETERMINISM_TRACE_TEST_POLICY.md`) |
| docs-only | 契約整合 (UI contract / state matrix 等)、Godot run 不要 |

## 5. 並列時の安全規則

- queue・proof・golden・統合ブランチは orchestrator のみ編集 (shared-state の単一書き手)。
- task ごとに worktree、`ACCEPT` 後のみ統合ブランチへ merge。
- golden fixture を複数ブランチで同時更新しない。同一 golden に触れる task は serialize。
- merge 後は必ず dependency sweep。`REPAIR_NOW` は backlog に動かさない。
- commit message は `autopilot(<TASK_ID>)`。並列でも task 単位の completion proof は崩さない。
- external/billed run と protected branch merge は事前確認。

## 6. パターン選択

| 状況 | パターン |
|---|---|
| 線形 spine / bounded | P0 / P2 |
| 独立 task が fan-out | P1 |
| high-value + ambiguous な core | P3 (golden で裁定) |
| 頑固 UI / spike / contract 未確定 | P4 (UI metric で裁定) |
| 設計判断 (depth=decision) | 委譲せず orchestrator 主導 |

## 7. status machine との対応

`QUEUE_OPERATION_RULES.md` をそのまま使う。並列拡張:

- 複数 task が同時に `RUNNING` になり得る (disjoint なら)。各 worktree が 1 task を占有。
- `VERIFYING` = gate 実行中。`ACCEPT`→`COMPLETE` / `COMPLETE_WITH_BACKLOG`、`REJECT`→`REPAIR_NOW`。
- Current pointer は線形時のみ意味を持つ。並列時は「並列可能 READY 集合」を proof log に記す。

## 8. Autonomous orchestration loop (自律実行サイクル)

orchestrator (Opus) が、その時点の queue に応じて §3 のパターンを自動選択し、gate と queue state 更新まで含めて次 task へ進む。承認待ちで止まらず、明示された checkpoint と stop 条件でのみ止まる。

### 8.1 1 反復の手順

```text
1. SWEEP   : dependency sweep を回し、READY frontier F = {依存が満たされた task} を得る。
2. STOP?   : F が空なら停止 (§8.4)。残りが全て blocked なら理由を報告して停止。
3. CLASSIFY: F の各 task を分類する — type(→§4 gate) / depth(surface|integrated|decision) / target files。
4. SELECT  : §8.2 の決定規則でパターンを 1 つ選ぶ。
5. CHECK?  : §8.3 の checkpoint に該当するなら、実行せずユーザーへ escalate して停止。
6. CONTRACT: §2 の contract を書く (acceptance/depth/scope/gate/isolation)。
7. PLAN    : `TASK_PACKET.md` に従い task packet を作る (complexity 相応)。
8. RUN     : 選んだパターンを実行 (P0 直接 / P2 委譲 / P1 並列 / P3 競争 / P4 探索)。
9. GATE    : `./tools/test.sh` が §4 の当該 gate を緑にする。ACCEPT→10、REJECT→REPAIR_NOW で 8 へ (§8.4 の repair 上限)。
10. RECORD : self-review を書き、queue status を更新、Scheduled task を queue へ追加、proof log を記す。
11. COMMIT : commit 可能 status のみ `PROJECT_PROFILE.md` に従い commit。
12. LOOP   : 1 へ。
```

shared state (`IMPLEMENTATION_QUEUE.md`・proof・golden・統合ブランチ) を書くのは常に orchestrator (§0)。

### 8.2 パターン自動選択 (決定規則・上から評価)

1. F 内に depth=`decision` の task がある、または acceptance が未記録の product/UX 判断を要する → **§8.3 checkpoint** (実行しない)。
2. それ以外で |F| ≥ 2 かつ target files が disjoint な独立部分集合がある → **P1 parallel**(各 task は P2 で worktree 委譲)。
3. 単一 task:
   - core/policy/trace かつ high-value + ambiguous (実装の自由度が高く golden で裁定可能) → **P3 dual-run**。
   - UI/editor かつ contract 未確定 or 過去に難航 → **P4 spar**(UI metric で裁定)。
   - bounded かつ小さい (1-2 file, surface) → **P0**(orchestrator が直接実装)。
   - bounded だが手数が多い (integrated) → **P2 delegation**。

迷ったら保守的に倒す: 委譲より直接 (P0)、競争より委譲 (P2)。「executor が臆病」と感じたら contract の depth を直す (bolder と言わない)。

### 8.3 Checkpoint (実行せず止まり、ユーザー判断を仰ぐ)

- depth=`decision` の設計/意味論 task (例: EQM-014 event model semantics)。
- acceptance を満たすのに未記録の product/UX 決定が要るとき。
- billed/external agent run が必要なとき。
- protected branch (`main` 等) への merge。
- milestone 境界 (v0.1, v0.2, …) — 自然なレビュー点。
- gate REJECT が §8.4 の repair 上限を超えたとき。

checkpoint では「現在 frontier・選んだパターン・止まった理由・必要な判断」を 1 メッセージで提示する。

### 8.4 Stop / repair 規律

- 通常 stop 条件 (`PROJECT_PROFILE.md`): 必須環境欠如 / 外部 credential・公開 upload / repo 外破壊操作 / ユーザー指示と roadmap の直接矛盾。
- gate REJECT は同 task で repair (`REPAIR_NOW`)。**repair 上限 = 3 反復**。超えたら checkpoint で止め、findings を提示する。`REPAIR_NOW` を backlog に動かさない。
- 環境不足は `BLOCKED_BY_TEST_ENV` (docs/state commit のみ)。`SPLIT_REQUIRED` は task を分割して queue へ。

### 8.5 この repo の現況での自動進行 (参考)

v0.1 spine (EQM-002→010→011→012→013) は bounded・linear・Godot/golden gated なので **P0/P2 で自律進行**でき、**EQM-014 (depth=decision) で checkpoint** に当たって止まる。以降は editor/demo の fan-out で P1/P4 が効く。
