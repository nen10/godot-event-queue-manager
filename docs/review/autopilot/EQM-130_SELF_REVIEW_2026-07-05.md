# EQM-130 Self Review — 維持条件 sweep 自動駆動 + 公平合成 + 迎撃標準形 [repair: A2/C1/C2]

date: 2026-07-05 / pattern: P2 (codex 委譲 1 run)

## Acceptance check

- [x] **A2 消化**: 相談4「EQM は評価タイミングのみ固定」— 既定 sweep (primary_threshold) を step_tick が自動評価、カスタム sweep 名は §4.7 sweep rule と名前で連動 (同 tick 重複抑止)。predicates は runtime named registry から自動供給。relations 未接続 = 完全 no-op (既存挙動不変、既存 golden 全 green)。維持条件が「ゲームが呼ばないと評価されない」状態は解消。
- [x] **C1 消化**: 公平合成 golden `fairness_relation_chain` — 公平関係 bind → 展開 rule → X への裁定効果が Y へ展開 (`targets_expanded`) → Y 側のみ armed の反射が解決後 sweep で発火。「関係により増えた対象 + 事後の個別誘発」の筋が 1 trace で読める。
- [x] **C2 消化**: 迎撃標準形 — interceptor の effect handler 内から `intervene_close` を呼ぶ利用形を test で例示 (`window_closed cause: intervention` が interceptor の resolved 後に出る order 検証つき)。
- [x] gate PASS ×2 (files=70 checks=1342)。新規 public API なし (api-surface 不変)。

## 委任と検証

- 検収指摘なし。dedup (既定 sweep と同名 rule の二重評価防止) まで contract どおり。

## 申し送り

- カスタム sweep の評価点は「step_tick 内の rule 実行後」に統一 (rule 実行の瞬間ではない)。tick 内での相対順序が問題になる実需要が出たら §4.7 との統合を再訪。
