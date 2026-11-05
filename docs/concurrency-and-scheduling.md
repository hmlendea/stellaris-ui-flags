# Concurrency and Scheduling

## Overview

The build system is **strictly sequential** — there is no parallelism, no scheduling, no background processing. This is a deliberate design choice (D1, INV-16).

## Execution Model

```
build.sh <version>
│
├── [Sequential] Setup validation
├── [Sequential] Static staging
└── [Sequential] Per-category loop
    └── [Sequential] Per-asset loop
        └── [Sequential] Pipeline stages
            1. Format → SVG
            2. SVG → 128px PNG → bevel → DDS
            3. SVG → 256px PNG → DDS
            4. SVG → 24px PNG → bevel → DDS
```

Every operation runs to completion before the next begins. No threads, no subprocess pools, no job queues.

## Why Sequential

| Reason | Detail |
|--------|--------|
| Simplicity | Bash sequential loops are trivial to reason about and debug |
| GIMP process model | Each operation spawns a fresh GIMP process; parallel GIMP instances would need separate user dirs/configs |
| Shared state | `build/` and `out/` are shared directories with no locking — parallel writes would corrupt outputs |
| Scale | 300+ assets × ~8 GIMP invocations ≈ 5–15 minutes — acceptable for a content mod |
| Determinism | Sequential filesystem-order processing gives reproducible behaviour |

## Concurrency Safety

### Not Supported

| Scenario | Safe? | Consequence |
|----------|-------|-------------|
| Two builds, same checkout, same time | ❌ | Corrupted `build/` and `out/` (interleaved writes, no locks) |
| Build while editing `source/` | ⚠️ | Undefined — build may read partial files |
| Build while game reads `out/` | ⚠️ | Game may see partial state; copy/symlink `out/` instead of pointing game at it directly |
| Two builds, separate checkouts | ✅ | Independent directories — fully safe |

### No Locking Mechanisms

- No lock files
- No PID checks
- No mutexes or semaphores

**Responsibility:** The user must not run concurrent builds. There is no protection and no warning.

## Scheduling

### Build Scheduling

**None.** Builds run when invoked:

```bash
./build.sh <version>
```

- No cron, no CI build schedule, no watch mode
- CI workflows do **not** build — they download the pre-built release asset (D13)

### CI Trigger Scheduling

| Workflow | Trigger | Schedule |
|----------|---------|----------|
| steam-workshop.yml | Tag push `v*.*.*` | On release only |
| nexus-mods.yml | Tag push `v*.*.*` | On release only |

No timed/scheduled CI jobs exist.

## Performance Characteristics

### Per-Asset Cost

| Stage | GIMP Invocations | Approx. Time |
|-------|------------------|--------------|
| Format → SVG | 0–1 (XCF only; Inkscape/potrace otherwise) | 0.1–1s |
| SVG → 128px PNG | 1 | 0.5–1s |
| Bevel (main) | 1 | 0.5–1s |
| PNG → DDS (main) | 1 | 0.5–1s |
| SVG → 256px PNG | 1 | 0.5–1s |
| PNG → DDS (map) | 1 | 0.5–1s |
| SVG → 24px PNG | 1 | 0.5–1s |
| Bevel (small) | 1 | 0.5–1s |
| PNG → DDS (small) | 1 | 0.5–1s |
| **Total** | **8** | **~4–8s** |

### Build Totals

| Scenario | Assets | Approx. Time |
|----------|--------|--------------|
| Full rebuild | 300+ | 5–15 minutes |
| Incremental (few new) | 1–10 | <30 seconds |
| Static-only change | 0 (all skip) | <10 seconds |

The dominant cost is GIMP process startup (~0.5–1s per invocation), not the image work itself.

## Parallelisation Potential (Future Work)

Not implemented. If ever attempted, the constraints are:

| Constraint | Requirement |
|------------|-------------|
| Output isolation | Each worker writes to distinct output paths (already true — per-asset filenames) |
| Intermediate isolation | Per-asset `build/` subdirectories or suffixed intermediates |
| GIMP user dirs | Parallel GIMP instances need `--gimpdir` or similar isolation |
| Static staging | Must complete before workers start (single writer) |
| Determinism | Preserve per-asset independence (assets don't depend on each other) |

**Estimated gain:** Near-linear speedup possible (assets are independent), but complexity cost is high for a 5–15 minute build.

**Recommendation:** Not worth implementing at current project scale. If build time becomes painful, batch GIMP operations (one invocation per asset instead of 8) is a simpler optimisation.

## Summary

| Property | Value |
|----------|-------|
| Parallelism | None |
| Concurrency safety | None (user responsibility) |
| Scheduling | Manual invocation only |
| CI builds | None (asset download instead) |
| Build time (full) | 5–15 minutes |
| Build time (incremental) | <30 seconds |
| Bottleneck | GIMP process startup |
| Parallelisation | Possible but not implemented |