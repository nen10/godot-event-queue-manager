# EQM-129 Self Review — wrapper 意味論の標準 2 種 [repair: 意図監査 A1]

date: 2026-07-05 / pattern: P2 (codex 委譲 1 run + orchestrator 検収)

## Acceptance check (相談3-#9 決定 + user 承認の標準 2 種)

- [x] **inv_chain (反転連鎖)**: 包まれた状態への grant が宣言 pair の dual へ反転。wrap 順に適用、二重で恒等 (対合 inv(inv(s))=s が実挙動で成立)。pair 未宣言 = fault + 素通し。
- [x] **relation_chain (透徹連鎖)**: grant 完了後、関係沿いに同状態を連鎖付与。停止 = §6.4 2a と同一の hop_cost/budget。**単層 (連鎖先で再適用なし)**、連鎖先の inv_chain は局所適用。relations 未接続 = fault。
- [x] 未知/無 kind = 不活性 data (既存互換)。kind は serialize roundtrip。
- [x] `state_wrapper_applied` trace (relation_chain は chained 配列つき)。SEM §5.7/§11 改訂 (同 commit)。
- [x] **BFS 共通化**: EQRelationGraph.expand へ移設、pipeline 2a は委譲 — expansion_transform golden green が同値性の機械的証明。
- [x] golden wrapper_chains + gate PASS ×2 (files=69 checks=1319; coverage 31/31 維持)。

## 委任と検証

- 検収修正 1 件: 不活性 wrapper (未知 kind) と抑止された relation_chain (連鎖先) にも `state_wrapper_applied` を記録していた — 「適用していないのに適用記録」は説明可能性を壊すため無 trace 化 + regression assert 追加。
- 契約に「相談決定の原文意図」を貼り込む新手順を初適用 — 意味論の取り違えなし。

## 申し送り

- clear/効果側の wrapper 修飾は標準 2 種の scope 外 (grant 側のみ)。EBS スキル執筆で需要が出たら additive。
- EBS acceptance 注釈 B-1 (連鎖系 inv ペアの「メタレベル相殺」) は EBS 側規則 — wrapper params に メタ値を積んで EBS が解決する形で表現可能 (EQM 側の強制なし、META_LEVEL_ASSIGNMENT.md どおり)。
