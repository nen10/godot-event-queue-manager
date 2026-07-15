# EQM-133 UX — reaction-expiry checkpoint

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---:|---:|---:|---|---|
| count終了時にstale expiryをcancelする | medium | high | low | reject | 凍結済み`already_closed` traceを失い、save有無で観測が変わる。 |
| armed rowだけでexpiryを保存する | low | high | low | reject | count終了後はarmed rowが消え、reservation identityを復元できない。 |
| live expiryを独立tableで保存する | high | low | medium | adopt | armed中／count終了後を同じevent identityで継続できる。 |
| private expiry resolverをgameから呼ぶ | low | high | low | reject | addon内部状態にconsumerを結合する。 |
| exact 1-event public boundaryを追加する | high | low | medium | adopt | expiry観測と次reservation解決を分離できる。 |

## Experience steps

1. 利用者は従来どおりdurationつきreaction preparationをsubmitする。
2. 回数終了でarmed slotが閉じても、duration eventはmaster timelineに残る。
3. schema v6 save/loadはそのeventとclosed reservation revisionを同一identityで継続する。
4. `resolve_one_scheduled_event()`を使うconsumerはexpiry 1件だけを処理し、次のreservationを別stepにできる。
5. 従来の`resolve_next()`利用者はexpiryを内部消費する既存挙動のまま使える。

UI／ゲーム上のexpiry表示、`already_closed`をどの演出にするかはconsumer-ownedであり変更しない。
