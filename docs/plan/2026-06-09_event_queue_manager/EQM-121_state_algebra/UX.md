# EQM-121 UX — 状態代数 backend

user goal: EBS 系 consumer が (1) inv ペアと共存規則を data 宣言するだけで欠損⇄虚飾型の状態対を決定的に扱え、(2) 凍結・鈍化の重複が自動復帰し、(3) 寿命 3 種が既存条件語彙で宣言できることを golden trace で確認できる。

## Operation steps (L2/L3 利用者の導線)

1. `declare_inv_pair(a, b, rule)` を起動時に宣言 → 以後 `grant_state/clear_state` だけで共存規則が働く。
2. rate 一時変更は `add_rate_modifier` → 期限切れ/解除で自動的に元の実効 rate へ。
3. 寿命は EQConditionSpec (counter / duration) の既存宣言のみ — 新 API を覚えない。

## 採用/廃止 UX

- 採用: 共存規則は宣言時に 1 回選ぶ (付与のたびに指定しない)。
- 廃止 (hack): ゲーム側が復帰 rate を手計算して re_rate する運用 (決定性が消費者任せになる)。
- 干渉: なし (全て additive、L0/L1 不変)。
