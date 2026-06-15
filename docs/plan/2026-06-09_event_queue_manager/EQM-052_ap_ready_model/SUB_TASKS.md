# EQM-052 SUB_TASKS

## Complexity

Class: C3
Reason:
- Action Resolution Turn-Based の **設計核**: AP 回復 (進行指標) + ready 予約 + wait による turn close。roadmap §1.1 の最重要 test case。
- L2 policy (AP/reservation を扱う深層パス)。orchestrator-direct (設計縮小回避)。

Required artifacts: Complexity header / Task Resolution / UX (最小) / POLICY (AP model + Invariant) / IMPLEMENTATION_PLAN。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQActionResolutionPolicy (L2) | AP 回復で ready turn を grant | adopt | EQPolicy 契約。AP は data[ap_key]、recovery per-actor。ready delay = ceil(spent_AP / recovery)。 |
| ready 予約 = AP 回復後の turn | "解決時間=N = AP が N 回復" | adopt | 次 ready は spent AP を回復しきった時点。 |
| turn closes through wait | wait が turn を閉じ次 ready を schedule | adopt | on_turn_finished が close (= wait)。cost が次 delay を決める。 |
| AP spend/recovery deterministic | 整数・再現可能 | adopt | ap_after = ap_max - cost、delay = ceil(deficit/recovery)。 |
| ready_reservation_for() で READY 予約を具体化 | "ready reservation" を EQM-050 READY kind で表現 | adopt | EQReservation(kind=READY, delay=AP回復delay) を返す helper。 |
| full event-line backend / solve condition | — | defer→EQM-053/060 | 本 task は AP delay 駆動。event-line への還元証明は EQM-053。 |

## Scheduled Task Audit

新規 scheduled task なし。EQM-052 完了で EQM-053 (reducibility proof) が解放。reaction/condition は EQM-060/061、rumination は EQM-062。
