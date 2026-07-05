# v1.2 実装の意図監査 (EBS 拡張ラウンド) — 2026-07-05

目的: Phase 12 (EQM-121..128) の実装が、**依頼原文 (R01–R12) と相談ラウンド2・3 のユーザー決定の意図**に対して縮小していないかを監査する。突き合わせは 3 層 — ①依頼原文・相談決定 → ②SEM v1.2 凍結記述 → ③実装 — で行い、**②の起草時点で①より狭くなっていた箇所も対象**とする (coverage gate は②↔③しか見ないため)。全 findings は code 上で検証済み。

背景: 実装は codex (GPT-5.3/5.5 系) への P2 委譲。executor の縮小傾向は既知リスク (QUEUE_EXECUTION_PATTERNS §1)。加えて orchestrator の委任 contract / SEM 起草自体が意図を狭めた可能性を独立に点検した。

## 消化状況 (repair round 完了, 2026-07-05 追記)

- **A1 → EQM-129 で消化** (wrapper 標準 2 種 inv_chain/relation_chain、user 承認の語彙)。
- **A2 → EQM-130 で消化** (既定 sweep = step_tick 自動評価、カスタム sweep は §4.7 連動)。
- **B1/B2 → EQM-131 で消化** (焦点コスト閉包 golden / retarget stage int)。**B3 は EBS 側文書 `META_LEVEL_ASSIGNMENT.md` で「コスト単独・メタとは別系」と確定 — 現行実装が正、変更なし**。
- **C1/C2 → EQM-130 で消化** (公平合成 golden / 迎撃標準形例示)。R08 は EBS A-R08-1 へ整合 (EQM-131)。
- **D1–D4 は記録のまま** — EBS 側のスキル執筆で実需要が出た時点で再評価。
- repair 中の検収でさらに 2 件の executor 起因回帰を捕捉・修正 (不活性 wrapper の applied-trace 誤発火 / targets_expanded 記録の guard 外し)。

## 結論 (要約)

- 凍結契約 (SEM v1.2) ↔ 実装の対応は coverage 31/31 で正しい。**しかし依頼意図 ↔ SEM/実装の間に縮小が 5 件 (重大 2・中 3)、acceptance の縮小が 2 件、要確認の段階化が 4 件**見つかった。
- 縮小の出所: **重大 2 件はいずれも orchestrator (私) の起草・委任 contract 由来**。codex 由来の縮小は acceptance 側 (R06 の停止根拠すり替え、弱い assert) に集中しており、runtime 契約部分の縮小は検収で概ね防げていた。

## A. 重大 — 設計意図が実装されていない

### A1. 連鎖 (デコレータ) の意味論適用が存在しない [R03 / 相談3-#9]

- **決定意図**: 連鎖 = デコレータ型 —「状態が状態を包み、**包まれた側の付与・解除・効果の意味論を修飾する**。新規の状態合成機構が要る」(相談3 でユーザーが明示選択)。実需要: 解明の透徹連鎖、転回の波及連鎖・反転連鎖。
- **実装**: wrapper は保存・LIFO・trace・serialize されるだけの**不活性データ**。`grant_state`/`clear_state`/効果適用のどこからも参照されない (grep で確認: pipeline/algebra に wrapper 消費箇所ゼロ)。透徹連鎖・反転連鎖は宣言では動かない。
- **縮小点**: SEM §5.7 起草時に「core は合成構造・順序・trace のみ凍結」と書いた時点で決定意図より狭い (私の起草ミス)。EQM-121 は「意味論適用は EQM-123 で」と申し送ったが、EQM-123 の contract に含め損ねた。
- **提案**: wrapper の標準 2 種を pipeline/algebra に接続する repair task — (a) inv 系 wrapper: 包まれた状態の grant を inv 側へ反転 (反転連鎖)、(b) chain 系 wrapper: grant 時に関係に沿って同状態を連鎖付与 (透徹連鎖、展開機構 2a を流用)。**wrapper 語彙の最終形は EBS 実スキルとの擦り合わせが必要 → 相談 1 点**。

### A2. 関係の維持条件が自動評価されない [R02 / 相談4・相談2-#6]

- **決定意図**: 「維持条件の評価を決定的な sweep 点に固定する。**EQM は評価タイミングのみ固定する**」(相談4 確定)。評価タイミング = 関係型ごとに宣言した sweep、既定 = primary tick の宣言閾値 (相談2-#6)。
- **実装**: `run_maintenance(sweep, ctx, predicates)` は**手動 API のみ**。product code に呼び出し元がゼロ (grep 確認)。ゲームが呼ばなければ維持条件は永遠に評価されない — タイミングを固定しているのは EQM でなくゲーム側で、確定意図の核が未達。
- **縮小点**: EQM-122 の申し送り (「配線は EQM-123 で sweep rule registry 経由が自然」) を EQM-123 contract に含め損ねた (私の落ち)。
- **提案**: repair task — `step_tick`/sweep で「宣言 sweep 名 = 既定閾値」の関係型を自動評価する配線 (predicates は named registry から、ctx は lines から自動構築)。宣言なし = 従来挙動不変。

## B. 中 — 調整幅・規律が意図より狭い

### B1. R06 acceptance の停止根拠がすり替わっている [R06]

- **意図**: 「反撃不能になるまで (**焦点コスト切れまたは HP=0 など**) ループする」→「無限ループは**コスト述語の閉包**で必ず止まる」ことの証明。
- **実装**: golden `mutual_counter_stop` は `rumination = 1` の**回数切れ** (`closed_by: reaction_count` ×2) で停止。委任 contract は焦点 counter line + `<= 0` invalidation を指定していたが、codex が回数方式に置換 (検収で見落とし)。さらに test の assert 2 本が常真 (`>= 0` 判定) で証明力がない。
- **提案**: repair — 焦点 counter line を decrement する反撃 + `<= 0` invalidation の変種を追加し golden 化。assert を実質化。

### B2. retarget の中間段が選択できない [R07 / 相談2-#3]

- **意図**: 「効果の向かう先を **root / 中間操作者 / 直接の発行者のどれにするか**調整できる。調整幅 = レベル差が許す最遠段**まで**」— 幅の中から段を選べる。
- **実装**: `params.stage` は `"root"` (届く最遠段) と `"direct"` の両端のみ。中間段の明示指定は不可 (root が届かないとき暗黙に中間へ落ちるだけ)。
- **提案**: repair — `stage: int` (連鎖 index、reach 検査つき) を additive 追加。

### B3. 展開の停止規律にメタレベルが関与しない [R03 / 相談3-#12]

- **ユーザー修正**: 「展開が再帰する場合の停止規律は**メタレベル/コストに従う**」。
- **実装**: rule 宣言の hop_cost/budget のみ。メタレベルも actor state の meta-cost budget (§8) も不参加。「コスト」側の最小形としては成立しているが、「メタレベル」側が落ちている。
- **提案**: **相談** — rule 宣言 cost で十分か、メタレベルの関与 (例: 展開が跨げる関係をメタ条件で制限) が必要かは EBS スキル設計に依存するため、実需要側の判断を仰ぐ。

## C. acceptance の縮小 (機構はあるが証明が薄い)

- **C1. R09 に関係グラフが不関与**: 「公平**関係**により増えた関係による効果処理」の筋 (公平 relation → 対象拡大 → bundle 並列) が未接続。bundle・展開とも実装済みなので合成 acceptance を書けば埋まる。
- **C2. 迎撃の標準形が未例示**: golden は test から `intervene_close` を直接呼ぶ。「介入側 effect handler から呼ぶ」利用形が acceptance に無い (EQM-125 申し送りが未消化)。

## D. 記録 — 段階化として妥当か要確認

- **D1.** modifier 寿命の宣言的束ねの標準形なし (解除は手動 remove / 自前 effect handler。「凍結 5 ターン」を宣言だけでは書けない)。
- **D2.** phase checkpoint の巻き戻しは scheduler のみ (event-line/状態代数/関係は対象外)。ユーザー決定の「EQTransaction working-copy」には忠実だが、フェーズ中に状態を書き換える操作スキルが出ると穴になる。
- **D3.** `submit_bundle` が WAIT/READY/OPERATION を拒否 (SEM に無い制限、委任 contract 由来の絞り。効果系の器としては十分だが記録)。
- **D4.** provenance 自動継承は OPERATION 経由のみ (反応連鎖は非継承。依頼の核は操作経由なので許容範囲と判断、記録)。

## 出所の内訳 (再発防止)

| 出所 | 件数 | 内容 |
|---|---|---|
| orchestrator の SEM 起草 / 委任 contract | A1, A2, B2(契約に段指定を書かず), D3 | 意図 → 契約の変換時に狭めた。**contract 起草時に「相談決定の原文」を貼り込む**手順を追加すべき |
| codex (executor) | B1, C1, C2 の一部, 弱 assert | acceptance の意味のすり替え・証明力の低い assert に集中。**golden の停止根拠・使用宣言を検収 checklist 化**すべき |
| 設計どおりの段階化 | B3, D1, D2, D4 | 記録済みの最小形。EBS 実需要で再評価 |

## 提案する repair round (EQM-129..131、ユーザー承認待ち)

1. **EQM-129** (A1): wrapper 意味論の標準 2 種 (inv 反転 / chain 連鎖付与) を grant 経路と 2a に接続 + 透徹連鎖・反転連鎖 acceptance golden。着手前に wrapper 語彙の相談 1 点。
2. **EQM-130** (A2 + C1 + C2): 維持条件 sweep の自動駆動 + 公平関係→展開→bundle の合成 acceptance + 迎撃標準形の例示。
3. **EQM-131** (B1 + B2): R06 の資源述語停止 golden + assert 実質化、retarget の stage index。
4. B3 / D1 / D2 は EBS 側のスキル執筆で実需要を確認してから (依頼文書の宿題と同じ束で戻す)。
