# EQM-116 Self-Review 2026-07-02

Pattern: P0 (orchestrator-direct)。Repair: 0。

## Execution summary

SEM v1.1 §5.2 の race pattern を実装した。`submit_race(members) -> race_group_id`: 同一 effect・異なる solve_conditions の複数予約を通常 pipeline で発行し、最初に解決した member が勝者。勝者確定時に未確定の敗者を一掃 (pending conditional は除去、scheduled は cancel) し `closed_by: race_lost` + `race_group` field で trace。gid は deterministic 採番 (`eqm.race.<seq>`)。同時成立の勝敗は既存 §7.1 hook → 発行順に委ね、race 専用順序規則は作らない (Q28)。3 表示分離の最小実装: trace 全候補可視 (`race_opened`/`race_resolved`) = EQM debug、`EQDebugOverlay` の race_group 連続行集約 (`group_rows`) = game-dev debug、in-game は勝者の効果のみ presentation へ流れる構造で既に充足。

## Acceptance result — met

効果の単一適用 (同時成立時含む)・敗者の可視な一掃・replay byte 同一性・overlay 集約を test で固定。既存 UI metric 群は無変更 green (集約 row は別 role で rows() 契約不変)。

## Test summary

```text
./tools/test.sh -> RESULT: PASS; files=57 checks=910 failures=0
```

## Golden updates (explicit)

`tests/golden/api_surface.json` のみ。

## Deviations

- `_race_of` の stale entry (他経路で死んだ member) は放置許容 (解決に到達しないため無害; POLICY fallback 表)。race 帳簿の snapshot 化は EQM-117 の scope 判断に委ねる — 帳簿は「未解決 race の見た目」であり、member 予約自体が snapshot 対象 (conditional/scheduled) なので、v1.x では帳簿を復元時に submit_race 再構築で賄う (EQM-117 で判断・記録)。
- tests/golden の専用 fixture は作らず 2-run byte 同一性で被覆 (EQM-115 と同方針)。

## No sample-only completion / UX path reduction

合成 race シナリオの property 検証。OR 解決の入口は `submit_race` 1 本 (solve への OR mode 追加は不採用 — Q18/Q29 確定維持)。

## Repair-now / follow-up

なし。次: EQM-117 (snapshot v2 + save 境界 enforcement) READY。
