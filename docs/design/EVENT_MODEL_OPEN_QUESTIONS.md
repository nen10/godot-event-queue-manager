# Event Model Open Questions

目的: event model スケールの設計未決点を一覧化し、EQM-014 (EVENT_MODEL_SEMANTICS.md) の入力にする。各項目は semantics 確定時に adopted/rejected を記録し、本 file の項目は決定への pointer に置き換える。

status:

- `SETTLED` — ユーザー合意済み。EQM-014 で確定記述する。
- `DECIDED(user)` — ユーザー決定済み。検証条件つきで確定する。
- `PIVOT` — core data model を動かす論点。他項目を従える。
- `CLUSTERED` — PIVOT(進行モデル)に従属。単独では確定しない。
- `RECOMMENDED` / `OPEN` — agent 推奨あり / ユーザー判断待ち。
- `META` — 原則確認。

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
| Q16 | PIVOT | event-line 導入 |
| Q17 | OPEN | event-line 前進方式と決定性 |
| Q18 | OPEN | 多条件 解決 / 失効 (OR/AND, on-expiry) |
| Q19 | OPEN | eager の責務分割 |
| Q20 | OPEN | 同時解決 / 上位順序の拡張点 |
| Q21 | OPEN | reentrancy 統一 (window nest / trigger nest) |
| Q22 | OPEN | event-line × snapshot / actor lifecycle |
| Q23 | META | 過剰一般化のガードレール |

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



## Q18 — 多条件の解決 / 失効 (OR/AND, on-expiry) [OPEN]

問い: 1 event/reservation が複数 event-line・reaction-count・predicate にまたがる「解決条件」「失効条件」を持てるか。組合せは OR か AND か両方か。失効時の on-expiry effect を持つか。

なぜ重要: 「3回 or 5ターンで消える buff」「eager と global tick のどちらか切れたら消滅」「反応回数で close(deadline=∞ 可)」を統一表現する(Q05/Q06/Q14 を吸収)。

推奨: 解決条件・失効条件をそれぞれ「event-line 閾値 / reaction-count / predicate」の集合とし、既定 OR、AND は明示宣言。on-expiry effect を optional に持つ。条件成立・失効はすべて trace に記録する。

擦り合わせたい点: AND 条件(全条件成立で初めて解決/失効)の実 game 需要があるか。なければ v1 は OR のみにして複雑性を抑えたい。

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

## Q23 — 過剰一般化のガードレール [META]

問い: event-line 一般化は、自分で定めた UX_PATH_REDUCTION_POLICY(過剰一般化=負価値)と矛盾しないか。

整理: 矛盾しない。一般化するのは「進行・条件の substrate(core data model)」であり「user-facing 入口の入力クラス」ではない。両者は別物。ガードレール:
- (a) 全 event-line kind は serializable。
- (b) 前進は deterministic な定義点のみ。
- (c) reducibility test で既知系(CTB/energy/wait-turn/TO/FFT/ATB)が写像できることを常時 gate(EQM-053 を event-line へ拡張)。
- (d) arbitrary-predicate eager や generic picker のような「広い入口・完走非保証」は依然禁止。

擦り合わせたい点: なし(原則確認)。これに同意できれば event-line 導入と UX_PATH_REDUCTION は両立する。

user意見: 問題ありません
