# EQM-139 UX — unchanged relation semantics, actor-local work

## User goal

game developerが大きなrelation graphを宣言しても、あるactorの関係照会、関係展開、離脱が
無関係なrelation数に比例せず、従来と同じ順序・trace・snapshotで動作する。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. public adjacency/cache API | low | high | high | reject | derived state管理をconsumerへ漏らす |
| B. private actor adjacency lookup | high | low | medium | adopt | caller変更なしでactor局所workにできる |
| C. relation id順を採番順へ変更 | low | high | medium | reject | 既存determinism契約を変える |
| D. elapsed ratioをportable SLA化 | low | high | low | reject | host noiseをcorrectness gateへ混ぜる |

## Experience steps

1. callerは従来どおりrelation typeをdeclareし、bind/invert/dissolveする。
2. `relations_of(actor)`は従来と同じrelation id順のdeep copyを返す。
3. `expand()`は従来と同じBFS順とbudget cutoffを返す。
4. actor離脱は開始時に接続していたrelationを同じ順で解消し、serial reboundも維持する。
5. performance laneだけがlegacy full scanとadjacency経路のelapsed/workを報告する。

Public API、resource schema、snapshot、trace recordは変更しない。
