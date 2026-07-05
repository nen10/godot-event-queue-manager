# EQM-127 POLICY — snapshot v3
## 採用判断
- v2 と同じ互換 pattern (additive tables + migrator + 前方 = 安定 error)。
- phase_checkpoints table は EQM-126 の実装形に従属 — 126 完了後に本 task が確定して取り込む。
## Fallback / Mirror
| item | decision | why | removal condition | test |
|---|---|---|---|---|
| v1/v2 bundle | migrator 連鎖 (v1→v2→v3、欠落 = 空) | 既存互換 | なし | roundtrip test |
## State / Invariant
| state/source | invariant | risk | proof/test |
|---|---|---|---|
| v3 load | restore() 経路で trace 無発火 | load 時 trace 汚染 | replay 同一 trace 証明 |
## 未確定だが task 内で決めてよい事項
- state_algebra table の key 名。
