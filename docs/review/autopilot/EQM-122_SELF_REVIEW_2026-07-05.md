# EQM-122 Self Review — 関係グラフ backend

date: 2026-07-05
task: EQM-122 (queue Phase 12)
pattern: P2 (codex GPT-5.5 委譲 1 run、orchestrator 検収 + 配線)

## Acceptance check (SEM v1.2 §13.1)

- [x] 関係型宣言 (name / category / inverse / TREE|GRAPH / maintenance = EQConditionSpec 相当 or null / sweep 宣言 (既定 = primary threshold) / on_dissolve = NONE|SERIAL_SUTURE)。同名再宣言は置換、不正 enum・空名は fault。
- [x] 関係 instance: `eqm.rel.<seq>` 決定的採番・reuse なし。TREE 制約は bind 時 validation (拒否 + fault; mode 分岐は上位責務)。GRAPH はループ許容 (解析)。
- [x] 直列縫合: A→B→C の中間解消で A→C を `relation_rebound` (via = 解消 id) として結線。端では縫合しない。
- [x] 維持条件 sweep: `run_maintenance(sweep, ctx, predicates)` — relation id 内容昇順、EQConditionEval 流用 (LINE_THRESHOLD / NAMED_PREDICATE)、不成立 = dissolve(cause: maintenance_failed)、未登録 predicate = fault + 維持。
- [x] invalidate_actor 連動: EQReservationRuntime.relations (optional 接続) → 正規離脱経路が incident 関係を解消時規則経由で dissolve (配線 test 有)。
- [x] trace kinds: relation_bound / relation_dissolved / relation_rebound / relation_inverted。serialize roundtrip (内容順 sort、StringName 素 sort 不使用 — EQM-121 の決定性教訓を contract に明記して委任)。
- [x] 月/星 acceptance 例: 召喚 tree + 解析 GRAPH + 復讐 = 追跡 invert。
- [x] gate: `./tools/test.sh` PASS ×2 (files=62 checks=1103 failures=0; coverage 24/31)。

## 委任と検証

- codex は contract どおり新規 2 file のみ・failures=0 で納品。sort は全箇所 content-order (指示反映)。
- orchestrator 検収での発見・修正 1 件 (**repair-now**): `run_maintenance` の `var maintenance: Dictionary = decl.get("maintenance", null)` — maintenance 無し型が対象 sweep に乗ると **typed-null 代入の engine error + 誤 fault が毎 sweep 発生** (probe で実証)。untyped 化して null 分岐を先行させ、隔離 regression test を追加 (初版 test は既存 fixture の再 fault を数え損ねたため隔離 instance に修正)。
- orchestrator 追加実装: EQReservationRuntime への optional `relations` 配線 + invalidate_actor 統合 + test (queue acceptance の「invalidate_actor 連動」は runtime 側配線を要するため、L2 file へは committer 側で最小 additive)。

## API surface

- `EQRelationGraph` を L3 登録、`--update` + `docs/design/API_SURFACE.md` 追記。EQReservationRuntime.relations は untyped var (L2 surface に L3 型シグネチャを出さない)。leak gate ok。

## 申し送り

- run_maintenance の呼び出し元 (どの sweep 点で駆動するか) は pipeline 統合の関心 — EQM-123 の 2a 展開と同時に、sweep rule registry (§4.7) 経由で「宣言 sweep 名 → run_maintenance」を配線するのが自然。
- 縫合の構造制約再検証 (縫合後 TREE を破るケース) は bind 経由なので既存 validation が効く (test 済み)。
