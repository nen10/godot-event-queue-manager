# EQM-040 POLICY

## 採用判断

- **EQEnergyPolicy** は EQM-030 契約を実装。energy が `threshold` に達した actor が行動し、`cost` を spend、remainder を carry-over する。
- **int 写像 + carry-over 追跡**: actor ごとに `energy_at_turn` (行動時点 energy) と carry (spend 後) を data に保持。
  - delay = `max(1, ceil((threshold - carry) / speed))` (整数)。
  - `energy_at_turn = carry + speed*delay` を次回 finish 用に保存。
  - on_turn_finished: `carry = energy_at_turn - cost`。cheap cost → carry 大 → 次 delay 短。
- **speed**: data[speed_key]。faster ほど充填速い (delay 計算に内包)。
- **cost**: result.cost>0 ? result.cost : base_cost。seed は energy=0 から。
- **独立実装**: event-line backend は使わず delay 駆動 (roadmap §1.1)。reducibility は EQM-053。

## 不採用判断

- float を delay/ordering に使う。
- tick-by-tick polling の本 task 実装 (Phase4/5 backend)。
- energy を built-in field 化 (data 経由)。

## Invariants

- delay は int >= 1。speed<=0 は 1 にクランプ。
- 同 speed・同 cost・同 carry なら delay は決定的。
- carry-over: cheap action 後の delay < 通常 (残量分短縮)。
- core ordering (int key) を変えない。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| delay(carry,speed) | int>=1、cost↑で次 delay↑、speed↑で delay↓ | 非単調 | heavy>normal>wait、faster<slower |
| carry-over | cheap action 後 delay 短縮 | carry 喪失 | wait 後 delay < normal、2 連 wait で更に |
| readiness | seed first turn = ceil(threshold/speed) | 閾値誤り | seed delay assert |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| cost<=0 | base_cost | normal の既定 | — | normal delay |
| speed<=0 | 1 にクランプ | div0/停滞回避 | — | (defensive) |
| 離脱 actor | 再投入しない | 幽霊 turn 防止 | — | (共通機構) |
