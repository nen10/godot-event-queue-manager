# EQM-126 Self Review — 操作フェーズ再帰 + ループ巻き戻し

date: 2026-07-05 / task: EQM-126 / pattern: P2 (codex 委譲 1 run)

## Acceptance check (SEM v1.2 §8.4)

- [x] open_phase(name, inputs): top 明示 window 上の順序付き checkpoint (scheduler snapshot + 宣言入力 slot + 決定的 seq)。`phase_opened` trace。明示 window なし / 空 name = fault。
- [x] ループ検出 = 同名フェーズ再訪 (checkpoint stack の name 列)。新 checkpoint は積まず、**ループ開始点の snapshot へ restore + 上位 checkpoint を pop**。`phase_rolled_back` (rolled_back_from + cleared_inputs 内容順 sort)。解除の実体はゲーム側 (SEM どおり記録のみ)。
- [x] close_phase(commit): pop (commit=false は restore して pop)。`phase_closed` trace。空 stack = fault。
- [x] window close (通常/deadline/intervention) でフェーズ stack 破棄。フェーズ不使用経路は不変 (既存 golden 全 green)。
- [x] 水鏡 golden `mirror_loop_rollback`: target_select → mirror_input → confirm → mirror_input 再訪 = rollback、confirm 中に schedule した予約が巻き戻しで消えることを test で確認。
- [x] gate PASS ×2 (files=66 checks=1240; coverage 29/31)。

## 委任と検証

- 検収指摘なし。特筆: `_reconcile_runtime_state_after_snapshot_restore` — snapshot restore で消えた event id を全帳簿 (`_window_of_event` / `_bound_inv` / `_bundle_of` / `_by_event` / `_bundle_members` / `_expiry_by_event`) から掃除する堅実な自発実装。contract は「scheduler restore」だけ要求していたが、EQM-124/125 で増えた帳簿との整合を正しく読んだ。
- cleared_inputs の sort は String 配列 (内容順) — StringName 非決定 sort の回避を確認。

## 申し送り

- phase checkpoint の snapshot は scheduler のみ (event-line / 状態代数 / 関係は含まない)。操作フェーズ中にそれらを書き換える設計が EBS 側に出た場合、checkpoint の対象拡大が必要 — EQM-128 の acceptance で需要を確認し、必要なら follow-up 起票。
- EQWindow.phase_checkpoints は to_dict に載る (snapshot v3 の checkpoint table は EQM-127 が確定)。
