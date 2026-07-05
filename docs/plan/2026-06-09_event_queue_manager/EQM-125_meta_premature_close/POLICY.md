# EQM-125 POLICY — premature close
## 採用判断
- 同値 = 介入成功 (Q51)。解決済み維持・pending のみ打ち切り (Q50)。deadline rollback とは別 cause。
## 不採用判断
- draft rollback 型中終了 / nest 深度由来メタ / 部分順序 — EQM-120 不採用確定。
## Fallback / Mirror
| item | decision | why | removal condition | test |
|---|---|---|---|---|
| メタ不足の介入 | window 維持 + 介入効果は通常解決 + trace | 回避の説明可能性 | なし | test |
## State / Invariant
| state/source | invariant | risk | proof/test |
|---|---|---|---|
| premature close | 解決済み effect の巻き戻しゼロ | rollback 混入 | golden (2 step 維持) |
| close 記録 | 両メタ値 + intervener id が window_closed に載る | 説明不能 | trace test |
## 未確定だが task 内で決めてよい事項
- intervene_close の呼び出し規約 (介入 effect handler からの呼び出しを標準形とする)。
