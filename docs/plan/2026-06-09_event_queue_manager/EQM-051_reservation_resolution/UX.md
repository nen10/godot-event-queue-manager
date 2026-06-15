# EQM-051 UX

利用者 = addon consumer (L2 deep path) / EQM-052 policy。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. submit(reservation) で kind に応じ scheduling | high | low | low | adopt | consumer は reservation を投げるだけ。 |
| B. resolve_next() で 1 件解決 + 効果適用 | high | low | low | adopt | immediate/prepared/wait/operation の意味を集約。 |
| C. operation が target に reservation を起こす | high | low | low | adopt | Action Resolution の核 (反応誘発)。 |
| D. reaction-prep は arm のみ (発火は EQM-061) | high | low | low | adopt | trigger phase へ責務分離。 |

## User goal

EQReservation を submit すると kind に応じて scheduler に載り、resolve_next で immediate は即時、prepared は遅延後、wait は ready 予約を生み、operation は対象に reservation を起こす。reaction-prep は arm される。

## Operation steps

1. `var rr := EQReservationRuntime.new()`; actor を `rr.runtime.register_actor(...)`。
2. `rr.submit(EQReservation.new(actor, def))`。
3. `var res := rr.resolve_next()` → 解決 + 効果適用。
4. operation: `res2.target_id = target`; submit/resolve → target に reservation。

## 既存 UX との干渉

新規 L2 runtime。EQReservation に target_id 追加 (L2 surface)。L0/L1 不変。golden 更新。
