# EQM-139 Self Review — relation adjacency runtime

Date: 2026-07-18
Task: EQM-139 / roadmap Phase 15 / queue Phase 14
Primary classification: relation determinism + runtime performance

## Outcome

`EQRelationGraph`が既に維持していたsorted actor adjacencyを、`relations_of`、BFS
`expand`、actor invalidation、TREE parent validation、serial-suture incoming/outgoingへ接続した。
actor起点の処理は無関係relationを走査せず、canonical truthは従来どおり`_relations`にある。

監査で、restoreの重複relation idがcanonical payloadを置換しても旧endpoint adjacencyを
残す既存問題を発見した。replacement成立時に旧relationをdeindexしてから同じidを再indexし、
stale endpointによる誤query/誤invalidationを閉じた。

Public API、resource/snapshot schema、trace/goldenは変更していない。全relationが評価対象の
maintenance、serialization、public `relation_ids()`は意図的にglobal scanを維持した。

## Acceptance review

- [x] `relations_of`はincident idだけをString relation-id順に読み、deep copyを返す。
- [x] `expand`はfrontier actorごとのincident idだけを読み、既存の再訪/cost/BFS順を維持する。
- [x] actor invalidationは開始時incident idのfresh copyを解消し、serial reboundを追加対象にしない。
- [x] TREE bind/invert/restoreとserial suture helperがactor adjacencyを使う。
- [x] double-digit id、self-loop、failed invert rollback、duplicate restore idを専用回帰で固定した。
- [x] maintenance、snapshot roundtrip、trace、API、既存goldenは不変。
- [x] regression/performance discovery分離を維持し、双方PASS。

## Algorithm / state audit

| area | result |
|---|---|
| canonical state | `_relations`のまま。`_actor_relations`は非serialize派生状態 |
| adjacency order | `String(relation_id)`昇順。self-loopも一id一回 |
| query ownership | incident id Arrayはfresh shallow copy、public payloadはdeep copy |
| expansion | 各frontierでincident idのみ。canonical payloadはread-only direct lookup |
| invalidation | mutation前のsorted incident snapshotを反復 |
| replacement | duplicate idのvalidation後、旧endpointをremoveしてlast accepted payloadをindex |
| global paths | maintenance / serialization / `relation_ids()`は目的上full scanを維持 |

## Performance evidence

Fixtureは2,048 GRAPH relations、選択actor degree 9（requested type 8 + other type 1）。
hard gateはexact payload/order/BFS/state/trace、production global-id call数0、inspection count。

| path | legacy ids | adjacency ids | deterministic work reduction | advisory speedup range |
|---|---:|---:|---:|---:|
| `relations_of` | 2,048 | 9 | 227.6x | 517.50–528.69x |
| bounded `expand` | 34,816 | 89 | 391.2x | 647.39–656.32x |
| invalidation selection | 2,048 | 9 | 227.6x | 975.11–1,071.40x |

各elapsed値は5 warmups後、6 samples（旧→新/新→旧を3回ずつ）のcentral-pair average。
batchはquery 80回、expand 6回、selection 150回で、3 complete runsのraw sample/central値は
`docs/design/RUNTIME_PERFORMANCE_PROFILE.md`に記録した。比率はrelation局所処理だけであり、
`step_tick`全体、frame、consumer runtimeの倍率ではない。

## Test summary

| command | result | classification |
|---|---|---|
| `./tools/test.sh` | PASS: 74 files / 1,792 checks / 0 failures (`20260718-231233-76887`); API/coverage/golden/package gates PASS | passed |
| `./tools/test.sh --performance` | PASS: 5 files / 41 checks / 0 failures (`20260718-231246-77781`) | passed |
| same performance command | PASS (`20260718-231308-78743`) | repeated evidence |
| same performance command | PASS (`20260718-231337-79346`) | repeated evidence |

## Deviation / repair-now audit

| item | classification | resolution |
|---|---|---|
| duplicate restore id left stale actor adjacency | repair-now correctness invariant | replacement-safe `_add_relation` + stale endpoint query/invalidate regression |
| first performance load used non-constant `Array.size()` and inferred Variant | repair-now test parse | fixed constant/type annotation; discarded run `20260718-230309-37603`; three clean runs collected |
| first reviewed expand A/B timed an instrumented legacy oracle | repair-now measurement validity | discarded runs `20260718-230554-49686` / `20260718-230640-53612` / `20260718-230707-55950`; counter-free exact legacy timing helperで再計測 |
| TREE duplicate id counted its own old payload as another parent | repair-now restore semantics | same idだけparent checkから除外し、別id parent拒否も回帰で固定 |
| very large sparse-fixture ratios | advisory scope risk | raw batches/work counts公開、operation-localと明記、elapsedをhard gateに不使用 |
| post-repair independent re-review | passed | TREE replacement、counter-free legacy timing、3-run値、lane分離にrepair-nowなし |

Repair-now: none.
Follow-up-ready: EQM-140 sparse event-line polling (already queued).
Proof grade: `contract_tested` + deterministic work gate + environment-labelled advisory A/B.
