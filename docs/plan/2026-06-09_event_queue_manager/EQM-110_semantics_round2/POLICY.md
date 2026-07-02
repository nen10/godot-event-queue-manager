# EQM-110 POLICY — semantics round 2

## 採用判断

- Q27–Q43 のユーザー注釈 (2026-07-02) を決定として確定する。16 項目は推奨案の承認、Q31 のみ相談つき条件承認 (下記 reconciliation で解決)。
- **Q31 reconciliation (effect callback の任意/必須)**: ユーザー懸念は「callback がないと開発者が effect を管理しにくくならないか」。解決は **宣言 linkage 方式**:
  - `EQActionDefinition.effect_name: StringName` (optional) を導入。設定された reservation の解決は、runtime の **named effect registry** (`register_effect(name, callable)`, Q30/Q35 と同一機構) の handler を呼び、返る `EQEffectRecord[]` を chunk へ積む。
  - `effect_name` が設定済みで handler 未登録なら **安定 error** (silent skip 禁止)。`effect_name` 空は「明示的に effect なし」であり合法 (WAIT/READY 等)。
  - L0/L1 の `finish_action` 流儀は「effect なし解決」として不変 — simple path に callback を強制しない。
  - 管理しやすさは「必須化」ではなく「宣言したら必ず結線される」ことで担保する。docs/template/dogfood は named-effect path を natural path として提示する。
  - よって contract 上は任意項目、L2 の推奨経路は named effect。ユーザーの「そうでなければ任意項目で構わない」を満たす。
- coverage gate は本 task で checker まで実装する (matrix 宣言のみは不採用、SUB_TASKS G 参照)。
- Q35 のユーザー補足「effect の grouping 設計の余地」は **declared follow-up** として registry/synthesis に記録する (EQEffectRecord への group tag は golden へ波及するため、需要確定時に additive 追加)。v1.x 前半では実装しない。

## 不採用判断

- solve-wins の optional 化 (Q28) — 一律 invalidation-wins (user 確定)。
- latched 評価様式 (Q29)、callable update rule / rate 帯域 (Q33)、repeating threshold primitive (Q34)、composite 自動束ね (Q38) — いずれも user 確定どおり不採用。
- reaction 専用順序規則 (Q32) — 不採用 (priority + sequence で足りる)。

## 破壊的変更の理由

なし (docs + tools 追加のみ)。SEM v1.1 は additive。将来 EQM-113 で `fire_cascade` の in-place 解決を廃止するが、それは当該 task の POLICY で扱う。

## Resource / API / UI の境界

- 本 task は契約文書と検査 tool のみ。API 実体は EQM-111+ が SEM v1.1 を典拠に実装する。
- coverage matrix は docs/design/ に置く (設計文書の隣、SEM §16 から参照)。checker は tools/、gate は `./tools/test.sh`。

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| SEM §16 の旧「Phase 4/5+ deferred」記述 | v1.1 で supersede 記録に置換 (削除しない) | 履歴と re-freeze 根拠の保存 | なし (記録) | contract 検査は coverage matrix 側 |
| coverage matrix の `reserved` 行 | 許容 (owning task 未完了の間) | 段階実装の正直な表現 | owning task COMPLETE 時に `implemented` へ flip | checker: implemented 行の file/test 実在 + COMPLETE task の reserved 残留 FAIL |
| registry の user意見 原文 | 原文保持、決定は → 決定 block で追記 | 注釈の一次記録性 | なし | — |

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| SEM v1.1 | Q01–Q26 決定と矛盾しない (additive) | 旧決定の黙示的上書き | synthesis に決定対照表; self-review で差分列挙 |
| coverage matrix | 全凍結契約 row が {owning task, file, test, status} を持つ | 行漏れ = gate 無効 | checker が SEM §16 契約 ID との対応を検査 |
| queue Phase 11 | acceptance が契約 ID を引用する | 写像漏れ再発 | queue row 記載 + checker の task 列参照 |
| registry Q27–Q43 | 全 status が DECIDED(user)/SETTLED | 未決の混入 | finalization 表 |

## 未確定だが task 内で決めてよい事項

- coverage matrix の row 粒度 (契約 group 単位 / field 単位) → group 単位 + 主要 field を明記する折衷で確定。
- checker の検査深度 → file/test path 実在 + status/task 整合まで (意味検査はしない)。
