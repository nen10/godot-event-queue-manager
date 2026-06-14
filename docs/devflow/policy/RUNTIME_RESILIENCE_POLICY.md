# Runtime Resilience Policy

対象: Event Queue Manager runtime (core scheduler, reservations, triggers, event-lines, presentation buffer)
目的: shipped game が EQM 内部の異常で crash しないことを保証しつつ、開発時には異常を即座に露見させる。fail-fast と fail-safe を mode で分離する。

上位: `docs/devflow/PROJECT_PROFILE.md`。error code 体系は `docs/design/ERROR_CONTRACT.md` (EQM-020)。

---

## 0. 二相モデル

| mode | 既定の用途 | 異常時の挙動 |
|---|---|---|
| `dev` (assertion) | 開発・test・editor | 即停止 (assert / push_error)。異常を隠さない。 |
| `shipped` (resilient) | 製品 build | 継続。該当 event を skip/invalidate し、構造化 log を残す。player の game を落とさない。 |

mode は明示設定で切替える。silent な自動判定に頼らない (UX_PATH_REDUCTION と同趣旨)。既定は `dev`。

## 1. 異常の分類と既定処理

`ERROR_CONTRACT.md` の recoverability class に対応づける。

| class | 例 | dev | shipped |
|---|---|---|---|
| `contract_violation` | dead actor への予約、未知 schema_version、不正 base_type | assert 停止 | event skip + `invalid_event_skipped` trace + log |
| `budget_exceeded` | reentrancy 深度超過 (Q02 backstop)、reaction chain 上限 (EQM-062) | assert 停止 | chain 打ち切り + stable error event + log |
| `resource_invalid` | 必須 policy 欠落、ambiguous tie-breaker | assert 停止 | empty/unset state へ縮退 + log |
| `external_state` | actor node 消滅、WeakRef 失効 | warn + skip | skip + log (Q05 invalidation 経路) |

## 2. 不変条件

- shipped mode でも **決定性は保たれる**。skip/invalidate は trace に現れ、同入力で再現する。resilience は非決定性の言い訳にしない。
- shipped mode は状態を破壊しない。異常 event は drop されるが scheduler の整合 (sequence, generation, snapshot) は保たれる。
- どの mode でも、異常は静かに飲み込まない。dev は停止、shipped は必ず log + trace record。
- mode 切替が挙動を変えるのは「異常時のみ」。正常 path の結果は mode 不変 (golden trace は mode 間で一致)。

## 3. Test 要件

- 各 recoverability class について、dev mode で停止し、shipped mode で「落ちずに skip + trace record」になることの test。
- shipped mode の異常注入後も snapshot roundtrip と後続 pop 順が整合することの test。
- 正常入力で dev/shipped の trace が byte 一致することの test (mode neutrality)。

## 4. Acceptance への組み込み

- runtime に触れる task は、新たな異常 path に recoverability class を割り当て、両 mode の挙動を test する。
- shipped mode で crash しうる未分類 path を残さない。残す場合は理由と除去条件を self-review に記す。
