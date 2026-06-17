# EQM-071 UX

利用者 = Action Resolution の player turn を扱う game developer。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. immediate action を試し wait 前なら rollback | high | low | low | adopt | 試行錯誤を first-class (PROJECT_PROFILE)。 |
| B. wait が turn を確定し次 ready を schedule | high | low | low | adopt | wait = commit + AP 回復後の次 turn。 |
| C. commit 後は draft 不可 | high | low | low | adopt | commit 境界の整合。 |

## User goal

player turn 中の immediate action は draft され、wait する前なら rollback で取り消せる。wait すると draft が live に commit され、AP 回復後の ready 予約 (次 turn) が schedule される。

## Operation steps

1. `var tx := EQTransaction.new(rt.scheduler)`。
2. immediate action: `tx.draft_push(...)`。気が変われば `tx.rollback()` (live 不変)。
3. wait: `policy.wait_close(rt, actor_id, EQActionResult.new(ap_cost, 0), tx)` → commit + ready 予約。

## 既存 UX との干渉

EQActionResolutionPolicy に wait_close 追加 (surface 変更 → golden)。EQTransaction に commit 後 guard。L0/L1 不変。
