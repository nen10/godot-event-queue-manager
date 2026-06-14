# EQM-014 SUB_TASKS (PLAN DRAFT — awaiting user review)

> Status: **planning draft for review**. depth=`decision` (autonomous-loop checkpoint, QUEUE_EXECUTION_PATTERNS §8.3). No spec docs written, no registry/queue edits, no commit until this split is approved.

## Complexity

Class: **C5**
Reason:
- roadmap/phase 級。Phase 2 API freeze 前段の中心契約 (event-line / solve・invalidation / composite comparator / reentrancy / save boundary / trace-kind / coverage matrix) を確定する。
- 1 つの completion commit で説明できない複数の完了境界 (semantics spec / ordering coverage matrix / open-questions registry 確定 + concepts 整合) を含む。
- 後続 Phase 2/5 (EQM-020 resource, EQM-050 reservation schema) が後方互換破壊なしに乗るための契約予約を伴う。

Required artifacts (C5): Complexity header / Task Resolution candidate matrix / Scheduled Task Audit / UX Candidate Matrix / POLICY (Fallback・State/Invariant) / IMPLEMENTATION_PLAN (dependency/test matrix)。**本 draft では split 提案 + adopted/rejected マッピング + coverage matrix 骨子までを提示し、各 sub-task の UX/POLICY/IMPLEMENTATION_PLAN は split 承認後に sub-task ごとに作成する。**

## 入力 (確定済み)

- `docs/design/EVENT_MODEL_CONCEPTS.md` — 三面モデル (event-line=進行入力 / event=解決出力 / event_line_progressed=trace 観測)。confirmed 2026-06-14。
- `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md` — Q01–Q26 registry。大半 `DECIDED(user)`。
- `docs/review/EVENT_MODEL_OPEN_QUESTIONS_SYNTHESIS_2026-06-14.md` — 決定根拠。
- EQM-010/011/012/013 で確立した core: EQEntry/EQOrdering、scheduler、snapshot schema、trace-kind open schema。

## Task Resolution candidate matrix

| 候補 | 目標 | 採否 | 概要 |
|---|---|---|---|
| 単一 task で全 deliverable | semantics + coverage + registry を 1 commit | reject | C5 規約: 1 completion commit で説明不能。proof が曖昧になる。 |
| **3 sub-task へ分割 (推奨)** | 完了境界を分ける | **adopt** | 014.01 semantics spec / 014.02 coverage matrix / 014.03 registry+concepts 確定。下記。 |
| event-line を別 task (EQM-015) へ分離 (Cluster A=A3) | — | reject | ユーザー決定は **A1** (EQM-014 スコープ内で契約予約)。分離しない。 |
| 契約 + backend 実装を同 task | — | reject | 契約・schema・trace-kind は本 task、backend 実装は Phase4/5 (後方互換破壊なしを保証)。 |
| Q17 予測深さ N を本 task で確定 | — | reject | core 決定ではなく perf 予算 (EQM-102)・prediction (EQM-033) の入力。defer。 |

## 提案: EQM-014 の C5 split (3 sub-task)

完了境界ごとに分割。すべて docs-only acceptance (Godot run 不要、§4 gate=契約整合)。依存は線形 (01→02→03)。Phase 2 API freeze は 3 つすべての完了を条件とする。

| sub-task | deliverable | target files | depth | acceptance / gate |
|---|---|---|---|---|
| **EQM-014.01** event model semantics spec | 三面モデル + event-line 契約 + solve(AND)/invalidation(OR) + composite comparator hook + reentrancy spec + save boundary + trace-kind schema + driver/await 契約予約 | `docs/design/EVENT_MODEL_SEMANTICS.md` (new) | decision | 7 契約群 (下記 §契約予約) を矛盾なく記述。Phase1/2 で予約・Phase4/5 で破壊しないと明記。CONCEPTS と整合。 |
| **EQM-014.02** ordering coverage matrix | ≥8 system を model へ写像、unmappable は queue 候補化 | `docs/design/ORDERING_MODEL_COVERAGE.md` (new) | decision | 下記 §coverage 骨子の全行が「写像可 / queue 候補」で埋まる。4X 行 (Q13) と 行動解決ターン制行が写像可と示される。 |
| **EQM-014.03** registry + concepts 確定 | Q01–Q26 の adopted/rejected を registry へ確定反映、CONCEPTS の Q26 pointer を整合、deferred/support を記録 | `docs/design/EVENT_MODEL_OPEN_QUESTIONS.md`, `docs/design/EVENT_MODEL_CONCEPTS.md` | decision | 下記 §adopted/rejected 全項目が registry に確定 status で存在。Q17/Q24/Q25 が defer/support として 1 行記録。 |

代替命名案: EQM-014.01/.02/.03 ではなく新規 EQM-015/016/017 として queue 追加する案もある (queue 番号の連続性 vs 親子関係の可読性)。**要レビュー判断** (下記 §レビュー判断 1)。

## 契約予約 (EQM-014.01 が記述する 7 群 — queue acceptance 由来)

1. **event-line** = acceptance 定義の incremental 整数進行。global tick = primary。event 側発行可。per-entity event-line は acceptance 定義で built-in 必須 field にしない。invariant: event-line=進行入力 / master timeline=解決出力 (単一 int comparator: tick/priority/sequence)、due_tick 直接書換禁止 (reschedule のみ)。
2. **solve_conditions (AND default) / invalidation_conditions (OR default)**。AND 失効=decremental counter event-line。OR 解決=race pattern + race-group id + 3 表示分離 (EQM debug / game-dev debug / presentation)。
3. **composite resolution comparator hook**。serializable state 由来の deterministic key (float 可・ここのみ、core ordering key には不関与。live-object 禁止。golden 必須)。最終 fallback = default event-line 上の発行順。並列発行禁止。
4. **sweep point** = 各 event 解決後の collection window。eager = trigger 型 invalidation 条件。
5. **reentrancy spec** = window nest (meta-cost budget, Q02) + trigger nest (bounded round + cycle guard, EQM-062) を統一記述。交差ケース v1 想定、暫定 cost 設計可。
6. **save boundary** = effect 処理チャンク空。チャンク追加は解決時 (発行時でない)。window open で空化。許容 sync barrier に一致。
7. **trace record kinds** = `event_line_progressed` / `window_opened` / `window_closed` / 失効 `closed_by`。(EQM-013 で trace-kind schema は open 化済み → harness 改修不要)。

加えて driver/await 契約 (EQM-032 が参照) と Q03 deadline window (optional property) を semantics に含める。

## adopted/rejected マッピング (EQM-014.03 が registry へ確定 — 全 Q)

| Q | 決定 (2026-06-14) | EQM-014 での扱い | owner sub-task |
|---|---|---|---|
| Q01 save 境界 | save nest 上限 = base-operator window nest level | semantics §save | 014.01 + 014.03 |
| Q02 window nesting | meta level/cost 制約、window 層に cycle guard なし | reentrancy spec | 014.01 |
| Q03 window deadline (ATB) | adopt: optional window property、frozen=deadline∞ | semantics §window | 014.01 |
| Q04 同時性/batch | core 全順序、同時性=composite event、member 順=Q20 | semantics §composite | 014.01 |
| Q05 無効化 timing | lazy predicate + `invalid_event_skipped`、eager 二分 (Q19) | semantics §invalidation | 014.01 + 014.03 |
| Q06 duration expiry | event 化、reaction-count close/deadline∞=Q18 多条件失効 | semantics §invalidation | 014.01 |
| Q07 遡及時間変更 | due_tick 直接書換禁止 (reschedule のみ)、WT/CT=event-line | semantics §event-line | 014.01 |
| Q08 priority 不変 | immutable、reschedule のみ | semantics §ordering | 014.01 |
| Q09 effect 順序/trigger 収集 | atomic、default order+adapter、post-resolution window、上位=Q20/nest=Q21 | semantics §composite/§reentrancy | 014.01 |
| Q10 actor lifecycle | actor_id 再利用禁止、pending=Q05、round membership=policy | semantics §lifecycle | 014.01 |
| Q11 数値域 | 全 int (tick int64)、float は core ordering 不関与、over-cap/effect 順=Q20 | semantics §numeric | 014.01 |
| Q12 感知分類 | simulation 側 deterministic data、trace 含む | semantics §presentation 予約 | 014.01 |
| Q13 timeline 単一性 | 1 manager=1 master timeline+N event-line、4X 並行戦域 v1 外、matrix 検証 | semantics + coverage 4X 行 | 014.01 + 014.02 |
| Q14 反芻経済 | AP 再徴収なし default、policy hook | semantics §reservation 予約 | 014.01 |
| Q15 replay 製品化 | v1 defer | registry deferred | 014.03 |
| Q16 event-line 導入 | A1 採用、global tick=primary、event 側発行可、per-entity 非必須 | semantics §event-line | 014.01 |
| Q17 前進方式/決定性 | per-tick polling 既定。予測深さ N は **defer** (EQM-033/102 入力) | semantics §event-line + registry defer note | 014.01 + 014.03 |
| Q18 多条件 solve/invalidation | solve=AND / invalidation=OR、race pattern | semantics §conditions | 014.01 |
| Q19 eager 責務分割 | sweep=解決後 window、eager=trigger 型 invalidation | semantics §sweep | 014.01 |
| Q20 同時解決/上位順序 | B1 comparator hook、fallback=発行順、並列発行禁止 | semantics §composite | 014.01 |
| Q21 reentrancy 統一 | window nest+trigger nest 統一 spec、交差 v1 想定 | semantics §reentrancy | 014.01 |
| Q22 event-line×snapshot/save | save 境界=effect チャンク空、解決時追加、window open で空化 | semantics §save | 014.01 |
| Q23 過剰一般化ガードレール | 合意 (meta) | semantics §guardrails | 014.01 |
| Q24 grouped/micro-event-line | **deferred** (RTS 補助線、v1 実装外) | registry deferred 1 行 | 014.03 |
| Q25 sync barrier | core named concept にしない、acceptance 支援は継続課題 (support) | registry OPEN(support) | 014.03 |
| Q26 identity/granularity/lifecycle/scaling | DECIDED: identity=数えたい意味単位、deterministic 採番、stacking=acceptance 定義 (独立/refresh/共有 pool 全表現)、homogeneous→pattern2 で O(1) scaling、watched/sparse polling | semantics §event-line identity | 014.01 + 014.03 |

## coverage matrix 骨子 (EQM-014.02 — ≥8 system)

| # | system | 写像方針 (検証対象) | 状態 |
|---|---|---|---|
| 1 | CTB (Charge Time Battle) | per-entity CT = homogeneous event-line (pattern2 tick sweep)、閾値→turn event | 写像予定 |
| 2 | Energy (roguelike) | per-entity energy event-line、threshold readiness、carry-over | 写像予定 |
| 3 | Wait Turn (TO / FFT-CT) | per-entity WT/CT event-line、即時 next-ready 解決、action cost で次 WT 改変 | 写像予定 |
| 4 | FE phase (player/enemy phase) | phase 進行 event-line / round 構造、policy 所有 membership | 写像予定 |
| 5 | 4X phase (並行戦域) | 複数 event-line + 共有 primary tick (Q13)、複数 master timeline は v1 外 | 写像予定 (Q13 検証点) |
| 6 | Stack / LIFO (MTG 風) | window nest + LIFO 解決、reentrancy spec (Q21) | 写像予定 |
| 7 | Pokémon-style speed turn | priority bracket + speed tie、composite comparator (Q20) | 写像予定 |
| 8 | ATB | deadline window (Q03)、real-time hybrid | 写像予定 |
| 9 | 行動解決ターン制 (核 test case) | AP 回復 event-line、ready reservation、予約準備=解決時間 | 写像予定 (最重要) |
| — | grouped/micro-event-line (Q24) | deferred 補助線 | deferred 記録 |
| — | sync-barrier 命名 (Q25) | core 化しない、support 記録 | support 記録 |

unmappable case が出たら **Phase 2 API freeze 前に** queue 候補として記録する (acceptance 要件)。

## Scheduled Task Audit

- EQM-014 を 3 sub-task (014.01/.02/.03 もしくは EQM-015/016/017) へ split し queue へ追加する (**承認後**)。依存: 014.01→014.02→014.03。
- EQM-020 (resource/API) の dependency を EQM-014 → 014.03 (= EQM-014 群の最終完了) へ更新する。
- coverage matrix で unmappable case が出た場合のみ、Phase 2 freeze 前の追加 task を最大 1 つ候補化する (QUEUE_OPERATION_RULES §1)。
- Q17 予測深さ N を EQM-033/EQM-102 の acceptance 入力として参照記録する (新 task ではない)。

## レビュー判断 (ユーザー確認したい点)

1. **split 採否と命名**: EQM-014 を 3 sub-task に分けるか (推奨)。番号は `EQM-014.01/.02/.03` か 新規 `EQM-015/016/017` か。
2. **Phase 2 freeze gate**: API freeze を 3 sub-task すべての完了に gate する方針でよいか。
3. **EQM-020 依存付け替え**: EQM-020 の dependency を EQM-014 群の最終完了へ移す方針でよいか。
4. (確認のみ) Q17 予測深さ N を本 task で確定せず EQM-033/102 入力として defer する点。

承認 (または調整) 後に、各 sub-task の UX/POLICY/IMPLEMENTATION_PLAN を作成し queue へ反映してから実装 (spec 執筆) に進む。

1 -> splitします。番号は任意です。toolで受け入れ済みの方式で構いません。しかし sub-task の番号規則は、分解が必要な task が計画時に判明した場合に行うものとして重複のリスクを避けて機械的に命名できるように設計しているものであるという意図について問題があるとお考えであれば Opus はあらかじめ pipeline 設計に関して指摘を行うべきでした。 Opus の要望により実行の session を新しくしたため記憶がないのかもしれませんが、実行段階になってからこのような判断を私に提案する前に、十分な相談をする時間を私たちは設けたはずです。過去のことはどうでも良いので Opus が望む限り、合理的な pipeline 設計について十分議論する時間が私たちにはあります。
2, 3 -> 実行順序を決めることも conductor であるあなたの仕事です。任意に行なってください。
4 -> 構いません。
