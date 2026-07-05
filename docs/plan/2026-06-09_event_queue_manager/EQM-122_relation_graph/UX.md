# EQM-122 UX — 関係グラフ backend

user goal: 月/星 (召喚・身代・吸収・解析) の有向関係を data 宣言で持ち、視界条件は自前の NAMED_PREDICATE を渡すだけで、解消・結び直し・反転の全履歴が trace で説明できる。

## Operation steps

1. 起動時に関係型を宣言 (分類 / 構造制約 / 維持条件 / 解消時規則)。
2. `bind(type, from, to)` だけで関係が張れ、維持は宣言 sweep が自動評価。
3. 解体・死亡時の結び直しは宣言 (SERIAL_SUTURE) が自動適用 — ゲーム側 code 不要。

## 採用/廃止 UX

- 採用: 関係の全 lifecycle event が trace に出る (デバッグは trace を読むだけ)。
- 廃止 (hack): ゲーム側 Dictionary での関係管理 + 手動 cleanup。
- 干渉: なし (additive、L3 opt-in)。
