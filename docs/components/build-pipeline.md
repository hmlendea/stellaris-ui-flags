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
| `GIMP_TOOL_PATH` | GIMP | Script-fu execution, XCF → PNG, DDS export |

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
**Tools:** GIMP (xcf-to-png), ImageMagick, potrace

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

Renders SVG to PNG at specified size using GIMP Script-fu.

```bash
svg-to-png() {
    local INPUT_FILE_PATH="${1}"
    local OUTPUT_FILE_PATH="${2}"
    local OUTPUT_IMAGE_SIZE="${3}"
    "${GIMP_TOOL_PATH}" -i -b "(svg-to-png \"${INPUT_FILE_PATH}\" \"${OUTPUT_FILE_PATH}\" ${OUTPUT_IMAGE_SIZE})" -b "(gimp-quit 0)"
}
```

**Path:** SVG → PNG
**Tool:** GIMP with `svg-to-png.lisp` script
**Parameter:** Output image size (pixels)

### `png-to-dds`

Exports PNG to DDS using GIMP Script-fu.

```bash
png-to-dds() {
    local INPUT_FILE_PATH="${1}"
    local OUTPUT_FILE_PATH="${2}"
    "${GIMP_TOOL_PATH}" -i -b "(png-to-dds \"${INPUT_FILE_PATH}\" \"${OUTPUT_FILE_PATH}\")" -b "(gimp-quit 0)"
}
```

**Path:** PNG → DDS
**Tool:** GIMP with `png-to-dds.lisp` script

### `apply-gradient-bevel`

Applies gradient bevel effect to PNG using GIMP Script-fu.

```bash
apply-gradient-bevel() {
    local INPUT_FILE_PATH="${1}"
    local OUTPUT_FILE_PATH="${2}"
    "${GIMP_TOOL_PATH}" -i -b "(gradient-bevel \"${INPUT_FILE_PATH}\" \"${OUTPUT_FILE_PATH}\")" -b "(gimp-quit 0)"
}
```

**Path:** PNG → PNG (with bevel)
**Tool:** GIMP with `gradient-bevel.lisp` script

### `xcf-to-png`

Exports XCF to PNG using GIMP Script-fu.

```bash
xcf-to-png() {
    local INPUT_FILE_PATH="${1}"
    local OUTPUT_FILE_PATH="${2}"
    "${GIMP_TOOL_PATH}" -i -b "(xcf-to-png \"${INPUT_FILE_PATH}\" \"${OUTPUT_FILE_PATH}\")" -b "(gimp-quit 0)"
}
```

**Path:** XCF → PNG
**Tool:** GIMP with `xcf-to-png.lisp` script

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
    case "${FLAG_FILE}" in
        *.bmp)  bmp-to-svg  "${FLAG_FILE}" "${FLAG_BUILD_SVG_FILE_PATH}" ;;
        *.png)  png-to-svg  "${FLAG_FILE}" "${FLAG_BUILD_SVG_FILE_PATH}" ;;
        *.xcf)  xcf-to-svg  "${FLAG_FILE}" "${FLAG_BUILD_SVG_FILE_PATH}" ;;
        *.ai)   ai-to-svg   "${FLAG_FILE}" "${FLAG_BUILD_SVG_FILE_PATH}" ;;
        *.svg)  cp "${FLAG_FILE}" "${FLAG_BUILD_SVG_FILE_PATH}" ;;
        *)      echo "Unsupported format: ${FLAG_FILE}"; continue ;;
    esac

    # Render SVG → 128px PNG (main)
    svg-to-png "${FLAG_BUILD_SVG_FILE_PATH}" "${FLAG_BUILD_MAIN_PNG_FILE_PATH}" 128

    # Apply gradient bevel to main
    apply-gradient-bevel "${FLAG_BUILD_MAIN_PNG_FILE_PATH}" "${FLAG_BUILD_MAIN_BEVEL_PNG_FILE_PATH}"

    # Export main PNG → DDS
    png-to-dds "${FLAG_BUILD_MAIN_BEVEL_PNG_FILE_PATH}" "${FLAG_OUTPUT_MAIN_FILE_PATH}"

    # Render SVG → 256px PNG (map)
    svg-to-png "${FLAG_BUILD_SVG_FILE_PATH}" "${FLAG_BUILD_MAP_PNG_FILE_PATH}" 256

    # Export map PNG → DDS (no bevel)
    png-to-dds "${FLAG_BUILD_MAP_PNG_FILE_PATH}" "${FLAG_OUTPUT_MAP_FILE_PATH}"

    # Render SVG → 24px PNG (small)
    svg-to-png "${FLAG_BUILD_SVG_FILE_PATH}" "${FLAG_BUILD_SMALL_PNG_FILE_PATH}" 24

    # Apply gradient bevel to small
    apply-gradient-bevel "${FLAG_BUILD_SMALL_PNG_FILE_PATH}" "${FLAG_BUILD_SMALL_BEVEL_PNG_FILE_PATH}"

    # Export small PNG → DDS
    png-to-dds "${FLAG_BUILD_SMALL_BEVEL_PNG_FILE_PATH}" "${FLAG_OUTPUT_SMALL_FILE_PATH}"
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
  128px PNG → gradient bevel → DDS (main flag)
  256px PNG → DDS (map flag, NO bevel)
  24px PNG  → gradient bevel → DDS (small flag)
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

Individual asset failures logged but don't halt pipeline:

```bash
case "${FLAG_FILE}" in
    *.bmp)  bmp-to-svg  ... || { echo "Failed: ${FLAG_FILE}"; continue; } ;;
    # ...
esac
```

### Output Verification

No explicit verification of DDS output validity — relies on GIMP DDS plug-in.

## Performance Characteristics

| Aspect | Characteristic |
|--------|----------------|
| Parallelism | None (sequential) |
| Tool startup | Per-asset (GIMP/Inkscape invoked per file) |
| Incremental | File-existence based |
| Typical full build | 5-15 minutes |
| Typical incremental | <30 seconds |
| Memory usage | Low (streaming) |
| Disk usage | ~2-3x source size (intermediates) |

## Extension Points

### Adding New Source Formats

1. Add conversion function (e.g., `webp-to-svg`)
2. Add case in main loop
3. Ensure function produces SVG at `FLAG_BUILD_SVG_FILE_PATH`

### Adding New Output Resolutions

1. Add `svg-to-png` call with new size
2. Add `png-to-dds` call for new output path
3. Create output directory in category iteration

### Modifying Bevel Parameters

Edit `source/scripts/gradient-bevel.lisp` — no build.sh changes needed.

### Changing Output Naming

Modify `FILE_PREFIX` in `get-flag-file-name` or add entries to `names.txt`.