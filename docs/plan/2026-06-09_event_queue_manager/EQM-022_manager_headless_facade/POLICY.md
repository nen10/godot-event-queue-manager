# EQM-022 POLICY

## 採用判断

- **EQRuntime = headless facade**。scheduler (EQScheduler) + registry (EQActorRegistry) + 任意 config (EQConfig) + trace (EQTrace) を所有。scene tree 不要。EQManager node (EQM-032) はこの薄い wrapper。
- **二相 mode** (`Mode.DEV` 既定 / `Mode.SHIPPED`)。recoverability class に応じ:
  - dev: 異常を loud (push_error, `emit_engine_diagnostics` 既定 true) + `halted=true` で当該 advance を停止。**hard assert は使わない** (test/consumer を crash させない、可観測な停止)。
  - shipped: 該当 event を skip + `faults[]` log + trace `invalid_event_skipped` を残し継続。
- **mode neutrality**: 正常入力では fault が発生せず、dev/shipped の trace は byte 一致 (RUNTIME_RESILIENCE §2)。異常時のみ挙動が割れる。
- **どの mode でも silent 飲み込みなし**: 異常は必ず `faults[]` に構造化記録、shipped は trace record も残す。
- **finish_action は EQActionResult のみ**。result.validate() を通し、不正は両 mode で next-event を schedule しない (dev は halt + loud)。
- **delay は result 駆動** (policy 連動 delay 計算は Phase3)。config/policy は start() の validation slot + 将来 hook。

## 不採用判断

- hard assert による dev 停止 (検証不能・consumer 巻き込み)。
- 異常の silent skip (log/trace なし)。
- 生 Dictionary finish_action。
- shipped mode で scheduler 状態を破壊する skip (sequence/generation/snapshot 整合を保つ)。

## Resource / API / UI 境界

- **public**: `EQRuntime` (mode, register_actor, start, schedule, advance, finish_action, trace, trace_jsonl, faults, halted, scheduler, registry)。
- **internal**: `_handle_fault`, `_trace`, decided_by 算出。
- UI 無し (headless)。EQManager node が signal 化 (EQM-032)。

## Invariants

- 正常 path の結果は mode 不変 (dev trace == shipped trace, byte)。
- shipped の skip/invalidate は trace に現れ、同入力で再現 (resilience は非決定性の言い訳にしない)。
- shipped mode は scheduler 整合 (sequence/generation/snapshot) を破壊しない。
- 異常は静かに飲み込まない (dev 停止+loud / shipped log+trace)。
- finish_action の不正 result は両 mode で next event を作らない。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| `mode` | 正常入力で挙動不変 | mode で正常結果が割れる | 同一操作列 → dev/shipped trace byte 一致 |
| `halted` (dev) | dev 異常で停止・可観測 | hard assert で crash | 異常注入 → halted=true, 後続 advance=null, faults 記録 |
| shipped skip | 該当 event のみ drop、継続 | 状態破壊 / silent | 異常注入 → invalid_event_skipped trace + 継続 + snapshot roundtrip 整合 |
| `faults[]` | 異常は必ず記録 | silent 飲み込み | 両 mode で fault が 1 件記録 |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| unregistered actor の event を advance | dev: halt+loud / shipped: skip + invalid_event_skipped + continue | contract_violation。RUNTIME_RESILIENCE §1 | — | 両 mode で挙動差 + 共通 fault 記録 |
| 不正 EQActionResult を finish | 両 mode で next event 不生成、dev は halt | negative delay 等は契約違反 | — | finish に bad result |
| dev mode の loudness | `emit_engine_diagnostics` (既定 true) | dev fail-fast は可視。test は false で log 清浄 | — | flag off で fault 記録のみ確認 |
| config 不在 | start() は空 EQValidation (異常でない) | config は任意 (scene-local 既定) | — | config なし start で valid |
