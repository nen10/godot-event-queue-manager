# EQM-126 UX — phase recursion
user goal: 共鳴 (4 段階) や水鏡 (再帰入力) の深い操作フェーズで、ループが起きたら最小 cycle の入力だけ解除して安全に戻る — ゲーム側は再入力 UX に集中できる。
## 採用/廃止 UX
- 採用: 巻き戻し span と解除入力が trace で読める。
- 廃止 (hack): ゲーム側の手動フェーズ管理と ad-hoc reset。
