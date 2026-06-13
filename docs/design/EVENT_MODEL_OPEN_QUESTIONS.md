# Event Model Open Questions

目的: event model スケールの設計未決点を一覧化し、EQM-014 (EVENT_MODEL_SEMANTICS.md) の入力にする。各項目は semantics 確定時に adopted/rejected を記録し、本 file の項目は決定への pointer に置き換える。

status:

- `DECIDED(user)` — ユーザー決定済み。検証条件つきで semantics に確定する。
- `RECOMMENDED` — agent 推奨あり。採否は EQM-014 で確定。
- `OPEN` — 推奨方向のみ。ユーザー判断が望ましい。

| id | status | 領域 |
|---|---|---|
| Q01 | DECIDED(user) | save 境界 |
| Q02 | DECIDED(user) | window nesting 制約 |
| Q03 | RECOMMENDED | window deadline (ATB) |
| Q04 | RECOMMENDED | 同時性 / batch 解決 |
| Q05 | RECOMMENDED | 予約の無効化 |
| Q06 | RECOMMENDED | 持続時間切れの event 化 |
| Q07 | RECOMMENDED | 遡及的時間変更 (haste/slow) |
| Q08 | RECOMMENDED | priority の不変性 |
| Q09 | RECOMMENDED | event 内 effect 順序と trigger 収集 |
| Q10 | OPEN | actor lifecycle |
| Q11 | RECOMMENDED | 数値域 |
| Q12 | RECOMMENDED | 感知分類の所属側 |
| Q13 | RECOMMENDED | timeline の単一性 |
| Q14 | OPEN | 反芻の経済 |
| Q15 | OPEN | replay の製品化 |

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

## Q04 — 同時性 / batch 解決 [RECOMMENDED]

問い: 厳密全順序のみか、「同時」に解決すべき event 群 (WeGo 同時手番、相打ち、同時 KO) を表す primitive を持つか。

推奨: core は全順序を維持し、同時性は composite event (複数 effect を単一解決として束ねる) で表現する。全順序を崩す並行解決は導入しない。

影響: EQM-014, EQM-050, EQM-080。

## Q05 — 予約の無効化 [RECOMMENDED]

問い: owner 死亡 / target 消滅 / 前提崩れの判定タイミング — lazy (解決時に validity predicate 評価) か eager (状態変化時に cascade cancel) か。連鎖 cancel と trace への現れ方。

推奨: lazy 判定 + `invalid_event_skipped` の trace record を標準とする。eager な無効化が必要な game 規則は trigger (反応) として表現する。

影響: EQM-011, EQM-051, EQM-061。

## Q06 — 持続時間切れの event 化 [RECOMMENDED]

問い: 反応準備等の duration expiry は event として timeline に乗るか、参照時に lazy 判定か。

推奨: event 化する。trace に可視になり、on-expiry trigger が定義可能で、決定性検証が単純になる。

影響: EQM-061。

## Q07 — 遡及的時間変更 [RECOMMENDED]

問い: haste / slow / time-stop が既存予約の due_tick を直接書き換えることを許すか (TO の wait 再計算問題)。

推奨: 直接書き換え禁止。変更は reschedule (cancel + push, generation bump) のみとし、再計算規則は policy が所有する。queue backend の不変条件が単純に保たれる。

影響: EQM-011, EQM-041。

## Q08 — priority の不変性 [RECOMMENDED]

問い: ordering key の priority は entry 生成後に可変か。

推奨: 不変。変更は reschedule 経由のみ。heap/sorted backend の不変条件と trace の説明可能性を守る。

影響: EQM-010/011。

## Q09 — event 内 effect 順序と trigger 収集 [RECOMMENDED]

問い: 1 event が複数 effect を持つ場合 (AoE) の対象順序と、effect 適用中に発火条件を満たした trigger の扱い。

推奨: 解決単位は atomic とし、対象順序は deterministic な default (target id 順) + adapter による明示順 (空間順等)。trigger は適用中に interleave せず、解決完了後の collection window でまとめて arm / 発火評価する。

影響: EQM-051, EQM-061, EQM-080。

## Q10 — actor lifecycle [OPEN]

問い: 戦闘中の参加 (召喚・増援) / 離脱 / 死亡時に、pending 予約・round membership・反応準備をどう処理するか。actor_id の再利用を許すか。

推奨方向: actor_id 再利用禁止 (save/load と trace の同一性保証)。離脱時の pending は Q05 の invalidation 経路で処理。round membership 更新は policy 所有。

影響: EQM-021, EQM-030, EQM-090。

## Q11 — 数値域 [RECOMMENDED]

問い: tick / AP / meta cost / priority の数値域と溢れ・負値規則。

推奨: すべて int (tick は int64 前提を宣言)。負 AP の可否は policy 宣言制、上限超過は安定 error。float は ordering に一切関与しない (既存原則の数値域への具体化)。

影響: EQM-010, EQM-020。

## Q12 — 感知分類の所属側 [RECOMMENDED]

問い: 感知範囲 / 可視性の分類 (important / sensed / offscreen) は simulation 側の deterministic data か、presentation 側の判断か。

推奨: simulation 側の deterministic data とし trace に含める。flush barrier 判断が依存するため、presentation 側に置くと presentation neutrality property (flush policy を変えても simulation trace 不変) が検証不能になる。見せ方の良否のみ presentation 側。

影響: EQM-080/081/082。

## Q13 — timeline の単一性 [RECOMMENDED]

問い: 1 つの EQManager に複数 timeline (4X の並行戦域等) を持たせるか。

推奨: 1 EQManager = 1 timeline を宣言し、複数 instance 間の同期は v1 scope 外とする。coverage matrix の 4X 行は単一 timeline での写像可能性を確認する。

影響: EQM-014, EQM-032。

## Q14 — 反芻の経済 [OPEN]

問い: 予約反芻による再予約時に AP を再徴収するか。解決時間 / due の再計算規則はどうするか。(ユーザー設計の "反撃準備" 予約反芻=1 は再徴収なしと読める。)

推奨方向: 再徴収なしを default とし、policy hook で変更可能にする。

影響: EQM-050, EQM-062。

## Q15 — replay の製品化 [OPEN]

問い: canonical trace を使った in-game replay / 戦闘 log UI を product 機能にするか。

推奨方向: v1 では defer。trace format が既に互換資産なので後付け可能。roadmap 改訂時に再検討。

影響: roadmap。
