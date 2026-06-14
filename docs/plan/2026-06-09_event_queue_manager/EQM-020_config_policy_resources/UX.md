# EQM-020 UX

利用者 = addon consumer / 後続 task。L1 surface (policy 選択) の入口を狭める (UX_PATH_REDUCTION)。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. config.policy = EQPolicy concrete subclass のみ | high | low | low | adopt | single-accepted-class。途中で死ぬ経路を作らない。 |
| B. policy 未設定は明示 `POLICY_MISSING` | high | low | low | adopt | no-fallback-chain。silent default を作らない。 |
| C. base EQPolicy instance 直接使用は error | high | low | low | adopt | base は拡張点。直接使用は完走非保証 → `POLICY_BASE_INSTANCE`。 |
| D. tie_break は既知の total 集合のみ | high | low | low | adopt | unset=ambiguous / 未知=unknown を明示 error。 |
| E. policy slot に Resource 全般を受ける | low | high | low | reject | 入口が広く完走非保証。speculative generality。 |
| F. 未設定で bundled sample policy へ fallback | low | high | med | reject | hack path。理解可能性を壊す。 |

## User goal

EQConfig を作り policy と tie_break を選ぶと、不足 (policy 欠落) や曖昧 (tie_break 未選択) が **明示 validation 結果** (安定 code) として返り、silent に「とりあえず動く」状態にならない。`.tres` で保存・読込できる。

## Operation steps

1. `var cfg := EQConfig.new()`。
2. `cfg.policy = <EQPolicy concrete subclass instance>` (Phase3 の Fixed/CTB 等; base instance は不可)。
3. `cfg.tie_break = &"sequence"` (既定; 既知 total 集合から選ぶ)。
4. `var v := cfg.validate()` → `EQValidation`。`v.is_valid()` / `v.errors()` / `v.codes()`。
5. 保存/読込: `ResourceSaver.save(cfg, path)` / `ResourceLoader.load(path)`。

## 採用 / 廃止

- 採用: single-accepted-class、明示 not-configured、既知 tie_break 集合、`.tres` roundtrip。
- 廃止 (hack 化しない): Resource 全般受け入れ、silent sample fallback、unset 黙認。

## Rejection tests (UX_PATH_REDUCTION §3)

- policy=null → `POLICY_MISSING`、is_valid=false。
- base EQPolicy instance → `POLICY_BASE_INSTANCE`、is_valid=false。
- tie_break=&"" → `TIE_BREAK_AMBIGUOUS`、is_valid=false。
- tie_break=&"bogus" → `TIE_BREAK_UNKNOWN`、is_valid=false。

## 既存 UX との干渉

新規 Resource。既存 runtime (scheduler/snapshot/trace) に影響なし。L0/L1 surface に L2/L3 を leak させない。
