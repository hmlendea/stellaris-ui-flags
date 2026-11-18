# Asset Conversion Flow

## Overview

This document details the per-asset format conversion pipeline — the transformation of a single source asset through all conversion stages to produce the three output DDS variants (main, map, small).

## Conversion Pipeline Per Asset

```
SOURCE ASSET
    │
    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STAGE 1: SOURCE FORMAT → SVG                                                │
│                                                                             │
│   .svg  ──► COPY                                                            │
│   .ai   ──► Inkscape ──► SVG                                                │
│   .bmp  ──► potrace ──► SVG                                                 │
│   .png  ──► ImageMagick ──► BMP ──► potrace ──► SVG                        │
│   .xcf  ──► GIMP ──► PNG ──► ImageMagick ──► BMP ──► potrace ──► SVG       │
│                                                                             │
│   OUTPUT: build/<category>/<source_name>.svg                               │
└─────────────────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STAGE 2: SVG → THREE PNG RESOLUTIONS (parallel logical, sequential actual) │
│                                                                             │
│   SVG ──► GIMP (svg_to_png) ──► 128×128 PNG (main)                         │
│   SVG ──► GIMP (svg_to_png) ──► 256×256 PNG (map)                          │
│   SVG ──► GIMP (svg_to_png) ──►  24×24  PNG (small)                        │
│                                                                             │
│   Each invocation: independent GIMP process                                 │
└─────────────────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STAGE 3: BEVEL APPLICATION (main & small only)                              │
│                                                                             │
│   128px PNG ──► GIMP (gradient_bevel) ──► 128px PNG (beveled, in place)     │
│    24px PNG ──► GIMP (gradient_bevel) ──►  24px PNG (beveled, in place)     │
│   256px PNG ──► (NO BEVEL)                                                 │
│                                                                             │
│   Bevel: blurred silhouette emboss with gradient highlight/shadow           │
└─────────────────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STAGE 4: PNG → DDS EXPORT                                                   │
│                                                                             │
│   128px beveled PNG ──► GIMP (png_to_dds) ──► out/.../main/<name>.dds       │
│   256px flat PNG    ──► GIMP (png_to_dds) ──► out/.../map/<name>.dds        │
│    24px beveled PNG ──► GIMP (png_to_dds) ──► out/.../small/<name>.dds      │
│                                                                             │
│   DDS: uncompressed BGRA8, linear colour space                              │
└─────────────────────────────────────────────────────────────────────────────┘
    │
    ▼
THREE OUTPUT DDS FILES
```

## Stage 1: Source Format → SVG

### SVG (Direct Copy)

**Path:** `source/flags/<cat>/flag.svg` → `build/<cat>/flag.svg`

**Operation:** `cp`

**Conditions:** Source is already SVG — no conversion needed.

**Advantages:** Fastest, preserves vector quality, no rasterisation artifacts.

### AI (Adobe Illustrator)

**Path:** `source/flags/<cat>/flag.ai` → `build/<cat>/flag.svg`

**Tool:** Inkscape CLI

**Command:**
```bash
inkscape "input.ai" --export-type=svg --export-filename="output.svg"
```

**Limitations:**
- Inkscape's AI import is limited (AI is proprietary)
- Complex gradients, meshes, effects may not convert
- Text may not render if fonts missing
- Best for simple vector artwork saved as AI

### BMP (Bitmap)

**Path:** `source/flags/<cat>/flag.bmp` → `build/<cat>/flag.svg`

**Tool:** potrace

**Command:**
```bash
potrace "input.bmp" -s -o "output.svg"
```

**Algorithm:** Potrace traces bitmap edges to vector paths.

**Best For:** High-contrast, simple shapes, solid colours.

**Poor For:** Anti-aliased edges, gradients, photographic content, fine detail.

**Parameters:**
- `-s` — SVG output format
- Default: black-on-white tracing, single colour

### PNG (Raster)

**Path:** `source/flags/<cat>/flag.png` → `build/<cat>/flag.svg`

**Pipeline:** PNG → BMP → SVG

**Step 1: PNG → BMP (ImageMagick)**
```bash
convert "input.png" "temp.bmp"
```

**Step 2: BMP → SVG (potrace)**
```bash
potrace "temp.bmp" -s -o "output.svg"
```

**Cleanup:** Temporary BMP removed after conversion.

**Limitations:** Same as BMP — potrace traces edges, loses anti-aliasing, gradients.

**Best For:** Simple pixel art, high-contrast logos, solid shapes.

### XCF (GIMP Native)

**Path:** `source/flags/<cat>/flag.xcf` → `build/<cat>/flag.svg`

**Pipeline:** XCF → PNG → BMP → SVG

**Step 1: XCF → PNG (GIMP Python-Fu)**
```bash
execute-gimp-script-file "xcf_to_png" \
    INPUT_IMAGE_PATH "input.xcf" \
    OUTPUT_IMAGE_PATH "temp.png"
```
- Loads XCF, merges visible layers, saves PNG

**Step 2: PNG → BMP (ImageMagick)**
```bash
convert "temp.png" "temp.bmp"
```

**Step 3: BMP → SVG (potrace)**
```bash
potrace "temp.bmp" -s -o "output.svg"
```

**Cleanup:** Temporary PNG and BMP removed.

**Use Case:** Layered designs with effects that need GIMP to flatten.

**Limitations:** Longest path, most quality loss (layer merge → raster → trace).

## Stage 2: SVG → PNG (Three Resolutions)

### Common SVG Rendering (svg_to_png.py)

**Function:** `render_flag(source_path, output_path, output_size)`

**Process:**
1. Load SVG directly through `file-svg-load` at the target size, disregarding the ratio
2. Merge the imported layers into a single flag layer
3. Sample the corner colour and remove it with colour to alpha
4. Lock the alpha and repaint the opaque area white
5. Merge visible layers
6. Save PNG

### Resolution-Specific Details

#### Main Flag (128px)

**Call:** `render_flag(svg, build_main.png, 128)`

**Output:** `build/<cat>/<source>.png` (128×128)

**Purpose:** Primary flag emblem for empire customisation, diplomacy UI.

**Bevel:** Applied in Stage 3.

#### Map Flag (256px)

**Call:** `render_flag(svg, build_map.png, 256)`

**Output:** `build/<cat>/map/<source>.png` (256×256)

**Purpose:** Galaxy map flag display.

**Bevel:** **NOT applied** — flat rendering for map clarity.

#### Small Flag (24px)

**Call:** `render_flag(svg, build_small.png, 24)`

**Output:** `build/<cat>/small/<source>.png` (24×24)

**Purpose:** UI icons, fleet lists, small UI elements.

**Bevel:** Applied in Stage 3.

### SVG Import Behaviour

| SVG Feature | Support |
|-------------|---------|
| Basic shapes (rect, circle, path) | Full |
| Gradients (linear, radial) | Partial |
| Patterns | Limited |
| Text | Font-dependent |
| Embedded images | Supported |
| External references | Not supported |
| Animations | Not supported |
| Filters (blur, etc.) | Limited |

### Background Handling

The script removes the flat background colour that SVG exports usually bake in:

```python
background_colour = pick_colour(image, flag_layer, 3.0, 0.0)
remove_colour(flag_layer, background_colour)
```

**Assumption:** Flag emblem on a solid background (usually black or white).

**Failure Mode:** Complex backgrounds not removed — may show in output.

## Stage 3: Gradient Bevel Application

### Algorithm (gradient_bevel.py)

```
INPUT: PNG with alpha channel (flag emblem on transparent)
OUTPUT: PNG with 3D bevel effect

1. Load PNG as image
2. Create a black "Relief" layer
3. Paint the flag silhouette onto the Relief layer in white
4. Apply Gaussian blur to the Relief layer to round the silhouette edges
5. Apply emboss to the Relief layer for directional relief shading
6. Erase everything outside the flag shape
7. Create a "Colour" layer with a radial gold gradient, clipped to the flag shape
8. Remove the original flag layer
9. Merge visible layers
10. Save PNG
```

### Bevel Parameters (Defaults)

| Parameter | Value | Effect |
|-----------|-------|--------|
| `BLUR_RADIUS` | 2.5 | Gaussian blur for the relief silhouette |
| `RELIEF_AZIMUTH` | 115.0 | Emboss light direction |
| `RELIEF_ELEVATION` | 40.0 | Emboss light elevation |
| `RELIEF_DEPTH` | 5 | Emboss depth |

### Colour Gradients

| Layer | Highlight (FG) | Shadow (BG) |
|-------|----------------|-------------|
| Relief | White (255,255,255) | Black (0,0,0) |
| Colour Overlay | Gold (178,164,136) | Dark Gold (113,82,9) |

### Visual Result

- **Raised appearance** — emblem looks embossed
- **Metallic sheen** — gold gradient on colour overlay
- **Depth perception** — highlight/shadow from directional light
- **Consistent style** — all flags share bevel parameters

### Why Bevel on Main & Small Only?

| Variant | Bevel? | Reason |
|---------|--------|--------|
| Main (128px) | Yes | Primary display, benefits from 3D look |
| Map (256px) | No | Flat better for map readability, no visual clutter |
| Small (24px) | Yes | Adds definition at tiny size |

## Stage 4: PNG → DDS Export

### Export Function (png_to_dds.py)

**Function:** `convert_image(source_path, output_path)`

**Process:**
1. Load PNG
2. Call `file-dds-export` with `compression-format` set to `none`
3. Save DDS

### DDS Export Settings

```python
export_dds(image, output_path)
# Equivalent to:
#   run_procedure('file-dds-export', {
#       'image': image,
#       'file': Gio.File.new_for_path(output_path),
#       'compression-format': 'none',
#   })
```

### Effective Settings

| Setting | Value | Notes |
|---------|-------|-------|
| Compression | Uncompressed BGRA8 | 32bpp, no lossy compression |
| Mipmaps | None | Single level only |
| Colour Space | Linear | No sRGB conversion |
| Alpha | Straight | Not premultiplied |
| Normal Map | No | Standard texture |

**Note:** The 59 background textures under `source/backgrounds/` are also uncompressed BGRA8 DDS files, so the generated flags match the shipped format.

For 24×24 small flag: identical output size

## Conversion Quality Considerations

### Vector → Raster → Vector → Raster (PNG/XCF/BMP sources)

**Quality Loss Points:**
1. **Rasterisation** (SVG → PNG at target size) — minimal if SVG source
2. **Potrace tracing** (PNG/BMP/XCF → SVG) — major loss for complex images
3. **Re-rasterisation** (SVG → PNG) — minimal
4. **Bevel** — adds effect, not loss
5. **DDS export** — lossless (uncompressed BGRA8)

**Best Quality Path:** SVG source → direct to all three PNG sizes → DDS

**Worst Quality Path:** XCF → PNG → BMP → SVG → PNG → DDS (multiple raster/vector transitions)

### Format Recommendations

| Source Type | Recommended Format | Reason |
|-------------|-------------------|--------|
| New designs | SVG | Vector, scalable, single source |
| Existing raster | PNG (clean, high-contrast) | Better than BMP/XCF for tracing |
| Layered GIMP | XCF | Preserves layers for editing |
| Legacy AI | AI | If SVG not available |
| Simple bitmap | BMP | Direct to potrace |

## Per-Format Conversion Summary

| Source | SVG Conversion | PNG Renders | Bevel | DDS Exports | GIMP Calls |
|--------|----------------|-------------|-------|-------------|------------|
| SVG | Copy (0) | 3 | 2 | 3 | 8 |
| AI | Inkscape (1) | 3 | 2 | 3 | 8 |
| BMP | Potrace (1) | 3 | 2 | 3 | 8 |
| PNG | IM+Potrace (2) | 3 | 2 | 3 | 8 |
| XCF | GIMP+IM+Potrace (3) | 3 | 2 | 3 | 8 |

**GIMP Calls per Asset:** Always 8 (3 svg_to_png + 2 gradient_bevel + 3 png_to_dds)

**Additional Calls for XCF:** +1 (xcf_to_png in conversion stage)

## Intermediate File Locations

```
build/<category>/
├── <source_name>.svg              # Stage 1 output
├── <source_name>.png              # Stage 2 main (128px), bevel applied in place
├── map/
│   ├── <source_name>.png          # Stage 2 map (256px)
│   └── (no bevel)
└── small/
    └── <source_name>.png          # Stage 2 small (24px), bevel applied in place
```

## Cleanup

**Automatic:** Temporary files (BMP, intermediate PNG) removed after each conversion function.

**Persistent:** `build/` directory retains all intermediates for incremental builds.

**Full Clean:** `rm -rf build out` removes all generated files.

## Debugging Conversion Issues

### Check Intermediate Files

```bash
# After build, inspect build/<category>/
ls -la build/human/
# Should see: flag.svg, flag.png, map/flag.png, small/flag.png
```

### Test Individual Stages

```bash
# Test SVG → PNG (128px)
env GIMP_SCRIPT_INPUT_IMAGE_PATH="build/human/flag.svg" \
    GIMP_SCRIPT_OUTPUT_IMAGE_PATH="/tmp/test_128.png" \
    GIMP_SCRIPT_OUTPUT_IMAGE_SIZE="128" \
    gimp -i --batch-interpreter=python-fu-eval \
    -b "import sys; sys.path.insert(0, 'source/scripts'); exec(open('source/scripts/svg_to_png.py').read())" --quit

# Test bevel
env GIMP_SCRIPT_IMAGE_PATH="/tmp/test_128.png" \
    gimp -i --batch-interpreter=python-fu-eval \
    -b "import sys; sys.path.insert(0, 'source/scripts'); exec(open('source/scripts/gradient_bevel.py').read())" --quit

# Test DDS export
env GIMP_SCRIPT_INPUT_IMAGE_PATH="/tmp/test_128.png" \
    GIMP_SCRIPT_OUTPUT_IMAGE_PATH="/tmp/test.dds" \
    gimp -i --batch-interpreter=python-fu-eval \
    -b "import sys; sys.path.insert(0, 'source/scripts'); exec(open('source/scripts/png_to_dds.py').read())" --quit
```

### Common Issues

| Symptom | Likely Cause | Check |
|---------|--------------|-------|
| Flag invisible | Alpha channel lost | Verify PNG has transparency before bevel |
| Bevel too strong/weak | Parameters | Adjust `BLUR_RADIUS`, `RELIEF_DEPTH`, and `RELIEF_ELEVATION` in gradient_bevel.py |
| Map flag has bevel | Logic error | Verify map path skips bevel in build.sh |
| DDS won't load | Export procedure | Verify GIMP reports `file-dds-export`; try opening the DDS in GIMP |
| Colours wrong | Colour space | DDS saved linear, game expects sRGB? |
| Jagged edges | Potrace tracing | Use SVG source instead of PNG/BMP |