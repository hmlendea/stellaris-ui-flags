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
│   SVG ──► GIMP (svg-to-png) ──► 128×128 PNG (main)                         │
│   SVG ──► GIMP (svg-to-png) ──► 256×256 PNG (map)                          │
│   SVG ──► GIMP (svg-to-png) ──►  24×24  PNG (small)                        │
│                                                                             │
│   Each invocation: independent GIMP process                                 │
└─────────────────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STAGE 3: BEVEL APPLICATION (main & small only)                              │
│                                                                             │
│   128px PNG ──► GIMP (gradient-bevel) ──► 128px PNG (beveled)              │
│    24px PNG ──► GIMP (gradient-bevel) ──►  24px PNG (beveled)              │
│   256px PNG ──► (NO BEVEL)                                                 │
│                                                                             │
│   Bevel: 3D emboss with gradient highlight/shadow                          │
└─────────────────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ STAGE 4: PNG → DDS EXPORT                                                   │
│                                                                             │
│   128px beveled PNG ──► GIMP (png-to-dds) ──► out/.../main/<name>.dds      │
│   256px flat PNG    ──► GIMP (png-to-dds) ──► out/.../map/<name>.dds       │
│    24px beveled PNG ──► GIMP (png-to-dds) ──► out/.../small/<name>.dds     │
│                                                                             │
│   DDS: BC1/BC3 compression, mipmaps, linear colour space                   │
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

**Step 1: XCF → PNG (GIMP Script-fu)**
```lisp
(xcf-to-png "input.xcf" "temp.png")
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

### Common SVG Rendering (svg-to-png.lisp)

**Function:** `svg-to-png(inputPath, outputPath, outputSize)`

**Process:**
1. Load SVG via GIMP's SVG import plug-in
2. Get imported dimensions
3. Calculate scale: `outputSize / max(width, height)`
4. Scale image maintaining aspect ratio
5. Create new square image `outputSize × outputSize`
6. Copy scaled content centered in new image
7. If bottom layer is solid colour: apply colour-to-alpha (transparency)
8. Merge visible layers
9. Save PNG

### Resolution-Specific Details

#### Main Flag (128px)

**Call:** `svg-to-png(svg, build_main.png, 128)`

**Output:** `build/<cat>/<source>.png` (128×128)

**Purpose:** Primary flag emblem for empire customisation, diplomacy UI.

**Bevel:** Applied in Stage 3.

#### Map Flag (256px)

**Call:** `svg-to-png(svg, build_map.png, 256)`

**Output:** `build/<cat>/map/<source>.png` (256×256)

**Purpose:** Galaxy map flag display.

**Bevel:** **NOT applied** — flat rendering for map clarity.

#### Small Flag (24px)

**Call:** `svg-to-png(svg, build_small.png, 24)`

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

The script attempts to remove solid-colour backgrounds:

```lisp
; If bottom layer is solid, make transparent
(plug-in-colortoalpha RUN-NONINTERACTIVE image bottom-layer background-colour)
```

**Assumption:** Flag emblem on solid background (usually white or transparent).

**Failure Mode:** Complex backgrounds not removed — may show in output.

## Stage 3: Gradient Bevel Application

### Algorithm (gradient-bevel.lisp)

```
INPUT: PNG with alpha channel (flag emblem on transparent)
OUTPUT: PNG with 3D bevel effect

1. Load PNG as image
2. Create "Logo" layer (copy of base)
3. Create "Colour Overlay" layer (solid fill)
4. FOR each layer (Logo, Colour Overlay):
   a. Alpha to selection (select non-transparent pixels)
   b. Grow selection by bevel-size (22px default)
   c. Create new layer from selection (bump map source)
   d. Fill with white
   e. Gaussian blur by bevel-width (2.5px)
   f. Apply bump map to target layer:
      - Height: bevel-height (40)
      - Light direction: calculated from indentX/indentY
   g. Apply gradient blend:
      - Logo: White → Grey (highlight → shadow)
      - Colour Overlay: Gold → Dark Gold
5. Merge layers
6. Save PNG
```

### Bevel Parameters (Defaults)

| Parameter | Value | Effect |
|-----------|-------|--------|
| `bevel-size` | 22 | Selection grow radius (bevel width) |
| `bevel-width` | 2.5 | Gaussian blur for bump map |
| `bevel-height` | 40 | Bump map height (emboss depth) |
| `indentX` | bevel-size + 12 | Light X offset |
| `indentY` | bevel-size + height/8 | Light Y offset |

### Colour Gradients

| Layer | Highlight (FG) | Shadow (BG) |
|-------|----------------|-------------|
| Logo | White (255,255,255) | Grey (127,127,127) |
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

### Export Function (png-to-dds.lisp)

**Function:** `png-to-dds(inputPath, outputPath)`

**Process:**
1. Load PNG
2. Call `file-dds-save` with fixed parameters
3. Save DDS

### DDS Export Parameters

```lisp
(file-dds-save RUN-NONINTERACTIVE image drawable
               outputPath outputPath
               0  ; compression: 0=DXT1, 1=DXT3, 2=DXT5, 3=BC4, 4=BC5, 5=BC7
               0  ; mipmaps: 0=generate
               0  ; normal map: 0=no
               0  ; gamma correction: 0=no
               0  ; sRGB: 0=linear
               0  ; premultiply alpha: 0=no
               0  ; flip Y: 0=no
               0  ; unused
               1.0 ; mipmap bias
               0  ; unused
               0  ; unused
               0.5) ; sharpen filter
```

### Effective Settings

| Setting | Value | Notes |
|---------|-------|-------|
| Compression | Auto (DXT1/BC1 or DXT5/BC3) | Based on alpha channel |
| Mipmaps | Generated | Full chain down to 1×1 |
| Colour Space | Linear | No sRGB conversion |
| Alpha | Straight | Not premultiplied |
| Normal Map | No | Standard texture |

### Compression Selection

| Input Alpha | Output Format | Use Case |
|-------------|---------------|----------|
| No alpha (opaque) | DXT1 (BC1) | 4bpp, 6:1 compression |
| Has alpha | DXT5 (BC3) | 8bpp, 4:1 compression |

**Note:** The DDS plug-in auto-detects alpha and selects format.

### Mipmap Chain

For 128×128 main flag:
```
Level 0: 128×128
Level 1:  64×64
Level 2:  32×32
Level 3:  16×16
Level 4:   8×8
Level 5:   4×4
Level 6:   2×2
Level 7:   1×1
```

For 256×256 map flag: 9 levels (256→1)

For 24×24 small flag: 5 levels (24→12→6→3→1)

## Conversion Quality Considerations

### Vector → Raster → Vector → Raster (PNG/XCF/BMP sources)

**Quality Loss Points:**
1. **Rasterisation** (SVG → PNG at target size) — minimal if SVG source
2. **Potrace tracing** (PNG/BMP/XCF → SVG) — major loss for complex images
3. **Re-rasterisation** (SVG → PNG) — minimal
4. **Bevel** — adds effect, not loss
5. **DDS compression** — lossy (DXT1/5)

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

**GIMP Calls per Asset:** Always 8 (3 svg-to-png + 2 gradient-bevel + 3 png-to-dds)

**Additional Calls for XCF:** +1 (xcf-to-png in conversion stage)

## Intermediate File Locations

```
build/<category>/
├── <source_name>.svg              # Stage 1 output
├── <source_name>.png              # Stage 2 main (128px)
├── <source_name>_bevel.png        # Stage 3 main
├── map/
│   ├── <source_name>.png          # Stage 2 map (256px)
│   └── (no bevel)
└── small/
    ├── <source_name>.png          # Stage 2 small (24px)
    └── <source_name>_bevel.png    # Stage 3 small
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
# Should see: flag.svg, flag.png, flag_bevel.png, map/flag.png, small/flag.png, small/flag_bevel.png
```

### Test Individual Stages

```bash
# Test SVG → PNG (128px)
gimp -i -b "(svg-to-png \"build/human/flag.svg\" \"/tmp/test_128.png\" 128)" -b "(gimp-quit 0)"

# Test bevel
gimp -i -b "(gradient-bevel \"/tmp/test_128.png\" \"/tmp/test_bevel.png\")" -b "(gimp-quit 0)"

# Test DDS export
gimp -i -b "(png-to-dds \"/tmp/test_bevel.png\" \"/tmp/test.dds\")" -b "(gimp-quit 0)"
```

### Common Issues

| Symptom | Likely Cause | Check |
|---------|--------------|-------|
| Flag invisible | Alpha channel lost | Verify PNG has transparency before bevel |
| Bevel too strong/weak | Parameters | Adjust `bevel-size`, `bevel-height` in gradient-bevel.lisp |
| Map flag has bevel | Logic error | Verify map path skips bevel in build.sh |
| DDS won't load | Compression | Verify GIMP DDS plug-in, try opening in GIMP |
| Colours wrong | Colour space | DDS saved linear, game expects sRGB? |
| Jagged edges | Potrace tracing | Use SVG source instead of PNG/BMP |