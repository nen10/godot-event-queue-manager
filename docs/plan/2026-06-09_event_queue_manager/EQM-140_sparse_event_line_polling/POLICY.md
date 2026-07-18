# EQM-140 POLICY — watched selector and derived effective-rate cache

## Adopted decisions

- canonical truthは`_lines`内の`value`、base `rate`、modifier Array。
- `_effective_rates`は非serializeの派生Dictionaryで、existing lineごとに一entryを持つ。
- effective rate計算はmodifier Arrayを宣言順に読み、最後に現れた`override`を採用する。
  overrideがなければbase rate + 全`add`の合計とする。
- construction/issue/re-rate/modifier add/remove/restoreは対象cacheを同期更新する。
- restoreはcanonical payloadを全て読み終えてからcacheをsilent rebuildし、trace、fault、
  registered sweep-rule Callablesを変更しない。
- poll selectorはwatched keyだけを走査し、existing lineへfilter後に`String(id)` content順でsortする。
  watched valueは読まず、unknown keyは従来どおりsilentに除外する。
- effective rate 0はskipし、negative rateは従来どおりprogressionする。

## Compatibility / determinism

- `step_tick`のprimary sync → deadline → poll → sweep → relation maintenance → invalidation →
  pending evaluation順は不変。
- watched集合の導出元を増減しない。relation maintenance参照の追加は本task外。
- public API、API golden、snapshot schema、trace kind/field/orderは不変。
- hard gateはexact values/trace/snapshot、live watched ids、cache transition、deterministic work count。
  elapsed speedupは同一processのadvisoryであり合否条件にしない。
- 通常回帰はperformance fixtureをdiscoverせず、performance commandはperformanceだけを走らせる。

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| poll時full `line_ids()` | remove | watched sparsityを失う | immediate | exact selector parity + work count |
| lookup時modifier scan | remove from read path | depthに比例する | immediate | legacy formula parity + cache transitions |
| missing-cache lazy scan | do not add | invariant defectを隠す | n/a | every existing line has cache after mutation/restore |
| serialized effective rate | do not add | derived stateをschemaへ混ぜる | n/a | `to_dict` exact/no cache key |
| relation-maintenance watch expansion | defer | progression semantics change | separate contract decision | n/a in EQM-140 |

## State / Invariant proof

cache refreshはcanonical mutationが成功した後だけ行う。invalid line/kind/modifier操作はcanonical、
cache、sequenceを変更しない。restoreはold line/cacheを両方clearし、最終canonical payloadから
一度だけ再構築するため、duplicate payloadやprimary overwriteも最終値と一致する。
