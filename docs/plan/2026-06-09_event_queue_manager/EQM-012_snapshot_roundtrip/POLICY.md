# EQM-012 POLICY

## 採用判断

- **EQSnapshot = format/version authority**。`SCHEMA_VERSION` 定数、`validate(data) -> Load`、`describe(code)`。serialize 形式と version 検証の単一の置き場所。
- **EQScheduler = state capture/apply**。自分の internals を知る scheduler が `snapshot()` で dict 化し、`restore()` で適用する。EQSnapshot が format を、scheduler が state を所有する分離。
- **live state のみ snapshot する**。`_backend.ordered()` の live entry のみを `to_dict()`。stale (cancel/reschedule で取り残された) entry は lazy-deletion の実装詳細で観測意味を持たないため compact する。
- **`_generation` は entry から再構築**する。live entry は generation を保持しており、`_generation[event_id] = entry.generation` で復元すれば「live event_id 集合 == _generation key 集合」「event_id ごと live entry は高々1」の invariant が構造的に保たれる。冗長な map を serialize しない。
- **counters は明示 serialize**する。`next_event_id` / `next_sequence` は live entry から導出不能 (popped/cancelled を含む過去の最大値に依存)。`current_tick` も同様。
- **restore は validate → build(非破壊) → commit の順**。error code が OK 以外なら scheduler を一切変更しない。OK のとき初めて clear + 再構築。
- **未知 version は stable load error** (`UNKNOWN_VERSION`)。crash させない (RUNTIME_RESILIENCE: shipped fail-safe)。version 検査を構造検査より先に行う (未知 version は形が違い得る)。

## 不採用判断

- stale entry の serialize (実装詳細の漏れ)。
- `_generation` の独立 serialize (冗長、不整合リスク)。
- bool-only restore (UNKNOWN_VERSION と MALFORMED を区別不能)。
- 未知 version の例外/crash (fail-safe 違反)。

## Resource / API / UI 境界

- **public**: `EQScheduler.snapshot() -> Dictionary`、`EQScheduler.restore(Dictionary) -> int`、`EQSnapshot.SCHEMA_VERSION`、`EQSnapshot.Load`、`EQSnapshot.validate/describe`。
- **internal**: dict 化の鍵名、再構築手順。
- snapshot dict は plain (Node 参照禁止、serializable core)。

## Invariants

- roundtrip: `snapshot → restore` 後、current_tick・next_event_id・next_sequence・live entries・generations・以降の pop 順が保存時と同一。
- restore error 時、対象 scheduler は呼び出し前と完全に同一。
- snapshot dict は常に `schema_version` を持つ。
- 復元後も「live event_id 集合 == _generation key 集合」が成立。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| snapshot dict | `schema_version` を必ず持つ。entries は live のみ。 | 形式漏れ / stale 混入 | snapshot dict の schema_version と entries 数 (cancel 後) を assert |
| restore(OK) | current_tick/counters/pop順 が roundtrip で一致 | 復元欠落 | A=保存前 pop 列、B=復元後 pop 列、A==B。current_tick・次 push id 一致 |
| restore(error) | scheduler 不変 | error path で破壊 | 既存 entry を持つ scheduler に未知 version/MALFORMED を restore→不変 + 元の pop 順維持 |
| `_generation` 再構築 | live entry から一意復元 | 不整合 | 復元後 cancel/reschedule が機能、size 整合 |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| 未知 schema_version | `Load.UNKNOWN_VERSION` 返却、scheduler 不変 | shipped fail-safe、stable error | compat 方針変更時 (EQM-103) | schema_version=999 で UNKNOWN_VERSION、毎回同コード |
| 構造欠落 (top-level key 不足) | `Load.MALFORMED` 返却、不変 | silent 読み込み禁止 | — | `{}` / 欠落 dict で MALFORMED |
| valid-version 内の malformed entry | 本 task では非対象。defensive に MALFORMED 返却 (silent skip しない) | 完全 fail-safe は error taxonomy (EQM-020) / resilience modes (EQM-022) が所有 | EQM-020/022 完了時に taxonomy へ統合 | self-review に既知制約として記録 |
