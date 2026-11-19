# Build Pipeline Component

## Overview

The build pipeline is implemented entirely in `build.sh` — a single bash script that orchestrates the complete conversion of source assets to a Stellaris-compatible mod package. It follows a **declarative, stage-based architecture** where each stage has a single responsibility.

## Script Structure

```
build.sh
├── Configuration Constants
├── Path Definitions
├── Tool Detection
├── Utility Functions
├── Conversion Functions
├── Main Execution Loop
└── Descriptor Generation
```

## Configuration Constants

```bash
MOD_ID="ui-flags"
MOD_NAME="Universum Infinitum: Flags"
MOD_VERSION="${1}"           # Required command-line argument
STELLARIS_VERSION="v4.5.*"   # Supported game version pattern
```

## Path Definitions

```bash
SOURCE_DIR_PATH="source"
BUILD_DIR_PATH="build"
OUT_DIR_PATH="out"
MOD_OUT_DIR_PATH="${OUT_DIR_PATH}/${MOD_ID}"
```

Derived paths constructed dynamically during execution.

## Tool Detection

### Detection Order

For each tool, the script checks in priority order:

1. **System path** (e.g., `/usr/bin/inkscape`)
2. **Flatpak system export** (e.g., `/var/lib/flatpak/exports/bin/org.inkscape.Inkscape`)
3. **Flatpak user export** (e.g., `~/.local/share/flatpak/exports/bin/org.inkscape.Inkscape`)

### Tools Detected

| Variable | Tool | Purpose |
|----------|------|---------|
| `CONVERT_TOOL_PATH` | ImageMagick `convert` | PNG ↔ BMP, image manipulation |
| `POTRACE_TOOL_PATH` | `potrace` | Raster → vector tracing |
| `INKSCAPE_TOOL_PATH` | Inkscape | SVG rendering, AI → SVG |
| `GIMP_TOOL_PATH` | GIMP | Python-Fu batch execution, XCF → PNG, DDS export |

### Detection Function Pattern

```bash
TOOL_TOOL_PATH="$(which tool 2>/dev/null || \
    [ -f "/var/lib/flatpak/exports/bin/org.tool.Tool" ] && \
    echo "/var/lib/flatpak/exports/bin/org.tool.Tool" || \
    [ -f "${HOME}/.local/share/flatpak/exports/bin/org.tool.Tool" ] && \
    echo "${HOME}/.local/share/flatpak/exports/bin/org.tool.Tool")"
```

### Validation

```bash
if [ ! -f "${TOOL_TOOL_PATH}" ]; then
    echo "Tool is not installed"
    exit 1
fi
```

## Utility Functions

### `get-flag-file-name`

Resolves output filename from source filename using `names.txt` mapping.

```bash
get-flag-file-name() {
    local FLAG_NAMES_FILE_PATH="${1}"
    local SOURCE_FILE_NAME="${2}"
    local FILE_PREFIX="ui_"
    local FLAG_FILE_NAME

    FLAG_FILE_NAME=$(grep "^${SOURCE_FILE_NAME}=" "${FLAG_NAMES_FILE_PATH}" | awk -F= '{print $2}')
    if [ -z "${FLAG_FILE_NAME}" ]; then
        echo "${FILE_PREFIX}${SOURCE_FILE_NAME}"
    else
        echo "${FLAG_FILE_NAME}"
    fi
}
```

**Inputs:** names.txt path, source filename (without extension)
**Output:** Output filename (without extension)

### `generate-mod-descriptor`

Creates `.mod` descriptor files for Stellaris.

```bash
generate-mod-descriptor() {
    local MOD_DESCRIPTOR_PATH="${1}"
    local MOD_DESCRIPTOR_PATH_VALUE="${2}"

    cat > "${MOD_DESCRIPTOR_PATH}" <<EOF
name="${MOD_NAME}"
path="${MOD_DESCRIPTOR_PATH_VALUE}"
supported_version="${STELLARIS_VERSION}"
tags={
    "Graphics"
}
picture="thumbnail.png"
EOF
}
```

**Inputs:** Output path, path value for descriptor
**Output:** Writes descriptor file

## Conversion Functions

### `bmp-to-svg`

Converts BMP to SVG via potrace.

```bash
bmp-to-svg() {
    local INPUT_FILE_PATH="${1}"
    local OUTPUT_FILE_PATH="${2}"
    "${POTRACE_TOOL_PATH}" "${INPUT_FILE_PATH}" -s -o "${OUTPUT_FILE_PATH}"
}
```

**Path:** BMP → SVG
**Tool:** potrace with `-s` (SVG output)

### `png-to-svg`

Converts PNG to SVG via BMP intermediate.

```bash
png-to-svg() {
    local INPUT_FILE_PATH="${1}"
    local OUTPUT_FILE_PATH="${2}"
    local TEMP_BMP_FILE_PATH="${OUTPUT_FILE_PATH}.bmp"
    "${CONVERT_TOOL_PATH}" "${INPUT_FILE_PATH}" "${TEMP_BMP_FILE_PATH}"
    bmp-to-svg "${TEMP_BMP_FILE_PATH}" "${OUTPUT_FILE_PATH}"
    rm -f "${TEMP_BMP_FILE_PATH}"
}
```

**Path:** PNG → BMP → SVG
**Tools:** ImageMagick convert, potrace

### `xcf-to-svg`

Converts XCF (GIMP) to SVG via PNG → BMP intermediates.

```bash
xcf-to-svg() {
    local INPUT_FILE_PATH="${1}"
    local OUTPUT_FILE_PATH="${2}"
    local TEMP_PNG_FILE_PATH="${OUTPUT_FILE_PATH}.png"
    local TEMP_BMP_FILE_PATH="${OUTPUT_FILE_PATH}.bmp"
    xcf-to-png "${INPUT_FILE_PATH}" "${TEMP_PNG_FILE_PATH}"
    "${CONVERT_TOOL_PATH}" "${TEMP_PNG_FILE_PATH}" "${TEMP_BMP_FILE_PATH}"
    bmp-to-svg "${TEMP_BMP_FILE_PATH}" "${OUTPUT_FILE_PATH}"
    rm -f "${TEMP_PNG_FILE_PATH}" "${TEMP_BMP_FILE_PATH}"
}
```

**Path:** XCF → PNG → BMP → SVG
**Tools:** GIMP (xcf_to_png), ImageMagick, potrace

### `ai-to-svg`

Converts Adobe Illustrator AI to SVG via Inkscape.

```bash
ai-to-svg() {
    local INPUT_FILE_PATH="${1}"
    local OUTPUT_FILE_PATH="${2}"
    "${INKSCAPE_TOOL_PATH}" "${INPUT_FILE_PATH}" --export-type=svg --export-filename="${OUTPUT_FILE_PATH}"
}
```

**Path:** AI → SVG
**Tool:** Inkscape CLI

### `svg-to-png`

Renders SVG to PNG at specified size with `rsvg-convert` and ImageMagick.

```bash
svg-to-png <input_file_path> <output_file_path> <output_image_size>
```

```bash
rsvg-convert -w "${OUTPUT_IMAGE_SIZE}" -h "${OUTPUT_IMAGE_SIZE}" -b white \
    -o "${RAW_PNG_PATH}" "${INPUT_IMAGE_PATH}"
magick "${RAW_PNG_PATH}" \( +clone -fill "${BACKGROUND_COLOUR}" -colorize 100 \) \
    -compose Difference -composite -colorspace Gray "${RAW_PNG_PATH}.alpha.png"
magick -size "${OUTPUT_IMAGE_SIZE}x${OUTPUT_IMAGE_SIZE}" xc:white \
    "${RAW_PNG_PATH}.alpha.png" -alpha off -compose CopyOpacity -composite \
    -type TrueColorAlpha -define png:color-type=6 "${OUTPUT_IMAGE_PATH}"
```

**Path:** SVG → PNG
**Tool:** `rsvg-convert` and ImageMagick; no GIMP session is required
**Parameter:** Output image size (pixels)

### `png-to-dds`

Exports PNG to DDS with a plain Python writer.

```bash
png-to-dds <input_file_path> <output_file_path>
```

```bash
"${PYTHON_BINARY}" "${SOURCE_SCRIPTS_DIR_PATH}/png_to_dds.py" \
    "GIMP_SCRIPT_INPUT_IMAGE_PATH=${INPUT_IMAGE_PATH}" \
    "GIMP_SCRIPT_OUTPUT_IMAGE_PATH=${OUTPUT_IMAGE_PATH}"
```

**Path:** PNG → DDS
**Tool:** Python 3 with `png_to_dds.py`; the uncompressed format needs no GIMP session

### `bevel-pngs`

Applies the gradient bevel to a list of PNGs, batching them into shared GIMP sessions.

```bash
bevel-pngs <round_name> <png_path>...
```

```bash
execute-gimp-script-file "bevel_batch" IMAGE_PATHS "$(printf '%s\n' "$@")"
```

**Path:** PNG → PNG (with bevel), rewritten in place
**Tool:** GIMP with `bevel_batch.py` script

### `xcf-to-png`

Exports XCF to PNG using GIMP Python-Fu.

```bash
xcf-to-png <input_file_path> <output_file_path>
```

```bash
execute-gimp-script-file "xcf_to_png" \
    INPUT_IMAGE_PATH "${INPUT_IMAGE_PATH}" \
    OUTPUT_IMAGE_PATH "${OUTPUT_IMAGE_PATH}"
```

**Path:** XCF → PNG
**Tool:** GIMP with `xcf_to_png.py` script

## Main Execution Loop

### Initialisation

```bash
# Validate version argument
if [ -z "${MOD_VERSION}" ]; then
    echo "Usage: ./build.sh <version>"
    exit 1
fi

# Validate source directory
if [ ! -d "${SOURCE_DIR_PATH}" ]; then
    echo "MISSING SOURCE DIRECTORY"
    exit 1
fi

# Validate tools
# ... tool detection and validation ...
```

### Static Asset Staging

```bash
# Create output directories
mkdir -p "${MOD_OUT_DIR_PATH}/flags/backgrounds"
mkdir -p "${MOD_OUT_DIR_PATH}/localisation"

# Copy backgrounds
cp -r "${SOURCE_DIR_PATH}/backgrounds/"* "${MOD_OUT_DIR_PATH}/flags/backgrounds/"

# Copy colours.txt
cp "${SOURCE_DIR_PATH}/colours.txt" "${MOD_OUT_DIR_PATH}/flags/colors.txt"

# Copy localisation
cp "${SOURCE_DIR_PATH}/localisation.yml" "${MOD_OUT_DIR_PATH}/localisation/ui-flags_l_english.yml"

# Copy thumbnail
cp "${SOURCE_DIR_PATH}/thumbnail.png" "${MOD_OUT_DIR_PATH}/thumbnail.png"

# Generate descriptors
generate-mod-descriptor "${OUT_DIR_PATH}/${MOD_ID}.mod" "mod/${MOD_ID}"
generate-mod-descriptor "${MOD_OUT_DIR_PATH}/descriptor.mod" "."
```

### Category Iteration

```bash
for CATEGORY_DIR in "${SOURCE_DIR_PATH}/flags/"*/; do
    CATEGORY_NAME=$(basename "${CATEGORY_DIR}")

    # Create build directories
    mkdir -p "${BUILD_DIR_PATH}/${CATEGORY_NAME}/map"
    mkdir -p "${BUILD_DIR_PATH}/${CATEGORY_NAME}/small"

    # Create output directories
    mkdir -p "${MOD_OUT_DIR_PATH}/flags/${CATEGORY_NAME}/map"
    mkdir -p "${MOD_OUT_DIR_PATH}/flags/${CATEGORY_NAME}/small"

    # Copy usage.txt if present
    if [ -f "${CATEGORY_DIR}/usage.txt" ]; then
        cp "${CATEGORY_DIR}/usage.txt" "${MOD_OUT_DIR_PATH}/flags/${CATEGORY_NAME}/usage.txt"
    fi

    # Process each asset file
    for FLAG_FILE in "${CATEGORY_DIR}"*; do
        # ... asset processing ...
    done
done
```

### Per-Asset Processing

```bash
for FLAG_FILE in "${CATEGORY_DIR}"*; do
    [ -f "${FLAG_FILE}" ] || continue

    # Extract filename without extension
    FLAG_FILE_NAME=$(basename "${FLAG_FILE}")
    SOURCE_FILE_NAME="${FLAG_FILE_NAME%.*}"

    # Resolve output filename
    FLAG_OUTPUT_FILE_NAME=$(get-flag-file-name "${SOURCE_DIR_PATH}/names.txt" "${SOURCE_FILE_NAME}")

    # Define output paths
    FLAG_OUTPUT_MAIN_FILE_PATH="${MOD_OUT_DIR_PATH}/flags/${CATEGORY_NAME}/${FLAG_OUTPUT_FILE_NAME}.dds"
    FLAG_OUTPUT_MAP_FILE_PATH="${MOD_OUT_DIR_PATH}/flags/${CATEGORY_NAME}/map/${FLAG_OUTPUT_FILE_NAME}.dds"
    FLAG_OUTPUT_SMALL_FILE_PATH="${MOD_OUT_DIR_PATH}/flags/${CATEGORY_NAME}/small/${FLAG_OUTPUT_FILE_NAME}.dds"

    # Incremental build check
    if [ -f "${FLAG_OUTPUT_MAIN_FILE_PATH}" ] && \
       [ -f "${FLAG_OUTPUT_MAP_FILE_PATH}" ] && \
       [ -f "${FLAG_OUTPUT_SMALL_FILE_PATH}" ]; then
        continue
    fi

    # Define build intermediate paths
    FLAG_BUILD_SVG_FILE_PATH="${BUILD_DIR_PATH}/${CATEGORY_NAME}/${SOURCE_FILE_NAME}.svg"
    FLAG_BUILD_MAIN_PNG_FILE_PATH="${BUILD_DIR_PATH}/${CATEGORY_NAME}/${SOURCE_FILE_NAME}.png"
    FLAG_BUILD_MAP_PNG_FILE_PATH="${BUILD_DIR_PATH}/${CATEGORY_NAME}/map/${SOURCE_FILE_NAME}.png"
    FLAG_BUILD_SMALL_PNG_FILE_PATH="${BUILD_DIR_PATH}/${CATEGORY_NAME}/small/${SOURCE_FILE_NAME}.png"
    FLAG_BUILD_MAIN_BEVEL_PNG_FILE_PATH="${BUILD_DIR_PATH}/${CATEGORY_NAME}/${SOURCE_FILE_NAME}_bevel.png"
    FLAG_BUILD_SMALL_BEVEL_PNG_FILE_PATH="${BUILD_DIR_PATH}/${CATEGORY_NAME}/small/${SOURCE_FILE_NAME}_bevel.png"

    # Convert source format to SVG
    source-to-svg "${FLAG_FILE}" "${FLAG_BUILD_SVG_FILE_PATH}"

    # Register the flag so the bevels can be batched after the parallel rasterisation
    FLAG_KEYS+=("${CATEGORY_NAME}/${SOURCE_FILE_NAME}")
    FLAG_MAIN_PNG_PATHS[${FLAG_KEY}]="${FLAG_BUILD_MAIN_PNG_FILE_PATH}"
    FLAG_SMALL_PNG_PATHS[${FLAG_KEY}]="${FLAG_BUILD_SMALL_PNG_FILE_PATH}"
    # ... map and DDS paths are registered the same way ...

done
```

The per-asset worker rasterises the main, map and small PNGs and exports all three DDS files:

```bash
(
    FLAG_LOG_PATH="${BUILD_DIR_PATH}/${CATEGORY_NAME}-${SOURCE_FILE_NAME}.log"

    (
        is-beveled-png "${FLAG_BUILD_MAIN_PNG_FILE_PATH}" || rasterise-bevel-png "${FLAG_BUILD_MAIN_PNG_FILE_PATH}"
        is-beveled-png "${FLAG_BUILD_SMALL_PNG_FILE_PATH}" || rasterise-bevel-png "${FLAG_BUILD_SMALL_PNG_FILE_PATH}"

        if ! is-usable-png "${FLAG_BUILD_MAP_PNG_FILE_PATH}"; then
            svg-to-png "${FLAG_BUILD_SVG_FILE_PATH}" "${FLAG_BUILD_MAP_PNG_FILE_PATH}" "256"
        fi

        # The map needs no bevel, so its DDS is exported now.
        export-map-dds "${FLAG_BUILD_MAP_PNG_FILE_PATH}" "${FLAG_OUTPUT_MAP_FILE_PATH}"
    ) > "${FLAG_LOG_PATH}" 2>&1
) &
```

Once every worker has finished, the bevels are batched into shared GIMP sessions, and the rounds
retry whichever images a killed session left unmarked:

```bash
for BEVEL_ROUND_NUMBER in $(seq 1 "${VARIANT_ATTEMPT_COUNT}"); do
    collect-unbeveled-pngs
    [ "${#FLAG_BEVEL_PATHS[@]}" -eq 0 ] && break

    bevel-pngs "${BEVEL_ROUND_NUMBER}" "${FLAG_BEVEL_PATHS[@]}"
done
```

The beveled main and small PNGs are exported only after the rounds, so their DDS textures carry the
bevel:

```bash
for FLAG_KEY in "${FLAG_KEYS[@]}"; do
    while [ "$(jobs -rp | wc -l)" -ge "${FLAG_WORKER_COUNT}" ]; do
        wait -n
    done

    (
        export-beveled-dds \
            "${FLAG_MAIN_PNG_PATHS[${FLAG_KEY}]}" "${FLAG_MAIN_DDS_PATHS[${FLAG_KEY}]}" \
            "${FLAG_SMALL_PNG_PATHS[${FLAG_KEY}]}" "${FLAG_SMALL_DDS_PATHS[${FLAG_KEY}]}"
    ) > "${BUILD_DIR_PATH}/${FLAG_KEY//\//-}.export.log" 2>&1 &
done
```

## Conversion Flow Summary

```
SOURCE FORMAT          CONVERSION PATH                              OUTPUTS
─────────────────────────────────────────────────────────────────────────────
.svg                   copy → SVG                                   → 128, 256, 24 PNG
.png                   PNG → BMP → SVG                              → 128, 256, 24 PNG
.xcf                   XCF → PNG → BMP → SVG                        → 128, 256, 24 PNG
.ai                    AI → SVG                                     → 128, 256, 24 PNG
.bmp                   BMP → SVG                                    → 128, 256, 24 PNG

ALL FORMATS THEN:
  128px PNG → rasterise → gradient bevel → DDS (main flag)
  256px PNG → rasterise → DDS (map flag, NO bevel)
  24px PNG  → rasterise → gradient bevel → DDS (small flag)

EXPORT ORDER:
  map DDS is exported by the worker, because it needs no bevel
  main and small DDS are exported after the bevel rounds, from the beveled PNGs
```

## Incremental Build Logic

The pipeline skips assets where all three output DDS files already exist:

```bash
if [ -f "${FLAG_OUTPUT_MAIN_FILE_PATH}" ] && \
   [ -f "${FLAG_OUTPUT_MAP_FILE_PATH}" ] && \
   [ -f "${FLAG_OUTPUT_SMALL_FILE_PATH}" ]; then
    continue
fi
```

**Benefits:**
- Fast re-builds when adding new assets
- Preserves previously processed assets
- No cache invalidation needed

**Limitations:**
- Does not detect source file changes
- Does not detect script/configuration changes
- Manual clean required for full rebuild: `rm -rf build out`

## Error Handling

### Tool Validation

All tools validated at startup — fail fast if missing.

### Conversion Errors

Individual asset failures are logged per worker but do not halt the rasterisation and export stage:

```bash
source-to-svg "${FLAG_FILE}" "${FLAG_BUILD_SVG_FILE_PATH}"
...
export-map-dds "${FLAG_BUILD_MAP_PNG_FILE_PATH}" "${FLAG_OUTPUT_MAP_FILE_PATH}"
```

A bevel failure does not stop the batch, because an unmarked image is retried over the remaining
rounds. A flag whose bevels are still missing once the rounds are exhausted is reported at the end
of the build.

### Output Verification

The DDS export is verified by the existence of every expected file, and the bevels are verified by
a completion marker written only after each bevel has been saved.

## Performance Characteristics

| Aspect | Characteristic |
|--------|----------------|
| Parallelism | `FLAG_WORKER_COUNT` workers for rasterisation and export, `FLAG_GIMP_CONCURRENCY` GIMP sessions for the batched bevels |
| Tool startup | Per session for GIMP (`FLAG_BEVEL_BATCH_SIZE` flags per start), per file for the plain tools |
| Incremental | File-existence based, bevels cached per variant |
| Typical full build | Dominated by the number of bevel sessions |
| Typical incremental | Seconds when only new assets are added |
| Memory usage | Bounded by the batch size each GIMP session holds |
| Disk usage | ~2-3x source size (intermediates) |

## Extension Points

### Adding New Source Formats

1. Add a branch to `source-to-svg` (e.g., `webp) webp-to-svg ... ;;`)
2. Ensure the branch produces SVG at `FLAG_BUILD_SVG_FILE_PATH`

### Adding New Output Resolutions

1. Add `svg-to-png` call with new size
2. Add `png-to-dds` call for new output path
3. Create output directory in category iteration

### Modifying Bevel Parameters

Edit `source/scripts/gradient_bevel.py` — no `build.sh` changes needed.

### Tuning the Bevel Batching

Change `FLAG_BEVEL_BATCH_SIZE` (flags per GIMP session) or `FLAG_GIMP_CONCURRENCY` (sessions at
once) — no script changes needed.

### Changing Output Naming

Modify `FILE_PREFIX` in `get-flag-file-name` or add entries to `names.txt`.