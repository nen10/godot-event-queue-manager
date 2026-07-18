# EQM-139 SUB_TASKS — relation adjacency runtime

## Complexity

Class: C3

Reason:

- 既存のderived actor adjacencyをqueryだけでなくBFS、TREE validation、serial suture、
  actor invalidationへ接続するalgorithm変更である。
- relation id順、BFS再訪、mutation中のrebound、restore再構築という隠れた不変条件を
  同時に固定する必要がある。
- correctness回帰と独立performance A/Bを別laneで完了証拠にする。

Required artifacts:

- Task Resolution / Scheduled Task Audit
- UX Candidate Matrix
- State / Invariant Table
- Dependency / Test Matrix

## Task Resolution

| candidate | value | decision | reason |
|---|---|---|---|
| A. actor局所処理でも`relation_ids()`を全走査 | 実装が単純 | reject | sparse graphで無関係edgeに比例する |
| B. `_actor_relations`をcanonical table化 | lookupが直接的 | reject | snapshot/trace/mutationのtruthが二重化する |
| C. sorted adjacency idを入口にcanonical relationを読む | 局所work + 既存意味論 | adopt | `_relations`をtruthのまま保ち、既存indexを再利用できる |
| D. actorごとのrelation payload複製cache | query最速 | defer | payload整合とinvert/restore invalidationが過剰 |
| E. maintenanceもactor adjacencyへ変更 | 全scan削減 | reject | maintenanceは全relationを評価する処理でactor起点ではない |

## Scheduled Task Audit

新しいscheduled taskはない。event-line sparse pollingはEQM-140、reaction FIRE condition
semanticsはEQM-141として既にqueue済み。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| `_relations` | canonical relation payload table | derived indexをtruth扱い | queryはidからcanonical payloadを読む |
| `_actor_relations` | actorごとのincident id、String relation id昇順、一id一回 | add/remove/invert/restoreでstale/duplicate | bind/invert/dissolve/restore exact adjacency |
| query result | relation id順、deep copy | caller mutationでgraph破壊 | result Array/payload mutation regression |
| expansion | relation id順BFS、再訪もcost/enqueue、outputは一actor一回 | adjacency化で順序/loop cutoff drift | legacy parity + cycle/budget exact result |
| invalidation | 開始時incident idのcopyを順にdissolve | dissolve/rebound中のindex mutation | exact dissolve trace + serial rebound |
| duplicate restore id | canonicalは検証後の後勝ち、旧endpointは所有権を失う | stale adjacencyが別relationを返す/消す | replacement-safe add + stale endpoint invalidation regression |
| full-table paths | maintenance/serializationはcanonical全走査 | unrelated relationを評価/保存しない | existing maintenance/roundtrip regression |
