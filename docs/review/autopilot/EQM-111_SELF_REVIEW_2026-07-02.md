# EQM-111 Self-Review 2026-07-02

Pattern: P0 (orchestrator-direct)。Repair: 0 (新規 test 2 file を含め初回 green)。

## Execution summary

SEM v1.1 §5.4/§5.5/§5.6 の conditions 契約を実装した。`EQConditionSpec` (LINE_THRESHOLD / COUNTER / NAMED_PREDICATE、relative threshold、condition_id)、純粋評価器 `EQConditionEval` (bind で相対→絶対固定・COUNTER→counter line 束縛、level-triggered AND / OR + closed_by / invalidation-wins、fault は値返し)、`EQActionDefinition` の additive 拡張 (条件配列 + duration/rumination 糖衣の `normalized_conditions()`)、`EQRuntime` の named predicate registry (置換許容・空名 fault・copy 返し)。pipeline への組込みは scope 外 (EQM-113)。

## Acceptance result — met

| acceptance | result |
|---|---|
| EQConditionSpec .tres roundtrip | 入れ子 typed array ごと保存/復元 (test_eq_condition_spec) |
| solve/invalidation additive 追加 + 糖衣正規化 | declared 先頭維持 + duration→relative LINE_THRESHOLD(primary, id=duration) + rumination→COUNTER(start=rum+1, id=reaction_count); legacy dict 互換 |
| level AND / OR / invalidation-wins helper | ctx 変化での再評価 (非 latched)・同時成立で INVALIDATE・first-declared closed_by を test で固定 |
| named predicate registry | 登録/置換/空名 fault/copy 返し (外部変異不能)/未登録 = CONDITION_PREDICATE_UNREGISTERED fault |
| ERROR_CONTRACT codes | +5 codes (doc 表と eq_error.gd 一致) |
| API surface (L2, no leak) | +EQConditionSpec/+EQConditionEval L2; EQRuntime +3 methods (StringName/Callable のみ、L3 型は署名に不在) — 明示 --update で golden 再 baseline |
| coverage rows flip | conditions-contract / named-predicate-registry -> implemented (checker green) |

## Test summary

```text
./tools/test.sh -> RESULT: PASS; files=50 checks=726 failures=0
[api-surface] ok / [contract-coverage] rows=21 implemented=8 reserved=13 violations=0
```

(注: coverage 数値は flip 後の再実行で implemented=8。proof の violations=0 は flip 前後とも成立。)

## Golden updates (explicit)

- `tests/golden/api_surface.json` — 上記 surface diff のみ。ordering/trace golden への変更なし。

## Deviations

- `docs/design/ERROR_CONTRACT.md` §4 表に EQM-081 の `eqm.presentation.policy_class_conflict` 行が欠落していたため backfill した (taxonomy 実体と doc の不一致解消; 実装変更なし)。
- COUNTER の runtime counter line 採番は EQM-112 (event-line backend) の責務。評価器は `counter_line_id` を bind 引数で受け、未束縛は fault にする (silent 化しない) ことで契約を先取りせず塞いだ。

## No sample-only completion

評価器 test は合成 ctx に対する property 検証 (level/AND/OR/勝敗/fault) であり、sample preset 依存なし。.tres roundtrip は user:// 一時 file。

## UX path reduction

条件の入力クラスは 3 type の serializable Resource + named registry に狭めた (自由 Callable 保持・条件 DSL は不採用、UX.md matrix)。既存 API の削除なし (additive)。

## Repair-now / follow-up

なし。次: EQM-112 (event-line backend) READY。
