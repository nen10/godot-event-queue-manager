# EQM-023 UX

end-user UX surface は無い。「利用者」= addon 開発者 / CI gate。

## UX Candidate Matrix

| candidate | user value | risk | cost | decision | reason |
|---|---|---|---|---|---|
| A. surface 変更は golden diff で必ず可視化 | high | low | low | adopt | 意図しない public API 変更を gate が止める。 |
| B. layer 未割当 class は FAIL | high | low | low | adopt | 新 public class に層割当を強制 (L3 leak 予防の前提)。 |
| C. golden 更新は明示 flag のみ | high | low | low | adopt | 通常 run は read-only。 |
| D. L3→L0/L1 leak は FAIL | high | low | low | adopt | roadmap §3.1 の層分離を機械保証。 |

## 開発者の操作

1. 通常: `./tools/test.sh` が `python3 tools/check_api_surface.py` を実行し、surface を golden と exact 比較 + leak 検出 + 未 tag 検出。差分/leak/未 tag があれば FAIL。
2. 意図した surface 変更時: `python3 tools/check_api_surface.py --update` (または `./tools/test.sh --update-golden api_surface`) で再 baseline し、self-review に差分要約を記載。
3. 検出器健全性: `python3 tools/check_api_surface.py --self-test` が synthetic な L3 leak を検出することを毎 run 確認。

## 既存 UX との干渉

新規 dev gate。runtime/resource に影響なし。test.sh の python-checks 区画に 2 invocation を追加。
