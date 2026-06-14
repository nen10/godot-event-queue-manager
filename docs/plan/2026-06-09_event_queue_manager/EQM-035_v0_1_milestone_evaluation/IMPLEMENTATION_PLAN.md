# EQM-035 IMPLEMENTATION_PLAN

## Scope

v0.1 slice (EQM-010..034) の評価レポートを作る。code 変更なし。

## 変更対象ファイル

- `docs/review/V0_1_MILESTONE_EVALUATION_2026-06-15.md` (new)。

## 実装 steps

1. semantics drift 監査 (SEMANTICS §3-§16 vs 実装)。
2. API friction 列挙 → candidate / no-change。
3. north-star metric baseline。
4. roadmap 確認。
5. `./tools/test.sh` が緑のまま (docs change) を確認。

## Test path / gate

- docs-only。`./tools/test.sh` PASS 維持 (code 不変)。

## Completion checklist

- [ ] 評価レポートが存在。
- [ ] semantics drift 監査済み (drift / 予約の区別)。
- [ ] friction が candidate / no-change として明示記録。
- [ ] north-star metric を baseline。
- [ ] roadmap を更新 or 不変確認。
- [ ] `./tools/test.sh` PASS。
