# EQM-118 POLICY — reducibility 再証明

## 採用判断

- **等価の定義 = canonical trace の `resolved` 部分列 (tick, actor, priority) の一致**。EQM-053 の order 配列より強く (絶対 tick を含む)、trace 構造の差 (pipeline 側は event_line_progressed 等が混在、kind が turn/reservation で異なる) を跨いで比較可能な最強の共通射影。byte 同一は構造上不可能であり要求しない (self-review 明記)。
- **数理の同型**: CTB = ceil(cost*scale/speed) (no-carry reset) / Energy = carry (energy -= spend) / Wait-Turn = countdown (rate -1, act で maxi(1,cost) へ再設定)。per-tick 前進と dedicated の closed-form due は整数演算で一致する (EQM-053 で確立済みの関係を product 経路で再確認)。
- **submit 時点評価**: 初期 ready (wait 0) の検出が「次の tick 境界」まで遅れると dedicated (seed due=0) と 1 tick ずれる。level 意味論では「既に真の条件は発行時点で成立」が正しく、SEM §5.4 に追記の上 pipeline に実装。既存 test は全て「submit 時点で未成立」のため挙動不変。
- **golden**: product 経路の CTB run を fixture 化 (初回 baseline は明示 flag、DETERMINISM_TRACE_TEST_POLICY §2 手続き)。

## 不採用判断

- 旧 EQM-053 test の置換 (層が異なる、SUB_TASKS E)。byte 同一比較 (構造上不可能)。

## Invariants / State Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| 比較射影 | resolved 部分列は両 trace から機械抽出 | 手書き期待値の混入 | 抽出 helper を両側で共用 |
| matrix | EQM-053 と同一 (非約数 speed 含む) | cherry-pick | 同じ case 定数を使用 |
| golden | 明示 flag でのみ更新 | 黙示再 baseline | 既存 golden 機構を踏襲 |
