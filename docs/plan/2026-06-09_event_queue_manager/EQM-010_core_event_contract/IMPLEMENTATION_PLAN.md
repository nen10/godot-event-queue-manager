# EQM-010 IMPLEMENTATION_PLAN

## Scope

core event entry + 決定的 ordering 契約を定義し、後続 core task が乗る headless test framework を確立する。scheduler/snapshot/trace は含めない。

## 変更対象ファイル

- `addons/event_queue_manager/runtime/eq_entry.gd` — EQEntry (keys + identity + payload + make/to_dict/from_dict)。
- `addons/event_queue_manager/runtime/eq_ordering.gd` — less_than + sort。
- `test_project/tests/eq_test.gd` — assert helper (新)。
- `test_project/tests/run_all.gd` — 探索 runner へ書き換え。
- `test_project/tests/core/test_scaffold.gd` — EQM-002 smoke を test 化。
- `test_project/tests/core/test_eq_ordering.gd` — 順序契約 + permutation + 負 tick。
- `tools/test.sh` — import pass + masked-failure guard (framework 確立に必要)。

## 実装 steps

1. EQEntry / EQOrdering を作成。
2. test framework (eq_test + discovering run_all) を作成。
3. core tests を作成。
4. tools/test.sh に import pass + script-error guard を追加。
5. clean checkout (`.godot/` 削除) で `./tools/test.sh` PASS を確認。

## Test path

- `./tools/test.sh` → import pass → headless runner → `files=2 checks=9 failures=0 PASS` → exit 0。
- masked-failure guard により compile/script error は exit 0 でも FAIL。

## Completion checklist

- [x] due_tick ASC / priority DESC / sequence ASC を test で証明。
- [x] insertion permutation 不変を test で証明。
- [x] 負 tick 拒否 (make → null)。
- [x] clean checkout で import pass 込み PASS。
- [x] masked compile/script error を gate が拾う。
