# EQM-121 Self Review — 状態代数 backend

date: 2026-07-05
task: EQM-121 (queue Phase 12)
pattern: P2 (orchestrated delegation — codex GPT-5.5 exec 2 run、orchestrator が contract/gate/golden/queue を所有)

## Acceptance check (SEM v1.2 §5.7 / §4.8)

- [x] rate modifier-stack: `add_rate_modifier` / `remove_rate_modifier` / `effective_rate_of` (override は付与順最後勝ち、なければ base + Σadd、int のみ)。`poll_tick` は実効 rate 使用、実効 0 = 凍結 skip。trace cause `modifier_added`/`modifier_removed` + `modifier_id` + effective from/to。to_dict/restore roundtrip (modifier_seq 含む)。
- [x] EQStateAlgebra (new, L3): `declare_inv_pair` (CANCEL/EXCLUDE/COEXIST、再宣言置換)。CANCEL = 符号付き 1 軸 line (`eqm.axis.<actor>.<a>__<b>`)、相殺は算術。EXCLUDE = dual clear → grant (trace 順検証済み)。COEXIST/未宣言 = 独立 line。wrap/unwrap LIFO + `state_wrapped`/`state_unwrapped` trace + serialize (String key、決定的順)。
- [x] 寿命 3 種 acceptance golden `lifetime_composition.trace.jsonl`: `closed_by` = reaction_count (スタック系) / duration (ターン系) / manual_invalidate (現象 = 明示 invalidation のみ) + CANCEL 相殺 (grant 3 → dual 1 → 軸 2) を同一 trace で被覆。
- [x] gate: `./tools/test.sh` PASS ×2 連続 (files=61 checks=1049 failures=0; api-surface ok; contract-coverage implemented=23 reserved=8 violations=0)。

## 委任と検証 (CLAUDE.md: 委任結果は必ず検証)

- Run 1 (一括委任) は codex が巨大 golden JSON を読んで context 枯渇 → 失敗 (code 変更なし)。対策: file 読み取りの allowlist / api-surface を orchestrator 移管 / 2 分割で再委任。
- Run A (modifier-stack): diff 精査で契約準拠を確認、そのまま採用。
- Run B (EQStateAlgebra + golden): 検収で 2 点を orchestrator が修正:
  1. **`active_state` の三項式が非 CANCEL・stack 0 分岐で bool を返す崩れ** → `state if stacks_of > 0 else &""` に修正 + regression test 追加。
  2. 下記の非決定性 bug の暴露 (codex の新 test file 追加が引き金、原因は既存 code)。

## Repair-now: StringName sort の非決定性 (既存 bug、本 task で発見・修正)

- **事象**: Run B 後に既存 golden `reducibility_ctb_pipeline` が mismatch。poll 順が golden (steady→heavy→quick) とも今回 (quick→heavy→steady) とも内容順でない。
- **原因**: Godot 4.7 で `Array[StringName].sort()` は **intern/アドレス順** (headless probe で実証: `[aa, zz, ct.heavy, ...]`)。`EQEventLines.line_ids()` / `run_sweep_rules` の actor 走査が process の intern 履歴依存 = **replay 決定性の潜在破り** (EQM-112 起源)。test file が 1 個増えただけで順序が変わった。
- **修正**: 内容順 sort (`sort_custom(String(a) < String(b))`) へ変更 (line_ids / run_sweep_rules の 2 箇所)。eq_state_algebra.gd の sort は String key のため影響なし。editor 専用 `eq_calibration_tab.gd` の sort は golden 非関与のため対象外 (記録のみ)。
- **golden 再 baseline** (DETERMINISM_TRACE_TEST_POLICY §2 の明示手続き):
  - `./tools/test.sh --update-golden reducibility_ctb_pipeline`
  - 差分検証: 旧新 8663 行、record 多重集合は一致 (順序のみの差)、**非 progression 行 (resolved 等) の順序は完全一致** — 解決順・意味論は不変で、poll 記録の tick 内並びが内容順に正規化されただけ。
  - 他 golden で poll/sweep 記録を含むものなし (grep 確認)。`lifetime_composition` は修正後の順で green。

## API surface

- `EQStateAlgebra` を L3 で LAYER_MAP に追加、`python3 tools/check_api_surface.py --update` で再 baseline (差分 = EQStateAlgebra 1 class の追加のみ)、`docs/design/API_SURFACE.md` の L3 行に追記。L0/L1 leak なし (gate ok)。

## 申し送り

- `EQStateAlgebra.from_dict` は wrap_state を replay するため trace 付きで呼ぶと load 時に `state_wrapped` が emit される。snapshot 統合 (EQM-127) では `restore()` (直接復元・無 trace) を load 経路に使うこと。
- wrapper の意味論適用 (透徹連鎖などの実 decorator) は EQM-123 の変換/展開と EQM-128 の acceptance instance で確定する。
