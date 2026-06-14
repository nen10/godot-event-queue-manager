# EQM-033 IMPLEMENTATION_PLAN

## Scope

EQPrediction (branch + predict_turns) と EQSnapshot.equals を実装する。full transaction/rollback は Phase7。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_prediction.gd` — `EQPrediction`: branch / predict_turns。
- `addons/event_queue_manager/runtime/eq_snapshot.gd` — `EQSnapshot.equals(a, b)` 追加。
- `tools/check_api_surface.py` — LAYER_MAP に `EQPrediction: L0`。
- `docs/design/API_SURFACE.md` — L0 表に追記。
- `tests/golden/api_surface.json` — `--update`。
- `test_project/tests/core/test_eq_prediction.gd` — purity / predict==actual / branch 比較 / 短い列。

## 実装 steps

1. EQSnapshot.equals。
2. EQPrediction.branch / predict_turns。
3. LAYER_MAP + API_SURFACE.md。
4. test。
5. `python3 tools/check_api_surface.py --update`。
6. `./tools/test.sh` PASS。

## Test path / gate

- §4 gate (core): prediction purity (snapshot before==after) + predict==actual + branch 独立性。
- §4 gate (API surface): EQPrediction L0、leak なし。
- 期待: 既存 217 + 新 checks、api-surface ok、exit 0。

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| EQScheduler snapshot/restore (EQM-012) | branch 不完全 | branch が live snapshot を復元 |
| EQRuntime/policy (EQM-022/030/031) | virtual advance ずれ | predict==actual |
| principle 17 (purity) | live mutation | snapshot before==after |
| API surface gate | 無断 surface 変更 | 明示 --update、L0 |

## Completion checklist

- [ ] predict_turns が次 N turn を返し、live は不変 (snapshot before==after)。
- [ ] predict == actual (default action)。
- [ ] branch が live と独立 (data 変更が伝播しない)、act-now vs wait の順序差を観測。
- [ ] per-step 評価 (precompute しない)。
- [ ] EQSnapshot.equals 追加。
- [ ] EQPrediction L0、golden 明示更新、self-review に diff。
- [ ] `./tools/test.sh` PASS。
