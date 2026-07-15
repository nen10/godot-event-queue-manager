# Action Resolution (AP 回復型 turn)

`EQActionResolutionPolicy` (L1 policy, L2-aware) は action point loop を駆動します。各 actor は tick ごとに AP を回復し、`ap_max` に到達すると行動できます。この章では turn loop、**wait / ready / end-turn** semantics、`EQTransaction` による **rollback** を扱います。

---

## 1. policy

```text
ap_key             = &"ap"            actor ごとの AP field
recovery_key       = &"ap_recovery"   actor ごとの tick あたり AP 回復量 (なければ recovery_per_tick)
ap_max             = 100              turn ready になる AP
recovery_per_tick  = 10               actor が recovery_key を持たない場合の default recovery
action_ap_cost     = 100              finish が cost 0 を報告した場合に消費される AP
```

actor ごとの recovery は actor の data に設定します。速い actor はより早く `ap_max` に到達し、より頻繁に行動します。

## 2. turn loop (manager-driven)

```gdscript
var config := EQConfig.new()
config.policy = EQActionResolutionPolicy.new()      # concrete policy。base instance は使わない

var manager := EQManager.new()
manager.configure(config)
manager.register_actor(&"hero").data["ap_recovery"] = 12
manager.register_actor(&"orc").data["ap_recovery"] = 9
manager.seed()

while true:
    var e = manager.step()                          # 次の ready turn。なければ null
    if e == null:
        break
    var actor: StringName = e.actor_id
    # ... actor の action を解決する (effects, reactions, visuals) ...
    manager.finish_action(actor, EQActionResult.new(100, 0))   # cost=100, delay=0
```

`EQActionResult.new(cost, delay)`: `cost` は消費 AP です。0 の場合は `action_ap_cost` が default cost として使われます。`delay` は次の grant を shift します。

### 2.1 finish_action と wait_close (重要)

`manager.step()` は acted actor 上で manager を **suspend** します (`is_awaiting_turn()` が true になります)。この suspend を解除し、policy に次の ready turn の schedule を委譲するのは `manager.finish_action(actor, result)` だけです。

runtime に対して `policy.wait_close(runtime, actor, result)` を直接呼んでも、manager の suspend は解除されません。manager-driven loop では 1 turn 後に deadlock します。`wait_close` は **explicit-transaction flow** 用です。runtime と transaction を自分で保持している場合に使います。これは実際の dogfood friction として見つかった点です (`docs/review/DOGFOOD_FRICTION_2026-06-18.md`, F1)。

```text
manager-driven loop       -> manager.finish_action(actor, result)
explicit-transaction flow -> policy.wait_close(runtime, actor, result, transaction)
```

## 3. Wait / ready / end-turn

loop を形作る reservation kind です (`reservations.md` も参照):

- **WAIT**: current turn を早く終え、**READY** reservation を schedule します。actor は AP 回復後に次の turn を得ます。`wait_close` はこれを **wait/end-turn commit boundary** で行います。working changes は turn close でちょうど commit されます (EQM-071)。半分だけ適用された wait が観測されることはありません。
- **READY**: wait/AP recovery によって作られる turn-grant です。解決されると actor に turn が渡されます。`EQActionResolutionPolicy.ready_reservation_for(runtime, actor_id, spent)` は actor 用の READY reservation を作ります。

これらが解決される順序は他の event と同じ全順序 `(due_tick, priority, sequence)` です。wait/ready は determinism を壊しません。

## 4. EQTransaction による rollback

`EQTransaction` は schedule changes を **working copy** に stage します。action を preview し、live queue には触れずに commit または discard できます。

```gdscript
var txn := EQTransaction.new(runtime.scheduler)   # live scheduler の working copy
txn.draft_push(due_tick, priority, &"turn", &"hero")  # scheduled event を stage
txn.draft_cancel(some_event_id)                       # cancellation を stage

if txn.is_live_unchanged():
    pass                          # まだ何も stage されていない
# decide:
txn.commit()                      # working copy を live scheduler に適用
# or
txn.rollback()                    # discard。live scheduler は元のまま
```

Guarantees:

- `working()` は staged scheduler、`draft()` は staged events の一覧です。
- `rollback()` は live scheduler を transaction 開始前と byte-identical に保ちます。partial apply は起きません。
- `commit()` は atomic に適用します。`is_committed()` で確認できます。

「今行動するか wait するか」の preview、undo、wait/end-turn boundary はすべて、この working-copy primitive の上に構築されます。consumer code で ad-hoc snapshot を作る必要はありません。

## 5. Worked example

`demos/action_resolution/demo_battle.gd` は end-to-end の public-API-only slice です。この policy による AP turn、armed counter (reservation + trigger)、simulation effects、flushed visuals、deterministic trace を含みます。copy 元にする reference であり、§2.1 の通り manager-driven path として `manager.finish_action` を使っています。


---

## L2 natural path (v1.1)

v1.1 の pipeline (`EQReservationRuntime`, SEM §6.1) では、配線は 3 つの宣言に畳まれます。
条件・反応・効果を使う場合の推奨形です:

```gdscript
var rr := EQReservationRuntime.new()
rr.runtime.register_effect(&"counterattack", func(view): return [ ...EQEffectRecord... ])
rr.submit(load("res://.../counterattack_preparation.tres") ...)
```

- **宣言 linkage**: .tres の `effect_name` が handler を名指しします。設定済みで未登録なら
  安定 error (`eqm.effect.unregistered`) — silent skip はしません。
- **単一の解決サイクル**: pop → effect → chunk → sweep → drain (`last_drained`)。
  解決の間 chunk は空なので、`EQSaveAdapter.save(rr.runtime, rr)` は save 境界
  (`is_save_boundary()`) でのみ成立します (境界外は `eqm.save.blocked`)。
- **発火した反応は schedule されます** (その場で解決しない) — master timeline が唯一の
  解決権威のまま、全 step が trace に残ります。

外部 state のtransactionを handler 内で一度だけcommitし、その成功時に作った複数の
event viewを一つのouter sweepへ渡す場合は、型付きv1を登録します。

```gdscript
rr.runtime.register_effect_commit(&"transactional", func(view):
    var candidate := EQEffectCommitResult.make_success(records, ordered_event_views)
    var validation := candidate.validate() # world swap前のpure gate
    if not validation.is_valid():
        return EQEffectCommitResult.make_failure({"code": "consumer.invalid_candidate"})
    commit_candidate_state_once()
    return candidate
)
```

`SUCCESS`だけがrecordsをchunkへ積み、ordered event viewsを一つのbatch境界でsweepします。
`FAILURE {diagnostic}`はrecords 0件・sweep 0回です。直近結果は
`last_effect_commit_outcome()` のdeep copyから観測できます。v1は単一予約のmain effect専用で、
atomic bundle memberと`expiry_effect_name`では明示的に拒否されます。これら二つのcontextは
既存Array handlerだけを使用してください。
初回のaccepted submitはmain／expiry両handlerのmode（0 legacy / 1 typed）をreservationへ
保存します。save/loadとresolutionはこのbindingを再検査するため、pending workを残したまま
named handlerをlegacy↔typedへ変更して意味をすり替えることはできません。不一致は
`eqm.effect.commit_result_binding_mismatch`で通知され、binding fieldのないschema v1-v3 saveはlegacyのままです。
schema v4が両binding fieldを導入し、current schema v5 writerも必ず書きます。readerが欠落fieldをlegacy 0へ
migrateするのはschema v1-v3だけです。v4以降のreservationでどちらかが欠ける場合は
`eqm.effect.commit_result_version_unsupported`としてstate適用前に拒否します。v3 readerは
top-level versionでv4 bundle全体を拒否するため、typed bindingを無視して解釈し直しません。
current readerもschema v1-v3で明示されたnonzero bindingを
`reason: binding_not_supported_by_schema`で拒否するため、top-level versionだけを書き換えても回避できません。

scheduled reaction FIREのhandler viewにはversion 1の`reaction_fire_context`も入ります。FIRE eventと1始まりの使用回数を識別し、trigger event id/tick/ordered viewとconsumer-owned value copyを保持します。schema v5はscheduled rowごとにこれを保存します。armed stateとpending FIREは別reservation instanceであり、保存原因を持たないhistorical pending FIREは現在worldから再構築せず拒否します。

OPERATION targetはsubmit時点でnon-emptyかつregisteredでなければなりません。有効に発行された
後でeffectがactorを除去しても、現在のrecordsとouter sweepは完了します。EQMが止めるのはownerが
不在になった暗黙のfuture work（non-reaction ruminationの再submitと、その後離脱したtargetへ
OPERATIONがcaused armする処理）だけです。このguardはGAME上の「撃破」を定義しません。撃破後も関与する
GAME ruleなら、そのentityをregisteredのままにできます。

dogfood の手動配線 `run_trace()` はこの path 以前の対照であり、同 file の
`run_l2_trace()` が natural path のリファレンスです。
