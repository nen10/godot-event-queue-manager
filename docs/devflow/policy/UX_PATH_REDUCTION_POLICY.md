# UX Path Reduction Policy

対象: Event Queue Manager の API / Resource / Editor UI 全域
目的: 負の価値を持つ UX を作り出す経路 (hack path) を実装から取り除く。入力クラスの過剰一般化による「途中で適用不能になる experience steps」のパターン増加を防ぐ。

上位方針: `docs/devflow/policy/UI_TESTABILITY_POLICY.md` (layer L6)

---

## 0. 概念と既知の呼び名

- 使われない一般化の温存は code smell の **speculative generality** に相当する。
- 設計指針としては **make invalid states unrepresentable** / capability narrowing が近い。
- 本 policy はこれらを UX 観点で適用する: 「entry できるが完走できない経路」は UX 上の負債であり、削除対象である。

## 1. 判定規則

### 1.1 Mid-flow failure rule

ある入力 (node class / resource class / 選択) が機能の入口を通過できるのに、後続 step で適用不能になるなら、それは設計 bug である。対応は常に「入口を狭める」であり、「後続 step に分岐を足す」ではない。

### 1.2 Single accepted class rule

主要機能の slot は、受け入れる class をちょうど 1 つ持つ。

```text
Bad:  picker.base_type = "Resource"                          # なんでも入る
Bad:  if node is EQActorNode: ... elif node is Node2D: ...   # 複数受け入れ
Good: picker.base_type = "EQConfig"
Good: register_actor(actor_id, adapter: EQActorAdapter)
```

### 1.3 No fallback chain rule

主要導線に fallback chain を置かない。

```text
Bad:  selected config -> autoload config -> bundled sample   (silent)
Good: selected config、または明示の "not configured" state
```

「とりあえず動く」silent fallback は、理解可能性を破壊する hack path として扱う。

### 1.4 Redundancy rule

ある経路の安全性が「別の場所で既に制御されているから」である場合、その経路の受け入れコードは冗長性の証明であり、削除する。

参考事例 (godot-hex-map-lab): `_collect_tile_map_layers_recursive` が `HexTileMapLayer` に加えて汎用 `TileMapLayer` も収集していた。生成結果の貼り付け先として汎用 class が残ることは、機能不整合な UX path を温存する。受け入れを 1 class に絞って排除した。

### 1.5 First-found rule

複数候補からの silent 先頭選択 (first-found / index 0) を禁止する。複数あり得るなら明示 picker、単数のはずなら検証 error。

## 2. EQM 具体例

| slot / 経路 | 受け入れ | 拒否 |
|---|---|---|
| timeline_dock の config slot | EQConfig | Resource 全般、EQPolicy 直接 |
| EQConfig の policy slot | EQPolicy の concrete subclass | base EQPolicy instance (validation error) |
| actor 登録 | `register_actor(actor_id, adapter)` | scene tree scan による duck-typed node 収集 |
| finish_action | EQActionResult | 生 Dictionary fallback |
| demo scene | public API のみ | runtime internal への直接アクセス |
| EQManager 解決 | 明示参照 / 明示 picker | "first EQManager found in tree" |

## 3. 削除の手順

1. hack path を発見したら分類する: `remove-now` / `backlog (removal condition 付き)`。
2. `remove-now` は同 task で削除し、**rejection test** を追加する:
   - 無効 class 入力 -> 安定 error code を持つ validation error。
   - UI では明示 unset / error state。silent 受け入れが復活したら test が落ちる。
3. 旧経路を保護している test は更新または削除する (PROJECT_PROFILE の test 原則)。
4. task packet の UX.md candidate matrix に「拒否した一般化」を記録する。

削除した path は「その経路を通す test」ではなく「その経路が拒否される test」で守る。

## 4. 例外: 意図された拡張点

一般化が本当に必要な場合 (例: ユーザー拡張点としての EQPolicy 抽象)、以下を満たすこと:

- 拡張点として EDITOR_UI_CONTRACT.md / manual に記載される。
- すべての実装が同一の contract test を通る (contract が「完走可能性」を保証する)。
- 「入口は広いが途中で死ぬ」具体 path が存在しない。

拡張点 = 受け入れ class の集合が open であること。hack path = 集合が open なのに完走保証が closed であること。両者を混同しない。

## 5. Acceptance への組み込み

- 新機能 task の acceptance には、受け入れ class の rejection test を含める。
- self-review は「追加した入口」「狭めた入口」「残存 fallback」を列挙する。
- 残存 fallback には removal condition と backlog task id を付ける。
