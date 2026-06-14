# EQM-012 IMPLEMENTATION_PLAN

## Scope

scheduler state の serializable snapshot/restore を実装する。schema_version + 未知 version の stable load error を確立する。policy/trace/node-bridge は含めない。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_snapshot.gd` — `EQSnapshot`: `SCHEMA_VERSION`、`Load` enum、`validate`、`describe`。
- `addons/event_queue_manager/runtime/eq_scheduler.gd` — `snapshot() -> Dictionary` / `restore(Dictionary) -> int` を追加。
- `test_project/tests/core/test_eq_snapshot.gd` — roundtrip 忠実性 + 未知 version/malformed の stable error + error 時不変。

## 実装 steps

1. `EQSnapshot` を作成 (version 定数 + validate(version 先 → 構造) + describe + Load enum)。
2. `EQScheduler.snapshot()` を実装 (live entry を to_dict、counters/current_tick 同梱)。
3. `EQScheduler.restore()` を実装 (validate → 非破壊 build → commit、`_generation` を entry から再構築)。
4. test を作成。
5. `./tools/test.sh` PASS を確認。

## Test path

- `./tools/test.sh` → import pass → headless runner。
- 期待: 既存 50 checks + EQM-012 の新 checks 全 pass、`failures=0`、exit 0。

## Dependency / Test Matrix

| dependency / area | risk | proof / test |
|---|---|---|
| EQM-011 scheduler state (current_tick/counters/generation) | 復元欠落で pop 順ずれ | 保存前後の pop 列一致、current_tick・次 push id 一致 |
| EQEntry.to_dict/from_dict (EQM-010) | 直列化往復で entry 破損 | roundtrip entry の keys/payload 一致 |
| lazy invalidation (EQM-011) | stale 混入 / 復元後の二重 pop | cancel 後 snapshot の entries 数、復元後 pop に stale なし |
| schema_version contract | 未知 version の不安定 error | version=999 で UNKNOWN_VERSION 固定、scheduler 不変 |
| restore 非破壊性 | error path で破壊 | error 時に既存 entry の pop 順維持 |

## Completion checklist

- [ ] snapshot() が plain Dictionary を返し schema_version を持つ。
- [ ] roundtrip で current_tick・next_event_id・next_sequence・live entries・generations・pop 順が一致。
- [ ] cancel 後の snapshot は live entry のみ (stale compaction)。
- [ ] 復元後に cancel/reschedule/push が正しく機能 (counters/generation 整合)。
- [ ] 未知 schema_version → `Load.UNKNOWN_VERSION`、scheduler 不変、毎回同コード。
- [ ] MALFORMED (構造欠落) → `Load.MALFORMED`、scheduler 不変。
- [ ] `./tools/test.sh` PASS。
