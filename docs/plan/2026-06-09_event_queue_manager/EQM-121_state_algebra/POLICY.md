# EQM-121 POLICY — 状態代数 backend

## 採用判断

- SEM v1.2 §5.7/§4.8 の凍結契約をそのまま実装する。設計判断は EQM-120 で完了済み (depth=integrated、decision なし)。
- CANCEL の記録形 = 符号付き counter line 1 本 (pair = 1 軸)。線 id は決定的採番。
- modifier 合成 = ADD + OVERRIDE のみ。実効 = 有効 OVERRIDE があれば付与順最新の値、なければ base + Σadd。
- wrapper は合成構造 + 順序 + trace + serialize のみ core が凍結。wrapper の意味論適用は §6.4 (EQM-123) 以降。

## 不採用判断

- 乗算 modifier / visited-set 停止 / 1 パス変換 — EQM-120 で不採用確定 (synthesis 逸脱 5 点)。本 task で再導入しない。
- 状態 type registry の EQM 側所有 — 状態型は acceptance 宣言 data。EQM は代数構造のみ。

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| 旧 re_rate API | base_rate 書き換えとして保持 (breaking change なし) | 既存 test/golden 不変 | なし | 既存 test green 維持 |
| 未知 line への modifier 操作 | fault 記録 (silent no-op 禁止) | EQEventLines の既存 fault 規約 | なし | 新 test |

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| 既存 golden 群 | modifier 追加で既存 trace が変わらない (additive) | poll 経路の regression | 既存 golden green |
| effective_rate | 変更のたび決定的再計算、int のみ | float 混入 | test + §12 |
| CANCEL 軸 | grant/相殺が算術で閉じる。符号 = 有効状態 | 二重帳簿 | roundtrip + trace test |

## 未確定だが task 内で決めてよい事項

- modifier_id / 軸 line id の採番書式 (eqm.counter と同型の連番)。
- wrapper 宣言 dict の field 名 (name/params)。
