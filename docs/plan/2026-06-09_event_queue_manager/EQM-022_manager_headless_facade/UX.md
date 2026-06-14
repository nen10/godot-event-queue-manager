# EQM-022 UX

利用者 = addon consumer (game loop) / EQManager node (EQM-032)。L0/L1 surface の中核 facade。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. headless facade (scene 不要) | high | low | low | adopt | core test 可能・serializable。EQManager node はこの薄い wrapper。 |
| B. mode は明示設定 (既定 dev) | high | low | low | adopt | silent 自動判定しない (UX_PATH_REDUCTION 同趣旨)。 |
| C. finish_action(EQActionResult) | high | low | low | adopt | 生 Dictionary fallback 禁止。 |
| D. 異常は faults[] + trace に必ず残す | high | low | low | adopt | どの mode でも silent 飲み込みなし。 |
| E. dev mode を hard assert 停止 | low | high | low | reject | 検証不能・consumer game も巻き込む。`halted` flag で表現。 |

## User goal

scene 無しで actor を登録し、queue を start し、ready event を pop し、行動を finish して次 event を schedule できる。dev mode では異常で即停止し可視化され、shipped mode では該当 event を skip+log して game を落とさず継続する。正常入力なら両 mode の trace は byte 一致する。

## Operation steps

1. `var rt := EQRuntime.new(config, EQRuntime.Mode.DEV)`。
2. `rt.register_actor(&"hero")` …。
3. `rt.start()` → config validation (任意)。
4. `rt.schedule(&"hero", 1)` で初期 event 投入。
5. `var e := rt.advance()` で ready event を解決 (trace に記録)。
6. `rt.finish_action(&"hero", EQActionResult.new(cost, delay))` で次 event を `current_tick+delay` に schedule。
7. `rt.trace_jsonl()` で canonical trace。`rt.faults` / `rt.halted` で異常状態。

## 既存 UX との干渉

新規 facade。scheduler/registry/config/trace を所有・結線。public surface は EQM-023 が snapshot gate にかける。
