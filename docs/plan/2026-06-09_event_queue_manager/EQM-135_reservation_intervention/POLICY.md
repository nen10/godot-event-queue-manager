# EQM-135 POLICY — reservation meta intervention

## Adopted contract

- `intervene_reservation(event_id, intervener)`はscheduled event identityで通常のPREPARED singletonだけを対象にする。
- 予約側metaはsubmitが受理された時点でinstanceへ一度だけ固定し、save/loadとruminationを跨いで再samplingしない。v1搭載値は`definition.meta_level`のcopyである。
- `intervener.meta_level >= reservation issued meta`なら介入成功。同値は成功する。
- 成功はscheduler／pending／snapshot tableから対象を除去し、effectを実行せずstatusをINVALIDATEDにする。
- 成功traceは既存語彙`event_invalidated` + `closed_by: intervention`を使い、対象／介入側metaとoptional intervener event idを持つ。
- meta不足は正常結果として`intervention_avoided`を記録し、scheduler、reservation、snapshotを変更しない。
- 存在しないid、非PREPARED、非pending、bundle、race、reaction FIREは単一stable errorでfail-closedし、対象状態を変更しない。

## Rejected / deferred

- explicit windowのcloseとの統合。
- bundle member単体、race member、reaction FIRE occurrenceへの介入。
- consumer側の損害、視界、範囲、intervener meta算定。

## State / Invariant Table

| state | invariant | proof |
|---|---|---|
| ISSUED | instance metaはsubmit受理時に一度だけ固定 | definition変更後の比較 + save row |
| AVOIDED | meta不足では対象event/status/save rowが不変 | avoid test |
| INTERVENED | scheduler、pending、save rowから同時に消失しeffect未実行 | success/equal tests |
| REJECTED | 非対応context／unknown idで状態不変、stable fault | rejection matrix |
| TRACED | 結果traceは介入呼び出し時に一度だけ記録 | ordered trace assertions |
