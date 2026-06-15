# EQM-050 POLICY

## 採用判断

- **EQActionDefinition (Resource, L2)**: authored reservation schema。
  - `Kind` enum = IMMEDIATE / PREPARED / REACTION_PREPARATION / WAIT / READY / OPERATION。
  - fields: `delay`(int) / `tags`(Array[StringName]) / `duration`(int, -1=∞) / `rumination`(int) / `operation_target_tag`(StringName)。
  - `DURATION_UNLIMITED := -1` (reaction prep を反応回数のみで close、Q06)。
  - validate() + to_dict/from_dict (`.tres` roundtrip)。
- **EQReservation (RefCounted, L2)**: runtime instance。`actor_id` + `definition` + `remaining_ruminations` + `remaining_duration` + `status`(PENDING/ARMED/RESOLVED/INVALIDATED) + `event_id`。validate() (definition 委譲 + 自身) + to_dict/from_dict (definition を inline 直列化)。
- **kind 別 validation 制約** (安定 code、append-only):
  - 全 kind: delay>=0、rumination>=0、duration>=-1。
  - IMMEDIATE: delay==0。PREPARED: delay>0。REACTION_PREPARATION: duration!=0 (>0 or -1)。OPERATION: operation_target_tag!=&""。
- **L2 は opt-in**、L0/L1 surface 不変 (§3.1)。L3 を L0/L1 に leak させない (gate)。

## 不採用判断

- 解決 pipeline の本 task 実装 (EQM-051)。
- solve/invalidation condition オブジェクト (EQM-060)。
- kind を string で受ける (enum で invalid state を unrepresentable に)。
- rumination cycle guard の本 task 実装 (EQM-062; ここは field のみ)。

## Invariants

- 同一 definition の validate は決定的・副作用なし。
- `.tres` roundtrip で全 field 保存。EQReservation.to_dict は Node 参照を含まない (definition は値で inline)。
- kind と field の不整合は安定 code の validation error (silent 受理しない)。
- duration=-1 は ∞ として扱い、それ以外の負値は invalid。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| EQActionDefinition.validate | kind 別制約を満たす | 不正組合せ受理 | 各 kind の valid/invalid を assert |
| duration | >=-1、-1=∞ | 負値混入 | duration=-2 invalid、-1 valid (reaction) |
| .tres roundtrip | 全 field 保存 | 直列化欠落 | save/load 後 kind/delay/tags/duration/rumination 一致 |
| EQReservation.to_dict | live ref なし、counters 保存 | Node 漏洩 | to_dict に definition inline、status/counters 復元 |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| immediate + delay>0 | `reservation.immediate_nonzero_delay` | kind 制約 | — | assert |
| prepared + delay<=0 | `reservation.prepared_zero_delay` | 準備は遅延必須 | — | assert |
| reaction-prep + duration==0 | `reservation.reaction_needs_duration` | 武装窓が必要 (∞ は -1) | — | assert |
| operation + 空 target tag | `reservation.operation_needs_target` | 対象予約を起こす | — | assert |
| 負 delay/rumination, duration<-1 | 対応 code | 数値域 (§12) | — | assert |
