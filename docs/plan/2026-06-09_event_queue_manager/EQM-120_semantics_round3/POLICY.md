# EQM-120 POLICY — semantics round 3 (EBS 拡張ラウンド)

## 採用判断

- 相談ラウンド2・3 (2026-07-05, AskUserQuestion による対話) のユーザー決定を確定する。fork 16 点 (ラウンド2: 8 / ラウンド3: 8)。
- **メタレベル (Q51)**: スキル宣言の int (未宣言 0)、event/window が運ぶ、nest 深度と独立。単一 int 全順序、同値 = 介入成功。発行連鎖の各段が保持。
- **状態代数 (Q44/Q45/Q48-連鎖)**: inv ペア = ペア宣言 + 規則選択制。相殺は符号付き 1 本の counter line。suspension = modifier-stack (加算 + override のみ、乗算は需要待ち)。連鎖 = **デコレータ型** (状態が状態を包む新規の状態合成構造)。
- **pipeline (Q48/Q49/Q52)**: 展開・変換は pop 直後・effect 段の前 (展開 → 変換)。展開の再帰停止 = **メタレベル/コスト準拠** (§8 語彙; visited-set 単独案は不採用)。変換は**多重適用許可** — 適用構造は開発者が計画できる data とし、意味論的 validation は **EBS 側責務**、EQM は決定的順序 + trace + 有界 round の安全弁のみ。変換はパラメータ別の型 (対戦術 = target 変換 / 反転系 = 状態代数変換)。atomic bundle は前倒し。
- **関係グラフ (Q47)**: 評価タイミング = 関係型ごと宣言 sweep。結び直し語彙 = 直列縫合のみ (enum, additive 拡張余地)。actor 離脱は解消時規則を通して自動解消。
- **window (Q50/Q53)**: premature close = 解決済み維持・pending 打ち切り (`cause: intervention`)、deadline rollback とは別意味論。フェーズ巻き戻しは window draft に加えて**フェーズ内 sub-checkpoint** を持つ (1 window 内の多段フェーズを想定)。
- **発行連鎖 (Q52)**: event 側 provenance で確定 (依頼中の event-line 拡張示唆は三面分離 §2.1 を理由に不採用 — ユーザー承認済み)。

## 不採用判断

- メタレベルの部分順序 (カテゴリ比較) — 単一 int 全順序 (user 確定、roadmap Rejected へ記録済み)。
- window nest 深度からのメタレベル導出 — 深さと強さの混同 (user 確定)。
- premature close の draft rollback 型 — 介入の発動条件が「起きた効果」に依存するため矛盾 (user 確定)。
- rate modifier の乗算 — 現実需要になし。整数分数 + 丸め規則の定義が前提のため需要確定時に additive 追加 (user 確定)。
- 展開停止の visited-set 単独規律 — メタレベル/コスト準拠に置換 (user 修正)。
- 変換の 1 パス制限 — 多重適用許可に置換 (user 修正)。
- ループ解消の前進遷移方式 — 巻き戻し + 入力解除 (user 確定)。
- counter 2 本 + 差し引き (相殺記録形) — 符号付き 1 本 (user 確定)。

## 破壊的変更の理由

なし (docs + queue 追加のみ)。SEM v1.2 は additive。§7.1 の「composite atomic bundle は defer」staging は Q49 で解除されるが、supersede 記録として残す (削除しない)。snapshot は v3 を**予約** (additive tables + v2→v3 migrator; 実装は EQM-127)。

## Resource / API / UI の境界

- 本 task は契約文書と queue のみ。API 実体は EQM-121..128 が SEM v1.2 を典拠に実装する。
- 空間述語 (視界・範囲・座標) はゲーム側 NAMED_PREDICATE 供給 (Q12 の延長、依頼合意済み)。防御スタック実体・変換 validation・メタレベル値付けは EBS/ゲーム側責務。

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| §7.1 の bundle defer 記述 | supersede 記録に置換 (削除しない) | staging 履歴の保存 | なし (記録) | coverage row atomic-bundle |
| coverage の Deferred 節 bundle 項 | Q49 取り込みを追記 | 帳簿の一貫性 | なし | checker |
| registry の user意見 原文 | 原文保持 (対話回答は要約引用) | 注釈の一次記録性 | なし | — |
| EBS 引き渡し原本 | 相談ラウンド記録を同期 (EQM 側は受領コピー凍結) | 二重管理の drift 防止 (原本 = EBS 側) | なし | — |

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| SEM v1.2 | Q01–Q43 決定と矛盾しない (additive) | 旧決定の黙示上書き | synthesis 対照表 + self-review 差分列挙 |
| coverage matrix | 新規契約 row が {owning task, status=reserved} を持ち task が queue に実在 | 行漏れ / typo | checker (owning task 実在検査 + reserved 残留 FAIL) |
| queue Phase 12 | acceptance が契約 ID を引用、依存は線形鎖 | 写像漏れ | queue row 記載 |
| L0/L1 surface | 拡張の非漏出 (全て L2/L3 opt-in) | layer leak | EQM-023 API surface gate (実装 task 側) |

## 未確定だが task 内で決めてよい事項

- SEM の節番号割当 (§4.8 / §5.7 / §6.4–6.5 / §7.2 / §8.2–8.4 / §10.1 / §13.1 / §16.2) → 既存構造への additive 挿入で確定。
- 相殺の trace 表現 (signed line の progression + 派生状態変化の 2 記録) → §11 で確定記述。
- queue task の粒度 (8 実装 task の線形鎖) → SUB_TASKS の Scheduled Task Audit で確定。
