# EQM-112 UX — event-line backend

user goal: L2/L3 開発者 (と後続 EQM-113 pipeline) が、WT/CT/効果回数などの進行を「値と増分の data」として宣言・前進・観測でき、その全変化が trace で説明される。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. data-only line table (L3 class) | high | low | medium | adopt | Q33 確定。snapshot/replay が閉じる |
| B. per-line callable update rule | medium | high | medium | reject | Q33 で不採用確定 (save 不能・決定性検証不能) |
| C. L0 EQRuntime に lines を公開 | medium | high | low | reject | L3 leak。統合は L2 側 (EQM-113) |

## Operation steps

1. (L3 直接利用時) `EQEventLines.issue(&"party_wt", 0, 1)` で軸を発行、`advance` / `re_rate` を event effect から呼ぶ。
2. 多数同質進行は `register_sweep_rule(name, callable)` + actor state の per-entity param で宣言する (pattern 2)。
3. 条件 (EQM-111) は line 値を読む。`derive_watched` が pending 条件から watched 集合を導出し、poll cost は監視中の軸のみに比例する。
4. すべての変化は `event_line_progressed` (cause 付き) として trace に出る。

- 採用 UX: data 宣言 + named sweep rule。廃止/保留: なし (新規領域)。
- 干渉: なし (既存 policy 群は本 backend を使わず並存 — reducibility 接続は EQM-118)。
