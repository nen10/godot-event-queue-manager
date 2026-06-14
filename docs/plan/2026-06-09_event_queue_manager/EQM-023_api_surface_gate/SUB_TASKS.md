# EQM-023 SUB_TASKS

## Complexity

Class: C3
Reason:
- python gate tool + golden + 文書 + test.sh 結線にまたがる process gate。
- **layer-aware** (L0-L3) surface 抽出と **L3 leak 検出**という横断契約。golden 承認フロー (明示 flag のみ更新)。

Required artifacts: Complexity header / Task Resolution / Scheduled Task Audit / UX (最小) / POLICY / IMPLEMENTATION_PLAN (dependency/test matrix)。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| check_api_surface.py | public surface を deterministic 抽出 + golden 比較 | adopt | class_name + public member (非 `_`)。layer tag。sorted JSON。 |
| layer map (tool 内 dict) + API_SURFACE.md | class→layer の単一権威 + 人間文書 | adopt | core/L0/L1/L2/L3。未 map の public class は FAIL (層割当を強制)。 |
| L3 leak 検出 | L0/L1 の public signature に L3 型が出たら FAIL | adopt | 現状 L3 不在で trivially pass。`--self-test` で検出器を毎回証明。 |
| golden 明示更新 | 通常 run は read-only 比較 | adopt | `--update` flag のみ再生成 (DETERMINISM policy 同趣旨)。 |
| source に `## @layer` tag を全 file 付与 | — | reject | 14 file churn。tool 内 map + golden 二重チェックで drift は golden diff が捕捉。 |
| 通常 run で golden 自動更新 | — | reject | 明示 flag のみ。 |

## Scheduled Task Audit

新規 scheduled task なし。EQM-023 完了で **Phase 2 (resource/API) milestone**。次フロンティアは Phase 3 (EQM-030 fixed round policy)。L2/L3 class は Phase 5 (EQM-050+) で追加され、その時に layer map / golden / leak 検出が実効化する。
