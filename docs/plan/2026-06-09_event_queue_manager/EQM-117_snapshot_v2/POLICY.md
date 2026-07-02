# EQM-117 POLICY — snapshot v2 + save 境界 enforcement

## 採用判断

- **bundle v2 は additive + migrator**: `SNAPSHOT_COMPAT_V1.md` の stance (preserve/migrate/replace/defer) に従い、v1 bundle は欠落 table = 空として load (明示 migrator)。新 reader は v1/v2 両対応、旧 reader は v2 を清潔に拒否 (既存 fail-safe)。
- **save gate**: `EQSaveAdapter.save(runtime, pipeline)` は `pipeline.is_save_boundary()` (chunk 空 ∧ 明示 window なし) を要求。違反 = `eqm.save.blocked` fault + 空 bundle。force flag は設けない (Q41)。draft の save 既定 = Q01 (boundary へ rollback してから save するのは acceptance の操作)。
- **verify-before-mutate load**: 復元前に { sweep rule 名 (lines 側 registry), NAMED_PREDICATE 名, effect_name / expiry_effect_name } の登録を検査。未登録 = 安定 error (predicate/effect の既存 codes) + false、runtime は未変更。
- **serialize は名前と data のみ**: Callable / live object は一切保存しない (EQCondition.to_dict は custom_predicate を除外)。`contains_live_object` を test で適用。

## 不採用判断 / 制限の明記

- **windows table = 常に空** (boundary gate の帰結、到達不能 path を作らない)。key は schema shape として保持。
- **race 帳簿は非 serialize** (SUB_TASKS F): open race を跨ぐ save では、復元後に勝者が解決しても敗者一掃 (`race_lost` 一括) は行われない — 敗者は自身の invalidation 条件でのみ閉じる。制限として本 POLICY と self-review に明記、需要時に起票。
- EQManager への save API (G)。

## Invariants / State Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| bundle | live object 不含・schema_version 必須 | Node 混入 | contains_live_object test |
| save gate | boundary 外で bundle を作らない | 半端な状態の保存 | blocked test (chunk 非空 / window open) |
| load | 検査失敗時は runtime 未変更 | 半 load | 未登録 predicate load 後の状態 test |
| roundtrip | lines/conditional/armed/scheduled を跨いで同一継続 | 復元漏れ | 継続順序の同一性 test |
| 互換 | v1 bundle load 可 / 未知 version 拒否 | 黙示の再解釈 | migrator + reject test |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| v1 bundle | 欠落 table = 空で受理 (migrator) | preserve stance | v2.0 で v1 打ち切り判断まで | v1 load test |
| 復元後の counter 継続 | counter_seq 保存で id 再利用なし | replay 同一性 | — | EQM-112 roundtrip test (既存) |
| open race を跨ぐ save | 非対応を明記 (fault にはしない — member 自体は正しく保存) | 帳簿の複雑さ回避 | 需要時の帳簿 serialize | docs 明記 (test なし — 到達可能だが挙動は member 単位で正しい) |
