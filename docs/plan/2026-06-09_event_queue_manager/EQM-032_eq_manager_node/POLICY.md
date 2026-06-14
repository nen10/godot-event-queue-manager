# EQM-032 POLICY

## 採用判断

- **EQManager extends Node** (class_name)。EQRuntime を wrap。scene-local 既定 (autoload は opt-in、profile)。
- **6 signal**: `queue_changed` / `event_ready(entry)` / `turn_ready(actor_id, entry)` / `event_resolved(entry)` / `timeline_advanced(tick)` / `invalid_event_skipped(fault)`。
- **driver 契約** (SEMANTICS §14 と整合):
  - who advances: consumer が `step()` / `advance_frame(budget)` を呼ぶ。Node は暗黙 auto-drive しない (本 task)。
  - suspend: `turn_ready` 発火後は `_awaiting_turn=true` で `step()` が null を返す (入力待ち)。`finish_action` が解除。
  - await boundary: `event_resolved` 発火と次 `step()` の間が presentation 境界。
  - frame-budget: `advance_frame(budget)` は budget 件まで解決 (turn は auto_result で自動 finish)。**order/trace は budget に不変** (determinism)。
- **policy 自動委譲**: `finish_action` は policy があれば `policy.on_turn_finished`、無ければ `runtime.finish_action` (default delay)。EQM-030/031 から defer した結線。
- **invalid actor policy**: `configure(config)` が `runtime.start()` で validate。`validate()` で EQValidation を返す。invalid config は dev/shipped に従い surface。
- **plugin 登録**: `add_custom_type("EQManager", "Node", script, null)` / `_exit_tree` で remove。

## 不採用判断

- Node の暗黙 _process auto-drive (default off; consumer 駆動)。auto-drive は将来 opt-in。
- production node bridge (save/load rebind, autoload installer, 全 domain signal) → EQM-085。
- EQRuntime 内部 (mode/faults 機構) の変更 (wrap のみ)。

## Invariants

- `advance_frame` の trace は budget に不変 (time-slicing が順序を変えない)。
- `turn_ready` 後 `finish_action` までは新たな解決が起きない (suspend)。
- 正常 path は EQRuntime と同一 trace (manager は signal 層のみ追加)。
- scene tree 無しでも method/signal が機能 (headless test 可能)。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| `_awaiting_turn` | turn_ready 後 suspend、finish で解除 | 二重解決 / 入力無視 | turn_ready 後 step()=null、finish 後 step 再開 |
| advance_frame(budget) | trace は budget 不変 | time-slice で順序破壊 | budget=1 と budget=N の trace byte 一致 |
| signals | 解決ごとに正しい signal/payload | signal 漏れ/誤 payload | signal recorder で順序・payload assert |
| configure(invalid) | validation で捕捉 | silent 不正 policy | base policy config → validate invalid |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| turn_ready 中の step() | null (suspend) | player await | — | suspend test |
| policy 無し finish | runtime.finish_action (delay) | policy 任意 | — | (EQM-022 default path) |
| invalid config | validate で報告、mode に従う | silent 不正回避 | — | base policy → invalid |
| shipped skip | invalid_event_skipped signal + trace | 可視化 | — | orphaned event skip |
