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
    # `fired` は condition に match した reservation。ここで counter を解決する
    pass
```

`rumination` は同じ armed reaction が消費されるまでに何回 fire できるかを制御します。`duration` (`DURATION_UNLIMITED` を含む) は tick 上でどれだけ armed のまま残るかを制御します。

## 4. Worked example

同梱 demo `demos/action_resolution/demo_battle.gd` は、AP 回復 loop の上にこの counter をそのまま arm します (hero が incoming damage に反応、`rumination = 1`)。public API だけを使う canonical な非 sample 例です。`DemoBattle.run_trace(8)` を実行すると、trace (`reaction_fired` record) に reservation の fire が現れます。

## 5. Determinism

reservation は plain event と同じ全順序 comparator `(due_tick, priority, sequence)` で解決されます。reaction firing は resolved-event sweep point で駆動されます。したがって reaction が順序へ与える影響は deterministic であり、canonical trace に現れます。trace record を消しても outcome は変わりません (`concepts.md` §2.3)。

