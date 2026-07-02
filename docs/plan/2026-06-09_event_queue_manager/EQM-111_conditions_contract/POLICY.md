# EQM-111 POLICY — conditions 契約実装

## 採用判断

- **COUNTER は decremental counter event-line の糖衣** (SEM §5.1 と同型): bind 時に runtime 採番の counter line へ束縛され、term は `(counter_line, 0, LE)` の LINE_THRESHOLD になる。評価器に counter 専用経路を作らない。
- **relative threshold**: LINE_THRESHOLD に `relative` flag。bind 時の line 現在値を加算して絶対閾値へ固定する (Q27 の「絶対 key で timeline に乗る」と同型)。duration 糖衣・WT 系「今から N」を一般形で表せる。
- **空 solve_conditions = 恒真** (vacuous AND)。delay 型 event の「pop = 解決可能」と一貫。
- **closed_by**: `condition_id` 宣言があればそれ、なければ bind 時に `<group>:<index>` を決定的に採番。
- **predicate registry**: runtime instance 所在 (scene-local 原則)。名前空でない StringName。再登録は置換 (冪等 setup を許す)。評価 ctx には Dictionary (name→Callable) として渡し、評価器は runtime に依存しない。
- **評価器の fault は値で返す** (throw しない): dev halt / shipped skip の判断は pipeline (EQM-113) の責務 (RUNTIME_RESILIENCE_POLICY)。

## 不採用判断

- latched 評価・crossing 検出・repeating threshold (Q29/Q34 で不採用確定)。
- 評価器から EQRuntime への直接参照 (循環と test 容易性のため ctx dict に限定)。

## Invariants / State Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| EQConditionSpec | serializable のみ (.tres/to_dict roundtrip 同値) | Callable 混入 | roundtrip test + NAMED_PREDICATE は name のみ保持 |
| bind 出力 term | 絶対閾値・不変 dict | relative の二重加算 | bind test (relative/absolute) |
| solve 評価 | level-triggered AND (評価点の ctx のみ参照) | 状態記憶の混入 | 同一 terms を ctx 変化で再評価する test |
| invalidation 評価 | OR + 最初に成立した term の closed_by | 順序非決定 | terms 順固定の test |
| decide | invalidation-wins 一律 | solve 優先の逆転 | 同時成立 test |
| predicate 未登録 | 安定 fault (CONDITION_PREDICATE_UNREGISTERED)、silent false 禁止 | 黙殺 | fault 返却 test |
| ctx 未知 line | 安定 fault (CONDITION_LINE_UNKNOWN) | 0 扱いの黙殺 | fault 返却 test |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| duration/rumination 糖衣 field | 維持 + normalized_conditions() へ写像 | 既存利用者互換 + 単純系は単純に (Q42) | v2.0 で条件宣言へ一本化を再検討 | 正規化 test |
| EQCondition (trigger 照合) | 併存 (役割が別: event view 照合) | EQM-060 契約の維持 | — | 既存 tests |

## ERROR_CONTRACT 追加 codes

`eqm.condition.line_id_empty` / `eqm.condition.predicate_name_empty` / `eqm.condition.counter_start_invalid` (RESOURCE_INVALID) ・ `eqm.condition.predicate_unregistered` / `eqm.condition.line_unknown` (CONTRACT_VIOLATION)。
