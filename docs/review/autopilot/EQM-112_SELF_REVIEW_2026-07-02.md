# EQM-112 Self-Review 2026-07-02

Pattern: P0 (orchestrator-direct)。Repair: 0 (新規 2 test file 初回 green)。

## Execution summary

SEM v1.1 §4.3/§4.6/§4.7/§12.1 の event-line backend を実装した。`EQEventLines` (L3): data-only line table `{id, value, rate}`、前進 2 経路 (watched∧rate≠0 の sparse `poll_tick` / effect からの明示 `advance`)、`re_rate`、deterministic counter 採番 (`eqm.counter.<seq>`)、primary line の scheduler 鏡映 (`sync_primary`)、pending 条件からの `derive_watched`、named sweep rule registry (登録順 × actor_id 昇順、pattern (2))、cause 別 `event_line_progressed` の実 emit、faults 記録 (throw しない)、callable 不含の dict roundtrip。

## Acceptance result — met

| acceptance | result |
|---|---|
| line = data のみ / 明示 advance / re-rate | int 型 API + roundtrip test。callable update rule なし |
| deterministic 採番 | counter seq 単調・fresh instance 同一 id・restore 後継続 (再利用なし) test |
| watched 導出 + sparse polling | derive_watched (bound terms union) + unwatched/frozen 非前進 test |
| event_line_progressed 実 emit | issued/advanced/poll/re_rated/sweep_rule の cause 別記録、jsonl 検証 |
| sweep rule registry | 登録順固定・actor_id 昇順・rule name trace・置換/空名 fault test |
| Q43 予算 | 300 watched lines × 200 polls ≤ 400ms (宣言 0.5ms/poll × 4x CI headroom)、200 actors × 50 sweeps ≤ 100ms — EQM-102 と同じ粗い guard 方針 |
| L3 leak なし | standalone class。EQRuntime/L0 署名に型不露出 (leak detector green) |
| coverage 3 rows flip | event-line-backend / sweep-rule-registry / progression-budgets -> implemented |

## Test summary

```text
./tools/test.sh -> RESULT: PASS; files=52 checks=780 failures=0
[api-surface] ok (no L3 leak) / [contract-coverage] violations=0 (flip 後 implemented=11)
```

## Golden updates (explicit)

- `tests/golden/api_surface.json` — +EQEventLines (L3) のみ。ordering/trace golden 変更なし。

## Deviations

- `PRIMARY_LINE_ID` は L3 側で再宣言し、L2 (`EQActionDefinition.PRIMARY_LINE_ID`) との同値を test で固定した (L3→L2 resources への preload 依存を避ける。drift は test が検出)。
- poll の trace 抑制 flag は導入しない (SEM §2.1: 観測は削っても挙動不変が原則)。予算 test は trace 付きで測定 (honest cost)。
- scheduler との実配線 (`sync_primary` の呼び出し点、条件 gate 済み event の pop 統合) は EQM-113 の scope。

## No sample-only completion

Property 検証 (挿入順入替で同 trace、fresh instance 同一採番、CT 到達 tick の厳密値 20) が中心。sample preset 依存なし。

## UX path reduction

前進経路を 2 つ (poll / 明示 advance) に固定し、callable update rule・rate 帯域という広い入口は不採用 (Q33 確定)。既存 API 変更なし (additive)。

## Repair-now / follow-up

なし。次: EQM-113 (解決 pipeline 統合) READY — Phase 11 の要 (5-step 契約 / chunk 配線 / reaction schedule 化 / invalidate_actor / expiry event)。
