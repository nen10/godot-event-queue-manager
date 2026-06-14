# EQM-001 SUB_TASKS

## Complexity

Class: C2
Reason:
- devflow specialization (profile + test index) + 1 harness script。bounded。
- 採否のある選択は test.sh の Godot 欠如時挙動と profile の収録範囲のみ。状態境界は小さく fallback/mirror なし。

Required artifacts:
- Complexity header
- Task Resolution
- Scheduled Task Audit
- UX Candidate Matrix (UX.md)
- fallback/mirror 確認 (POLICY.md)

## Task Resolution

| 候補 | 目標/UX | 採否 | 概要 |
|---|---|---|---|
| fill PROJECT_PROFILE.md | autopilot が EQM の原則・gate・停止条件を 1 file で判断できる | adopt | 汎用 template を EQM 専用に書き換え、追加 policy 群を参照 |
| fill TEST.md | 標準検証コマンドと環境要件・test path を確定 | adopt | `./tools/test.sh`、Godot 4.x headless、python3、category 別 path |
| create tools/test.sh | Godot 欠如時に明確に exit する harness skeleton | adopt | env 検出、run-id 出力先、欠如時 BLOCKED_BY_TEST_ENV |
| adjust roadmap-autopilot SKILL.md | description の project wording、非線形 pattern への入口 | adopt | EQM 名称 + QUEUE_EXECUTION_PATTERNS 参照 |
| cross-ref 整合 | 参照先 process file が実在する | adopt | profile/TEST の参照を実ファイルへ |

## Scheduled Task Audit

新規 scheduled task なし。EQM-002 (addon scaffold) は既に queue 化済みで本 task の依存先。
