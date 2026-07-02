# EQM-113 SUB_TASKS — 解決 pipeline 統合

## Complexity

Class: C4
Reason:

- runtime/reservation/trigger/chunk/bridge の 5 subsystem を単一契約 (SEM §6.1) へ統合する。
- 既存挙動の契約変更 2 点 (fire_cascade in-place 廃止 → schedule 化; expiry silent 削除 → event 化) を含む。
- 既存 test (EQM-062 cycle guard) の新契約への更新を伴う。

Required artifacts: C4 (fallback/mirror 必須、rejected/deferred の queue 化判定含む — 本 file と POLICY.md)。

## Task resolution

| task 候補 | 目標/UX | 採否 | 概要 |
|---|---|---|---|
| A. EQReservationRuntime を 5-step pipeline へ再構成 | SEM §6.1 | 採用 | pop → effect (宣言 linkage) → chunk → sweep → trace/drain。L2 が lines (L3) を所有し L0 署名に出さない |
| B. effect registry + 宣言 linkage | §6.1 (Q31) | 採用 | EQRuntime.register_effect / EQActionDefinition.effect_name (+expiry_effect_name); 設定済み未登録 = 安定 error |
| C. reaction schedule 化 + bounded rounds | §6.2 (Q32) | 採用 | fired は現在 tick へ push (宣言 priority)。同 tick round 上限 + `reaction_fired` round trace。fire_cascade / max_chain は削除 (replace stance) |
| D. expiry event 化 | §6.3 (Q40) | 採用 | arm 時に kind=&"expiry" を schedule; closed_by duration / reaction_count / already_closed |
| E. invalidate_actor 正規経路 | §13 (Q39) | 採用 | EQRuntime (L0: pending cancel + trace + unregister, mode 中立) + L2 拡張 (disarm + conditional 破棄) + bridge 配線 |
| F. 条件 gate 済み予約の検出/push (Q27) + step_tick | §5.4/§4.3 | 採用 | 未 schedule の条件つき予約を sweep/tick 境界で評価し、成立 tick を due として push。step_tick = tick+1 → sync/poll/sweep rules/評価 |
| G. 数値 invalidation の sweep 再評価 | §5.3 | 採用 | scheduled 済み予約の invalidation terms を sweep で再評価し cancel + closed_by (eager-numeric) |
| H. EQManager (L0) への pipeline 露出 | — | 不採用 | L0 surface 不変。L2 利用者は EQReservationRuntime を直接使う (manual は EQM-119) |
| I. on-expiry effect の汎用 hook 化 | — | 不採用 | expiry_effect_name (named registry) で足りる。汎用 hook は入口拡大 |

Scheduled task: なし (authoring/manual 反映は EQM-119、snapshot 組込みは EQM-117 が owner)。
