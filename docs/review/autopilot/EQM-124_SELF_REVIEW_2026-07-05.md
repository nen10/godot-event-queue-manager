# EQM-124 Self Review — composite atomic bundle

date: 2026-07-05 / task: EQM-124 / pattern: P2 (codex 委譲 1 run)

## Acceptance check (SEM v1.2 §7.2)

- [x] `submit_bundle(reservations, delay)` — 全員 valid のときのみ発行 (部分発行なしの rollback)、WAIT/READY/OPERATION 拒否、`eqm.bundle.<seq>` 決定的採番。
- [x] bundle 解決 = 1 解決単位: member 順 = §7.1 hook → 発行順 (`order_hook_applied` が golden に乗る)、member 単位の lazy invalidation-wins、既存 2a/2b (展開・変換) を member ごとに適用、**member 間 sweep なし → 全適用後に単一 sweep → 単一 drain** (save 境界整合)。
- [x] `bundle_resolved` trace (bundle id + member 列、sweep 前に記録 — reaction_fired が必ず後に並ぶ)。
- [x] 公平 golden `fairness_bundle`: 順序独立の 2 効果 + 事後の個別反射誘発 (相談3 の二段構え) を 1 trace で被覆。
- [x] bundle 不使用経路は従来挙動 (既存 golden 全 green)。gate PASS ×2 (files=64 checks=1179; coverage 27/31)。

## 委任と検証

- codex は contract 準拠 + 自発的に bundle 帳簿の掃除を invalidation/race 経路 (`_clear_bundle_event_link/_clear_bundle_group`) へ配線 — 検収で妥当と判断 (dangling 帳簿の防止)。
- `_sweep(raw_view)` への変更 (旧 `_view_of(res)` 再計算) は同値 view の再利用で意味論不変 — 検収で確認。
- 軽微 (修正せず記録): `_sweep_bundle` の cascade 上限超過分岐が `_recheck_scheduled_invalidation`/`_evaluate_pending_conditional` を skip する (通常 `_sweep` は継続)。上限超過は fault 済みの anomaly path であり決定性への影響なし。対称性の是正は EQM-128 の acceptance で必要が出た場合に。

## 申し送り

- bundle member の展開・変換は member ごと独立適用 — 「bundle 全体への変換」は未定義 (需要が出たら additive)。
