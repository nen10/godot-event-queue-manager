# Reservations

**reservation** は action-intent field を持つ event です。すぐ解決される action ではなく、*準備中*、*反応中*、*待機中*、*ready*、または *target 上で操作中* の action を表します。これは L2 です。単純な turn-order 導線 (L0/L1) では使いません。

Classes: `EQActionDefinition` (intent), `EQReservation` (live instance), `EQTriggerEngine` + `EQCondition` (arming + firing)。すべて public API です。下の例も sample resource を仮定せず、直接使います。

---

## 1. EQActionDefinition.Kind

```text
IMMEDIATE              すぐ解決する (delay 0)
PREPARED               `delay` ticks 後に解決する (preparation)
REACTION_PREPARATION   `duration` の間 armed され、matching event で fire する (counter/interrupt)
WAIT                   current turn を早く終え、READY reservation を schedule する
READY                  AP 回復後の turn-grant (action_resolution.md 参照)
OPERATION              target に reservation を発生させる (operate-on-target)
```

Fields:

```text
kind                 EQActionDefinition.Kind
delay                PREPARED action が解決されるまでの ticks
duration             REACTION_PREPARATION が armed のまま残る ticks。DURATION_UNLIMITED (-1) = tick deadline なし
rumination           reaction が初回後に追加で fire できる回数 (0 = 1 回だけ fire)
tags                 action が持つ StringName tags
operation_target_tag OPERATION: target に置かれる reservation の tag
```

`EQActionDefinition.validate()` は `EQValidation` を返します。不整合な definition (negative delay、reaction 以外への duration など) は明示的な error になり、silent default にはなりません。

## 2. EQReservation

```gdscript
var def := EQActionDefinition.new()
def.kind = EQActionDefinition.Kind.REACTION_PREPARATION
def.duration = EQActionDefinition.DURATION_UNLIMITED
def.rumination = 1            # 2 回 counter できる (first + 1)
def.tags = [&"counter"]

var reservation := EQReservation.new(&"hero", def)   # actor_id + intent
```

`EQReservation.Status` は `PENDING → ARMED → RESOLVED | INVALIDATED` と遷移します。reservation は serializable (`to_dict` / `from_dict`) で、live Node を持ちません。

## 3. reaction を arm し、fire する

`EQTriggerEngine` は `EQCondition` の背後に reservation を arm し、event が sweep point で解決されたときに matching したものを fire します。

```gdscript
var trigger := EQTriggerEngine.new()

var cond := EQCondition.new()
cond.match_target = &"hero"        # reaction は hero への incoming event を見る
cond.require_tags = [&"damage"]    # ...damage tag を要求する

trigger.arm(reservation, cond, 0)  # tick 0 で arm

# later: hero への attack が解決されたとき (sweep point)
var view := {"kind": &"hit", "source": &"orc", "target": &"hero", "tags": [&"damage"]}
for fired in trigger.on_event_resolved(view, current_tick):
    # standalone engine互換projection: conditionにmatchしたarmed reservation
    pass
```

`rumination` は同じ armed reaction が消費されるまでに何回 fire できるかを制御します。`duration` (`DURATION_UNLIMITED` を含む) は tick 上でどれだけ armed のまま残るかを制御します。

reservation pipelineではmatchをその場で解決しません。matchごとに独立したFIRE reservationをscheduleし、handler viewへversion 1の`reaction_fire_context`を渡します。ここには`fire_event_id`、1始まりの`fire_index`、trigger event id/tick/view/source/target/cellとconsumer-owned event view copyが入ります。pending copyは`reaction_fire_context_for_event(event_id)`で取得できます。armed slotは別instanceなので、残り回数とexpiryはpending FIREやsave/loadを跨いでも保たれます。

## 4. Worked example

同梱 demo `demos/action_resolution/demo_battle.gd` は、AP 回復 loop の上にこの counter をそのまま arm します (hero が incoming damage に反応、`rumination = 1`)。public API だけを使う canonical な非 sample 例です。`DemoBattle.run_trace(8)` を実行すると、trace (`reaction_fired` record) に reservation の fire が現れます。

## 5. Determinism

reservation は plain event と同じ全順序 comparator `(due_tick, priority, sequence)` で解決されます。reaction firing は resolved-event sweep point で駆動されます。したがって reaction が順序へ与える影響は deterministic であり、canonical trace に現れます。trace record を消しても outcome は変わりません (`concepts.md` §2.3)。


---

## 宣言的な条件と閉路 (v1.1)

v1.1 から reservation は条件集合を宣言できます (SEM §5.4–§5.6):

```text
solve_conditions          Array[EQConditionSpec] — AND、level 評価。空 = gate なし
invalidation_conditions   Array[EQConditionSpec] — OR。同時成立は invalidation-wins
```

`EQConditionSpec` は serializable な 1 項: `LINE_THRESHOLD` (event-line 値と閾値)、
`COUNTER` (減算カウンタ)、`NAMED_PREDICATE` (`register_predicate` で登録した名前 —
save を跨ぐのは名前だけ)。既存の `duration` / `rumination` はこの**糖衣**です
(duration = 期限閉路、rumination = 使用回数カウンタ)。

最頻ケースは spec すら不要 — 「3 回 or 5 ターンで閉じる反撃準備」は .tres 1 個・
コード 0 行で宣言できます (`dogfood/action_resolution/counterattack_preparation.tres`):

```text
kind = REACTION_PREPARATION
duration = 5          # OR 閉路: 5 tick (-1 で deadline ∞)
rumination = 2        # OR 閉路: 計 3 回
effect_name = &"counterattack"   # 宣言 linkage — register_effect が結線
```

すべての閉路は canonical trace の `closed_by` で説明されます: 宣言した条件 id、
または予約語 `duration` / `reaction_count` / `already_closed` / `actor_removed` /
`race_lost`。silent に閉じるものはありません。

## v1.2: 状態代数・関係グラフ・介入 (EQM-121〜127)

EBS 拡張ラウンド (SEM v1.2) で入った宣言群。すべて L2/L3 の opt-in — 宣言しなければ従来挙動のまま。

### 状態の対 (inv ペア) と一時変更

```gdscript
var algebra := EQStateAlgebra.new(rr.lines)
algebra.declare_inv_pair(&"欠損", &"虚飾", EQStateAlgebra.Rule.CANCEL)  # 相殺 = 符号付き 1 軸
algebra.grant_state(&"hero", &"欠損", 3)
algebra.grant_state(&"hero", &"虚飾", 1)   # 軸は +2 (欠損 2 に相殺)
rr.state_algebra = algebra                 # schema v3で導入、current schema v7でも保存
```

規則は pair ごとに `CANCEL` (相殺) / `EXCLUDE` (排他: 付与時に対を解除) / `COEXIST` (共存)。
rate の一時変更は modifier で宣言する — 凍結は `override 0`、鈍化/機敏は `add ±n`。重複しても解除時に自動で残りの実効 rate へ戻る:

```gdscript
var freeze := rr.lines.add_rate_modifier(&"ct.hero", "override", 0)
rr.lines.remove_rate_modifier(&"ct.hero", freeze)  # 凍結解除 → 元の実効 rate
```

### 関係グラフと波及・変換

```gdscript
var rg := EQRelationGraph.new()
rg.declare_relation_type({"name": &"召喚", "structure": EQRelationGraph.Structure.TREE,
	"on_dissolve": EQRelationGraph.Dissolve.SERIAL_SUTURE})  # 解消時は直列縫合
rg.bind(&"召喚", &"月", &"星")
rr.relations = rg
rr.declare_expansion_rule({"relation_type": &"召喚", "effect_tag": &"損害", "hop_cost": 1, "budget": 2})
# → tag <損害> の効果対象が関係に沿って月へも拡大 (targets_expanded が trace に出る)
rr.register_transform({"name": &"弱化反射", "match_tags": [&"弱化"], "kind": "retarget",
	"params": {"stage": "direct"}, "meta_level": 1, "priority": 0})
# → 効果の向き先を発行連鎖の段へ差し替え (対戦術)。反転系は kind: "state_inv"
```

変換は多重適用できる。どの変換がどの効果に適用され得るかの検証 (スキル効果グラフ) は利用側 (EBS 等) の責務で、EQM は決定的順序と trace と有界 round のみ保証する。

### メタレベルと介入・同時解決・操作フェーズ

```gdscript
var w := rr.open_window(&"mover", &"move", EQWindow.DEADLINE_UNLIMITED, 0, &"", 1)  # meta_level 1
rr.intervene_close(w.window_id, {"meta_level": 1})  # 同値 = 介入成功。解決済み効果は残り
                                                    # pending だけ closed_by: intervention で閉じる
var event_id := rr.submit(prepared)
rr.intervene_reservation(event_id, {"meta_level": 1}) # PREPARED単独予約をeffect実行前に無効化
rr.submit_bundle([a, b])       # 同 tick 原子解決 (member 間で反応は発火しない)
rr.open_phase(&"入力", [&"mirror.a"])  # 操作フェーズ checkpoint。同名再訪 = ループ検出 →
                                        # 開始点へ巻き戻し + cleared_inputs が trace に出る
```

メタレベルはスキル宣言の int 1 個 (`EQActionDefinition.meta_level`、未宣言 = 0)で、accepted submit時に予約へ固定する。同値は介入成功、不足時は`intervention_avoided`となる。reservation介入v1は通常PREPARED singletonだけを対象にし、bundle／race／reaction FIREはfail-closed。スキルごとの値付けは利用側のゲームデザイン判断。

### save

schema v3で上記の`relations` / `state_algebra` tableを導入し、schema v4で全reservationの
main／expiry effect-result mode binding、schema v5でscheduled reaction FIRE contextを導入した。
schema v6は回数でarmed slotが閉じた後もduration eventを保持する`reaction_expiries` tableを追加した。
current schema v7はさらに全reservationの`issued_meta_level`を保持する。loadは登録名・binding・occurrence／expiry identity・発行時metaを先に
検証し、安定error時は何も適用しない。原因を保存していなかったhistorical pending FIREや、
reservationを保存していなかったhistorical orphan expiryは推測せず拒否する。通常のhistorical
scheduled workとstill-armed expiryはmigrateする。
