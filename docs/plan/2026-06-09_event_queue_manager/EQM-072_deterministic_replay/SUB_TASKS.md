# EQM-072 SUB_TASKS

## Complexity

Class: C2 (delegated; contract pinned by orchestrator)
Reason:
- deterministic seeded RNG + replay proof。RNG 意味論は標準 (Godot RandomNumberGenerator の seed+state 直列化)、目標は固定 (同 seed/同 state → 同列・同順序再現)。設計縮小リスク低。
- 委譲: Codex 5.5 (gpt-5.5 xhigh)。orchestrator が contract + gate + surface 配線。

Required artifacts: Complexity header / Task Resolution / Contract (IMPLEMENTATION_PLAN) / 委譲記録。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQRng (core) | seeded・serializable な決定的 RNG | adopt | RandomNumberGenerator を wrap、seed/state を to_dict/from_dict。同 seed→同列。 |
| replay proof | snapshot 復元で random 依存の順序/結果を再現 | adopt | 途中 save (scheduler snapshot + rng.to_dict) → 別 instance へ restore → 継続が無停止 run と一致。 |
| random 依存 ORDER | RNG が event 順序に影響する scenario | adopt | random tie/delay で scheduler 順が rng に依存、snapshot+restore で同順序。 |
| eq_snapshot.gd の schema 改変 | — | reject(委譲側) | EQRng は自己直列化。core snapshot schema は触らせない (必要なら orchestrator が additive helper)。 |
| 新規アルゴリズム自作 | — | reject | Godot RandomNumberGenerator (seed+state) を使う。 |

## 委譲 (P2)

- executor: Codex 5.5 (gpt-5.5 xhigh)。contract = `IMPLEMENTATION_PLAN.md`。
- scope: `addons/.../runtime/eq_rng.gd`, `test_project/tests/transaction/test_eq_rng_replay.gd`。**tools/check_api_surface.py / golden / eq_snapshot.gd は触らない** (orchestrator が surface 配線; eq_snapshot は EQRng 自己直列化で不要)。
- gate: orchestrator が LAYER_MAP (EQRng: core) + golden + `./tools/test.sh`。repair 上限 3。

## Scheduled Task Audit

新規 scheduled task なし。EQM-072 完了で Phase 7 (Transaction and rollback) milestone。
