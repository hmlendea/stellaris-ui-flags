# Concurrency and Scheduling

## Overview

The build system is **pipeline-parallel**. Rasterisation and DDS export run in independent workers, and
the bevels are batched into shared GIMP sessions. Two knobs bound the parallelism: `FLAG_WORKER_COUNT`
for the plain-tool workers and `FLAG_GIMP_CONCURRENCY` for the GIMP sessions (D1).

## Execution Model

```
build.sh <version>
│
├── [Sequential] Setup validation
├── [Sequential] Static staging
└── [Sequential] Per-category loop
    └── [Sequential] Per-asset registration
        └── [FLAG_WORKER_COUNT parallel] Rasterise + export workers
            1. Format → SVG
            2. SVG → 128px, 256px, 24px PNG
            3. PNG → DDS (main, map, small)
    └── [FLAG_GIMP_CONCURRENCY parallel] Batched bevel rounds
        └── [FLAG_BEVEL_BATCH_SIZE] flags per GIMP session
```

Registration is sequential, and the bevels run only after every worker has finished, so the bevel
sessions never overlap the workers. Inside a round, sessions run concurrently up to
`FLAG_GIMP_CONCURRENCY`.

## Why These Limits

| Reason | Detail |
|--------|--------|
| GIMP process model | Each session spawns a fresh GIMP process (`--new-instance`); every instance reserves its own tile cache, so the session count is bounded separately from the worker count |
| Bounded memory | A GIMP session's memory grows with the number of images it has processed, so the batch is capped by `FLAG_BEVEL_BATCH_SIZE` and a killed session is retried |
| Shared state | Each flag writes only its own paths, and each session writes its own log, so the workers do not interleave output |
| Scale | One GIMP start covers a whole batch, so the cost is bounded by the number of sessions rather than the number of flags |

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