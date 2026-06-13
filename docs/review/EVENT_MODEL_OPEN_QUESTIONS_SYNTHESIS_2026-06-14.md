# Event Model Open Questions — Synthesis 2026-06-14

Mode: synthesis (design-gap consolidation, EQM-014 着手前)
Input: `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md` (Q01-Q15, ユーザー追記済み), `docs/review/ROADMAP_GAP_EVALUATION_2026-06-13.md`
Output: 本 report (candidate 一覧)。EQM-014 / roadmap への反映はユーザー判断後に行う (前回 §5/§6 と同じ二段階フロー)。

---

## 1. 総括

Q03-Q15 のうち user 意見が付いた項目 (Q04, Q05, Q06, Q07, Q09, Q11, Q13) は、個別に読むと粒度の異なる懸念に見えるが、突き合わせると共通の根が 1 つに収束する。

> 現行 RECOMMENDED 群は「単一 global tick + lazy/eager invalidation」を進行・終了・順序判定の唯一の軸として前提している。しかしユーザーの行動解決ターン制要件 (entity 別 WT/CT 進行、反応回数による close、composite 解決時の entity 別進行値比較) は、acceptance 側が定義する複数の「進行指標」を進行・終了・順序の軸として使うことを要求する。

Q07 second-discussion で提示された **"event-line"** が、この欠落 primitive の名称になる。これを軸に Q04/05/06/07/09/11/13 を再分類すると、不足点は実質 **2 つの設計判断 (Cluster A / B)** に縮約できる。残りは Cluster 確定後に再評価すれば自然に決まる narrow 項目である。

重要: event-line は Phase4 (Energy/Wait Turn) 専用の拡張ではない。行動解決ターン制の核である「予約準備」(解決時間=3 = AP が 3 回復するまで) は entity 固有の AP 回復という進行指標そのものであり、**v1 のコア概念**に該当する。したがって Cluster A は EQM-014 (Phase2 API freeze 前段) のスコープ判断として扱う必要がある。

---

## 2. クラスタリング表

| Q | 既存 status | 本 report での扱い |
|---|---|---|
| Q04 | RECOMMENDED | Cluster B (確認質問 → comparator hook で回答) |
| Q05 | RECOMMENDED | Cluster A (eager の責務の一部) + narrow 残項目 |
| Q06 | RECOMMENDED | Cluster A (close 条件の複数化) |
| Q07 | RECOMMENDED | Cluster A (event-line 本体の提案元) |
| Q08 | RECOMMENDED | 影響なし。確定のまま。 |
| Q09 | RECOMMENDED | Cluster B (acceptance 側上位順序 + trigger nesting narrow 項目) |
| Q10 | OPEN | 影響なし。確定のまま。 |
| Q11 | RECOMMENDED | Cluster B (composite 内 effect 順序での float 許容範囲) |
| Q12 | RECOMMENDED | 影響なし。確定のまま。 |
| Q13 | RECOMMENDED | Cluster A (timeline 単一性の再定義) |
| Q14 | OPEN | 影響なし。確定のまま。 |
| Q15 | OPEN | 影響なし。確定のまま。 |

---

## 3. Cluster A — 進行指標の複数化 (event-line primitive)

対象: Q05 (一部), Q06, Q07, Q13

### 3.1 何が欠けているか

- Q07: TO の WT / FFT の CT は entity 固有の蓄積/消費パラメータで進行する。global tick の書き換え (Q07 推奨で禁止済み) ではなく、「毎 tick、WT/CT 条件を満たした entity に行動ターン予約 event を追加する」という incremental な進行軸が必要。さらに、この進行軸は acceptance 側が任意個数定義でき、event 側から新しい進行軸を発行できる必要がある。
- Q06: 反応準備の close 条件は「持続時間 (tick) 切れ」だけでなく「反応回数を消費し切った」でもよい。後者は tick 非依存の close 条件であり、deadline=∞ を許容する必要がある。
- Q05 (third-discussion): 「効果回数制限つき状態変化」のように、eager (trigger 発火) と tick 進行の **どちらか先に条件を満たした時点で消滅する** event を表現したい。これは現行の「lazy 判定 vs eager cascade」の二分法には収まらない。
- Q13: 「1 EQManager = 1 timeline」の "timeline" が global tick だけを指すのか、acceptance 側が追加する進行軸も含むのかで、4X 並行戦域要件への答えが変わる。

### 3.2 統合提案: event-line + close condition declaration

- **event-line**: 「ある単位 (entity / party / global / acceptance 定義の任意グループ) に紐づく、整数の進行値」。global tick は "primary event-line" として特別扱いされる 1 インスタンスとみなす。
- 各 reservation/event は **close condition** を 1 つ以上宣言できる。条件は `(event-line, threshold, 比較演算)` の組、または trigger (Q05 の eager) のいずれか。複数条件は OR として評価する (先に満たした条件で close、trace に `closed_by: <condition id>` を記録)。
- "予約準備" (解決時間=3) は `event-line = AP_recovery(self), threshold = +3` という close condition の具体例として表現できる。WT/CT も同様に entity 固有 event-line の close condition として表現できる。
- Q06 の反応回数 close は `event-line = reaction_count(self), threshold = 0, 比較 = <=` として表現でき、tick 側の close condition を持たなければ deadline=∞ と等価になる。
- Q05 third-discussion の「eager か tick かどちらか先に切れたら消滅」は、まさに OR 条件の標準形として回収される。Q05 の lazy/eager 二分法自体は変更不要 — eager は「trigger 型 close condition」として既存の trigger 機構に乗る。
- Q13 は「1 EQManager = 1 primary event-line (global tick) + acceptance 定義の N 個の追加 event-line」と再定義する。4X 並行戦域は「複数 manager」ではなく「複数 event-line + 共有 primary tick」で写像できる可能性が高く、coverage matrix で検証可能。

### 3.3 方針候補

**Option A1 (推奨)**: event-line を EQM-014 のスコープに正式に含める。Phase1 の `EQEntry` / ordering 契約に close condition の最小フィールド (`close_conditions: Array`, 各要素は `{kind: tick|event_line|trigger, ...}`) を予約する。実装の本体 (event-line backend, AP 連動など) は Phase4/5 に回せるが、契約・schema・trace record kind (`event_line_advanced` 等) は Phase1/2 で確定させないと、Phase5 の Reservation schema が後方互換破壊なしに拡張できない。

**Option A2**: v1 では event-line を見送り、global tick のみ。WT/CT は「WT 残量から `due_tick` を逆算する」退化系で Phase4 に押し込み、Q06/Q07/Q13 は OPEN のまま roadmap 注記に留める。リスク: 行動解決ターン制の核である「予約準備」(AP 回復ベース) がこの退化系に収まるか不明であり、Phase5 で再設計コストが発生する可能性が高い。

**Option A3**: event-line を EQM-014 から分離し、新規 task (例: EQM-015, dependency: EQM-013, blocks: EQM-020) として Phase2 内に追加する。EQM-014 の coverage matrix では WT/CT/反応回数 close を「EQM-015 待ち」と明記し、Phase2 API freeze は EQM-014 + EQM-015 の両方の完了を条件とする。

推奨順位: **A1 > A3 > A2**。A1 と A3 の差は「同一 task か別 task か」のみで、設計判断としては同じ。task サイズが `docs/devflow/policy/IMPLEMENTATION_QUEUE_DESIGN_POLICY.md` の想定を超える場合は A3 を選ぶ。

ユーザー意見:推奨案で進める。ただ、`event_line_advanced`という命名は何を指してるのかわからないので好ましくない。いい名前ではないかもしれないが、`event_line_evangelion`とか、パッとする名前にしましょう。

---

## 4. Cluster B — composite 解決時の acceptance 側順序定義

対象: Q04, Q09, Q11

### 4.1 何が欠けているか

- Q04: 「同時」を表す composite event の **内部** でどう解決するかは event 分類ごとに acceptance 側が定義する、という理解で合っているか (確認)。
- Q09 (first): 合っているが、acceptance 側がより上位の順序を定義できる API が必要。例: TO の WT 値解消が複数 entity 同時の composite event 解決のとき、ベース WT 値が低い方を先に行動順とする。
- Q09 (second): trigger 適用中にさらに別の trigger / event が反応する **trigger nesting** の可能性があり、解決判定 (Q05 の collection window, Q02 の nesting budget) との整合が必要。
- Q11: EQM core の ordering key に float は関与しないという原則は維持しつつ、composite 内の **effect 順序** (acceptance 側定義) には float を許容したい (例: WT 値そのものは float かもしれない)。

### 4.2 統合提案: acceptance comparator hook + nesting の Q02 拡張

- composite event の **どれが次か** は EQM core が tick/priority/sequence (すべて int, Q11 の原則どおり) で決定する。これは不変。
- composite event の **内部の effect/target 順序** は acceptance 側が供する `comparator` (Resource/Callable) に委譲する。comparator の入力には event-line 値 (Cluster A) や float を含む任意の state 参照を許可する — ただしこれは EQM core ordering とは別レイヤーであることを `EVENT_MODEL_SEMANTICS.md` で明記する (Q11 の「float は ordering に関与しない」は **core ordering key** に限定したスコープ宣言として再記述)。
- Q04 の確認には **Yes** で回答できる。ただし「acceptance 側定義に委ねる」だけでは API が無いため、上記 comparator hook の追加が回答の実体になる。
- Q09 (second) の trigger nesting は、Q02 で確定した「meta level/cost による well-founded order」を **trigger nesting にも同じ機構として適用できるか** を検証する narrow 項目として EQM-061/062 に記録する (詳細は §5)。

### 4.3 方針候補

**Option B1 (推奨)**: 上記 comparator hook を Q09 の回答として EQM-014 に明記する。Reservation schema (Phase5, EQM-050) の comparator フィールドは EQM-014 で契約のみ予約。

**Option B2**: composite event を複数の通常 event に分解し、acceptance 側が動的 priority を計算して全順序に挿入する。「同時」の概念が Q04 の前提 (全順序を維持しつつ同時性は composite で表現) と矛盾するため非推奨。Q04 の既存推奨と整合しない。

推奨: **B1**。

ユーザー意見: 推奨案で進める。 event-line 同時性はゲーム進行上の処理チャンク境界として acceptance の特徴, invariant を大きな枠組みで明確にする可能性がある。

---

## 5. 残る narrow 項目 (Cluster 確定後に再評価)

| 項目 | 内容 | 再評価条件 |
|---|---|---|
| Q05 残部 | lazy 判定 + `invalid_event_skipped` の基本方針自体は維持。Cluster A の close condition (OR) 導入後、「eager 無効化」が trigger 型 close condition で完全に回収されるかを再確認する。 | Cluster A (A1/A3) 確定後 |
| Q09 (second) | trigger nesting の評価順序。Q02 の meta-cost/budget を trigger nesting (window を開かない反応連鎖) にも適用できるか。EQM-062 の cycle guard との重複/分担を整理する。 | Cluster B (B1) 確定後、EQM-061/062 設計時 |
| Q13 残部 | 4X 並行戦域要件が「複数 event-line + 共有 primary tick」で実際に写像できるかは coverage matrix (EQM-014) での具体検証が必要。 | Cluster A (A1/A3) 確定後 |

---

## 6. roadmap / vocabulary への影響候補 (未反映)

- `docs/plan/2026-06-09_event_queue_manager/ROADMAP.md` §5 Vocabulary へ追加候補: `Event-line` / `Close condition` / `Composite resolution comparator`。
- EQM-014 acceptance への追加候補 (A1 採用時): 「close condition (tick / event-line / trigger, OR 結合) のフィールド契約、composite resolution comparator hook の契約を `EVENT_MODEL_SEMANTICS.md` に含める」。
- A3 採用時: 新task EQM-015 を Phase2 に追加し、EQM-020 の dependency を EQM-014 から EQM-015 へ変更。
- `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md` への追加候補: 新規 Q16 (event-line scoping, Cluster A の Option 選択) / Q17 (composite comparator hook, Cluster B の Option 選択)。Q07/Q13 は Q16 への pointer に置き換え、Q04/Q09/Q11 は Q17 への pointer に置き換える形で整理する。

---

## 7. ユーザーへの確認候補

1. Cluster A: Option A1 (EQM-014 スコープ内で契約のみ予約) / A3 (新task EQM-015 に分離) / A2 (見送り) のどれを採るか。
判断 -> A1
2. Cluster B: Option B1 (acceptance comparator hook) で Q04/Q09/Q11 をまとめて回答する方針でよいか。
判断 -> B1
3. "event-line" の命名は採用するか、別名にするか (vocabulary 確定のため)。
判断 -> "event-line" 採用
4. §5 の narrow 項目は Cluster 確定後の再評価に回してよいか (現時点で個別の決定は不要)。
判断 -> 回して良いが、いくつか意見を記載する。

### Q05 残部

close condition (OR) 導入はよい。ただし event の解決と失効は異なる概念として扱う。close condition (OR) の適用は event の失効を扱う。for-all 型の失効 AND 条件の term は decrimental に扱う入り口に回収すれば良い。
一方 event の肯定的解決... solve condition は AND で発行する。仮に OR 条件での実 game 需要時は、同一 effect の event-line を異なる解決条件でそれぞれ発行し、それらいずれかの解決を失効 OR 条件として一律に採用すれば OR 解決の event-line 発行を実現可能。ただし、同一効果 event-line の複数発行は、EQM向けのdebug表示と、実 game 開発向けの debug 表示及び、実 game 向けの presentation の適切な扱いをそれぞれ分離する必要があることに注意し、ゲーム開発者向けの出口管理設計に注意する。
これは RTS モデルに近い極大 entity および event-line 管理に関する grouped-event-line, micro-event-line 導入を見据えた設計だが、RTS acceptance は実装上は検討不要。 edge case 包摂性を利用した設計上の補助線としてのみ考慮する。

### Q09 (second)

meta-cost/budget を trigger nesting (window を開かない反応連鎖) にも適用してよい。
windoe nesting / trigger nesting が交差するケースでの cost 設計オプションの柔軟性にも注意する。

1. Q13 の「1 manager = 1 primary event-line + N acceptance-defined event-line」という再定義方向で coverage matrix 検証に進めてよいか。
判断 -> その定義で検証を進める。

---

## 8. 決定事項の反映 (2026-06-14 ユーザー回答)

- Cluster A: **A1** で確定。EQM-014 スコープ内で event-line 関連の契約 (フィールド・schema・trace record kind) を予約する。
- Cluster B: **B1** で確定。acceptance comparator hook を Q04/Q09/Q11 の回答として EQM-014 に明記する。
- 用語: **"event-line"** を vocabulary として正式採用する。
- trace record kind の命名 `event_line_advanced` は **不採用**。「advanced」は「進行した」と「高度な」のどちらにも読めて不明瞭。命名は §9 Q16 で再検討する。
- Q13: 「1 manager = 1 primary event-line + N acceptance-defined event-line」の定義で coverage matrix 検証に進める。

### 8.1 §3.2 の修正: solve condition (AND) と invalidation condition (OR) の分離

ユーザー指摘により、§3.2 の "close condition (OR)" は **2 つの異なる概念を 1 つに混ぜていた** ことが判明した。修正版モデル:

- **resolution (解決)**: event が本来の効果を発生させること。`solve_conditions` は **AND** で評価する (すべての条件が揃って初めて解決する)。
- **invalidation/失効 (expiry)**: event が解決されずに消える/無効化されること。`invalidation_conditions` (旧 close condition) は **OR** で評価する。Q05 の eager cascade、tick 持続時間切れ、Q06 の反応回数切れは、すべて invalidation 側の条件として整理する。

この分離により、Q05 の「lazy 判定 + eager」の区別は **invalidation_conditions の評価方法 (lazy=参照時 / eager=trigger即時)** という narrow な実装選択に縮小される。

### 8.2 OR 型 solve condition の表現パターン (race pattern)

solve_conditions が AND のみだと、「いずれかの条件が満たされたら解決」という OR 型の解決需要 (ユーザー: 実 game 需要時) を表現できない。ユーザー提案の解法:

> 同一 effect に対し、異なる solve_conditions を持つ event-line を複数発行する。いずれか 1 つが解決した時点で、残りの event-line を invalidation_conditions (OR) によって一律に失効させる。

これにより OR 型解決は「複数 event-line の race + 勝者以外を OR invalidation」という標準形に還元できる。

**新たな要請 (debug/presentation 分離)**: 同一 effect に対する複数 event-line の発行は、以下 3 種の表示を区別しなければ「同じ効果が複数回起きたように見える」混乱を生む。

1. EQM 内部 debug 表示 (race の全候補を見せる)
2. 実 game 開発者向け debug 表示 (race を「1 つの解決候補群」として要約)
3. 実 game 向け presentation (勝者のみを 1 回提示する)

これは Phase 8 (EQM-080/081, 効果・presentation pipeline) と Phase 9 (EQM-091, debug inspector) の両方に影響する設計要請であり、EQM-014 では **概念契約のみ** (race group をまとめる id、3 種表示の責務分離方針) を記録し、実装詳細は該当 phase に委ねる。

### 8.3 grouped-event-line / micro-event-line (将来拡張・補助線)

ユーザーは、上記 race pattern が RTS 規模の極大 entity 数・event-line 数を扱う "grouped-event-line" / "micro-event-line" 概念への入口になり得ると指摘した。ただし:

- v1 (本 roadmap の対象ジャンル群) では RTS acceptance は不要であり、**実装は検討しない**。
- これは「edge case を包摂できる設計になっているか」を確認するための **補助線** としてのみ扱う — つまり、§8.1/8.2 のモデルが grouped/micro-event-line を後付けできる形であれば十分で、それ自体を今 設計・実装する必要はない。

`docs/design/EVENT_MODEL_OPEN_QUESTIONS.md` には OPEN/deferred として 1 行記録する程度に留める (Q15 の replay 同様の扱い)。

### 8.4 Q09 (second) の追記反映

meta-cost/budget (Q02) は trigger nesting にも適用してよい、と回答された。追加の注意点: **window nesting と trigger nesting が交差するケース** での cost 設計オプションの柔軟性。具体的には、ある反応連鎖が「window を開く trigger」と「window を開かない trigger」を混在させる場合、budget を共有 (同一 cost 計算に統合) するか分離 (window 用 budget と trigger-nesting 用 budget を独立に持つ) するかが未決。EQM-061/062 設計時の narrow 項目として記録する。

### 8.5 §4.3 追記の反映: event-line 同時性 = 処理チャンク境界

ユーザーは、event-line の「同時性」(複数 entity が同一 event-line の同一 threshold に到達する) を、composite resolution の枠を超えて **「ゲーム進行上の処理チャンク境界」** という大きな acceptance 側 invariant の枠組みとして捉えられる可能性を指摘した。

これは Cluster B の comparator hook (composite **内部**の順序付け) よりも上位の概念で、以下を統一的に説明できる可能性がある:

- Q04/Q09 の composite resolution 境界
- Q12 (感知分類) の flush barrier 境界 (Phase 8)
- §8.1 の AND solve_conditions が「複数 event-line が同時に閾値へ到達した」状態の特殊ケースである

EQM-014 でこの一般化を正式な named concept ("resolution chunk" / "sync barrier" 等、命名は要検討) として `EVENT_MODEL_SEMANTICS.md` に含めるかどうかは、§9 Q21 として候補化する。

---

## 9. 派生する設計点候補 (Round 2)

### Q16 — trace record kind の命名

`event_line_advanced` は不採用。候補:

- `event_line_progressed` — 「進行した」を明示。`window_opened`/`window_closed` と同じ過去分詞形で既存 trace 命名規則と整合。
- `event_line_stepped` — incremental な一歩を強調。
- `event_line_updated` — 汎用的だが「進行」のニュアンスが弱い。

推奨: `event_line_progressed` (既存命名規則との整合性、意味の明確さを優先)。

判断 -> 推奨案で進める。

### Q17 — solve condition (AND) / invalidation condition (OR) の分離を EQM-014 acceptance に明記するか

§8.1 のモデル修正を EQM-014 の正式な設計判断として記録する。Q05 の status は `DECIDED(user)` の narrow 版 (invalidation_conditions の評価方法のみ残る) に更新する。

判断 -> そのようにしてください。

### Q18 — race pattern + 3 種表示分離の概念契約を EQM-014 に含めるか

§8.2 の「race group id」「3 種表示の責務分離方針」を `EVENT_MODEL_SEMANTICS.md` の概念契約として記録するか、Phase 8/9 の該当 task (EQM-080/081/091) acceptance への追記候補として先送りするか。

判断 -> 概念契約に含めます。

### Q19 — grouped-event-line / micro-event-line を OPEN item として記録するか

`docs/design/EVENT_MODEL_OPEN_QUESTIONS.md` に deferred (RTS 向け補助線) として 1 行追加するのみで良いか。

判断 -> deferred とする。

### Q20 — window nesting / trigger nesting 交差時の budget 共有・分離

EQM-061/062 設計時の narrow 項目として記録するのみで良いか、または EQM-014 で「budget は entity 単位で共有 (default) / acceptance 側で分離可能」という方向性だけ先に宣言するか。

判断 -> EQM-061/062 設計時の narrow 項目とする。

### Q21 — event-line 同時性 = 処理チャンク境界 (sync barrier) の一般化

§8.5 の一般化を `EVENT_MODEL_SEMANTICS.md` に named concept として含めるか。含める場合、命名候補: `resolution_chunk` / `sync_barrier` / `event_line_barrier`。

判断 -> 含めない。 event-line 同時の際は sync barrier の一例となる可能性が高いが、その全てとは言えないため。とはいえ acceptance 側 game 開発 においては sync barrier 設計の必要があり、EQMとしてもそれを支援することは課題である。

---

このRound 2 候補への判断が揃った時点で、`docs/design/EVENT_MODEL_OPEN_QUESTIONS.md` の Q16/Q17 (Round1 §6 で予告した event-line scoping / composite comparator) に加えて Q18-Q21 相当の項目を統合し、EQM-014 の acceptance 文言案を次の report で提示する。

