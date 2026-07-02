# EQM-112 POLICY — event-line backend

## 採用判断

- **EQEventLines は L3** (API_SURFACE 初の L3 tag)。L0/L1 の public signature に型名を出さない — runtime への統合 (EQM-113) は L2 (EQReservationRuntime) 側から行い、EQRuntime の L0 surface に EQEventLines 型を露出しない。
- **primary line = 値の鏡** (rate 0 で発行): global tick の正は scheduler.current_tick。`sync_primary(tick)` で鏡映し、progressed trace を残す。rate 自走にすると tick の二重管理になる。
- **counter 採番** = `eqm.counter.<seq>`、単調 int。発行順一意 (Q20) により replay 決定的。
- **走査順は常に sorted**: poll は line id 昇順、sweep rule は登録順 × actor_id 昇順。snapshot 復元後も同順 (to_dict が id 昇順で書く)。
- **faults は記録して投げない** (EQTriggerEngine と同型): unknown line への advance/re_rate は `eqm.condition.line_unknown` を faults へ。dev/shipped の扱いは pipeline (EQM-113)。
- **trace は cause field で 1 kind に集約** (`event_line_progressed` + cause: issued/advanced/poll/re_rated/sweep_rule) — kind 増殖を避け、§11 の予約名を維持。
- **PRIMARY_LINE_ID は再宣言 + 同値 test**: EQActionDefinition.PRIMARY_LINE_ID (L2 糖衣の参照先) と EQEventLines.PRIMARY_LINE_ID (L3) を preload 依存で結ばず、test で drift を封じる (L3→L2 resources への依存を避ける)。

## 不採用判断

- callable 型 update rule / rate 帯域 (Q33 確定どおり)。
- crossing-tick 計算 backend (Q17 (b)) — 将来 task。導入時は golden 等価 gate。
- poll の trace 抑制 flag — 観測は削っても挙動不変が原則 (SEM §2.1)。抑制は trace 側の将来課題とし、本 task では常時記録。

## Invariants / State Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| line table | value/rate は int のみ、id 不変 | float 混入 | API が int 型注釈、test |
| poll | watched ∧ rate≠0 のみ前進 | unwatched の前進 | sparse poll test |
| counter seq | 単調・to_dict/from_dict で保存 | 復元後の id 衝突 | roundtrip + 再発行 test |
| 走査順 | id 昇順 / 登録順 / actor 昇順 | 挿入順依存 | 順序 test (挿入順を入れ替えて同結果) |
| faults | unknown line は記録、silent false にしない | 黙殺 | fault test |
| trace | cause 別 progressed、canonical keys | 非決定 field | jsonl 部分一致 test |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| primary line 値と scheduler.current_tick | sync_primary による明示同期 (鏡) | 二重管理防止 | EQM-113 が pipeline で唯一の呼び出し点を持つ | sync test + (113 で) pipeline test |
| sweep rule callables | snapshot は名前のみ (Q30 と同型) | serialize 不能 | — | to_dict に callable 不在 test |
