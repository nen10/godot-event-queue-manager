# EQM-117 UX — snapshot v2 + save 境界 enforcement

user goal: 条件・進行・反応を使う game でも save/load が「全部戻る」こと。境界外 save は黙って壊れず、明示 error になること。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. bundle v2 additive + save gate + verify-load | high | medium | high | adopt | Q41 確定。互換 stance を守りつつ L2 状態を保存 |
| B. force save flag | low | high | low | reject | Q41 で不採用確定 (silent 半端保存の入口) |
| C. race 帳簿まで serialize | medium | medium | medium | reject (明記) | member 予約は保存される。帳簿は需要時 |

## Operation steps

1. save: `EQSaveAdapter.save(rr.runtime, rr)` — boundary (chunk 空 ∧ window なし) でのみ bundle が返る。外なら `eqm.save.blocked` を受けて game 側が boundary へ誘導する。
2. load: 起動時に predicates / effects / sweep rules を登録した上で `EQSaveAdapter.load(rt, bundle, rebind, rr)`。未登録名は false + 安定 error (半 load しない)。
3. v1.0 の save はそのまま読める (欠落 = 空)。将来 schema の save は清潔に拒否される。

- 採用 UX: 単一 save 経路 + 明示 gate。廃止/保留: なし。干渉: 既存 v1 bundle 利用者は無変更で動く。
