# CLAUDE.md

Godot addon: Event Queue Manager — 行動順 (event / turn / action order) 管理 addon。
開発は Roadmap -> Implementation Queue -> Task Packet の自動化フローで進む。判断基準は文書化済みであり、このファイルは入口のみを示す。

## Read order (smallest relevant set)

1. `AGENTS.md` — request 種別ごとの文書 dispatch table。
2. `docs/devflow/PROJECT_PROFILE.md` — 原則、禁止 default、停止条件。
3. `docs/plan/2026-06-09_event_queue_manager/IMPLEMENTATION_QUEUE.md` — Current pointer と READY task。
4. task 種別に対応する policy (`AGENTS.md` の table に従う)。

## Commands

- 標準検証: `./tools/test.sh` (EQM-001 で作成。存在しない間は `BLOCKED_BY_TEST_ENV` を記録)
- Godot headless: `godot --headless --path test_project --script res://tests/run_all.gd`
- UI static audit: `python3 tools/ui_static_audit.py`
- test 出力先: `.godot_user/test-runs/<run-id>/` (固定 path / 共有 log へ書かない)

## codexへの作業委任（常時有効）

任意の作業について以下のcodex系ツールに分担させてよい。

- **codex-fugu**: 理解力が高い方。複雑な理解・判断が必要なタスクや実行経路の確立が必要な作業に使う。コマンドライン実行のみ可能 `codex-fugu`
- **codex CLI (GPT 5.5)**: 設計済み・大規模な実行タスクに使う（`codex exec -s workspace-write - < prompt.md` 等、バックグラウンド実行）。5.3ではなく5.5を指定する。

委任した結果は必ず検証すること（誤分類・サンプルレート異常などの実績あり）。

## Hard rules

- Queue 実行では planning 後に承認待ちで止まらない。実装 -> test -> self-review -> queue 更新 -> commit まで同 run で行う (`docs/devflow/LINEAR_AUTOPILOT_QUEUE.md`)。
- No sample-only completion。silent fallback chain 禁止。入力クラスは狭める (`docs/devflow/policy/UX_PATH_REDUCTION_POLICY.md`)。
- golden trace fixture を自動更新しない。明示 flag + self-review 記載が必須 (`docs/devflow/policy/DETERMINISM_TRACE_TEST_POLICY.md`)。
- Editor UI は injected headless state の projection。UI acceptance は metric / state / interaction contract であり screenshot ではない (`docs/devflow/policy/UI_TESTABILITY_POLICY.md`)。
- runtime は dev fail-fast / shipped fail-safe の二相。shipped mode は consumer の game を crash させず、正常 trace は mode 不変 (`docs/devflow/policy/RUNTIME_RESILIENCE_POLICY.md`)。
- 簡易 turn-order パス (L0/L1) と深層 reservation/event-line パス (L2/L3) は両方 first-class。L3 を L0/L1 surface に leak させない (ROADMAP §3.1)。
- state 表示は icon / checkbox 等の非文字 modality を優先する (`UI_LAYOUT_METRIC_TEST_POLICY.md` §5.11)。
- commit message: `autopilot(<TASK_ID>): <summary>`。commit 可能 status のみ (`docs/devflow/PROJECT_PROFILE.md`)。

## Repository map

```text
docs/devflow/          開発プロセス (process / policy / profile / test index)
docs/plan/<date>_<id>/ roadmap, implementation queue, task packets
docs/design/           event model semantics, open questions, error/API contracts
docs/review/           evaluation reports, self-reviews (autopilot/)
docs/ui/               UI 契約文書 (EQM-086 以降に作成)
addons/event_queue_manager/  addon 本体 (EQM-002 以降に作成)
tools/                 test.sh, static audits
```
