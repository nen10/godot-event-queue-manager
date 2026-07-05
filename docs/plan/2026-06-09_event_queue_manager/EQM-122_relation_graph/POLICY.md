# EQM-122 POLICY — 関係グラフ backend

## 採用判断

- SEM v1.2 §13.1 凍結契約どおり (depth=integrated、decision なし)。
- 結び直し語彙 = NONE | SERIAL_SUTURE のみ (EQM-120 確定、追加パターンは需要待ち)。
- 維持条件の空間述語は NAMED_PREDICATE (ゲーム側供給、Q12 延長)。EQM は評価タイミング (宣言 sweep) のみ固定。
- actor 離脱は invalidate_actor から解消時規則経由で自動解消 (特別扱いの silent 削除禁止)。

## 不採用判断

- named handler 制の解消規則 / ループの graph アルゴリズム的検出 (構造制約は TREE validation のみ) — EQM-120 で不採用・scope 外確定。

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| TREE violation | dev = fail-fast / shipped = skip+log (bind 拒否) | RUNTIME_RESILIENCE 二相 | なし | 両 mode test |
| 未宣言 type の bind | fault (silent 生成禁止) | UX_PATH_REDUCTION | なし | test |

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| relation id | 決定的採番・reuse なし | replay 不一致 | roundtrip + trace test |
| 直列縫合 | 縫合後も型の構造制約を満たす | TREE 破り | test |
| invalidate_actor | incident 関係が必ず trace に出る | silent 削除 | test |

## 未確定だが task 内で決めてよい事項

- 関係 id 採番書式 (eqm.rel.<seq>)、宣言 dict の field 名。
