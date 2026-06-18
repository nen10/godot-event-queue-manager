# EQM-080 POLICY

(設計の上位ソース: 承認済み plan `~/.claude/plans/phase-8-glimmering-wren.md`。)

## 採用判断

- **EQEffectRecord (core)**: simulation truth。`kind`/`source`/`target`/`stat`/`delta`(int)/`tags`/`classification`(StringName)。`CLASS_IMPORTANT/SENSED/OFFSCREEN` 定数。`to_trace_record()` = open-kind schema (EQM-013) 用の Dictionary (`kind=&"effect"` + fields)。`to_dict`/`from_dict`。即時記録 = 解決時に構築・追加。
- **EQEffectChunk (core)**: EffectRecord の蓄積器。`add`/`records`/`is_empty`/`clear`/`drain`。**`is_save_allowed()` = is_empty** (§10/§22)。解決時追加・save 境界で空。
- **EQPresentationEvent (presentation)**: `actor_id` + `position`(Variant 値 snapshot, queue 時点) + `classification` + `tags` + `changes_position_of`(Array[StringName]) + `depends_on`(Array[StringName])。transient `bind/bound` (live Node 用、非直列化)。`to_dict` は live ref を含めない。
- classification は consumer/adapter 供給 (Q12, decision 3)。addon は spatial 計算しない。
- 一方向: presentation 側は simulation (chunk/trace/scheduler) に書き戻さない (neutrality)。

## 不採用判断

- chunk/save 境界の EQM-085 への defer (user 決定で EQM-080 実装)。
- addon 内 sensing 計算 (consumer 供給)。
- position の present-時解決 (queue 時点 snapshot、barrier のため)。
- float を core ordering に (effect delta は int)。

## Invariants

- EffectRecord は即時・決定的、to_trace_record は canonical (int delta, no live ref)。
- chunk: 解決時追加、`is_save_allowed()` ⇔ is_empty。
- PresentationEvent.to_dict に live Node 参照なし (position は値)。
- presentation 側は simulation を変更しない。

## State / Invariant Table

| state/source | invariant | risk | proof/test |
|---|---|---|---|
| EffectRecord | 即時・決定的・trace 化 | 遅延/非決定 | 構築即 chunk に入る、to_trace_record canonical |
| chunk | is_save_allowed=is_empty | save 境界誤り | add で非空、drain/clear で空=save 可 |
| PresentationEvent | live ref を保存形式に入れない | Node 漏洩 | to_dict に binding なし、position は値 |
| classification | consumer 供給 field | addon 内計算 | field 値をそのまま保持 |

## Fallback / Mirror Handling

| item | decision | why | removal condition | test |
|---|---|---|---|---|
| classification 未設定 | 既定 &"" (= consumer 未分類) | 黙計算しない | — | 既定値確認 |
| position 未設定 | null/既定値 | 任意 | — | to_dict roundtrip |
| chunk drain | records 返却 + clear | save 境界遷移 | — | drain 後 is_empty |
