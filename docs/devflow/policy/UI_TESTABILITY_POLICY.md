# UI Testability Policy

対象: Event Queue Manager の Godot Editor 向け UI surface 全体
目的: スクリーンショットと人間目視に依存せず、editor UI の構造的品質を自動テストの acceptance gate にする。あわせて、人間の感性 feedback を構造化して取り込む経路を定義する。

origin: godot-hex-map-lab の UI Layout Metric Test policy を、event queue domain 向けに一般化した。

---

## 0. 結論

Event Queue Manager の core は headless / deterministic / serializable である。この性質を UI テスト容易性の基盤に使う。

```text
EQSnapshot / validation result / prediction result / draft state
  -> surface model (plain data)
    -> Control tree (projection)
      -> layout snapshot JSON
        -> metric evaluator
          -> fail / warn / info report
            -> acceptance decision
```

- Editor UI は「注入された headless state の projection」として実装する (**Projection-first UI**)。
- 構造的品質 (truncation, scroll不能, no-op button, debug leakage, 状態矛盾, 表示順序の不一致) は数値・状態評価で gate する。
- 感性的品質 (美しさ、迷いにくさ) は Layout Calibration Loop と Analog Test に分離し、構造評価と混ぜない。

## 1. Editor surfaces

roadmap Phase 10 時点の予定 surface。確定値は `docs/ui/EDITOR_UI_CONTRACT.md` が持つ。

```text
timeline_dock        : next-N preview と順序表示
order_inspector      : 順序決定理由の explanation 表示
config_panel         : EQConfig / EQPolicy 選択と validation 表示
template_generator   : ジャンル別 template 生成 dialog
calibration_tab      : debug-only layout calibration (UI_LAYOUT_CALIBRATION_POLICY.md)
```

## 2. Projection-first UI 要件

| 要件 | 内容 | 検証 |
|---|---|---|
| state injection | surface は `set_state(model)` 等で描画入力を注入できる。EditorInterface / EditorSelection 依存は thin adapter に隔離する。 | scenario builder が editor selection なしで全表示状態を構築できる |
| metric metadata | 重要 Control は `ui_metric_id` / `ui_metric_role` / `ui_metric_surface` / `ui_metric_required` meta を持つ。 | snapshot collector / static audit |
| no UI-side recomputation | 表示順序・件数・状態 badge など headless state から導出できる値を UI 側で再計算しない。 | projection integrity test (L4) |
| explicit empty state | 未選択・未設定・invalid は明示 state として描画する。silent fallback 禁止。 | state matrix test (L2)、UX_PATH_REDUCTION_POLICY.md |

## 3. Test layers

| layer | 検出対象 | 仕組み | 詳細 policy |
|---|---|---|---|
| L0 Static audit | source 上の危険 pattern (no-op button, generic picker, debug 文字列) | `tools/ui_static_audit.py` | UI_LAYOUT_METRIC_TEST_POLICY.md |
| L1 Layout metric | truncation, scroll 不能, dead area, row geometry | Godot headless layout oracle + snapshot JSON + evaluator | UI_LAYOUT_METRIC_TEST_POLICY.md |
| L2 State matrix | 状態と表示の矛盾 | scenario builder + `docs/ui/EDITOR_STATE_MATRIX.md` | UI_LAYOUT_METRIC_TEST_POLICY.md |
| L3 Interaction contract | no-op button, 効果契約・tooltip 欠落 | action metadata + signal 検査 | UI_LAYOUT_METRIC_TEST_POLICY.md |
| L4 Projection / explanation contract | UI 表示順と headless 順序の不一致、説明データ欠落 | explanation-as-data、trace 比較 | DETERMINISM_TRACE_TEST_POLICY.md |
| L5 Layout calibration | 人間の layout 感性 feedback | tweak-and-bake + ledger | UI_LAYOUT_CALIBRATION_POLICY.md |
| L6 UX path reduction | hack 経路、入力クラス過剰一般化 | 設計 gate + rejection test | UX_PATH_REDUCTION_POLICY.md |
| Analog | 美しさ、操作感、editor 全体連携 | 人間 | ANALOG_TEST_POLICY.md |

L0-L4 と L6 は `./tools/test.sh` に統合する自動 gate。L5 と Analog は人間 loop であり、CI gate にしない。

## 4. Source of truth

UI test の基準値は policy 本体ではなく、以下の契約文書が持つ (queue task EQM-086 / EQM-094 で作成):

```text
docs/ui/EDITOR_UI_CONTRACT.md        # surface ごとの目的、必須 component、禁止 visible text、threshold
docs/ui/EDITOR_STATE_MATRIX.md       # scenario state ごとの期待表示と禁止表示
docs/ui/LAYOUT_CALIBRATION_LEDGER.md # calibration 履歴、cold-control 記録
```

policy 本体には数式・手順・severity 規則のみを置き、project 固有の数値は契約文書に置く。これにより policy は他 project へ移植可能になる。

## 5. Severity model

UI_LAYOUT_METRIC_TEST_POLICY.md の severity を全 layer 共通で使う。

```text
P0_FAIL: task を accept できない。
P1_FAIL: 無関係 task なら accept 可。ただし repair-now として次の UI task で修正する。
WARN:    accept 可。report に follow-up を残す。
INFO:    診断のみ。
```

## 6. Adoption stages

| stage | 内容 | queue task |
|---|---|---|
| M0 | EDITOR_UI_CONTRACT / EDITOR_STATE_MATRIX 作成 | EQM-086 |
| M1-M3 | static audit + snapshot collector + WARN-only metric report | EQM-087 |
| M4 | P0 gate 有効化 | EQM-093 |
| M5 | calibration 実績による threshold 校正 + P1 gate | EQM-094, EQM-095 |

UI surface を新規追加する task は、最低 M0 相当 (contract 追記) と M1 相当 (metadata 付与 + snapshot 収集対象化) を同 task 内で行う。

## 7. Task type requirements

| task 種別 | 必須 gate |
|---|---|
| docs-only UI 契約 task | contract / state matrix 更新のみ。Godot 実行不要。 |
| UI layout task | L0、L1 (P0=0)、該当 L2 state、metric report path の self-review 記載。 |
| resource 選択 UI task | L0-L3 + picker specificity + sample separation。 |
| interaction task | L3 全件 + 該当 L2。 |
| timeline / explanation task | L4 projection integrity + explanation-as-data。 |
| package task | UI gate 不要。dist freshness は別 task。 |

## 8. 移植性

EQM 固有の数値・state 一覧は `docs/ui/` の契約文書側に置く。この policy と下位 policy 群は数式・手順のみを持つため、他 project へは「契約文書を書き直すだけ」で移植できる。
