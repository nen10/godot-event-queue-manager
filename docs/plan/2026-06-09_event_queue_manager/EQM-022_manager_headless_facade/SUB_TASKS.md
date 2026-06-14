# EQM-022 SUB_TASKS

## Complexity

Class: C3
Reason:
- 既存 core 全体 (scheduler / registry / config / action result / error taxonomy / trace) を 1 facade に結線する統合 task。
- **dev/shipped resilience 二相 toggle** を初めて実装し、recoverability class に応じた挙動 (dev 停止 / shipped skip+log+continue) と **mode neutrality** (正常入力 trace は mode 不変) を保証する。
- fallback/mirror (resilience modes) と state/invariant を扱う → Fallback/Mirror table 必須。

Required artifacts: Complexity header / Task Resolution / Scheduled Task Audit / UX / POLICY (Fallback/Mirror + State/Invariant) / IMPLEMENTATION_PLAN (dependency/test matrix)。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQRuntime (headless facade) | register/start/advance/finish_action を scene 無しで結線 | adopt | scheduler + registry + (任意) config を所有。trace 記録。 |
| dev/shipped mode toggle | recoverability に応じ dev=停止+loud / shipped=skip+log+continue | adopt | `mode` + `faults[]` + `halted`。異常注入時のみ挙動が割れる。 |
| mode neutrality | 正常入力で dev/shipped trace が byte 一致 | adopt | 同一操作列を両 mode で実行し trace_jsonl 比較。 |
| finish_action は EQActionResult のみ | 生 Dictionary 禁止 | adopt | UX_PATH_REDUCTION §2。result.validate を通す。 |
| dev mode を hard assert で停止 | — | reject | test harness を crash させ検証不能。`halted` flag + (任意) push_error で「停止かつ可観測」にする。 |
| concrete policy で delay 計算 | — | defer | Phase3。本 task は result.delay 駆動。policy は validation slot + 将来 hook。 |
| 異常を silent 飲み込み | — | reject | RUNTIME_RESILIENCE §2。dev は loud、shipped は必ず log+trace。 |

## Scheduled Task Audit

新規 scheduled task なし。次の依存解放は EQM-023 (API surface gate)。EQRuntime が L0-L3 の public surface 集約点になるため EQM-023 の surface 抽出対象。policy 連動 delay は Phase3 (EQM-030+)。
