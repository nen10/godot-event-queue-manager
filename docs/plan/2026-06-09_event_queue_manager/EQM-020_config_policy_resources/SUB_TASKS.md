# EQM-020 SUB_TASKS

## Complexity

Class: C3
Reason:
- 複数ファイル (EQConfig + EQPolicy base + error taxonomy code + ERROR_CONTRACT.md + tests)。
- **error taxonomy 契約** (stable codes / recoverability class / surfacing) を確立し、EQM-022 (resilience modes) と以降の runtime/validation 全てが乗る。
- UX_PATH_REDUCTION (single accepted class / no fallback chain) と RUNTIME_RESILIENCE (4 recoverability class, dev/shipped) の双方を初めて具体実装に落とす。

Required artifacts: Complexity header / Task Resolution / Scheduled Task Audit / UX Candidate Matrix / POLICY (Invariant + Fallback/rejection table) / IMPLEMENTATION_PLAN (dependency/test matrix)。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQError (taxonomy) | stable code + recoverability + severity + surfacing の単一権威 | adopt | namespaced StringName code、append-only。`runtime/eq_error.gd`。 |
| EQValidation (result) | validate() の戻り型。issue 集約 | adopt | `runtime/eq_validation.gd`。errors/warnings/codes/is_valid。 |
| EQPolicy (base Resource) | 順序 policy の拡張点 base | adopt | `resources/policies/eq_policy.gd`。policy_name。Phase3 の concrete が継承。base instance 直接使用は validation error。 |
| EQConfig (Resource) | policy + tie_break を持つ設定 Resource | adopt | `resources/eq_config.gd`。`.tres` roundtrip、validate()。 |
| ERROR_CONTRACT.md | taxonomy 文書 | adopt | code 表 + recoverability→dev/shipped 表 + 安定性約束 + validation 連携。 |
| validate() が自分で crash/skip する | — | reject | validate は **報告**のみ (EQValidation 返却)。dev assert / shipped skip の実行は EQM-022 (mode toggle)。層分離。 |
| policy slot に Resource 全般を受ける | — | reject | UX_PATH_REDUCTION single-accepted-class: EQPolicy concrete のみ。null/base は明示 error。 |
| 未設定時に sample policy へ silent fallback | — | reject | no-fallback-chain: 明示 "not configured" (POLICY_MISSING)。 |
| int error code | — | reject | StringName namespaced code の方が trace 安定・人間可読・version 跨ぎで安定。 |

## Scheduled Task Audit

新規 scheduled task なし。次の依存解放は EQM-021 (actor/action API)。EQError/EQValidation は EQM-021 (actor 重複登録 etc.) と EQM-022 (mode toggle) が再利用する。
