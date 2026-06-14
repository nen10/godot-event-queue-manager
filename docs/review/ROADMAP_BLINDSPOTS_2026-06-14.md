# Roadmap Blind Spots 2026-06-14

Mode: evaluate (strategic / architectural altitude)
目的: ここまでの検討 (dev process / test policy 群, event model 意味論, gap eval G1-G10) は「正しさ・プロセス・意味論」に集中していた。本 report は altitude を上げ、**まだ視野に入っていない角度** を精査する。各項目は roadmap への candidate であり、採否はユーザー判断後に反映する (既存の二段階フロー)。

既検討との区別: G1-G10 = 意味論/正しさ/プロセスの穴。本 report = 製品戦略・runtime 基盤・統合・addon 自身の lifecycle の穴。

---

## Tier 1 — roadmap の形を変えうる視角

### B1. 層化と progressive disclosure (最重要)

EQM は実質 2 つの製品である:

- **簡易 turn-order helper** — 「initiative 順 / CTB リストが欲しい」。addon 採用者の 80%。
- **深い event-line reservation engine** — action-resolution + 再帰召喚 + reentrancy。ユーザーの中核 vision。

ここまでの深掘りは後者に集中した。リスク: architecture が難ケースに最適化され、簡易ケースが二級市民化する / API が複雑で簡易採用者が離れる。roadmap は **明示的な層** を定義し、各層が単独で使えること、簡易パスが複雑性税を払わないことを保証すべき。

```text
L0 turn order      : actor 登録 → turn_ready signal → 終了通知。event-line/reservation を知らずに完結。
L1 policy          : Fixed/CTB/Energy を Resource 差し替えで。
L2 reservation     : 予約/AP/解決時間。L0/L1 を壊さず opt-in。
L3 event-line/window/reentrancy : 行動解決ターン制のフル機能。
```

提案: roadmap に「層と公開境界」節を追加し、各 milestone が「どの層まで simple に使えるか」を success criteria に含める。EQM-023 (API surface gate) を層別に拡張。これは progressive disclosure であり UX_PATH_REDUCTION と同系統 (簡易パスを hack でなく first-class に保つ)。

判断 -> progressive disclosure を保つ上でコストの問題なのか設計自体の不可能さなのかは区別して管理します。簡易パスは hack でないことについて開発体験価値のために同意しますが、簡易パスを唯一の first-class にするつもりはないです。

### B2. scope realism / minimum lovable product の前倒し

12 phase・30+ task・極めて深い意味論。meta-risk: 意味論の rabbit hole が「使える release」を遠ざける。我々自身、数ターンを意味論に費やした。

提案: v0.1 (Phase0-3) が **単独で出荷できる価値** を持つか再点検し、L3 の深い意味論は L0/L1 の後ろに隠れて opt-in であることを保証する。EQM-014 (意味論確定) は L3 契約の **予約** に留め、実装は Phase4/5 に置く分離 (A1 決定) を厳守 — これが守られないと v0.1 が L3 に人質に取られる。

判断 -> 本 addon 開発はゲーム性が未実証の行動解決ターン制の実現可能性をsmall stepで進めるためのテストケースとして実 game モデルを採用しているものの、それ自体で出荷することは想定していません。このことは着実な開発進行を妨げる意図はありませんし、EQMモデルごとに独立した再実装を禁止する意図もありません。

### B3. runtime 基盤: GDScript か GDExtension か / Godot version matrix

roadmap は全 `.gd` 前提だが明示決定がない。これは foundational:

- **言語選択**: 大規模戦闘・再帰召喚の polling cost (Q17/Q26) は GDScript の律速になりうる。core scheduler を GDExtension (C++) にする / できる余地を残すかは architecture を縛る。少なくとも「core は backend 差し替え可能 (sorted-array → binary heap → 将来 native)」を public API 不変で保証する設計か (EQM-102 と接続)。
- **Godot version matrix**: 対象は 4.x のどこからか。`project.godot` の値と整合した宣言が必要。addon にとって致命的に重要。

提案: roadmap に「対象 runtime / version matrix」節、core を言語非依存契約 (backend port 可能) として設計する制約を明記。

判断 -> そうします。

### B4. AI / 意思決定統合

turn-order system が存在する主目的の 1 つは「AI と player がターン順を読んで計画する」こと。prediction engine (EQM-033) は基盤だが、**AI が scheduler に仮説評価を問う** story が無い (「今動く vs 待つ」の比較、hypothetical branch の評価)。これは中核ユースケースの空白。

提案: prediction を「pure な hypothetical 実行 API」として設計し (snapshot 分岐 → 仮想 advance → 破棄)、AI 統合を 1 phase または EQM-033 拡張として明示。determinism + snapshot が既に基盤なので追加コストは小さい。

判断 -> 問題ありません。

### B5. production resilience 哲学 (fail-fast vs fail-safe)

error taxonomy (G9/EQM-020) は *コード* を定める。だが **shipped game が EQM のバグで crash してはならない** という非機能スタンスは未定。dev 時 fail-fast (assert で即停止) と production 時 fail-safe (event skip + log で継続) を mode 分離するか。再帰召喚の budget 超過、不正条件、dead actor 予約などの runtime 遭遇時の既定挙動。

提案: 「dev assertion mode / shipped resilient mode」の二相を PROJECT_PROFILE か新 policy で定義し、EQM-020 error taxonomy に recoverability class として接続。

判断 -> そうしましょう。

### B6. multiplayer non-preclusion (実装でなく制約として)

roadmap は network rollback を defer 済み。だが我々が作っている **deterministic + serializable + seeded RNG + snapshot replay** は lockstep netcode の最難部そのもの。実装しないとしても「将来の lockstep を *妨げない*」を非機能制約として捕捉すれば、後付け可能性を資産化できる。差別化要因にもなる (「決定的だから将来 multiplayer 化できる turn engine」)。

提案: roadmap の deferred 節に「multiplayer-readiness は non-preclusion 制約」と明記。determinism trace policy が既にこの価値を守っているので、追加作業はほぼ宣言のみ。

判断 -> 正しい。

---

## Tier 2 — 追加的・後段で効く視角

| id | 視角 | なぜ重要 | 暫定 disposition |
|---|---|---|---|
| B7 | content-scale authoring | 実 game は action/condition/status が数百。Resource 1ファイル×数百 → 管理破綻。bulk 編集・library 横断 validation。 | Phase10 editor に「content library 管理」を追加候補。EQM-020 validation を library 規模で。 |
| B8 | Godot idiom 統合 | SceneTree pause, EditorUndoRedoManager, Timer/AnimationPlayer/Tween 共存, group/signal。adapter は触れたが idiom 具体は未定。 | Phase9 (EQM-032) acceptance に pause/undo 連携を追加候補。 |
| B9 | frame budget / time-slicing | 大規模戦闘で 1 frame に 500 event 解決 = hitch。advance を frame 予算で分割する driver mode。 | EQM-032 driver 契約 + Phase8 presentation と接続。B3 言語選択と連動。 |
| B10 | runtime debug overlay (consumer 向け) | 開発者が *自分の game* を EQM で debug する runtime overlay/log hook。editor inspector とは別。 | B4/HUD(EQM-083) と統合候補。 |
| B11 | localization / accessibility (runtime UI) | 提供する HUD/timeline の l10n・colorblind・screen reader。 | EQM-083 acceptance に追加候補。UI policy に既存の icon/non-text modality と接続。 |
| B12 | license / governance / AssetLib | MIT 等の license、contribution、AssetLib 提出要件。模倣元 game 名は clean-room で問題小。 | EQM-103 release 候補に追加。 |
| B13 | 競合 positioning / 差別化 | 既存 Godot turn addon や hand-roll に対する選択理由。killer = determinism+trace+event-line generality か。 | roadmap §1 の "why" に positioning 段落を追加候補。優先度判断の指針になる。 |
| B14 | 製品価値 metric / north star | release 後の「価値ある」判定。採用数・dogfood friction 減・simple パス完走率。 | EQM-035 評価 task の指標に追加候補。 |
| B15 | mental-model 教育を deliverable 化 | event-line/event/trace モデルは高度。教え方自体が製品リスク。 | EVENT_MODEL_CONCEPTS.md を manual の概念章に昇格、Phase11 で。 |

---

## 推奨する取り込み順

1. **B1 (層化) と B2 (scope realism)** を先に roadmap へ — これらは他全部の優先度を決めるメタ判断。
2. **B3 (runtime 基盤/version)** を Phase0-1 の制約として確定 — 後からの変更コストが最大。
3. **B5 (resilience), B6 (multiplayer non-preclusion)** は宣言コストが小さく価値が高い non-functional 制約。
4. **B4 (AI 統合)** は prediction 設計 (EQM-033) を決める前に方向だけ確定。
5. Tier 2 は該当 phase の acceptance 追記で吸収。

各項目の `判断 ->` にユーザー判断を記入後、ROADMAP_POLICY / IMPLEMENTATION_QUEUE_DESIGN_POLICY に従って roadmap・queue へ反映する。

---

## 反映 (2026-06-14, ユーザー判断後)

ユーザー判断の重要 nuance:
- B1: 簡易パスは hack でないが**唯一の first-class ではない**。簡易・深層の両方が first-class。progressive disclosure の leak は「コスト(支払可)か設計不能か」を区別して管理する。
- B2: 本 addon は未実証の行動解決ターン制の実現可能性を small step で検証する **vehicle**。test-case game 自体の出荷は非目標。着実な進行は妨げない。**モデルごとの独立再実装は禁止しない**(reducibility は証明であって強制ではない)。

| id | 反映先 |
|---|---|
| B1 | ROADMAP §3.1 (層と公開境界), 原則15。EQM-023 を layer-aware 化。success criteria に simple-path 非leak。 |
| B2 | ROADMAP §1.1 (開発 role 再フレーム), §1.2 (positioning)。EQM-053 を「証明であり強制でない」へ。success criteria を「検証可能 capability」基準に。 |
| B3 | ROADMAP §3.2 (runtime/version), 原則19。EQM-002 (version 宣言), EQM-011 (backend 契約)。 |
| B4 | ROADMAP 原則17, success criteria。EQM-033 を pure hypothetical API へ。 |
| B5 | 新 policy `RUNTIME_RESILIENCE_POLICY.md`, 原則16。EQM-020 (recoverability→mode), EQM-022 (mode toggle)。 |
| B6 | ROADMAP 原則18, deferred 節 (non-preclusion), success criteria。determinism policy が既に value を保護。 |
| B7 | EQM-020 (library 規模 validation は将来), Phase10 候補として保持。 |
| B8 | EQM-032 (SceneTree pause / EditorUndoRedoManager 共存)。 |
| B9 | EQM-032 (frame-budget time-sliced advance)。 |
| B10 | EQM-083 (consumer 向け runtime debug overlay)。 |
| B11 | EQM-083 (HUD l10n + non-text modality)。 |
| B12 | EQM-103 (LICENSE / AssetLib / clean-room)。 |
| B13 | ROADMAP §1.2 positioning。 |
| B14 | EQM-035 (north-star metrics)。 |
| B15 | EQM-100 (concepts 章 = three-plane mental model)。 |

未反映(将来 phase で吸収): B7 の content library 管理 UI は Phase10 editor の独立 task 候補として残す(現状は EQM-020 validation の将来拡張注記のみ)。

user追記: Tier 2 も任意のタイミングで進めて構いません。
