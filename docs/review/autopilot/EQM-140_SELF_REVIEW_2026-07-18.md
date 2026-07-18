# EQM-140 Self Review — sparse event-line polling

Date: 2026-07-18
Task: EQM-140 / roadmap Phase 15 / queue Phase 14
Primary classification: event-line determinism + runtime performance

## Outcome

`EQEventLines.poll_tick()`のall-line content sort + watched filterを、watched key filter +
live id content sortへ置き換えた。effective rateはcanonical base rate / modifier Arrayから
更新時に導出し、private `_effective_rates` cacheからO(1)で読む。

Canonical line payload、public API、snapshot schema、trace kind/field/order、`step_tick`順は
変更していない。relation-maintenance-only lineをwatched集合へ追加する意味論変更と、
`ctx_lines()`全表copyは本taskへ混ぜていない。

## Acceptance review

- [x] production poll selectionはwatched keysだけを列挙し、live canonical idsをcontent-sortする。
- [x] watched valueは無視、unknownはsilent、String/StringName keyは旧selectorとexact parity。
- [x] construction/issue/re-rate/modifier add/remove/restoreの全境界でcacheを同期する。
- [x] latest override、base+add、override中re-rate、zero skip、negative pollを固定した。
- [x] invalid操作はcache/modifier sequenceを変更しない。
- [x] in-place restoreはold cacheを除去し、primary default/overwrite、duplicate line後勝ちを再構築する。
- [x] cacheはserializeされず、trace/sweep rules/snapshot continuationは不変。
- [x] regression/performance discovery分離を維持し、双方PASS。

## Algorithm / state audit

| area | result |
|---|---|
| canonical state | `_lines`のvalue/base rate/modifier Array |
| derived state | `_effective_rates[id]` exactly one per existing line、非serialize |
| lookup | existing lineはcache read、unknownは従来どおり0 |
| mutation | successful issue/re-rate/add/remove後に対象lineをrefresh |
| restore | old line/cache clear → final payload load → silent full rebuild |
| selector | watched String/StringName keys → live id → de-duplicate → String content sort |
| full/global paths | `line_ids()` serialization、`ctx_lines()`、sweep rule scanは目的上不変 |

## Performance evidence

| path | legacy source work | current source work | deterministic reduction | advisory speedup range |
|---|---:|---:|---:|---:|
| sparse poll selection | 4,097 canonical ids | 36 watched keys (32 live) | 113.8x fewer source keys | 185.17–190.19x |
| effective-rate lookup | 32 modifier inspections | 0 modifier inspections + 1 cache read | modifier traversal removed | 18.28–18.55x |

各elapsed値は5 warmups後、6 samples（旧→新/新→旧を3回ずつ）のcentral-pair average。
batchはselector 80回、rate lookup 5,000回で、3 complete runsのraw sample/central値は
`docs/design/RUNTIME_PERFORMANCE_PROFILE.md`に記録した。test-only legacy helperは削除前の
production code shapeをcounterなしで複製している。

比率はselection/lookupだけで、poll progression/trace全体、`step_tick`、frame、consumer
runtimeの倍率ではない。re-rateはcache refreshのためmodifier深さ分をmutation時に払い、
その後のreadsを定数化する。このmutation tradeoffはtimed lookup値に含めない。

## Test summary

| command | result | classification |
|---|---|---|
| `./tools/test.sh` | PASS: 74 files / 1,831 checks / 0 failures (`20260718-232538-24404`); API/coverage/golden/package gates PASS | passed |
| `./tools/test.sh --performance` | PASS: 5 files / 49 checks / 0 failures (`20260718-232551-25295`) | passed |
| same performance command | PASS (`20260718-232613-25681`) | repeated evidence |
| same performance command | PASS (`20260718-232638-27568`) | repeated evidence |

## Deviation / repair-now audit

| item | classification | resolution |
|---|---|---|
| first reviewed legacy rate helper was semantically equal but not exact removed syntax | repair-now measurement validity | discarded runs `20260718-232119-10476` / `20260718-232205-13124` / `20260718-232226-14382`; exact range/index/type/base-local copyで3 runs再計測 |
| restore proof omitted primary/duplicate payload edges | repair-now proof completeness | primary missing/default、primary overwrite、duplicate line last-wins回帰を追加 |
| one generic work label mixed units | repair-now evidence clarity | source keysとmodifier inspections/cache readsをpath別に明記 |
| cache shifts re-rate work to mutation | accepted tradeoff | profile/self-reviewへscope明記、elapsedをlookup-onlyに限定 |

Independent re-reviewは修理後の現filesystemを再監査し、runtime、回帰境界、exact legacy
helper、work表現、profile/self-review、API surface、`git diff --check`の整合を確認した。
追加のrepair-now項目はない。

Repair-now: none.
Follow-up-ready: EQM-141 reaction FIRE condition semantics (already queued); relation-maintenance watch expansion and `ctx_lines()` require separate evidence.
Proof grade: `contract_tested` + deterministic work gate + environment-labelled advisory A/B.
