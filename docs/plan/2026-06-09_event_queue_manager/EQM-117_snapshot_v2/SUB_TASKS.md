# EQM-117 SUB_TASKS — snapshot v2 + save 境界 enforcement

## Complexity

Class: C4
Reason: on-disk 契約の version bump (migrate 手続き)・save 経路の gate 追加・複数 subsystem (lines/armed/conditional/scheduled) の直列化と verify-before-mutate load。

Required artifacts: C4 (fallback/mirror 必須 — POLICY.md)。

## Task resolution

| task 候補 | 目標/UX | 採否 | 概要 |
|---|---|---|---|
| A. bundle SCHEMA_VERSION 2 (additive tables) | SEM §10 (Q41) | 採用 | event_lines / windows / armed_triggers / pending_conditional / scheduled_reservations。v1 bundle は欠落 = 空で load (migrator)。v2-in-v1 は既存 fail-safe が拒否 |
| B. save gate (`is_save_boundary`) | §10 (Q22/Q41) | 採用 | boundary 外の save = `eqm.save.blocked` 安定 error + 空 bundle。force flag なし |
| C. pipeline の save_state / verify+apply restore | §10 | 採用 | verify-before-mutate: sweep rule / predicate / effect の名前登録を検査してから復元。未登録 = 安定 error + false |
| D. EQCondition の serialize (to_dict/from_dict) | armed 復元 | 採用 | custom_predicate は除外 (transient 明記済み) |
| E. windows table の内容 | — | 空 literal + 記録 | save は boundary gate により window_depth=0 でのみ成立 → 非空は到達不能。schema shape として key は置き、理由を POLICY に記録 (将来の rollback-bundle 用) |
| F. race 帳簿の serialize | — | 不採用 (declared follow-up) | member 予約自体は conditional/scheduled として保存される。open race を跨ぐ save では settlement の敗者一掃が復元後に効かない制限を docs に明記し、需要時に v2 帳簿化 |
| G. EQManager への save API 追加 | — | 不採用 | L0 経路に chunk/window はなく gate 対象がない。save 経路は EQSaveAdapter に一本化 (queue target からの deviation として記録) |

Scheduled task: なし (F は制限の明記で v1.x 完了; 需要発生時に起票)。
