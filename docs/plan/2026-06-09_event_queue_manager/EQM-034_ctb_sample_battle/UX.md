# EQM-034 UX

利用者 = 新規 addon 開発者 (quickstart で初めて触る)。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. quickstart は project-created config | high | low | low | adopt | bundled sample に依存しない (UX_PATH_REDUCTION §1.3)。 |
| B. demo は public API のみ | high | low | low | adopt | runtime internal に触れない (UX_PATH_REDUCTION §2)。 |
| C. demo の「動いた」= golden trace | high | low | low | adopt | 目視でなく trace 一致 (DETERMINISM §5)。 |
| D. sample preset を production 既定化 | low | high | low | reject | learning path 専用。production は project asset。 |

## User goal

quickstart に従い、自分で EQConfig (policy=EQCTBPolicy) を作り、EQManager に actor を register し、turn_ready を受け、finish_action で進める CTB battle を最小手数で動かせる。sample は学習用と明示され、production の既定にはならない。

## Operation steps (quickstart)

1. EQConfig を作成 (code か .tres)、policy に EQCTBPolicy を設定。
2. scene に EQManager を追加し configure(config)。
3. register_actor + data["speed"] 設定、seed()。
4. turn_ready を connect、finish_action(actor, EQActionResult) で進行。
5. (任意) EQPrediction.predict_turns で次順表示。

## 既存 UX との干渉

新規 demo + docs。public API のみ。test_project に demos symlink。demo golden trace 追加。
