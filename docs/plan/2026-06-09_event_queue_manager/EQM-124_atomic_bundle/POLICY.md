# EQM-124 POLICY — atomic bundle
## 採用判断
- SEM v1.2 §7.2 どおり。member 間 sweep なし・完了後に単一 sweep。which-bundle-is-next は §3 comparator 不変。
## 不採用判断
- 自動束ね (§7.1 既決)。member 間の部分 sweep。
## Fallback / Mirror
| item | decision | why | removal condition | test |
|---|---|---|---|---|
| bundle 未使用経路 | 従来 resolve_next 不変 | additive | なし | 既存 golden green |
## State / Invariant
| state/source | invariant | risk | proof/test |
|---|---|---|---|
| bundle 解決 | atomicity: member 間で trigger 発火しない | 順序依存混入 | trace test (bundle 中に reaction_fired が挟まらない) |
| save 境界 | bundle 完了までは chunk 非空 | 中間 save | is_save_allowed test |
## 未確定だが task 内で決めてよい事項
- bundle API の形 (resolve_bundle(event_ids) か submit 側宣言か — 実装時に最小の形を選ぶ)。
