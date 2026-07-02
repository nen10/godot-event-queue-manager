# EQM-116 POLICY — race pattern

## 採用判断

- **race = 発行の糖衣**: member は通常の pipeline (条件 gate/schedule) を通る。core が増やすのは { group 帳簿, 勝者確定時の敗者一掃, trace 語彙 } のみ。勝敗順序は既存機構 (§7.1 hook → 発行順) に委ねる。
- **勝者確定点 = member の解決時** (resolve_next の status RESOLVED 直後)。敗者のうち status が未確定 (PENDING) のものだけを一掃する (他経路で既に INVALIDATED の member は触らない)。
- **gid は deterministic 採番** (発行順一意, Q20 と同列)。`race_opened {race_group, members}` / `race_resolved {race_group, winner, event_id}` を trace。敗者の `event_invalidated` は `closed_by: race_lost` + `race_group` field。
- **3 表示分離の最小実装**: (1) EQM 内部 debug = trace に全候補可視 (D)。(2) game-dev debug = overlay が race_group 連続行を 1 候補群 row に集約 (E)。(3) in-game = presentation pipeline は勝者の解決 effect しか受け取らないため既に勝者のみ (追加実装不要と明記)。

## 不採用判断

- race 専用勝者規則 (F)。member の動的追加 API (需要が出たら EQM-119 以降)。

## Invariants / State Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| 効果 | race 全体で 1 回だけ適用 | 勝者複数 | 一括 run の last_drained 総数 test |
| 敗者 | 全て closed_by: race_lost で trace | silent 消滅 | trace 検証 |
| gid | 同一操作列で replay 同一 | 非決定採番 | 2 instance 同一 gid test |
| 勝敗 | hook → 発行順 (専用規則なし) | 隠れ順序規則 | 同時成立 test |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| 敗者の scheduled event | cancel (lazy) + trace | §3 の reschedule-only を保つ | — | 同時成立 test |
| _race_of の stale entry (他経路で死んだ member) | 放置許容 (解決に到達しないため無害) | 帳簿の簡潔さ | v2 で group 帳簿を snapshot 化する際に整理 | actor 離脱 + race test |
