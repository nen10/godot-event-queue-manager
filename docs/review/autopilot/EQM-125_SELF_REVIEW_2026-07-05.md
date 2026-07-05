# EQM-125 Self Review — メタレベル + window premature close

date: 2026-07-05 / task: EQM-125 / pattern: P2 (codex 委譲 1 run + orchestrator 検収)

## Acceptance check (SEM v1.2 §8.2/§8.3)

- [x] EQWindow.meta_level (宣言 int、open_window 末尾 param、to_dict)。window_opened へは**非 0 のときのみ**掲載 — 既存 golden を変えない additive の要請を codex が正しく処理。
- [x] window 帰属帳簿: 「明示 window open 中に schedule された予約」= pending member (非永続、解決/invalidate/close で掃除)。
- [x] intervene_close: 同値 = 介入成功 (`<` のみ回避)。成立時は対象 + nest 上位を上から close — 各 window の pending member を `event_invalidated (closed_by: intervention)` で一掃、draft rollback (= pending 破棄のみ。**解決済み効果への巻き戻し操作は存在しない**)、pre_close hook (deadline 対称)、`window_closed (cause: intervention)` + window_meta/intervener_meta/intervener_event_id。
- [x] 回避 = `intervention_avoided` trace (正常系、fault でない) + window/pending 無傷。SEM §11 に kind を additive 追記 (同 commit)。
- [x] golden `interception_close` = 凍結 acceptance 形 (5 歩中 2 歩 resolved 維持 + 3 歩打ち切り、tie meta 1 vs 1)。
- [x] gate PASS ×2 (files=65 checks=1207; coverage 28/31)。

## 委任と検証

- codex 納品は契約準拠 (帳簿掃除・nest close・回避 trace・既存 golden 保護すべて対応)。検収での介入 2 件:
  1. **golden シナリオ強化**: 納品は 1 解決 + 1 pending の縮小形 → 依頼の凍結 narrative (5 歩の 2 歩目で迎撃、残 3 打ち切り) へ orchestrator が書き直し再 baseline。acceptance instance は EBS が依頼文書と 1:1 照合するため縮小形では成果にならない。
  2. **golden env var の統一 (原因は orchestrator の contract 誤指定)**: 私の委任 prompt が `EQ_UPDATE_GOLDEN` と指定していたため codex 製 3 test が repo 標準 `GODOT_UPDATE_GOLDEN` (test.sh --update-golden の配線) と不整合 → 3 file を標準へ統一。教訓: 委任 contract に書く定数・環境変数は既存実装から grep で採ること。

## 申し送り

- intervene_close の呼び出し規約 (介入側 effect handler から window_id をどう知るか) は EQM-128 の acceptance で標準形を示す (相手 actor の window 照会 API は window_depth/…既存で足りるか確認)。
