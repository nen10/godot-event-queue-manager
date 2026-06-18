# EQM-080 UX

利用者 = game developer (simulation 効果記録 + 視覚要求の分離)。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. EffectRecord は即時・決定的・trace | high | low | low | adopt | simulation truth、neutrality の anchor。 |
| B. PresentationEvent は別 queue (deferrable) | high | low | low | adopt | 視覚は後段で flush 可、simulation を歪めない。 |
| C. position は queue 時点の値 snapshot | high | low | low | adopt | EQM-082 barrier が位置比較可能。live Node を保存形式に入れない。 |
| D. classification は consumer 供給 | high | low | low | adopt | Q12 simulation 側、addon は spatial 非計算。 |
| E. chunk 空 = save 可 | high | low | low | adopt | §10/§22 save 境界を結線。 |

## User goal

action 解決時に effect (damage/status 等) が即時・決定的に EffectRecord として記録され trace に乗る。視覚は EQPresentationEvent として別 queue に積まれ、後段の flush policy が defer/skip しても simulation は不変。effect-chunk が空のとき save 可能 (is_save_allowed)。

## Operation steps

1. 解決時: `var r := EQEffectRecord.new(); r.kind=&"damage"; r.target=&"hero"; r.stat=&"hp"; r.delta=-12; r.classification=EQEffectRecord.CLASS_IMPORTANT`。
2. `chunk.add(r)` (蓄積); trace へ `trace.record(r.to_trace_record())`。
3. 視覚: `var pe := EQPresentationEvent.new(); pe.actor_id=&"hero"; pe.position=<value>; pe.classification=...` → buffer (EQM-081)。
4. save 判定: `chunk.is_save_allowed()` (空なら可)。drain で次フェーズへ。

## 既存 UX との干渉

新規 core (EffectRecord/Chunk) + presentation (PresentationEvent)。EQTrace open-kind schema を利用。L0/L1 不変。API surface に presentation layer 追加。
