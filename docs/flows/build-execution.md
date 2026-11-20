# Build Execution Flow

## Overview

This document describes the end-to-end execution flow of the build pipeline from invocation to completion, including all decision points, data transformations, and control flow.

## Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         BUILD EXECUTION FLOW                                │
└─────────────────────────────────────────────────────────────────────────────┘

START
  │
  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. ARGUMENT VALIDATION                                                      │
│    ├── Read $1 as MOD_VERSION                                               │
│    ├── IF empty: PRINT usage, EXIT 1                                        │
│    └── IF provided: CONTINUE                                                │
└─────────────────────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 2. SOURCE DIRECTORY VALIDATION                                              │
│    ├── CHECK source/ exists                                                 │
│    ├── IF missing: PRINT "MISSING SOURCE DIRECTORY", EXIT 1                │
│    └── IF exists: CONTINUE                                                  │
└─────────────────────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 3. TOOL DETECTION & VALIDATION                                              │
│    ├── ImageMagick: CHECK /usr/bin/convert                                 │
│    ├── potrace: CHECK /usr/bin/potrace                                     │
│    ├── Python 3: CHECK /usr/bin/python3, else `command -v python3`          │
│    ├── rsvg-convert: CHECK /usr/bin/rsvg-convert, else `command -v`         │
│    ├── IF missing: PRINT "[ERROR] X is not installed on this system", EXIT 1 │
│    ├── GIMP: NOT checked here — resolved lazily at the first bevel session   │
│    └── ALL found: CONTINUE                                                  │
└─────────────────────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 4. STATIC ASSET STAGING                                                     │
│    ├── CREATE out/ui-flags/flags/backgrounds/                               │
│    ├── CREATE out/ui-flags/localisation/                                    │
│    ├── COPY source/backgrounds/* → out/ui-flags/flags/backgrounds/         │
│    ├── COPY source/colours.txt → out/ui-flags/flags/colors.txt             │
│    ├── COPY source/localisation.yml → out/ui-flags/localisation/           │
│    │   └── RENAME to ui-flags_l_english.yml                                 │
│    ├── COPY source/thumbnail.png → out/ui-flags/thumbnail.png              │
│    ├── GENERATE out/ui-flags.mod (root descriptor)                         │
│    └── GENERATE out/ui-flags/descriptor.mod (package descriptor)           │
└─────────────────────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 5. CATEGORY DISCOVERY & ITERATION                                           │
│    ├── GLOB source/flags/* → category entries                              │
│    ├── SKIP empty directories and non-directories                            │
│    ├── FOR each category directory:                                         │
│    │   ├── EXTRACT category name (basename)                                 │
│    │   ├── CREATE build/<category>/map/                                     │
│    │   ├── CREATE build/<category>/small/                                   │
│    │   ├── CREATE out/ui-flags/flags/<category>/map/                       │
│    │   ├── CREATE out/ui-flags/flags/<category>/small/                     │
│    │   ├── IF source/flags/<category>/usage.txt EXISTS:                    │
│    │   │   └── COPY to out/ui-flags/flags/<category>/usage.txt             │
│    │   └── PROCESS ASSETS (step 6)                                          │
│    └── ALL categories processed: CONTINUE                                   │
└─────────────────────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 6. PER-ASSET PROCESSING (nested in category loop)                           │
│    ├── GLOB source/flags/<category>/* → asset files                         │
│    ├── SKIP usage.txt and non-regular files                                 │
│    ├── FOR each asset file:                                                 │
│    │   ├── SKIP if not regular file                                         │
│    │   ├── EXTRACT source filename (basename without extension)            │
│    │   ├── RESOLVE output filename via get-flag-file-name()                │
│    │   │   ├── LOOKUP in source/names.txt                                   │
│    │   │   ├── IF found: USE mapped name                                    │
│    │   │   └── IF not found: USE "ui_" + source filename                   │
│    │   ├── CONSTRUCT output paths:                                          │
│    │   │   ├── MAIN: out/ui-flags/flags/<cat>/<name>.dds                   │
│    │   │   ├── MAP:  out/ui-flags/flags/<cat>/map/<name>.dds               │
│    │   │   └── SMALL: out/ui-flags/flags/<cat>/small/<name>.dds            │
│    │   ├── INCREMENTAL CHECK:                                               │
│    │   │   ├── IF all 3 output DDS exist: CONTINUE (skip asset)           │
│    │   │   └── ELSE: PROCEED                                                │
│    │   ├── CONSTRUCT build intermediate paths                               │
│    │   ├── FORMAT CONVERSION (step 7)                                       │
│    │   ├── RASTERISE & EXPORT MAP, REGISTER FOR BEVEL (step 8)              │
│    │   └── LOOP to next asset                                               │
│    └── ALL assets processed: CONTINUE to next category                      │
│ 8b. AFTER ALL WORKERS: BATCHED BEVEL ROUNDS (step 9)                        │
│ 8c. AFTER BEVEL ROUNDS: EXPORT BEVELED MAIN & SMALL DDS (step 10)          │
└─────────────────────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 7. SOURCE FORMAT → SVG CONVERSION                                           │
│    ├── SWITCH on file extension:                                            │
│    │   ├── .bmp  → bmp-to-svg()  (potrace)                                  │
│    │   ├── .png  → png-to-svg()  (magick → potrace)                        │
│    │   ├── .svg  → COPY to build SVG                                        │
│    │   └── DEFAULT → PRINT "Unsupported format", CONTINUE                  │
│    └── OUTPUT: build/<category>/<source_name>.svg                          │
└─────────────────────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 8. RASTERISE PNGs (MAIN 128px, MAP 256px, SMALL 24px); EXPORT MAP DDS      │
│    ├── svg-to-png(build SVG, build MAIN PNG, 128)                          │
│    │   └── rsvg-convert + ImageMagick, no GIMP session                      │
│    ├── svg-to-png(build SVG, build MAP PNG, 256)                           │
│    ├── svg-to-png(build SVG, build SMALL PNG, 24)                          │
│    ├── export-map-dds(build MAP PNG, out MAP DDS)                          │
│    │   └── the map needs no bevel, so it is exported by the worker         │
│    └── OUTPUT: build/<category>/<name>.png and the map/ and small/ variants │
└─────────────────────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 9. BATCHED BEVEL (MAIN + SMALL)                                             │
│    ├── bevel-pngs(round, unbeveled MAIN and SMALL PNGs)                    │
│    │   └── GIMP: blur silhouette, emboss relief, gradient tint per image   │
│    │   └── FLAG_BEVEL_BATCH_SIZE images per session, FLAG_GIMP_CONCURRENCY │
│    │       sessions at once; one session start covers the whole batch      │
│    ├── Round whose session is killed retries the unmarked PNGs             │
│    └── OUTPUT: MAIN and SMALL PNGs beveled in place, each with a .beveled  │
└─────────────────────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 10. BEVELED PNG → DDS EXPORT                                                │
│    ├── export-beveled-dds(build MAIN PNG, out MAIN DDS)                    │
│    ├── export-beveled-dds(build SMALL PNG, out SMALL DDS)                  │
│    │   └── Python writes the uncompressed format directly, no GIMP session │
│    ├── Runs after the bevel rounds, so the output textures carry the bevel │
│    └── OUTPUT: out/ui-flags/flags/<cat>/<name>.dds and the small/ variant  │
└─────────────────────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 11. COMPLETION                                                              │
│    ├── All categories processed                                             │
│    ├── All assets processed                                                 │
│    ├── Unbeveled flags reported (if any) before the final count            │
│    ├── Final line: Produced <n> of <n> flag DDS files.                     │
│    └── Output package ready at out/ui-flags/                                │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Detailed Step Descriptions

### Step 1: Argument Validation

**Trigger:** Script invocation `./build.sh <version>`

**Logic:**
```bash
MOD_VERSION="${1}"
if [ -z "${MOD_VERSION}" ]; then
    echo "Please specify a version!"
    exit 1
fi
```

**Failure Mode:** Missing argument → immediate exit with `Please specify a version!`.

**Success:** `MOD_VERSION` set, proceed to step 2.

### Step 2: Source Directory Validation

**Logic:**
```bash
[ ! -d "${SOURCE_DIR_PATH}" ] && echo "MISSING SOURCE DIRECTORY" && exit -1
```

**Failure Mode:** `source/` not found → exit with code 255 (`-1`). Usually means wrong working directory.

**Success:** Source directory confirmed, proceed to step 3.

### Step 3: Tool Detection & Validation

**Detection Order (per tool):**
- ImageMagick and potrace: fixed `/usr/bin` paths
- Python 3 and `rsvg-convert`: `/usr/bin` path, then `command -v` fallback
- GIMP: `/usr/bin/gimp`, then the Flatpak system export, then the Flatpak user export — evaluated lazily at the first bevel session, not at start-up

**Tools Checked at Start-up:**
| Tool | Command | Checked at start-up |
|------|---------|---------------------|
| ImageMagick | `/usr/bin/convert` | Yes |
| potrace | `/usr/bin/potrace` | Yes |
| Python 3 | `python3` | Yes |
| librsvg | `rsvg-convert` | Yes |
| GIMP | `gimp` | **No** — lazily at the first bevel session |

**Failure Mode:** A tool missing at start-up → print `[ERROR] X is not installed on this system`, exit 1. A missing GIMP only fails once a bevel is actually required.

**Success:** Tool paths stored in variables, proceed to step 4.

### Step 4: Static Asset Staging

**Operations (sequential):**
1. Create output directory structure
2. Copy backgrounds (40+ DDS files)
3. Copy colours.txt → colors.txt
4. Copy localisation.yml → ui-flags_l_english.yml
5. Copy thumbnail.png
6. Generate root descriptor (out/ui-flags.mod)
7. Generate package descriptor (out/ui-flags/descriptor.mod)

**Descriptor Generation:**
```bash
generate-mod-descriptor "${MOD_DESCRIPTOR_PRIMARY_FILE_PATH}"
generate-mod-descriptor "${MOD_DESCRIPTOR_SECONDARY_FILE_PATH}"
```

**Relationship:** Both descriptors are written by the same function, so both carry `path="mod/ui-flags"`; they differ only in location.

### Step 5: Category Discovery & Iteration

**Discovery:**
```bash
for CATEGORY_DIR in "${SOURCE_DIR_PATH}/flags/"*/; do
    CATEGORY_NAME=$(basename "${CATEGORY_DIR}")
```

**Per-Category Setup:**
- Create `build/<category>/map/` and `/small/`
- Create `out/ui-flags/flags/<category>/map/` and `/small/`
- Copy `usage.txt` if present

**Iteration:** Processes categories in filesystem order (alphabetical by directory name).

### Step 6: Per-Asset Processing

**Asset Discovery:**
```bash
for FLAG_FILE in "${CATEGORY_DIR}"*; do
    [ -f "${FLAG_FILE}" ] || continue
```

**Filename Resolution:**
```bash
FILE_NAME="${FILE_BASENAME%.*}"  # Remove extension
FLAG_FILE_NAME=$(get-flag-file-name "${FILE_NAME}")
```

**Output Paths:**
| Variant | Path |
|---------|------|
| Main | `out/ui-flags/flags/<cat>/<name>.dds` |
| Map | `out/ui-flags/flags/<cat>/map/<name>.dds` |
| Small | `out/ui-flags/flags/<cat>/small/<name>.dds` |

**Incremental Check:**
```bash
if [ -f "${MAIN}" ] && [ -f "${MAP}" ] && [ -f "${SMALL}" ]; then
    continue  # Skip to next asset
fi
```

**Build Intermediate Paths:**
| Intermediate | Path |
|--------------|------|
| SVG | `build/<cat>/<source>.svg` |
| Main PNG | `build/<cat>/<source>.png` |
| Map PNG | `build/<cat>/map/<source>.png` |
| Small PNG | `build/<cat>/small/<source>.png` |
| Bevel markers | `build/<cat>/<source>.png.beveled` and the small variant |

### Step 7: Source Format → SVG Conversion

**Conversion Matrix:**

| Source Format | Function | Tools | Intermediate Steps |
|---------------|----------|-------|-------------------|
| `.bmp` | `bmp-to-svg` | potrace | Direct |
| `.png` | `png-to-svg` | magick, potrace | PNG → BMP → SVG |
| `.svg` | `cp` | shell | Direct copy |

**Error Handling:** Unsupported format → warning, continue to next asset.

### Step 8: Rasterisation and Map Export (per flag, in workers)

Each registered flag is handled by a worker bounded by `FLAG_WORKER_COUNT`:

```
SVG (build)
  → svg-to-png (128px main)   → PNG (build, awaiting bevel)
  → svg-to-png (24px small)   → PNG (build, awaiting bevel)
  → svg-to-png (256px map)    → PNG (build)
  → png_to_dds (map)          → DDS (out/map)
```

**GIMP Invocations:** None — the main and small PNGs are rasterised only; the map PNG needs no bevel,
so its DDS is exported immediately.

### Step 9: Batched Bevel (main + small)

After every worker has finished, the unbeveled main and small PNGs are collected and beveled in shared
GIMP sessions:

```
FOR each bevel round (up to VARIANT_ATTEMPT_COUNT):
  collect every registered main/small PNG lacking a .beveled marker
  IF none remain: BREAK
  bevel-pngs round, chunked by FLAG_BEVEL_BATCH_SIZE (FLAG_GIMP_CONCURRENCY at once)
  re-rasterise any PNG a killed session left unusable
```

**GIMP Invocations:** One session per chunk; a killed session leaves its unmarked images for the next round.

### Step 10: Beveled DDS Export

The beveled main and small PNGs are exported only after the rounds, so their textures carry the bevel:

```
build/<cat>/<name>.png       (beveled) → png_to_dds → out/<cat>/<name>.dds
build/<cat>/small/<name>.png (beveled) → png_to_dds → out/<cat>/small/<name>.dds
```

**GIMP Invocations:** None — the export is plain Python.

### Step 11: Completion

**End State:**
- All categories processed
- All assets processed (or skipped via incremental check)
- Unbeveled flags (if any) reported with a diagnosed reason
- Final line: `Produced <n> of <n> flag DDS files.`
- Complete mod package at `out/ui-flags/`
- Root descriptor at `out/ui-flags.mod`

## Control Flow Summary

```
build.sh <version>
    │
    ├─► Validate version
    ├─► Validate source/
    ├─► Resolve tools (magick, rsvg-convert, potrace, python3)
    ├─► Stage static assets (backgrounds, colours, localisation, thumbnail)
    ├─► Generate descriptors
    ├─► FOR each category in source/flags/:
    │       ├─► Create build/ and out/ directories
    │       ├─► Copy usage.txt if exists
    │       ├─► FOR each asset in category:
    │       │       ├─► Resolve output name (names.txt or default)
    │       │       ├─► Check incremental (skip if all 3 DDS exist)
    │       │       ├─► Convert source → SVG
    │       │       ├─► [workers] Rasterise PNGs; export map DDS (no bevel)
    │       │       └─► Register main/small PNG for the bevel rounds
    │       └─► Next asset
    └─► Next category
    │
    ├─► FOR each bevel round: batch unbeveled main/small PNGs through GIMP
    ├─► Export beveled main and small DDS
    └─► Done → out/ui-flags/ ready
```

## Error Propagation

| Stage | Error Handling |
|-------|----------------|
| Argument validation | Exit 1 (`Please specify a version!`) |
| Source validation | Exit 255 (`-1`) |
| Tool detection | Exit 1 per missing start-up tool; GIMP fails only at the first bevel |
| Static staging | `cp` reports errors; a missing thumbnail aborts the build |
| Descriptor generation | Unconditional |
| Category iteration | Skips empty and non-directory entries |
| Asset processing | Continues on failure; the failing worker logs to its own file |
| Format conversion | Unsupported extension → warning, continue |
| Bevel rounds | A killed session leaves images unmarked; they are retried, then reported |
| DDS export | Missing output → error exit 3 from the export helper |

**Design Philosophy:** Fail fast for setup, continue for asset processing to maximise output, then
report any bevels that remained unmarked.

## Performance Characteristics

| Phase | Time (Typical) | Parallelism |
|-------|----------------|-------------|
| Setup (steps 1-4) | <1s | None |
| Rasterise + map export per asset | <1s | `FLAG_WORKER_COUNT` workers |
| Batched bevels | ~1s per image plus one session start per batch | `FLAG_GIMP_CONCURRENCY` sessions |
| Beveled DDS export | Milliseconds per flag | `FLAG_WORKER_COUNT` workers |
| Full build (378 assets) | Dominated by the bevel session count | Bounded |

**Bottleneck:** The GIMP session start, amortised over `FLAG_BEVEL_BATCH_SIZE` images per session.
The rasterisation and DDS export use plain tools and are effectively free.

## Incremental Build Behaviour

**Trigger:** Re-run `build.sh` without cleaning `build/` and `out/`

**Logic:** Per-asset check for all three output DDS files.

**Skip Condition:** All three exist → `continue` (skip entire asset processing).

**Limitations:**
- Does NOT detect source file modification
- Does NOT detect script/configuration changes
- Does NOT detect tool version changes

**Workaround for Changes:** `rm -rf build out` before rebuild.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Start-up validation failure (version argument, ImageMagick, potrace, Python 3, rsvg-convert) |
| 2 | Invalid arguments passed to `execute-gimp-script-file` |
| 3 | A conversion/export helper failed to produce its output |
| 255 (`-1`) | `source/` directory missing |

Individual asset failures do not affect the exit code; the final line reports the produced flag DDS
count against the expected count.