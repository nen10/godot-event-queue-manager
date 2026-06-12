# Reusable Devflow Pack

目的: 既存 addon 開発リポジトリで機能した Roadmap / Queue / Autopilot 開発プロセスを、別コンセプトの新規プロジェクトへ移植しやすい形に抽象化する。

## 構成

```text
.agents/skills/roadmap-autopilot/SKILL.md
  Codex / agent が読む短い入口。

docs/devflow/
  README.md
  LINEAR_AUTOPILOT_QUEUE.md
  PROJECT_PROFILE.md
  QUEUE_OPERATION_RULES.md
  TASK_PACKET.md
  TEST.md
  PORTING_CHECKLIST.md

  examples/
    PROJECT_PROFILE.godot-addon-hex-map.example.md

  policy/
    README.md
    ANALOG_TEST_POLICY.md
    ROADMAP_POLICY.md
    IMPLEMENTATION_QUEUE_DESIGN_POLICY.md
```

## 使い方

1. この pack を新規プロジェクトまたは addon リポジトリへコピーする。
2. `docs/devflow/PROJECT_PROFILE.md` に project 固有の domain、product principles、test command、forbidden defaults を埋める。
3. `.agents/skills/roadmap-autopilot/SKILL.md` の description と read order を必要に応じて調整する。
4. feedback / concept / approved brainstorm を入力にして `docs/plan/<YYYY-MM-DD>_<ROADMAP_ID>/ROADMAP.md` を作る。
5. `docs/plan/<YYYY-MM-DD>_<ROADMAP_ID>/ROADMAP.md` から `docs/plan/<YYYY-MM-DD>_<ROADMAP_ID>/IMPLEMENTATION_QUEUE.md` を作る。
6. Queue の `READY` task を順次実装する。

## 基本思想

- `.agents/skills/roadmap-autopilot/SKILL.md` は短い dispatcher にする。
- 判断基準は `docs/devflow/policy/` に置く。
- 実行手順は `docs/devflow/` に置く。
- プロジェクト固有の価値観は `docs/devflow/PROJECT_PROFILE.md` に置く。
- Roadmap と Queue は別成果物にする。
- Task packet は実装中の局所判断に使う。
- Self-review と test result は proof であり、恒久仕様ではない。
