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

The serialized scheduler snapshot (`EQSnapshot`, `SCHEMA_VERSION = 1`) and the
save bundle (`EQSaveAdapter`, `schema_version`) are the on-disk contracts a
consumer's save files depend on. This declares the v1.0 compatibility stance so a
game shipping on v1.0 knows what survives an addon upgrade.

## Decision (declared for v1.0): PRESERVE within v1.x, MIGRATE across a break, DEFER v2 tooling

| option | chosen? | meaning here |
|---|---|---|
| **preserve** | ✅ within v1.x | `schema_version = 1` stays readable across every v1.x release (patch + minor). No field is removed or repurposed within v1.x; only additive, optional fields may appear, and a v1.0 reader ignores unknown keys it doesn't need. |
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
  (tested, EQM-085), so a consumer can branch on it.

## What a consumer can rely on at v1.0

1. A save written by any v1.x release loads in any later v1.x release.
2. A save written by a *newer* schema (a future v2) is rejected cleanly on an older
   reader, never partially applied.
3. When a breaking change ships, it is a version bump with a documented migrator —
   the change is visible, not silent.

## Out of scope for v1.0

- Automatic v1→v2 migration (no v2 schema exists; deferred).
- Cross-engine-version snapshot portability beyond what Godot's own Variant
  serialization guarantees.
