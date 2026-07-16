# EQM-134 IMPLEMENTATION PLAN — state/relation engineering work scale

1. Reproduce and fix repeated `state_inv` oscillation without changing other
   transform convergence.
2. Add an executable multi-axis state/relation/trigger work-scale rung.
3. Document that evidence counts are engineering measurements, not GAME caps.
4. Run the standard suite, inspect deterministic trace/API diffs, and record a
   self-review.

No public method or snapshot schema is added.  Existing game consumers require
no migration.
