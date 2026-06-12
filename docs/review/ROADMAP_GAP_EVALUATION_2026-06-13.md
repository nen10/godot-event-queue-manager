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
3. window open 中の snapshot/save 可否 (mid-turn save 問題)。
4. nesting: 操作行動が他 entity の window を開く場合の深さ上限と cycle guard。

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

## 5. 未反映 candidate (ユーザー採否待ち)

1. G3: game-loop driver 契約の Phase 9 明示化。
2. G4: snapshot schema version の EQM-012 acceptance 追加。
3. G5: public API surface golden test。
4. G6: runtime timeline HUD phase の新設。
5. G7: dogfood vertical slice milestone。
6. G9: error taxonomy の EQM-020 統合。
7. G10: 性能予算の数値宣言。
8. §2 policy reducibility test の acceptance 追加。

採用する場合は ROADMAP_POLICY に従い roadmap を改訂し、IMPLEMENTATION_QUEUE_DESIGN_POLICY に従って task 化する。
