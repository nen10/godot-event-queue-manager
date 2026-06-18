# Design Review Policy

対象: Event Queue Manager の Roadmap、Implementation Queue、Task Packet、設計文書、UI contract、test/proof plan、実装後成果物
目的: 実装前または実装後の設計レビューで、project profile の価値判断が implementation slice へ正しく落ちているかを確認する。

origin: PTCG-AIBC の `design-review-policy.md` を、Event Queue Manager の Godot addon 開発向けに翻案した。

---

## 0. 結論

設計レビューは approval 待ちの儀式ではなく、実装が小さく縮小されすぎたり、逆に完了条件が曖昧な大 task になったりすることを防ぐ gate である。

Event Queue Manager では、特に次を分離して確認する。

- code が書けたこと。
- `./tools/test.sh` または対象 test で壊れていないこと。
- scheduler / policy / UI / docs / package の product proof が揃っていること。
- 旧 UX、暫定 schema、暫定 test を守るべき canonical contract と誤認していないこと。

設計レビューは、`docs/devflow/PROJECT_PROFILE.md` の product principles を上位判断として使う。古い実装や古い test が accepted direction と矛盾する場合は、互換維持ではなく queue / task packet で置換方針を明示する。

## 1. レビューの目的

設計レビューでは次を確認する。

- 目的、入力資料、対象 workflow が明確である。
- 採用、棄却、延期する UX / API / policy 判断が明示されている。
- 実装対象が product slice として小さく分割され、各単位に完了条件がある。
- code test と product proof が分離されている。
- Core Scheduler、Resource/API、Policy、Trigger/Reaction、Transaction、Presentation、Editor UI、Runtime integration、Docs/Demos/Package の依存が混ざっていない。
- 実装時に固定する contract と、addon 利用者または開発者が設定で変える control surface が分かれている。
- 追加要件が発生したときに、既存 task へ曖昧に混ぜず、Queue、Task Packet、contract 文書、optional prerequisite のどれかとして追跡できる。
- 既存の schema、UI path、golden、test fixture を変える場合は、使用実績を確認し、置換するのか互換性を維持するのかを設計側で明示している。

## 2. レビュー対象の分類

レビュー対象は、まず次のどれに当たるかを分類する。複数にまたがる場合は、失敗時の影響が最も大きい分類を主分類にする。

| 分類 | 対象例 | 見落としやすい問題 |
|---|---|---|
| roadmap / direction | `ROADMAP.md`、phase 設計、feedback 反映 | workflow 価値ではなくファイル分割だけで phase 化する |
| queue / orchestration | `IMPLEMENTATION_QUEUE.md`、dependencies、proof log | 1 task が大きすぎる、または code fragment になり product value がない |
| task packet | `SUB_TASKS.md`、`UX.md`、`POLICY.md`、`IMPLEMENTATION_PLAN.md` | 採用/棄却判断、fallback、state invariant、test path が後段へ先送りされる |
| core scheduler | push/pop/peek/cancel/reschedule、tie-break、snapshot | int order key、同順解決、prediction purity、snapshot continuity が曖昧になる |
| resource / API contract | `EQConfig`、`EQPolicy`、`EQEventTemplate`、validation、public method | sample-only default、unknown field、round-trip、layer 境界が未確認になる |
| policy / progression | Fixed round、CTB、Energy、Wait Turn、Action Resolution、event-line | event-line と master timeline が混ざる、policy 固有 contract がない |
| trigger / reaction | condition、reaction arming、duration、cancel/expire、cycle guard | 条件評価と効果実行が混ざる、循環予約や無限反応を検出できない |
| transaction / presentation | rollback、commit、deterministic RNG、effect flush、visibility | UI 都合で simulation correctness を歪める |
| editor UI / UX | timeline dock、config panel、inspector、template generator | projection-first でない、sample が production source になる、no-op / hack path が残る |
| runtime / integration | Godot Node bridge、autoload 任意、save/load rebind、resilience mode | saved data に Node 参照が混ざる、shipped game を crash させる |
| test / proof | `./tools/test.sh`、golden trace、property test、UI metric | test が旧 UX/API を温存する、golden diff を根拠なしに更新する |
| docs / demos / package | manual、demo scene、addon manifest、dist/package | 実装前の manual が正本化する、demo が trace proof を持たない |
| generated artifact | golden、layout snapshot、metric report、generated docs、package artifact | 正本上書き、snapshot 保存、再生成条件が実装時に曖昧になる |
| provisional contract redesign | 暫定 schema、fixture、UI state、test oracle、generated artifact | ほぼ未使用の暫定形式を後方互換対象として守ってしまう |

## 3. 基本レビュー項目

## 基本レビュー項目

以下は自明な項目として、設計ごとに見出しまたは表の列があればよい。

## 入力資料と根拠

## 目標と分割した目標

### 採用 / 棄却 / 延期判断

採用する UX / API / policy と、棄却または延期する選択肢を明示する。旧 UI や旧 test を残す/削除の理由。

## 実装範囲

## 成果物

code、test、golden、contract 文書、manual、demo、package artifact を分けて書く。

### 依存関係

先に必要な schema、state model、fixture、Godot runtime、editor surface、docs を Queue ID または path で追跡する。

### 実行順序

実装順、proof 生成順、docs 更新順を分ける。manual と package refresh は、説明対象の UI/API が安定してから行う。

### Test Gate

標準検証は `./tools/test.sh`。対象 slice に必要な unit/property/golden/UI metric/manual/package 検査も書く。

### Product Proof Gate

code test とは別に、addon の価値が証明された状態を書く。例: canonical trace が順序を証明する、editor UI が injected state の projection として操作できる、demo が headless trace gate を持つ。

### Compatibility / Replace Stance

既存 schema、fixture、UI path、test oracle を守るのか置換するのかを書く。新規 addon の既定は `replace` だが、`active_canonical` の場合だけ migration / deprecation を検討する。

## 要件整理レビュー

要件整理レビューは、1 task の実装規模を小さく保ちながら、必要な要件を漏らさず積み上げるために行う。追加要件は既存 task の説明へ曖昧に混ぜず、Queue、Task Packet、contract 文書、control surface、optional prerequisite のどれかとして追跡する。

| レビュー項目 | 確認すること | 設計へ残す内容 |
|---|---|---|
| code 完了と product 完了を分ける | 実装が通っただけで addon workflow が達成済みに見えないか | `test gate` と `product proof gate` を別に書く |
| 実装前に足りない前提を洗い出す | schema、fixture、Godot runtime、editor surface、sample asset、contract 文書が未準備ではないか | dependency map、prerequisite、Queue ID を書く |
| 前提ごとに解決計画を作る | 大きな前提を1行の注意書きで済ませていないか | 入力、出力、検証方法、実装順を書く |
| 依存を Queue 番号で追えるようにする | 「先にこれが必要」が文章だけになっていないか | `EQM-xxx` や Scheduled task ID を依存列に明記する |
| 既存 Queue を壊さず追加 Queue を足す | 参照済み番号を renumber していないか | 新規 Queue ID、実行位置、dependency、acceptance を書く |
| 実装で固定する点を決める | 実装者の裁量で comparator、schema、fallback、Resource API が変わる箇所が残っていないか | canonical schema、public method、validation、fallback、resilience mode を固定する |
| 設定で変える入口を決める | addon 利用者や開発者が変えたい値が code 改変前提になっていないか | `EQConfig`、`EQPolicy`、Resource、inspector option、dev/shipped mode へ出す |
| 任意拡張を分ける | 今すぐ必須ではない genre policy、demo、adapter、visual polish が混ざっていないか | optional prerequisite または backlog として分離する |
| 暫定 contract を本採用 contract へ統一する | ほぼ未使用の schema、fixture、UI state、test oracle に互換層を増やしていないか | 使用実績、暫定判定、本採用形式、旧形式の破棄/再生成方針を書く |
| 成果物の種類を分ける | code、test fixture、golden、docs、package が同じ完了条件になっていないか | proof grade と artifact checkpoint を分ける |
| 長い検証を checkpoint 化する | Godot import、demo trace、UI metric、package check を1つの曖昧な完了条件にしていないか | smoke、targeted、full、再実行条件、出力 path を書く |
| 生成手順と設定を残す | golden や generated docs が再生成不能になっていないか | command、input、output、run-id、update 条件を self-review に残す |

## 4. 設計理念

以下は、対象分類に該当する場合に設計が満たすべき理念である。該当しない分類は省略してよい。

### 順序決定は単一の決定論的パスを持つ

順序を決定するすべての経路——解決・予測・復元・表示——が同じ trace を生む。経路ごとに結果が異なるなら、順序保証は成立していない。

対象分類: core scheduler、policy / progression、transaction / presentation、test / proof、editor UI / UX。

### データは層境界を越えても意味を保つ

canonical schema が存在し、保存・復元・layer 間転送で意味が変わらない。上位層の概念が下位層の surface に漏れない。

対象分類: resource / API contract、runtime / integration、docs / demos / package、provisional contract redesign。

### UI は state の投影であり、state の源泉ではない

画面に出るものはすべて headless state から導出できる。state が先、surface が後。UI 固有の状態が simulation に逆流しない。

対象分類: editor UI / UX、task packet、test / proof。

### 正常パスは環境に依存せず、異常パスは環境に適応する

正常 trace は実行環境やエラーモードの違いで変わらない。異常時の振る舞いだけが環境に応じて分岐する。永続化データに実行環境固有の参照を含まない。

対象分類: runtime / integration、resource / API contract、transaction / presentation。

### 評価と実行は分離し、副作用は境界を持つ

「何が起きるか」の判定と「実際に起こす」は別フェーズである。副作用には開始・終了・取消の明示的な境界があり、無限連鎖を起こさない。未確定の変更が確定済みの状態と混ざらない。

対象分類: trigger / reaction、transaction / presentation、policy / progression。

### テストは採用した契約を証明し、廃止した契約を温存しない

テストが守る対象は現在の accepted contract である。旧仕様を延命するためのテストは追加しない。検証不能な環境では完了扱いにせず阻害を記録する。

対象分類: test / proof、core scheduler、editor UI / UX、docs / demos / package。

### 文書は採用済み事実を説明し、demo は検証可能な証拠を持つ

manual は仕様を決める文書ではなく、決まった仕様を説明する文書である。demo と sample は学習素材であり、production の入力源にならない。生成物には再現手順が残る。

対象分類: docs / demos / package、generated artifact、test / proof。

### 未確立の契約は互換対象ではなく、置換対象である

ほぼ使われていない暫定形式を後方互換の対象として守らない。使用実績（`provisional_unused` / `limited_internal` / `active_canonical`）を分類し、互換性維持を検討するのは `active_canonical` の場合だけである。

対象分類: provisional contract redesign、resource / API contract、test / proof、docs / demos / package。

## 5. レビュー結果の記録形式

設計レビュー結果には、最低限次を残す。

| 項目 | 記録内容 |
|---|---|
| 対象 | Roadmap、Queue、Task Packet、設計文書、実装後成果物の path |
| 主分類 | レビュー対象の分類 |
| 判断 | `pass`、`pass_with_followups`、`needs_design_update`、`blocked` |
| 採用判断 | 採用する UX / API / policy / test proof |
| 棄却 / 延期判断 | 残さない旧 UX、暫定 contract、backlog へ送る optional scope |
| 実装固定点 | schema、API、comparator、validation、fallback、resilience mode |
| control surface | `EQConfig`、`EQPolicy`、Resource、inspector option、dev/shipped mode |
| test gate | code 実装として通す検査 |
| product proof gate | 順序、UI、demo、package など product value の証明 |
| proof grade | `schema_only`、`headless_smoke`、`contract_tested`、`golden_or_property_proven`、`editor_projection_verified`、`package_or_demo_verified` |
| 追加要件 | 新規 Queue、Scheduled task、contract 文書、optional prerequisite |
| provisional contract | 使用実績分類、本採用 contract、旧 contract の扱い、互換性判断 |
| 未解決リスク | 実装時に縮小されやすい点、Godot 環境依存、長時間検証、外部 asset 依存 |

## 6. 完了条件

設計レビューは、次を満たしたときに完了とする。

- 目標、入力、成果物、依存、実行順序が書かれている。
- 採用、棄却、延期する UX / API / policy が明示されている。
- test gate と product proof gate が分離されている。
- 実装固定点と control surface が分離されている。
- 追加要件が Queue、Task Packet、contract 文書、control surface、optional prerequisite のいずれかに整理されている。
- 詳細レビュー項目のうち、該当分類に必要なものが確認されている。
- proof grade と、code 完了、artifact 完了、product review の境界が分かる。
- 暫定 contract を変える場合、互換性維持ではなく本採用 contract へ統一する意図、旧 contract の扱い、ユーザー確認事項が書かれている。
- Godot や標準検証環境がない場合、完了扱いにせず `BLOCKED_BY_TEST_ENV` と command/error を記録する。
