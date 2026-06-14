# EQM-021 POLICY

## 採用判断

- **EQActorState** = serializable identity (`actor_id`) + acceptance-defined `data: Dictionary` + **transient** `_binding: WeakRef`。to_dict/from_dict は actor_id + data のみ (Node 参照を保存形式に混ぜない、Adapter 原則)。bind/bound/is_bound が weak-binding placeholder。
- **EQActionResult** = `cost` / `delay` / `allow_negative_cost`。validate() は delay<0 を常に不正 (timeline を逆行させる → CONTRACT_VIOLATION)、cost<0 は allow_negative_cost=false のとき不正 (RESOURCE_INVALID; semantics §12 「負 AP は policy 宣言制」)。
- **EQActorRegistry** = actor_id 登録の単一所有。重複 (active) と再利用 (retired) を区別して拒否。register は成功で EQActorState、拒否で null。validate_register が code を返す。
- **actor_id 再利用禁止** (semantics §13/Q10): unregister 後も id を retired として記憶し再登録を拒否 (`id_reused`)。これは `tie_break=&"actor_id"` の total 性 (EQM-020) の裏付けでもある。
- 新 EQError code は **append-only** で追加: `eqm.actor.duplicate_id` (CONTRACT_VIOLATION) / `eqm.actor.id_reused` (CONTRACT_VIOLATION) / `eqm.actor.empty_id` (RESOURCE_INVALID) / `eqm.action.negative_delay` (CONTRACT_VIOLATION) / `eqm.action.negative_cost` (RESOURCE_INVALID)。

## 不採用判断

- per-entity 進行 (WT/CT/AP) の built-in field 化 (Q16: acceptance 定義、data に委ねる)。
- 生 Node 参照の state 保持 (WeakRef のみ transient)。
- register の silent overwrite / 再利用許可 (identity を壊す)。
- finish_action の生 Dictionary 受け入れ (EQActionResult 型のみ)。

## Resource / API / UI 境界

- **public**: `EQActorState` (actor_id, data, bind/bound/is_bound, to_dict/from_dict)、`EQActionResult` (cost, delay, allow_negative_cost, validate)、`EQActorRegistry` (register, validate_register, is_registered, get_state, unregister, actor_ids, size)。
- **internal**: `_active` / `_retired` map、`_binding`。
- UI 無し。

## Invariants

- actor_id は session 内で一意・不再利用 (active ∪ retired にある id は再登録不可)。
- 保存形式 (to_dict) は live Node/Object 参照を含まない。
- EQActionResult.validate は副作用なし・決定的。delay>=0 は常時不変条件。
- register 拒否時は registry 状態不変 (size 不変)。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| registry `_active`/`_retired` | id は一意・不再利用 | silent overwrite / identity 衝突 | 重複→duplicate_id、unregister 後再登録→id_reused、size 不変 |
| `EQActorState._binding` | transient、to_dict に出ない、freed→null | Node 参照が save に漏れる | to_dict に binding key 無し; freed object で bound()=null |
| `EQActionResult` | delay>=0 常時、cost<0 は policy 宣言時のみ可 | timeline 逆行 / 数値域違反 | negative_delay、negative_cost(allow 切替)、valid |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| 重複 register | null + `duplicate_id` | silent overwrite 禁止 | — | register x2 |
| 再利用 register | null + `id_reused` | identity 安定 (§13) | — | unregister→register |
| 空 id | null + `empty_id` | 無効 identity 拒否 | — | register("") |
| negative delay | `negative_delay` | timeline 逆行不可 | — | delay=-1 validate |
| negative cost | `negative_cost` (allow_negative_cost で解除) | §12 policy 宣言制 | policy が refund を宣言 | cost=-1 allow on/off |
