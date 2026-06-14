# EQM-021 UX

利用者 = addon consumer / EQM-022 facade。actor 登録と行動結果の型付き入口。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. register(actor_id) 重複は明示拒否 | high | low | low | adopt | silent overwrite を作らない。`duplicate_id`。 |
| B. actor_id 再利用も拒否 | high | low | low | adopt | semantics §13: identity 安定 (save/load・trace)。`id_reused`。 |
| C. finish_action は EQActionResult 型のみ | high | low | low | adopt | 生 Dictionary fallback 禁止 (UX_PATH_REDUCTION §2)。 |
| D. weak binding は WeakRef placeholder | high | low | low | adopt | Node 参照を保存形式に混ぜない。freed→null。 |
| E. per-entity WT/CT/AP を built-in field | low | high | med | reject | acceptance 定義 (Q16)。data Dictionary に委ねる。 |
| F. register が既存 id を上書き | low | high | low | reject | hack path。identity を壊す。 |

## User goal

actor_id で actor を登録し、重複・再利用・空 id は明示拒否される。行動結果は型付き EQActionResult で渡し、不正 (負 delay 等) は明示 validation。game 側 object は WeakRef で緩く束ね、消滅は null で表れる (保存形式には混ぜない)。

## Operation steps

1. `var reg := EQActorRegistry.new()`。
2. `var s := reg.register(&"hero")` → `EQActorState` (重複/再利用/空は null、`reg.validate_register(id)` で code)。
3. `s.bind(game_object)` → `s.is_bound()` / `s.bound()` (freed→null)。
4. `s.data` に acceptance 定義の進行/属性を置く (built-in field にしない)。
5. `var r := EQActionResult.new(); r.cost = 5; r.delay = 3; r.validate()`。

## Rejection tests

- register 重複 → null + `duplicate_id`。
- unregister 後の再 register → null + `id_reused`。
- 空 id register → null + `empty_id`。
- EQActionResult negative delay → `negative_delay`; negative cost (allow=false) → `negative_cost`。

## 既存 UX との干渉

新規 runtime class。EQM-020 の EQError/EQValidation を再利用。scheduler 等に影響なし。
