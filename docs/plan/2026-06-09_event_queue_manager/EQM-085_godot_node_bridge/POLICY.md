# EQM-085 POLICY

## 採用判断

- **EQSaveAdapter (L0)**: `save(runtime) -> Dictionary` = schema_version + scheduler.snapshot() + 各 active actor の to_dict (actor_id + data)。**live Node を含まない**。`load(into_runtime, data, rebind={}) -> bool` = scheduler.restore + 各 actor を re-register + data 復元 + rebind map で `state.bind(node)`。未知 schema は false。
- **EQNodeBridge (Node, L0)**: `bind_actor(actor_id, node)` (WeakRef + state.bind)、`node_for`、`on_actor_freed(actor_id)` = registry.unregister → runtime の Q05 invalidation 経路で pending を skip + `event_invalidated` emit、`prune_freed()` で WeakRef 失効を一括処理。
- **multi-domain signal bridge**: `turn_ready` / `reservation_resolved` / `trigger_fired` / `effect_recorded` / `presentation_flushed` / `event_invalidated`。manager.turn_ready / invalid_event_skipped を forward、残り domain は `notify_*` helper で consumer が emit (dogfood F2 対応)。
- **autoload opt-in**: 自動 install しない。bridge は scene-local Node として動作 (profile 既定)。opt-in は doc。
- live Node を保存形式に混ぜない (Adapter 原則): actor_id + WeakRef のみ。

## 不採用判断

- save に live Node を含める。
- actor 削除で crash (invalidation 経路 = shipped fail-safe)。
- autoload 強制 (scene-local 既定)。

## Invariants

- save dict は live Node 参照を含まない (actor_id + data + int のみ)。
- load + rebind 後、pop 順が save 前と一致 (scheduler 復元)。
- actor 削除後、その pending events は advance で skip (invalidation)、scheduler 整合維持。
- bridge は autoload なしで scene-local 動作。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| save dict | live Node なし、actor_id+data+int | Node 漏洩 | save に binding/Object なし |
| load + rebind | pop 順再現、actor bound | 復元欠落 | load 後 pop 列一致、bound node |
| actor freed | pending skip (invalidation) | 幽霊 event / crash | on_actor_freed 後 advance で skip、shipped |
| signal bridge | 6 domain 発火 | signal 欠落 | 各 domain の emit 検査 |
| scene-local | autoload 不要 | autoload 強制 | bridge 単体動作 |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| save に Node | 不含 (actor_id+data) | Adapter 原則 | — | save dict 検査 |
| actor 削除 | unregister=invalidation | fail-safe | — | freed 後 skip |
| autoload | opt-in、scene-local 既定 | profile | — | scene-local 動作 |
| 未知 save schema | load false | stable | — | bad schema_version |
