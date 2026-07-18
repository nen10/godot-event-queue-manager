# EQM-140 SUB_TASKS — sparse event-line polling

## Complexity

Class: C3

Reason:

- poll selectionとeffective-rate計算という二つのhot pathを、deterministic trace順を変えずに
  同時に派生stateへ移す。
- issue/re-rate/modifier add/remove/restoreの全mutation境界でcache invariantが必要になる。
- correctness回帰と独立performance A/Bを別laneで完了証拠にする。

Required artifacts:

- Task Resolution / Scheduled Task Audit
- UX Candidate Matrix
- State / Invariant Table
- Dependency / Test Matrix

## Task Resolution

| candidate | value | decision | reason |
|---|---|---|---|
| A. 毎pollで全lineをcontent-sort後にwatched filter | 実装単純 | reject | Wが小さくてもN全体に比例する |
| B. watched keyをlive lineへfilterしてcontent-sort | O(W log W) selection | adopt | 既存のline-id trace順を保てる |
| C. effective rateを毎lookupでmodifier全走査 | canonicalだけで完結 | reject | poll/authoring lookupがmodifier深さに比例する |
| D. canonical line payloadへeffective fieldを保存 | lookup O(1) | reject | snapshot/data-only schemaへ派生値を混ぜる |
| E. separate rebuildable effective-rate cache | lookup O(1)、schema不変 | adopt | canonical base/modifier配列から決定的に再構築できる |
| F. watched集合をrelation maintenanceまで拡張 | correctness候補 | defer | step_tick挙動を変えるため本performance taskへ混ぜない |

## Scheduled Task Audit

新しいscheduled taskは追加しない。

- relation maintenanceのLINE_THRESHOLD参照が現在の`_watched()`に含まれない点は既存の
  correctness候補だが、watch集合を広げるとline progression/traceが変わる。本taskは入力集合を
  厳密維持し、別の意味論監査と最小再現が得られた時だけ起票する。
- `ctx_lines()`の全line copyは別hot pathであり、本fixtureでは支配率を測らない。新しい
  EQM-local profileが出るまでqueue化しない。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| `_lines` | value/rate/modifier arrayのcanonical truth | cacheをserialize/canonical化 | snapshot/API audit |
| `_effective_rates` | existing lineごとにexactly one derived int | mutation後stale/missing key |全mutation transition regression |
| modifier array | Array順の最後のoverrideが勝つ | id sortで意味論drift | multiple override add/remove/restore |
| watched selection | membershipだけを使用、unknownはsilent除外、String content順 | value参照/挿入順/intern順drift | reversed insertion + false value + unknown trace parity |
| polling | effective 0はskip、negativeはadvance | baseだけを見て誤advance | add-to-zero/override-zero/negative regression |
| restore | trace/sweep rulesを保持しcacheをsilent rebuild | old cache key/trace noise | in-place restore regression |
