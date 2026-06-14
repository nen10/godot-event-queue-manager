# EQM-011 SUB_TASKS

## Complexity

Class: C3
Reason:
- 複数ファイル (EQScheduler + EQBackend contract + EQSortedArrayBackend) にまたがる。
- backend を **language-agnostic contract interface** の背後に隠し、sorted-array → binary heap → native を public API 不変で差し替え可能にする横断判断を含む (roadmap §3.2, principle 19)。
- lazy invalidation / generation の意味論を決め、EQM-012 (snapshot) / EQM-013 (trace) が乗る scheduler state 不変条件を確立する。

Required artifacts: Complexity header / Task Resolution / Scheduled Task Audit / UX (最小) / POLICY (境界 + Invariant Table) / IMPLEMENTATION_PLAN (dependency/test matrix)。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQBackend (abstract contract) | 順序付きコンテナの最小 contract | adopt | `insert / pop_min / peek_min / ordered / size / is_empty / clear`。`@abstract` で未実装呼び出しを dev fail-fast。 |
| EQSortedArrayBackend | sorted-array 実装 | adopt | `bsearch_custom` で順序挿入、`pop_front` で最小取り出し。MVP backend。 |
| EQScheduler | push/pop/peek/cancel/reschedule + lazy invalidation | adopt | event_id / sequence を採番。`_generation` map で liveness を持つ。 |
| generation = liveness の単一真実 | cancel/reschedule を O(1) lazy 化、snapshot 安全 | adopt | `_generation` の key 集合 == live event_id 集合。`size()=_generation.size()`。 |
| current_tick = event-driven clock | pop で `max(current_tick, due_tick)` へ前進 | adopt | time-first にしない (event が時刻を決める)。EQM-012 が snapshot する。 |
| reschedule = cancel+re-push (同 event_id, 新 sequence, gen+1) | due_tick 直接書換禁止の唯一の経路 | adopt | EVENT_MODEL: reschedule-only。旧 entry は stale 化。 |
| 2nd backend を test 内に定義し metamorphic 比較 | contract 抽象が漏れていない証明 | adopt | 素朴な unsorted backend を通しても pop 順が一致 → scheduler は contract のみに依存。 |
| eager (即時) deletion backend 操作 | cancel 時に中身を即削除 | reject | lazy invalidation が acceptance。即削除は heap で O(n)。pop 時 discard に統一。 |

## Scheduled Task Audit

新規 scheduled task なし。次の依存解放は EQM-012 (snapshot roundtrip)。current_tick / sequence counter / generation を EQM-011 で scheduler state として確立し、EQM-012 がそれを serialize する。
