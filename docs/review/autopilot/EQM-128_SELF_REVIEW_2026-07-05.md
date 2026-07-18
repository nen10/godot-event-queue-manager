# EQM-128 Self Review — Q54 確認系 acceptance 束 + manual v1.2

date: 2026-07-05 / task: EQM-128 (Phase 12 終端) / pattern: P2 (codex 委譲) + P0 (manual 直筆)

## Acceptance check (SEM v1.2 §16.2 / Q54)

**確認系の成果 = 「既存機能で書ける」証明。全 6 項目が runtime 変更ゼロ・宣言のみで成立:**

- [ ] R04 original claim was invalidated by the 2026-07-18 EQM-137 audit; see the correction below. The retained proof covers normalized event tags + `EQCondition` trigger matching only.
- [x] R06: 相互反撃が反撃回数の枯渇 (`closed_by: reaction_count`) で必ず停止 — golden `mutual_counter_stop` + 停止後 pending 0。cascade 上限 fault ではなく宣言資源で止まることを確認。
- [x] R08: `set_order_hook` の stack_index 降順適用例 (`order_hook_applied` で順序固定)。実体はゲーム側 (相談5) — EQM は順序規律のみ。
- [x] R09: bundle + 片側のみ armed 反射 = 視界非対称の公平 (bundle 後の個別誘発が片側のみ)。
- [x] R11: `ready_reservation_for` の政策外ターン付与 + invalidate→issue が trace 上原子的 (間に他 resolved なし)。
- [x] R12: 発行前修飾 (delay ×1.5 → 6) で足りる証明 — **EQM 変更不要を test + doc comment で記録** (依頼どおり)。
- [x] manual: ja 正文 + en の v1.2 章 (状態代数 / 関係・展開・変換 / メタレベル・介入・bundle・フェーズ / save v3)、dogfood README 参照。
- [x] gate PASS ×2 (files=68 checks=1304 failures=0; **coverage 31/31 — Phase 12 完了**)。

## 委任と検証

- 初回委任は codex が context 枯渇 (探索過多)。**対策が効いた**: API 署名一覧を contract に貼り込み、runtime file の読取りを全面禁止 → 2 file のみ・一発 green で納品。委任 contract の設計原則として記録: 「実装済み API を使わせる task では、読ませるのでなく署名を貼る」。
- manual は設計文脈 (相談ラウンド決定・逸脱 5 点) を持つ orchestrator が直筆 (P0)。ユーザーは英語設計文書を読まないため ja を正文の粒度にした。

## Phase 12 総括 (round-level)

- EQM-120..128 の 9 task、全て同日完了。P2 委譲 7 run 成功 / 2 run が context 枯渇で仕切り直し (いずれも code 破壊なし)。
- orchestrator 検収で捕捉した実バグ 4 件: StringName sort の replay 非決定性 (既存・重大)、active_state の型崩れ、maintenance typed-null、v2 test の偽陽性化。委任 contract 側の誤り 1 件 (golden env var) も検収で発見・是正。
- 「宣言なし = v1.1 挙動不変」を全 task で golden により機械的に担保。

## 2026-07-18 correction (EQM-137 audit)

R04の上記claimを撤回する。旧testはfalse `in_zone`でも`reaction_fired`を肯定し、
suppressionも非負件数だけを確認していたためproofになっていなかった。testはnormalized
intrusion tag + `EQCondition` matcherの厳密な非一致/一致/FIRE解決へ差し替えた。
reaction definition solve/invalidationをFIREへ適用する意味論はEQM-141へ分離する。
