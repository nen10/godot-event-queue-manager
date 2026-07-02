# EQM-117 Self-Review 2026-07-02

Pattern: P0 (orchestrator-direct)。Repair: 0。

## Execution summary

SEM v1.1 §10 (Q41) を実装した。save bundle を `SCHEMA_VERSION 2` へ bump し、additive tables (event_lines / windows / armed_triggers / pending_conditional / scheduled_reservations) を追加。`EQSaveAdapter.save(runtime, pipeline)` は `is_save_boundary()` (chunk 空 ∧ 明示 window なし) を enforce し、境界外は `eqm.save.blocked` + 空 bundle (force flag なし)。load は **verify-before-mutate**: bundle が参照する sweep rule / predicate / effect 名の登録を検査してから適用し、未登録は安定 error + runtime 無変更。v1 bundle は欠落 table = 空で load (SNAPSHOT_COMPAT の migrate stance を履行)、未知 version は従来どおり清潔に拒否。Callable は一切 serialize されない (EQCondition.to_dict は custom_predicate 除外)。

## Acceptance result — met

roundtrip test: lines (値/rate/counter_seq)・条件 gate 済み予約 (bound terms ごと)・armed 反応 (+expiry event link)・scheduled 予約 (+invalidation terms) を跨いで保存/復元し、復元側が**同一の継続 resolution 列**を辿ることを固定。既存 v1 save/load tests (EQM-085) は無変更 green。

## Limitations (正直な記録)

- **windows table は常に空**: save は boundary gate により window_depth 0 でのみ成立するため、非空は到達不能。key は schema shape として保持 (将来の rollback-bundle 用)。
- **open race 帳簿は非 serialize**: member 予約自体は保存される。save を跨いだ race では勝者解決時の敗者一括一掃が働かず、敗者は自身の invalidation 条件でのみ閉じる。需要発生時に帳簿 serialize を起票する。
- EQManager への save API は不採用 (L0 経路に chunk/window がなく gate 対象がない — queue target からの deviation)。

## Test summary

```text
./tools/test.sh -> RESULT: PASS; files=58 checks=938 failures=0
[contract-coverage] flip 後 implemented=19 reserved=2
```

## Golden updates (explicit)

`tests/golden/api_surface.json` のみ。

## No sample-only completion / UX path reduction

合成 pipeline 状態の roundtrip property 検証。force save flag という「広い入口」を仕様として拒否した。

## Repair-now / follow-up

なし。declared follow-up: race 帳簿 serialize (需要時)。次: EQM-118 (reducibility 再証明) READY。
