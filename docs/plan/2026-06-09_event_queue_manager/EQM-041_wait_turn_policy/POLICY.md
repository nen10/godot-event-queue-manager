# EQM-041 POLICY

## 採用判断

- **EQWaitTurnPolicy** は EQM-030 契約を実装。
  - seed: 各 unit を `due_tick = data[wait_key]`, `priority = data.get(agility_key, 0)`, `kind=&"turn"` で schedule。
  - **instant resolve**: scheduler が min due_tick を pop し current_tick がそこへ jump する (idle tick を踏まない) のが「次 ready unit に即解決」の写像。
  - on_turn_finished: `next_wait = result.cost>0 ? result.cost : base_cost`。`schedule(current_tick + next_wait, agility)`。**重い行動 → 大きい next wait → 後で行動**。
- **equal wait tie-break (明示)**: 同 wait = 同 due_tick。`priority = agility` の降順で先後 (速い unit 先, Q09「ベース WT 低い方先」を agility で表現)、agility 同値なら sequence (登録順) で確定。決定的全順序。
- **wait/agility は data 経由** (acceptance 定義, Q16)。
- **demo** demos/wait_turn_tactics (learning path) + golden trace。
- 独立実装 (delay/due_tick 駆動)、reducibility は EQM-053。

## 不採用判断

- wait/agility を built-in field 化。
- 専用 WT event-line backend の本 task 実装 (Phase4/5)。
- equal wait の非決定 tie (random)。

## Invariants

- pop は最小 wait (= 最小 due_tick) の unit を選ぶ。current_tick は単調非減少で jump。
- 同 wait は agility DESC → sequence ASC で決定的。
- next_wait >= 1 (停滞しない; cost<=0 は base_cost)。
- core ordering (int key) を変えない。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| due_tick=wait | min wait が先、clock jump | idle 踏む / 順序誤り | waits 3/5/8 → 順序 3,5,8、current_tick jump |
| next_wait=cost | heavy→後、wait→先 | cost 無視 | heavy next > wait next |
| equal wait | agility DESC→sequence | 非決定 tie | 同 wait 異 agility の順序、同 agility は登録順 |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| cost<=0 | base_cost | normal 既定 | — | normal next wait |
| equal wait | agility→sequence | 決定的 | — | tie test |
| 離脱 unit | 再投入しない | 幽霊 turn 防止 | — | (共通機構) |
| demo golden 不一致 | FAIL + 再 baseline | regression | — | exact 比較 |
