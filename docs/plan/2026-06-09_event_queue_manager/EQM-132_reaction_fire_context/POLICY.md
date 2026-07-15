# EQM-132 POLICY — reaction fire occurrence context v1

## Adopted contract

- `reaction_fire_context_version = 1` の JSON-safe Dictionary を public value contract とする。
- context は `fire_event_id`、`fire_index`、`trigger` を持つ。`trigger` は `event_id`、`view_index`、`tick`、`source`、`target`、`cell` を持ち、`event_view` は consumer-owned view の canonical deep copy である。
- `fire_index` は同じ armed reservation に対する 1-based の発火番号であり、`definition.rumination + 1` が最大発火回数になる既存規則と整合する。
- armed reservation と scheduled FIRE occurrence は別 instance にする。armed 側だけが remaining-rumination と expiry lifecycle を所有する。
- pipeline は FIRE event id を key に context を保持し、effect handler view へ deep copy を投影する。inspection API も deep copy のみ返す。
- 新 schema の pending reaction FIRE は context 必須。context を表現できない historical save に pending reaction FIRE が含まれる場合は stable rejection とし、推測して復元しない。
- EQM は source/target/cell のゲーム意味を解釈しない。consumer が `TRIGGER_SOURCE` 等へ写像する。
- 回数、duration、priority と consumer の AP/cost は独立 contract である。

## Rejected / deferred

- armed reservation 本体への mutable `last_cause`。
- world re-query による cause 再構築。
- whole reaction chain context/fuel policy。
- typed expiry effect commit result。expiry は既存 legacy hook/trace を維持する。

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| legacy `on_event_resolved()` | keep as projection of occurrence API | public trigger-engine tests/consumersを壊さない | major API redesign | existing trigger tests |
| context-less historical pending FIRE | reject, no fallback | cause の捏造を防ぐ | explicit migration source exists | save verification test |
| `reaction_fire_context` inspection/callback | same event-id keyed source, deep-copy projections | mirror driftを防ぐ | none | mutation-isolation test |

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| ARMED | armed instance は scheduled event map に入らず status=ARMED | occurrence scheduling が expiry を壊す | two-fire + expiry test |
| FIRE_PENDING | fresh reservation instance と exact event-id context が 1:1 | cause overwrite / alias | two fires queued before resolve |
| FIRE_RESOLVE | handler view の context は該当 event id の deep copy | 別 FIRE の cause 混入 | distinct source/index assertions |
| SAVE | scheduled FIRE と context が同じ row で roundtrip | replay divergence | snapshot continuation equality |
| INVALIDATE | event map と context map を同時に消す | stale context leak | invalidation cleanup test |
