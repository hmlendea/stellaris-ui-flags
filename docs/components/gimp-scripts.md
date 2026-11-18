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
2. Get image dimensions (width, height)
3. Create a black "Relief" layer
4. Paint the flag silhouette onto the Relief layer in white
5. Apply Gaussian blur to the Relief layer to round the silhouette edges
6. Apply emboss to the Relief layer to obtain directional relief shading
7. Erase everything outside the flag shape
8. Create a "Colour" layer with a radial gold gradient, clipped to the flag shape
9. Remove the original flag layer
10. Merge visible layers
11. Save as PNG
```

**Key Constants (in script):**
```python
BLUR_RADIUS = 2.5       # Gaussian blur radius used for the relief silhouette
RELIEF_AZIMUTH = 115.0  # Emboss light direction
RELIEF_ELEVATION = 40.0 # Emboss light elevation
RELIEF_DEPTH = 5        # Emboss depth
```

**Colour Stops:**

| Layer | Highlight (Foreground) | Shadow (Background) |
|-------|------------------------|---------------------|
| Relief | White | Black |
| Colour | Gold (178,164,136) | Dark Gold (113,82,9) |

**GIMP PDB Functions Used:**
- `gimp-file-load` — Load PNG
- `gimp-layer-new` — Create the Relief and Colour layers
- `gimp-image-insert-layer` — Add layers to the image
- `gimp-image-select-item` — Select the flag silhouette
- `gimp-drawable-edit-fill` — Fill with the foreground or background colour
- `gimp-drawable-edit-gradient-fill` — Apply the radial gold gradient
- `gegl:gaussian-blur` — Blur the relief silhouette
- `gegl:emboss` — Emboss the relief silhouette
- `gimp-image-merge-visible-layers` — Flatten
- `file-png-export` — Save PNG

**Modification Points:**
- Bevel softness: Change `BLUR_RADIUS`
- Bevel depth: Change `RELIEF_DEPTH`
- Bevel light direction: Change `RELIEF_AZIMUTH` and `RELIEF_ELEVATION`
- Gradient colours: Modify `COLOUR_GRADIENT_START` and `COLOUR_GRADIENT_END`

### png_to_dds.py

**Purpose:** Exports a PNG image to DDS format with Stellaris-compatible settings.

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

**Export Settings (in `gimp_image_operations.export_dds`):**
```python
'compression-format': 'none',
```

**Effective Settings:**
- **Compression:** Uncompressed BGRA8
- **Mipmaps:** None
- **Colour Space:** Linear (no sRGB conversion)

**Note:** The uncompressed format matches the DDS textures previously produced by the GIMP 2.10 build.

**GIMP PDB Functions Used:**
- `gimp-file-load` — Load PNG
- `file-dds-export` — Save DDS

**Modification Points:**
- Compression format: Change `DDS_COMPRESSION_FORMAT`
- Mipmap generation: Add a `mipmaps` export property

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
| DDS export | `file-dds-export` | Write DDS textures |
| Colour to Alpha | `gegl:color-to-alpha` | Remove solid backgrounds |
| Gaussian Blur | `gegl:gaussian-blur` | Relief silhouette smoothing |
| Emboss | `gegl:emboss` | Bevel embossing |
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
