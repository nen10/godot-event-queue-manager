# EQM-139 IMPLEMENTATION PLAN — relation adjacency runtime

## Scope

actor起点のrelation query、BFS expansion、actor invalidation、TREE/serial helperを既存の
sorted actor adjacencyへ接続し、無関係relationのfull scanを除く。

## Target files

- `addons/event_queue_manager/runtime/eq_relation_graph.gd`
- `test_project/tests/core/test_eq_relation_graph.gd`
- `test_project/tests/core/test_eq_resolution_rewrites.gd`
- `test_project/tests/performance/test_eq_relation_graph_adjacency.gd`
- `docs/design/RUNTIME_PERFORMANCE_PROFILE.md`
- queue/self-review/test inventory

## Implementation steps

1. sorted incident relation idをfresh Arrayで返すprivate helperを追加する。
2. duplicate restore idのreplacement前に旧endpoint adjacencyを除去する。
3. `relations_of`と`invalidate_actor`をincident id反復へ変更する。
4. `expand`をfrontier actorごとのincident id反復へ変更し、canonical payloadを直接読む。
5. TREE parent/incoming/outgoing lookupをincident id反復へ変更する。
6. bind/invert/dissolve/restore、query ownership、exact trace、BFS cycle/budgetを回帰で固定する。
7. performance laneで同一graph上の旧full-scan実装とのoutput parity、inspection count、elapsed A/Bを記録する。
8. full regression、independent performance、API/snapshot/trace auditを実行する。
9. self-review、runtime profile、queue proofを更新してcommitする。

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| adjacency ordering | query/BFS順序drift | double-digit idを含むexact relation id order |
| payload ownership | caller mutation | returned Array/Dictionary mutation後の再照会 |
| mutation iteration | dissolveでadjacency縮小 | copied incident ids + exact dissolve trace |
| serial suture | rebound対象/順序drift | chain actor invalidation exact rebound state |
| TREE constraint | parent見落とし | bind/restore/invert rollback regression |
| BFS cycle/budget | adjacency化で再訪規律drift | legacy output parity + exact bounded cycle |
| maintenance/serialization | sparse化の誤適用 | existing all-relation maintenance/roundtrip |
| duplicate restore id | old endpoint adjacency残留 | last-wins canonical payload + stale endpoint query/invalidate |
| elapsed evidence | noisy ratio | warmup + alternating repeated batches; ratio advisory only |
| lane separation | speed test enters regression | explicit discovery counts from both commands |

## Completion checklist

- [x] Actor-local production paths inspect only incident relation ids.
- [x] Exact query/BFS/invalidation order and TREE/GRAPH semantics match legacy behavior.
- [x] Maintenance, trace, snapshot roundtrip, API surface remain unchanged.
- [x] Deterministic work-count reduction and advisory A/B are recorded independently.
- [x] Regression and performance commands pass.
- [x] Self-review has no repair-now item and queue dependency sweep is updated.
