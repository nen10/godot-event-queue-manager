# Event Queue Manager

A Godot 4.x addon for deterministic **event / turn / action order** management.

RPG 戦闘・ローグライク・タクティクス・4X・カード/ボードなど、多くのゲームで共通して必要になる「行動順管理」を、決定的かつ観測可能な順序で導入できるようにする addon。

> Status: pre-v0.1 / 設計・実装初期。code は `addons/event_queue_manager/` 以下に Phase 進行で追加される (EQM-002 以降)。本リポジトリは Roadmap → Implementation Queue → Task の自動化フローで開発する。

## 何ができるか (狙い)

- **単純な行動順** (L0/L1): actor 登録 → `turn_ready` signal → 行動終了。Fixed round / CTB / Energy / Wait Turn を Resource 差し替えで。
- **深い行動解決** (L2/L3): AP・解決時間・条件トリガ・反応準備・予約反芻・rollback を持つ予約 (reservation) と、進行軸を一般化する **event-line** モデル。
- **決定的な順序**: 順序は int (tick, priority, sequence) の単一全順序。canonical trace を golden fixture で検証する。
- **simulation と presentation の分離**: ステータス反映と画面エフェクト反映を分離し、表示矛盾を flush policy で防ぐ。
- **projection-first な editor UI**: editor は注入された headless state の projection。UI は数値 metric で受け入れ判定する (screenshot に依存しない)。

対応を意図するゲームシステム例: ポケモン型、ターン制不思議のダンジョン、FE、4X、タクティクスオウガ型ウェイトターン、および AP ベースの「行動解決ターン制」。

## 概念モデル

`event-line` (進行入力) と `event` (master timeline 上の解決順) と `event_line_progressed` (trace 観測) を 3 つの面として分離する。詳細は [`docs/design/EVENT_MODEL_CONCEPTS.md`](docs/design/EVENT_MODEL_CONCEPTS.md)。

## 開発フロー

開発は文書化された自動化フローで進む。入口は [`AGENTS.md`](AGENTS.md)。

```text
concept / feedback
  -> docs/plan/<date>_<id>/ROADMAP.md          # 方向 (docs/devflow/policy/ROADMAP_POLICY.md)
  -> docs/plan/<date>_<id>/IMPLEMENTATION_QUEUE.md  # task 分割 (IMPLEMENTATION_QUEUE_DESIGN_POLICY.md)
  -> READY task を実行                          # 線形: LINEAR_AUTOPILOT_QUEUE.md
                                                # 非線形: QUEUE_EXECUTION_PATTERNS.md
```

| 見る場所 | 内容 |
|---|---|
| [`AGENTS.md`](AGENTS.md) | request 種別ごとの文書 dispatch table |
| [`docs/devflow/PROJECT_PROFILE.md`](docs/devflow/PROJECT_PROFILE.md) | 原則・gate・停止条件・commit 可否 |
| [`docs/plan/2026-06-09_event_queue_manager/ROADMAP.md`](docs/plan/2026-06-09_event_queue_manager/ROADMAP.md) | 方向・層 (L0-L3)・milestone |
| [`docs/plan/2026-06-09_event_queue_manager/IMPLEMENTATION_QUEUE.md`](docs/plan/2026-06-09_event_queue_manager/IMPLEMENTATION_QUEUE.md) | task と Current pointer |
| [`docs/devflow/policy/`](docs/devflow/policy/) | test / UX / 決定性 / resilience の判断基準 |
| [`docs/design/`](docs/design/) | event model 意味論・open questions・契約 |

## テスト

```sh
./tools/test.sh        # 標準検証。$GODOT または PATH 上の godot を使う
```

- 必要環境: Godot 4.x (headless), python3。
- Godot が無い場合、`./tools/test.sh` は `BLOCKED_BY_TEST_ENV` を明示し専用 exit code (3) で終了する。
- 出力先は `.godot_user/test-runs/<run-id>/` (固定 path / 共有 log へ書かない)。
- 詳細は [`docs/devflow/TEST.md`](docs/devflow/TEST.md)。

## リポジトリ構成

```text
addons/event_queue_manager/  addon 本体 (EQM-002 以降)
docs/devflow/                開発プロセス (process / policy / profile / test index)
docs/plan/<date>_<id>/        roadmap, implementation queue, task packets
docs/design/                  event model semantics, open questions, contracts
docs/review/                  evaluation reports, self-reviews (autopilot/)
docs/ui/                      UI 契約文書 (EQM-086 以降)
tools/                        test.sh, static audits
```

## License

未確定 (release 候補 EQM-103 で AssetLib 互換ライセンスを選定)。
