# Event Model — Conceptual Foundations

status: confirmed 2026-06-14 (three-plane model). EQM-014 の `EVENT_MODEL_SEMANTICS.md` への確定入力。
未決の identity/scaling 判断は `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md` Q26 が持つ。
根拠記録: `docs/review/EVENT_MODEL_OPEN_QUESTIONS_SYNTHESIS_2026-06-14.md`。

---

## 1. 三面モデル (three planes)

`event-line` / `event` / `event_line_progressed` は同じものの 3 種類ではなく、3 つの異なる面に属する別物である。分類の目的は面どうしの汚染を防ぐこと。決定性保証はこの分離に依存する。

### 1.1 event-line — 状態 / 入力

- acceptance が更新規則 (増分・条件) を定義する、名前つきの整数進行変数。global tick はその primary。
- 「起きること」ではない。master timeline に乗らない。単独では何も生まない。ただ進むだけ。
- **目的**: 進行の複雑さを入力層に閉じ込める。あらゆるゲーム固有の「時間が進む / 準備が溜まる / 残量が減る」を座標軸として吸収し、解決層は「ある条件が参照する event-line が閾値を越えた」しか見ない。これによりジャンル追加で comparator を触らず、速度変化を `due_tick` 再計算ではなく event-line の増分変更で表せる。

### 1.2 event — 出力 / 順序

- 順序解決の単位。`solve_conditions` (AND) が揃うと解決し、effect を effect 処理チャンクへ出し、event-line を発行/再レートし、後続 event を schedule しうる。`invalidation_conditions` (OR) が立てば解決せず脱落する。reservation は行動意図フィールドを足した event。
- 進行軸ではない。「進む」ことはなく、一度きり解決するか失効する。
- **目的**: master timeline を「1 種類のものの単一決定的全順序」に保つ。comparator は event だけを (tick, priority, sequence) で並べる。event-line をこの層から締め出してあるため全順序が証明可能・説明可能なまま保たれる。

### 1.3 event_line_progressed — 観測 / 記録

- canonical trace の 1 行。「解決列のこの地点で event-line X が進んだ (a→b / レート変化 / 発行)」を記録する trace kind。解決済み event 記録・`window_opened/closed`・失効 (`closed_by`) と並ぶ。
- runtime オブジェクトでもシミュレーション手順でもない。何も引き起こさない。消しても挙動は不変で、変わるのは検証・説明可能性だけ。
- **目的**: trace を決定性証明と説明の源にする。入力層 (event-line) の変化を可視化し、「なぜ event E が今解決したか」を trace から答えられ、進行の決定性を解決の決定性と独立に golden 検証でき、replay/予測が状態を厳密再構成できる。

## 2. 解決サイクル (one-way valves)

event-line と event は一方向の弁で繋がる閉ループ。面は決して融合しない — **動く座標は決して timeline 上の項目にならない。**

```text
event-line が閾値を越える ──(条件成立)──▶ event が解決可能/失効になる   (入力 → 出力)
event が解決する          ──(発行/再レート)─▶ event-line が動く/生まれる   (出力 → 入力)
両方                       ──(記録)─────────▶ trace に event_line_progressed 等  (観測)
```

## 3. event を発行する vs event-line を発行する

- **event を発行** = 何かを起こす/解決させたいとき。通常はこちら。たいてい *既存の* event-line (global tick, entity の WT) を条件で参照する。
- **event-line を発行** = *新しい進行軸* が要るときだけ。

race pattern (OR 解決) で発行されるのは **event-line を条件にした複数 racing event** (同一 effect・異なる `solve_conditions`) であり、event-line そのものを複数発行するのではない。event-line はその条件が参照する進行軸 (通常は共有) である。

### 3.1 進行の 2 つの表現 (scaling の鍵)

同じ「進行」を acceptance は 2 通りに表現できる。選択が cost を決める。

| 表現 | 何が起きるか | 使いどころ | event-line 数 |
|---|---|---|---|
| (1) first-class event-line | 固有 identity・snapshot 上の entry・直接 polling される進行座標 | *少数の独立した* 進行軸 (party 共有 WT, グローバルな天候カウンタ等) | 軸の数 |
| (2) entity/effect 状態 + tick 駆動 sweep | 値は entity/effect の field。primary tick 上の 1 つの system event が多数の同質な値を一括前進し、閾値到達で解決 event を発行 | *多数の同質な* 進行 (全 entity の CT, 全 buff の uses_left) | O(1) |

per-entity WT/CT は (1) を*必須にしない* (Q16 決定)。多数 entity が同じ規則で進むなら (2) を採るのが既定で、これにより first-class event-line 数は entity 数に依存せず O(1) に抑えられる。(1) は規則が個別に独立な軸にのみ使う。

**「多数同質 (homogeneous)」の定義**: 進行規則の *shape* が同一で、per-entity parameter のみ異なるもの。例:「毎 tick 自速度ぶん CT 加算、閾値で行動」は速度の値だけ違い shape は同一。機械判定基準は「規則を共通 callable + per-entity param に分離できるか」。分離できれば homogeneous (pattern 2)、条件・効果の構造が個別なら heterogeneous (pattern 1)。

**watched / sparse polling**: event-line が watched = 未解決 event の solve/invalidation 条件が 1 つ以上それを参照している状態。これは現在の pending 条件から導出される state 由来の性質で、予測深さに従属しない。polling 対象は watched かつ rate≠0 (非 frozen) の event-line のみ。これにより event-line 総数が大きくても前進コストは「実際に監視されている軸」に比例する。

## 4. event-line / counter の identity と lifecycle

進行を数える単位の identity は、**ゲームが数えたい意味単位に一致させる**。これが唯一の不変条件。具体的な granularity 方針 (どこまで first-class にするか、stacking 意味論、再帰召喚の cost) は未決として Q26 が持つ。

確定している点:

- event-line / counter の id は安定・serializable で、deterministic な counter (event sequence / actor_id と同列) で採番する。発行順は一意 (並列発行禁止, Q20) なので採番は replay 間で決定的。
- 失効 lifecycle: entity 消滅時の per-entity 進行 cleanup は actor lifecycle (Q10) に従い、actor_id 再利用は禁止。
- buff の uses_left「使い回し」は普遍規則ではない。stacking 意味論は acceptance 定義 (独立 stack→個別 counter / refresh→単一 counter 再利用 / 共有 pool→単一共有)。モデルは 3 者すべてを表現でき、reuse を hardcode しない。

## 5. 不変条件チェックリスト

- event-line は timeline に乗らない。timeline に乗るのは event だけ。
- master ordering key は int のみ (tick, priority, sequence)。float は composite comparator と effect 内順序にのみ許され、core ordering には不関与。
- 進行変更は event-line の増減で表し、`due_tick` 直接書換は禁止 (reschedule のみ)。
- solve=AND / invalidation=OR。OR 解決は racing event、AND 失効は decremental counter event-line。
- counter identity = 数えたい意味単位。id は deterministic 採番。
- 進行・解決・失効・window はすべて trace kind を持ち golden で守られる。

## 参照

- 決定一覧: `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md` (Decisions 2026-06-14)
- 未決 identity/scaling: 同 Q26
- 上位順序の拡張点: 同 Q20
- save 境界 / snapshot: 同 Q01 / Q22
