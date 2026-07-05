# EQM-123 Self Review — pipeline 拡張 (展開・変換・provenance)

date: 2026-07-05
task: EQM-123 (queue Phase 12)
pattern: P2 (codex GPT-5.5 委譲 1 run、orchestrator 検収)

## Acceptance check (SEM v1.2 §6.4/§6.5)

- [x] **2a 展開**: `declare_expansion_rule({relation_type, effect_tag, hop_cost>0, budget>0})`。BFS は関係 id 内容昇順・双方向。**停止規律 = コスト** (hop ごとに hop_cost 消費、budget 超の hop をしない; 再訪も budget を消費 — visited set でない。ユーザー確定どおり)。展開ありのときのみ view["targets"] (先頭 = 元 target) + `targets_expanded` trace。relations 未接続 / rule 不一致 = 完全 no-op。
- [x] **2b 変換**: `register_transform({name, match_tags, kind: retarget|state_inv, params, meta_level, priority})`。適用順 = メタ降順 → priority 降順 → 登録順。**多重適用** (view が変化する限り再 round) + `max_transform_rounds=8` 超で fault (silent 無限ループ禁止)。retarget = provenance 段選択 (root = 条件を満たす最遠段 / direct、reach = transform.meta ≥ 段.meta、同値 OK、provenance 空 = 発行者へ)。state_inv = pair の inv 書き換え。適用ごと `effect_transformed` trace。意味論的 validation は consumer (EBS) 責務 — EQM は順序 + trace + 安全弁のみ。
- [x] **provenance**: `EQReservation.provenance` additive + to_dict/from_dict。OPERATION 経由の caused reservation に自動継承・追記 `[{actor, event_id, meta_level}]`。view に provenance / meta_level / state (state_name 宣言時) を公開。**event 側のみ** (event-line 拡張なし — 三面分離)。
- [x] **2c**: `_apply_effect` へ展開・変換済み view。**step 4 の sweep は素の `_view_of(res)` のまま** — trigger 挙動不変。
- [x] golden `expansion_transform` (targets_expanded / effect_transformed / resolved) + 既存 golden 全 green。
- [x] gate: `./tools/test.sh` PASS ×2 (files=63 checks=1154 failures=0; coverage 26/31)。

## 委任と検証

- codex は scope 厳守 (additive 3 product file + test + golden)、宣言なし不変条件・決定的 sort・fault 規約すべて反映。
- orchestrator 検収での修正 1 件: **複数 rule 一致時の展開が「最後の rule で上書き」**になっており、trace (全 rule 分記録) と view (最後のみ) が不整合 → **union 化** (origin 先頭、決定的 rule 順で初出のみ追加) + 多重 rule test 追加。
- 軽微 (修正せず記録): `_pick_stage_actor` の未使用 local `params` (無害)。`round` local が組込み関数名を shadow (GDScript 上合法)。

## API surface

- 新 public member (declare_expansion_rule / register_transform / max_transform_rounds / provenance / meta_level / state_name) を明示 `--update` + `API_SURFACE.md` note で反映。新 class なし。L3 leak なし。

## 申し送り

- EQM-125 (premature close) は本 task の `meta_level` 運搬と provenance をそのまま消費する。
- 展開の hop_cost/budget は rule 宣言に置いた (§8 語彙内の最小形)。actor state からの budget 支払いが必要になったら additive で拡張 (Q23 ガードレール)。
- state_inv は pair を transform params で宣言する形 (EQStateAlgebra の宣言と独立)。EQM-128 の acceptance で EBS 実ペアに揃えて整合を見る。
