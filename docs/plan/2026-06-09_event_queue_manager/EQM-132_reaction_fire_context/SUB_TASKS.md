# EQM-132 SUB_TASKS — reaction fire occurrence context v1

## Complexity

Class: C3

Reason:
- trigger engine、scheduled occurrence、effect callback、save/load、trace にまたがる公開 L2 contract である。
- 同じ armed reservation の複数回 FIRE と、FIRE 前後の保存を同時に正しく扱う必要がある。

Required artifacts:
- Task Resolution / Scheduled Task Audit
- UX / POLICY / IMPLEMENTATION_PLAN
- state/invariant table、dependency/test matrix

## Task Resolution

| candidate | decision | reason |
|---|---|---|
| 発火元 view を捨てたまま game 側で現在状態から推測する | reject | trigger-time の source/cell と FIRE-time の世界を混同し、replay 不能になる。 |
| armed reservation 本体へ最後の cause を保持する | reject | 未解決 FIRE が複数あると上書きされ、armed/expiry status も scheduled occurrence と競合する。 |
| FIRE ごとに reservation occurrence を複製し、event-id keyed context を pipeline が所有する | adopt | occurrence identity、複数 FIRE、save/load を一つの規則で扱える。 |
| trigger view 全体をゲーム語彙として解釈する | reject | EQM は serializable envelope の運搬だけを所有し、意味は adapter/game に残す。 |
| rumination/count と任意のゲームコストを結合する | reject | EQM は回数と順序だけを所有し、コスト関数は consumer policy である。 |

## Scheduled Task Audit

本 task は Amberground の実需要で確定した最小 public contract を閉じる。相互反応の fuel/cycle policy、typed expiry transaction、presentation/UI は本 task の acceptance に不要であり、EQM-132 から暗黙に実装しない。新規 scheduled task は作成しない。
