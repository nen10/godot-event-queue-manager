# EQM-050 UX

利用者 = addon consumer (L2: reservation を使う深層パス)。L0/L1 は不変 (opt-in)。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. EQActionDefinition で reservation を宣言 | high | low | low | adopt | kind/delay/tags/duration/rumination を typed Resource で。 |
| B. kind ごとに validation 制約 | high | low | low | adopt | immediate=delay0 等、不正を明示 code。 |
| C. duration=-1 で ∞ (回数 close) | high | low | low | adopt | reaction prep を反応回数で close (Q06)。 |
| D. L2 は opt-in、L0/L1 不変 | high | low | low | adopt | 簡易パスを壊さない (§3.1)。 |
| E. kind を string で受ける | low | med | low | reject | enum で invalid state を表現不能に。 |

## User goal

reservation (immediate/prepared/reaction-prep/wait/ready/operation) を EQActionDefinition として宣言でき、不正な組合せ (immediate なのに delay>0 等) は安定 code で validation error になる。runtime では EQReservation として counters/status を持ち serializable。

## Operation steps

1. `var def := EQActionDefinition.new(); def.kind = EQActionDefinition.Kind.PREPARED; def.delay = 3; def.tags = [&"attack"]`。
2. `def.validate()` → EQValidation。
3. runtime: `var r := EQReservation.new(actor_id, def)`; `r.validate()`; `r.to_dict()`/`from_dict()`。

## 既存 UX との干渉

新規 L2 class。L0/L1 surface 不変。API surface に L2 列、ERROR_CONTRACT に reservation code 追加。
