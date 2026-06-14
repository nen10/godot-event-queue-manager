# EQM-021 SUB_TASKS

## Complexity

Class: C3
Reason:
- 複数ファイル (EQActorState + EQActionResult + EQActorRegistry + tests)。
- actor_id identity 不変条件 (再利用禁止, semantics §13/Q10) と weak-binding 分離 (Node 参照を保存形式に混ぜない) という横断契約を確立。
- EQM-020 の EQError/EQValidation を再利用し、新 code を append-only で追加。

Required artifacts: Complexity header / Task Resolution / Scheduled Task Audit / UX Candidate Matrix / POLICY (Invariant + Fallback/rejection) / IMPLEMENTATION_PLAN (dependency/test matrix)。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQActorState | engine 側 actor 状態。serializable identity + acceptance data + transient weak binding | adopt | actor_id + data(Dictionary) + `_binding: WeakRef`(非直列化)。bind/bound/is_bound。to_dict/from_dict は actor_id+data のみ。 |
| EQActionResult | finish_action の型付き結果 | adopt | cost/delay/allow_negative_cost。validate()。生 Dictionary fallback を禁止 (UX_PATH_REDUCTION)。 |
| EQActorRegistry | actor_id 登録・重複/再利用拒否 | adopt | register/is_registered/get_state/unregister/actor_ids/size。retired id 追跡で再利用禁止。 |
| per-entity 進行 (WT/CT/AP) を built-in field 化 | — | reject | semantics Q16: per-entity event-line は acceptance 定義。data Dictionary に委ねる。 |
| 生 Node 参照を state に保持 | — | reject | Adapter 原則: Node 参照を保存形式に混ぜない。WeakRef のみ (transient)。 |
| register が既存 id を silent overwrite | — | reject | 重複は明示拒否 (null + duplicate_id)。再利用も拒否 (id_reused, semantics §13)。 |

## Scheduled Task Audit

新規 scheduled task なし。次の依存解放は EQM-022 (headless facade)。EQActorRegistry/EQActionResult は EQM-022 の register/finish_action 経路が消費する。実 weak-binding rebind-on-load は EQM-085 (node bridge)。
