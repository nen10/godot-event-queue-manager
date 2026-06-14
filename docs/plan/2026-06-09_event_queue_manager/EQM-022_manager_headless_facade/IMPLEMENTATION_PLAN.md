# EQM-022 IMPLEMENTATION_PLAN

## Scope

EQRuntime headless facade と dev/shipped resilience 二相 toggle を実装する。policy 連動 delay 計算は Phase3。node signal 化は EQM-032。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_error.gd` — runtime code を append (`eqm.runtime.unregistered_actor_event`, `eqm.runtime.schedule_unregistered_actor`)。
- `addons/event_queue_manager/runtime/eq_runtime.gd` — `EQRuntime`。
- `docs/design/ERROR_CONTRACT.md` — runtime code 追記。
- `test_project/tests/core/test_eq_runtime.gd` — register/start/schedule/advance/finish の基本フロー + 二相 resilience + mode neutrality + shipped 後の snapshot 整合。

## 実装 steps

1. EQError に runtime code 2 つ append + ERROR_CONTRACT.md。
2. EQRuntime: mode/registry/scheduler/config/trace/faults/halted; register_actor/start/schedule/advance/finish_action; `_handle_fault` (dev halt+loud / shipped log+continue)。
3. tests: 基本フロー、mode neutrality (正常入力 dev==shipped trace)、resilience (unregistered actor event を両 mode、finish 不正 result)、shipped skip 後の snapshot roundtrip 整合。
4. `./tools/test.sh` PASS。

## Test path / gate

- §4 gate (runtime/integration): dev/shipped 二相 resilience test + mode neutrality + node-bridge は EQM-085 (本 task は headless)。
- `./tools/test.sh` 期待: 既存 167 + 新 checks 全 pass、exit 0。dev fault 注入 test は `emit_engine_diagnostics=false` で log 清浄。

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| EQScheduler/EQTrace (EQM-011/013) | 結線で順序/trace 崩れ | 基本フローの trace が EQOrdering 順 |
| EQActorRegistry (EQM-021) | actor 結線漏れ | unregistered actor event の検出 |
| RUNTIME_RESILIENCE §2/§3 | mode で正常結果が割れる / silent skip | mode neutrality (byte 一致) + 両 mode fault 記録 + shipped 後 snapshot 整合 |
| EQActionResult (EQM-021) | 不正 result が通る | finish 不正で next event 不生成 |
| EQError taxonomy | runtime 異常未分類 | 新 runtime code の recoverability assert |

## Completion checklist

- [ ] register/start/schedule/advance/finish の基本フローが scene 無しで動く。
- [ ] mode toggle: dev=halt+loud / shipped=skip+log+trace+continue。
- [ ] mode neutrality: 正常入力で dev/shipped trace が byte 一致。
- [ ] 異常は両 mode で faults[] に記録 (silent 飲み込みなし)。
- [ ] shipped skip 後も scheduler snapshot roundtrip 整合。
- [ ] finish 不正 result で next event を作らない。
- [ ] 新 runtime code が ERROR_CONTRACT.md と EQError に存在。
- [ ] `./tools/test.sh` PASS。
