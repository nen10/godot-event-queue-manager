# EQM-128 POLICY — acceptance 束
## 採用判断
- 確認系は「既存機能で書ける」ことの証明が成果 — 新 primitive を追加しない (追加が要る発見は queue 候補化して停止判断)。
- EBS 側宿題 (メタレベル値付け / 変換 validation) は acceptance に含めない — 値は仮置きで golden 化。
## State / Invariant
| state/source | invariant | risk | proof/test |
|---|---|---|---|
| 相互反撃 | 資源述語の閉包で必ず停止 | 無限 cascade | golden + bounded rounds |
| 寸断 | トリガ抑制が invalidation で書ける | 新 primitive 誘惑 | test のみで証明 |
## 未確定だが task 内で決めてよい事項
- manual 章立て。
