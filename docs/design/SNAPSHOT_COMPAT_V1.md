# Snapshot schema compatibility — v1.0 stance

> **v1.1 (EQM-117, 2026-07-02): bundle `SCHEMA_VERSION` is now 2.** Additive
> pipeline tables (`event_lines` / `windows` / `armed_triggers` /
> `pending_conditional` / `scheduled_reservations`, SEM §10) sit next to the v1
> keys. The declared **migrate** path shipped with it: a v1 bundle loads with
> the missing tables defaulted to empty; a v2 bundle on a v1.0 reader is
> rejected cleanly (unchanged fail-safe). Saving through the pipeline is gated
> on the save boundary (chunk empty, no explicit window; `eqm.save.blocked`
> otherwise, no force flag). Loading verifies referenced predicate / effect /
> sweep-rule names BEFORE mutating anything (stable error, never a half-load).
> The `windows` table is always empty in a save (the boundary gate implies
> depth 0); the key exists for schema shape / future rollback bundles. Open
> race groups are not persisted — members are, but the winner's bulk
> loser-sweep does not survive a save (EQM-117 POLICY).

> **v1.2 (EQM-127, 2026-07-05): bundle `SCHEMA_VERSION` is now 3.** Additive
> `relations` and `state_algebra` tables are added for L3 extension support
> (relation graph / state stack algebra, SEM §13.1 / §5.7). No migration is
> needed in this seam: missing tables are treated as empty. A v3 bundle is
> rejected by a v1/v2 reader because of `schema_version`, while a bundle newer
> than v3 is rejected by the same fail-safe boundary in the v3 reader.
> Verification of v3 tables is verify-before-mutate:
> `relations` / `state_algebra` are accepted only when the runtime has
> corresponding optional attachment, relation maintenance predicates are
> registered, and then restores are in-place (`restore`, not `from_dict`).

> **Transactional effect-result binding (2026-07-14): bundle
> `SCHEMA_VERSION` is now 4.** Every reservation written by the v4 writer
> carries `effect_commit_result_version` and
> `expiry_effect_commit_result_version`; these preserve whether each named
> handler was issued as legacy Array mode (`0`) or typed-result mode (`1`).
> The v4 reader migrates v1-v3 reservation dictionaries that lack either field
> by assigning legacy mode `0`. Versions 1-3 can only express legacy mode:
> explicitly supplied nonzero bindings are rejected as
> `binding_not_supported_by_schema`, preventing a v4 typed bundle from being
> accepted after only its top-level version is rewritten. A v4 payload must
> contain both fields for every
> serialized reservation; a missing field is rejected verify-before-mutate as
> `eqm.effect.commit_result_version_unsupported` (`reason: missing_binding`).
> A v3 reader rejects the whole v4 bundle at the top-level `schema_version`
> boundary. It therefore cannot ignore the new fields and silently reinterpret
> pending typed work as legacy work.

> **Reaction FIRE occurrence context (EQM-132, 2026-07-15): bundle
> `SCHEMA_VERSION` is now 5.** Every `scheduled_reservations` row carries
> `reaction_fire_context` (`{}` for ordinary reservations). A pending reaction
> FIRE requires a valid version-1 value whose `fire_event_id` matches the row;
> duplicate/orphan identities and malformed values reject before mutation.
> Armed state and scheduled FIRE occurrences serialize as distinct reservation
> instances. Versions 1-4 continue to migrate ordinary rows with an empty
> context, but a historical pending reaction FIRE is rejected because those
> formats never stored its trigger cause. A v4 reader rejects v5 at the
> top-level boundary and cannot silently discard the cause.

> **Reaction-expiry ownership (EQM-133, 2026-07-15): bundle
> `SCHEMA_VERSION` is now 6.** The additive `reaction_expiries` table contains
> every live scheduler expiry event and its reservation value, including the
> stale event retained after reaction-count exhaustion. Its event ids must be
> a bijection with scheduler `expiry` entries. A still-armed reaction's
> `expiry_event_id` points at the same value; a count-closed row is `RESOLVED`
> with no remaining uses and later preserves `closed_by: already_closed`.
> Versions 1-5 migrate expiry state only when an armed row retains that link.
> A historical orphan scheduler expiry is rejected before mutation because
> those formats did not store the reservation identity required to rebuild it.
> A v5 reader rejects v6 at the top-level boundary.

> **Issuance-time reservation meta (EQM-135, 2026-07-18): bundle
> `SCHEMA_VERSION` is now 7.** Every serialized reservation carries
> `issued_meta_level`, sampled once when submit is accepted. It can therefore
> remain stable if a declaration changes later. Versions 1-6 migrate a missing
> sample from the inline definition meta. Those versions cannot represent a
> differing issued value; placing one under a historical top-level version is
> rejected before mutation. A v6 reader rejects v7 at the top-level boundary
> and cannot silently fall back to the later declaration value.

> **Armed reaction FIRE gate (EQM-141, 2026-07-19): bundle
> `SCHEMA_VERSION` is now 8.** Every armed trigger row carries its already-bound
> `solve`, `inv`, and declared `counter_lines` state; `event_lines.counter_ids`
> records which frozen lines were generated as counters. A v1-v7 empty-gate arm
> migrates to empty arrays. A historical arm whose definition declares a gate
> rejects before mutation because those formats cannot recover its relative
> threshold anchor or counter-line identity. Schema v8 verifies exact term shape,
> the arm-time authored spec snapshot, saved line identity, predicate registration,
> and unique generated-counter provenance. The same row projects each exact
> slot's arm-time duration, authored rumination, and remaining rumination; duplicate
> slots do not share this state. Post-arm definition edits therefore do not rewrite
> the gate/lifecycle snapshot or make a writer-produced bundle unloadable. A v7
> reader rejects v8 at the top-level boundary.

The serialized scheduler snapshot (`EQSnapshot`, `SCHEMA_VERSION = 1`) and the
save bundle (`EQSaveAdapter`, `schema_version`) are the on-disk contracts a
consumer's save files depend on. This declares the v1.0 compatibility stance so a
game shipping on v1.0 knows what survives an addon upgrade.

## Decision (declared for v1.0): PRESERVE within v1.x, MIGRATE across a break, DEFER v2 tooling

| option | chosen? | meaning here |
|---|---|---|
| **preserve** | ✅ within v1.x | Historical schemas remain readable when their payload contains enough state for deterministic migration. No field is removed or repurposed within one schema; when a new field must not be ignored by an older reader, the bundle version is bumped and the later reader supplies an explicit migration. The documented fail-closed exception is a v1-v7 conditioned armed reaction: those schemas never stored its bound anchor/counter identity, so a v8 reader rejects that ambiguous state instead of guessing. |
| **migrate** | ✅ on a breaking change | a breaking schema change bumps `SCHEMA_VERSION` (and the addon minor/major) and ships an explicit migrator + a changelog entry. A save is never silently reinterpreted under a new schema. |
| **replace** | ❌ | the addon does not silently discard or overwrite an incompatible snapshot. Loading an unsupported version fails safe (below), leaving the consumer to decide. |
| **defer** | ✅ cross-major tooling | a v1→v2 migration tool is deferred until a v2 schema actually exists; building it now would be speculative. The seam (`schema_version` + `is_supported_version`) is in place so it can be added without redesign. |

## Current load behavior (the fail-safe that backs the stance)

- `EQSnapshot.is_supported_version(v)` is `v == SCHEMA_VERSION`. A snapshot with a
  missing, newer, or unknown `schema_version` is **rejected** with an `EQError`
  (`UNKNOWN_VERSION`), not coerced — consistent with shipped fail-safe
  (`RUNTIME_RESILIENCE_POLICY`): the consumer's game is not crashed, and a bad save
  is not silently half-loaded.
- `EQSaveAdapter.load(...)` returns `false` on an unsupported `schema_version`
  (tested, EQM-085), so a consumer can branch on it. The current v8 reader
  accepts bundle versions 1 through 8. For v1-v3 only, absent effect-result
  binding fields migrate to legacy `0`, but any explicit nonzero binding is
  rejected; v4+ requires both fields. Schema v5 additionally requires the
  scheduled-row context field. Schema v6 additionally requires exact
  `reaction_expiries` ownership. Schema v7 additionally requires an integer
  `issued_meta_level` on every reservation; v1-v6 migrate it from the inline
  definition and reject an explicit differing value. Schema v8 additionally
  requires exact bound state for every armed reaction FIRE gate; v1-v7 migrate
  only empty-gate arms, and preserves exact slot-local duration/use continuation.
  All reject malformed bundles before applying any state.

## What a consumer can rely on at v1.0

1. A save written by a v1.x release loads in a later v1.x release when its
   historical payload contains all state required for deterministic migration.
   The explicit fail-closed exception is a v1-v7 save with a conditioned armed
   reaction: it is rejected because the historical payload cannot reconstruct
   the arm-time relative anchor or generated-counter identity. Empty-gate arms
   from those versions continue to migrate, and schema v8 conditioned arms are
   fully preserved.
2. A save written by a *newer* schema is rejected cleanly on an older reader,
   never partially applied. In particular, a v7 reader rejects a v8 bundle at
   the top-level version boundary.
3. When a breaking change ships, it is a version bump with a documented migrator —
   the change is visible, not silent.

## Out of scope in the original v1.0 release

- Automatic v1→v2 migration (no v2 schema existed at that release; the later
  migration history is recorded above).
- Cross-engine-version snapshot portability beyond what Godot's own Variant
  serialization guarantees.

> **Scheduler backend selection (EQM-145, 2026-07-19): no snapshot schema change.**
> `EQConfig.scheduler_backend` is Resource/API configuration, not scheduler
> state. Scheduler snapshots continue to store only live entries, counters, and
> the clock; they do not serialize whether the runtime used the sorted-array or
> binary-heap backend. A loaded snapshot is therefore portable across backends:
> choose the backend in `EQConfig` before restore/seed, and the restored pop
> order remains identical because `EQOrdering` is total. Attempting to apply a
> backend config after live events exist records
> `eqm.runtime.scheduler_backend_reconfigure_nonempty` and keeps the existing
> scheduler rather than migrating it implicitly.
