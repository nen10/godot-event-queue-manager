# EQM-020 IMPLEMENTATION_PLAN

## Scope

EQConfig / EQPolicy base Resource と validation、error taxonomy (EQError + EQValidation + ERROR_CONTRACT.md) を実装する。concrete policy (Fixed/CTB) は Phase3。mode toggle の実行 (dev assert / shipped skip) は EQM-022。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_error.gd` — `EQError`: Recoverability/Severity enum、stable code 定数、code→metadata、recoverability_of/severity_of/surfaces_in/is_known。
- `addons/event_queue_manager/runtime/eq_validation.gd` — `EQValidation`: add/is_valid/errors/warnings/codes。
- `addons/event_queue_manager/resources/policies/eq_policy.gd` — `EQPolicy extends Resource`: policy_name。
- `addons/event_queue_manager/resources/eq_config.gd` — `EQConfig extends Resource`: policy/tie_break/schema_version、validate()→EQValidation。
- `docs/design/ERROR_CONTRACT.md` — taxonomy 文書。
- `test_project/tests/resource/test_eq_error_taxonomy.gd` — code metadata + EQValidation 集約。
- `test_project/tests/resource/test_eq_config.gd` — roundtrip + validation (missing/base/ambiguous/unknown/valid)。

## 実装 steps

1. `EQError` (enum + codes + metadata + accessors)。
2. `EQValidation` (issue 集約)。
3. `EQPolicy` base、`EQConfig` (validate は EQError code を使用、base-instance を preload 比較で検出)。
4. `ERROR_CONTRACT.md` (code 表 + recoverability→dev/shipped 表 + 安定性約束)。
5. resource tests (taxonomy + roundtrip + rejection)。
6. `./tools/test.sh` PASS を確認。

## Test path / gate

- §4 gate (resource/API): roundtrip + validation。layer-aware API surface (EQM-023) は後続。
- `./tools/test.sh` → import → runner。期待: 既存 92 + 新 checks 全 pass、exit 0。

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| RUNTIME_RESILIENCE_POLICY §1 | recoverability class 不一致 | EQError の 4 class が policy 表と一致、code→class を assert |
| UX_PATH_REDUCTION | 入口が広い/ fallback 残存 | rejection test (null/base/ambiguous/unknown) |
| EVENT_MODEL_SEMANTICS §12 | tie_break/数値域 契約乖離 | tie_break 既知集合 = 決定的 total、int 域宣言 |
| `.tres` 直列化 | roundtrip 欠落 | save/load 後フィールド保存 assert |
| EQM-012 schema_version 整合 | config 版管理欠如 | EQConfig.schema_version フィールド存在 |

## Completion checklist

- [ ] EQError: 4 recoverability class + stable codes + metadata accessors。
- [ ] EQValidation: is_valid/errors/warnings/codes。
- [ ] EQConfig.validate: missing/base/ambiguous/unknown を検出、valid config は issue 空。
- [ ] `.tres` roundtrip で policy/tie_break/schema_version 保存。
- [ ] ERROR_CONTRACT.md に code 表 + recoverability→dev/shipped + 安定性約束。
- [ ] rejection tests 4 種。
- [ ] `./tools/test.sh` PASS。
