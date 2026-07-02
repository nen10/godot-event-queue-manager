# EQM-113 Self-Review 2026-07-02

Pattern: P0 (orchestrator-direct)。Repair: 1/3 — 新規 3 file の EOF 改行欠落による Godot parse error (挙動でなく書式; 修正後初回 green)。

## Execution summary

SEM v1.1 §6.1–§6.3/§13 を実装し、EQReservationRuntime を 5-step 解決 pipeline (pop → effect → chunk → sweep → trace/drain) に再構成した。

- **宣言 linkage (Q31)**: `effect_name` 空 = effect なし解決、設定済み未登録 = `eqm.effect.unregistered` (dev halt / shipped skip+fault)。handler は named registry (`register_effect`)。
- **chunk = save 境界**: 効果 records は解決時に chunk へ積まれ、resolve 完了時に `last_drained` へ drain。resolve 間は常に `is_save_allowed()`。
- **Q27 適用**: 条件 gate 済み予約は `step_tick`/sweep の評価で「成立検出 tick = due_tick」で push (厳密 tick を test で固定)。
- **reaction schedule 化 (Q32)**: fired は現在 tick + 宣言 priority で push。in-place `fire_cascade` は削除し、同 tick round guard (`max_cascade_rounds`, TRIGGER_CHAIN_LIMIT) + `reaction_fired` round trace が EQM-062 の受け入れを引き継ぐ。
- **expiry event 化 (Q40)**: arm 時に expiry event を schedule。`closed_by: duration / reaction_count / already_closed`。on-expiry effect (`expiry_effect_name`) も pipeline 経由。engine 単体の lazy expire は観測可能化 (`expired`)。
- **invalidate_actor (Q39)**: L0 (cancel + `event_invalidated` trace + unregister、mode 中立) + L2 (disarm + conditional 破棄)。bridge の `on_actor_freed` が正規経路を呼ぶ。dev/shipped の trace 同一性を test で固定。
- **数値 invalidation の sweep 再評価 (§5.3)**: scheduled 済み予約の invalidation を毎 sweep 再評価し cancel + closed_by。

## Acceptance result — met

queue row の全項目を上記で充足 (tests: files=54 checks=839 failures=0; 既存 EQM-051/052/060/061 test は無変更で green — 旧挙動の保存を証明)。

## Golden updates (explicit)

- `tests/golden/api_surface.json` のみ。**demo/dogfood の trace golden は不変** — fire_cascade / EQReservationRuntime は demo/dogfood で未使用 (grep 確認)、`sync_primary` を無記録の鏡に変更したため既存 trace に新 record は入らない。

## Deviations

- **EQEventLines.sync_primary を無記録化** (EQM-112 からの変更): primary は scheduler.current_tick の鏡であり、tick の前進は resolved record が既に canonical に持つ。記録すると既存 golden 全てが変わるため、観測は他 cause (issued/advanced/poll/re_rated/sweep_rule) に限定した。
- **rumination の counter line 化は見送り** (POLICY 判断): 反応回数の runtime store は既存 `remaining_ruminations` を維持し、消尽時 `closed_by: reaction_count` を追加。宣言 COUNTER spec (acceptance 起票) は counter line に束縛される。二重管理を避ける層分け。
- **armed 反応への宣言 LINE_THRESHOLD invalidation は未接続**: 反応の失効は duration (expiry event) と count で閉じる。armed 状態への数値 invalidation 接続は Q42 受け入れ (EQM-119) で要否を再評価する (declared follow-up)。
- fired reaction は同一 EQReservation object が「armed slot」と「scheduled 解決」を兼ねる (status を上書き)。動作は test で固定済みだが、instance 分離は EQM-119 の authoring 整理で再検討 (declared follow-up)。
- `runtime._fault` を L2 から直接呼ぶ (GDScript に private はなく、mode 判断の単一権威を保つため)。

## No sample-only completion

Pipeline の property (検出 tick 厳密値 / mode 中立 byte 同一 trace / 有界 cascade の解決回数上限 / save 境界の常時成立) を合成シナリオで固定。sample preset 依存なし。

## UX path reduction

- in-place cascade (hack 経路) を削除。効果適用の入口を named registry 1 本に限定。
- 新規入力クラスは serializable な named effect のみ (自由 callback の直接保持は不採用)。

## Repair-now / follow-up

repair-now なし。declared follow-ups (上記 Deviations): armed 反応への数値 invalidation / fired instance 分離 — EQM-119 で再評価。次: EQM-114 (window object model) READY。
