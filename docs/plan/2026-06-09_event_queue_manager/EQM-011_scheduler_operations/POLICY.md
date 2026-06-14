# EQM-011 POLICY

## 採用判断

- **backend contract** = 順序付きコンテナの最小操作集合 (`insert / pop_min / peek_min / ordered / size / is_empty / clear`)。これだけが public API と backend の境界。実装差し替え (sorted-array → binary heap → native) は public API を変えない (roadmap §3.2)。
- **`@abstract`** で contract を表現する。未実装メソッド呼び出しは dev fail-fast (`RUNTIME_RESILIENCE_POLICY`)。base class は `.new()` 不可。
- **liveness = generation map**。`_generation: event_id -> 現行 generation`。entry が live ⇔ `_generation[entry.event_id] == entry.generation`。serializable (EQM-012 が依存)。identity 比較ではなく int 比較なので snapshot 復元後も成立。
- **lazy invalidation**。cancel/reschedule は backend の中身を触らず generation のみ操作する O(1)。stale entry は pop で表面化した時点で discard。heap backend でも中間削除コストを払わない。
- **採番**は scheduler。`event_id` は単調増加 (再利用しない)。`sequence` も単調増加 (順序の tie-break、FIFO)。reschedule は同 event_id・新 sequence。
- **current_tick = event-driven clock**。pop で `max(current_tick, popped.due_tick)`。time-first にしない。

## 不採用判断

- caller 採番 event_id (重複責務の押し付け)。
- due_tick 直接書換 (EVENT_MODEL 違反、reschedule-only)。
- cancel 時の即時中間削除 (lazy invalidation が acceptance、heap で O(n))。

## Resource / API / UI 境界

- **public**: `EQScheduler` (push/pop/peek_next/peek/cancel/reschedule/size/is_empty/current_tick) と `EQBackend` 型。
- **internal**: `_generation`, `_next_event_id`, `_next_sequence`, backend 内部配列。
- UI 無し (headless core)。

## Invariants

- ordering key (due_tick, priority, sequence) は entry 生成後 immutable。順序変更は cancel+re-push のみ。
- `_generation` の key 集合 == 現在 live な event_id 集合。⇒ `size() == _generation.size()`。
- 1 つの event_id につき live な entry は高々 1 つ (現行 generation のもの)。
- 正常 trace は backend 実装に不変 (metamorphic: sorted-array と naive backend が同じ pop 順)。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| `_generation[event_id]` | live ⇔ entry.generation と一致。cancel で erase、reschedule で +1。 | stale entry を live と誤認 | cancel/reschedule 後の pop 順と size を assert |
| `_next_event_id` | 単調増加・再利用なし。負 tick 拒否時は消費しない。 | id 衝突 / 拒否時の番号飛び | 拒否 push 後の次 push が連番、cancel 後 id 不再利用 |
| `_next_sequence` | 単調増加。reschedule で新値。 | 同 sequence で順序非決定 | permutation/ reschedule 後の順序 assert |
| `current_tick` | pop で単調非減少、popped.due_tick へ前進。 | 時刻巻き戻り | 連続 pop で current_tick 非減少を assert |
| backend choice | scheduler は contract のみに依存 | 実装漏れ | 2 backend metamorphic 一致 test |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| 負 tick push | reject (`-1` 返却) | silent fallback 禁止。明示拒否。 | — (恒久) | `push(-1) == -1` かつ counter 不消費 |
| 未知 id の cancel/reschedule | `false` 返却 | 暗黙生成しない | — (恒久) | `cancel(999) == false` |
| 空 queue の pop | `null` 返却 | 例外でなく明示 empty | — (恒久) | `pop()` on empty == null |
