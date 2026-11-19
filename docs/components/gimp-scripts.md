# GIMP Scripts

## Overview

The build pipeline uses two GIMP Python-Fu scripts for image processing operations that require GIMP's advanced capabilities, plus a wrapper that batches the bevels into shared sessions. Each script is invoked as a GIMP batch command that evaluates the script file, passing its parameters through environment variables.

## Script Inventory

| Script | Purpose | Invoked By | Input | Output |
|--------|---------|------------|-------|--------|
| `bevel_batch.py` | Bevels every image of a batch in one GIMP session | `bevel-pngs` | newline-separated PNG paths | PNGs (with bevel) |
| `gradient_bevel.py` | Applies 3D gradient bevel effect | `bevel_batch.py` | PNG | PNG (with bevel) |
| `png_to_dds.py` | Exports PNG to DDS format | `png-to-dds` | PNG | DDS |
| `xcf_to_png.py` | Exports XCF (GIMP native) to PNG | `xcf-to-png` / `xcf-to-svg` | XCF | PNG |

## Shared Modules

| Module | Responsibility |
|--------|----------------|
| `gimp_script_arguments.py` | Reads parameters from `GIMP_SCRIPT_*` environment variables |
| `gimp_script_errors.py` | Defines `GimpScriptError` for conversion failures |
| `gimp_procedures.py` | Looks up and runs GIMP procedures with named properties |
| `gimp_image_operations.py` | Image, layer, selection, filter, and export operations |

## Script Details

### bevel_batch.py

**Purpose:** Applies the gradient bevel to every image of a batch inside one GIMP session, so the
per-invocation start-up cost is paid once per batch instead of once per image.

**Location:** `source/scripts/bevel_batch.py`

**Function Signatures:**
```python
read_image_paths()
bevel_images(image_paths)
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `IMAGE_PATHS` | string | Newline-separated paths of the PNG files, each rewritten in place |

**Algorithm:**

```
1. Split the newline-separated IMAGE_PATHS argument into paths
2. Apply the gradient bevel to each path in turn
3. Write the completion marker only after each bevel has been saved
4. Report every path that failed, and continue with the remaining ones
```

**Note:** A failure on one image does not stop the batch, because an unmarked image is retried over
the remaining rounds. The caller keeps the batch bounded, because the memory a session holds grows
with the number of images it has processed.

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

### svg-to-png

**Purpose:** Renders an SVG file to a PNG at a specified pixel size, removing the flat background
colour.

**Location:** the `svg-to-png` function in `build.sh`

**Tooling:** `rsvg-convert` and ImageMagick. This stage no longer uses GIMP: rasterising through
`rsvg-convert` and deriving the alpha with ImageMagick reproduces the former GIMP pipeline exactly
while costing milliseconds instead of a multi-second GIMP start.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `input_image_path` | string | Path to input SVG file |
| `output_image_path` | string | Path for output PNG file |
| `output_image_size` | integer | Target dimension in pixels (square: width = height) |

**Algorithm:**
```
1. Rasterise the SVG at the target size over a white background
2. Sample the background colour from the top-left corner
3. Take the difference from that colour as the alpha channel
4. Composite that alpha over an opaque white base
5. Save as a truecolour PNG with alpha
```

**Key Operations:**
- **Rasterisation:** `rsvg-convert -w N -h N -b white`. The white background is essential; SVGs traced from bitmaps draw black shapes with no background rectangle, so a transparent background would render black on black and leave the emblem invisible.
- **Alpha:** the emblem is whatever differs from the sampled background colour, and that difference becomes the alpha channel.
- **Base:** an explicit white image, because the pipeline expects the emblem to be white with the shape in the alpha channel alone.
- **Colour type:** the output must be forced to PNG colour type 6. ImageMagick otherwise emits a greyscale image, which the DDS writer reads as the wrong channels.

**Modification Points:**
- Output size: Passed as parameter (128, 256, or 24)
- Background colour: Change the `-b` argument
- Alpha derivation: Modify the difference composite

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
    -b "exec(open('source/scripts/gradient_bevel.py').read())" --quit
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
| xcf_to_png | Corrupt XCF | Load fails |

### Debugging
Run the script directly through GIMP batch mode with the parameters supplied as environment variables, and inspect the GIMP console output.
