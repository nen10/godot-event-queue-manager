# EQM-032 UX

利用者 = game developer (L0 flow: register → turn_ready → finish)。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. scene-local EQManager Node (autoload 任意) | high | low | low | adopt | profile 既定。autoload は opt-in。 |
| B. signal で turn_ready / event_resolved | high | low | low | adopt | Godot idiom。consumer は signal を聴く。 |
| C. finish_action が policy へ自動委譲 | high | low | low | adopt | L0 で policy 詳細を見せない。 |
| D. turn_ready 後 suspend (入力待ち) | high | low | low | adopt | player turn の await boundary。 |
| E. advance_frame(budget) for hitch 回避 | high | low | low | adopt | large battle を time-slice。order 不変。 |
| F. Node が暗黙に毎 frame auto-drive | low | med | low | reject(default) | 明示 advance。auto-drive は将来 opt-in。 |

## User goal

`EQManager` を scene に置き actor を register、policy を選ぶと、`turn_ready` で行動可能になり、`finish_action` で次が自動 schedule され、`event_resolved`/`timeline_advanced` で進行が観測できる。large battle は `advance_frame(budget)` で frame 予算内に区切れ、順序は不変。

## Operation steps

1. `var m := EQManager.new()` (scene-local; autoload 不要)。
2. `m.configure(config)` または `m.set_policy(EQCTBPolicy.new())`。
3. `m.register_actor(&"hero").data["speed"]=10` …。
4. `m.seed()`。
5. signal 接続: `m.turn_ready.connect(...)`, `m.event_resolved.connect(...)` 等。
6. `m.step()` → turn_ready で suspend → `m.finish_action(actor, result)` → 次へ。
7. 非対話イベントは `m.advance_frame(budget)` で一括解決。

## driver / await 契約

`EVENT_MODEL_SEMANTICS.md` §14 に記載 (who advances=consumer / suspend=turn_ready後 / await boundary=event_resolved↔next / frame-budget)。本 task で EQManager の実 API に整合させる。

## 既存 UX との干渉

新規 Node。EQRuntime を wrap (内部不変)。plugin に custom type 登録。API surface 変更 → golden 更新。
