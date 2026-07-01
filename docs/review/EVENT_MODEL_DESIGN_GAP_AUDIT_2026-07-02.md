# Event Model 設計・実装ギャップ監査 (2026-07-02)

目的: `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md` (Q01–Q26) の決定が設計文書・実装へ意図どおり流れたかの追跡監査と、v1.x 実装再開に必要な**設計自体の不足**の洗い出し。後者は同 registry の実装ラウンド (Q27–Q43, 2026-07-02 追補) として起票した。

対象: v1.0 RC (EQM-103, 2026-06-18) 時点の全設計文書・addon 実装・queue proof log。

## 1. 結論

1. **設計文書層は忠実**。SEM / CONCEPTS / COVERAGE は Q01–Q26 の決定を正確に反映しており、相互矛盾はない。
2. **ズレは実装層への受け渡しで発生**。SEM §16 が「Phase 4/5+ で実装」とした凍結契約群が queue の Phase 4–6 acceptance に写像されず、v1.0 RC 完了時点で「予約のみ」のまま。deferred の公式記録もない (SEM §16 自身の re-freeze ルール未履行)。
3. **契約を実装するには SEM の記述粒度では不足する設計詳細が 17 点残る** (§4)。特に「条件成立 → master timeline の ordering key 導出」と「解決 pipeline の callback 契約」は、確定しないまま実装を始めると決定性と三面モデル不変条件を壊すリスクがある。

## 2. 契約 vs 実装 drift (確定記録)

### 2.1 予約のみで未実装の凍結契約

| 契約 (Q) | 実装状況 (2026-07-02 検証) |
|---|---|
| event-line backend・発行・watched/sparse polling (Q16/Q17/Q26) | 不在。進行は各 policy が actor state 内数値を直接管理。event-line の API / identity / trace なし |
| `solve_conditions` (AND) / `invalidation_conditions` (OR) (Q18/Q05/Q06) | field 名も概念も不在。`eq_action_definition.gd` は単一 `duration` + `rumination` のみ |
| race pattern / race-group id / 3表示分離 (Q18) | 不在 |
| composite event + comparator hook (Q04/Q09/Q11/Q20) | 不在。COVERAGE のほぼ全行が写像先に引く hook が存在しない |
| window 機構 (open/close, deadline, meta-cost budget, nest) (Q01/Q02/Q03) | 不在。`eq_transaction.gd` は 1 段 draft/commit のみ |
| trace kinds `event_line_progressed` / `window_opened` / `window_closed` / `closed_by` | 製品コードは emit しない (EQM-013 の open schema が予約のみ) |

### 2.2 実装済みに見えて配線が切れているもの

- **save 境界 (Q22)**: `eq_effect_chunk.gd:30` の `is_save_allowed()` は孤立 helper。`eq_save_adapter.gd` は参照せず無条件 save。runtime 解決経路は chunk に record を積まない (chunk 利用は presentation テストのみ)。snapshot の event-line table (Q22 → EQM-012 影響) も未消化。
- **Q06 失効の event 化**: trigger duration expiry は `eq_trigger_engine.gd:101` で silent 削除 (status 変更のみ、trace なし、on-expiry effect なし)。Q06 決定と逆。
- **Q05 lazy invalidation の位置づけ**: 離脱 actor の event skip は `eq_runtime.gd:90` に実装されているが「anomaly (cause: contract_violation)」扱いで、dev mode では halt する。Q05 は死亡・離脱を通常経路とする意図だった。

### 2.3 acceptance 縮小の記録漏れ

- **EQM-053**: acceptance「reservation + event-line model で構成した config が dedicated policy の golden trace を再現」に対し、実体は `test_eq_reducibility.gd` 内の手書き per-tick simulation との order 配列比較。product model 経由でも golden trace 比較でもない。self-review は縮小を明示せず「met」と記録。
- **EQM-050/051**: acceptance に conditions が最初から含まれない — drift は queue 設計時点 (SEM §16 → acceptance の写像漏れ) で始まっている。
- **EQM-103**: declared follow-ups (icon / dock mounting / snapshot migrator) に event model 未実装群が入っていない。

### 2.4 軽微な整合問題

- `IMPLEMENTATION_QUEUE.md` の Current pointer が `EQM-081` のまま stale だった (proof log 末尾は queue complete)。本監査に伴い修正済み。
- OPEN_QUESTIONS の Q12 pointer「SEM §11」の指し先 (trace kinds) に感知分類の記述がない。実体は EQM-080/081 で実装済みのため実害小。次回 SEM 更新時に pointer を §11 + EQM-080 系へ補正する。
- COVERAGE row 6 (stack/LIFO) の宣言写像は「window nest + meta-cost」だが、出荷済み stack demo は「priority-as-depth LIFO」という別写像。window 実装後に demo か matrix のどちらかを揃える。

## 3. 工程上の原因と再発防止

原因: 凍結契約 (SEM §16) と queue task acceptance の間に対応検査がなく、「契約→どの task が実装を負うか→どの test が守るか」が機械検証されていない。EQM-023 (API surface gate) は「漏れ出し」は検出するが「未達」は検出しない。

再発防止 (v1.x queue に含める):

- **contract coverage matrix**: SEM §16 の凍結項目ごとに { owning task, 実装 file, test } を表にし、`tools/` の static check で「owning task = COMPLETE なのに実装 file / test が空」を FAIL にする。
- **re-freeze 記録**: 「v1.0 の実装 scope = L0/L1 + L2 骨格。event-line / conditions / window / composite は契約予約のみ」を SEM §16 に追記し、v1.x での実装順を宣言する (SEM §16 のルール履行)。

## 4. 設計自体の不足 → 実装ラウンド Q27–Q43

実装・利用の両視点で SEM を読み直した結果、以下が未確定。詳細と推奨は `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md` の「実装ラウンド擦り合わせ (Q27–Q43)」に起票した。

| 群 | Q | 不足 |
|---|---|---|
| 条件・解決 pipeline | Q27 | 条件成立 event の ordering key (due_tick/priority) 導出規則がない — 入力面→出力面の弁に key 割当が未定義 |
| | Q28 | solve と invalidation の同時成立時の優先規則 / race 勝者決定の明文化 |
| | Q29 | solve AND の評価様式 (同一評価点で全成立 = level か、成立記憶 = latched か) |
| | Q30 | predicate 条件の serialize 方法 (現 `custom_predicate` は transient で save/load 不能) |
| | Q31 | **[PIVOT]** 解決 pipeline の callback 契約 (resolve → effect 適用者 → chunk → sweep の呼出し順と consumer 実装面) |
| | Q32 | fired reaction の解決方式 — 現 `fire_cascade` の in-place 解決は「timeline 上でのみ解決」不変条件と不整合 |
| event-line backend | Q33 | update rule の表現 (data 限定か callable 許容か) |
| | Q34 | threshold 意味論 (crossing/level、repeating、1 poll 複数 crossing) |
| | Q35 | pattern (2) sweep rule の宣言・serialize 方法 |
| window | Q36 | window の object model (EQTransaction との関係、budget の所在、trace fields) |
| | Q37 | deadline 到達時の open draft の既定動作 |
| composite | Q38 | composite 形成規則と hook signature |
| drift 是正 | Q39 | actor 離脱の正規 invalidation 経路 (Q05 是正: `invalidate_actor` + `closed_by` trace) |
| | Q40 | duration expiry の event 化形 (Q06 是正) |
| 出荷・利用 | Q41 | snapshot schema v2 additive 計画 |
| | Q42 | L2 authoring surface — 行動解決ターン制の反撃準備が .tres 1 個で書けるか (受け入れ基準) |
| | Q43 | event-line polling の性能予算数値 (v1.x 目標規模) |

## 5. 提案 queue 骨子 (Q27–Q43 決定後に正式起票)

依存順の下書き。正式な acceptance は `IMPLEMENTATION_QUEUE_DESIGN_POLICY.md` に従い EQM-110 の planning で確定する。各 task の acceptance に**対応する凍結契約 ID を明記**する (§3 の再発防止)。

| id (案) | 内容 |
|---|---|
| EQM-110 | semantics round 2: Q27–Q43 決定の SEM v1.1 反映 + re-freeze 記録 + contract coverage matrix + Q12 pointer 補正 |
| EQM-111 | conditions 契約実装 (solve/invalidation schema + validation + named predicate registry) |
| EQM-112 | event-line backend (line table, rate, watched/sparse polling, `event_line_progressed` trace, EQM-102 予算拡張) |
| EQM-113 | 解決 pipeline 統合 (Q31/Q32; sweep 統合, `closed_by` trace, Q39 invalidate_actor, Q40 expiry event 化) |
| EQM-114 | window/deadline/budget (`window_opened/closed` trace, save 境界配線 = `is_save_allowed` を save 経路へ) |
| EQM-115 | comparator hook (+ composite は Q38 決定範囲で) |
| EQM-116 | race pattern + race-group id (debug 表示分離は最小限) |
| EQM-117 | snapshot v2 + save boundary enforcement + replay 証明拡張 |
| EQM-118 | EQM-053 再証明 (product event-line model 経由 + golden trace 比較) |
| EQM-119 | L2 authoring surface + 行動解決ターン制 dogfood 更新 + manual 更新 |

## 6. 進め方

1. ユーザーが Q27–Q43 の `user意見:` に注釈 (推奨採用なら一言で可)。
2. synthesis を `docs/review/` に記録し、SEM v1.1 へ確定記述 (EQM-110)。
3. EQM-111 以降を queue に起票し、`LINEAR_AUTOPILOT_QUEUE.md` に従い自律実行。

## 参照

- 契約: `docs/design/EVENT_MODEL_SEMANTICS.md` (§16 凍結一覧)
- registry: `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md` (Q27–Q43 追補)
- 先行 review: `docs/plan/2026-06-09_event_queue_manager/DESIGN_REVIEW_FEEDBACK.md` (task packet 工程 gap; 本監査とは対象が異なる)
