# Determinism / Trace Test Policy

対象: Event Queue Manager core scheduler, policies, reservations, triggers, transaction, presentation buffer, demos, timeline UI (projection)
目的: 「event の解決順序」という product の中心価値を、canonical trace と property test で機械的に証明する。

上位方針: `docs/devflow/policy/UI_TESTABILITY_POLICY.md` (layer L4)

---

## 0. 結論

順序は EQM の主要 product value であり、順序の証明を screenshot にも sample 動画にも依存させない。

```text
scheduler run (seeded)
  -> canonical trace (JSONL)
    -> golden fixture diff (approval)
    -> property / metamorphic checks
      -> acceptance decision
```

## 1. Canonical trace

### 1.1 Record format

resolved event 1 件 = 1 record:

```json
{"i": 12, "tick": 30, "seq": 45, "event_id": "e0045", "kind": "resolved",
 "actor": "u_orc_1", "action": "prepared_attack",
 "cause": "timer",
 "tie_break": {"compared": ["due_tick", "priority", "sequence"], "decided_by": "sequence"},
 "effects": [{"target": "u_hero", "stat": "hp", "delta": -12}]}
```

`cause` の値: `timer | trigger:<tag> | rumination | operation | wait | ready`

### 1.2 Canonical rules

- 順序決定 key (tick, priority, seq) は int のみ。float を含む trace は invalid。
- key の出力順は固定。wall-clock、node path、object address を含めない。
- 同 seed・同入力で byte 単位再現可能であること。
- 解決順 index `i` を必ず持つ。

## 2. Golden trace (approval testing)

- fixture: `tests/golden/<case>.trace.jsonl`
- 比較は exact match。fail 時は diff を report する。
- baseline update は明示操作のみ:

```text
1. diff を読み、regression / accepted change を分類する。
2. accepted change の場合のみ、明示 flag (例: ./tools/test.sh --update-golden <case>) で再生成する。
3. self-review に diff 要約と理由を記載する。golden 更新を含む commit はその記載なしに作らない。
```

- CI / 通常 run での自動更新は禁止。
- 並列実行下: 通常 run の golden は read-only (比較のみ) で並列安全。`--update-golden` は serial・単一プロセスで、異なる golden file のみを書く (`PROJECT_PROFILE.md` Test Design Policy)。並列でだけ起きる golden diff は hermeticity bug であり retry で隠さない。

## 3. Property / metamorphic tests

最低限の性質:

| property | 内容 |
|---|---|
| permutation invariance | 同一 (tick, priority, seq) 集合を任意順で push しても pop 順は同一。 |
| snapshot continuity | 途中 snapshot -> restore 後の継続 trace は、無停止 run の trace と一致。 |
| replay determinism | 同 seed の再実行で trace が byte 一致。 |
| prediction purity | predict(N) の結果 == その後実際に解決される N 件。predict は live state を変更しない (前後 snapshot 一致)。 |
| presentation neutrality | presentation flush policy を変えても EffectRecord (simulation 側) trace は不変。 |
| policy metamorphics | 例: CTB で全 speed を等倍しても順序不変。wait turn で全 wait に定数加算しても順序不変。 |
| rollback identity | draft -> rollback 後の trace は、draft 前 snapshot からの trace と一致。 |

性質は phase 進行に合わせて追加する。各 policy task は自 policy の metamorphic property を最低 1 つ持つ。

## 4. Explanation as data

順序決定理由は文字列ではなく構造化 data で生成する:

```gdscript
{
  "chosen": "e0045",
  "candidates": [
    {"event_id": "e0045", "due_tick": 30, "priority": 2, "sequence": 45},
    {"event_id": "e0046", "due_tick": 30, "priority": 2, "sequence": 46}
  ],
  "decided_by": "sequence"
}
```

- core test: explanation の `decided_by` と比較 key が comparator 実装と一致する。
- UI test (L4): order_inspector はこの data を描画する projection であり、独自文言で理由を再構成しない。
- timeline projection integrity: 表示順 == prediction 順 (UI_LAYOUT_METRIC_TEST_POLICY.md §5.9)。

## 5. Demo trace gate

各 demo は headless 実行で golden trace を持つ:

```text
demos/ctb_battle        -> tests/golden/demo_ctb_battle.trace.jsonl
demos/wait_turn_tactics -> tests/golden/demo_wait_turn.trace.jsonl
demos/action_resolution -> tests/golden/demo_action_resolution.trace.jsonl
```

demo の「動いた」は人間の目視ではなく trace 一致で証明する。画面エフェクトの良否は analog test 領域。

## 6. Report / 実行

- 出力: `.godot_user/test-runs/<run-id>/traces/`
- `./tools/test.sh` が golden 比較と property test を含む。
- 失敗分類は `docs/devflow/LINEAR_AUTOPILOT_QUEUE.md` の failure class に従う。golden diff の自動容認は `repair-now` 相当の違反として扱う。
