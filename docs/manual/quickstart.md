# Quickstart — a CTB battle in a few lines

This walks through the L0/L1 flow (register → turn_ready → finish) with a
**project-created** config. The bundled `demos/ctb_battle/` is a learning-path
sample — your game makes its own `EQConfig`, never relying on a sample default.

## 1. Create a config (project asset)

In code:

```gdscript
var config := EQConfig.new()
config.policy = EQCTBPolicy.new()   # a concrete policy; a raw EQPolicy base is rejected
config.tie_break = &"sequence"      # deterministic total tie-break
```

Or author it as a `.tres` and load it. Either way the config is **yours**, not a
hidden bundled default.

You can validate before use:

```gdscript
var v := config.validate()
if not v.is_valid():
    for issue in v.errors():
        push_error("config: %s" % issue["code"])
```

## 2. Add the manager and register actors

```gdscript
var manager := EQManager.new()   # scene-local; add as a child node (autoload optional)
add_child(manager)
manager.configure(config)

manager.register_actor(&"hero").data["speed"] = 15
manager.register_actor(&"rogue").data["speed"] = 22
manager.register_actor(&"golem").data["speed"] = 8
manager.seed()                   # schedules the first turns via the policy
```

Per-actor stats (here `speed`) live in `data` — the engine fixes no built-in
progression field, so any policy reads what it needs.

## 3. React to turns

```gdscript
manager.turn_ready.connect(func(actor_id, _entry):
    # the actor is up; decide its action, then finish it:
    manager.finish_action(actor_id, EQActionResult.new(/*cost*/ 100, /*unused for CTB*/ 0))
)
manager.event_resolved.connect(func(entry): print("resolved: ", entry.actor_id))
```

Drive the queue from your game loop:

```gdscript
func _process(_dt):
    manager.advance_frame(8)   # resolve up to 8 turns this frame (time-sliced; order is deterministic)
```

A heavier action (larger `cost`) delays the actor's next turn; a wait is
cheaper. Haste/slow are just changes to `data["speed"]`.

## 4. Preview what's next (optional)

```gdscript
var upcoming := EQPrediction.predict_turns(manager.runtime(), 5)  # next 5 actor ids
# prediction is pure: it never mutates the live queue.
```

## Where to go next

- Concepts (event-line / event / trace, and the L0→L3 layers): `docs/design/EVENT_MODEL_SEMANTICS.md`.
- The sample: `demos/ctb_battle/`.
- Errors and validation: `docs/design/ERROR_CONTRACT.md`.
