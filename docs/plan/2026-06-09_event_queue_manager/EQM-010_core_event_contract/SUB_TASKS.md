# EQM-010 SUB_TASKS

## Complexity

Class: C3
Reason:
- 複数ファイル (EQEntry + EQOrdering) に加え、後続全 core task が乗る **test framework 規約**を確立する。
- headless での class_name 解決という横断的判断を含む。

Required artifacts: Complexity header / Task Resolution / UX (最小) / POLICY (API + 規約) / IMPLEMENTATION_PLAN。

## Task Resolution

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| EQEntry | 順序 key + identity + payload を持つ event entry | adopt | make() 検証 factory、to_dict/from_dict (snapshot 用)。 |
| EQOrdering | due_tick ASC / priority DESC / sequence ASC の全順序 | adopt | less_than + sort。sequence 一意で sort 安定性に非依存。 |
| test framework | headless 探索 runner + assert helper | adopt | eq_test.gd (path load) + run_all.gd が test_*.gd を sorted 探索し static run(t) を呼ぶ。 |
| core tests | 順序契約 + permutation 不変 + 負 tick 拒否 | adopt | test_eq_ordering.gd (9 checks)。 |
| scaffold smoke を test 化 | EQM-002 smoke を test_scaffold.gd へ | adopt | runner 一本化。 |

## Scheduled Task Audit

新規 scheduled task なし。次の依存解放は EQM-011 (scheduler operations)。
