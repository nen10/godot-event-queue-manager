# EQM-011 UX

API 利用者 (addon consumer / 後続 task) から見た最小操作 surface。これは L0/L1 surface の土台 (roadmap §3.1)。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. push が event_id を返す | high | low | low | adopt | cancel/reschedule の handle が必要。caller が id を発明しなくて済む。 |
| B. caller が event_id を渡す | medium | medium | low | reject | 重複/衝突を caller に押し付ける。採番は scheduler の責務。 |
| C. cancel/reschedule を event_id key にする | high | low | low | adopt | acceptance 記載。安定 identity。 |
| D. reschedule で due_tick を直接書換 | low | high | low | reject | EVENT_MODEL の due_tick 直接書換禁止。cancel+re-push に統一。 |
| E. peek(N) を非破壊にする | high | low | low | adopt | HUD/prediction (EQM-033) が live queue を壊さず覗ける。 |

## User goal

scheduler に event を入れ、決定的順序で取り出し、未解決 event を取消/再スケジュールし、次に何が来るかを覗ける。Godot scene 無し (headless) で完結する。

## Operation steps

1. `var s := EQScheduler.new()` — 既定 backend は sorted-array。`EQScheduler.new(custom_backend)` で差し替え可能。
2. `var id := s.push(due_tick, priority, kind, actor_id, payload)` — 採番された `event_id` を得る。負 tick は `-1` (明示拒否、silent fallback なし)。
3. `s.peek_next()` / `s.peek(n)` — 取り出さずに次/先頭N件を見る。
4. `s.pop()` — 最小 entry を取り出す。`current_tick` がその `due_tick` へ前進。空なら `null`。
5. `s.cancel(id)` — live なら取消し `true`。未知/取消済みは `false`。
6. `s.reschedule(id, new_due_tick, new_priority := <維持>)` — 同 id で再投入。旧 entry は stale 化。

## 採用 / 廃止

- 採用: event_id 返却、非破壊 peek、lazy cancel、reschedule-only な tick 変更。
- 廃止 (hack 化しない): due_tick 直接書換、caller 採番 id、cancel 時の即時中身削除。

## 既存 UX との干渉

なし。EQM-010 の EQEntry/EQOrdering を内部利用するのみ。public surface は EQScheduler に新規追加。
