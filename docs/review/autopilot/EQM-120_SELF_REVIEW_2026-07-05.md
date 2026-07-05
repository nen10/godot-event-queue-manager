# EQM-120 Self Review — semantics round 3 (EBS 拡張ラウンド Q44–Q54)

date: 2026-07-05
task: EQM-120 (queue Phase 12 先頭、docs-only)
pattern: P0 (orchestrator-direct)。相談ラウンド2・3 は同日の対話 (AskUserQuestion) でユーザー決定。

## Acceptance check

- [x] SEM v1.2: Q44–Q54 を *(v1.2)* 節として additive 記録 — §4.8 (modifier-stack) / §5.7 (状態代数: inv ペア・共存規則・wrapping・寿命合成) / §6.4–6.5 (展開・変換・provenance) / §7.2 (atomic bundle、§7.1 staging 解除を supersede 記録) / §8.2–8.4 (メタレベル・premature close・フェーズ再帰) / §10.1 (snapshot v3 予約) / §11 (trace kinds 追加) / §13.1 (関係グラフ) / §16.2 (v1.2 freeze 記録) / §17 (references)。
- [x] registry: 拡張ラウンド finalization (全 11 項目 DECIDED/SETTLED)、相談ラウンド2・3 の決定表 (fork 16 点)、Q→SEM→owner pointer 表、各 Q の user意見に対話決定を記録。
- [x] coverage: reserved 10 行 (owning EQM-121..128、同 commit で queue に実在)、Deferred 節更新 (bundle 解除 / v1.2 新規 defer 3 件)。
- [x] queue: Phase 12 (EQM-120 COMPLETE + EQM-121 READY + EQM-122..128 BACKLOG、線形鎖)、proof log、Current pointer = 実装 run 承認待ち CHECKPOINT。
- [x] EBS 引き渡し原本の同期 (相談ラウンド2・3 記録)。
- [x] `./tools/test.sh` PASS (docs/queue のみ; contract-coverage gate green)。

## 決定の忠実性 (推奨からの逸脱を正しく記録したか)

ユーザーが推奨案と**異なる**選択をした 5 点を、SEM 本文・registry user意見・synthesis の 3 箇所すべてで推奨案でなく決定側に揃えたことを確認:

1. 展開の再帰停止 = メタレベル/コスト準拠 (visited set 案は SEM §6.4 2a に「decided: not a bare visited-set rule」と明記)。
2. 変換の多重適用 = 許可 + 適用構造は開発者計画 + validation は EBS 側 (SEM §6.4 2b)。
3. 変換のパラメータ別型 (対戦術 = 対象先 / 反転系 = 状態代数) — ユーザー補足を契約構造として §6.4 に固定。
4. フェーズ内 sub-checkpoint (window draft では不足) — SEM §8.4。
5. ループ解消 = 巻き戻し方式 (相談ラウンド2; 前進遷移不採用)。

## 整合性チェック

- Q01–Q43 決定の不変性: 既存節の変更は (a) header status 行への v1.2 追記、(b) §7.1 staging bullet への解除 pointer 追記、(c) §11 への reserved kinds 追記、(d) §16.1 直後への §16.2 追加 — いずれも additive。旧決定の書き換えなし。
- 語彙の非重複: 展開停止・modifier 寿命・pending 打ち切り・関係維持失効はすべて既存語彙 (§8 meta-cost / §6.3 expiry / §5 invalidation) を参照し、新規予算体系・新規寿命 primitive を作っていない。
- 三面分離: provenance を event 側に置く決定で §2.1 不変。event-line 側拡張の不採用はユーザー承認を registry に記録。
- L0/L1 非漏出: v1.2 機構は全て宣言 opt-in。API surface は本 task で不変 (docs のみ)。実装 task で EQM-023 gate が守る。
- checker 整合: reserved 行の owning task (EQM-121..128) は同 commit の queue Phase 12 に実在 (typo guard green)。

## リスク / 実装 task への申し送り

- **§6.4 2a の hop cost 宣言形**が未確定 (§8 語彙内で EQM-123 が確定する)。§8 の budget と衝突しない設計にすること (synthesis「新予算体系を作らない」)。
- **wrapper 語彙の具体形** (透徹連鎖等の宣言 data) は EQM-121 が EBS スキルを instance に固定する。core が凍結したのは合成構造 + 順序 + trace のみ。
- **相殺 = 符号付き 1 本**は「pair = 1 軸」が成り立つ場合の記録形。EBS 側スキルで stack 上限や非対称な減衰が出た場合は EQM-121 で pair 宣言側の追加 field として吸収する (符号形は不変)。
- **snapshot v3** は予約のみ。EQM-121..126 は serialize 可能な data 形で実装し、table 化は EQM-127 に集約。
- EBS 側宿題 (メタレベル値付け / 変換 validation) は EQM の acceptance に含めない — EQM-128 の golden は EQM 側で値を仮置きして書く。

## 結論

Phase 12 の設計入力は完備。実装 run はユーザー承認待ち (queue CHECKPOINT)。
