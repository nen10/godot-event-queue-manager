# EQM-118 Self-Review 2026-07-02

Pattern: P0 (orchestrator-direct)。Repair: 0 — 等価 assert 7 case (CTB 3 / Energy 2 / Wait-Turn 2、EQM-053 と同一 matrix、非約数 speed 含む) が初回で全て成立した。

## Execution summary

EQM-053 の監査確定した縮小 (テスト内手書き per-tick sim / order 配列比較 / product model 不使用) を解消した。CTB / Energy / Wait-Turn を **product の実装** (EQConditionSpec + EQEventLines + EQReservationRuntime pipeline) で構成し、dedicated policy と **canonical trace の `resolved` 部分列 (tick, actor, priority) の完全一致**を証明した:

- CTB: per-entity CT line (rate=speed)、`ct >= cost*scale` gate、no-carry reset、priority=speed。
- Energy: energy line (rate=speed)、閾値 100、carry (advance −spend)、priority=0。
- Wait-Turn: WT line (rate=−1) の countdown、`wt <= 0` gate、act で maxi(1,cost) 再設定、priority=agility。

product 経路の CTB 全 trace を golden fixture 化 (`reducibility_ctb_pipeline`、初回 baseline は明示 flag)。

## Product 変更 (1 点、SEM 追記済み)

**submit 時点も評価点** (SEM §5.4 追記): 既に成立している条件集合は発行時点で作用する (schedule/drop)。level 意味論の帰結で、wait=0 の初期 ready が dedicated の seed (due 0) と一致するために必要だった。既存 tests は全て「submit 時未成立」のため無変更 green。

## 比較方式の注記 (byte 同一を要求しない理由)

pipeline 側 trace には `event_line_progressed` 等の補助 record が混在し、event kind も turn/reservation で異なるため、byte 同一は構造上不可能。`resolved` record の (tick, actor, priority) 射影は両 trace から機械抽出できる最強の共通部分であり、EQM-053 の order 配列 (tick なし・trace 非経由) より厳密に強い。旧 test (dedicated ↔ 抽象 sim) は別層の保証として存置。

## Test summary

```text
./tools/test.sh -> RESULT: PASS; files=59 checks=947 failures=0
```

## Golden updates (explicit)

- `tests/golden/reducibility_ctb_pipeline.trace.jsonl` — **新規 baseline** (product 経路 CTB、speed/cost matrix 18 turns の全 canonical trace)。
- api_surface 変更なし (product 変更は既存 method 内部のみ)。

## No sample-only completion / UX path reduction

matrix は EQM-053 と同一 (cherry-pick なし; 非約数 speed の一般 case 含む)。新規入力クラスなし。

## Repair-now / follow-up

なし。次: EQM-119 (authoring surface + dogfood/manual — Phase 11 最終 task) READY。
