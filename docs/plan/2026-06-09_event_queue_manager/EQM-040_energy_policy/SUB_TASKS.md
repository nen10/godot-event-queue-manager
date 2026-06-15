# EQM-040 SUB_TASKS

## Complexity

Class: C2
Reason:
- EQM-030 契約 (seed/on_turn_finished) を再利用する 3 つ目の policy。判断余地は energy carry-over の int 写像のみ。
- 新 class 1 → API surface 変更 (golden 更新)。

Required artifacts: Complexity header / Task Resolution / UX (最小) / POLICY / IMPLEMENTATION_PLAN。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQEnergyPolicy | threshold readiness + action cost + carry-over | adopt | energy が threshold に達したら行動、cost を spend、remainder を carry。 |
| int 写像 (energy_at_turn 追跡) | float を ordering に入れない | adopt | delay=ceil((threshold-carry)/speed)、energy_at_turn を data に保持。 |
| carry-over = cheap action で次が早い | roguelike の核 | adopt | carry = energy_at_turn - cost。残量が次 delay を短縮。 |
| speed 差で行動頻度 | faster がより速く充填 | adopt | per-tick speed 加算 (delay 計算に内包)。 |
| tick-by-tick polling 実装 | — | reject(MVP) | pattern2 sweep は Phase4/5 event-line backend。本 policy は delay 駆動。 |
| energy を built-in field 化 | — | reject | data[energy_key] (acceptance 定義, Q16)。 |

## Scheduled Task Audit

新規 scheduled task なし。次の依存解放は EQM-041 (wait-turn)。energy の reducibility (event-line) は EQM-053。
