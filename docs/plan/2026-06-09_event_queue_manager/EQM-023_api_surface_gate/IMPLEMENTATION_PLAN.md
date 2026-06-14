# EQM-023 IMPLEMENTATION_PLAN

## Scope

layer-aware public API surface snapshot gate を実装する。tool + golden + 文書 + test.sh 結線。L2/L3 class は Phase 5 で追加され gate が実効化する。

## 変更対象ファイル

- `tools/check_api_surface.py` — 抽出 + golden 比較 + leak 検出 + 未 tag 検出 + `--update` / `--self-test`。
- `tests/golden/api_surface.json` — surface golden (repo-root; python 消費)。
- `docs/design/API_SURFACE.md` — naming 規約 + layer 割当 + 更新手順 + leak 規則。
- `tools/test.sh` — python-checks 区画で check_api_surface.py を実行 (`--self-test` + check; `--update-golden api_surface` → `--update`)。

## 実装 steps

1. `check_api_surface.py`: `*.gd` から class_name + public member 抽出 (annotations 対応: `@abstract func` / `@export var`)、layer map 適用、sorted JSON、golden compare、leak check、untagged check、`--update` / `--self-test`。
2. `API_SURFACE.md`。
3. `tools/test.sh` に結線。
4. golden 初回生成: `python3 tools/check_api_surface.py --update`。
5. 通常 `./tools/test.sh` で gate pass を確認。

## Test path / gate

- §4 gate (resource/API): layer-aware surface。`--self-test` が leak 検出器を証明。
- `./tools/test.sh` 期待: python check pass + Godot 191 checks 維持、exit 0。

## Dependency / Test Matrix

| dependency / area | risk | proof |
|---|---|---|
| 全 addon public class | 抽出漏れ (@abstract/@export) | golden に EQBackend abstract method, @export var が出る |
| roadmap §3.1 layer | 層分離未保証 | leak check + `--self-test` |
| DETERMINISM (golden 承認) | 自動更新 | 通常 run read-only、`--update` のみ |
| test.sh 結線 | gate が走らない | test.sh が python tool を実行し非 0 で FAIL |

## Completion checklist

- [ ] naming 規約 (public/internal) を API_SURFACE.md に文書化。
- [ ] surface が layer (L0-L3/core) tag 付きで deterministic export。
- [ ] L3→L0/L1 leak と未割当 class が FAIL (`--self-test` で検出器証明)。
- [ ] surface diff が doc note なしで FAIL (golden exact 比較)。
- [ ] golden 更新は `--update` flag のみ。
- [ ] test.sh が tool を実行。`./tools/test.sh` PASS。
