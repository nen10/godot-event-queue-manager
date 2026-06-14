# EQM-031 POLICY

## 採用判断

- **EQCTBPolicy** は EQM-030 の契約 (seed/on_turn_finished) を実装。
- **int CT 写像**: `delay = max(1, (cost*scale + speed-1) / speed)` (整数 ceil 除算)。speed・cost・scale は int、float を ordering に入れない (semantics §12)。
  - faster (speed↑) → delay↓ → 単位時間あたり多ターン。
  - heavy action (cost↑) → delay↑。wait (cost↓) → delay↓。
- **cost source**: `on_turn_finished` は `result.cost` を使用。`cost<=0` は `base_cost` (normal) に写す。seed は `base_cost` で初期 charge。
- **haste/slow**: actor `data[speed_key]` の変更として表現。policy は reschedule のたびに現 speed を読むため次ターンに反映 (per-entity 状態は acceptance 定義、Q16)。
- **tie**: 同 due_tick は `priority = speed` DESC、次に sequence。faster が同時 charge 時に先。
- **独立実装**: 専用 event-line backend は使わず delay 駆動 (roadmap §1.1 で独立 policy は許容)。reducibility 証明は EQM-053。

## 不採用判断

- float を delay/ordering に使う (§12 違反)。
- 専用 CT counter event-line の本 task 実装 (Phase4/5)。
- speed を built-in field 化 (data 経由)。

## Invariants

- delay は常に int >= 1 (停止しない・逆行しない)。speed<=0 は 1 にクランプ (div0 回避)。
- speed が大きいほど同入力で delay が小さい (単調)。
- 同 speed・同 cost なら delay は決定的に同一。
- core ordering (int key) を変えない。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| delay_of(speed,cost) | int>=1、speed↑で単調減、cost↑で単調増 | 非単調 / float | heavy>normal>wait、hasted<normal<slowed |
| ターン頻度 | speed↑で多ターン | 頻度逆転 | 9 advance で fast>slow |
| haste/slow | data[speed] 変更が次 delay に反映 | 反映漏れ | speed 変更後の delay 変化 |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| cost<=0 | base_cost に写す | normal action の既定 | — | normal turn の delay |
| speed<=0 | 1 にクランプ | div0 / 無限停滞回避 | — | (defensive) |
| 離脱 actor | on_turn_finished で再投入しない | 幽霊 turn 防止 | — | (EQM-030 と共通機構) |
