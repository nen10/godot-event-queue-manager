# policy を選ぶ: ジャンル対応表

policy は「次に誰の turn か」に答えます (L1)。game の turn 進行に合わせて選びます。下記の各 row には `demos/` 配下に runnable で golden-tested な demo があります。近いものを copy してください。すべての demo は public API だけを使い、自分の `EQConfig` を作ります。bundled default には依存しません。

| genre / feel | policy | demo | 順序の決め方 |
|---|---|---|---|
| 古典的 initiative / **team phase** | `EQFixedRoundPolicy` | `demos/phase_battle/` | round ごとに、`initiative` key で並べる (priority DESC)。initiative band で phase を作れる (allies → enemies など)。 |
| **Charge Time / ATB** | `EQCTBPolicy` | `demos/ctb_battle/` | actor が `speed` で charge し、cost を超えると行動。速い actor ほど turn が多い。 |
| **Energy threshold** | `EQEnergyPolicy` | `demos/energy_battle/` | tick ごとに `speed` で energy を得て、`threshold` で行動。spend 後に残る energy は inspect 可能。 |
| **Wait-based** (wait-turn) | `EQWaitTurnPolicy` | `demos/wait_turn_tactics/` | actor ごとの wait counter。低い wait が先。同 wait は `agility` で break。 |
| **Action economy / SRPG** (AP, reactions) | `EQActionResolutionPolicy` | `demos/action_resolution/` | tick ごとに AP が回復し、`ap_max` で turn ready。prepared / counter action には reservation / trigger を組み合わせる。 |
| **Stack / LIFO** (カードゲーム風 response) | *(composition, no policy)* | `demos/stack_resolution/` | item は同 tick を共有し、`priority = stack depth` にする。全順序 (priority DESC) により最後に push したものが先に解決される。 |

## Notes

- **Phase と stack には専用 policy は不要です。** どちらも既存の全順序 `(due_tick ASC, priority DESC, sequence ASC)` 上の composition です。phase は `EQFixedRoundPolicy` の initiative band、stack は L0 `EQRuntime` の `priority = depth` で表現します。これは意図的です。新しい genre は、新しい policy class を追加する前に composition を試してください (ROADMAP §3.1: L0/L1 を小さく保つ)。
- **決定性は統一されています。** すべての policy は同じ comparator を通り、同じ canonical trace kind (`resolved` と `decided_by` tie-break) を出します。各 demo は golden (`test_project/tests/golden/demo_*.trace.jsonl`) に対して approval-tested です (`DETERMINISM_TRACE_TEST_POLICY §5`)。re-baseline は `./tools/test.sh --update-golden <case>` だけで行います。
- **policy は Resource です。** `EQConfig.policy` には concrete subclass を割り当てます。null や base `EQPolicy` instance は validation error です。silent default にはなりません (`concepts.md` と `EDITOR_UI_CONTRACT.md` の config panel を参照)。

## どの demo を copy すべきか

- 「speed-based turn だけほしい」→ `ctb_battle`。visible な energy bar value が欲しければ `energy_battle`。
- 「味方全員が動き、次に敵全員が動く」→ `phase_battle`。
- 「wait / defer を持つ tactics」→ `wait_turn_tactics`。
- 「AP、prepared attack、counter」→ `action_resolution`。その後 `reservations.md` と `action_resolution.md` を読む。
- 「response spell が先に解決される stack」→ `stack_resolution`。

