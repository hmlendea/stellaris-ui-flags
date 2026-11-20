# API Reference

## Overview

This mod is a **content mod** — it adds flag assets, colours, and localisation to Stellaris. It does not expose a traditional code API. The "API surface" consists of:

1. **Build pipeline functions** (bash functions in `build.sh`)
2. **GIMP Python-Fu functions** (Python functions in `source/scripts/*.py`)
3. **Content interfaces** (Stellaris mod file formats consumed by the game)

## Build Pipeline Functions (`build.sh`)

### `get-flag-file-name`

Resolves the output filename from a source filename using the global `names.txt` mapping.

```bash
get-flag-file-name <source_file_name>
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `source_file_name` | string | Source filename without extension |

**Returns:** Output filename (without extension) via stdout.

**Behaviour:**
- If `source_file_name` found in `names.txt`: returns mapped value
- If not found: returns `"ui_" + source_file_name`

The mapping file path is read from the global `FLAG_NAMES_FILE_PATH` variable (`source/names.txt`), so the function takes a single argument.

**Example:**
```bash
get-flag-file-name "eagle"
# Returns: "ui_domination_1" (if names.txt has eagle=ui_domination_1)
# Returns: "ui_eagle" (if no entry)
```

---

### `generate-mod-descriptor`

Generates a Stellaris mod descriptor file (`.mod`).

```bash
generate-mod-descriptor <output_path>
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `output_path` | string | Where to write the descriptor file |

**Side Effects:** Writes descriptor file to `output_path`.

**Descriptor Content:**
```ini
version="${MOD_VERSION}"
name="${MOD_NAME}"
path="mod/${MOD_ID}"
tags={
	"Graphics"
}
supported_version="${STELLARIS_VERSION}"
```

Both descriptors are written identically, so both carry `path="mod/ui-flags"`. There is no `picture` field.

**Example:**
```bash
generate-mod-descriptor "out/ui-flags.mod"
generate-mod-descriptor "out/ui-flags/descriptor.mod"
```

---

### `bmp-to-svg`

Converts BMP to SVG via potrace.

```bash
bmp-to-svg <input_file_path> <output_file_path>
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `input_file_path` | string | Path to input BMP file |
| `output_file_path` | string | Path for output SVG file |

**Tool:** potrace (`-s` flag for SVG output)

---

### `png-to-svg`

Converts PNG to SVG via BMP intermediate.

```bash
png-to-svg <input_file_path> <output_file_path>
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `input_file_path` | string | Path to input PNG file |
| `output_file_path` | string | Path for output SVG file |

**Pipeline:** PNG → BMP (ImageMagick) → SVG (potrace)

**Side Effects:** Creates and removes temporary BMP file.

---

### `svg-to-png`

Renders SVG to PNG at specified size with `rsvg-convert` and ImageMagick.

```bash
svg-to-png <input_file_path> <output_file_path> <output_image_size>
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `input_file_path` | string | Path to input SVG file |
| `output_file_path` | string | Path for output PNG file |
| `output_image_size` | integer | Target dimension in pixels (square) |

**Tool:** `rsvg-convert` and ImageMagick, through the `svg-to-png` function in `build.sh`

**Sizes Used:** 128 (main), 256 (map), 24 (small)

---

### `png-to-dds`

Exports PNG to DDS with the plain Python writer.

```bash
png-to-dds <input_file_path> <output_file_path>
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `input_file_path` | string | Path to input PNG file |
| `output_file_path` | string | Path for output DDS file |

**Tool:** Python 3 with `png_to_dds.py`, which writes the uncompressed format directly instead of
starting GIMP

---

### `bevel-pngs`

Applies the gradient bevel to a list of PNGs, batching them into shared GIMP sessions.

```bash
bevel-pngs <round_name> <png_path>...
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `round_name` | string | Name of the retry round, used for the session log file names |
| `png_path` | list | Paths of the PNG files, each rewritten in place |

**Behaviour:** Chunks the paths by `FLAG_BEVEL_BATCH_SIZE`, runs at most `FLAG_GIMP_CONCURRENCY`
sessions at once, and writes a completion marker per image only after its bevel has been saved.

**Tool:** GIMP batch mode with `bevel_batch.py`

---

### `collect-unbeveled-pngs`

Fills `FLAG_BEVEL_PATHS` with every registered flag PNG that is not beveled, so the retry rounds can
attempt exactly the images a killed session left behind.

```bash
collect-unbeveled-pngs
```

**Tool:** None, file-system checks only

---

### `report-unbeveled-flags`

Prints the path, source SVG, and diagnosed reason for every flag still unbeveled after the final
round. Each reason is produced by `describe-bevel-failure`, which reads the session log, flag list,
and exit code beside each `build/bevel-*.log` to attribute the failure to a session fate.

```bash
report-unbeveled-flags
```

**Tool:** None, reads `build/bevel-*.log*` files

---

## GIMP Python-Fu Functions

### `apply_gradient_bevel` (gradient_bevel.py)

Applies 3D gradient bevel effect to a flag emblem.

```python
apply_gradient_bevel(image_path)
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `image_path` | string | Path to the PNG file, rewritten in place |

**Behaviour:** Loads PNG, applies a white-to-grey radial gradient to the flag, bump maps it using a blurred silhouette as the height map, offsets/inverts/dims the blur layer, overlays a radial gold gradient clipped to the shape, then merges and saves the PNG. The flag is deliberately not re-clipped to the silhouette after the bump map, because the legacy bump map colours pixels outside it and clipping would thin the emblem edges. The algorithm reproduces the GIMP 2.10 bevel.

**Key Constants:**
```python
BLUR_RADIUS = 2.5       # Gaussian blur radius used for the relief silhouette
BUMP_AZIMUTH = 115.0    # Bump-map light direction
BUMP_ELEVATION = 40.0   # Bump-map light elevation
BUMP_DEPTH = 5          # Bump-map depth
COMPLETION_MARKER_SUFFIX = '.beveled'  # Marker written only after a successful save
```

---

### `bevel_images` (bevel_batch.py)

Applies the gradient bevel to every image of a batch inside one GIMP session.

```python
bevel_images(image_paths)
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `image_paths` | list | PNG paths, each rewritten in place |

**Behaviour:** Writes a flushed `[INFO] Beveling '<path>'` line before each image (so a killed session still
records the image in flight), calls `apply_gradient_bevel`, and writes the `.beveled` marker only
after the bevel is saved. A failure on one image is reported as a warning and the batch continues.

---

### `convert_image` (png_to_dds.py)

Exports PNG to DDS format.

The 128-byte header is byte-identical to the one GIMP's `file-dds-export` writes with compression
disabled; only the pixel data follows it, as raw BGRA.

```python
convert_image(source_path, output_path)
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `source_path` | string | Path to input PNG file |
| `output_path` | string | Path for output DDS file |

**Behaviour:** Reads the PNG dimensions and the BGRA pixel data from ImageMagick in one invocation
each, then writes a 128-byte DDS header followed by the raw pixels.

---

### `svg-to-png` internals

The stage is implemented by the `svg-to-png` function in `build.sh`, which invokes `rsvg-convert`
and then ImageMagick for the alpha channel.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `source_path` | string | Path to input SVG file |
| `output_path` | string | Path for output PNG file |
| `output_size` | integer | Target dimension (square) |

**Behaviour:** Loads SVG at the target size, removes the flat background colour, repaints the opaque area white, and saves the PNG.

## Content Interfaces (Stellaris Mod Formats)

### Mod Descriptor Format

```ini
version="<build_version>"
name="<display_name>"
path="mod/<mod_id>"
supported_version="<version_pattern>"
tags={
    "<tag1>"
}
```

**Fields:**

| Field | Type | Required | Example |
|-------|------|----------|---------|
| `version` | string | Yes | `1.0.0` |
| `name` | string | Yes | `Universum Infinitum: Flags` |
| `path` | string | Yes | `mod/ui-flags` |
| `supported_version` | string | Yes | `v4.5.*` |
| `tags` | list | Yes | `{"Graphics"}` |

There is no `picture` field; both descriptors carry `path="mod/ui-flags"`.

### Colour Definition Format (`colors.txt`)

```txt
colors = {
    <colour_name> = {
        flag = hsv { <H> <S> <V> }
        map = hsv { <H> <S> <V> }
        ship = hsv { <H> <S> <V> }
        use_as_border_color = <yes|no>
    }
}

randomizable_combo = { <colour1> <colour2> <colour3> }
```

**Colour Contexts:**

| Context | Used For | Resolution |
|---------|----------|------------|
| `flag` | Main/small flags | 128px / 24px |
| `map` | Galaxy map flags | 256px |
| `ship` | Ship hull patterns | Variable |

**HSV Ranges:**
- H: 0.0–1.0
- S: 0.0–1.0
- V: 0.0–1.0+ (can exceed 1.0)

**RGB Alternative:** `rgb { <R> <G> <B> }` with 0–255 values.

### Localisation Format (`*_l_english.yml`)

```yaml
l_english:
 <key>:0 "<value>"
```

**Key Pattern for Categories:** `FLAG_CATEGORY_<directory_name>`

**Example:**
```yaml
l_english:
 FLAG_CATEGORY_aquatic:0 "Aquatic"
 FLAG_CATEGORY_ui_starwars:0 "Star Wars"
```

### Flag Directory Structure

```
flags/
├── colors.txt
├── backgrounds/
│   └── <background_name>.dds
└── <category>/
    ├── <flag_name>.dds          # 128px main
    ├── map/
    │   └── <flag_name>.dds      # 256px map
    └── small/
        └── <flag_name>.dds      # 24px small
```

**Requirements:**
- All three variants must exist for each flag
- Same filename across all three variants
- DDS format without mipmaps

## Usage Examples

### Build Script Invocation

```bash
# Basic build
./build.sh 1.0.0

# Incremental build (add new assets, rebuild)
./build.sh 1.0.1

# Full rebuild
rm -rf build out
./build.sh 1.0.1
```

### GIMP Script Direct Invocation

```bash
GIMP_SCRIPTS_DIRECTORY_PATH="source/scripts"

# Apply the gradient bevel to a single PNG (rewritten in place)
env GIMP_SCRIPT_IMAGE_PATH="input.png" \
    gimp --new-instance -i --batch-interpreter=python-fu-eval \
    -b "import sys; sys.path.insert(0, '${GIMP_SCRIPTS_DIRECTORY_PATH}'); exec(open('${GIMP_SCRIPTS_DIRECTORY_PATH}/gradient_bevel.py').read())" --quit

# Apply the bevel to a newline-separated batch (in place, shared session)
env GIMP_SCRIPT_IMAGE_PATHS="input_a.png
input_b.png" \
    gimp --new-instance -i --batch-interpreter=python-fu-eval \
    -b "import sys; sys.path.insert(0, '${GIMP_SCRIPTS_DIRECTORY_PATH}'); exec(open('${GIMP_SCRIPTS_DIRECTORY_PATH}/bevel_batch.py').read())" --quit

# Export to DDS (plain Python, no GIMP)
env GIMP_SCRIPT_INPUT_IMAGE_PATH="input.png" \
    GIMP_SCRIPT_OUTPUT_IMAGE_PATH="output.dds" \
    python3 "${GIMP_SCRIPTS_DIRECTORY_PATH}/png_to_dds.py"
```

**Note:** `gradient_bevel.py` takes a single `GIMP_SCRIPT_IMAGE_PATH`; SVG rasterisation is not a GIMP operation and is performed by the `svg-to-png` bash function through `rsvg-convert` and ImageMagick. GIMP sessions are started with `--new-instance` so a batch is never discarded by an instance that is still shutting down.

### Adding a New Flag

1. Place source file: `source/flags/<category>/my-flag.svg`
2. Optional mapping: Add `my-flag=ui_custom_name` to `source/names.txt`
3. Build: `./build.sh <version>`
4. Output: `out/ui-flags/flags/<category>/ui_custom_name.dds` (+ map/ and small/ variants)

### Adding a New Category

1. Create directory: `source/flags/my-category/`
2. Add localisation: `FLAG_CATEGORY_my-category:0 "My Category"` in `source/localisation.yml`
3. Add flag assets to directory
4. Build: `./build.sh <version>`

## Error Codes

### Build Script Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Validation failure (missing version argument, setup tools, or usage error) |
| 2 | Invalid arguments handed to `execute-gimp-script-file` |
| 3 | A conversion helper (`png-to-bmp`, `svg-to-png`, `bmp-to-svg`, `png-to-dds`, `export-*`) failed to produce its output |
| 255 (`-1`) | `source/` directory not found |

### Common Error Messages

| Message | Cause |
|---------|-------|
| `Please specify a version!` | No version argument provided |
| `MISSING SOURCE DIRECTORY` | `source/` not found (wrong working directory?) |
| `[ERROR] ImageMagick is not installed on this system` | `/usr/bin/convert` not present |
| `[ERROR] potrace is not installed on this system` | `/usr/bin/potrace` not present |
| `[ERROR] Python 3 is not installed on this system` | `python3` not found |
| `[ERROR] rsvg-convert is not installed on this system` | `rsvg-convert` not found |
| `[ERROR] GIMP is not installed on this system` | No GIMP binary found when a bevel session is started (checked lazily, not at start-up) |
| `[WARNING] Unsupported source format for '<file>'` | Source file has unsupported extension |
| `[ERROR] <n> flags were not beveled after 8 attempts:` | Bevels remained unmarked after every retry round |

## Related Documentation

- [Build Pipeline Component](../components/build-pipeline.md) — Detailed function implementations
- [GIMP Scripts Component](../components/gimp-scripts.md) — Python-Fu details
- [Build Execution Flow](../flows/build-execution.md) — End-to-end execution
- [Asset Conversion Flow](../flows/asset-conversion.md) — Per-asset conversion
- [Configuration](../configuration.md) — Configuration sources