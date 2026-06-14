# EQM-031 SUB_TASKS

## Complexity

Class: C2
Reason:
- EQM-030 で確立した policy 契約 (seed/on_turn_finished) を再利用する 2 つ目の concrete policy。判断余地は CT→int delay の写像のみ。
- 新 class 1 つ → API surface 変更 (golden 更新)。

Required artifacts: Complexity header / Task Resolution / UX (最小) / POLICY / IMPLEMENTATION_PLAN。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQCTBPolicy | speed と action cost で次ターン時刻を決める | adopt | delay = ceil(cost*scale/speed) (全 int)。faster=短 delay=多ターン。 |
| int CT 写像 (ceil 除算) | float を ordering に入れない | adopt | `(cost*scale + speed-1)/speed`、min 1。semantics §12。 |
| haste/slow = actor data の speed 変更 | 次ターン挙動 | adopt | policy が reschedule 時に data[speed] を読む → speed↑で次 delay 短縮。 |
| priority = speed (同 due_tick の tie) | 同時 charge は faster 先 | adopt | tie は priority(speed) DESC → sequence。 |
| 専用 CT counter event-line を今 実装 | — | defer | semantics の event-line backend は Phase4/5。本 policy は delay 駆動の独立実装 (roadmap §1.1)。 |

## Scheduled Task Audit

新規 scheduled task なし。次の依存解放は EQM-032 (EQManager node, policy↔runtime 結線)。CTB の reducibility (reservation/event-line で再現) は EQM-053。
