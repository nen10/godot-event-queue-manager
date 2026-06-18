# EQM-083 POLICY

## 採用判断 (projection contract)

- **projection-first**: HUD は `set_state(order: Array, stale: bool)` で headless state (prediction) を注入され、それを **verbatim** に描画する。scheduler/policy を呼んで順序を再計算しない (UI_TESTABILITY L4 projection integrity)。
- **ui_metric_id metadata**: 各 row Control と stale indicator に `ui_metric_id` / `ui_metric_role` meta を付与 (EQM-087 collector の対象)。
- **stale state 明示**: `stale=true` (presentation deferred) は明示 badge。未設定/空 prediction は明示 empty state (silent fallback なし)。
- **非文字 modality**: 順位は position badge (整数)、stale は icon。label は localizable (`tr()` 可能な key)。color のみに依存しない (colorblind/SR 安全)。
- **EQDebugOverlay**: opt-in。injected live order + per-entry "why next" explanation data (EQTrace の decided_by など、explanation-as-data) を表示。consumer の自 game に組み込む debug hook。
- layer = `ui` (runtime UI; editor docks は Phase 9)。

## 不採用判断

- UI 側 order/件数/state の再計算 (projection integrity 違反)。
- color のみの状態表現 (非文字 modality 必須)。
- silent な empty fallback。

## Invariants

- HUD の表示順 == injected prediction 順 (L4 projection integrity)。
- HUD は scheduler/policy を呼ばない (state injection のみ)。
- 重要 Control は ui_metric_id を持つ。
- stale/empty は明示 state。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| set_state(order) | 表示 row == injected order | UI recompute | rows() == injected order (L4) |
| stale flag | deferred で明示 badge | silent stale | stale=true で stale indicator visible |
| empty prediction | 明示 empty state | silent fallback | 空 order で empty marker |
| ui_metric_id | 重要 Control に付与 | metric 不可視 | row/stale の meta 存在 |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| 空 prediction | 明示 empty state | silent fallback 禁止 | — | empty で marker |
| deferred presentation | stale badge | 整合性可視化 | — | stale=true |
| order 再計算要求 | しない (inject のみ) | projection-first | — | HUD は scheduler 非参照 |
