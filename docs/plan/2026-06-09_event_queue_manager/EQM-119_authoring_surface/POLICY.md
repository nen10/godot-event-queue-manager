# EQM-119 POLICY — L2 authoring surface

## 採用判断

- **凍結基準は糖衣で満たす**: 「3 回 or 5 ターンで close」は `rumination=2` (計 3 回) + `duration=5` の 2 field 宣言 = EQM-111 の正規化 (`reaction_count` / `duration` 条件) がそのまま閉路になる。EQConditionSpec の明示宣言は「糖衣で表せない条件」用であり、最頻ケースが 2 int で書けることこそ §5.6 の意図 (単純な場合は単純に)。
- **.tres は手書きで check-in**: ResourceSaver 生成ではなく authored asset として置く — 「editor/inspector で宣言できる形」の実物証明。dogfood 配下 (learning path、production slot ではない)。
- **dogfood は additive**: `run_l2_trace()` を追加し、既存 `run_trace()` (L0 手動配線) とその golden は不変。両者の対比が manual の教材になる (F 不採用理由)。
- **golden の可視性**: 1 つの決定的 run に count 閉路と duration 閉路の両方を含め、`closed_by` がどちらで閉じたか fixture 上で読めることを基準の証明とする。
- **Q35 effect grouping = defer 確定**: grouping (視認性単位) は `EQEffectRecord.tags` + presentation policy の classification で今日表現可能。専用 field は golden 波及を伴うため、実需要の信号が出るまで実装しない。declared follow-up を closed (deferred) として記録。

## 不採用判断

- run_trace() の書き換え (F) / editor picker の新設 (G — 既存 follow-up に包含) / .tres の複数バリエーション check-in (∞ 変種は test 内で duration=-1 に複製して証明)。

## Invariants / State Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| .tres | GDScript 0 行 (data のみ) で load・validate 可 | 手書き構文の破損 | load + validate test |
| 閉路 | count/duration どちらで閉じたか trace で判別可能 | 閉路の黙殺 | golden + closed_by assert |
| 既存 dogfood golden | 不変 | additive 崩れ | 既存 dogfood test green |
| manual | EN/JA mirror 同内容 | 片側更新 | 両 file 更新 (self-review 列挙) |
