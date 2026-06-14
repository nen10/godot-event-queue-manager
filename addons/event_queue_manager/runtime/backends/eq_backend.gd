@abstract
class_name EQBackend
extends RefCounted
## Ordered-container contract behind which the scheduler stores entries.
##
## This is the single seam between EQScheduler's public API and the storage
## strategy. A concrete backend keeps EQEntry objects retrievable in EQOrdering
## order; the scheduler layers identity, generation/liveness and tick on top and
## never reaches into a backend's internals. Swapping sorted-array -> binary heap
## -> future native backend must not change the public API (roadmap §3.2,
## principle 19).
##
## Liveness is NOT a backend concern: a backend may hold stale (cancelled or
## rescheduled) entries. The scheduler discards them lazily when they surface.
##
## All methods are abstract: calling them on the base type is a dev fail-fast
## bug (RUNTIME_RESILIENCE_POLICY). Concrete backends must override every method.

const EQEntry := preload("../eq_entry.gd")


## Inserts an entry, preserving retrieval in EQOrdering order.
@abstract func insert(entry: EQEntry) -> void


## Removes and returns the EQOrdering-minimum entry, or null when empty.
@abstract func pop_min() -> EQEntry


## Returns the EQOrdering-minimum entry without removing it, or null when empty.
@abstract func peek_min() -> EQEntry


## Returns all entries in EQOrdering (pop) order without mutating the backend.
## Used by the scheduler for non-destructive peek(N) and later snapshot/trace.
## May include stale entries; the scheduler filters by liveness.
@abstract func ordered() -> Array


## Number of entries held (including any stale ones).
@abstract func size() -> int


## True when the backend holds no entries.
@abstract func is_empty() -> bool


## Drops all entries.
@abstract func clear() -> void
