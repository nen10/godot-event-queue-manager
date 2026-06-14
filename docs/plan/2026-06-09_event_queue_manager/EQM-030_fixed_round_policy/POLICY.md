# EQM-030 POLICY

## 採用判断

- **EQPolicy 契約 = `seed(runtime, actor_ids)` + `on_turn_finished(runtime, actor_id, result)`**。policy は runtime primitives (registry / scheduler.current_tick / `runtime.schedule`) の上に順序規則を実装し、runtime/backend 内部には触れない。base は no-op (concrete が override; base instance 直接使用は EQM-020 で validation error)。
- **EQFixedRoundPolicy**: initiative を `actor_state.data[initiative_key]` (既定 &"initiative") から読む。
  - seed: round1 = 全 actor を `due_tick=1`, `priority=initiative`, `kind=&"turn"` で schedule。battle-start 順 = initiative DESC (EQOrdering)。
  - on_turn_finished: actor が登録済みなら次 round (`current_tick+1`) に同 priority で再投入。未登録なら何もしない (removal skip)。
- **順序は EQOrdering に委譲**: 同 round (同 due_tick) 内で priority(=initiative) DESC、同 initiative は sequence(登録順) ASC。初期化不要・決定的。
- **runtime 自動委譲は EQM-032 へ defer**。本 task は EQRuntime を変更しない (EQM-022 の mode/flow を保つ)。policy は test/consumer が seed + on_turn_finished を駆動。

## 不採用判断

- runtime 内部 (backend/_generation) への policy 直接アクセス。
- initiative の built-in field 化 (acceptance 定義、data 経由)。
- 本 task での EQRuntime.finish_action 改変 (EQM-032 で結線)。

## Invariants

- 同 initiative の actor は登録順 (sequence) で決定的に解決。
- round N は due_tick=N。round refresh は各 actor の current_tick+1 再投入で自動成立。
- removal: 登録解除された actor は on_turn_finished で再投入されず、pending event は runtime が skip (shipped) / halt (dev)。
- policy は core ordering を変えない (priority/sequence の int 規則をそのまま使う)。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| seed 順序 | round1 = initiative DESC, tie=登録順 | 非決定 tie | advance 列が initiative 順、同値は登録順 |
| round refresh | round2 = round1 と同順 | round 境界崩れ | 2 round 分の advance 列一致 |
| removal | 離脱 actor は以降 0 turn | 幽霊 turn | unregister 後 advance 列に不在 |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| 同 initiative | sequence(登録順) tie-break | 決定的全順序 | — | 同値2体の順序 |
| 離脱 actor | on_turn_finished で再投入しない + runtime skip | 幽霊 turn 防止 | — | shipped で removal skip |
| initiative 未設定 | data.get(key,0)=0 (最低) | 明示 default | — | 未設定 actor が最後 |
