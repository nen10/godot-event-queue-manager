# EQM-012 UX

API 利用者から見た snapshot/restore 操作。save/load (EQM-085) と prediction (EQM-033) の基盤。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. snapshot() が plain Dictionary を返す | high | low | low | adopt | JSON/`.tres` どちらにも乗る。Node 参照を含めない (serializable core)。 |
| B. restore() が結果コードを返す | high | low | low | adopt | 未知 version を crash させず stable error。dev は assert OK。 |
| C. restore が bool だけ返す | medium | medium | low | reject | UNKNOWN_VERSION と MALFORMED を区別できない。 |
| D. snapshot が stale entry も保持 | low | medium | medium | reject | 観測意味なし。live state のみで pop 順は完全再現。 |

## User goal

scheduler の状態を直列化して保存し、後で復元すると、その後の pop 順・採番・cancel/reschedule が保存時と同一に再現される。未知 schema の data を読んでも crash せず明示エラーになる。

## Operation steps

1. `var data := s.snapshot()` — plain Dictionary (schema_version 付き)。Node 参照を含まない。
2. (任意) JSON / `.tres` へ保存。
3. `var code := s2.restore(data)` — `EQSnapshot.Load.OK` なら復元成功。`UNKNOWN_VERSION` / `MALFORMED` なら `s2` は不変。
4. 復元後の `s2` は保存時と同じ current_tick・採番・pop 順を持つ。

## 採用 / 廃止

- 採用: plain Dictionary snapshot、結果コード返却、live state compaction。
- 廃止 (hack 化しない): 未知 version の silent 読み込み、stale entry の serialize、bool-only restore。

## 既存 UX との干渉

EQScheduler に `snapshot()` / `restore()` を追加するのみ。既存 push/pop/peek/cancel/reschedule に影響なし。
