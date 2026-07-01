# Event Queue Manager マニュアル日本語版

このディレクトリは `docs/manual/` の日本語版です。英語版の構成を保ちつつ、現在のコードベースで確認できる UI 実行パスの状態も別章にまとめています。

| 章 | 内容 |
|---|---|
| [addon_user_manual.md](addon_user_manual.md) | アドオン利用者向けの統合マニュアル。導入、最小 turn loop、policy、UI の現状を一通り確認する入口 |
| [concepts.md](concepts.md) | event-line / event / trace の 3 面モデルと L0-L3 レイヤ |
| [quickstart.md](quickstart.md) | CTB battle を最小コードで動かす L0/L1 手順 |
| [policy_selection.md](policy_selection.md) | ジャンル別 policy 選択と demo 対応表 |
| [reservations.md](reservations.md) | 予約、準備、反応、wait/ready、target 操作 |
| [action_resolution.md](action_resolution.md) | AP 回復型 turn loop、wait/ready、rollback |
| [ui_execution_paths.md](ui_execution_paths.md) | マニュアル上の実施項目が UI から実行可能かのコードベース確認 |

読む順序は、単純な行動順だけなら `concepts.md` の L0/L1 と `quickstart.md` で十分です。準備行動、反応、AP、rollback を扱う場合だけ `reservations.md` と `action_resolution.md` に進んでください。
