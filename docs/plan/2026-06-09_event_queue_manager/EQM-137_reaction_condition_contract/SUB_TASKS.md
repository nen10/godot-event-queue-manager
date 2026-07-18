# EQM-137 SUB_TASKS — reaction-condition contract hardening

## Complexity

Class: C3

Reason:

- public L2 submit/trigger boundaries、runtime resilience、error taxonomy、consumer integration
  proofを横断する。
- invalid inputの状態非変更とdev/shipped二相を同時に固定する必要がある。
- 正常trigger lifecycleとsnapshot/traceを変えないことをfull regressionで証明する。

Required artifacts:

- Task Resolution / Scheduled Task Audit
- UX Candidate Matrix
- State / Invariant Table
- Dependency / Test Matrix

## Task Resolution

| candidate | value | decision | reason |
|---|---|---|---|
| A. `EQReservationRuntime.submit()`だけで型検査 | authoritative consumer boundaryを安全化 | reject alone | direct `EQTriggerEngine` / index callerがghost stateを作れる |
| B. submit + engine + indexの三層で明示拒否 | structured faultの権威を1箇所に保ちつつ派生層も壊れない | adopt | runtimeはfault、low-levelはbool/-1で副作用なしに拒否できる |
| C. `EQConditionSpec`をtrigger matcherへ変換 | 旧EBS testをそのまま通す | reject | pending solve/invalidationとevent triggerの意味を混同し、保存契約も曖昧になる |
| D. named trigger predicateを新設 | durable spatial triggerを直接表現 | defer | 現需要はnormalized event tags + `EQCondition`で書ける。definition側named gateは現行FIRE pipelineに未統合なので独立修理taskとし、本taskのproofに混ぜない |
| E. invalid submitをfaultだけで記録 | 最小差分 | reject | shipped anomalyのtrace証拠が残らない |
| F. `reservation_rejected` traceを記録 | fake eventを作らずpre-submit rejectionを説明 | adopt | resilience policyのlog + traceを満たし、正常traceは不変 |

## Scheduled Task Audit

新しいscheduled taskはない。wildcard candidate merge、relation adjacency、sparse event-line
pollingは既にEQM-138〜140としてqueue化済み。reaction definitionのsolve/invalidationを
FIRE occurrenceへ適用する既存R04意味論のgapは独立follow-upに記録する。durable named
trigger predicateは具体的なsave/load需要が発生するまでdeferし、自動起票しない。
