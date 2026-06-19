# コンセプト: 考え方の土台

この章では、以降のマニュアルが前提にするモデルを説明します。一度読めば十分です。**単純な導線 (L0/L1) では深い層 (L2/L3) を使う必要はありません**。ただし、なぜ層が分かれているかを知っておくと、単純な project を単純なまま保てます。

正本: `docs/design/EVENT_MODEL_CONCEPTS.md` と `docs/design/EVENT_MODEL_SEMANTICS.md`。この章は利用者向けの要約です。

---

## 1. 2 つの問い

この addon は 2 つの異なる問いに答えます。混ぜないでください。

| 問い | レイヤ | 使うもの |
|---|---|---|
| 「次に誰の turn か」 | **L0 / L1** | `EQManager`、`EQConfig`、policy |
| 「準備済み/反応/待機中の action が何を、どの順序で行ったか」 | **L2 / L3** | reservation、trigger、transaction、event-line |

多くのターン制ゲームは、最初の問いだけで出荷できます。L0/L1 だけで完結でき、reservation や event-line に触れる必要はありません。

---

## 2. 3 つの面: 深いモデル

深い層を使う場合、engine は 3 つの面に分かれています。この 3 面を混ぜないことが、順序を決定的で説明可能にするための要点です。

```text
event-line ──(condition の threshold を超える)──▶ event が解決可能 / 無効になる   (input → output)
event      ──(resolve 時に issue / re-rate)────▶ event-line が進む、または生まれる (output → input)
both       ──(record)──────────────────────────▶ trace: event_line_progressed, …  (observation)
```

### 2.1 event-line: 進行の入力

名前付きの整数進行変数です。global tick が代表例で、entity ごとの wait-time や charge も event-line になり得ます。event-line は「起きるもの」ではなく、ただ進みます。master timeline 上の item にはなりません。

役割は、ゲームごとの「時間が進む / charge が溜まる / fuel が減る」といった進行を座標軸として吸収することです。そうすると、解決層は常に「condition の event-line が threshold を超えた」という形だけを見ればよくなります。

### 2.2 event: 順序づけられる出力

順序解決の単位です。`solve_conditions` (AND) がすべて満たされると解決され、effect を出し、event-line を issue / re-rate し、follow-up event を schedule できます。`invalidation_condition` (OR) が先に成立した場合は、解決されずに落ちます。

**reservation は、action-intent field を持つ event です。** comparator は event を単一の全順序 key `(due_tick ASC, priority DESC, sequence ASC)` で並べます。event-line はこの層に入れないため、全順序を証明できます。

### 2.3 event_line_progressed: 観測

canonical trace の 1 行です。「この解決 stream のこの時点で、event-line X が a→b に進んだ / re-rate された / issue された」という観測を記録します。

runtime object ではなく、何も引き起こしません。trace record を消しても挙動は同じです。だから schedule とは独立に、決定性を golden test できます。

---

## 3. レイヤ構成 (L0 → L3)

```text
L0  turn order ("who acts next")     EQRuntime, EQManager, EQActorRegistry, EQPrediction
L1  policy selection                 EQConfig, EQFixedRoundPolicy, EQCTBPolicy, EQEnergyPolicy, EQWaitTurnPolicy
L2  reservation / prepared actions   EQActionDefinition, EQReservation, EQActionResolutionPolicy,
                                     EQTriggerEngine, EQCondition, EQTransaction
L3  event-line internals             progression-as-input substrate。user API としては出さない
```

単純な導線を守るルール:

- **L3 は L0/L1 の public signature に漏れません。** class は `docs/design/API_SURFACE.md` でちょうど 1 つの layer に割り当てられます。api-surface gate は、L3 type が L0/L1 public method に現れたら build を落とします。単純導線の利用者が event-line を誤って渡されることはありません。
- **L0/L1 だけで first-class です。** `EQManager` + `EQConfig` + policy で、reservation なしの完全で決定的かつ保存可能な turn order が得られます。
- **L2 は opt-in です。** action が準備済み、反応、待機、target 操作を扱うときだけ reservation / trigger / transaction を使います (`reservations.md`)。L3 は内部に留まります。

---

## 4. 次に読むもの

- turn order だけなら、ここで十分です。`EQManager` (L0) + policy (L1) を使ってください。Timeline Preview Dock は `EQPrediction` が計算した順序をそのまま投影します。
- 準備、counter、wait、ready、target-operation action を扱う場合は `reservations.md`。
- AP 回復型の action-resolution loop、rollback、wait semantics は `action_resolution.md`。

