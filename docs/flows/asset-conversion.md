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
│ STAGE 2: SVG → THREE PNG RESOLUTIONS                                         │
│                                                                             │
│   SVG ──► rsvg-convert + ImageMagick (svg-to-png) ──► 128×128 PNG (main)     │
│   SVG ──► rsvg-convert + ImageMagick (svg-to-png) ──► 256×256 PNG (map)      │
│   SVG ──► rsvg-convert + ImageMagick (svg-to-png) ──►  24×24  PNG (small)    │
│                                                                             │
│   No GIMP session; about a hundred milliseconds for all three                 │
└─────────────────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STAGE 3: BATCHED BEVEL (main & small only)                                  │
│                                                                             │
│   128px PNG ─┐                                                              │
│              ├──► GIMP session (bevel_batch) ──► PNGs (beveled, in place)   │
│    24px PNG ─┘                                                              │
│   256px PNG ───► (NO BEVEL)                                                 │
│                                                                             │
│   Bevel: blurred silhouette emboss with gradient highlight/shadow           │
│   FLAG_BEVEL_BATCH_SIZE flags per session, FLAG_GIMP_CONCURRENCY at once    │
└─────────────────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STAGE 4: PNG → DDS EXPORT                                                   │
│                                                                             │
│   128px beveled PNG ──► python (png_to_dds) ──► out/.../main/<name>.dds     │
│   256px flat PNG    ──► python (png_to_dds) ──► out/.../map/<name>.dds      │
│    24px beveled PNG ──► python (png_to_dds) ──► out/.../small/<name>.dds    │
│                                                                             │
│   DDS: uncompressed BGRA8, no mipmaps, GIMP-compatible header               │
│   No GIMP session, so the stage costs a fraction of the others              │
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

### Common SVG Rendering (svg-to-png)

**Location:** the `svg-to-png` function in `build.sh`

**Process:**
1. Rasterise the SVG with `rsvg-convert` at the target size over a white background
2. Sample the background colour from the top-left corner
3. Take the difference from that colour as the alpha channel
4. Composite the alpha over an opaque white base, forcing PNG colour type 6

The white background matters: SVGs traced from bitmaps draw black shapes with no background
rectangle, so a transparent background renders black on black and the emblem disappears. Forcing the
colour type matters too, because a greyscale PNG is read as the wrong channels by the DDS writer.

### Resolution-Specific Details

#### Main Flag (128px)

**Call:** `svg-to-png <svg> build_main.png 128`

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
2. Duplicate the flag layer as a silhouette
3. Create a "Blur" layer and paint the silhouette onto it in white
4. Select the silhouette and apply a Gaussian blur to the Blur layer, then clear the selection
5. Apply a white-to-grey radial gradient to the flag layer
6. Apply Bump Map to the flag using the Blur layer as the height map
7. Offset, invert and dim the Blur layer to 50% opacity, then remove it
8. Create a "Colour" layer with a radial gold gradient, blended with Grain Merge and clipped to the flag shape
9. Keep the flag as the base layer
10. Merge visible layers
11. Save PNG
```

### Bevel Parameters (Defaults)

| Parameter | Value | Effect |
|-----------|-------|--------|
| `BLUR_RADIUS` | 2.5 | Gaussian blur for the height-map silhouette |
| `BUMP_AZIMUTH` | 115.0 | Bump-map light direction |
| `BUMP_ELEVATION` | 40.0 | Bump-map light elevation |
| `BUMP_DEPTH` | 5 | Bump-map depth |
| `BUMP_AMBIENT` | 0.15 | Bump-map ambient light |

### Colour Gradients

| Layer | Highlight (FG) | Shadow (BG) |
|-------|----------------|-------------|
| Blur | White (255,255,255) | Transparent |
| Flag | White (255,255,255) | Grey (127,127,127) |
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
1. Read the PNG dimensions and the four channels with ImageMagick
2. Reorder the channels to BGRA
3. Write the 128-byte `DDS ` header, then the pixels

### DDS Export Settings

```python
convert_image(source_path, output_path)
# Header: 128 bytes, byte-identical to file-dds-export with compression disabled
# Body:   raw BGRA, no mipmaps
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

**GIMP Calls per Asset:** 2 (the two `gradient_bevel` bevels). The SVG rasterisation and the three
DDS exports no longer use GIMP, which is why the build is several times faster.

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
rsvg-convert -w 128 -h 128 -b white -o /tmp/raw.png "build/human/flag.svg"
magick identify /tmp/raw.png

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
| Bevel too strong/weak | Parameters | Adjust `BLUR_RADIUS`, `BUMP_DEPTH`, and `BUMP_ELEVATION` in gradient_bevel.py |
| Map flag has bevel | Logic error | Verify map path skips bevel in build.sh |
| DDS won't load | Header fields | Compare the DDS header with a known-good file; the writer reproduces GIMP's exactly |
| Colours wrong | Colour space | DDS saved linear, game expects sRGB? |
| Jagged edges | Potrace tracing | Use SVG source instead of PNG/BMP |