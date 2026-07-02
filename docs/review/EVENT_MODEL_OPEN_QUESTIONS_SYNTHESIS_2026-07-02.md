# Event Model Open Questions — Synthesis 2026-07-02 (実装ラウンド Q27–Q43)

入力: `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md` Q27–Q43 のユーザー注釈 (2026-07-02)、`docs/review/EVENT_MODEL_DESIGN_GAP_AUDIT_2026-07-02.md`。
出力: `docs/design/EVENT_MODEL_SEMANTICS.md` v1.1 (確定記述)、`docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md` (gate)、queue Phase 11 (EQM-110..119)。

結果: **17 項目すべて確定**。16 項目は推奨案の承認 (一部に運用上の補足)。Q31 のみ相談つき条件承認で、下記 §2 の reconciliation により解決した。

## 1. 決定対照表

| Q | 決定 (SEM v1.1 記録先) | 補足 (user 注釈の要点) |
|---|---|---|
| Q27 | 条件成立 event の key = (成立検出 sweep 点の global tick, 宣言 priority (default 0), 新規 sequence)。同 tick 内順序は comparator に委ねる → §5.4 | 層別規則は持たない |
| Q28 | invalidation-wins 一律。race 勝者 = hook → 発行順。`closed_by` で説明 → §5.4 | solve-wins optional は不採用 |
| Q29 | solve AND は level-triggered のみ。latched は counter line で表現 → §5.4 | 侵入/離脱系は予約追加/失効で表現可を user 確認済み |
| Q30 | named predicate registry (runtime instance 所在)。条件は name のみ serialize。未登録 name load = 安定 error。`custom_predicate` は transient 限定 → §5.5 | — |
| Q31 | 解決 pipeline 5-step 契約。effect callback は**宣言 linkage 方式**で任意項目 → §6 | 相談への回答は §2 |
| Q32 | fired reaction = schedule 方式 (due=current, 宣言 priority, 新 sequence)。cascade = bounded round、round 番号 trace。in-place 解決 (`fire_cascade`) は廃止予定 → §6.2 | reaction 専用順序規則は不要 |
| Q33 | event-line = data のみ `{id, value:int, rate:int/tick}`。前進 = rate polling + 明示 advance の 2 経路。rate 帯域なし → §4.6 | 「event-line 自体の data に吸収」 |
| Q34 | threshold = level 意味論。到達の瞬間性は解決 effect の reset/減算で作る。同時到達順序は Q27/Q38 → §4.6/§5.4 | — |
| Q35 | sweep rule = named rule registry + per-entity param (actor state)。実行順 = 登録順固定、走査 = actor_id 昇順 → §4.7 | **follow-up**: effect grouping (視認性) の設計余地を残す (§3) |
| Q36 | first-class `EQWindow`。EQTransaction は draft 実装として従属。L0 turn_ready→suspend = 暗黙 nest_level=0 window に統一 → §8.1 | base-operator level の柔軟さがゲームモード多層性に効く |
| Q37 | deadline 既定 = draft rollback + close + `window_closed(cause: deadline)`。commit は close 前 hook で明示 → §9 | 具体対応は acceptance 設計前提 |
| Q38 | 自動束ねなし。hook = `order_simultaneous(candidates) -> permutation`。既定 = 発行順。atomic bundle は明示 API として v1.x 後段 → §7.1 | — |
| Q39 | 正規 API `invalidate_actor(actor_id, cause)`。`closed_by: actor_removed`、mode 中立。離脱者を対象とする event は core 不関知 (acceptance 条件で表現) → §13 | 蘇生/召喚等の細部を core に埋め込みすぎない (需要時に検討) |
| Q40 | expiry event を arm 時に schedule (∞ は無し)。`closed_by: duration` / `reaction_count` / `already_closed` の語彙 → §6.3/§11 | — |
| Q41 | snapshot schema v2 additive (event_lines/windows/armed_triggers + 条件 inline)。v1→v2 migrator。`is_save_allowed` を save 経路へ配線、chunk 非空 save = 安定 error。draft save は Q01 既定 (rollback to boundary) → §10 | — |
| Q42 | `EQActionDefinition` additive 拡張 + `EQConditionSpec`。糖衣 (duration/rumination) 維持。受け入れ基準 = 反撃準備 .tres 1 個・GDScript 0 行・`closed_by` 可視 → §5.6 | 拡張は需要に応じ検討 |
| Q43 | 予算: actor ≤200 / watched line ≤300 / armed trigger ≤200 / advance() 追加コスト ≤0.5ms (headless debug) / 予測 depth N ≤20 → §12.1 | — |

## 2. Q31 reconciliation — effect callback の任意/必須

user 相談: 「effect callback がない場合、開発者が管理しにくくならないだろうか？そうでなければ任意項目で構わない。」

回答: 管理しやすさは「必須化」ではなく「**宣言したら必ず結線される**」ことで担保する — **宣言 linkage 方式**:

- `EQActionDefinition.effect_name: StringName` (optional)。設定された reservation の解決時、runtime の named effect registry (`register_effect(name, callable)`, Q30/Q35 と同一機構) の handler が呼ばれ、返り値 `EQEffectRecord[]` が effect 処理チャンクへ積まれる。
- `effect_name` 設定済み + handler 未登録 = **安定 error** (silent skip 禁止)。空 = 「明示的に effect なし」で合法 (WAIT/READY 等)。
- L0/L1 の `finish_action` 流儀は不変 (effect なし解決)。simple path に callback を強制しない。
- L2 の save 境界厳密性・effect-level trace・presentation record は named-effect path から自然に得られるため、docs/template/dogfood はこれを natural path として提示する。

管理不能になる経路 (「callback を書いたのに呼ばれない」「宣言したのに handler がない」) は error/validation で塞がれるため、任意項目でも管理性は落ちない。user 注釈の条件節「そうでなければ任意項目で構わない」を満たす — **任意項目で確定**。

## 3. Declared follow-ups (実装しないが記録する)

- **effect grouping (Q35 補足)**: ゲーム開発者の意図に応じた EffectRecord の grouping (視認性/デバッグ表示単位)。EQEffectRecord への group tag 追加は golden trace へ波及するため、需要確定時に additive 追加を検討する。EQM-119 (authoring/dogfood) の入力として記録。
- **composite atomic bundle (Q38)**: v1.x 前半は order hook のみ。bundle 化 API は後段。
- **蘇生/召喚が離脱済み actor を対象にする規則 (Q39)**: core は不関知を維持。需要を受けてから acceptance パターン集として検討。

## 4. 工程上の確定

- 再発防止 gate: `docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md` (契約→owning task→実装 file→test) + `tools/check_contract_coverage.py` を `./tools/test.sh` に配線。implemented 宣言 row の file/test 実在と、COMPLETE task の reserved 残留を FAIL にする。
- SEM §16 の旧「Phase 4/5+ deferred」散文は v1.1 の re-freeze 記録で supersede (削除せず履歴保存)。
- v1.x queue: EQM-110 (本 task) → 111 conditions → 112 event-line → 113 pipeline → 114 window → 115 hook → 116 race → 117 snapshot v2 → 118 reducibility 再証明 → 119 authoring/dogfood。線形鎖。
