# EQM-050 SUB_TASKS

## Complexity

Class: C3
Reason:
- **初の L2 surface** (reservation)。Action Resolution Turn-Based の核となる reservation schema を確立し、EQM-051 (pipeline)/052 (AP-ready)/060+ (trigger) が乗る。
- 新 class 2 + 新 error code 群 → API surface (L2 列が初めて埋まる) + ERROR_CONTRACT 変更。

Required artifacts: Complexity header / Task Resolution / UX (最小) / POLICY (schema + Invariant) / IMPLEMENTATION_PLAN。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQActionDefinition (Resource) | reservation の authored schema | adopt | kind(enum) / delay / tags / duration / rumination / operation_target_tag + validate + .tres roundtrip。 |
| EQReservation (runtime instance) | actor の pending reservation | adopt | actor_id + definition + counters(remaining_ruminations/duration) + status + validate + to_dict/from_dict。 |
| 6 reservation kind | immediate/prepared/reaction-prep/wait/ready/operation | adopt | acceptance 列挙。kind ごとの validation 制約。 |
| duration=-1 = ∞ (deadline 無限) | reaction prep の回数 close | adopt | Q06: deadline=∞ を許容 (反応回数で close)。 |
| 新 EQError reservation code | kind 別 validation の安定 code | adopt | negative_delay / immediate_nonzero / prepared_zero / negative_rumination / invalid_duration / reaction_needs_duration / operation_needs_target。append-only。 |
| 解決 pipeline をここで実装 | — | defer→EQM-051 | 本 task は schema + validation のみ。scheduling/resolution は EQM-051。 |
| solve/invalidation 条件オブジェクト | — | defer→EQM-060 | 本 task は kind/fields。condition contract は Trigger phase。 |

## Scheduled Task Audit

新規 scheduled task なし。次の依存解放は EQM-051 (reservation resolution pipeline)。AP-ready model は EQM-052、condition は EQM-060、rumination cycle guard は EQM-062。
