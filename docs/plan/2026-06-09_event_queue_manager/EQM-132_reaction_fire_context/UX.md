# EQM-132 UX — reaction fire occurrence context v1

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---:|---:|---:|---|---|
| handler が armed 時 target だけを受け取る | low | high | low | reject | incoming source を安全に参照できない。 |
| handler が versioned reaction context を受け取る | high | low | medium | adopt | trigger-time fact と scheduled FIRE を追跡できる。 |
| reservation Resource にゲーム固有 `TRIGGER_SOURCE` field を追加する | low | high | medium | reject | addon/game 境界を破る。 |

## Experience steps

1. 利用者は従来どおり reaction preparation と condition を submit する。
2. matching event view の commit 後 sweep で、EQM は独立した FIRE occurrence を schedule する。
3. effect handler は reservation view の `reaction_fire_context` から、FIRE event id、trigger event id、tick、view index、source、target、cell、元 view、1-based fire index を読む。
4. save/load 後も同じ pending FIRE occurrence が同じ context で解決する。
5. trace の `reaction_fired` から FIRE と trigger occurrence の対応を追跡できる。

維持: `on_event_resolved()` の reservation 配列 API、従来の condition/rumination/duration authoring。

保留: typed expiry transaction、reaction chain のゲーム上の fuel、editor projection。
