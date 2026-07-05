# EQM-123 POLICY — pipeline 拡張

## 採用判断

- 段 = pop 直後・effect 前、順序 = 展開 → 変換 (EQM-120 確定)。
- 展開停止 = **メタレベル/コスト準拠** (§8 語彙内。visited-set 単独は不採用 — synthesis 逸脱 1)。
- 変換 = **多重適用許可**。適用構造は data で計画可能、意味 validation は EBS 側。EQM は決定的順序 + trace + 有界 round 安全弁のみ (synthesis 逸脱 2)。
- 変換はパラメータ別型 (target / 状態代数)。他パラメータ型は additive (synthesis 逸脱 3)。
- provenance は event 側のみ (三面分離)。

## 不採用判断

- 変換の 1 パス制限 / visited-set 停止 / event-line への provenance — EQM-120 不採用確定。

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| 展開予算尽き | 決定的打ち切り + trace (error ではない) | 停止規律そのもの | なし | test |
| 変換 runaway | 有界 round 超過 = dev fail-fast / shipped skip+log | RESILIENCE 二相 | なし | 両 mode test |
| 宣言なし | 2a/2b とも no-op (v1.1 挙動不変) | additive | なし | 既存 golden green |

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| 既存 golden | 宣言なしで trace 不変 | pipeline regression | 既存 golden green |
| 変換適用列 | メタ降順 → priority → sequence で決定的 | 順序不定 | permutation test |
| provenance | 発行 event にのみ付与・自動追記 | event-line 漏れ | test |

## 未確定だが task 内で決めてよい事項

- 展開宣言/変換宣言の dict field 名、hop cost の宣言 key 名 (§8 語彙内)。
