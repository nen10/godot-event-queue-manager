# EQM-010 UX

UI surface: なし (headless core)。User = API consumer。API ergonomics は POLICY.md。

## API Candidate Matrix

| candidate | value | risk | decision | reason |
|---|---|---|---|---|
| `EQEntry.make()` が invalid で null を返す | high | low | adopt | 明示拒否。caller が扱う。silent default ではない。 |
| `EQEntry.make()` が assert で停止 | low | high | reject | test で捕捉できず、shipped で crash。resilience は scheduler 層で。 |
| ordering を `less_than` + `sort` の static で公開 | high | low | adopt | 純粋・決定的・test 容易。 |
