# EQM-033 POLICY

## 採用判断

- **EQPrediction** (L0、static API)。`branch(runtime) -> EQRuntime` と `predict_turns(runtime, n, default_cost) -> Array`。
- **branch**: 新 EQRuntime に live scheduler の snapshot を restore し、active actor を data copy つきで再登録。policy/config/mode を引き継ぐ。**live は一切触らない**。discard (参照破棄) で消える。
- **predict_turns**: branch 上で n 回、`advance` → (policy あれば) `on_turn_finished(default action)` を 1 step ずつ回す。**precompute せず per-step 再評価** (event-line watched-set の N 非従属性, Q26 の構造を先取り)。
- **prediction purity** (principle 17): live scheduler の snapshot は predict 前後で一致。`EQSnapshot.equals` で検証。
- **prediction == actual**: 同じ default action で実際に live を進めた順序と predict 順序が一致。projection integrity (表示順=予測順=実順) の基盤。
- **act-now vs wait**: branch を 2 本作り異なる first action を当てて順序差を観測。live 不変。

## 不採用判断

- predict が live scheduler を pop する (純粋性違反)。
- N 件を precompute する設計 (watched-set 独立性を壊す)。
- full transaction/rollback (Phase7 EQM-070+)。

## Invariants

- predict 後、live scheduler の current_tick/counters/entries/generations が不変 (snapshot before==after)。
- predict_turns(n) の順序 == default action で live を n turn 進めた順序。
- branch の変更は live に伝播しない (scheduler copy + actor data copy)。
- predict は決定的 (同 live 状態で同結果)。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| live scheduler | predict で不変 | 純粋性違反 | snapshot before==after (EQSnapshot.equals) |
| predict 順序 | == 実 advance 順序 | 予測ずれ | predict 列 == actual 列 |
| branch actor data | live と独立 | 伝播汚染 | branch で data 変更しても live 不変 |
| per-step 評価 | N に非従属 | precompute leak | 1 step ずつ pop+reschedule (構造) |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| policy 無し predict | scheduler に既にある event を N 件 (reschedule なし) | policy 任意 | — | (default path) |
| 空 queue | 途中で打ち切り (返り < N) | 明示終端 | — | n > queue で短い列 |
