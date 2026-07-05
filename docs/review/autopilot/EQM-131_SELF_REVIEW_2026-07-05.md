# EQM-131 Self Review — acceptance 修理 [repair: B1/B2 + EBS A-R08-1]

date: 2026-07-05 / pattern: P2 (codex 委譲 1 run + orchestrator 検収)

## Acceptance check

- [x] **B1 消化**: R06 の新変種 golden `focus_cost_counter_stop` — 焦点 line (非対称 3/2) を反撃 effect が decrement、`LINE_THRESHOLD <= 0` (condition_id: focus_exhausted) の invalidation で応酬が停止。rumination は 10 で回数では止まらないことを保証 — **「コスト述語の閉包で必ず止まる」の原文意図をようやく証明**。旧 golden (回数系) は変種として不変。常真 assert 2 本を実質化 (event_invalidated = 2 / closed_by 明示)。
- [x] **B2 消化**: retarget `params.stage` に int (provenance index) — 中間段の明示選択が宣言可能に。reach 検査は同一 (meta >=)、範囲外 = no-op、"root"/"direct" 挙動不変 (test で固定)。
- [x] **A-R08-1 整合**: R08 例をメタレベル**昇順**・同率**付与順** (index tiebreak — 不安定 sort でも決定的) の hook に書き換え、3 候補 + 同率ペアで order 検証。
- [x] gate PASS ×2 (files=70 checks=1356)。

## 委任と検証

- 検収で **scope 外の回帰 1 件**を捕捉・修正: `_apply_target_expansion` の `targets_expanded` 記録がインデント 1 段外に移動しており (codex の意図不明な編集)、**展開ゼロの matching rule でも記録が出る**状態だった。golden はすべて「必ず展開する」シナリオのため素通り — guard 内へ復帰 + 「展開なし = 無記録」の regression test を追加。
- 教訓 (memory 反映): 委任 diff の検収では「契約対象の関数」だけでなく **同 file 内の無関係 hunk を必ず走査**する (今回は git diff の全 hunk 精査で発見)。

## 申し送り

- stage int は provenance の絶対 index。EBS 側で「後ろから n 段」が欲しくなったら additive (負 index) で拡張可能。
