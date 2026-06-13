# Roadmap Gap Evaluation 2026-06-13

Mode: evaluate (roadmap-autopilot)
Inputs: `docs/plan/2026-06-09_event_queue_manager/ROADMAP.md` / `IMPLEMENTATION_QUEUE.md`, devflow policy 群, ユーザー設計質問 (turn-as-phase-event, 適用例の固定化)。
Output: 本 report + queue 反映済み task (EQM-014, EQM-035) + 未反映 candidate 一覧。

---

## 1. 検討: 行動ターンを「event 追加 phase を引き起こす event」として管理する

### 判断: adopt 推奨 (確定は EQM-014 の semantics 決定で行う)

行動ターン = 「解決時に insertion window (phase) を開く event」というモデルは、既存原則 (Event-first / Actor turn は event の一種) の自然な精緻化であり、以下を統一する:

- 行動解決ターン制: "予約準備" 解決 -> turn 獲得 = window open。"待機" 解決 = window close + ready reservation 予約。ユーザー設計と完全に同型。
- player turn transaction (Phase 7): turn window = draft transaction の寿命。window open が draft を開き、close が commit する。Phase 5/7 の概念が 1 つになる。
- 反応準備 (Phase 6): trigger 発火 = micro window open。同時発火の解決順は「window 内挿入規則」として定義できる。
- 4X phase / stack 解決: phase・priority window も同じ primitive の応用になる。

discrete event simulation では「event handler が新 event を enqueue する」のは標準形であり、ここでの新規性は **reentrancy 境界** (window open 中は global tick が凍結し、挿入権が特定 entity に付与される) を明示することにある。

### 決めるべき設計点 (EQM-014 で記録する)

1. window 内で解決される即時行動は global timeline に乗るのか、window-local 順序を持つのか (二層時間モデルの明示)。comparator は単純に保ち、window は scheduler state として表現する案を推奨。
2. trace への反映: record kind に `window_opened` / `window_closed` を追加し、golden trace で window 構造ごと決定性を証明する。
3. window open 中の snapshot/save 可否 (mid-turn save 問題)。 -> base-operator window となる nest level を save 可能な nest level の上限とする。(base-operator となる nest lebel は 各 acceptance 側の game model において管理される)
4. nesting: 操作行動が他 entity の window を開く場合の深さ上限と cycle guard。 -> cycle guardは不要だが、操作行動の可否を制限する "meta level/cost" paramater を operator について参照して nesting に制約を与える。ただし、各 acceptance 側の game model において required "meta level/cost" を表現する nest level に応じた 単調増加な関数 を定義して基準とする。このとき、定義した単調増加な関数は一つの基準であり、各 acceptance 側の実際の game ルールの実装上では、他entityの抵抗値などの未確定の変数を含んだ判定を含む形式で実際の nesting 可否に使用することも想定される。

### 設計点 3 / 4 の検証 (2026-06-13, agent)

**設計点 3 (save 上限 = base-operator window の nest level): 原理上成立。**
「save 可能点 = 過渡的制御状態を schema が有限に表現できる quiescent boundary」という一般原則の具体化であり、base-operator level を acceptance 側 game model が定義することは policy 分離原則に合致する。深さが有界になることで save schema 側の open window stack 表現が有限になる — この規則自体が schema 単純化の根拠になる。成立条件:

- (a) **snapshot-for-save** と **snapshot-for-rollback/prediction** (任意深度・in-memory、Phase 7 が要求) を区別し、本制約は save path にのみ適用する。
- (b) save 時に open draft が残る場合の意味論を 1 つ選ぶ。推奨: draft を rollback して boundary 状態を保存 (rollback identity property と整合)。draft ごと serialize は schema 拡大として v1 では非推奨。
- (c) save schema は base level までの open window stack (挿入権、残 AP、armed reactions) を明示 serialize する。
- (d) 深い nest での save 試行は安定 error とし、`is_save_allowed()` 相当を core API に置く。

**設計点 4 (cycle guard 不要、meta level/cost による nesting 制約): 原理上成立。**
単調増加 cost + 有限 budget は well-founded order を与え、nesting chain の停止を保証する。成立条件:

- (a) 単調増加は**狭義**であること (int 域なら f(n) >= f(0) + n となり depth <= budget が直ちに出る)。広義単調、特に cost 0 の plateau は停止保証を失う。core は宣言形式 (table / parametric) の cost 関数について狭義性を validation し、custom callable は consumer 責任 + (d) の backstop 適用とする (任意 callable の単調性検証は不可能なため)。
- (b) chain 継続中 (祖先 window が open の間) は operator の meta budget が回復しないことを core invariant とする。回復を許す game 規則では (d) が唯一の停止保証になる。
- (c) 抵抗値等の未確定変数を含む可否判定は deterministic RNG stream から引き、判定内容 (paid cost, roll, 結果) を trace に記録する。explanation-as-data で「なぜ割り込めなかったか」を提示できること。
- (d) game rule とは別に engineering backstop (絶対 max depth + 安定 error) を core に置く。これは consumer 定義関数の誤りを explicit error にするためであり、game 設計への介入ではない。
- (e) 「cycle guard 不要」は **window nesting については正しい** (cost が well-founded order を与えるため)。ただし EQM-062 の cycle guard は別層 — 同一 tick 内の trigger / rumination 連鎖 (window を開かない反応 ping-pong) — を対象とするため存置する。cross-tick の予約 ping-pong は game 時間上の loop であり合法 (AP 経済が律速)。

両決定は `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md` に Q01 / Q02 (DECIDED) として登録し、EQM-014 が上記条件ごと semantics に確定する。

### Risk

「あらゆる event が window を開ける」と一般化すると無限再帰と理解不能 UX を招く。UX_PATH_REDUCTION に従い、window-opening は特定 event kind (turn grant / interrupt window) の明示 capability とし、汎用 capability にしない。

## 2. 検討: 適用ゲームシステム例の固定化 vs 汎用性

### 判断: 固定化する。ただし「API の特殊化」ではなく「acceptance の固定化」として行う

addon/library の典型的失敗は固定化ではなく過剰一般化であり、これは既に UX_PATH_REDUCTION_POLICY が負価値と定義した形 (入口が広く完走保証がない) と同型である。固定例は acceptance anchor (demo + golden trace) として固定し、core には genre 分岐を置かない。

ユーザーの直観どおり、行動解決ターン制は meta 次数が高い: CTB / wait-turn / energy は「即時行動のみ」「AP=1」「解決時間=0」等の退化ケースとして表現できる見込みが高い。core を reservation + trigger + window で最適化しても汎用性を失いにくい。

### 危険への安全機構 (機構で守る。感覚で守らない)

1. **Ordering model coverage matrix** (EQM-014): 既知の順序システム >= 8 種を model へ写像し、写像できない/不自然なケース (例: stack/LIFO 解決、同時手番 WeGo、ATB hybrid) を API freeze 前に検出する。
2. **Policy reducibility test** (EQM-030/031/040/041 acceptance への追加候補): 専用 policy の trace == 同じ系を reservation model で表現した trace。退化ケース性を test で証明し続けることで、「固定例への最適化が汎用 model を壊した」瞬間に検出できる。
3. demo / golden trace は per-genre に保持し、core 変更が全 genre trace を通過することを常時 gate とする。

reducibility test は未 queue 化。EQM-014 の Scheduled task として採否判断することを推奨。

## 3. Roadmap の根本的不足 (大局)

| id | gap | 重要度 | 処置 |
|---|---|---|---|
| G1 | **Event model 意味論仕様の不在**。vocabulary は意味論ではない。ordering key、tick 進行、window/reentrancy、同時 trigger 解決順、AP 会計が文書化されておらず、Phase 5/6/7 が互いに非互換な前提を導出する危険。 | 最高 | **EQM-014 として queue 追加済み** (Phase 2 API freeze の前段) |
| G2 | **モデル被覆の検証不在** (§2)。 | 高 | EQM-014 に同梱済み |
| G3 | **Game-loop driver / async 境界の契約不在**。誰が advance を呼ぶか、player input 待ちの suspend semantics、アニメーション await と resolution の関係。Phase 9 の「integration」に暗黙に埋まっている。 | 高 | candidate: Phase 9 produces へ明示追加 + EQM-032 acceptance 拡張 |
| G4 | **Snapshot schema versioning の不在**。snapshot は save data であり、ゲームは save を出荷する。pre-1.0 migration を defer するのは妥当だが、schema version field + 拒否規則は v0.x から必要。 | 高 | candidate: EQM-012 acceptance へ version field 追加、Phase 12 で compatibility stance 宣言 |
| G5 | **Public API surface gate の不在**。public/internal の命名規約、API surface の golden snapshot test (公開 API が無断で変わると fail)。agent 開発では特に有効。 | 中 | candidate: Phase 12 または EQM-020 で導入 |
| G6 | **Player-facing runtime timeline HUD の不在**。editor preview はあるが、引用ジャンルほぼ全てで必要になる in-game 行動順表示 (FFX 型 CTB list 等) が product に無い。projection-first 設計の自然な応用先。 | 中-高 | candidate: 新 phase (Phase 9 と 10 の間)。roadmap 改訂で判断 |
| G7 | **Dogfood milestone の不在**。demo は API friction を発見しない。実 consumer project (小さくてよい。行動解決ターン制 vertical slice が最適) を v0.5-0.7 帯に置く。 | 中-高 | candidate: milestone 表へ追加 |
| G8 | **評価 checkpoint の不在**。ROADMAP_POLICY は batch 後評価を求めるが queue に評価 task が無かった。 | 中 | **EQM-035 として queue 追加済み** (v0.1 後)。以後の milestone でも反復 |
| G9 | **Error taxonomy の不在**。安定 error code、回復可能性分類、game 内/editor での表面化規則。各 task が ad hoc に発明する危険。 | 中 | candidate: EQM-020 acceptance へ統合 |
| G10 | **性能予算が数値未定義**。"large battles" の目標値 (actor 数 / event 数 / tick 当たり予算) が無く、Phase 12 の benchmark が合否判定できない。 | 低-中 | candidate: EQM-102 の前に予算宣言を追加 |

## 4. 今回反映済み

- EQM-014 (semantics + coverage matrix) を Phase 1 に追加。EQM-020 の依存を EQM-014 へ変更。
- EQM-035 (v0.1 milestone evaluation) を Phase 3 末尾に追加。
- ROADMAP.md: Phase 2 / Phase 3 produces へ対応行を追加。
- CLAUDE.md (Claude Code 用入口) を追加。
- UI_LAYOUT_METRIC_TEST_POLICY.md §5.11 State display modality を追加 (state は icon/checkbox 等の非文字 modality 優先、boolean の text 表示は P0)。

## 5. candidate の task 化 (2026-06-13 ユーザー承認 -> 反映済み)

1. G3: EQM-032 acceptance へ driver 契約を統合。roadmap Phase 9 produces へ明示。
2. G4: EQM-012 acceptance へ `schema_version` + 安定 load error を追加。EQM-103 で compatibility stance 宣言。
3. G5: EQM-023 (public API surface snapshot gate) を Phase 2 末尾に追加。
4. G6: EQM-083 (runtime timeline HUD) を queue Phase 8b として追加。roadmap Phase 9 produces へ反映。
5. G7: EQM-084 (dogfood vertical slice) を追加。milestone v0.6 Dogfood Slice を新設。
6. G9: EQM-020 acceptance へ error taxonomy (`docs/design/ERROR_CONTRACT.md`) を統合。
7. G10: EQM-102 acceptance を「予算宣言 -> 予算に対する benchmark 判定」へ変更。roadmap Phase 12 へ反映。
8. reducibility: EQM-053 (policy reducibility proofs) を Phase 5 末尾に追加。

## 6. 第2回反映 (2026-06-13)

- 設計点 3/4 のユーザー編集を検証し、§1 に成立条件を記録した (原理上いずれも成立)。
- `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md` を新設: Q01/Q02 (ユーザー決定済み) + Q03-Q15 (event model スケールの未決点、推奨つき)。EQM-014 の acceptance がこの全項目の解決を要求する。
- §5 の全 candidate を queue / roadmap へ task 化した (上記)。
