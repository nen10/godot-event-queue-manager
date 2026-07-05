# EQM-129 IMPLEMENTATION_PLAN — wrapper 意味論の標準 2 種 [repair: 意図監査 A1]
## Scope
相談3-#9 決定「デコレータ = 包まれた状態の付与・解除・効果の意味論を修飾する状態合成」の実装。user 承認 (2026-07-05): 標準 2 種 (inv_chain / relation_chain) で確定。SEM §5.7 改訂済み (同 commit)。
## 変更対象
- `runtime/eq_state_algebra.gd` (grant 時の wrapper 適用 + relations 接続)
- `runtime/eq_relation_graph.gd` (`expand` 公開 helper — BFS の共通化)
- `runtime/eq_reservation_runtime.gd` (_bfs_expand_targets を expand へ委譲、挙動不変)
- `tests/core/test_eq_wrapper_semantics.gd` (new) + `tests/golden/wrapper_chains.trace.jsonl` (new)
## 要点
- inv_chain: grant を宣言 pair の dual へ反転 (wrap 順に適用、二重で恒等 = 対合)。pair 未宣言は fault + 素通し。
- relation_chain: grant 時に関係沿いへ同状態を連鎖付与 (§6.4 2a と同一の cost 停止)。連鎖先への relation_chain 再適用なし (単層)。連鎖先の inv_chain は局所適用。
- `state_wrapper_applied` trace (SEM §11 追記済み)。未知 kind = 不活性 (互換)。
- gate: 既存 golden 全 green (特に expansion_transform = BFS 委譲の同値性証明)。
