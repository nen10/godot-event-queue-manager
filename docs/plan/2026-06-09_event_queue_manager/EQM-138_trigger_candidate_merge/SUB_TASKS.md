# EQM-138 SUB_TASKS — stable trigger candidate merge

## Complexity

Class: C3

Reason:

- hot pathのalgorithm変更だが、condition mutation時のrebucket順序という隠れた不変条件を
  同時に固定する必要がある。
- canonical armed order、derived index、rumination/disarm/save continuationを横断する。
- correctness回帰と独立performance A/Bの両方を完了証拠にする。

Required artifacts:

- Task Resolution / Scheduled Task Audit
- UX Candidate Matrix
- State / Invariant Table
- Dependency / Test Matrix

## Task Resolution

| candidate | value | decision | reason |
|---|---|---|---|
| A. concat後の全候補sortを維持 | mutation後も順序が直る | reject | sweepごとにO(c log c)を払い、wildcard-heavyで退行する |
| B. bucketをconcatするだけ | sort除去が最小 | reject | target/wildcardのglobal arm orderを失う |
| C. bucketをsequence順に維持し二-way merge | O(c)候補構築 + exact order | adopt | normal armは末尾append、retargetだけordered insertで不変条件を維持できる |
| D. canonical armed tableを毎回scan | 実装単純 | reject | EQM-136のcandidate work削減を失う |
| E. persistent merged cache | query最速 | defer | condition mutation/disarm/expiryのinvalidation複雑度が需要に対して過大 |

## Scheduled Task Audit

新しいscheduled taskはない。relation adjacencyとsparse event-line pollingは既に
EQM-139/140、reaction FIRE condition semanticsはEQM-141としてqueue済み。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| target bucket | `seq` strictly ascending | retargetした古いslotが末尾へ入りorder破壊 | populated destinationへのretarget regression |
| wildcard bucket | `seq` strictly ascending | specific→wildcardで古いslotが後置 | populated wildcardへのretarget regression |
| candidates result | target + wildcardの全slotをglobal `seq`順で一度ずつ返す | duplicate/drop/tie drift | target-only/wildcard-only/mixed exact arrays |
| returned array | derived bucketのaliasを外へ返さない | caller mutationでindex破壊 | single-bucket result mutation regression |
| canonical state | armed table / sequence ownershipはengine | indexをtruth化 | existing lifecycle/save regression |
