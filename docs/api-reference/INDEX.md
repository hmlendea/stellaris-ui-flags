# API Reference

## Overview

This mod is a **content mod** — it adds flag assets, colours, and localisation to Stellaris. It does not expose a traditional code API. The "API surface" consists of:

1. **Build pipeline functions** (bash functions in `build.sh`)
2. **GIMP Script-fu functions** (Scheme functions in `source/scripts/*.lisp`)
3. **Content interfaces** (Stellaris mod file formats consumed by the game)

## Build Pipeline Functions (`build.sh`)

### `get-flag-file-name`

Resolves output filename from source filename using the `names.txt` mapping.

```bash
get-flag-file-name <names_file_path> <source_file_name>
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `names_file_path` | string | Path to `names.txt` |
| `source_file_name` | string | Source filename without extension |

**Returns:** Output filename (without extension) via stdout.

**Behaviour:**
- If `source_file_name` found in `names.txt`: returns mapped value
- If not found: returns `"ui_" + source_file_name`

**Example:**
```bash
get-flag-file-name "source/names.txt" "eagle"
# Returns: "ui_domination_1" (if names.txt has eagle=ui_domination_1)
# Returns: "ui_eagle" (if no entry)
```

---

### `generate-mod-descriptor`

Generates a Stellaris mod descriptor file (`.mod`).

```bash
generate-mod-descriptor <output_path> <path_value>
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `output_path` | string | Where to write the descriptor file |
| `path_value` | string | Value for `path` field in descriptor |

**Side Effects:** Writes descriptor file to `output_path`.

**Descriptor Content:**
```ini
name="${MOD_NAME}"
path="${path_value}"
supported_version="${STELLARIS_VERSION}"
tags={
    "Graphics"
}
picture="thumbnail.png"
```

**Example:**
```bash
generate-mod-descriptor "out/ui-flags.mod" "mod/ui-flags"
generate-mod-descriptor "out/ui-flags/descriptor.mod" "."
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

### `xcf-to-svg`

Converts XCF (GIMP native) to SVG via PNG → BMP intermediates.

```bash
xcf-to-svg <input_file_path> <output_file_path>
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `input_file_path` | string | Path to input XCF file |
| `output_file_path` | string | Path for output SVG file |

**Pipeline:** XCF → PNG (GIMP) → BMP (ImageMagick) → SVG (potrace)

**Side Effects:** Creates and removes temporary PNG and BMP files.

---

### `ai-to-svg`

Converts Adobe Illustrator AI to SVG via Inkscape.

```bash
ai-to-svg <input_file_path> <output_file_path>
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `input_file_path` | string | Path to input AI file |
| `output_file_path` | string | Path for output SVG file |

**Tool:** Inkscape CLI (`--export-type=svg`)

---

### `svg-to-png`

Renders SVG to PNG at specified size using GIMP Script-fu.

```bash
svg-to-png <input_file_path> <output_file_path> <output_image_size>
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `input_file_path` | string | Path to input SVG file |
| `output_file_path` | string | Path for output PNG file |
| `output_image_size` | integer | Target dimension in pixels (square) |

**Tool:** GIMP batch mode with `svg-to-png.lisp`

**Sizes Used:** 128 (main), 256 (map), 24 (small)

---

### `png-to-dds`

Exports PNG to DDS using GIMP Script-fu.

```bash
png-to-dds <input_file_path> <output_file_path>
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `input_file_path` | string | Path to input PNG file |
| `output_file_path` | string | Path for output DDS file |

**Tool:** GIMP batch mode with `png-to-dds.lisp`

---

### `apply-gradient-bevel`

Applies gradient bevel effect to PNG using GIMP Script-fu.

```bash
apply-gradient-bevel <input_file_path> <output_file_path>
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `input_file_path` | string | Path to input PNG file |
| `output_file_path` | string | Path for output PNG file (with bevel) |

**Tool:** GIMP batch mode with `gradient-bevel.lisp`

---

### `xcf-to-png`

Exports XCF to PNG using GIMP Script-fu.

```bash
xcf-to-png <input_file_path> <output_file_path>
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `input_file_path` | string | Path to input XCF file |
| `output_file_path` | string | Path for output PNG file |

**Tool:** GIMP batch mode with `xcf-to-png.lisp`

## GIMP Script-fu Functions

### `gradient-bevel` (gradient-bevel.lisp)

Applies 3D gradient bevel effect to a flag emblem.

```lisp
(gradient-bevel inputPath outputPath)
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `inputPath` | string | Path to input PNG file |
| `outputPath` | string | Path for output PNG file |

**Behaviour:** Loads PNG, creates Logo and Colour Overlay layers, applies bump mapping and gradient shading, merges, saves PNG.

**Key Constants:**
```lisp
bevel-size: 22       ; Bevel width in pixels
bevel-width: 2.5      ; Gaussian blur radius
bevel-height: 40      ; Emboss depth
```

---

### `png-to-dds` (png-to-dds.lisp)

Exports PNG to DDS format.

```lisp
(png-to-dds inputPath outputPath)
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `inputPath` | string | Path to input PNG file |
| `outputPath` | string | Path for output DDS file |

**Behaviour:** Loads PNG, saves as DDS with DXT1/DXT5 compression and mipmaps.

---

### `svg-to-png` (svg-to-png.lisp)

Renders SVG to PNG at specified size.

```lisp
(svg-to-png inputPath outputPath outputSize)
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `inputPath` | string | Path to input SVG file |
| `outputPath` | string | Path for output PNG file |
| `outputSize` | integer | Target dimension (square) |

**Behaviour:** Loads SVG, scales to fit, centers in square image, removes solid background, saves PNG.

---

### `xcf-to-png` (xcf-to-png.lisp)

Exports XCF to flat PNG.

```lisp
(xcf-to-png inputPath outputPath)
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `inputPath` | string | Path to input XCF file |
| `outputPath` | string | Path for output PNG file |

**Behaviour:** Loads XCF, merges visible layers, saves PNG.

## Content Interfaces (Stellaris Mod Formats)

### Mod Descriptor Format

```ini
name="<display_name>"
path="<relative_path>"
supported_version="<version_pattern>"
tags={
    "<tag1>"
    "<tag2>"
}
picture="<thumbnail_file>"
```

**Fields:**

| Field | Type | Required | Example |
|-------|------|----------|---------|
| `name` | string | Yes | `Universum Infinitum: Flags` |
| `path` | string | Yes | `mod/ui-flags` or `.` |
| `supported_version` | string | Yes | `v4.5.*` |
| `tags` | list | No | `{"Graphics"}` |
| `picture` | string | No | `thumbnail.png` |

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
- DDS format with mipmaps

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
# Render SVG to 128px PNG
gimp -i -b "(svg-to-png \"input.svg\" \"output.png\" 128)" -b "(gimp-quit 0)"

# Apply bevel
gimp -i -b "(gradient-bevel \"input.png\" \"output.png\")" -b "(gimp-quit 0)"

# Export to DDS
gimp -i -b "(png-to-dds \"input.png\" \"output.dds\")" -b "(gimp-quit 0)"

# Export XCF to PNG
gimp -i -b "(xcf-to-png \"input.xcf\" \"output.png\")" -b "(gimp-quit 0)"
```

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
| 1 | Validation failure (missing argument, source, or tools) |

### Common Error Messages

| Message | Cause |
|---------|-------|
| `Usage: ./build.sh <version>` | No version argument provided |
| `MISSING SOURCE DIRECTORY` | `source/` not found (wrong working directory?) |
| `ImageMagick is not installed` | `convert` not in PATH or Flatpak |
| `potrace is not installed` | `potrace` not in PATH |
| `Inkscape is not installed` | Inkscape not found (system or Flatpak) |
| `GIMP is not installed` | GIMP not found (system or Flatpak) |
| `Unsupported format: <file>` | Source file has unsupported extension |

## Related Documentation

- [Build Pipeline Component](../components/build-pipeline.md) — Detailed function implementations
- [GIMP Scripts Component](../components/gimp-scripts.md) — Script-fu details
- [Build Execution Flow](../flows/build-execution.md) — End-to-end execution
- [Asset Conversion Flow](../flows/asset-conversion.md) — Per-asset conversion
- [Configuration](../configuration.md) — Configuration sources