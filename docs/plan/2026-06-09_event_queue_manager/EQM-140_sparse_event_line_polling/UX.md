# EQM-140 UX — same progression order, watched-only work

## User goal

game developerが多数のevent lineを持つruntimeで少数のconditionだけを待っていても、毎tickの
pollが無関係line数やmodifier深さに比例せず、従来と同じ値・trace順・snapshotで動作する。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. public cache/watched tuning API | low | high | high | reject | internal derived stateをconsumerへ漏らす |
| B. private watched selector + rate cache | high | low | medium | adopt | caller変更なしでhot workを削減できる |
| C. unknown watched lineをfault化 | low | high | low | reject | 既存silent poll + later condition fault順を変える |
| D. watched Dictionary valueでenable/disable | low | high | low | reject | 既存set-shaped membership semanticsを変える |
| E. elapsed ratioをportable SLA化 | low | high | low | reject | host noiseをcorrectness gateへ混ぜる |

## Experience steps

1. callerは従来どおりlineをissueし、base rateとmodifierを更新する。
2. runtimeは従来と同じpending/scheduled conditionからwatched setを導出する。
3. pollはlive watched lineだけをString content順に進め、unknown/zero-effective lineを記録しない。
4. re-rateやmodifier変更後の次pollは最新effective rateを使う。
5. save/load後も同じeffective rate・poll順・trace continuationになる。
6. performance laneだけがlegacy full-line selection / modifier scanとのelapsed/workを報告する。

Public API、resource schema、snapshot、trace recordは変更しない。
