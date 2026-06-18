# EQM-086 SUB_TASKS

## Complexity

Class: C3 (orchestrator-direct — UI 契約 = 設計、M0 docs-only)
Reason:
- editor UI の source-of-truth 契約 (surfaces / 必須 component / 禁止 visible text / state matrix / threshold) を確立。EQM-087/090/091/093/094/095 が乗る。
- docs-only (Godot run 不要、§4 gate=契約整合)。

Required artifacts: Complexity header / Task Resolution / IMPLEMENTATION_PLAN。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EDITOR_UI_CONTRACT.md | surface ごとの目的/必須 component/禁止 text/scroll/primary action/empty/threshold | adopt | timeline_dock / order_inspector / config_panel / template_generator / calibration_tab。§9 初期 threshold を保持。 |
| EDITOR_STATE_MATRIX.md | scenario state ごとの期待表示/禁止表示/modality | adopt | §4.4 states を期待 icon/badge/empty で記述。 |
| 初期 threshold を policy から契約へ移設 | 移植性 | adopt | policy は数式のみ、数値は契約 (UI_TESTABILITY §4)。 |

## Scheduled Task Audit

新規 scheduled task なし。次の依存解放は EQM-087 (UI metric harness, M1-M3)。
