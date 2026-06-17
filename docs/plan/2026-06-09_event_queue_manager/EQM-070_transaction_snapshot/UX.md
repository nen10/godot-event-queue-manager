# EQM-070 UX

利用者 = player-turn を扱う game developer (試行錯誤 → wait で確定)。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. draft を試して rollback / commit | high | low | low | adopt | player の試行錯誤を first-class に。 |
| B. drafting 中 live は不変 | high | low | low | adopt | 確定前は本番状態を汚さない。 |
| C. draft の inspect | high | low | low | adopt | 予定行動を確認できる。 |
| D. working-copy 方式 | high | low | low | adopt | live を触らず clone 上で draft。 |

## User goal

player turn 中に行動を draft (working copy に適用) し、内容を inspect し、気が変われば rollback、確定すれば commit で live に反映できる。commit 前は live scheduler が一切変わらない。

## Operation steps

1. `var tx := EQTransaction.new(manager.runtime().scheduler)`。
2. `tx.draft_push(...)` / `tx.draft_cancel(id)` で draft。
3. `tx.working()` / `tx.draft()` で inspect、`tx.is_live_unchanged()` で live 不変を確認。
4. `tx.rollback()` で破棄、または `tx.commit()` で live へ反映。

## 既存 UX との干渉

新規 L2 EQTransaction。EQScheduler.snapshot/restore (EQM-012) と EQSnapshot.equals (EQM-033) を利用。L0/L1 不変。API surface 変更 → golden 更新。
