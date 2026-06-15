# EQM-041 SUB_TASKS

## Complexity

Class: C3
Reason:
- EQM-030 契約を再利用する policy + demo (learning path) + demo golden trace。
- 「instant resolve to next ready」「equal wait tie-break の明示説明」という TO/FFT 固有の意味論判断。

Required artifacts: Complexity header / Task Resolution / UX (最小) / POLICY / IMPLEMENTATION_PLAN。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQWaitTurnPolicy | wait 値で次 ready unit に即解決 | adopt | seed: due_tick=wait。pop が min wait を選ぶ → clock が jump (instant)。 |
| action cost → 次 wait | 重い行動ほど次が遅い | adopt | next_wait = cost。schedule(current_tick + next_wait)。 |
| equal wait tie-break | 同 wait は agility 高い順 → 登録順 | adopt | priority=agility (Q09: 速い unit 先)。同値は sequence。doc 明示。 |
| wait_turn demo + golden | demo の「動いた」を trace で証明 | adopt | demos/wait_turn_tactics + demo_wait_turn.trace.jsonl。 |
| wait を built-in field 化 | — | reject | data[wait_key] (acceptance 定義)。 |
| 専用 WT event-line backend | — | reject(MVP) | Phase4/5。delay 駆動 (= due_tick=wait)。 |

## Scheduled Task Audit

新規 scheduled task なし。EQM-041 完了で Phase 4 milestone。次フロンティアは Phase 5 (EQM-050 reservation schema)。wait-turn の reducibility は EQM-053。
