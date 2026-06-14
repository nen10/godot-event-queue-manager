# EQM-030 UX

利用者 = addon consumer (L1 policy 選択)。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. policy = Resource swap で順序規則を差し替え | high | low | low | adopt | roadmap §3.1 L1。core 不変。 |
| B. initiative は actor data から読む | high | low | low | adopt | per-entity 進行は acceptance 定義 (Q16)。 |
| C. removal は次 round で skip | high | low | low | adopt | 離脱 actor は再投入しない (registry 確認)。 |
| D. policy が runtime 内部を直接操作 | low | high | low | reject | runtime primitives (schedule) のみ使用。 |

## User goal

EQFixedRoundPolicy を選ぶと、actor が initiative 順に毎 round 1 回行動し、同 initiative は登録順で決まり、離脱 actor は以降の round で skip される。

## Operation steps

1. `var pol := EQFixedRoundPolicy.new()` (initiative_key 既定 &"initiative")。
2. actor を runtime に register、`state.data["initiative"]` を設定。
3. `pol.seed(runtime, actor_ids)` で round1 を投入。
4. loop: `var e := runtime.advance()` → 行動 → `pol.on_turn_finished(runtime, e.actor_id, result)` で次 round。
   (EQM-032 の EQManager が finish 時に自動委譲し、この loop を signal flow にする。)

## 既存 UX との干渉

EQPolicy base に契約メソッド追加。EQRuntime 不変 (policy は primitives を使うのみ)。API surface 変更 → EQM-023 golden 更新。
