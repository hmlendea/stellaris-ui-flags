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

VARIANT_ATTEMPT_COUNT=8                                  # Bevel retry rounds
FLAG_WORKER_COUNT="${FLAG_WORKER_COUNT:-4}"              # Rasterise/export workers
FLAG_GIMP_CONCURRENCY="${FLAG_GIMP_CONCURRENCY:-4}"      # Concurrent GIMP sessions
FLAG_BEVEL_BATCH_SIZE="${FLAG_BEVEL_BATCH_SIZE:-$(bevel-batch-default)}"
```

`FLAG_BEVEL_BATCH_SIZE` defaults to the `bevel-batch-default` function, which derives `4`, `6`, or
`8` from `MemAvailable` in `/proc/meminfo` divided by `200000 * FLAG_GIMP_CONCURRENCY`.

## Path Definitions

```bash
SOURCE_DIR_PATH="$(pwd)/source"
SOURCE_FLAGS_DIR_PATH="${SOURCE_DIR_PATH}/flags"
SOURCE_SCRIPTS_DIR_PATH="${SOURCE_DIR_PATH}/scripts"
BUILD_DIR_PATH="$(pwd)/build"
OUTPUT_DIR_PATH="$(pwd)/out"
OUTPUT_MOD_DIR_PATH="${OUTPUT_DIR_PATH}/${MOD_ID}"
GIMP_SLOT_DIRECTORY_PATH="${BUILD_DIR_PATH}/gimp-slots"
```

All paths are anchored to `$(pwd)`, so the build must be run from the repository root. Derived
category and asset paths are constructed dynamically during execution.

## Tool Detection

### Detection Order

Tools are resolved to concrete binary paths at start-up. ImageMagick and potrace are checked at
fixed system paths, while Python 3 and `rsvg-convert` fall back to `command -v`:

```bash
[ ! -f "/usr/bin/convert" ]  && echo "[ERROR] ImageMagick is not installed on this system" && exit 1
[ ! -f "/usr/bin/potrace" ]  && echo "[ERROR] potrace is not installed on this system" && exit 1

PYTHON_BINARY="/usr/bin/python3"
[ ! -f "${PYTHON_BINARY}" ] && PYTHON_BINARY="$(command -v python3)"
[ ! -x "${PYTHON_BINARY}" ] && echo "[ERROR] Python 3 is not installed on this system" && exit 1

RSVG_BINARY="/usr/bin/rsvg-convert"
[ ! -x "${RSVG_BINARY}" ] && RSVG_BINARY="$(command -v rsvg-convert)"
[ ! -x "${RSVG_BINARY}" ] && echo "[ERROR] rsvg-convert is not installed on this system" && exit 1
```

GIMP is resolved **lazily**, inside `execute-gimp-script-file`, only when a bevel session is started:

1. `/usr/bin/gimp`
2. `/var/lib/flatpak/exports/bin/org.gimp.GIMP` (Flatpak system)
3. `${HOME}/.local/share/flatpak/exports/bin/org.gimp.GIMP` (Flatpak user)

Because GIMP is checked at the first bevel rather than at start-up, a build in which every flag is
already processed never requires GIMP to be installed.

### Tools Detected

| Variable | Tool | Purpose |
|----------|------|---------|
| (checked via `/usr/bin/convert`) | ImageMagick `/usr/bin/convert` | PNG → BMP flattening, pixel reads |
| (checked via `/usr/bin/potrace`) | `potrace` | Raster → vector tracing |
| `RSVG_BINARY` | `rsvg-convert` | SVG → PNG rasterisation |
| `PYTHON_BINARY` | Python 3 | DDS export (`png_to_dds.py`) |
| (resolved in `execute-gimp-script-file`) | GIMP | Python-Fu batch execution, gradient bevel |

### Conversion Helpers

Conversion helpers are called through `magick` and `potrace` directly (`magick`, `convert`,
`potrace --opaque`) rather than through stored path variables. The only stored variables are
`RSVG_BINARY`, `PYTHON_BINARY`, and the GIMP path resolved per session.

## Utility Functions

### `get-flag-file-name`

Resolves output filename from source filename using the global `FLAG_NAMES_FILE_PATH` (`source/names.txt`).

```bash
get-flag-file-name() {
    local SOURCE_FILE_NAME="$1"
    local FILE_PREFIX="ui_"
    local FLAG_FILE_NAME=$(grep "^${SOURCE_FILE_NAME}=" "${FLAG_NAMES_FILE_PATH}" | awk -F= '{print $2}')

    if [ -z "${FLAG_FILE_NAME}" ]; then
        echo "${FILE_PREFIX}${SOURCE_FILE_NAME}"
    else
        echo "${FLAG_FILE_NAME}"
    fi
}
```

**Inputs:** source filename (without extension)
**Output:** Output filename (without extension)

### `generate-mod-descriptor`

Creates a `.mod` descriptor file. Both descriptors are written identically, so both carry
`path="mod/ui-flags"`.

```bash
generate-mod-descriptor() {
    local FILE_PATH="${1}"

    echo "version=\"${MOD_VERSION}\"" > "${FILE_PATH}"
    echo "name=\"${MOD_NAME}\"" >> "${FILE_PATH}"
    echo "path=\"mod/${MOD_ID}\"" >> "${FILE_PATH}"
    echo "tags={" >> "${FILE_PATH}"
    echo "\t\"Graphics\"" >> "${FILE_PATH}"
    echo "}" >> "${FILE_PATH}"
    echo "supported_version=\"${STELLARIS_VERSION}\"" >> "${FILE_PATH}"
    echo "" >> "${FILE_PATH}"
}
```

**Inputs:** output path
**Output:** Writes descriptor file (no `picture` field)

## Conversion Functions

### `bmp-to-svg`

Converts BMP to SVG via potrace.

```bash
bmp-to-svg() {
    local INPUT_IMAGE_PATH="${1}"
    local OUTPUT_IMAGE_PATH="${2}"
    potrace --opaque -s "${INPUT_IMAGE_PATH}" -o "${OUTPUT_IMAGE_PATH}"
}
```

**Path:** BMP → SVG
**Tool:** `potrace --opaque -s <bmp> -o <svg>`

### `png-to-svg`

Converts PNG to SVG via a flattened BMP intermediate.

```bash
png-to-svg() {
    local INPUT_IMAGE_PATH="${1}"
    local OUTPUT_IMAGE_PATH="${2}"
    local OUTPUT_IMAGE_PATH_WITHOUT_EXTENSION="${OUTPUT_IMAGE_PATH%.*}"

    png-to-bmp "${INPUT_IMAGE_PATH}" "${OUTPUT_IMAGE_PATH_WITHOUT_EXTENSION}.bmp"
    bmp-to-svg "${OUTPUT_IMAGE_PATH_WITHOUT_EXTENSION}.bmp" "${OUTPUT_IMAGE_PATH}"
}
```

`png-to-bmp` first flattens the PNG onto black with `convert -background "#000" -flatten`, because
the build pipeline expects an opaque emblem before tracing.

**Path:** PNG → BMP → SVG
**Tools:** ImageMagick `convert`, `potrace`

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

### `export-map-dds` and `export-beveled-dds`

`export-map-dds` exports only the map DDS, because the map carries no bevel and can be written as
soon as its PNG is rasterised. `export-beveled-dds` exports the main and small DDS together, after
the bevel rounds, so both textures carry the bevel:

```bash
export-map-dds <map_png_path> <map_dds_path>
export-beveled-dds <main_png_path> <main_dds_path> <small_png_path> <small_dds_path>
```

### `bevel-pngs`

Applies the gradient bevel to a list of PNGs, batching them into shared GIMP sessions.

```bash
bevel-pngs <round_name> <png_path>...
```

The paths are chunked by `FLAG_BEVEL_BATCH_SIZE`; each chunk becomes one GIMP session via
`start-bevel-session`, which waits for a free slot bounded by `FLAG_GIMP_CONCURRENCY`:

```bash
execute-gimp-script-file "bevel_batch" IMAGE_PATHS "$(printf '%s\n' "$@")"
```

**Path:** PNG → PNG (with bevel), rewritten in place
**Tool:** GIMP with `bevel_batch.py` script; a `.beveled` marker beside each PNG records success

### `collect-unbeveled-pngs` and `report-unbeveled-flags`

`collect-unbeveled-pngs` fills `FLAG_BEVEL_PATHS` with every registered flag PNG lacking a `.beveled`
marker, so the retry rounds attempt exactly the images a killed session left behind.
`report-unbeveled-flags` prints each remaining flag with its source SVG and a diagnosed reason, which
`describe-bevel-failure` derives from the session log, its flag list, and its exit code.

## Main Execution Loop

### Initialisation

```bash
# Validate version argument
if [ -z "${MOD_VERSION}" ]; then
    echo "Please specify a version!"
    exit 1
fi

# Validate source directory and fixed-path tools
[ ! -d "${SOURCE_DIR_PATH}" ] && echo "MISSING SOURCE DIRECTORY" && exit -1
[ ! -f "/usr/bin/convert" ] && echo "[ERROR] ImageMagick is not installed on this system" && exit 1
[ ! -f "/usr/bin/potrace" ] && echo "[ERROR] potrace is not installed on this system" && exit 1
# Python 3 and rsvg-convert are resolved via /usr/bin or `command -v`, then validated
```

### Static Asset Staging

```bash
mkdir -p "${OUTPUT_BACKGROUNDS_DIR_PATH}"
mkdir -p "${OUTPUT_LOCALISATIONS_DIR_PATH}"

cp "${SOURCE_BACKGROUNDS_DIR_PATH}"/* "${OUTPUT_BACKGROUNDS_DIR_PATH}"
cp "${SOURCE_COLOURS_FILE_PATH}" "${OUTPUT_COLOURS_FILE_PATH}"
cp "${SOURCE_LOCALISATION_FILE_PATH}" "${OUTPUT_LOCALISATION_FILE_PATH}"
cp "${THUMBNAIL_FILE_PATH}" "${OUTPUT_MOD_DIR_PATH}"

generate-mod-descriptor "${MOD_DESCRIPTOR_PRIMARY_FILE_PATH}"
generate-mod-descriptor "${MOD_DESCRIPTOR_SECONDARY_FILE_PATH}"
```

Before staging, stale worker logs are cleared so a previous run is not summarised again:

```bash
rm -f "${BUILD_DIR_PATH}"/*.log "${BUILD_DIR_PATH}"/*.log.flags "${BUILD_DIR_PATH}"/*.log.exit
```

### Category Iteration

```bash
for CATEGORY_DIR in "${SOURCE_FLAGS_DIR_PATH}"/*; do
    [ -z "${CATEGORY_DIR}" ] && continue
    [ $(ls -A "${CATEGORY_DIR}" | wc -l) -eq 0 ] && continue
    [ ! -d "${CATEGORY_DIR}" ] && continue

    CATEGORY_NAME=$(basename "${CATEGORY_DIR}")

    # Create build and output directories
    mkdir -p "${CATEGORY_BUILD_MAP_DIR_PATH}" "${CATEGORY_BUILD_SMALL_DIR_PATH}"
    mkdir -p "${CATEGORY_OUTPUT_MAP_DIR_PATH}" "${CATEGORY_OUTPUT_SMALL_DIR_PATH}"

    if [ -f "${CATEGORY_DIR}/usage.txt" ]; then
        cp "${CATEGORY_DIR}/usage.txt" "${CATEGORY_OUTPUT_DIR_PATH}/usage.txt"
    fi

    # Process each asset file
    for FILE in "${CATEGORY_DIR}"/*; do
        # ... asset processing ...
    done
done
```

Empty category directories are skipped entirely, and the loop iterates plain entries (not a trailing-slash glob).

### Per-Asset Processing

```bash
for FILE in "${CATEGORY_DIR}"/*; do
    FILE_BASENAME=$(basename "${FILE}")

    [ "${FILE_BASENAME}" == "usage.txt" ] && continue

    FILE_NAME="${FILE_BASENAME%.*}"
    FILE_EXTENSION=$(echo "${FILE_BASENAME}" | cut -d'.' -f2)

    FLAG_FILE_NAME=$(get-flag-file-name "${FILE_NAME}")

    # Define output paths
    FLAG_OUTPUT_MAIN_FILE_PATH="${CATEGORY_OUTPUT_DIR_PATH}/${FLAG_FILE_NAME}.dds"
    FLAG_OUTPUT_MAP_FILE_PATH="${CATEGORY_OUTPUT_MAP_DIR_PATH}/${FLAG_FILE_NAME}.dds"
    FLAG_OUTPUT_SMALL_FILE_PATH="${CATEGORY_OUTPUT_SMALL_DIR_PATH}/${FLAG_FILE_NAME}.dds"

    # Incremental build check: skip only when all three outputs exist
    if [ -f "${FLAG_OUTPUT_MAIN_FILE_PATH}" ] && [ -f "${FLAG_OUTPUT_MAP_FILE_PATH}" ] && [ -f "${FLAG_OUTPUT_SMALL_FILE_PATH}" ]; then
        continue
    fi

    # Intermediate paths
    FLAG_PNG_BUILD_FILE_PATH="${CATEGORY_BUILD_DIR_PATH}/${FLAG_FILE_NAME}.png"
    FLAG_SVG_BUILD_FILE_PATH="${CATEGORY_BUILD_DIR_PATH}/${FLAG_FILE_NAME}.svg"
    FLAG_BUILD_MAP_FILE_PATH="${CATEGORY_BUILD_MAP_DIR_PATH}/${FLAG_FILE_NAME}.png"
    FLAG_BUILD_SMALL_FILE_PATH="${CATEGORY_BUILD_SMALL_DIR_PATH}/${FLAG_FILE_NAME}.png"

    # Convert source format to SVG
    source-to-svg "${FILE}" "${FLAG_SVG_BUILD_FILE_PATH}"

    # Register the flag so the bevels can be batched after the parallel rasterisation
    FLAG_KEY="${CATEGORY_NAME}/${FLAG_FILE_NAME}"
    FLAG_KEYS+=("${FLAG_KEY}")
    FLAG_MAIN_PNG_PATHS[${FLAG_KEY}]="${FLAG_PNG_BUILD_FILE_PATH}"
    FLAG_SMALL_PNG_PATHS[${FLAG_KEY}]="${FLAG_BUILD_SMALL_FILE_PATH}"
    FLAG_MAIN_DDS_PATHS[${FLAG_KEY}]="${FLAG_OUTPUT_MAIN_FILE_PATH}"
    FLAG_SMALL_DDS_PATHS[${FLAG_KEY}]="${FLAG_OUTPUT_SMALL_FILE_PATH}"
    FLAG_BEVEL_SVGS[${FLAG_PNG_BUILD_FILE_PATH}]="${FLAG_SVG_BUILD_FILE_PATH}"
    FLAG_BEVEL_SIZES[${FLAG_PNG_BUILD_FILE_PATH}]="128"
    FLAG_BEVEL_SVGS[${FLAG_BUILD_SMALL_FILE_PATH}]="${FLAG_SVG_BUILD_FILE_PATH}"
    FLAG_BEVEL_SIZES[${FLAG_BUILD_SMALL_FILE_PATH}]="24"

done
```

The worker for each flag rasterises the main and small PNGs, rasterises the map PNG, and exports the
map DDS (which needs no bevel), bounded by `FLAG_WORKER_COUNT`:

```bash
while [ "$(jobs -rp | wc -l)" -ge "${FLAG_WORKER_COUNT}" ]; do
    wait -n
done

(
    FLAG_LOG_PATH="${BUILD_DIR_PATH}/${CATEGORY_NAME}-${FLAG_FILE_NAME}.log"

    (
        is-beveled-png "${FLAG_PNG_BUILD_FILE_PATH}" || rasterise-bevel-png "${FLAG_PNG_BUILD_FILE_PATH}"
        is-beveled-png "${FLAG_BUILD_SMALL_FILE_PATH}" || rasterise-bevel-png "${FLAG_BUILD_SMALL_FILE_PATH}"

        if ! is-usable-png "${FLAG_BUILD_MAP_FILE_PATH}"; then
            svg-to-png "${FLAG_SVG_BUILD_FILE_PATH}" "${FLAG_BUILD_MAP_FILE_PATH}" "256"
        fi

        # The map needs no bevel, so its DDS is exported now.
        export-map-dds "${FLAG_BUILD_MAP_FILE_PATH}" "${FLAG_OUTPUT_MAP_FILE_PATH}"
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

ImageMagick and potrace are validated at start-up (fail fast if missing). Python 3 and
`rsvg-convert` are resolved to a binary path and validated immediately afterwards. GIMP is validated
lazily, at the first bevel session, so a fully cached build never needs it.

### Conversion Errors

Individual asset failures are logged per worker but do not halt the rasterisation and export stage:

```bash
source-to-svg "${FILE}" "${FLAG_SVG_BUILD_FILE_PATH}"
...
export-map-dds "${FLAG_BUILD_MAP_FILE_PATH}" "${FLAG_OUTPUT_MAP_FILE_PATH}"
```

A bevel failure does not stop the batch, because an unmarked image is retried over the remaining
rounds. A flag whose bevels are still missing once the rounds are exhausted is reported at the end
of the build by `report-unbeveled-flags`, with its source SVG and the fate of the session that was
handling it.

### Output Verification

The DDS export is verified by the existence of every expected file, and the bevels are verified by
a completion marker written only after each bevel has been saved. The final line reports the produced
flag DDS count against the expected count (`source flag files × 3`).

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

1. Add an `svg-to-png` call with the new size
2. Add the intermediate map/small directory path and register the raster details in `FLAG_BEVEL_SVGS` / `FLAG_BEVEL_SIZES` if the variant is beveled
3. Add an `export-*` call for the new output path and create its directory in the category iteration

### Modifying Bevel Parameters

Edit `source/scripts/gradient_bevel.py` — no `build.sh` changes needed.

### Tuning the Bevel Batching

Change `FLAG_BEVEL_BATCH_SIZE` (flags per GIMP session) or `FLAG_GIMP_CONCURRENCY` (sessions at
once) — no script changes needed.

### Changing Output Naming

Modify `FILE_PREFIX` in `get-flag-file-name` or add entries to `names.txt`.