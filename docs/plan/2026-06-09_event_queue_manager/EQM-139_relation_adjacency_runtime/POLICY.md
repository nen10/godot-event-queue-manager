# EQM-139 POLICY — canonical relation table with sorted actor adjacency

## Adopted decisions

- canonical truthは`_relations`。`_actor_relations`はserializeしない再構築可能な派生索引。
- actor adjacencyはrelation idのString昇順を保ち、self-loopも一idだけ格納する。
- actor局所処理はadjacencyのfresh copyを得て、payloadはcanonical tableから読む。
- `relations_of`はpayloadをdeep copyして返し、内部Array/Dictionaryを公開しない。
- `invalidate_actor`は開始時incident idのcopyを反復する。dissolve中にindexが変化しても、
  既存どおり開始後に生成されたserial reboundを追加対象にしない。
- `expand`は各frontier actorのincident idだけを昇順に読む。BFS再訪、cost消費、output重複抑止は不変。
- TREE parent validationとserial sutureのincoming/outgoing lookupも同じadjacencyを使う。
- maintenance、serialization、canonical `relation_ids()`は目的上全relation走査を維持する。
- restoreの重複relation idは既存validation順とcanonical replacement規律を維持し、
  replacementが成立する時だけ旧endpoint adjacencyを先に除去する。

## Compatibility / determinism

- bind/dissolve/invert/restore、TREE/GRAPH、serial suture、maintenanceの意味論は不変。
- public API、API golden、snapshot schema、trace/goldenは不変。
- hard gateはexact relation ids/payload/order/BFS/trace/snapshotとinspection work count。
  elapsed speedupは同一processのadvisoryであり合否条件にしない。
- 通常回帰はperformance fixtureをdiscoverせず、performance commandはperformanceだけを走らせる。

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| actor局所full scan | remove | unrelated graph sizeに比例する | immediate | test-only legacy parity + work count |
| duplicate payload cache | do not add | canonical stateを二重化する | future profile only | n/a |
| full maintenance scan | retain | 全relation評価が処理目的 | n/a | maintenance regression |

## State / Invariant proof

add/remove/invert/restoreは全て既存の`_add_relation`/`_remove_relation`を通るため、adjacencyは
canonical mutationと同時に更新される。既存idのaddは旧endpointを除去してから再indexする。
query/traversalはid copyだけを保持し、relation payloadを変更しない。mutationを伴う
invalidationだけはcopyを必須とする。
