# EQM-020 POLICY

## 採用判断

- **error taxonomy = EQError が単一権威**。code は **namespaced StringName** (`eqm.<area>.<name>`)、**append-only** (再利用・意味変更しない)。trace 安定・人間可読・version 跨ぎ安定。各 code に recoverability / severity / surfacing を付与。
- **recoverability 4 class** は `RUNTIME_RESILIENCE_POLICY` §1 に一致: `CONTRACT_VIOLATION` / `BUDGET_EXCEEDED` / `RESOURCE_INVALID` / `EXTERNAL_STATE`。各 class の dev/shipped 既定挙動を ERROR_CONTRACT.md に記す。
- **severity** = `{WARNING, ERROR}`。is_valid は ERROR が無いこと。
- **surfacing** = `{editor, game}` の集合。config validation 系は両方に出る。
- **validate() は報告のみ**。`EQValidation` を返し、自身は crash/skip しない。dev fail-fast (assert) / shipped fail-safe (skip+log) の **実行**は EQM-022 (mode toggle) が recoverability を見て行う。層を分離する。
- **EQPolicy = 拡張点 base** (UX_PATH_REDUCTION §4)。concrete subclass のみ完走保証。base instance 直接使用は `POLICY_BASE_INSTANCE` (contract_violation)。
- **EQConfig** は `policy` (EQPolicy) と `tie_break` (StringName) と `schema_version` を持つ。validate は missing/base/ambiguous/unknown を検出。

## 不採用判断

- validate 内 crash/skip (層越境。EQM-022 の責務)。
- policy slot に Resource 全般受け入れ / silent sample fallback (UX_PATH_REDUCTION 違反)。
- int error code (trace/版安定性で StringName 劣後)。

## Resource / API / UI 境界

- **public**: `EQConfig` (policy, tie_break, schema_version, validate→EQValidation)、`EQPolicy` (policy_name)、`EQError` (codes, recoverability_of, severity_of, surfaces_in, is_known)、`EQValidation` (add, is_valid, errors, warnings, codes)。
- **internal**: code→metadata map、base-instance 判定。
- UI 無し (Resource 層)。editor surfacing は EQM-090+ が EQValidation を projection。

## Invariants

- 同 code は常に同 recoverability/severity (taxonomy は単一権威)。
- validate は副作用なし・決定的。`.tres` roundtrip で policy/tie_break/schema_version 保存。
- code は append-only (除去・意味変更しない)。
- 正常 config の validate は is_valid=true、issue 空 (false error を出さない)。
- L1 surface に L2/L3 概念を leak させない。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| `EQConfig.policy` | concrete EQPolicy のみ valid。null/base は error | silent default / 完走非保証経路 | rejection test: null→POLICY_MISSING、base→POLICY_BASE_INSTANCE |
| `EQConfig.tie_break` | 既知 total 集合のみ valid | 非決定 tie / ambiguous | rejection: &""→AMBIGUOUS、&"bogus"→UNKNOWN; 既定 &"sequence" valid |
| `EQError` code metadata | code→recoverability/severity が固定 | 不整合な分類 | 各 code の recoverability/severity/surfaces を assert |
| `.tres` roundtrip | 保存→読込でフィールド保存 | 直列化欠落 | save/load 後 tie_break/schema_version/policy 存在 assert |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| policy 未設定 | `POLICY_MISSING` 明示 (fallback なし) | no-fallback-chain | — (恒久) | null policy validate |
| base EQPolicy 直接使用 | `POLICY_BASE_INSTANCE` | base は拡張点、完走非保証 | concrete subclass 登場後も維持 | base instance validate |
| tie_break 未選択 | `TIE_BREAK_AMBIGUOUS` | 非決定を黙認しない | — | &"" validate |
| 未知 tie_break | `TIE_BREAK_UNKNOWN` | 未知値を黙認しない | 集合拡張時は code 据置 | &"bogus" validate |
