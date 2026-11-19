# GIMP Scripts

## Overview

The build pipeline uses four GIMP Python-Fu scripts for image processing operations that require GIMP's advanced capabilities. Each script is invoked as a GIMP batch command that evaluates the script file, passing its parameters through environment variables.

## Script Inventory

| Script | Purpose | Invoked By | Input | Output |
|--------|---------|------------|-------|--------|
| `gradient_bevel.py` | Applies 3D gradient bevel effect | `apply-gradient-bevel` | PNG | PNG (with bevel) |
| `png_to_dds.py` | Exports PNG to DDS format | `png-to-dds` | PNG | DDS |
| `svg_to_png.py` | Renders SVG to PNG at specified size | `svg-to-png` | SVG | PNG |
| `xcf_to_png.py` | Exports XCF (GIMP native) to PNG | `xcf-to-png` / `xcf-to-svg` | XCF | PNG |

## Shared Modules

| Module | Responsibility |
|--------|----------------|
| `gimp_script_arguments.py` | Reads parameters from `GIMP_SCRIPT_*` environment variables |
| `gimp_script_errors.py` | Defines `GimpScriptError` for conversion failures |
| `gimp_procedures.py` | Looks up and runs GIMP procedures with named properties |
| `gimp_image_operations.py` | Image, layer, selection, filter, and export operations |

## Script Details

### gradient_bevel.py

**Purpose:** Applies a 3D bevel effect with gradient shading to a flag emblem, creating a raised/embossed appearance.

**Location:** `source/scripts/gradient_bevel.py`

**Function Signature:**
```python
apply_gradient_bevel(image_path)
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `image_path` | string | Path to the PNG file, rewritten in place |

**Algorithm:**

```
1. Load input PNG as image
2. Duplicate the flag layer as a height-map silhouette
3. Paint the flag silhouette onto a blur layer in white
4. Select the silhouette and apply a Gaussian blur to the blur layer, then clear the selection
5. Apply white-to-grey radial gradient to the flag layer
6. Apply Bump Map to the flag using the blurred silhouette as height map
7. Offset, invert and dim the blur layer, then remove it
8. Apply radial gold gradient to a Colour layer (Grain Merge blend) clipped to the flag shape
9. Merge visible layers
10. Save as PNG
```

**Note:** `edit_gradient_fill` differs from the GIMP 2.10 `gimp-edit-blend`. The legacy `95` and
`100` arguments were that procedure's opacity and were ignored; the GIMP 3 `offset` argument, which
is third, is the legacy offset of `0`. Passing `95` or `100` as the offset starts both gradients at
their dark end and renders the flag as flat, solid colour. The legacy Grain Merge blend is retained.

**Note:** The blur of the height map runs while the silhouette selection is still active, as the
legacy script does. Without the selection the blur widens the height map well beyond the silhouette,
the bump map sees an almost flat gradient, and the relief is flattened. This selection is what the
legacy `plug-in-gauss-rle` inherited from the preceding `gimp-image-select-item`.

**Note:** The flag is deliberately not re-clipped to the silhouette after the bump map. The legacy
bump map also coloured the pixels outside the silhouette, and re-clipping discards that relief and
thins the emblem edges.

**Key Constants (in script):**

```python
BLUR_RADIUS = 2.5       # Gaussian blur radius used for the relief silhouette
BUMP_AZIMUTH = 115.0    # Bump-map light direction
BUMP_ELEVATION = 40.0   # Bump-map light elevation
BUMP_DEPTH = 5          # Bump-map depth
BUMP_AMBIENT = 0.15     # Bump-map ambient light
GRADIENT_OFFSET = 0.0   # Gradient offset (legacy opacity of 95/100 was ignored)
USE_GRADIENT_DITHER = True  # Dither gradients, as the legacy gimp-edit-blend does
BLUR_OFFSET_ADJUSTMENT = 5   # Blur layer pixel offset
BLUR_LAYER_OPACITY = 50.0    # Blur layer opacity
BEVEL_SIZE = 22         # Selection inset for the flag gradient
BEVEL_INDENT_OFFSET = 12        # Bevel left inset in px
```

**Colour Stops:**

| Layer | Highlight (Foreground) | Shadow (Background) |
|-------|------------------------|---------------------|
| Blur | White silhouette | Transparent |
| Flag | White | Grey (127,127,127) |
| Colour | Gold (178,164,136) | Dark Gold (113,82,9) |

**GIMP procedures used:**
- `file-png-load` — Load PNG
- `gimp-layer-copy` — Create the silhouette layer
- `gimp-layer-new` — Create blur and Colour layers
- `gimp-image-insert-layer` — Add layers to the image
- `gimp-image-select-item` — Select the flag silhouette / colour layer
- `gimp-drawable-edit-fill` / `edit_gradient_fill` — Fill with colour or gradient
- `gegl:gaussian-blur` — Blur the relief silhouette
- `gegl:bump-map` — Emboss the flag using the silhouette as height map
- `gimp-image-merge-visible-layers` — Flatten
- `file-png-export` — Save PNG

**Modification Points:**
- Relief softness: Change `BLUR_RADIUS`
- Bevel depth: Change `BUMP_DEPTH`
- Bevel light direction: Change `BUMP_AZIMUTH` and `BUMP_ELEVATION`
- Gradient colours: Modify `COLOUR_GRADIENT_START` and `COLOUR_GRADIENT_END`
- Bevel offset: Change `BLUR_OFFSET_ADJUSTMENT`
- Bevel shadow strength: Change `BLUR_LAYER_OPACITY`
- Flag gradient inset and centre: Change `GRADIENT_OFFSET`, `BEVEL_INDENT_OFFSET`

### png_to_dds.py

**Purpose:** Exports a PNG image to DDS format with Stellaris-compatible settings.

This script does not use GIMP at all. It writes the 128-byte `DDS ` header itself, byte-identical
to the one `file-dds-export` produces with compression disabled, followed by raw BGRA pixels with no
mipmaps. Avoiding the GIMP start makes the export effectively free, because that start dominates
every other stage.

**Location:** `source/scripts/png_to_dds.py`

**Function Signature:**
```python
convert_image(source_path, output_path)
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `source_path` | string | Path to input PNG file |
| `output_path` | string | Path for output DDS file |

**Export Settings:**
```
Header: 128 bytes, byte-identical to GIMP's file-dds-export with compression disabled
Body:   raw BGRA pixels, no mipmaps
```

**Effective Settings:**
- **Compression:** Uncompressed BGRA8
- **Mipmaps:** None
- **Colour Space:** Linear (no sRGB conversion)

**Note:** The header matches the DDS textures previously produced by the GIMP 2.10 build, so the
output is byte-compatible while skipping the GIMP process entirely.

**Modification Points:**
- Header fields: Edit `build_header`
- Channel order: Edit the slice assignment in `convert_image`

### svg_to_png.py

**Purpose:** Renders an SVG file to a PNG at a specified pixel size, removing the flat background colour.

**Location:** `source/scripts/svg_to_png.py`

**Function Signature:**
```python
render_flag(source_path, output_path, output_size)
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `source_path` | string | Path to input SVG file |
| `output_path` | string | Path for output PNG file |
| `output_size` | integer | Target dimension in pixels (square: width = height) |

**Algorithm:**
```
1. Load SVG directly at the target output size (square)
2. Merge the imported layers into a single flag layer
3. Sample the corner colour, then remove it with colour to alpha
4. Lock the alpha and repaint the opaque area white
5. Merge visible layers
6. Save as PNG
```

**Key Operations:**
- **SVG Import:** `file-svg-load` renders the SVG at the requested size with the ratio disregarded
- **Background Removal:** `gegl:color-to-alpha` on the sampled corner colour
- **Repaint:** The alpha lock keeps the shape while every opaque pixel becomes white

**GIMP PDB Functions Used:**
- `file-svg-load` — Load SVG at a target size
- `gimp-image-merge-visible-layers` — Flatten
- `gimp-image-pick-color` — Sample the corner colour
- `gegl:color-to-alpha` — Remove the flat background
- `gimp-layer-set-lock-alpha` — Restrict the repaint to the shape
- `file-png-export` — Save PNG

**Modification Points:**
- Output size: Passed as parameter (128, 256, or 24)
- Background removal: Modify the sampled position or the colour threshold

### xcf_to_png.py

**Purpose:** Exports a GIMP XCF file (native format with layers) to a flat PNG.

**Location:** `source/scripts/xcf_to_png.py`

**Function Signature:**
```python
convert_image(source_path, output_path)
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `source_path` | string | Path to input XCF file |
| `output_path` | string | Path for output PNG file |

**Algorithm:**
```
1. Load XCF file (preserves all layers)
2. Merge all visible layers (flatten)
3. Save as PNG
```

**GIMP PDB Functions Used:**
- `gimp-file-load` — Load XCF (native loader)
- `gimp-image-merge-visible-layers` — Flatten (EXPAND-AS-NECESSARY)
- `file-png-export` — Save PNG

**Modification Points:**
- Layer merge mode: Change `merge_visible_layers` to use a different `Gimp.MergeType`
- Output format: Replace `export_png` with another export helper

## Invocation Pattern

All scripts are invoked via GIMP batch mode from `build.sh`, with parameters supplied as `GIMP_SCRIPT_*` environment variables:

```bash
# Pattern
env GIMP_SCRIPT_<NAME>="<value>" ... "${GIMP_TOOL_PATH}" -i \
    --batch-interpreter=python-fu-eval \
    -b "exec(open('${SCRIPT_PATH}').read())" --quit

# Example
env GIMP_SCRIPT_INPUT_IMAGE_PATH="in.svg" \
    GIMP_SCRIPT_OUTPUT_IMAGE_PATH="out.png" \
    GIMP_SCRIPT_OUTPUT_IMAGE_SIZE="128" \
    "${GIMP_TOOL_PATH}" -i --batch-interpreter=python-fu-eval \
    -b "exec(open('source/scripts/svg_to_png.py').read())" --quit
```

**Flags:**
- `-i` — No interface (batch mode)
- `--batch-interpreter=python-fu-eval` — Select the Python-Fu interpreter
- `-b` — Batch command
- `--quit` — Exit GIMP after commands

## Dependencies

### GIMP Version
- **Minimum:** GIMP 3.0+
- **Tested:** GIMP 3.2.8

### Required Plug-ins
GIMP 3 bundles every required plug-in.

| Plug-in | PDB Function | Purpose |
|---------|--------------|---------|
| SVG import | `file-svg-load` | Load SVG files |
| PNG import | `file-png-load` | Load PNG files |
| PNG export | `file-png-export` | Write PNG files |
| Colour to Alpha | `gegl:color-to-alpha` | Remove solid backgrounds |
| Gaussian Blur | `gegl:gaussian-blur` | Relief silhouette smoothing |
| Bump Map | `gegl:bump-map` | Bevel embossing |
| Python-Fu | `python-fu-eval` | Batch script interpreter |

### Flatpak Support
Scripts work with Flatpak GIMP (`org.gimp.GIMP`) when invoked via the detected Flatpak path.

## Error Handling

### Script-Level
- Missing parameters raise `GimpScriptError`
- GIMP returns non-zero exit on failure
- `build.sh` validates that each expected output file exists

### Common Failure Modes

| Script | Failure Cause | Symptom |
|--------|---------------|---------|
| gradient_bevel | Unsupported GEGL operation | GIMP error, no output |
| png_to_dds | DDS export procedure missing | "Unknown file format" |
| svg_to_png | Invalid SVG | Import fails, empty image |
| xcf_to_png | Corrupt XCF | Load fails |

### Debugging
Run the script directly through GIMP batch mode with the parameters supplied as environment variables, and inspect the GIMP console output.
