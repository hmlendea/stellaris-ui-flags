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
│    ├── FOR each tool in [convert, potrace, inkscape, gimp]:                │
│    │   ├── CHECK system PATH                                                │
│    │   ├── CHECK Flatpak system export                                      │
│    │   ├── CHECK Flatpak user export                                        │
│    │   ├── IF not found: PRINT "X is not installed", EXIT 1                │
│    │   └── STORE path in TOOL_TOOL_PATH                                     │
│    └── ALL tools found: CONTINUE                                            │
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
│    ├── GLOB source/flags/*/ → category directories                          │
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
│    │   ├── RENDER & BEVEL (steps 8-10)                                      │
│    │   └── LOOP to next asset                                               │
│    └── ALL assets processed: CONTINUE to next category                      │
└─────────────────────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 7. SOURCE FORMAT → SVG CONVERSION                                           │
│    ├── SWITCH on file extension:                                            │
│    │   ├── .bmp  → bmp-to-svg()  (potrace)                                  │
│    │   ├── .png  → png-to-svg()  (convert → potrace)                       │
│    │   ├── .xcf  → xcf-to-svg()  (gimp → convert → potrace)                │
│    │   ├── .ai   → ai-to-svg()   (inkscape)                                 │
│    │   ├── .svg  → COPY to build SVG                                        │
│    │   └── DEFAULT → PRINT "Unsupported format", CONTINUE                  │
│    └── OUTPUT: build/<category>/<source_name>.svg                          │
└─────────────────────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 8. SVG → 128px PNG (MAIN) + BEVEL                                           │
│    ├── svg-to-png(build SVG, build MAIN PNG, 128)                          │
│    │   └── GIMP: load SVG, scale to 128x128, remove background, save PNG   │
│    ├── apply-gradient-bevel(build MAIN PNG, build MAIN BEVEL PNG)          │
│    │   └── GIMP: load PNG, create layers, bump-map, gradient, merge, save  │
│    ├── png-to-dds(build MAIN BEVEL PNG, out MAIN DDS)                      │
│    │   └── GIMP: load PNG, save as DDS (DXT1/5, mipmaps)                  │
│    └── OUTPUT: out/ui-flags/flags/<cat>/<name>.dds (128px, beveled)        │
└─────────────────────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 9. SVG → 256px PNG (MAP) — NO BEVEL                                         │
│    ├── svg-to-png(build SVG, build MAP PNG, 256)                           │
│    │   └── GIMP: load SVG, scale to 256x256, remove background, save PNG   │
│    ├── png-to-dds(build MAP PNG, out MAP DDS)                              │
│    │   └── GIMP: load PNG, save as DDS (DXT1/5, mipmaps)                  │
│    └── OUTPUT: out/ui-flags/flags/<cat>/map/<name>.dds (256px, no bevel)   │
└─────────────────────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 10. SVG → 24px PNG (SMALL) + BEVEL                                          │
│    ├── svg-to-png(build SVG, build SMALL PNG, 24)                          │
│    │   └── GIMP: load SVG, scale to 24x24, remove background, save PNG     │
│    ├── apply-gradient-bevel(build SMALL PNG, build SMALL BEVEL PNG)        │
│    │   └── GIMP: load PNG, create layers, bump-map, gradient, merge, save  │
│    ├── png-to-dds(build SMALL BEVEL PNG, out SMALL DDS)                    │
│    │   └── GIMP: load PNG, save as DDS (DXT1/5, mipmaps)                  │
│    └── OUTPUT: out/ui-flags/flags/<cat>/small/<name>.dds (24px, beveled)   │
└─────────────────────────────────────────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 11. COMPLETION                                                              │
│    ├── All categories processed                                             │
│    ├── All assets processed                                                 │
│    ├── Output package ready at out/ui-flags/                                │
│    └── EXIT 0                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Detailed Step Descriptions

### Step 1: Argument Validation

**Trigger:** Script invocation `./build.sh <version>`

**Logic:**
```bash
MOD_VERSION="${1}"
if [ -z "${MOD_VERSION}" ]; then
    echo "Usage: ./build.sh <version>"
    exit 1
fi
```

**Failure Mode:** Missing argument → immediate exit with usage message.

**Success:** `MOD_VERSION` set, proceed to step 2.

### Step 2: Source Directory Validation

**Logic:**
```bash
if [ ! -d "${SOURCE_DIR_PATH}" ]; then
    echo "MISSING SOURCE DIRECTORY"
    exit 1
fi
```

**Failure Mode:** `source/` not found → exit. Usually means wrong working directory.

**Success:** Source directory confirmed, proceed to step 3.

### Step 3: Tool Detection & Validation

**Detection Order (per tool):**
1. `which tool` — system PATH
2. `/var/lib/flatpak/exports/bin/org.tool.Tool` — Flatpak system
3. `~/.local/share/flatpak/exports/bin/org.tool.Tool` — Flatpak user

**Tools Checked:**
| Tool | Command | Flatpak ID |
|------|---------|------------|
| ImageMagick | `convert` | N/A |
| potrace | `potrace` | N/A |
| Inkscape | `inkscape` | `org.inkscape.Inkscape` |
| GIMP | `gimp` | `org.gimp.GIMP` |

**Failure Mode:** Any tool missing → print message, exit 1.

**Success:** All tool paths stored in variables, proceed to step 4.

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
generate-mod-descriptor "${OUT_DIR_PATH}/${MOD_ID}.mod" "mod/${MOD_ID}"
generate-mod-descriptor "${MOD_OUT_DIR_PATH}/descriptor.mod" "."
```

**Key Difference:** Root descriptor has `path="mod/ui-flags"`, package descriptor has `path="."`.

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
SOURCE_FILE_NAME="${FLAG_FILE_NAME%.*}"  # Remove extension
FLAG_OUTPUT_FILE_NAME=$(get-flag-file-name "${SOURCE_DIR_PATH}/names.txt" "${SOURCE_FILE_NAME}")
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
| Main Bevel PNG | `build/<cat>/<source>_bevel.png` |
| Small Bevel PNG | `build/<cat>/small/<source>_bevel.png` |

### Step 7: Source Format → SVG Conversion

**Conversion Matrix:**

| Source Format | Function | Tools | Intermediate Steps |
|---------------|----------|-------|-------------------|
| `.bmp` | `bmp-to-svg` | potrace | Direct |
| `.png` | `png-to-svg` | convert, potrace | PNG → BMP → SVG |
| `.xcf` | `xcf-to-svg` | GIMP, convert, potrace | XCF → PNG → BMP → SVG |
| `.ai` | `ai-to-svg` | Inkscape | Direct |
| `.svg` | `cp` | shell | Direct copy |

**Error Handling:** Unsupported format → warning, continue to next asset.

### Step 8: Main Flag (128px) with Bevel

**Pipeline:**
```
SVG (build)
  → svg-to-png (128px)
  → PNG (build)
  → apply-gradient-bevel
  → PNG Bevel (build)
  → png-to-dds
  → DDS (out/main)
```

**GIMP Invocations:** 3 separate GIMP processes (one per script call).

### Step 9: Map Flag (256px) without Bevel

**Pipeline:**
```
SVG (build)
  → svg-to-png (256px)
  → PNG (build)
  → png-to-dds
  → DDS (out/map)
```

**GIMP Invocations:** 2 separate GIMP processes.

**Key Difference:** No bevel applied — map flags use flat rendering.

### Step 10: Small Flag (24px) with Bevel

**Pipeline:**
```
SVG (build)
  → svg-to-png (24px)
  → PNG (build)
  → apply-gradient-bevel
  → PNG Bevel (build)
  → png-to-dds
  → DDS (out/small)
```

**GIMP Invocations:** 3 separate GIMP processes.

### Step 11: Completion

**End State:**
- All categories processed
- All assets processed (or skipped via incremental check)
- Complete mod package at `out/ui-flags/`
- Root descriptor at `out/ui-flags.mod`
- Exit code 0

## Control Flow Summary

```
build.sh <version>
    │
    ├─► Validate version
    ├─► Validate source/
    ├─► Detect tools (convert, potrace, inkscape, gimp)
    ├─► Stage static assets (backgrounds, colours, localisation, thumbnail)
    ├─► Generate descriptors
    ├─► FOR each category in source/flags/:
    │       ├─► Create build/ and out/ directories
    │       ├─► Copy usage.txt if exists
    │       ├─► FOR each asset in category:
    │       │       ├─► Resolve output name (names.txt or default)
    │       │       ├─► Check incremental (skip if all 3 DDS exist)
    │       │       ├─► Convert source → SVG
    │       │       ├─► SVG → 128px PNG → bevel → DDS (main)
    │       │       ├─► SVG → 256px PNG → DDS (map, no bevel)
    │       │       └─► SVG → 24px PNG → bevel → DDS (small)
    │       └─► Next asset
    └─► Next category
    │
    └─► Done → out/ui-flags/ ready
```

## Error Propagation

| Stage | Error Handling |
|-------|----------------|
| Argument validation | Exit 1 |
| Source validation | Exit 1 |
| Tool detection | Exit 1 |
| Static staging | Continue (cp fails silently if source missing) |
| Descriptor generation | Continue |
| Category iteration | Continue on category error |
| Asset processing | Continue on asset error (warning printed) |
| Format conversion | Continue on conversion error |
| GIMP operations | Continue on GIMP error (non-zero exit ignored) |

**Design Philosophy:** Fail fast for setup, continue for asset processing to maximise output.

## Performance Characteristics

| Phase | Time (Typical) | Parallelism |
|-------|----------------|-------------|
| Setup (steps 1-4) | <1s | None |
| Per asset (steps 7-10) | 1-4s | None (sequential) |
| Full build (300+ assets) | 5-15 min | None |
| Incremental (1 new asset) | <30s | None |

**Bottleneck:** GIMP startup per script invocation (~0.5-1s each, 8 invocations per asset = 4-8s overhead per asset).

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
| 1 | Validation failure (argument, source, tools) |
| >1 | Not used (script doesn't exit with other codes) |

Individual asset failures don't affect exit code.