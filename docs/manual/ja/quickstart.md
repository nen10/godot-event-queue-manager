# Quickstart: 数行で CTB battle を動かす

この章では、L0/L1 の流れ (register → turn_ready → finish) を、**project 側で作成した** config で動かします。同梱の `demos/ctb_battle/` は学習用 sample です。自分の game では hidden bundled default に頼らず、自分の `EQConfig` を作ります。

## 1. config を作る (project asset)

コードで作る場合:

```gdscript
var config := EQConfig.new()
config.policy = EQCTBPolicy.new()   # concrete policy。raw EQPolicy base は rejected
config.tie_break = &"sequence"      # deterministic total tie-break
```

`.tres` として author して load しても構いません。どちらの場合も config は**自分の project のもの**であり、隠れた bundled default ではありません。

使用前に validate できます。

```gdscript
var v := config.validate()
if not v.is_valid():
    for issue in v.errors():
        push_error("config: %s" % issue["code"])
```

## 2. manager を追加し、actor を register する

```gdscript
var manager := EQManager.new()   # scene-local。child node として追加する。autoload は任意
add_child(manager)
manager.configure(config)

manager.register_actor(&"hero").data["speed"] = 15
manager.register_actor(&"rogue").data["speed"] = 22
manager.register_actor(&"golem").data["speed"] = 8
manager.seed()                   # policy を通じて最初の turn を schedule
```

actor ごとの stats (ここでは `speed`) は `data` に入れます。engine は built-in progression field を固定しません。policy が必要な field を読みます。

## 3. turn に反応する

```gdscript
manager.turn_ready.connect(func(actor_id, _entry):
    # actor の番。action を決めてから finish する:
    manager.finish_action(actor_id, EQActionResult.new(/*cost*/ 100, /*unused for CTB*/ 0))
)
manager.event_resolved.connect(func(entry): print("resolved: ", entry.actor_id))
```

game loop から queue を進めます。

```gdscript
func _process(_dt):
    manager.advance_frame(8)   # この frame で最大 8 turn を解決する。time-sliced でも順序は deterministic
```

重い action (大きい `cost`) は、次の turn を遅らせます。wait は軽くできます。haste / slow は単に `data["speed"]` の変更です。

## 4. 次の順序を preview する (任意)

```gdscript
var upcoming := EQPrediction.predict_turns(manager.runtime(), 5)  # next 5 actor ids
# prediction は pure。live queue を mutate しません。
```

## 次に読むもの

- Concepts: event-line / event / trace と L0→L3 layer は `docs/design/EVENT_MODEL_SEMANTICS.md`。
- sample: `demos/ctb_battle/`。
- error と validation: `docs/design/ERROR_CONTRACT.md`。

