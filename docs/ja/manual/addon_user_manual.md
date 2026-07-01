# Event Queue Manager アドオン利用者マニュアル

この文書は、Godot project に Event Queue Manager を導入して使う人向けの統合マニュアルです。既存の章別マニュアルを読む前に、実装済みの主導線、どこまで UI でできるか、どこからコードで扱うかを把握するための入口として使います。

## 1. 何を解決するアドオンか

Event Queue Manager は、ターン制・行動順・予約済みアクションの順序を決定的に扱う Godot 4.x アドオンです。

主導線は 2 つです。

| 導線 | 使う層 | 目的 |
|---|---|---|
| 単純な行動順 | L0 / L1 | actor を登録し、「次に誰が動くか」を policy で決める |
| 深い行動解決 | L2 | AP、準備、反応、予約、rollback を扱う |

ほとんどのターン制ゲームは、まず L0/L1 だけで始められます。reservation、trigger、transaction は必要になったときだけ opt-in してください。

## 2. 導入

1. `addons/event_queue_manager/` を自分の Godot project の `addons/` 以下へコピーします。
2. Project Settings -> Plugins で `Event Queue Manager` を有効化します。
3. scene に `EQManager` node を追加します。plugin 有効化後は Add Node から選べます。コードから作る場合は `EQManager.new()` でも構いません。

補足:

- core API は `class_name` 付きの GDScript class として実装されています。
- 標準導線は scene-local `EQManager` です。Autoload は任意です。
- 現時点の plugin は `EQManager` custom node type を登録します。Timeline Dock などの editor Control は実装・headless test 済みですが、Godot Editor の dock/menu として mount する glue は v1.x follow-up です。

## 3. 最小のターン順ループ

### 3.1 config を作る

`EQConfig` に concrete policy を入れます。base `EQPolicy` や null policy は validation error です。隠れた bundled default には頼らず、project 側で config を作ってください。

```gdscript
var config := EQConfig.new()
config.policy = EQCTBPolicy.new()
config.tie_break = &"sequence"

var validation := config.validate()
if not validation.is_valid():
	for issue in validation.errors():
		push_error("EQConfig: %s" % issue["code"])
```

`.tres` として保存しても、コードで生成しても構いません。重要なのは、ゲーム側が明示的に `EQConfig` を持つことです。

### 3.2 manager に設定し、actor を登録する

```gdscript
var manager := EQManager.new()
add_child(manager)
manager.configure(config)

manager.register_actor(&"hero").data["speed"] = 15
manager.register_actor(&"rogue").data["speed"] = 22
manager.register_actor(&"golem").data["speed"] = 8

manager.seed()
```

actor のパラメータは `EQActorState.data` に入れます。どの key を読むかは policy が決めます。例えば `EQCTBPolicy` は既定で `speed` を読みます。

### 3.3 turn_ready を受けて finish する

```gdscript
manager.turn_ready.connect(func(actor_id, entry):
	# ここでゲーム側の入力・AI・効果解決を行う。
	manager.finish_action(actor_id, EQActionResult.new(100, 0))
)

func _process(_delta):
	manager.advance_frame(8)
```

`EQManager.step()` は次の event を 1 つ進めます。`turn` event に到達すると `turn_ready` を emit し、`finish_action()` が呼ばれるまで suspend します。プレイヤー入力を待つゲームではこの suspend が await boundary です。

`advance_frame(budget)` は 1 frame で最大 `budget` 件まで進めます。time-slicing しても順序と trace は変わりません。

## 4. policy の選び方

| ゲーム感 | policy / 構成 | 主な actor data |
|---|---|---|
| 固定ラウンド、initiative、team phase | `EQFixedRoundPolicy` | `initiative` |
| CTB / ATB 風 | `EQCTBPolicy` | `speed` |
| energy threshold 風 | `EQEnergyPolicy` | `speed`, `energy` |
| wait-turn tactics | `EQWaitTurnPolicy` | `wait`, `agility` |
| AP 回復、準備、反応 | `EQActionResolutionPolicy` + reservation / trigger | `ap`, `ap_recovery` |
| stack / response 解決 | 専用 policy ではなく `priority = stack depth` の composition | game 側で depth を管理 |

最初は近い demo をコピーして、policy の export 変数だけ調整してください。対応 demo は `demos/` 以下にあります。

## 5. 次の順序を preview する

コードから見る場合:

```gdscript
var upcoming := EQPrediction.predict_turns(manager.runtime(), 5)
```

runtime HUD を使う場合:

```gdscript
var hud := EQTimelineHud.new()
add_child(hud)
hud.bind(manager, 5)
```

editor 用の `EQTimelineDock` Control も実装されていますが、現時点では Godot Editor の dock として自動表示されません。headless test では `set_preview(config, runtime, next_n)` で state を注入し、UI 表示順が `EQPrediction` と一致することを検証しています。

## 6. reservation / reaction を使うとき

reservation は「すぐ解決されない action intent」です。準備中、反応待ち、AP 回復後 ready、target 上の操作などを表します。

主要 class:

| class | 役割 |
|---|---|
| `EQActionDefinition` | action の種類、delay、duration、tags などの定義 |
| `EQReservation` | actor に紐づいた live reservation |
| `EQCondition` | trigger が見る条件 |
| `EQTriggerEngine` | armed reservation を event 解決時に fire する |
| `EQReservationRuntime` | reservation を scheduler に submit / resolve する |

例:

```gdscript
var definition := EQActionDefinition.new()
definition.kind = EQActionDefinition.Kind.REACTION_PREPARATION
definition.duration = EQActionDefinition.DURATION_UNLIMITED
definition.rumination = 1
definition.tags = [&"counter"]

var reservation := EQReservation.new(&"hero", definition)

var condition := EQCondition.new()
condition.match_target = &"hero"
condition.require_tags = [&"damage"]

var trigger := EQTriggerEngine.new()
trigger.arm(reservation, condition, 0)

var view := {
	"kind": &"hit",
	"source": &"orc",
	"target": &"hero",
	"tags": [&"damage"],
}

for fired in trigger.on_event_resolved(view, manager.runtime().scheduler.current_tick):
	# counter 解決
	pass
```

trigger sweep point はゲーム側が決めます。ダメージ確定後、演出前、割り込み可能なタイミングなど、ゲームごとの解決モデルに合わせて `on_event_resolved()` を呼んでください。

## 7. AP 行動解決と wait / rollback

AP 回復型の turn loop には `EQActionResolutionPolicy` を使います。

```gdscript
var config := EQConfig.new()
config.policy = EQActionResolutionPolicy.new()

var manager := EQManager.new()
manager.configure(config)
manager.register_actor(&"hero").data["ap_recovery"] = 12
manager.register_actor(&"orc").data["ap_recovery"] = 9
manager.seed()
```

manager-driven loop では、turn を閉じる入口は `manager.finish_action(actor_id, result)` です。`EQActionResolutionPolicy.wait_close(runtime, actor_id, result, transaction)` は runtime と transaction を自分で保持する explicit-transaction flow 用です。manager-driven loop で `wait_close()` だけを呼ぶと manager の suspend が解除されません。

rollback / preview には `EQTransaction` を使います。

```gdscript
var txn := EQTransaction.new(manager.runtime().scheduler)
txn.draft_push(10, 0, &"turn", &"hero")

if should_keep:
	txn.commit()
else:
	txn.rollback()
```

## 8. 保存、trace、決定性

順序は `(due_tick ASC, priority DESC, sequence ASC)` の int key で決まります。float は ordering key に使いません。

主な入口:

| 目的 | API |
|---|---|
| live queue の保存 | `EQScheduler.snapshot()` |
| snapshot restore | `EQScheduler.restore(data)` |
| save/load wrapper | `EQSaveAdapter.save(runtime)`, `EQSaveAdapter.load(runtime, data)` |
| trace を JSONL で出す | `EQManager.trace_jsonl()`, `EQRuntime.trace_jsonl()` |
| deterministic RNG | `EQRng` |

snapshot は schema version を持ちます。未知 version は silent migration せず、安定した load error として扱われます。

## 9. simulation と presentation を分ける

ゲームの状態更新と画面演出を混ぜないため、presentation 用の class があります。

| class | 役割 |
|---|---|
| `EQEffectRecord` | ダメージ、回復、状態変化などの効果 record |
| `EQEffectChunk` | 複数 record のまとまり |
| `EQPresentationEvent` | 表示対象、位置、重要度、依存関係 |
| `EQPresentationPolicy` | 即時表示、skip、player turn flush などの設定 |
| `EQPresentationBuffer` | presentation event の enqueue / flush |

addon はゲーム固有の効果意味論を決めません。効果 record をどのタイミングで作るか、trigger sweep と演出 flush をどう並べるかはゲーム側の解決モデルに合わせます。

## 10. validation と resilience mode

validation は `EQValidation` に集約されます。

```gdscript
var result := EQActionResult.new(-1, 0)
var validation := result.validate()
if validation.has_code(EQError.ACTION_NEGATIVE_COST):
	push_error("invalid action cost")
```

runtime には 2 つの mode があります。

| mode | 振る舞い |
|---|---|
| `EQRuntime.Mode.DEV` | anomaly を faults に記録し、advance loop を止める |
| `EQRuntime.Mode.SHIPPED` | consumer game を落とさず、invalid event を skip して trace に記録する |

正常入力では両 mode の trace は同じです。違いは anomaly 発生時だけです。

## 11. どの demo を見るべきか

| demo | 見る理由 |
|---|---|
| `demos/ctb_battle/` | 最小の speed-based turn order |
| `demos/energy_battle/` | energy threshold と持ち越し値 |
| `demos/wait_turn_tactics/` | wait / agility tie-break |
| `demos/phase_battle/` | fixed round / initiative band |
| `demos/action_resolution/` | AP、reservation、trigger、presentation |
| `demos/stack_resolution/` | priority による stack 解決 |
| `dogfood/action_resolution/` | public API だけで作った縦 slice |

## 12. 現時点の UI 範囲

成立しているもの:

- plugin 有効化後、`EQManager` node を Add Node から追加する導線。
- runtime HUD `EQTimelineHud` と debug overlay `EQDebugOverlay`。
- editor Control としての `EQTimelineDock`、`EQDebugInspector`、`EQTemplateGenerator`。
- UI headless metric tests による projection integrity、no-op button、debug leakage、sample separation の検証。

未成立または限定的なもの:

- `EQTimelineDock` / `EQDebugInspector` / `EQTemplateGenerator` を Godot Editor の dock/menu から開く導線。
- 汎用 `config_panel` の実装。
- 任意 policy を GUI で選ぶ wizard。
- reservation / transaction を GUI で authoring する画面。

つまり、v1.0 RC の単純 UX は「runtime/API と Add Node 導線」では成立していますが、「Editor 内で完結する設定・preview UI」としてはまだ follow-up があります。

## 13. 最初の実装チェックリスト

1. `EQConfig` を project 側で作った。
2. `config.policy` は concrete policy。
3. `config.validate()` が通る。
4. scene-local `EQManager` を置いた。
5. actor を `register_actor()` し、policy が読む `data` key を設定した。
6. `manager.seed()` を呼んだ。
7. `turn_ready` で action を決め、必ず `manager.finish_action()` で閉じる。
8. preview が必要なら `EQPrediction` または `EQTimelineHud` を使う。
9. 準備・反応・rollback が必要になった時点で L2 へ進む。

