# EQM-126 POLICY — phase recursion
## 採用判断
- 巻き戻し方式 (前進遷移不採用 — EQM-120 確定)。sub-checkpoint 必要 (相談3 #16)。
## Fallback / Mirror
| item | decision | why | removal condition | test |
|---|---|---|---|---|
| checkpoint 無しフェーズ | window open = 暗黙 checkpoint | 既存 §8.1 draft と整合 | なし | test |
## State / Invariant
| state/source | invariant | risk | proof/test |
|---|---|---|---|
| 巻き戻し | ループ開始点の状態と一致 (working-copy) | 部分復元 | roundtrip test |
| 検出 | 同一フェーズ再訪 = 決定的検出 | 偽陽性 | test |
## 未確定だが task 内で決めてよい事項
- 「鏡面入力」の表現 (checkpoint に紐づく宣言入力 slot として持つ)。
