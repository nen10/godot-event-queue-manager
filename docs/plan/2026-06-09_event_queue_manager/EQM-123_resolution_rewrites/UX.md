# EQM-123 UX — pipeline 拡張

user goal: 「星に損害 → 月にも」「弱化を発行者へ反射」を、効果 handler を書き換えずに宣言 (展開規則 / 変換宣言) だけで実現し、なぜその対象になったかを trace で追える。

## Operation steps

1. 展開規則 (関係型 ↔ 効果 tag) を宣言 → 対象拡大が自動。
2. 変換を named 宣言 → 対戦術/反射が pipeline に介入。多重適用の構造は EBS 側で設計・検証。
3. trace の targets_expanded / effect_transformed / provenance で全介入が説明可能。

## 採用/廃止 UX

- 採用: 介入は全部 pipeline の同一段 — ゲーム側 effect handler は展開・変換済み view を受けるだけ。
- 廃止 (hack): effect handler 内での手動対象拡大・手動反射。
- 干渉: なし (宣言なし = v1.1 挙動)。
