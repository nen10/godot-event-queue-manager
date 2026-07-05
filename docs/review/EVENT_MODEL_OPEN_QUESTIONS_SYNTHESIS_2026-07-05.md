# Event Model Open Questions — Synthesis 2026-07-05 (拡張ラウンド Q44–Q54)

status: EQM-120 の決定根拠記録。確定記述は `EVENT_MODEL_SEMANTICS.md` v1.2 の *(v1.2)* 節、起票と決定は `EVENT_MODEL_OPEN_QUESTIONS.md` 拡張ラウンド節。

## 経緯

- 2026-07-05: EBS (godot-editable-battleskill-system) の拡張依頼 R01–R12 を受領 (受領コピー: `docs/plan/2026-06-09_event_queue_manager/EBS_EXTENSION_REQUEST_2026-07-05.md`)。依頼は EBS 側相談ラウンド1 を反映した draft v2。
- 同日、対話 2 回 (相談ラウンド2 = 8 fork / 相談ラウンド3 = 8 fork) で意味論の全 fork をユーザー決定した。設計 fork の残はゼロ。確認系 (Q46/Q54) は acceptance 例が成果で、実装 task が所有する。

## 決定対照 (fork 16 点)

### 相談ラウンド2

| # | fork | 決定 | 主な理由 |
|---|---|---|---|
| 1 | メタレベル付与先 | スキル宣言の int (event/window が運ぶ、未宣言 0) | nest 深度との混同 (深い = 強い) を避け、EBS 側でスキルごとの強弱を設計できる |
| 2 | 値域・同値 | 単一 int 全順序、同値 = 介入成功 | 「比較不能」ケースを構造的に排除。同値は能動側 (コストを払った介入) を通す |
| 3 | 発行連鎖の各段 | 各段が宣言メタレベルを保持 | 「レベル差が届く最遠段」という target 調整幅が自然に定義できる |
| 4 | inv 双対の共存 | ペア宣言 + 規則選択制 (相殺/排他/共存) | stacking acceptance-defined (SEM §4.5) と整合。EQM は抽象構造、EBS が instance |
| 5 | suspension | modifier-stack | 重複 (鈍化中に凍結) の復帰値を EQM 側で決定的に保証 |
| 6 | 関係維持条件の評価 | 関係型ごと宣言 sweep (既定 = primary tick 閾値) | §4.7 registry 流用。ゲームごとの「T」定義差を吸収 |
| 7 | premature close の範囲 | 解決済み維持・pending 打ち切り | 介入の発動条件が「起きた効果」に依存 (相談1) — rollback は自己矛盾 |
| 8 | フェーズループ解消 | ループ開始点へ巻き戻し + 入力解除 | 依頼文の「working-copy がフェーズ巻き戻しに使えるか」の検討と整合 |

### 相談ラウンド3

| # | fork | 決定 | 主な理由 |
|---|---|---|---|
| 9 | 連鎖 (状態のラッピング) | **デコレータ型** — 状態が状態を包み、包まれた側の付与・解除・効果の意味論を修飾 | 波及 (対象拡大) とは別機構。状態代数に合成構造が要る |
| 10 | 結び直し語彙 | 直列縫合のみ (enum、additive 拡張余地) | 現実需要は解体のみ。UX_PATH_REDUCTION |
| 11 | 発行連鎖の載せ場所 | event 側 provenance | event-line は進行入力 — 出所記録は三面分離 (§2.1) を破る。依頼中の event-line 示唆はユーザー承認の上で不採用 |
| 12 | pipeline 詳細 | 段 = pop 直後・effect 前 (展開→変換)、BFS 関係 id 昇順、bundle 前倒し承認。**修正 2 点は下記「推奨からの逸脱」** | — |
| 13 | 相殺の記録形 | 符号付き 1 本 | inv ペア = 1 軸の両方向。相殺が算術で自動成立、対合の意味論と一致 |
| 14 | modifier 合成語彙 | 加算 + override のみ | 現実需要 (凍結 = override 0、鈍化/機敏 = ±add) で充足。乗算は整数分数 + 丸め規則が前提のため需要待ち |
| 15 | actor 離脱と関係 | 解消時規則を通して自動解消 | 身代/召喚 tree で親が死ぬケースの自然経路。決定性を EQM 側で保証 |
| 16 | checkpoint 粒度 | **フェーズ内 sub-checkpoint も必要** | 1 つの OPERATION window 内で多段フェーズ遷移 (共鳴の 4 段階) が起こる設計を想定 |

## 推奨からの逸脱 (ユーザー修正 4 点)

実装時に「推奨案の記憶」で書かないこと。SEM v1.2 が正。

1. **展開の再帰停止規律**: 推奨 (visited set) → **メタレベル/コストに従う** (§8 の meta-cost budget と同じ語彙で bound)。hop cost の宣言形は EQM-123 が §8 語彙内で確定する。
2. **変換の多重適用**: 推奨 (1 パス制限) → **許可**。適用構造 (どの変換がどれに適用され得るか) は開発者が計画できる data とし、スキル効果グラフによる選択的設計と意味論的 validation は **EBS 側の機能に寄せる**。EQM は決定的順序 (メタレベル降順 → priority → sequence) + 適用ごとの trace + 有界 round の安全弁 (RUNTIME_RESILIENCE の dev fail-fast) のみ保証する。
3. **変換のバリエーション** (ユーザー補足): 変換は event の**パラメータごとの型**を持つ — 対戦術 = 効果の**対象先**の変換、反転系 = **状態代数** (inv) における変換。他パラメータへの変換型も同じ枠で検討可能。SEM §6.4 はこの「パラメータ別書き換え」を契約構造として固定する。
4. **フェーズ checkpoint**: 推奨 (window draft で足りる) → **sub-checkpoint 追加**。window より細かい、フェーズ単位の順序付き checkpoint を draft 内に持つ。
5. **ループ解消の方式** (ラウンド2): 推奨寄りの前進遷移ではなく**巻き戻し**を選択。

(4 点 + ラウンド2 の 1 点 = 逸脱 5 点)

## Q01–Q43 との整合

- 三面分離 (§2.1) — provenance を event 側に置く決定はこれを守るため。event-line 側拡張は不採用。
- §4.6「rule = data」 — modifier-stack は data 拡張 (callable なし)。再計算は決定的。
- §5 条件語彙 — 寿命合成 (Q46)・modifier 寿命・pending 打ち切りは全て既存 invalidation OR / expiry event (§6.3) の語彙で書く。新規の寿命 primitive は作らない。
- §7 composite — bundle 前倒し (Q49) は §7 の core 保証 (atomicity / total order / serializability / trace) の実装であり、§7.1 hook と両立 (member 順序に hook を使う)。
- §8 reentrancy — 展開の停止規律はここの meta-cost 語彙を参照する (新予算体系を作らない)。メタレベル (Q51) は budget とは別概念 (比較用の宣言値) だが、同じ「介入の強さ」ドメインに属するため §8.2 に併記する。
- Q12 (感知分類 = simulation data) — 空間述語のゲーム側 NAMED_PREDICATE 供給はこの延長 (依頼合意済み)。
- Q23 過剰一般化ガードレール — 乗算 modifier / 結び直し語彙の拡張 / 変換型の追加は全て「需要確定時に additive」で統一。

## 責務の線引き (依頼合意の再掲 + 本 round での追加)

- EQM: 状態・関係の管理、解決順序・トリガ・介入の意味論、決定的順序と trace。
- ゲーム側: 空間述語 (NAMED_PREDICATE)、効果の実行、防御スタック実体。
- EBS: スキル記述と型検査。**本 round で追加**: 変換適用構造の validation、スキルごとのメタレベル値付け。
