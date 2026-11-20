# Invariants

## Overview

Invariants are conditions that must always hold true for the system to function correctly. Violating any of these breaks the build, the mod, or both. Future changes must preserve them.

## Build Invariants

### INV-1: Source Directory Presence

**Invariant:** `source/` directory exists at repository root when `build.sh` runs.

**Enforced by:** Build script validation (exit 1 if missing).

**Violation Effect:** Build aborts immediately.

---

### INV-2: All Required Tools Available

**Invariant:** ImageMagick, `rsvg-convert`, potrace, and Python 3 are detectable at build start; GIMP is detectable when a bevel session first starts.

**Enforced by:** Start-up tool detection and validation (exit 1 per missing tool), plus a lazy GIMP check inside `execute-gimp-script-file`.

**Violation Effect:** Build aborts at start-up if ImageMagick, potrace, Python 3, or `rsvg-convert` is missing. A missing GIMP aborts only once a bevel is actually required, so a fully cached build does not need it.

---

### INV-3: Version Argument Provided

**Invariant:** `build.sh` receives exactly one non-empty version argument.

**Enforced by:** Argument validation (exit 1 if empty).

**Violation Effect:** Build aborts with usage message.

---

### INV-4: SVG Intermediate Always Produced

**Invariant:** Every supported source format produces an SVG at `build/<category>/<source_name>.svg` before rendering.

**Enforced by:** Conversion functions and main loop structure.

**Violation Effect:** Subsequent `svg-to-png` calls fail; asset skipped.

**Dependency:** All rendering depends on this intermediate existing.

---

### INV-5: Three Output Variants Per Flag

**Invariant:** Each processed flag produces exactly three DDS files:
- `out/ui-flags/flags/<cat>/<name>.dds` (128px)
- `out/ui-flags/flags/<cat>/map/<name>.dds` (256px)
- `out/ui-flags/flags/<cat>/small/<name>.dds` (24px)

**Enforced by:** Main loop structure (three render/export sequences per asset).

**Violation Effect:** Game displays missing textures or fails to show the flag.

**Note:** The incremental skip check requires **all three** to exist — a partial set triggers reprocessing.

---

### INV-6: Same Filename Across Variants

**Invariant:** All three variants of a flag share the same base filename.

**Enforced by:** Single `FLAG_OUTPUT_FILE_NAME` used for all three paths.

**Violation Effect:** Game cannot associate variants; flag breaks in some contexts.

---

### INV-7: Map Flags Skip Bevel

**Invariant:** The 256px map variant never has gradient bevel applied.

**Enforced by:** Only the registered main and small PNGs are collected into `FLAG_BEVEL_PATHS`; the map PNG is rasterised and exported directly without ever reaching `bevel-pngs`.

**Violation Effect:** Map flags gain unwanted 3D effect; visual inconsistency.

---

### INV-8: Output Names Unique Per Category

**Invariant:** Within a category, no two source assets resolve to the same output filename.

**NOT enforced by:** Build script — collisions silently overwrite.

**Violation Effect:** One flag's output overwrites another's; a flag goes missing.

**Maintenance Rule:** When adding `names.txt` entries, verify no duplicate output values within a category.

---

### INV-9: Descriptor Files Generated Every Build

**Invariant:** Both `out/ui-flags.mod` and `out/ui-flags/descriptor.mod` are regenerated on every build, and both carry `path="mod/ui-flags"`.

**Enforced by:** Static staging stage runs unconditionally.

**Violation Effect:** Stale version/path in descriptors if constants change.

---

### INV-10: Static Assets Copied Every Build

**Invariant:** Backgrounds, colours.txt, localisation, and thumbnail are copied from source on every build.

**Enforced by:** Static staging stage runs unconditionally (overwrites existing).

**Violation Effect:** Stale static content if source files change.

---

## Content Invariants

### INV-11: Category Directory ↔ Localisation Key Match

**Invariant:** Every category directory under `source/flags/` has a corresponding `FLAG_CATEGORY_<directory_name>` key in localisation.

**NOT enforced by:** Build script.

**Violation Effect:** Category shows raw key (e.g., `FLAG_CATEGORY_newcat`) in game.

**Maintenance Rule:** When creating a category directory, add the localisation entry in the same change.

---

### INV-12: colours.txt Format Validity

**Invariant:** `source/colours.txt` is parseable by Stellaris (valid `colors = { ... }` block, valid HSV/RGB values).

**NOT enforced by:** Build script (copied verbatim).

**Violation Effect:** Colours missing or game errors on load.

**Maintenance Rule:** Validate format after editing; test in-game.

---

### INV-13: Background DDS Validity

**Invariant:** All files in `source/backgrounds/` are valid DDS (uncompressed BGRA8, square dimensions).

**NOT enforced by:** Build script (copied verbatim).

**Violation Effect:** Background fails to load or renders incorrectly in game.

---

### INV-14: Source Assets Have Removable Backgrounds

**Invariant (assumption):** Source flag designs have their emblem on a transparent or solid-colour background that the
`svg-to-png` stage can remove.

**NOT enforced by:** Build script.

**Violation Effect:** Flag renders with visible background square.

**Maintenance Rule:** Prepare sources with transparent backgrounds (SVG) or solid backgrounds (raster).

---

## Pipeline Invariants

### INV-15: Build Intermediates Persist

**Invariant:** `build/` directory retains SVG and PNG intermediates after build completes.

**Enforced by:** Build script never cleans `build/`.

**Violation Effect:** None directly — but deleting `build/` forces full reprocessing of all assets (intermediates regenerated).

**Purpose:** Intermediates enable debugging and would support future optimisation.

---

### INV-16: Bounded Parallel Workers

**Invariant:** Assets are rasterised and exported by at most `FLAG_WORKER_COUNT` workers, and at most
`FLAG_GIMP_CONCURRENCY` GIMP sessions run at once.

**Enforced by:** The worker loop waits for a free slot before starting the next worker, and
`start-bevel-session` waits for a free session slot before starting the next chunk.

**Violation Effect:** Concurrent builds on the same working copy corrupt outputs (shared `build/`
and `out/` directories, no locking).

**Maintenance Rule:** Never run two builds simultaneously on the same checkout.

---

### INV-17: GIMP Sessions Batch the Bevels

**Invariant:** The bevels are applied by shared GIMP sessions, each covering up to
`FLAG_BEVEL_BATCH_SIZE` images; the rasterisation and the DDS export use no GIMP session.

**Enforced by:** `bevel-pngs` chunks the paths and hands each chunk to `bevel_batch.py` in a single
session.

**Violation Effect:** One GIMP start per image, which restores the per-invocation start-up cost the
batching removes; an oversized batch exhausts the session memory and is killed partway.

**Consequence:** The per-image cost is the bevel itself; the session start is amortised over a whole
batch, and a killed session is retried over the remaining rounds.

---

### INV-18: Incremental Skip Requires All Three Outputs

**Invariant:** An asset is skipped only if all three output DDS files exist.

**Enforced by:** Three-file existence check.

**Violation Effect:** Partial outputs (e.g., after interrupted build) trigger full reprocessing of that asset — safe behaviour.

---

## Distribution Invariants

### INV-19: Release Archive Built From the Tag

**Invariant:** Each release workflow checks out the requested tag and builds the mod archive from that checkout.

**Enforced by:** Workflows — the archive is produced by the `Build the release archive` step from the checked-out content.

**Violation Effect:** A workflow failure leaves the platform on the previous version.

**Maintenance Rule:** Keep the tag, the build version argument, and the archive contents consistent.

---

### INV-20: Version Consistency Across Artefacts

**Invariant:** Build version = Git tag (minus `v`) = platform-displayed version.

**NOT enforced by:** Any automation.

**Violation Effect:** Confusing version mismatch across platforms.

**Maintenance Rule:** Follow the release procedure exactly — one version string everywhere.

---

## Invariant Enforcement Summary

| Invariant | Enforced | Mechanism |
|-----------|----------|-----------|
| INV-1 Source dir | ✅ Build aborts | Validation |
| INV-2 Tools | ✅ Build aborts | Start-up validation (GIMP lazy) |
| INV-3 Version arg | ✅ Build aborts | Validation |
| INV-4 SVG intermediate | ✅ Structural | Pipeline order |
| INV-5 Three variants | ✅ Structural | Pipeline order |
| INV-6 Same filenames | ✅ Structural | Single name variable |
| INV-7 No map bevel | ✅ Structural | Pipeline order |
| INV-8 Unique names | ❌ Manual | names.txt review |
| INV-9 Descriptors | ✅ Unconditional | Staging stage |
| INV-10 Static copy | ✅ Unconditional | Staging stage |
| INV-11 Localisation match | ❌ Manual | Same-change rule |
| INV-12 colours.txt valid | ❌ Manual | In-game test |
| INV-13 Background DDS valid | ❌ Manual | In-game test |
| INV-14 Removable backgrounds | ❌ Manual | Source preparation |
| INV-15 Intermediates persist | ✅ Structural | No cleanup |
| INV-16 Bounded parallel workers | ✅ Structural | Worker and session limits |
| INV-17 Batched GIMP sessions | ✅ Structural | Batching design |
| INV-18 Skip needs all three | ✅ Structural | Existence check |
| INV-19 Archive built from tag | ✅ Structural | Workflow build step |
| INV-20 Version consistency | ❌ Manual | Release procedure |

**Key Insight:** Structural invariants are safe — the pipeline design enforces them. Manual invariants (❌) rely on contributor discipline and are the most likely to break. When modifying the build, preserve all ✅ invariants; when contributing content, follow all ❌ maintenance rules.