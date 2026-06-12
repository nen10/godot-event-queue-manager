# Analog Test Policy

## Purpose

ユーザーが明示した場合に、Editor の実操作を観察するためのアナログテスト文書を作る指針を定める。

## Current rule


既存 `tests/analog_test/` は history / reference として保持するが、新 UX の acceptance にはしない。

## Scope

Analog test は、自動テストでは確認しにくい以下を扱う。

- Editor 操作の流れ。
- viewport hit / focus / selection。
- Scene Tree / Inspector / dock の連携。
- 保存、再読込、Undo / Redo の体験。
- 表示の自然さ、迷いにくさ。

## Output

```text
tests/analog_test/<USE_CASE_ID>_ANALOG_TEST_<YYYY-MM-DD>.md
docs/review/<USE_CASE_ID>_CODE_READING_<YYYY-MM-DD>.md
```

## Minimum content

- Use case。
- Preconditions。
- Operation steps。
- Expected observations。
- Failure signals。
- Code reading notes。
- Follow-up candidates。

## Judgement

Analog test は `tools/test.sh` の代替ではない。実施結果は UX 改善と follow-up planning の材料として扱う。
実装完了要件とは独立に扱い、開発中に実行不能な "Operation Steps" が存在することは正常とする。
