# Event Model Open Questions

目的: event model スケールの設計未決点を一覧化し、EQM-014 (EVENT_MODEL_SEMANTICS.md) の入力にする。各項目は semantics 確定時に adopted/rejected を記録し、本 file の項目は決定への pointer に置き換える。

status:

- `SETTLED` — ユーザー合意済み。EQM-014 で確定記述する。
- `DECIDED(user)` — ユーザー決定済み。検証条件つきで確定する。
- `PIVOT` — core data model を動かす論点。他項目を従える。
- `CLUSTERED` — PIVOT(進行モデル)に従属。単独では確定しない。
- `RECOMMENDED` / `OPEN` — agent 推奨あり / ユーザー判断待ち。
- `META` — 原則確認。

## Finalization (EQM-014.03, 2026-06-15)

semantics は確定し `docs/design/EVENT_MODEL_SEMANTICS.md` (契約) と `docs/design/ORDERING_MODEL_COVERAGE.md` (≥8 system 写像) に記述された。この 2 文書が **v1 authoritative** であり、本 registry の各項目はそこへの **pointer**(本 file 冒頭の目的どおり「決定への pointer に置き換える」)。下表は adopted/rejected の記録先。索引 status 表 (下記) が status-of-record で、全 Q は settled。Phase 2 API freeze は本 task 完了で gate 解除 (EQM-020 依存充足)。

> 追補 (2026-07-02): v1.0 RC 後の契約監査 (`docs/review/EVENT_MODEL_DESIGN_GAP_AUDIT_2026-07-02.md`) を受け、**実装ラウンド Q27–Q43** を本 file 末尾に追加した。Q01–Q26 の settled 状態は不変。

| Q | 決定の記録先 (SEM = EVENT_MODEL_SEMANTICS.md, COV = ORDERING_MODEL_COVERAGE.md) |
|---|---|
| Q01 save 境界 | SEM §10 |
| Q02 window nesting | SEM §8 |
| Q03 window deadline | SEM §9 (frozen = deadline ∞) |
| Q04 同時性/batch | SEM §7 (composite) |
| Q05 無効化 timing | SEM §5 / §5.3 (lazy/eager) |
| Q06 duration expiry | SEM §5 (invalidation, reaction-count) |
| Q07 遡及時間変更 | SEM §3 (reschedule-only) / §4 (event-line) |
| Q08 priority 不変 | SEM §3 |
| Q09 effect 順序/trigger 収集 | SEM §6 (sweep) / §7 (composite) |
| Q10 actor lifecycle | SEM §13 |
| Q11 数値域 | SEM §12 |
| Q12 感知分類 | SEM §11 (classification は simulation 側 data と明記, v1.1 追記) — 実装は EQM-080/081 (`EQEffectRecord.classification`) |
| Q13 timeline 単一性 | SEM §15 + COV row 5 (4X) |
| Q14 反芻経済 | SEM §16 (reservation field reserved; impl EQM-050/062) |
| Q15 replay 製品化 | deferred (registry; post-v1) |
| Q16 event-line 導入 | SEM §4 |
| Q17 前進方式/決定性 | SEM §4.4 — per-tick polling 既定。**予測深さ N は v1 defer (EQM-033 prediction / EQM-102 perf 予算の入力)** |
| Q18 多条件 solve/invalidation | SEM §5 (solve AND / invalidation OR / race pattern) |
| Q19 eager 責務分割 | SEM §5.3 / §6 |
| Q20 同時解決/上位順序 | SEM §7 (comparator hook, fallback=発行順) |
| Q21 reentrancy 統一 | SEM §8 |
| Q22 event-line×snapshot/save | SEM §10 |
| Q23 過剰一般化ガードレール | SEM §15 |
| Q24 grouped/micro-event-line | COV deferred (RTS 補助線、v1 実装外) |
| Q25 sync barrier | SEM §10 / §15 (core named concept にしない、acceptance 支援は継続課題) |
| Q26 identity/granularity/lifecycle/scaling | SEM §4.2 (2 表現) / §4.5 (identity・lifecycle・stacking) |

## Synthesis 2026-06-13: 進行モデル (progression model) が crux

ユーザー注釈を総合すると、推奨案とのズレの大半は個別 Q ではなく単一の core 判断に収束する。原因は「行動解決ターン制が要求する進行(progression)の多様性」が初期 roadmap で single global tick に圧縮されていたこと。

> global tick は唯一の進行軸ではない。TO の WT・FFT の CT(entity 固有の蓄積/消費)、効果回数カウンタ、numerical な eager 条件は、いずれも「acceptance が更新量・更新条件を定義する incremental 指標」= **event-line** の閾値到達として統一表現できる。global tick はその default event-line にすぎず、event は任意 event-line を発行・参照できる。

この一般化 (Q16) が Q04 / Q05 / Q06 / Q07 / Q09 / Q11 / Q13 / Q14 を束ねる。製品の核(決定的全順序)を壊さない reconciliation invariant:

- **event-line = 進行入力 (state)** と **master timeline = 解決順 (output)** を厳密に分離する。
- master timeline は従来どおり単一 comparator の全順序。event-line は deterministic な sweep 点で master timeline の event に変換されるのみ。
- これにより ordering key 不変・reschedule のみ (Q07/Q08) を壊さずに WT/CT・効果回数・eager を表現する。

未確定は「event-line を core data model として導入する範囲と決定性規律」へ移った。新規 Q16–Q23 がそれを擦り合わせる。over-generalization 懸念 (UX_PATH_REDUCTION との整合) は Q23 で明示処理する。

| id | status | 領域 |
|---|---|---|
| Q01 | DECIDED(user) | save 境界 |
| Q02 | DECIDED(user) | window nesting 制約 |
| Q03 | SETTLED | window deadline (ATB) — user: 良い |
| Q04 | CLUSTERED | 同時性 / batch → Q20 |
| Q05 | CLUSTERED | 予約の無効化 / eager → Q18 / Q19 |
| Q06 | CLUSTERED | 失効の event 化 → Q18 |
| Q07 | PIVOT | 進行軸 → Q16 / Q17 (event-line) |
| Q08 | SETTLED | priority 不変 — user: 正しい |
| Q09 | CLUSTERED | effect/上位順序/trigger nest → Q20 / Q21 |
| Q10 | SETTLED | actor lifecycle — user: 問題なし (cleanup → Q22) |
| Q11 | CLUSTERED | 数値域 / 上限 / effect 内順序 → Q20 |
| Q12 | SETTLED | 感知分類 simulation 側 — user: 正しい |
| Q13 | CLUSTERED | timeline 単一性 → Q16 (event-line ≠ timeline) |
| Q14 | SETTLED | 反芻経済 再徴収なし — user: 正しい |
| Q15 | SETTLED | replay defer — user: 正しい |
| Q16 | DECIDED(user) | event-line 導入 (A1) |
| Q17 | DECIDED(user) | 前進方式 = tick polling 既定 / 予測深さは要 example 擦り合わせ |
| Q18 | DECIDED(user) | solve=AND / invalidation=OR (race pattern) |
| Q19 | DECIDED(user) | eager = invalidation の trigger 型条件 / sweep = 解決後 collection window |
| Q20 | DECIDED(user) | composite comparator hook (B1) / fallback=発行順 |
| Q21 | DECIDED(user) | window+trigger nest 共通 reentrancy / 交差ケース想定 |
| Q22 | DECIDED(user) | event-line snapshot / save 境界 = effect 処理チャンク空 |
| Q23 | DECIDED(user) | 過剰一般化ガードレール 合意 |
| Q24 | DEFERRED | grouped / micro-event-line (RTS 補助線) |
| Q25 | OPEN(support) | sync barrier — core 命名はしないが acceptance 支援は課題 |
| Q26 | DECIDED(user) | event-line identity / granularity / lifecycle / 再帰召喚 scaling |

---

## Decisions 2026-06-14 (Cowork synthesis 反映)

決定の根拠記録は `docs/review/EVENT_MODEL_OPEN_QUESTIONS_SYNTHESIS_2026-06-14.md`。本 registry はその確定結果を保持する。

1. **進行モデル = event-line を v1 core に導入 (Cluster A = A1)**。global tick = primary event-line。event 側からの event-line 発行を許す。**per-entity event-line は acceptance 定義であり built-in 必須 field にしない** (意味論を 1 つの組込み挙動へ固定しないため)。契約・schema・trace record kind は Phase1/2 で予約し、backend 実装は Phase4/5 でも後方互換破壊しない。
2. **solve / invalidation の分離 (Q18 訂正)**。解決条件 `solve_conditions` 既定 = **AND**、失効条件 `invalidation_conditions` 既定 = **OR**。AND 失効は decremental counter event-line へ回収。OR 解決は race pattern (同一 effect を異なる solve_conditions で持つ **event-line を条件にした複数 racing event** を発行し、勝者以外を OR invalidation) で表現する。発行されるのは event であって event-line そのものではない (概念整理 `docs/design/EVENT_MODEL_CONCEPTS.md` §3)。race group は EQM debug / game-dev debug / presentation の 3 表示を分離する概念契約を持つ。
3. **composite comparator hook (Cluster B = B1)**。composite の「どれが次か」は core が int (tick/priority/sequence) で決める。composite **内部**順序と上限超過動作は acceptance 提供の deterministic comparator (serializable state 由来、float 可、live object 禁止、golden 必須) に委譲。最終 fallback = default event-line 上の **event 発行順**。同順 (並列) 発行は禁止。
4. **sweep 点 = 各 event 解決後の collection window** (Q19 / Q09 first)。eager は invalidation の trigger 型条件として既存 trigger 機構に乗る。
5. **reentrancy 統一 (Q21)**。window nest (meta-cost budget, Q02) と trigger nest (bounded round + cycle guard, EQM-062) は 1 つの reentrancy spec に統合記述。交差ケース (trigger が window を開く / window 内 trigger) は v1 想定、評価は暫定設計でよいが cost 設計の柔軟性を残す。
6. **save 境界 = effect 処理チャンクが空であること (Q22)**。effect 処理チャンクへの追加は event-line **解決時** (発行時ではない)。window open は open 時点で effect 解消済みとみなし直後のチャンクは空。よって sync barrier は EQM が許容する save 境界に一致する。過渡的 rate 変化中の save は許容するが acceptance 向け十分な管理は提供しない (auto save 程度)。
7. **trace record kind 命名 = `event_line_progressed`** (`event_line_advanced` 不採用)。`window_opened` / `window_closed` と同じ過去分詞形。
8. **sync barrier を core named concept にはしない (Q25)**。event-line 同時性は sync barrier の一例だが全てではない。acceptance 側 game 開発は sync barrier 設計を要し、EQM がそれを支援することは継続課題として残す。
9. **grouped / micro-event-line は deferred (Q24)**。RTS 規模の edge case 包摂性を確認する補助線。v1 実装対象外。

残る要 example 擦り合わせ: **予測深さ N の定義** (Q17)。core 決定ではなく性能予算 (EQM-102) と prediction (EQM-033) の入力。

---

## Q01 — save 境界 [DECIDED(user)]

決定: save 可能な nest level の上限 = base-operator window の nest level。base-operator level は acceptance 側 game model が管理する。

検証条件 (`docs/review/ROADMAP_GAP_EVALUATION_2026-06-13.md` §1): snapshot-for-save と snapshot-for-rollback の区別 / open draft の save 意味論 (推奨: rollback して boundary 保存) / open window stack の明示 serialize / `is_save_allowed()` + 安定 error。

影響: EQM-012, EQM-014, EQM-070/071。

## Q02 — window nesting 制約 [DECIDED(user)]

決定: nesting の cycle guard は持たず、操作行動の可否を operator の "meta level/cost" parameter で制約する。required cost は nest level の単調増加関数 (acceptance 側定義) を基準とし、実 game では抵抗値等の未確定変数を含む判定に拡張してよい。

検証条件 (同 §1): 狭義単調 (int 域なら depth <= budget が成立) / chain 中の budget 非回復 invariant / 未確定変数判定は deterministic RNG + trace 記録 / engineering backstop (絶対 max depth) / EQM-062 の同一 tick trigger 連鎖 guard は別層として存置。

影響: EQM-014, EQM-050/051, EQM-061/062。

## Q03 — window deadline (ATB active 風) [RECOMMENDED]

問い: window open 中は global tick 凍結が default だが、deadline 付き window (制限時間内に行動しないと window が閉じ、時間が流れ続ける ATB active mode) を model に含めるか。

推奨: optional な window property として含める。凍結 window は deadline = ∞ の特例になり、ATB / real-time hybrid が coverage matrix で写像可能になる。

影響: EQM-014, ORDERING_MODEL_COVERAGE, EQM-070。

user意見: 良い。

## Q04 — 同時性 / batch 解決 [RECOMMENDED]

問い: 厳密全順序のみか、「同時」に解決すべき event 群 (WeGo 同時手番、相打ち、同時 KO) を表す primitive を持つか。

推奨: core は全順序を維持し、同時性は composite event (複数 effect を単一解決として束ねる) で表現する。全順序を崩す並行解決は導入しない。

影響: EQM-014, EQM-050, EQM-080。

user意見: 賛成の上で疑問点 - composite event としての解決に関する実際の game 上の挙動は event 分類ごとに acceptance 側定義に寄せるとして理解することになるか？

→ 回答 / reconciliation: その理解で正しい。core が保証するのは composite event の atomicity・全順序・serializability・trace 被覆。member 解決順と effect 意味論は event 分類ごとに acceptance 側定義へ寄せる。ただし「acceptance が自由記述」ではなく、serializable state から導出される deterministic ordering-key 拡張点を 1 つ介して定義する(Q20)。これで自由度と決定性を両立する。

## Q05 — 予約の無効化 [RECOMMENDED]

問い: owner 死亡 / target 消滅 / 前提崩れの判定タイミング — lazy (解決時に validity predicate 評価) か eager (状態変化時に cascade cancel) か。連鎖 cancel と trace への現れ方。

推奨: lazy 判定 + `invalid_event_skipped` の trace record を標準とする。eager な無効化が必要な game 規則は trigger (反応) として表現する。

影響: EQM-011, EQM-051, EQM-061。

user意見: 主眼としては正しいが、eagarの責務については検討したい。

→ reconciliation: eager を二分する(Q19)。event-line 閾値で表せる numerical eager は deterministic sweep 点で評価し(「eager に見えるが定義点で評価」)、表せないものだけ trigger engine が bounded round で扱う。連鎖 cancel は多条件失効(Q18)へ統合する。

## Q06 — 持続時間切れの event 化 [RECOMMENDED]

問い: 反応準備等の duration expiry は event として timeline に乗るか、参照時に lazy 判定か。

推奨: event 化する。trace に可視になり、on-expiry trigger が定義可能で、決定性検証が単純になる。

影響: EQM-061。

user意見: 正しい。ただし、反応準備は反応回数によっても event の close を行う余地があり、その場合 deadline = ∞ を許容する。

→ reconciliation: 反応回数 close と deadline=∞ は「多条件失効」(Q18)の一例。解決条件・失効条件をそれぞれ集合(event-line 閾値 / reaction-count / predicate)とし、on-expiry effect を optional に持たせて Q05/Q06/Q14 を統一吸収する。

## Q07 — 遡及的時間変更 [RECOMMENDED]

問い: haste / slow / time-stop が既存予約の due_tick を直接書き換えることを許すか (TO の wait 再計算問題)。

推奨: 直接書き換え禁止。変更は reschedule (cancel + push, generation bump) のみとし、再計算規則は policy が所有する。queue backend の不変条件が単純に保たれる。

影響: EQM-011, EQM-041。

user意見: 
  first-discussion: event の管理に関して global tick は全てではなく、TO(tactics ogre) のWTシステム、FFT(FFタクティクス)のCTシステムでは entity 固有の paramater 消費/蓄積で行動ターン event が来る。
  second-discussion: 毎 tick 進行自体に、WT/CT条件で行動ターン予約効果をもつ event を追加すれば、再計算なしに少ない誤差で entity 別で進みの異なる WT/CT 進行を再現可能。ただし、Q06との関連にも注意すると、global な timeline 以外にも、更新量・更新条件を acceptance 側定義として設定可能な incremental な event 進行順管理指標("event-line")が任意個数可能・event側からのevent-line発行が可能 な方が良い可能性を感じる。Q05について、numerical な eager 条件は、event-line 化した方が trigger の責務を理解可能にできるようにも思う。
  third-discussion: global tick ではない増減する値によって管理されるような、効果回数制限付きの状態変化 などの扱いを管理しやすい方式は、Q05 のeager (i.e. trigger) として回収することになるか。eagar と global tick のどちらかでも切れたら消滅する event も設計可能とする需要が 効果回数制限付きの状態変化 等にある。

→ reconciliation: これが PIVOT。entity 固有 WT/CT・効果回数・numerical eager を **event-line**(Q16)へ統一し、global tick は default event-line とする。前進方式と決定性は Q17、「eager or global tick のどちらか切れたら消滅」は多条件失効(Q18)、save 整合は Q22。core invariant を厳守: event-line は進行入力、master timeline は解決順で、後者は単一 comparator の全順序を維持する(Q08 を保持し、due_tick 直接書換は引き続き禁止)。「再計算なし」は event-line の per-tick 前進(Q17 (a))で実現し、rate 変化は event-line の増分変更で吸収する。

## Q08 — priority の不変性 [RECOMMENDED]

問い: ordering key の priority は entry 生成後に可変か。

推奨: 不変。変更は reschedule 経由のみ。heap/sorted backend の不変条件と trace の説明可能性を守る。

影響: EQM-010/011。

user意見: 正しい。

## Q09 — event 内 effect 順序と trigger 収集 [RECOMMENDED]

問い: 1 event が複数 effect を持つ場合 (AoE) の対象順序と、effect 適用中に発火条件を満たした trigger の扱い。

推奨: 解決単位は atomic とし、対象順序は deterministic な default (target id 順) + adapter による明示順 (空間順等)。trigger は適用中に interleave せず、解決完了後の collection window でまとめて arm / 発火評価する。

影響: EQM-051, EQM-061, EQM-080。

user意見:
  first-discussion: 原則としてそれで良いが acceptance 側でより上位の順序を定義できる必要がある(Q04)。例えば TO(tactics ogre) での WT値解消が複数 entity 時の composite event 解決として、ベースWT値が低い方を先に行動順とするなど。
  second-discussion: trigger は適用中にさらに別のtrigger あるいは event が反応するなど trigger nest の可能性についても配慮し、解決の判定には注意が必要となる。(Q05, Q02..?)

→ reconciliation: 上位順序の acceptance 拡張点は Q20(serializable key のみ、golden 必須)。trigger nest の停止規律は Q21 で window nest(Q02 meta-cost)と共通の reentrancy spec として統合する。

## Q10 — actor lifecycle [OPEN]

問い: 戦闘中の参加 (召喚・増援) / 離脱 / 死亡時に、pending 予約・round membership・反応準備をどう処理するか。actor_id の再利用を許すか。

推奨方向: actor_id 再利用禁止 (save/load と trace の同一性保証)。離脱時の pending は Q05 の invalidation 経路で処理。round membership 更新は policy 所有。

影響: EQM-021, EQM-030, EQM-090。

user意見: とくに問題ない

## Q11 — 数値域 [RECOMMENDED]

問い: tick / AP / meta cost / priority の数値域と溢れ・負値規則。

推奨: すべて int (tick は int64 前提を宣言)。負 AP の可否は policy 宣言制、上限超過は安定 error。float は ordering に一切関与しない (既存原則の数値域への具体化)。

影響: EQM-010, EQM-020。

user意見: 上限超過は acceptance 側定義動作とする。EQM 側 ordering には float 関与しないが、composit event 効果としての event 内効果順序として acceptance 側定義を想定した方が良い。

→ reconciliation: master comparator は int 全順序を維持する(float 不関与)。上限超過の acceptance 動作と、effect 内順序の acceptance 定義(float 可)は、いずれも Q20 の拡張点へ集約し、master ordering には混ぜない。これで「ordering 決定性」と「effect 表現の自由度」を層で分離する。

## Q12 — 感知分類の所属側 [RECOMMENDED]

問い: 感知範囲 / 可視性の分類 (important / sensed / offscreen) は simulation 側の deterministic data か、presentation 側の判断か。

推奨: simulation 側の deterministic data とし trace に含める。flush barrier 判断が依存するため、presentation 側に置くと presentation neutrality property (flush policy を変えても simulation trace 不変) が検証不能になる。見せ方の良否のみ presentation 側。

影響: EQM-080/081/082。

user意見: 正しい。

## Q13 — timeline の単一性 [RECOMMENDED]

問い: 1 つの EQManager に複数 timeline (4X の並行戦域等) を持たせるか。

推奨: 1 EQManager = 1 timeline を宣言し、複数 instance 間の同期は v1 scope 外とする。coverage matrix の 4X 行は単一 timeline での写像可能性を確認する。

影響: EQM-014, EQM-032。

user意見: 他要件と合わせて総合的に判断。

→ reconciliation: event-line(Q16)は timeline ではなく進行入力。よって「1 EQManager = 1 master timeline + 多数 event-line」と再 framing する。これで「複数の進行軸」需要は event-line で満たし、4X 並行戦域=複数 master timeline は別問題として v1 scope 外を維持できる。両者の混同が Q13 の迷いの原因だった。

## Q14 — 反芻の経済 [OPEN]

問い: 予約反芻による再予約時に AP を再徴収するか。解決時間 / due の再計算規則はどうするか。(ユーザー設計の "反撃準備" 予約反芻=1 は再徴収なしと読める。)

推奨方向: 再徴収なしを default とし、policy hook で変更可能にする。

影響: EQM-050, EQM-062。

user意見: 正しい。

## Q15 — replay の製品化 [OPEN]

問い: canonical trace を使った in-game replay / 戦闘 log UI を product 機能にするか。

推奨方向: v1 では defer。trace format が既に互換資産なので後付け可能。roadmap 改訂時に再検討。

影響: roadmap。

user意見: 正しい。

---

# 進行モデル擦り合わせ (Q16–Q23, 2026-06-13)

各項目は { 問い / なぜ重要 (game requirement) / 推奨 / 擦り合わせたい点 } で書く。`user意見:` 欄へ inline 注釈を入れてください。EQM-014 はこの全項目を解決して semantics に確定する。

## Q16 — event-line の導入 [PIVOT]

問い: core の進行を単一 global tick に固定するか、acceptance が更新量・更新条件を定義する任意個の incremental 指標 "event-line" を first-class にするか。global tick は default event-line になり、event は event-line を発行・参照できる。

なぜ重要 (game requirement): TO の WT・FFT の CT は entity 固有の蓄積/消費で行動順が決まる。効果回数制限付き状態は別の減少カウンタで切れる。これらは single tick では recalculation なしに表現しづらい。

推奨: 導入する。ただし invariant を厳守 — 「event-line = 進行入力 (state)」「master timeline = 解決順 (output)」を分離し、後者は単一 comparator の全順序を保つ。event-line は deterministic な sweep 点で master timeline の event に変換されるのみ。これで Q07/Q08(ordering key 不変・reschedule のみ)を壊さずに WT/CT を表現できる。

擦り合わせたい点: event-line を runtime で動的発行(event 側発行)まで許すか、config 宣言の固定 kind 集合に留めるか。前者は snapshot schema を動的化する(Q22)。entity 固有 event-line(per-entity WT/CT)は最初から必要と想定してよいか。

user意見: 推奨案を進める。event-line の event 側発行を許し、entity 固有 event-line を前提にはしない。entity 固有 event-line はその意味論が acceptance 側定義に基づくため、必須にすると多様な game 定義を一つの entity 固有 event-line の振る舞いとして扱うリスクがある。

## Q17 — event-line の前進方式と決定性 [OPEN]

問い: event-line の閾値到達検出を (a) 毎 tick polling か、(b) 現 rate からの crossing tick 計算 + rate 変化時の再 wake か。

なぜ重要: (a) は「少ない誤差(tick 粒度)」でユーザー許容・実装単純・決定性明白だが O(event-lines × ticks)。(b) は効率的だが「再計算なし」という意図に一部反する局所再計算。

推奨: 既定 (a) polling、large-scale 最適化として (b) を後段 backend に置く。両者が同一 golden trace を produce することを reducibility gate にし、Q07 の「再計算問題」を test で封じる。

擦り合わせたい点: 想定 entity 数 / 同時 active event-line 数 / 予測深さ N の概算。性能予算(G10, EQM-102)の入力になる。tick 粒度の「少ない誤差」は本当に全 game で許容か(分数 crossing の厳密順序を要求する系はあるか)。

user意見: 推奨案を進める。
### 概算

tick という time-like な incremental paramater に制限した上での概算から始める。
まず edge case を詰める。
  
- RTS的な過密な entitiy 数を伴う集団戦:
  
entity 集団として集約した active event-line に対して、tick を進めるものとする。
このケースでは、event-lines × ticks については上限を固定した運用を前提としてよい。ただし、acceptance 側定義において、entity 集団が tick による active event-line を指針にもつと同時に各 entity は non-tick かつ numerical で scale 可能な計算負荷の低い micro-event-line による行動管理に従うとする。これには、RTSにおける event-line 進行については tick との独立性を保つことでゲーム性の中心にある real time 体験への干渉を防ぐ意図がある。この目標はv1として含める必要はない。

RTSモデル: {
    想定 entity 数 : 極大, (100 .. 10000 * entity group 数(10 .. 1000))
    同時 active event-line 数: [
        小~中 ( 100程度 * 少数のcommander用 ),
        grouped-event-line 小 ( 10 * entity group 数 (10 .. 1000) 程度)
        micro-event-line: 極大( 10 * entity 数, scalable, small cost)
    ]
    予測深さ N : 1 ( RTS はplayer自身の予測能力が試される点にゲーム性があるため、EQM側の予測深さは大きくならない)
}

結論/RTS: RTSモデルにおいては tick 毎の計算コスト節減が機能安定と独立したEQMモデルを採用する。entity 数 : 極大 においては、(b) 案でも不足があるため。ただし、RTS は edge case であり v1 において目標とせず、今後の acceptance の指標としても基本的には検討しない。ただし、合理的な開発設計を具体化する便利な例としては使用することができる。

次の edge case に進む

- シューティングゲーム的な発散的な entitiy 数および 同時 active event-line 数 を持つ

STGモデルでは、entity を集約するGX的合理性がない。異なる time span で個別の entity, bullets が管理される。これに近いユースケースでは、entity あたりの active event-line 自体を制限する。

STGモデル: {
    想定 entity 数 : 大(生成消滅が早い), 
    同時 active event-line 数: 大(生成消滅が早い),
    予測深さ N : n (複数回破裂する bullets など?)
}

問題が大きいためここではこれ以上の記述を避けます。いくつかの acceptance について少し具体化を進めましょう。
予測深さの概念については何を意図しているのか分からずに返答しているため、実 game 例によるすり合わせが必要。
-> 予測深さ : deterministicな戦闘結果/turn進行予測表示が扱う event 数


## Q18 — 多条件の解決 / 失効 (OR/AND, on-expiry) [OPEN]

問い: 1 event/reservation が複数 event-line・reaction-count・predicate にまたがる「解決条件」「失効条件」を持てるか。組合せは OR か AND か両方か。失効時の on-expiry effect を持つか。

なぜ重要: 「3回 or 5ターンで消える buff」「eager と global tick のどちらか切れたら消滅」「反応回数で close(deadline=∞ 可)」を統一表現する(Q05/Q06/Q14 を吸収)。

推奨 (訂正前): 解決条件・失効条件をそれぞれ集合とし、既定 OR、AND は明示宣言。— この推奨は **解決と失効を 1 概念に混ぜていた誤り**であり、下記 user 決定により訂正された。

→ 決定 (訂正): 解決 `solve_conditions` 既定 = **AND**、失効 `invalidation_conditions` 既定 = **OR**。両者は別概念。AND 失効は decremental counter event-line へ回収。OR 解決は race pattern (event-line を条件にした複数 racing event の発行。event-line そのものを複数発行するのではない) で表現。race group は 3 表示分離 (EQM debug / game-dev debug / presentation) の概念契約を持つ (Decisions 2026-06-14 §2, 概念整理 EVENT_MODEL_CONCEPTS.md §3)。

擦り合わせたい点 (解決済み): AND 失効需要は grouped-event-line の全 member 消滅で存在するが、numeric (decremental) 入口へ回収して OR 結合のみを v1 規定とする。

user意見: 推奨案を進める。解決と失効では既定が異なる。解決の既定は AND とし、失効の既定はORとする。ただし、失効においても AND の実 game 需要が存在する余地はある。具体的には grouped-event-line における menber entity が全て消滅した場合の event 失効を扱うなら、意味論的には AND 条件が直接的だが decrimental な設計により AND 条件を回避可能。結論、for-all 型の失効 AND 条件は numeric に扱う入り口に回収し、失効条件の各 term は OR 結合を規定として v1 実装を進める。一方このとき、解決の既定は AND としてよい。仮に OR 条件での実 game 需要時は、同一 effect の event-line を異なる解決条件でそれぞれ発行し、それらいずれかの解決を失効 OR 条件として一律に採用すれば OR 解決の event-line 発行を実現可能。ただし、同一効果 event-line の複数発行は、EQM向けのdebug表示と、実 game 開発向けの debug 表示及び、実 game 向けの presentation の適切な扱いをそれぞれ分離する必要があることに注意し、ゲーム開発者向けの出口管理設計に注意する。

## Q19 — eager の責務分割 [OPEN]

問い: eager(状態変化への即時反応)を、(1) event-line 閾値で表せる numerical eager = deterministic sweep で評価、(2) 表せない真の event 駆動 = trigger engine、に二分するか。

なぜ重要: ユーザーの「eager の責務を検討したい」「numerical eager は event-line 化で trigger 責務を理解可能に」に対応。任意の状態変化で interleave する eager は決定性と理解性の敵。

推奨: 二分する。(1) は sweep 点でのみ評価され「eager に見えるが定義点で評価」。(2) は bounded な評価 round に限定。arbitrary-predicate-on-every-mutation という入力クラスは提供しない(UX_PATH_REDUCTION)。

擦り合わせたい点: sweep 点の定義。候補は「各 event 解決後の collection window(Q09 first)」「tick 境界」「event-line 値変化時」。どれを正準にするか(複数併用は決定性記述を複雑にする)。

user意見:推奨案を進める。各 event 解決後の collection window(Q09 first)を採用する。

## Q20 — 同時解決 / 上位順序の拡張点 [OPEN]

問い: composite event のメンバ順序、複数 event-line 同時到達時の解決順を、acceptance が deterministic な ordering-key で定義する拡張点をどう設計するか。

なぜ重要: TO「ベース WT 低い方が先」など上位順序は game 規則。effect 内順序も acceptance 定義(float 可)、ただし master ordering 本体には不関与(Q11)。Q04/Q09/Q11 を統合する。

推奨: serializable state から導出される acceptance 提供の比較キーのみ許可(live object 参照禁止、golden trace 必須)。これは「完走保証つき拡張点」であり UX_PATH_REDUCTION の合法な開集合(集合は open だが total order と決定性が closed に保証される)。

擦り合わせたい点: 上位順序キーが参照してよい情報の範囲。entity stat / event tag / event-line 値 のどこまでか。範囲を絞るほど決定性検証と説明(order_inspector)が容易になる。

user意見: 推奨案を進める。acceptance 側の ordering-key は entity stat, event の nesting level, event tag 等については"行動解決ターン制"において自然に実 game 想定を持つ。決定性のための最終fallbackは event 発行順としてよい。並列化された event 発行(同順序 eventの存在)を禁止し、default event-line に回収された event 発行タイミングに基づいて定める。ただし event 発行順はあくまで最終 fallback であり acceptance 側定義の ordering-key による解決を優先する。これらの例外として micro-event-line に関しては、上位の grouped-event-line のみが micro-event-line を代表して順序解決に関する責務を負うものとする ( v1 では defer )

## Q21 — reentrancy 統一: window nest と trigger nest [OPEN]

問い: 行動 window の nest(Q02, meta-cost)と effect 適用中の trigger nest(Q09 second)を、単一の reentrancy / depth モデルで扱うか、別層のままにするか。

なぜ重要: 両者とも「解決の途中で新たな解決が割り込む」構造。停止保証(well-founded order / bounded round / cycle guard)を二重に発明すると不整合になる。

推奨: 2 層を明示区別しつつ共通の depth/停止規律を共有する。window nest = meta-cost budget(Q02)、trigger nest = bounded collection round + cycle guard(EQM-062)。両者の最大深度と trace 表現を 1 つの reentrancy spec に統合記述する。

擦り合わせたい点: 「trigger が window を開く / window 内で trigger が立つ」の交差ケースを v1 で必要とするか。必要なら停止保証は両 budget の積で評価する設計になる。

user意見: 交差ケースは想定する。評価方法は暫定設計で良いが、今後の開発柔軟性( cost 設計オプションの柔軟性 )の余地は残す。

## Q22 — event-line × snapshot / actor lifecycle [OPEN]

問い: 動的 event-line(特に per-entity)の生成・破棄を snapshot がどう捉えるか。entity 消滅時の event-line cleanup。

なぜ重要: event-line を first-class 化すると save schema に「active event-lines とその値・rate・更新条件」が入る。Q01 の save 境界・schema version と直接干渉する。

推奨: snapshot に event-line table を含め schema_version(EQM-012)で守る。per-entity event-line は actor lifecycle(Q10)で cleanup し、actor_id 再利用禁止を踏襲。

擦り合わせたい点: save 境界(Q01 の base-operator level)で「全 event-line が安定値」である必要があるか。過渡的 rate 変化中(window open 中)の save 可否を Q01 の draft-rollback 規則とどう揃えるか。

user意見: draft-rollback 規則 は ゲーム体験上の任意 save 境界として扱い acceptance 側判断において推奨される save 境界とする。過渡的 rate 変化中(window open 中)の save はEQMとしては可能とするが acceptance 向けの十分な管理機能は提供しない。auto save 機能の可否程度にとどめる。

effect 処理チャンク に追加されている項目がある状態では save しない。逆に言えば、sync barriar は EQM 上で許容する save 境界でもあるということになる。注意点は、effect 処理チャンクへの追加は event-line 解決時であって、event-line 発行時ではない。また window open は open 時点でeffect が解消されたものとし、open 直後 effect 処理チャンクには無いものとする。

→ 決定: save 境界 = **effect 処理チャンクが空**。チャンク追加は event-line **解決時**(発行時ではない)。window open は effect 解消済みとみなす。sync barrier は許容 save 境界に一致 (Q25 と接続)。過渡的 rate 変化中 save は許容するが acceptance 向け十分管理は非提供 (auto save 程度)。draft-rollback は acceptance 推奨 save 境界。影響: EQM-012 snapshot に event-line table + effect-chunk 空判定、EQM-014 save 意味論。

## Q23 — 過剰一般化のガードレール [META]

問い: event-line 一般化は、自分で定めた UX_PATH_REDUCTION_POLICY(過剰一般化=負価値)と矛盾しないか。

整理: 矛盾しない。一般化するのは「進行・条件の substrate(core data model)」であり「user-facing 入口の入力クラス」ではない。両者は別物。ガードレール:
- (a) 全 event-line kind は serializable。
- (b) 前進は deterministic な定義点のみ。
- (c) reducibility test で既知系(CTB/energy/wait-turn/TO/FFT/ATB)が写像できることを常時 gate(EQM-053 を event-line へ拡張)。
- (d) arbitrary-predicate eager や generic picker のような「広い入口・完走非保証」は依然禁止。

擦り合わせたい点: なし(原則確認)。これに同意できれば event-line 導入と UX_PATH_REDUCTION は両立する。

user意見: 問題ありません

## Q24 — grouped / micro-event-line [DEFERRED]

問い: RTS 規模の極大 entity / event-line を扱う grouped-event-line (group 代表進行) と micro-event-line (entity 個別・低コスト・tick 非依存) を v1 で扱うか。

決定: **deferred**。v1 実装対象外。§8 の race pattern・event-line モデルが後付け可能な形であることを確認する **edge case 補助線** としてのみ使う。Q15 (replay) と同じ deferred 扱い。

留意 (将来の写像点): grouped-event-line のみが micro-event-line を代表して順序解決の責務を負う (Q20 例外)。RTS では tick 計算コストから独立した EQM モデルを採る想定。実 acceptance としては今後も基本検討しない。

影響: roadmap (deferred note のみ)。

## Q25 — sync barrier の支援 [OPEN(support)]

問い: 「event-line 同時性 / effect 処理チャンク境界」を core named concept (`resolution_chunk` / `sync_barrier` 等) として `EVENT_MODEL_SEMANTICS.md` に正式化するか。

決定: **core named concept にはしない**。event-line 同時性は sync barrier の一例だが全てではないため、grand unifying concept への昇格は避ける。ただし:

- EQM は具体機構として **effect 処理チャンク** を持ち、その空き=save 境界=sync barrier の一致 (Q22) は明記する。
- acceptance 側 game 開発は sync barrier 設計を必要とし、**EQM がそれを支援することは継続課題**として残す (presentation flush barrier (Q12, Phase8) との接続を含む)。

影響: EQM-014 (effect 処理チャンクは記載 / sync barrier は支援課題として注記), EQM-080/081 (presentation flush との接続)。

## Q26 — event-line identity / granularity / lifecycle / 再帰召喚 scaling [OPEN]

経緯: 「event-line 発行はインフラ的で低頻度」という当初の characterization は誤り。ユーザー指摘により撤回する。発行頻度は { design の granularity 方針 } × { runtime 動態 } の積で、gameplay/runtime に依存する。buff stacking と再帰召喚 (召喚対象がさらに召喚) が想定範囲にあるため要検討。

確定済み (EVENT_MODEL_CONCEPTS.md §3/§4):

- 進行の 2 表現: (1) first-class event-line (少数の独立軸) / (2) entity・effect 状態 + primary tick 上の sweep event (多数の同質進行)。多数 entity の同質進行は (2) を既定とし first-class event-line 数を O(1) に抑える。per-entity event-line は必須にしない (Q16)。
- counter identity = 数えたい意味単位。id は deterministic 採番 (発行順一意, Q20)。
- buff uses_left の「使い回し」は普遍規則ではない。stacking 意味論は acceptance 定義 (独立 stack / refresh / 共有 pool)。

問い (擦り合わせたい点):

1. **granularity 方針の所在**: (1)/(2) の選択を acceptance に委ねる API 形にするか、EQM が「多数同質なら (2)」を推奨/誘導する形にするか。
2. **再帰召喚の v1 cost 目標**: 想定する同時 entity 数の概算と、polling cost を「watched かつ非 frozen な event-line のみ」に sparse 化する方針で v1 を賄えるか (full grouped/micro-event-line = Q24 は引き続き deferred)。
3. **stacking 既定**: buff 再付与の既定意味論を refresh (単一 counter 再利用) とするか、独立 stack (個別 counter) とするか。どちらを default にしても他方は明示宣言で選べる、でよいか。
4. **lifecycle**: 再帰召喚で生まれた entity/counter の cleanup を actor lifecycle (Q10) に完全従属させてよいか。中途 (window open 中等) で消えた entity の pending event は Q05 invalidation 経路で処理、で齟齬ないか。

推奨方向: 1 → acceptance 選択だが EQM は (2) を natural path にし (1) の濫用を防ぐ (UX_PATH_REDUCTION と同趣旨)。2 → sparse polling + (2) で v1 を賄い、RTS 極大は Q24 deferred。3 → refresh を default、独立 stack を明示宣言。4 → 従属させる。

影響: EQM-012 (snapshot の event-line table), EQM-014 (granularity/identity 契約), EQM-017相当 polling (EQM-053/102), EQM-021 (actor registry), Q10/Q17/Q22/Q24 と接続。

user意見:
1 -> 推奨案とする。ところで"多数同質"のような概念が自明に思えるほど明確化できるなら、それ自体価値がある結果である。
2 -> 推奨案とする。ただし、watchedの範囲は何が定めるのか？予測深さに従属させるのか、独立な acceptance 選択に従うのか。
3 -> 推奨案とする。どちらも選択できる。
4 -> 推奨案とする。

→ 決定 (2026-06-14, status: DECIDED(user)): 4 点とも採用。追加明確化:

- **「多数同質 (homogeneous)」の定義**: 進行規則の *shape* が同一で per-entity parameter のみ異なるもの。例: 「毎 tick 自速度ぶん CT 加算、閾値で行動」は速度の値だけ違い shape は同一 → 1 つの sweep event が全員を前進できる (pattern 2)。条件・効果の *構造* が個別に違えば heterogeneous → pattern (1)。判定は「規則を共通 callable + per-entity param に分離できるか」で機械的に下せる。この定義を `EVENT_MODEL_CONCEPTS.md` §3.1 に明文化する (ユーザー指摘どおり、定義自体が成果)。
- **watched の範囲**: event-line が watched = 未解決 event の solve/invalidation 条件が 1 つ以上それを参照していること。current pending 条件から導出される **state 由来の性質**で、予測深さには従属しない。予測は前進の各 step で watched-set を再評価するだけ。frozen (rate 0) と非 watched は polling 対象外 (sparse polling)。
- stacking は refresh default / 独立 stack 明示宣言の両選択可。lifecycle は actor lifecycle 従属、中途消滅 entity の pending は Q05 invalidation 経路。

影響: EVENT_MODEL_CONCEPTS.md §3.1 (homogeneity 定義), EQM-014 (watched-set / sparse polling 契約), EQM-053/102 (polling cost)。

---

# 実装ラウンド擦り合わせ (Q27–Q43, 2026-07-02)

経緯: v1.0 RC 完了後の契約監査 (`docs/review/EVENT_MODEL_DESIGN_GAP_AUDIT_2026-07-02.md`) で、(a) SEM §16 凍結契約が予約のみで未実装であること、(b) それらを実装するには SEM の記述粒度では足りない設計詳細が残ることを確認した。本 round はその設計詳細を確定し、v1.x 実装 queue (EQM-110 系、監査報告 §5) の入力にする。各項目は Q16–Q26 と同じ形式で、`user意見:` 欄へ inline 注釈を入れてください。決定後は SEM v1.1 (EQM-110) へ確定記述し、各項目を pointer に置き換える。

### Finalization (EQM-110, 2026-07-02)

全 17 項目がユーザー注釈により確定した (Q31 は相談つき条件承認 → reconciliation で解決)。確定記述は `EVENT_MODEL_SEMANTICS.md` **v1.1** の *(v1.1)* 節、根拠は `docs/review/EVENT_MODEL_OPEN_QUESTIONS_SYNTHESIS_2026-07-02.md`。実装対応は `docs/design/EVENT_MODEL_CONTRACT_COVERAGE.md` が追跡する。

| Q | 決定の記録先 (SEM v1.1) | 実装 owner |
|---|---|---|
| Q27 key 導出 / Q28 invalidation-wins・race 勝者 / Q29 level AND | SEM §5.4 | EQM-111/113 |
| Q30 named predicate registry | SEM §5.5 | EQM-111 |
| Q31 解決 pipeline (宣言 linkage の effect callback) | SEM §6.1 | EQM-113 |
| Q32 reaction schedule 化 | SEM §6.2 | EQM-113 |
| Q33 event-line data model / Q34 threshold level 意味論 | SEM §4.6 | EQM-112 |
| Q35 sweep rule registry (effect grouping は declared follow-up) | SEM §4.7 | EQM-112 |
| Q36 window object model / Q37 deadline 既定 | SEM §8.1 / §9 | EQM-114 |
| Q38 ordering hook (bundle は後段) | SEM §7.1 | EQM-115 |
| Q39 invalidate_actor 正規経路 | SEM §13 | EQM-113 |
| Q40 expiry event 化 | SEM §6.3 / §11 | EQM-113 |
| Q41 snapshot v2 + save 配線 | SEM §10 | EQM-117 |
| Q42 authoring surface (受け入れ基準凍結) | SEM §5.6 | EQM-119 (schema は EQM-111) |
| Q43 性能予算 | SEM §12.1 | EQM-112 |

| id | status | 領域 |
|---|---|---|
| Q27 | DECIDED(user) | 条件成立 event の ordering key 導出 |
| Q28 | DECIDED(user) | solve/invalidation 同時成立・race 勝者 |
| Q29 | DECIDED(user) | solve AND の評価様式 (level / latched) |
| Q30 | DECIDED(user) | predicate 条件の serialize (named registry) |
| Q31 | DECIDED(user) | 解決 pipeline の callback 契約 (PIVOT; reconciliation 済み) |
| Q32 | DECIDED(user) | fired reaction の解決方式 (nest / schedule) |
| Q33 | DECIDED(user) | event-line update rule の表現 (data 限定) |
| Q34 | DECIDED(user) | threshold 意味論 (level 統一 / repeating) |
| Q35 | DECIDED(user) | pattern (2) sweep rule の宣言・serialize |
| Q36 | DECIDED(user) | window の object model |
| Q37 | DECIDED(user) | deadline 到達時の既定動作 |
| Q38 | DECIDED(user) | composite 形成規則と hook signature |
| Q39 | DECIDED(user) | actor 離脱の正規 invalidation 経路 (Q05 是正) |
| Q40 | DECIDED(user) | duration expiry の event 化形 (Q06 是正) |
| Q41 | DECIDED(user) | snapshot schema v2 (additive) |
| Q42 | DECIDED(user) | L2 authoring surface (行動解決ターン制) |
| Q43 | DECIDED(user) | event-line polling 性能予算数値 |

## Q27 — 条件成立 event の ordering key 導出 [RECOMMENDED]

問い: solve_conditions が sweep 点で成立した event は、master timeline 上でどの ordering key `(due_tick, priority, sequence)` を得るか。SEM §5 (条件) と §3 (comparator) の間に key 割当規則がない — 三面モデルの「入力 → 出力」の弁に変換規則が未定義。

なぜ重要 (game requirement): WT/CT 到達で行動権を得る event の解決タイミングと同 tick 内順序はゲーム性そのもの。規則がないと event-line backend の実装ごとに順序が変わり、決定性 golden が書けない。

推奨: 成立を検出した sweep 点の global tick を `due_tick` に、`priority` は event 宣言時に固定した値 (default 0)、`sequence` は新規採番で push する (reschedule と同型)。条件 event と delay 型 scheduled event は同一 comparator に乗り、§3 は不変。非 tick event-line 参照条件でも due_tick は「成立検出時の global tick」で統一する。

擦り合わせたい点: 同 tick 内で「条件成立 event」と「既存 scheduled event」の相対順序は comparator (priority → sequence) に委ねてよいか。それとも「scheduled 優先」等の層別規則が要るか。

user意見: 承認。comparatorに委ねて良い。

## Q28 — solve / invalidation の同時成立・race 勝者 [RECOMMENDED]

問い: 同一評価点で solve_conditions と invalidation_conditions が両方成立した場合の優先規則。および race pattern で複数 racing event の solve が同時成立した場合の勝者決定。

なぜ重要: 「3回 or 5ターン」の buff が最後の 1 回の使用と同時に turn 切れした場合等、境界一致は実 game で頻出する。規則がないと race pattern の決定性が保証できない。

推奨: **invalidation-wins** (失効優先)。効果を出さない側に倒すのが安全で、race の敗者一掃とも整合する。race 同時成立の勝者は comparator hook (Q20) → fallback = 発行順 (§7) で決める。どちらも trace の `closed_by` で説明可能にする。

擦り合わせたい点: invalidation-wins を全 event 一律の core 規則とするか、event 宣言で solve-wins を選べる optional にするか (推奨: 一律。分岐は UX_PATH_REDUCTION に反する)。

user意見: 承認。一律で良い。

## Q29 — solve AND の評価様式 (level / latched) [RECOMMENDED]

問い: `solve_conditions` (AND) は「同一評価点で全 term が成立している」(level-triggered) か、「各 term は一度成立したら記憶される」(latched) か。

なぜ重要: 「AP ≥ 5 かつ 対象が可視」で、AP が一度 5 に達した後 4 に落ちてから対象が可視になったとき解決するか否かが変わる。決定性 trace の説明可能性にも直結する。

推奨: **level-triggered を唯一の意味論**とする。latched が必要な game 規則は「成立時に decremental/incremental counter event-line へ書き込む」ことで表現でき (Q18 の AND 失効回収と同型)、primitive を増やさない (UX_PATH_REDUCTION)。

擦り合わせたい点: latched 相当の実需要が counter 経由の表現で書きにくくないか、行動解決ターン制の具体例で確認したい。

user意見: 承認。latched 相当の実需要例：1. ある地点に侵入してから一定ターン経過.< 問題なさそう  2. ある地点範囲内で一定ターン経過 < これは侵入時/離脱時に予約を追加/失効を伴えば良い

## Q30 — predicate 条件の serialize (named registry) [RECOMMENDED]

問い: trigger predicate 型の条件はどう snapshot/replay を生き延びるか。現 `EQCondition.custom_predicate` は transient な Callable で、pending 条件が save を跨げない。

なぜ重要: 条件つき event は数 tick〜数十 tick 生存する。save/load 後に条件が消える・評価不能になるのは L2 の中核 UX を壊す。live object 禁止 (Q20) とも整合させる必要がある。

推奨: **named predicate registry**。acceptance が起動時に `register_predicate(name, callable)` で登録し、条件は name (StringName) のみ保持・serialize する。load 時に未登録 name は安定 error (ERROR_CONTRACT 追加)。`custom_predicate` の直接保持は「save を跨がない transient 用途」と明記し、予約条件経路では named のみ許可する。

擦り合わせたい点: registry の所在 (EQRuntime instance か global か — 推奨: runtime instance。scene-local 原則と整合)。predicate の入力 view の固定 (serializable dict のみ、Q20 と同じ制約) でよいか。

user意見: 承認。それらの案で進める。

## Q31 — 解決 pipeline の callback 契約 [PIVOT]

問い: event 解決 1 回の正確な呼出し順序と、consumer (acceptance) が実装する面をどう固定するか。SEM §6 は sweep を散文で述べるが、「誰が effect を適用するか」「chunk へいつ積むか」「sweep で何を再評価するか」の call contract がない。

なぜ重要: これが event-line / conditions / trigger / chunk / trace の全てを繋ぐ**唯一の統合点**。ここが曖昧なまま各機構を実装すると、現行のように機構どうしが配線されない (chunk が孤立、trigger が別経路) 再発を招く。他の Q の大半はこの契約の細部。

推奨: 解決 pipeline を 1 契約に固定する:
1. scheduler.pop → event 確定 (lazy invalidation 評価、`invalid_event_skipped`/`closed_by`)
2. acceptance の **effect callback** (`apply_effect(event_view) -> Array[EQEffectRecord]`) — effect 適用の唯一の実装点
3. EffectRecords を **effect 処理チャンクへ記録** (Q22 の「解決時に積む」を機械化)
4. **sweep**: trigger 収集/発火評価 + 数値 (event-line) invalidation 再評価 + event 発行/event-line 発行・re-rate の反映
5. trace 記録 → chunk drain → 次 event へ (chunk 空 = save 境界)

consumer 実装点は effect callback / (optional) comparator hook / (optional) named predicate のみ。`EQRuntime.advance` と `EQReservationRuntime.resolve_next` はこの pipeline に統合する。

擦り合わせたい点: effect callback を必須にするか (L0/L1 の現行 `finish_action` 流儀は「effect なし解決」として残す)。chunk drain のタイミング (各 event 後 / 各 sweep 後)。

user意見: 詳しく相談したい。effect callbackがない場合、開発者が管理しにくくならないだろうか？そうでなければ任意項目で構わない。

→ reconciliation (2026-07-02): 管理しやすさは「必須化」ではなく「**宣言したら必ず結線される**」ことで担保する — 宣言 linkage 方式。`EQActionDefinition.effect_name` (optional) を導入し、設定された reservation の解決は named effect registry (`register_effect(name, callable)`, Q30/Q35 と同一機構) の handler を呼び、返る EffectRecords を chunk へ積む。**設定済み + 未登録 = 安定 error** (silent skip 禁止)。空 = 明示的 effect なしで合法 (WAIT/READY、L0/L1 の `finish_action` 流儀)。「callback を書いたのに呼ばれない / 宣言したのに handler がない」が error で塞がれるため、任意項目でも管理性は落ちない — user の条件節を満たし**任意項目で確定**。L2 の natural path は named-effect (docs/template/dogfood で提示)。SEM §6.1。

## Q32 — fired reaction の解決方式 (nest / schedule) [RECOMMENDED]

問い: sweep で発火した reaction を、その場で入れ子解決するか (現 `fire_cascade` の in-place 方式)、「現在 tick の event」として master timeline へ schedule するか。

なぜ重要: 三面モデルの不変条件は「解決するのは timeline 上の event のみ」。現行の in-place 解決は fired reservation が comparator を通らず、trace 上も解決順の説明可能性が落ちる。Q21 の bounded round の単位もこれで決まる。

推奨: **schedule 方式**。fired reaction は `due_tick = current`, `priority = 宣言値`, 新規 sequence で push し、次の pop から通常 pipeline (Q31) で解決する。cascade = 「sweep → 発火 → schedule → 解決 → sweep …」の反復で、bounded round (round 上限 + 同一 (event, reaction) 再発火 guard) を trace に round 番号つきで記録。`fire_cascade` の in-place 解決は廃止。

擦り合わせたい点: 割り込み系 (「攻撃の前に反撃」) は priority で表現可能だが、「同 tick 内で必ず元 event の直後」を保証する reaction 専用の順序規則が要るか (推奨: priority + sequence で足りる。専用規則は増やさない)。

user意見: 承認。専用規則は不要。

## Q33 — event-line update rule の表現 (data 限定) [RECOMMENDED]

問い: event-line の「acceptance 定義の更新規則」を serializable data に限定するか、callable を許すか。

なぜ重要: 決定性・snapshot・replay の三点が「規則 = data」であることに依存する。callable を許すと event-line table が save を跨げない (Q30 と同根)。

推奨: **data のみ**: event-line = `{id, value: int, rate: int per primary tick}`。前進は (a) tick 結合の rate (watched かつ rate≠0 のみ polling, §4.3) と (b) event effect からの明示 `advance(line_id, amount)` の 2 経路のみ。rate 変更 = re-rate (event effect 経由)。callable 型の更新規則は導入しない。複雑な更新は「規則を持つ side の event」が明示 advance する形へ寄せる。

擦り合わせたい点: rate を「tick あたり固定 int」より広げる需要 (例: 帯域 [a,b] の deterministic RNG 加算) を v1.x で持つか (推奨: 持たない。RNG 加算は sweep event + 明示 advance で表現可能)。

user意見: 承認。evelt-line自体のdataに吸収する。帯域も不要。

## Q34 — threshold 意味論 (level 統一 / repeating) [RECOMMENDED]

問い: 条件 `(event-line, threshold, comparison)` は「crossing (到達の瞬間)」を検出するのか「level (現在値の比較)」を評価するのか。周期到達 (100 ごとに行動) と 1 poll 内の複数 crossing をどう扱うか。

なぜ重要: WT/CT の再帰的な行動順、rate が大きい場合の跨ぎ越しで順序が変わる。

推奨: **level 意味論に統一** (Q29 と同型): 評価点で `value ⋛ threshold` を見るだけ。到達の瞬間性は「解決した event の effect が line を reset/減算する」ことで作る (CT 系: 行動時に CT -= threshold)。これにより repeating threshold primitive も 1 poll 複数 crossing 問題も core から消える。跨ぎ越し誤差は Q17 のユーザー許容 (tick 粒度の少ない誤差) の範囲内。

擦り合わせたい点: 同一 tick で複数 entity が同時に threshold を跨いだ場合の順序は Q27/Q38 (comparator hook → 発行順) に委ねる、でよいか。

user意見: 承認。順番はその案に従う。

## Q35 — pattern (2) sweep rule の宣言・serialize [RECOMMENDED]

問い: CONCEPTS §3.1 の pattern (2)「共通 callable + per-entity param」の sweep rule を、どう宣言・serialize するか。callable は snapshot を跨げない。

なぜ重要: 多数同質進行 (全 entity の CT) の既定経路が pattern (2) であり、ここが不定だと「natural path」が作れず、per-entity first-class event-line (pattern 1) の濫用へ流れる (Q26 の意図と逆行)。

推奨: sweep rule も **named rule registry** (Q30 と同一機構) で宣言する: `register_sweep_rule(name, callable)`、per-entity param は actor state 内の serializable data。EQM は primary tick 上の system event としてこれを実行し、`event_line_progressed` 相当の trace (rule name + 対象数) を残す。snapshot は rule name + param のみ保存。

擦り合わせたい点: sweep rule の実行順 (複数 rule 登録時) — 推奨: 登録順固定 + 決定性 test。rule 内の entity 走査順 — 推奨: actor_id 昇順固定。

user意見: 承認。backendとしてこのような順番を持つ。sweepに限った話ではないが視認性のため、ゲーム開発者の意図に応じたeffectのgrouping設計の余地があっても良い。

## Q36 — window の object model [RECOMMENDED]

問い: window を runtime object としてどう定義するか。EQTransaction (1 段 draft/commit) との関係、meta-cost budget の所在、trace field。SEM は window の性質 (§8/§9/§10) を述べるが object としての定義がない。

なぜ重要: Q01 (save cap)・Q02 (budget)・Q03 (deadline)・Q21 (reentrancy)・Q22 (save 境界) が全て window 概念に依存する。実装はここが決まらないと始められない。

推奨: first-class `EQWindow`: `{window_id (deterministic 採番), owner_actor, nest_level, kind (acceptance tag; base-operator 判定は kind で), deadline (tick, ∞=frozen), budget_paid, draft}`。**EQTransaction は window の draft 実装として従属** (1 window = 1 draft; 現 API は互換 wrapper 化)。open/close は runtime API で行い `window_opened` / `window_closed` trace (fields: id / owner / nest_level / deadline / close cause) を emit。budget は owner actor の serializable state から支払い、chain 中非回復 (Q02) を window stack が enforce する。

擦り合わせたい点: L0 の `turn_ready` → suspend (§14) を「暗黙の nest_level=0 window」として統一するか、window は L2 opt-in に限るか (推奨: 統一。save cap の base-operator level が自然に定義できる)。

user意見: 承認。「暗黙の nest_level=0 window」として統一します。base-operator levelの柔軟さが、ゲームモードの多層性に効いてきます。

## Q37 — deadline 到達時の既定動作 [RECOMMENDED]

問い: deadline つき window (Q03) で deadline tick に到達したとき、open draft をどうするか。

なぜ重要: ATB active の「時間切れで手番を失う」体験の core 側既定。曖昧だと acceptance ごとに挙動が割れ、save 境界 (Q22) とも干渉する。

推奨: 既定 = **draft rollback + window close** + `window_closed(cause: deadline)` trace。commit したい game は close 前 hook (acceptance callback) で明示 commit を選べる。deadline は global tick 上の絶対 tick で、deadline window 中は tick が流れ続ける (§9)。rollback 後の chunk は空なので save 境界とも整合。

擦り合わせたい点: 「時間切れ時に強制 default 行動」の需要は hook での明示 commit に含めてよいか (推奨: よい。silent default は禁止原則に反する)。

user意見: 承認する。ゲーム開発者側が具体的対応を設計することが前提の項目である。

## Q38 — composite 形成規則と hook signature [RECOMMENDED]

問い: composite event (§7) は「いつ・誰が」形成するか。comparator hook の具体 signature。SEM は composite の保証 (atomicity 等) と hook の制約 (serializable, float 可, golden 必須) は定めたが、形成の trigger と関数形が未定。

なぜ重要: TO の「複数 entity 同時 WT 解消はベース WT 低い順」等、同時到達の解決はゲーム規則の核心。ここが決まらないと Q27/Q34 の同時到達ケースが閉じない。

推奨: **自動束ねはしない**。同一 sweep 点で同時に解決可能になった event 集合を候補として hook に渡し、hook は順序 (permutation) を返す。hook 未提供時の既定 = 発行順で逐次解決。composite (atomic bundle) 化は acceptance の明示 API とし、v1.x では「hook = 順序決定のみ」に絞り atomic bundle は後段 (v1.x 後半) に置く。signature 案: `order_simultaneous(candidates: Array[Dictionary(serializable view)]) -> Array[int]`。出力は golden trace に載せる。

擦り合わせたい点: v1.x 前半を「順序 hook のみ」に絞る段階分けでよいか。candidates view に含める field 範囲 (entity stat / event tag / event-line 値 / nest level — Q20 決定の範囲)。

user意見: 承認。その方針で良い。

## Q39 — actor 離脱の正規 invalidation 経路 (Q05 是正) [RECOMMENDED]

問い: 死亡・離脱 actor の pending event 処理を、現行の「anomaly (contract_violation, dev では halt)」から Q05 意図の「通常経路」へどう是正するか。

なぜ重要: 戦闘中の死亡はゲームの通常進行。dev mode (既定) が routine な状況で halt する現状は、Q05「lazy 判定 + `invalid_event_skipped` を標準とする」と `RUNTIME_RESILIENCE_POLICY` の意図 (anomaly のみ二相) の両方に反する。

推奨: 正規 API `invalidate_actor(actor_id, cause)` を追加: pending event を cancel し、armed reaction を解除し、per-entity 進行を cleanup (Q10/Q22) し、`closed_by: actor_removed` trace を残す (両 mode 同一動作・mode 中立)。`EQNodeBridge.on_actor_freed` はこれを呼ぶ。この経路を通らず unregister 済み actor の event が pop される場合のみ、従来どおり contract violation (dev halt) を維持する。

擦り合わせたい点: 離脱 actor を**対象** (target) とする他者の event の扱い — 推奨: core は関知せず、acceptance が invalidation 条件 (named predicate or counter) で表現する。これで足りるか。

user意見: それを可能にする枠組みとしては承認。ただし、開発者側で設計可能なゲームルールの詳細に先回りする必要はない。需要を受け取った時点で随時検討する。蘇生スキル・召喚スキルなど離脱済みを対象にとる行動は検討可能であり、あまりこちらでは細部を埋め込みすぎない。

## Q40 — duration expiry の event 化形 (Q06 是正) [RECOMMENDED]

問い: Q06 決定「duration expiry は event として timeline に乗り trace に可視・on-expiry trigger 定義可能」を、どの機構で実装するか。現行 trigger engine は silent 削除。

なぜ重要: 反応準備の失効はプレイヤーに見える状態変化であり、trace に無いと replay/デバッグで説明不能。on-expiry effect (失効時反動等) の定義点でもある。

推奨: arm 時に **expiry event** を `due_tick = armed_at + duration` で master timeline に schedule する (duration=∞ は schedule しない)。解決時: 対象がまだ armed なら失効処理 + `closed_by: duration` trace + optional on-expiry effect (Q31 pipeline に乗る)。先に反応回数で close していれば expiry event は lazy invalidation (`invalid_event_skipped` ではなく `closed_by: already_closed` の軽量 trace) で消える。reaction-count 消尽も同じ `closed_by` 語彙 (`closed_by: reaction_count`) で記録し、Q18 の条件語彙と揃える。

擦り合わせたい点: expiry event が queue を埋める規模 (armed 数百) の懸念 — 推奨: 許容 (EQM-102 予算内)。だめなら「失効は sweep の数値 invalidation で評価、trace のみ event 相当に記録」へ後退する。どちらを既定にするか。

user意見: 承認。推奨案で進める。

## Q41 — snapshot schema v2 (additive) [RECOMMENDED]

問い: event-line / window / pending conditions / armed trigger を snapshot にどう足すか。v1 save との互換。

なぜ重要: Q22 決定 (snapshot に event-line table) の実装形。`SNAPSHOT_COMPAT_V1.md` の preserve/migrate 立場に従う必要がある。

推奨: `schema_version = 2` で table を additive 追加: `event_lines[{id, value, rate, watched は導出なので保存しない}]`, `windows[{window_id, owner, nest_level, kind, deadline, budget_paid, draft}]`, `pending_conditions` (event 側に inline), `armed_triggers[{reservation, condition(named), armed_at, duration, expiry_event_id}]`。v1 bundle は load 可 (欠落 table = 空) の migrator を実装し、v2 save を v1 実装が読む方向は不支持 (stable error)。`is_save_allowed()` を `EQSaveAdapter.save` / `EQManager` に配線し、chunk 非空 save は安定 error (auto-save 用に force flag は設けない — 過渡 save は「chunk 空だが window open」の状態で表現される)。

擦り合わせたい点: draft (open window) の serialize は Q01 の「rollback して boundary 保存」を既定にするか、draft ごと保存も許すか (推奨: 既定 rollback、draft 保存は snapshot-for-rollback 側のみ)。

user意見: 承認。Q01が既定。

## Q42 — L2 authoring surface (行動解決ターン制) [RECOMMENDED]

問い: game 開発者が「条件つき予約」を宣言する Resource 面をどう設計するか。契約を実装しても、書き味が L3 露出だと本製品の目的 (構築しやすさ) を外す。

なぜ重要: 本 round の実装は全て L2/L3 基盤であり、開発者が触るのは authoring 面だけ。ここの受け入れ基準を先に固定しないと、実装都合の API が漏れる (L0/L1 非漏出は EQM-023 が守るが、L2 の書き味は gate がない)。

推奨: `EQActionDefinition` を additive 拡張: `solve_conditions: Array[EQConditionSpec]` / `invalidation_conditions: Array[EQConditionSpec]`。`EQConditionSpec` = `{type: LINE_THRESHOLD | COUNTER | NAMED_PREDICATE, line_id, threshold, comparison, counter_start, predicate_name}` の serializable Resource。既存 `duration` / `rumination` は糖衣 (validate 時に条件へ正規化) として互換維持。**受け入れ基準: 「反撃準備 — 3 回 or 5 ターンのどちらかで close、deadline ∞ 可」が .tres 1 個・GDScript 0 行で宣言でき、trace の `closed_by` にどちらで閉じたかが出ること。** editor picker は Phase 9 の資産 (metric harness) を再利用する。

擦り合わせたい点: 糖衣 (duration/rumination) を残すか、v1.x で条件宣言へ一本化するか (推奨: 残す。既存利用者の互換と「単純な場合は単純に」の両立)。

user意見: 承認。今後需要に応じて拡張は検討する。

## Q43 — event-line polling 性能予算数値 [OPEN]

問い: event-line backend (Q33) の polling / sweep の性能予算を数値で確定する。Q17 の概算は RTS/STG の edge case 検討で終わっており、v1.x の目標規模が未宣言 (EQM-102 の予算は scheduler 操作のみ)。

なぜ重要: 予算がないと EQM-112 の acceptance が書けず、「watched のみ polling」の sparse 化 (Q26) が十分かも判定できない。

推奨 (要ユーザー確認の下書き): v1.x 目標 = 同時 actor ≤ 200 / watched event-line ≤ 300 / armed trigger ≤ 200 / `advance()` 1 call の追加コスト ≤ 0.5ms (Godot 4.6 headless debug, EQM-102 と同条件)。RTS/STG 規模は対象外を維持 (Q24 deferred)。予測 (EQM-033) は同予算内で depth N ≤ 20。

---

# 拡張ラウンド擦り合わせ (Q44–Q54, 2026-07-05, EBS 実需要)

経緯: consumer プロジェクト **EBS** (godot-editable-battleskill-system) から状態・関係システムと解決パイプライン拡張の依頼 (R01–R12) を受領した。受領原本: `docs/plan/2026-06-09_event_queue_manager/EBS_EXTENSION_REQUEST_2026-07-05.md` (EBS 側原典 `docs/design/EQM_EXTENSION_REQUEST.md` draft v2、相談ラウンド1 反映済み)。依頼を本 registry の Q44–Q54 に起票する。起票と同日に**相談ラウンド2** を実施し、8 個の意味論 fork が DECIDED(user) となった (下表)。残る RECOMMENDED 項目は設計ラウンド (SEM v1.2 起草 task) の入力。roadmap 対応: `ROADMAP.md` §7 Phase 13。applicative case: `ORDERING_MODEL_COVERAGE.md` row 10。

### Finalization (EQM-120, 2026-07-05)

**相談ラウンド3** (同日) で残る fork 8 点も確定し、全 11 項目が settled した。fork 計 16 点のうち推奨からの逸脱 5 点 (展開停止 = メタ/コスト、変換多重適用 + EBS 側 validation、変換のパラメータ別型、フェーズ内 sub-checkpoint、ループ = 巻き戻し方式) は synthesis に明示。確定記述は `EVENT_MODEL_SEMANTICS.md` **v1.2** の *(v1.2)* 節、根拠は `docs/review/EVENT_MODEL_OPEN_QUESTIONS_SYNTHESIS_2026-07-05.md`。実装対応は `EVENT_MODEL_CONTRACT_COVERAGE.md` の reserved 行 (EQM-121..128) が追跡する。

| Q | 決定の記録先 (SEM v1.2) | 実装 owner |
|---|---|---|
| Q44 inv ペア + 共存規則 / Q46 寿命合成 | §5.7 | EQM-121 (acceptance 例は EQM-121/128) |
| Q45 rate modifier-stack | §4.8 | EQM-121 |
| Q47 関係グラフ | §13.1 | EQM-122 |
| Q48 展開 (波及) / 連鎖 = wrapping | §6.4 2a / §5.7 | EQM-123 / wrapping は EQM-121 |
| Q49 composite atomic bundle | §7.2 | EQM-124 |
| Q50 premature close / Q51 メタレベル | §8.3 / §8.2 | EQM-125 |
| Q52 変換フック + 発行連鎖 provenance | §6.4 2b / §6.5 | EQM-123 |
| Q53 フェーズ再帰 + sub-checkpoint + 巻き戻し | §8.4 | EQM-126 |
| (横断) snapshot v3 | §10.1 | EQM-127 |
| Q54 確認系 acceptance 束 | §16.2 | EQM-128 |

### 相談ラウンド3 の決定 (2026-07-05)

| # | fork | 決定 |
|---|---|---|
| 9 | 連鎖 (状態のラッピング) の機構 | **デコレータ型** — 状態が状態を包み、包まれた側の付与・解除・効果の意味論を修飾する状態合成構造 (関係伝播型/トリガ型ではない) |
| 10 | 結び直し規則の宣言語彙 | 直列縫合のみ (enum {NONE, SERIAL_SUTURE}、additive 拡張余地) |
| 11 | 発行連鎖の載せ場所 | event 側 provenance で確定 (event-line 拡張示唆は三面分離を理由に不採用 — 承認済み) |
| 12 | pipeline 詳細 | 段 (pop 直後・effect 前、展開→変換)・BFS 関係 id 昇順・bundle 前倒しを承認。**修正**: 展開の再帰停止 = メタレベル/コスト準拠 (§8 語彙)。変換は多重適用許可 — 適用構造は開発者が計画できる data、意味 validation は EBS 側。変換は event パラメータごとの型 (対戦術 = 対象先変換 / 反転系 = 状態代数変換) |
| 13 | 相殺の記録形 | 符号付き counter line 1 本 (inv ペア = 1 軸の両方向) |
| 14 | modifier 合成語彙 | 加算 + override のみ (乗算は整数分数 + 丸め規則の定義が前提のため需要待ち) |
| 15 | actor 離脱と関係グラフ | 解消時規則を通して自動解消 (`closed_by: actor_removed` + relation trace) |
| 16 | フェーズ checkpoint 粒度 | **フェーズ内 sub-checkpoint も必要** (1 つの OPERATION window 内の多段フェーズ遷移を想定) |

### 相談ラウンド2 の決定 (2026-07-05)

| # | fork | 決定 |
|---|---|---|
| 1 | メタレベルの付与先 | スキル宣言の int (EBS 解決仕様ブロック)。発行 event / 開いた window が実行時に運ぶ。未宣言 = 0。nest 深度と独立 |
| 2 | メタレベルの値域・同値 | 単一 int の全順序 (部分順序は不採用)。同値 = 介入成功 (window は中終了する) |
| 3 | 発行連鎖とメタレベル | 連鎖の各段がその段の操作 event の宣言メタレベルを保持。対戦術/反射の target 調整幅 = レベル差が許す最遠段 |
| 4 | inv 双対の共存意味論 | ペア宣言 + 規則選択制 (相殺 / 排他 / 共存 を pair ごとに data で宣言) |
| 5 | suspension の重複・復帰 | modifier-stack モデル (base rate + 寿命付き modifier 集合、実効 rate は変更毎に決定的再計算) |
| 6 | 関係維持条件の評価タイミング | 関係型ごとに宣言した sweep で評価 (既定 = primary tick の宣言閾値 = ゲームの「T開始時」) |
| 7 | window 中終了の効果範囲 | 解決済み効果は維持、pending のみ打ち切り (`window_closed(cause: intervention)`) |
| 8 | 操作フェーズのループ解消 | ループ開始点へ巻き戻し (EQTransaction working-copy) + 最小 cycle 上の鏡面入力を解除して再開 |

### R→Q 対応

| 依頼 | Q |
|---|---|
| R01 状態代数 | Q44 (双対) / Q45 (suspension) / Q46 (寿命合成) |
| R02 関係グラフ | Q47 |
| R03 連鎖・波及 | Q48 (+ Q49 同時性) |
| R04 オーラ・地点効果 | Q54 |
| R05 介入と window 中終了 | Q50 (+ Q51 メタレベル) |
| R06 反撃反撃ループ | Q54 |
| R07 効果書き換え・発行連鎖 | Q52 (+ Q51) |
| R08 防御誘発スタック順 | Q54 |
| R09 公平の並列 | Q49 / Q54 |
| R10 入れ子操作フェーズ | Q53 |
| R11 蘇生・追加行動 | Q54 |
| R12 発行時修飾 | Q54 |

| id | status | 領域 |
|---|---|---|
| Q44 | DECIDED(user) | 状態代数: inv 双対ペアの宣言と共存規則 (相殺 = 符号付き 1 本) |
| Q45 | DECIDED(user) | event-line rate の modifier-stack (加算 + override) |
| Q46 | SETTLED(SEM §5.7) | 寿命の合成 — 新規 primitive 不要、acceptance 例 = EQM-121/128 |
| Q47 | DECIDED(user) | 関係グラフの first-class data model (評価 sweep / 直列縫合 / 離脱連動) |
| Q48 | DECIDED(user) | 波及 = 展開 (§6.4 2a、メタ/コスト停止) / 連鎖 = デコレータ型 wrapping (§5.7) |
| Q49 | DECIDED(user) | composite atomic bundle の前倒し (公平・波及の同時性) |
| Q50 | DECIDED(user) | window premature close (介入の標準効果) |
| Q51 | DECIDED(user) | メタレベルの形式化 (横断) |
| Q52 | DECIDED(user) | 効果パターン変換フック (多重適用可) と発行連鎖 provenance (event 側) |
| Q53 | DECIDED(user) | 入れ子操作フェーズのループ検出・解消 (+ フェーズ内 sub-checkpoint) |
| Q54 | SETTLED(acceptance) | 確認系 acceptance 束 (R04/R06/R08/R09/R11/R12) — EQM-128 所有 |

## Q44 — 状態代数: inv 双対ペアの宣言と共存規則 [DECIDED(user)]

問い: 状態型の対合 `inv` (欠損⇄虚飾・狭窄⇄透徹・束縛⇄奔放・鈍化⇄機敏) を EQM はどう表現するか。特に inv ペアが同一対象に共存した瞬間の意味論。

なぜ重要 (EBS 実需要): 付与・解除・効果の意味論が `inv` を通して系統的に反転する状態群が EBS スキルの基礎語彙。共存時の挙動が未定義だと golden trace が書けず、個別ゲーム固有の stack 機構として誤実装される危険がある (依頼 R01 注意書き)。

推奨: **ペア宣言 + 規則選択制**。EQM は inv ペアの宣言 (状態型レベル) と、共存時規則 **相殺** (counter 差し引き) / **排他** (付与時に dual を解除してから付与) / **共存** (実行時相互作用なし、authoring 系統性のみ) の 3 択を pair ごとの serializable data として持つ。stacking acceptance-defined の既決 (SEM §4.5) と整合し、EBS は各ペアで規則を選んで acceptance instance にする。相殺/排他の適用と結果は trace に記録する。

擦り合わせたい点 (設計タスクへ): 相殺の記録形 (counter line 2 本の差し引きか、符号付き 1 本か)。

user意見 (相談ラウンド2, 2026-07-05): ペア宣言 + 規則選択制で確定。

user意見 (相談ラウンド3, 2026-07-05): 相殺の記録形 = **符号付き counter line 1 本**で確定 (inv ペア = 1 軸の両方向、相殺は算術で自動成立)。→ SEM §5.7。

## Q45 — event-line rate の modifier-stack (suspension) [DECIDED(user)]

問い: 前進規則の一時差し替え (凍結の保存・停止、鈍化/機敏) を、重複適用・途中解除・snapshot 復元と整合する形でどう表現するか。現行の re-rate (SEM §4.6) は「現在 rate の上書き」のみで復帰値を持たない。

なぜ重要: 鈍化中に凍結 → 凍結が先に切れたら「鈍化の rate」へ戻る、のような重複が実需要に含まれる。復帰値をゲーム側管理にすると重複ケースの決定性保証が消費者任せになる。

推奨: **modifier-stack モデル**。event-line が base rate + 有効 modifier 集合 (寿命付き、serializable data) を持ち、実効 rate は変更のたびに決定的に再計算する。suspension = 寿命付き modifier (凍結 = override-to-0 種)。modifier の寿命は既存 invalidation 語彙 (expiry event §6.3 / counter) で束ねる。既存 re-rate は「base rate の書き換え」として残す。snapshot v2 へ modifier table を additive 追加。

擦り合わせたい点 (設計タスクへ): modifier 合成の語彙 (加算 / 乗算 / override) と同種重複時の決定的適用順 (付与順 = event 発行順を推奨)。

user意見 (相談ラウンド2, 2026-07-05): modifier-stack モデルで確定。

user意見 (相談ラウンド3, 2026-07-05): 合成語彙 = **加算 + override のみ**で確定 (乗算は整数分数 + 丸め規則の定義が前提のため需要待ちの additive 拡張)。実効 = override 有効なら付与順最新の override 値、なければ base + Σadd。→ SEM §4.8。

## Q46 — 寿命の合成の適用確認 [RECOMMENDED]

問い: スタック系 (欠損, 反撃反芻) とターン系 (鑑別, 運命改変) の 2 種の寿命、および「ターン経過で解除されない」現象を、既存の invalidation OR + counter event-line で書けるかの適用確認 (依頼種別 [確認])。

なぜ重要: R01 の第 3 要素。書けるなら新規 primitive 不要で、成果は acceptance 例のみ。

推奨: 既存語彙で表現可能の見込み — スタック系 = decremental counter line、ターン系 = ターン閾値の expiry event (§6.3)、現象 = ターン条件を宣言しない (解除は明示 invalidation のみ)。EBS スキル群から 3 種各 1 つを golden 化する。

user意見: 相談ラウンド2・3 で異議なし → SETTLED (新規 primitive 不要、SEM §5.7 に確定記述)。acceptance 例 (3 種各 1 golden) は EQM-121/128 が所有。

## Q47 — 関係グラフの first-class data model [RECOMMENDED]

問い: 月 (主) / 星 (従) の有向関係を EQM が直列化可能データとして管理する際の schema — 関係型宣言 (分類: 追跡/求心/公平 + 反転)、構造制約 (ツリー / ループ許容)、維持条件、解消時の結び直し規則 — をどう固定するか。

なぜ重要: R02。actor 間の永続的有向関係は現状消費者任せで、Q48 の波及展開・R09 の公平の入力になる。付与・解消・結び直し・反転の trace 記録が決定性の説明可能性を担う。

決定済み (相談ラウンド2, 2026-07-05): 維持条件 (視界系 NAMED_PREDICATE、ゲーム側供給 — 相談4既決) の評価タイミングは**関係型ごとに宣言した sweep** (既定 = primary tick の宣言閾値、ゲームの「T開始時」相当)。sweep rule registry (§4.7) の機構を流用する。

推奨: 関係 = `{id (決定的採番, §4.5 と同格), type, from_actor, to_actor}` の serializable table。関係型宣言 = `{name, 分類, 反転形, 構造制約 (tree / loop 許容), 維持条件 (EQConditionSpec), 解消時規則}`。結び直し「直列関係の間ならば隣り合う関係を結び直す」は解消時規則の宣言パターンとして持つ。trace record kind を追加 (relation_bound / relation_dissolved / relation_rebound / relation_inverted 相当)。snapshot v2 へ additive table。

擦り合わせたい点 (設計タスクへ): 結び直し規則の宣言語彙 (直列縫合以外の必要パターン)、関係グラフの actor lifecycle (§13 invalidate_actor) との連動。

user意見 (相談ラウンド2, 2026-07-05): 評価タイミングのみ確定。schema 詳細は設計タスクで詰める。

user意見 (相談ラウンド3, 2026-07-05): 結び直し語彙 = **直列縫合のみ** (enum {NONE, SERIAL_SUTURE}、additive 拡張余地)。actor 離脱 = **解消時規則を通して自動解消** (単純削除・ゲーム側委譲は不採用)。→ SEM §13.1。

## Q48 — 効果対象の展開規則 (連鎖・波及) [RECOMMENDED]

問い: 関係グラフを入力とする「効果対象の動的拡大」(鑑波の損害波及、泡撃の波及的付与、解明/転回の状態ラッピング連鎖) を解決 pipeline (§6.1) のどの段で評価するか。展開が再帰する場合 (関係ループ時) の停止規律。

なぜ重要: R03。評価段が曖昧だと「星へ損害 → 月にも同時」の同時性と trigger 発火順が実装ごとに変わる。

推奨: 展開は **pop 直後・effect 段の前** に runtime が関係グラフから決定的に計算し、展開済み target 集合を event view で effect handler へ渡す。展開順序 = 関係 id 昇順の幅優先。再帰は visited set (同一 actor は一度のみ) で停止。展開結果 (元 target → 展開列) は trace に記録。「同時」が原子性を要求するケースは Q49 の atomic bundle に載せる。

user意見 (相談ラウンド3, 2026-07-05): 段 (pop 直後・effect 前) と BFS 関係 id 昇順は承認。**修正**: 再帰の停止規律は visited set でなく**メタレベル/コストに従う** (§8 の meta-cost 語彙で bound)。また R03 の「連鎖」は展開と別機構の**デコレータ型** (状態が状態を包む状態合成) — §5.7 wrapping へ分離。→ SEM §6.4 2a / §5.7。

user意見 (repair 相談, 2026-07-05): (1) wrapper の語彙 = **標準 2 種で確定** (inv 反転 / 関係連鎖付与、EQM-129 で意味論を実装。未知 kind は不活性 data として acceptance 拡張余地)。(2) 展開の停止規律は EBS 側文書 `META_LEVEL_ASSIGNMENT.md` で**コスト単独と確定** — メタレベル (比較値) とメタコスト予算 (展開の深さ) は別系・統合しない。hop cost = acceptance 宣言 budget。現行実装 (rule 宣言 cost) が整合。

## Q49 — composite atomic bundle の前倒し [RECOMMENDED]

問い: SEM §7.1 staging で後段送りにした「composite = 原子的 bundle」実装を本 round に前倒しするか。

なぜ重要: R09 公平の確定回答 (依頼 相談3) は「同一 tick の composite として解決し、互いの結果を入力にしない。composite 解決後の個別 state トリガは通常 sweep で発火」— これは member 間で sweep を挟まない**原子的 bundle** そのもの。R03 の「同時に損害」も同型。ordering hook (EQM-115) だけでは member 間に sweep が入り、この意味論を満たせない。

推奨: 前倒しする。bundle = member effect を全て適用してから単一 sweep を実施する解決単位。member 順序は既存 hook (§7.1) → 発行順。trace は bundle id + member 列。§7 の core 保証 (atomicity / total order / serializability / trace 被覆) に沿う。

user意見 (相談ラウンド3, 2026-07-05): 前倒しを承認 (pipeline 一括承認の一部、異議なし)。→ SEM §7.2 (§7.1 staging の deferral 解除)。

## Q50 — window premature close (介入の標準効果) [DECIDED(user)]

問い: 迎撃等の介入が対象 window を中終了させる意味論。解決済み効果と未解決 pending の扱い、deadline close (§9/Q37) との関係。

なぜ重要: R05。移動 window の 2 歩目で迎撃が発動した場合の「残り 3 歩」の扱いが未定義だと、介入系スキル全般の golden が書けない。

推奨: **解決済み効果は維持、pending のみ打ち切り**。window の未解決 member/pending events を invalidation で一掃 (`closed_by` 記録) し、`window_closed(cause: intervention)` を emit する。deadline の既定 (draft rollback, Q37) とは**別意味論**として区別する — 介入の発動条件が「効果が起きた事実」に依存する (依頼 相談1: 解決され効果が起きた時) ため、起きた効果は巻き戻さない。終了回避 = Q51 のメタレベル比較 (介入側 ≥ window 側で close 成立)。

user意見 (相談ラウンド2, 2026-07-05): 解決済み維持・pending 打ち切りで確定。

## Q51 — メタレベルの形式化 (横断) [DECIDED(user)]

問い: R05 (window 中終了の回避可否) と R07 (操作連鎖上の target 調整幅) に共通するメタレベルの付与先・値域・比較規則・発行連鎖との関係。依頼文書が明示した継続相談点。

なぜ重要: R05/R07 両方の前提となる新しい横断概念。未形式化のまま個別実装すると二重定義になる。

決定 (相談ラウンド2, 2026-07-05):

1. **付与先 = スキル宣言の int** (EBS 解決仕様ブロック)。発行された event / 開いた window が実行時に値を運ぶ。未宣言 = 0。window nest 深度とは独立 (「深い = 強い」の混同を避ける)。
2. **値域 = 単一 int の全順序** (部分順序は不採用 — 「順序がつかない」ケース自体を消す)。**同値 = 介入成功** (介入側 meta ≥ 対象側 meta で介入が通る)。
3. **発行連鎖の各段が、その段を発行した操作 event の宣言メタレベルを保持する**。対戦術・反射の target 調整幅 = 自分とのレベル差が許す最遠段まで選択可 (具体則は Q52)。

user意見 (相談ラウンド2, 2026-07-05): 上記 3 点で確定。

補記 (2026-07-05): EBS 側の値付け方針が `godot-editable-battleskill-system/docs/design/META_LEVEL_ASSIGNMENT.md` (叩き台 v2) として起草された — メタクラス (構造的分類、既定値 0..4) とメタレベル (発行時注入の単一 int = 既定値 + ゲーム側補正) の二層。EQM は「発行時に与えられる単一 int」しか見ない本契約と矛盾しないことを確認済み。防御スタック消費順 (メタ昇順・同率付与順) 等の用途 3〜5 は EBS/ゲーム側規則が値を参照する使い方で、EQM は意味論を強制しない。

## Q52 — 効果パターン変換フックと発行連鎖メタデータ [RECOMMENDED]

問い: 対戦術 (対象イベントの効果のパターン変換 — 弱化反射 = 付与先差し替え、損害反転 = 損害→回復) の介入点を pipeline のどこに置くか。変換の決定的適用順序。発行連鎖メタデータ (操作 root … 中間操作者 … 直接発行者) を event / event-line のどちらに載せるか。

なぜ重要: R07。解決サイクル (§6.1) に effect 変換の介入点がなく、発行連鎖の記録もない。

決定済み (Q51-3): 連鎖各段がメタレベルを保持し、変換後 target の選択幅 = レベル差で届く最遠段。

推奨: (1) 変換フックは **pop 後・effect 段の前** (Q48 の展開と同段; 適用順 = 展開 → 変換。変換どうしはメタレベル降順 → priority → sequence)。変換パターン (target 差し替え / 効果写像) は data 宣言 + named registry (§5.5 と同一機構)。適用は trace に記録。(2) 発行連鎖は **event 側の provenance メタデータ**に載せる — event-line は進行入力であり、出所記録を持たせると三面分離 (§2.1) を破るため、依頼中のユーザー示唆「event-line のメタデータ拡張」は不採用を推奨。連鎖 = `[{actor, event_id, meta_level}]` の列で、操作 event が発行する event へ自動継承・追記する。

擦り合わせたい点: 変換フックの多重適用 (変換の変換) を許すか、1 event 1 パスに制限するか (推奨: 1 パス。再帰は race/優先度で表現)。

user意見 (相談ラウンド3, 2026-07-05): 載せ場所 = **event 側 provenance で確定** (event-line 拡張は三面分離を理由に不採用 — 承認)。多重適用は**許可** (1 パス制限は不採用) — 適用構造は開発者がスキル効果グラフで選択的に計画できる data とし、意味論的 **validation は EBS 側の機能に寄せる**。EQM は決定的順序 + 適用ごとの trace + 有界 round の安全弁のみ。変換は event の**パラメータごとの型** — 対戦術 = 効果の対象先の変換、反転系 = 状態代数 (inv) における変換 — として整理し、他パラメータの変換型も同じ枠で追加可能。→ SEM §6.4 2b / §6.5。

## Q53 — 入れ子操作フェーズのループ検出・解消 [DECIDED(user)]

問い: OPERATION 系の深い入れ子 (共鳴の 4 段階操作解決、鏡面/水鏡の再帰的追加入力フェーズ) で操作フェーズ遷移がループしたときの検出と解消。

なぜ重要: R10。window nesting (§8) に再帰フェーズのループ検出・巻き戻し意味論がない。

推奨: 操作フェーズ = window の再帰として定義。フェーズ遷移履歴上の同一フェーズ再訪でループを検出し、**ループ開始点へ巻き戻す** — EQTransaction working-copy をフェーズ単位 checkpoint として使い、最小 cycle 上の全鏡面の入力を解除した状態で再開する。巻き戻し範囲と解除対象は trace に記録。

擦り合わせたい点 (設計タスクへ): フェーズ checkpoint の粒度 (window open ごとで足りるか)、解除後の再入力 UX (ゲーム側責務)。

user意見 (相談ラウンド2, 2026-07-05): 巻き戻し + 入力解除方式で確定 (前進遷移方式は不採用)。

user意見 (相談ラウンド3, 2026-07-05): checkpoint 粒度は window draft (§8.1) だけでは足りず、**フェーズ内 sub-checkpoint も必要** (1 つの OPERATION window 内で多段フェーズ遷移が起こる設計 — 共鳴の 4 段階等 — を想定)。→ SEM §8.4。

## Q54 — 確認系 acceptance 束 (R04/R06/R08/R09/R11/R12) [RECOMMENDED]

問い: 依頼の [確認] 項目群 — 既存機能で表現可能かの適用確認。成果 = applicative case / golden trace であり、新規設計は伴わない見込み。

内訳と見込み:

- **R04 オーラ・地点効果**: 「空間述語つき反応準備」の標準形 (ゲーム側 NAMED_PREDICATE + EQM 反応準備の合成) を applicative case 化。寸断 (トリガ抑制) が invalidation 条件で書けるかの確認を含む。
- **R06 相互反撃ループ**: 資源述語 (焦点コスト/HP) の閉包で必ず停止する golden。reentrancy は Q21/Q32 既決。
- **R08 防御誘発スタック順**: comparator hook (§7.1) の適用例のみ (スタック実体は完全にゲーム側 — 依頼 相談5 確定)。
- **R09 公平**: composite (Q49) + 事後の個別反射誘発の golden (依頼 相談3 確定)。視界条件の非対称を含む。
- **R11 蘇生・追加行動**: `ready_reservation_for` による政策外ターン付与 + 「invalidate → issue が同一 sweep 内で原子的に見える」ことの確認。
- **R12 発行時修飾** (枯渇反動/束縛/荷重): EQM 変更不要 (発行前にゲーム側で修飾) の確認記録のみ。

user意見: 設計 fork なし (確認系) → SETTLED。acceptance 束は EQM-128 が所有 (SEM §16.2)。R09 は Q49 の bundle に依存。

user意見: 承認。