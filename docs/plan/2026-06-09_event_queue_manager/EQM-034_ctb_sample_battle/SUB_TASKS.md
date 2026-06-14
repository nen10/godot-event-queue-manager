# EQM-034 SUB_TASKS

## Complexity

Class: C3
Reason:
- 初の demo (learning path) + quickstart docs + demo golden trace + test_project への demos symlink。
- 「sample-only completion 禁止 / sample は learning path」原則を初めて具体化。public API のみ使用を保証。

Required artifacts: Complexity header / Task Resolution / UX (最小) / POLICY / IMPLEMENTATION_PLAN。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| demos/ctb_battle (script + .tscn) | public API のみの CTB battle | adopt | EQManager + EQCTBPolicy + EQConfig。learning-path 明記。 |
| demo golden trace | demo の「動いた」を trace 一致で証明 | adopt | tests/golden/demo_ctb_battle.trace.jsonl (DETERMINISM §5)。 |
| quickstart.md | project-created config の手順 | adopt | bundled sample default に依存しない (UX_PATH_REDUCTION)。 |
| test_project/demos symlink | test から demo を res:// 到達 | adopt | addon symlink と同様。 |
| sample preset を production 既定にする | — | reject | sample は learning path のみ。production は project asset。 |
| demo に class_name 付与 | — | reject | API surface を汚さない。path load。 |

## Scheduled Task Audit

新規 scheduled task なし。EQM-034 完了で EQM-035 (v0.1 milestone 評価) と EQM-086 (editor UI contract) が解放。multi-genre demo suite は EQM-101。
