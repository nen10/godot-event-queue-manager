# EQM-113 POLICY — 解決 pipeline 統合

## 採用判断

- **pipeline の所在 = EQReservationRuntime (L2)**。EQEventLines (L3) を所有するのは L2 であり、EQRuntime (L0) の public 署名には出さない (leak gate)。L0 の `advance()`/`finish_action` 流儀は不変 (effect なし解決)。
- **宣言 linkage (Q31 確定)**: `effect_name` 空 = effect なし解決 (合法)。設定済み + 未登録 = `eqm.effect.unregistered` (CONTRACT_VIOLATION, dev halt / shipped skip+trace)。効果は `register_effect(name, callable)` (named registry) の handler が `EQEffectRecord[]` を返し chunk へ積まれる。
- **drain 規律**: resolve_next の末尾で chunk を drain し `last_drained` に置く (§6.1 step 5)。resolve 間は chunk 空 = save 境界が常に成立。
- **reaction は schedule (Q32 確定)**: fired は `due=current, priority=宣言値, 新 sequence` で push。cascade は「解決→sweep→発火→schedule」の自然な反復で、同 tick round が `max_cascade_rounds` を超えたら TRIGGER_CHAIN_LIMIT (BUDGET_EXCEEDED — dev halt / shipped truncate) を記録し以後の schedule を止める。round 番号は `reaction_fired` trace に載る。
- **rumination の counter 表現は据え置き** (二重管理回避): 反応回数の runtime store は既存 `remaining_ruminations` を維持し、消尽時に `closed_by: reaction_count` trace を追加する。宣言 COUNTER spec (acceptance 起票) は counter line に束縛される — 2 経路は用途が異なり衝突しない (糖衣は authoring 正規形として存在、runtime 実装は本 policy)。self-review に明記。
- **expiry は event (Q40 確定)**: arm 時に kind=&"expiry" を `armed_at + duration` へ schedule。pipeline 所有の反応は engine 側 lazy expire を使わない (UNLIMITED で arm し、期限は expiry event が唯一の閉路)。closed 済みなら `closed_by: already_closed` の軽量 trace。
- **invalidate_actor (Q39 確定)**: mode 中立 (fault にしない)。L0 部分 (scheduler cancel + `event_invalidated` trace + unregister) は EQRuntime、L2 部分 (armed 解除・conditional 破棄) は EQReservationRuntime が重ねる。bridge の `on_actor_freed` は runtime の正規 API を呼ぶ。バイパスして pop された未登録 actor event は従来どおり contract violation。
- **trace kinds 追加** (open schema): `event_invalidated` (closed_by 必須) / `reaction_fired` (round)。SEM §11 に additive 追記する。

## 不採用判断 / 破壊的変更

- `EQTriggerEngine.fire_cascade` / `max_chain` を **削除** (pre-1.0 replace stance)。in-place 解決は三面モデル不変条件に反する (Q32)。EQM-062 の受け入れ (有界 cascade + fault) は pipeline round guard として引き継ぎ、`test_eq_rumination_cycle_guard.gd` を新契約へ更新する。
- EQManager への pipeline 露出・汎用 on-expiry hook は不採用 (SUB_TASKS H/I)。

## Invariants / State Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| chunk | resolve_next 完了時は常に空 (drain 済み) | 積み残しで save 永久不可 | 連続 resolve 後 is_save_allowed test |
| fired reaction | 必ず timeline を経由 (in-place 解決なし) | sweep 内再帰 | queue 内容 assert + round trace |
| 同 tick cascade | round ≤ max_cascade_rounds | 無限 loop | runaway test (dev halt / shipped truncate) |
| expiry event | armed 反応の期限は event でのみ閉じる | silent 削除再発 | duration close test + trace 検証 |
| invalidate_actor | 両 mode 同一動作・trace 同一 | mode 分岐 | dev/shipped 両方で test |
| 条件 gate 済み予約 | 成立検出 tick = due_tick (Q27) | 検出遅延の不定 | step_tick 到達 test (厳密 tick) |
| L0 surface | EQEventLines 型が L0/L1 署名に不在 | L3 leak | api-surface leak gate |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| 旧 resolve_next 挙動 (immediate/prepared/wait/operation/ready/rumination) | 維持 (pipeline 内で同意味) | EQM-051/052 契約の保存 | — | 既存 test green 維持 |
| engine 単体の lazy expire | 単体利用向けに存置 + `expired` 公開 (観測可能化) | 単体層の後方互換 | pipeline 全面移行後の v2 整理 | engine test |
| scheduler.current_tick と primary line | sync_primary を pipeline の 2 点 (pop 後 / step_tick) だけで呼ぶ | 二重管理 | — | 同値 assert |

## 未確定だが task 内で決めてよい事項

- `max_cascade_rounds` 既定値 → 8 (エンジニアリング backstop; acceptance 可変)。
- 条件評価の順序 → 提出順固定 (deterministic)。
