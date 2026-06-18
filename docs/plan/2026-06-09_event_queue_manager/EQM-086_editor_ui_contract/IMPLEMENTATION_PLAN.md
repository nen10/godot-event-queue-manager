# EQM-086 IMPLEMENTATION_PLAN

## Scope

editor UI 契約 (M0) を docs として確立。実装・metric harness は EQM-087+。

## 変更対象ファイル

- `docs/ui/EDITOR_UI_CONTRACT.md` (new)。
- `docs/ui/EDITOR_STATE_MATRIX.md` (new)。

## 実装 steps

1. EDITOR_UI_CONTRACT.md: 各 surface の目的/必須 component(role)/禁止 visible text/scroll/primary action/empty/Copy Debug Report 境界/dead-area 例外宣言/初期 threshold (§9)。
2. EDITOR_STATE_MATRIX.md: §4.4 各 state の期待表示・禁止表示・modality (icon/badge)。
3. `./tools/test.sh` が緑のまま (docs change)。

## Test path / gate

- docs-only: 契約整合 (UI_LAYOUT_METRIC_TEST_POLICY の role/threshold/state を網羅)。Godot run 不要。
- `./tools/test.sh` 緑維持。

## Completion checklist

- [ ] 5 surface の契約 (目的/必須 role/禁止 text/scroll/primary/empty/threshold)。
- [ ] state matrix (≥ §4.4 states) を期待/禁止/modality で記述。
- [ ] 初期 threshold を契約に保持 (policy は数式のみ)。
- [ ] `./tools/test.sh` PASS。
