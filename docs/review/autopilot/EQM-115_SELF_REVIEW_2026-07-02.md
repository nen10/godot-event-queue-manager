# EQM-115 Self-Review 2026-07-02

Pattern: P0 (orchestrator-direct)。Repair: 1/3 — 不正 permutation test が dev halt に阻まれたため SHIPPED mode で fallback を観測する形へ setup 修正 (製品変更なし)。

## Execution summary

SEM v1.1 §7.1 の ordering hook を実装した。`EQReservationRuntime.set_order_hook(Callable)`: `order_simultaneous(candidates) -> Array[int]` (permutation)。適用点は「同一評価点で solve 成立した conditional 群の push 順」と「同一 sweep の fired reactions の schedule 順」の 2 箇所のみで、master comparator (§3) と既存 entry の key は不変 (hook は新規 sequence の割当順を変えるだけ)。candidates view は EQM 側で構築する serializable dict (index/actor/stats/tags/priority/nest_level/lines — float は stats 経由で読める scoped exception、live object は混入不能で test 検証)。未設定 = 発行順 (v1.0 と同一)。不正 permutation は `eqm.order.hook_invalid` fault + 発行順 fallback (silent 採用なし)。適用は `order_hook_applied` {count, order} として trace され、2-run byte 同一性で決定性を固定 (Q20 golden 保証)。

## Acceptance result — met

TO の「ベース WT 低い方が先」を hook 3 行で表現し、解決順 [b_fast, c_mid, a_slow] と trace `"order":[1,2,0]` を test で固定。composite atomic bundle は実装しない (defer 維持、§7.1 staging)。

## Test summary

```text
./tools/test.sh -> RESULT: PASS; files=56 checks=894 failures=0
```

## Golden updates (explicit)

`tests/golden/api_surface.json` のみ。

## Deviations

- queue target files にあった `resources/eq_config.gd` は変更していない (Callable は Resource に serialize 不能のため、predicates/effects と同じ起動時登録で統一 — SUB_TASKS E に記録)。
- golden fixture は新設せず 2-run byte 同一性 test で被覆 (EQM-118 の product 経路 golden に統合予定)。

## No sample-only completion / UX path reduction

Property 検証 (permutation 全単射・fallback・決定性)。拡張点は 1 hook のみで、自由 comparator による master ordering 差し替えは不採用のまま。

## Repair-now / follow-up

なし。次: EQM-116 (race pattern) READY。
