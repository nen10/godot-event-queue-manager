# EQM-035 SUB_TASKS

## Complexity

Class: C3
Reason:
- v0.1 slice 全体 (EQM-010..034) を横断する評価。semantics drift 監査・API friction・north-star metric baseline・roadmap 確認を含む。docs-only。

Required artifacts: Complexity header / Task Resolution / IMPLEMENTATION_PLAN。(UX/POLICY は評価 task のため省略 — 成果物は評価レポート。)

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| 評価レポート | v0.1 の到達度・drift・friction・metric・roadmap を記録 | adopt | `docs/review/V0_1_MILESTONE_EVALUATION_2026-06-15.md`。 |
| semantics drift 監査 | SEMANTICS 予約契約 vs 実装の乖離 | adopt | §3-§16 を実装と突合。A1 (予約 vs 実装) は drift ではない。 |
| API friction 列挙 | L0/L1 の使い勝手の摩擦 | adopt | 各 friction を queue candidate / no-change として明示記録。 |
| north-star metric baseline | 製品価値の定量基準 | adopt | simple-path-without-L3 / layer-leak / dogfood-friction / determinism coverage。 |
| roadmap 確認 | 変更 or 不変の判断 | adopt | Phase4 の前提 (v0.1 契約) 充足を確認。 |
| 評価で code 変更 | — | reject | 評価は記録のみ。修正は別 task / 別 phase。 |

## Scheduled Task Audit

EQM-035 完了で **v0.1 MVP milestone**。次フロンティアは Phase 4 (EQM-040 energy policy)。friction からの candidate は本評価に記録 (大半 no-change-for-v0.1、tie_break 消費の明確化は EQM-100 manual へ畳む)。
