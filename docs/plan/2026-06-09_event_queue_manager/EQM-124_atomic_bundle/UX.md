# EQM-124 UX — atomic bundle
user goal: 「公平」の並列効果を、互いの結果を入力にせず 1 tick で原子的に解決し、反射などの state トリガは解決後に個別発火させる — を宣言だけで。
## 採用/廃止 UX
- 採用: bundle = 明示 acceptance API (自動束ねなし)。
- 廃止 (hack): ゲーム側での「擬似同時」手動直列化。
