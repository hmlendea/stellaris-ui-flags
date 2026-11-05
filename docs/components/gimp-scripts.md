# GIMP Script-fu Scripts

## Overview

The build pipeline uses four GIMP Script-fu (Scheme/Lisp) scripts for image processing operations that require GIMP's advanced capabilities. These scripts are invoked via GIMP's batch mode (`gimp -i -b "(script-call ...)" -b "(gimp-quit 0)"`).

## Script Inventory

| Script | Purpose | Invoked By | Input | Output |
|--------|---------|------------|-------|--------|
| `gradient-bevel.lisp` | Applies 3D gradient bevel effect | `apply-gradient-bevel` | PNG | PNG (with bevel) |
| `png-to-dds.lisp` | Exports PNG to DDS format | `png-to-dds` | PNG | DDS |
| `svg-to-png.lisp` | Renders SVG to PNG at specified size | `svg-to-png` | SVG | PNG |
| `xcf-to-png.lisp` | Exports XCF (GIMP native) to PNG | `xcf-to-png` / `xcf-to-svg` | XCF | PNG |

## Script Details

### gradient-bevel.lisp

**Purpose:** Applies a 3D bevel effect with gradient shading to a flag emblem, creating a raised/embossed appearance.

**Location:** `source/scripts/gradient-bevel.lisp`

**Function Signature:**
```lisp
(define (gradient-bevel inputPath outputPath)
```

**Parameters:**
- `inputPath` — Path to input PNG file
- `outputPath` — Path for output PNG file

**Algorithm:**

```
1. Load input PNG as image
2. Get image dimensions (width, height)
3. Create "Logo" layer from image (base emblem)
4. Create "Colour Overlay" layer (solid colour fill)
5. Apply bevel to Logo layer:
   a. Alpha to selection
   b. Selection grow by bevel-size
   c. Create bump map from selection
   d. Apply bump map to Logo layer
   e. Apply gradient (white→grey) for highlight/shadow
6. Apply bevel to Colour Overlay layer:
   a. Alpha to selection
   b. Selection grow by bevel-size
   c. Create bump map
   d. Apply bump map
   e. Apply gradient (gold→dark gold)
7. Merge layers
8. Save as PNG
```

**Key Constants (in script):**
```lisp
(bevel-size 22)        ; Bevel size in pixels
(bevel-width 2.5)      ; Gaussian blur radius for bump map
(bevel-height 40)      ; Bump map height (emboss depth)
(indentX (+ bevel-size 12))
(indentY (+ bevel-size (/ height 8)))
```

**Colour Stops:**

| Layer | Highlight (Foreground) | Shadow (Background) |
|-------|------------------------|---------------------|
| Logo | White (255,255,255) | Grey (127,127,127) |
| Colour Overlay | Gold (178,164,136) | Dark Gold (113,82,9) |

**GIMP PDB Functions Used:**
- `gimp-file-load` — Load PNG
- `gimp-layer-new-from-drawable` — Create layer copy
- `gimp-image-add-layer` — Add layer to image
- `gimp-selection-layer-alpha` — Alpha to selection
- `gimp-selection-grow` — Grow selection
- `gimp-edit-fill` — Fill with foreground/background
- `plug-in-bump-map` — Apply bump mapping
- `gimp-gradient-segment-add-...` — Create custom gradients
- `gimp-edit-blend` — Apply gradient blend
- `gimp-image-merge-visible-layers` — Flatten
- `gimp-file-save` — Save PNG

**Modification Points:**
- Bevel size/depth: Change `bevel-size`, `bevel-height`
- Bevel colours: Modify foreground/background RGB values
- Gradient profile: Adjust gradient segment endpoints

### png-to-dds.lisp

**Purpose:** Exports a PNG image to DDS format with Stellaris-compatible compression settings.

**Location:** `source/scripts/png-to-dds.lisp`

**Function Signature:**
```lisp
(define (png-to-dds inputPath outputPath)
```

**Parameters:**
- `inputPath` — Path to input PNG file
- `outputPath` — Path for output DDS file

**Export Settings (hardcoded in `file-dds-save` call):**
```lisp
(file-dds-save RUN-NONINTERACTIVE image drawable
               outputPath outputPath
               0  ; compression: 0 = DXT1, 1 = DXT3, 2 = DXT5, 3 = BC4, 4 = BC5, 5 = BC7
               0  ; mipmaps: 0 = generate
               0  ; normal map: 0 = no
               0  ; gamma correction: 0 = no
               0  ; sRGB: 0 = linear
               0  ; premultiply alpha: 0 = no
               0  ; flip Y: 0 = no
               0  ; unused
               1.0 ; mipmap bias
               0  ; unused
               0  ; unused
               0.5) ; sharpen filter
```

**Effective Settings:**
- **Compression:** DXT1 (BC1) — no alpha, or DXT5 (BC3) with alpha
- **Mipmaps:** Auto-generated
- **Colour Space:** Linear (no sRGB conversion)
- **Alpha:** Premultiplied: No

**Note:** The DDS plug-in automatically selects DXT1 vs DXT5 based on alpha channel presence.

**GIMP PDB Functions Used:**
- `gimp-file-load` — Load PNG
- `file-dds-save` — Save DDS (from DDS plug-in)

**Modification Points:**
- Compression format: Change first parameter (0-5)
- Mipmap generation: Change second parameter
- Normal map flag: Change third parameter
- Sharpen filter: Change last parameter

### svg-to-png.lisp

**Purpose:** Renders an SVG file to a PNG at a specified pixel size, handling background transparency and colour-to-alpha conversion.

**Location:** `source/scripts/svg-to-png.lisp`

**Function Signature:**
```lisp
(define (svg-to-png inputPath outputPath outputSize)
```

**Parameters:**
- `inputPath` — Path to input SVG file
- `outputPath` — Path for output PNG file
- `outputSize` — Target dimension in pixels (square: width = height = outputSize)

**Algorithm:**
```
1. Load SVG as image (imports as vector layers)
2. Get imported image dimensions
3. Calculate scale factor: outputSize / max(width, height)
4. Scale image to fit outputSize (maintaining aspect ratio)
5. Create new square image (outputSize x outputSize)
6. Copy scaled SVG content to new image (centered)
7. If background layer exists and is solid:
   a. Apply colour-to-alpha to make background transparent
8. Merge visible layers
9. Save as PNG
```

**Key Operations:**
- **SVG Import:** Uses GIMP's SVG import plug-in
- **Scaling:** `gimp-image-scale-full` with interpolation
- **Centering:** Calculates offset to center non-square SVGs
- **Background Removal:** `plug-in-colortoalpha` on bottom layer if solid colour

**GIMP PDB Functions Used:**
- `gimp-file-load` — Load SVG (triggers SVG import)
- `gimp-image-scale-full` — Scale with interpolation
- `gimp-image-new` — Create target square image
- `gimp-layer-new-from-drawable` — Copy layers
- `gimp-image-insert-layer` — Add layers to new image
- `plug-in-colortoalpha` — Remove solid background
- `gimp-image-merge-visible-layers` — Flatten
- `gimp-file-save` — Save PNG

**Modification Points:**
- Output size: Passed as parameter (128, 256, or 24)
- Interpolation method: Change in `gimp-image-scale-full`
- Background removal: Modify colour-to-alpha threshold

### xcf-to-png.lisp

**Purpose:** Exports a GIMP XCF file (native format with layers) to a flat PNG.

**Location:** `source/scripts/xcf-to-png.lisp`

**Function Signature:**
```lisp
(define (xcf-to-png inputPath outputPath)
```

**Parameters:**
- `inputPath` — Path to input XCF file
- `outputPath` — Path for output PNG file

**Algorithm:**
```
1. Load XCF file (preserves all layers)
2. Merge all visible layers (flatten)
3. Save as PNG
```

**GIMP PDB Functions Used:**
- `gimp-xcf-load` — Load XCF (native loader)
- `gimp-image-merge-visible-layers` — Flatten (CLIP-TO-IMAGE)
- `gimp-file-save` — Save PNG

**Modification Points:**
- Layer merge mode: Change `CLIP-TO-IMAGE` to `EXPAND-AS-NECESSARY`
- Output format: Could save as other formats

## Invocation Pattern

All scripts invoked via GIMP batch mode from `build.sh`:

```bash
# Pattern
"${GIMP_TOOL_PATH}" -i -b "(script-function \"input\" \"output\" params)" -b "(gimp-quit 0)"

# Examples
"${GIMP_TOOL_PATH}" -i -b "(gradient-bevel \"in.png\" \"out.png\")" -b "(gimp-quit 0)"
"${GIMP_TOOL_PATH}" -i -b "(png-to-dds \"in.png\" \"out.dds\")" -b "(gimp-quit 0)"
"${GIMP_TOOL_PATH}" -i -b "(svg-to-png \"in.svg\" \"out.png\" 128)" -b "(gimp-quit 0)"
"${GIMP_TOOL_PATH}" -i -b "(xcf-to-png \"in.xcf\" \"out.png\")" -b "(gimp-quit 0)"
```

**Flags:**
- `-i` — No interface (batch mode)
- `-b` — Batch command (can repeat)
- `(gimp-quit 0)` — Exit GIMP after commands

## Dependencies

### GIMP Version
- **Minimum:** GIMP 2.10+
- **Tested:** GIMP 2.10, 2.99 (development)

### Required Plug-ins
| Plug-in | Purpose | Package (Debian/Ubuntu) |
|---------|---------|-------------------------|
| DDS | `file-dds-save` | `gimp-dds` |
| SVG Import | `gimp-file-load` for SVG | `gimp` (built-in) |
| Colour to Alpha | `plug-in-colortoalpha` | `gimp` (built-in) |
| Bump Map | `plug-in-bump-map` | `gimp` (built-in) |

### Flatpak Support
Scripts work with Flatpak GIMP (`org.gimp.GIMP`) when invoked via the detected Flatpak path.

## Error Handling

### Script-Level
- No explicit error handling in scripts
- GIMP returns non-zero exit on failure
- Build script continues on individual asset failure

### Common Failure Modes

| Script | Failure Cause | Symptom |
|--------|---------------|---------|
| gradient-bevel | Missing bump-map plug-in | GIMP error, no output |
| png-to-dds | Missing DDS plug-in | "Unknown file format" |
| svg-to-png | Invalid SVG | Import fails, empty image |
| xcf-to-png | Corrupt XCF | Load fails |

### Debugging
Run script interactively in GIMP:
1. Open GIMP
2. Filters → Script-Fu → Console
3. Paste script definition
4. Call function manually: `(gradient-bevel "test.png" "out.png")`

## Performance

| Script | Typical Time | Bottleneck |
|--------|--------------|------------|
| gradient-bevel | 0.5-2s | Bump map calculation |
| png-to-dds | 0.1-0.5s | DDS compression |
| svg-to-png | 0.5-1s | SVG import + scaling |
| xcf-to-png | 0.2-0.5s | Layer merging |

**Total per asset:** ~1-4 seconds (dominated by GIMP startup + script execution)

## Customisation Guide

### Adjusting Bevel Appearance

Edit `source/scripts/gradient-bevel.lisp`:

```lisp
; Larger bevel
(bevel-size 30)
(bevel-height 60)

; Softer bevel
(bevel-width 5.0)

; Different highlight colour
(gimp-context-set-foreground '(255 255 200))  ; Warm white
(gimp-context-set-background '(100 100 100))  ; Darker grey

; Different overlay colour
(gimp-context-set-foreground '(200 180 100))  ; Brighter gold
(gimp-context-set-background '(80 50 0))      ; Darker gold
```

### Changing DDS Compression

Edit `source/scripts/png-to-dds.lisp`:

```lisp
; Use DXT5 (BC3) explicitly for alpha
(file-dds-save ... 2 0 0 0 0 0 0 0 1.0 0 0 0.5)
;                    ↑
;              compression: 2 = DXT5

; Disable mipmaps
(file-dds-save ... 0 1 0 0 0 0 0 0 1.0 0 0 0.5)
;                    ↑
;              mipmaps: 1 = no mipmaps
```

### Modifying SVG Rendering

Edit `source/scripts/svg-to-png.lisp`:

```lisp
; Change interpolation (0=none, 1=linear, 2=cubic, 3=lanczos)
(gimp-image-scale-full image width height 3)  ; Lanczos (high quality)

; Disable background removal
; Comment out plug-in-colortoalpha section
```

## Testing Scripts

### Unit Test Pattern

```bash
# Test gradient-bevel
cp source/flags/human/some-flag.png /tmp/test.png
gimp -i -b "(gradient-bevel \"/tmp/test.png\" \"/tmp/test_bevel.png\")" -b "(gimp-quit 0)"
# Verify /tmp/test_bevel.png exists and has bevel

# Test png-to-dds
gimp -i -b "(png-to-dds \"/tmp/test_bevel.png\" \"/tmp/test.dds\")" -b "(gimp-quit 0)"
# Verify /tmp/test.dds opens in GIMP

# Test svg-to-png
gimp -i -b "(svg-to-png \"source/flags/human/flag.svg\" \"/tmp/test_128.png\" 128)" -b "(gimp-quit 0)"
# Verify 128x128 PNG

# Test xcf-to-png
gimp -i -b "(xcf-to-png \"source/flags/mechanical/gear.xcf\" \"/tmp/test.png\")" -b "(gimp-quit 0)"
# Verify PNG output
```

## Version History

| Version | Changes |
|---------|---------|
| Initial | Basic bevel, DDS export, SVG render, XCF export |
| Current | Optimised bevel parameters, fixed SVG centering, added colour-to-alpha |

## Known Limitations

1. **No parallel execution** — GIMP invoked per asset
2. **Fixed bevel parameters** — Same for all flags (no per-flag customisation)
3. **DXT1/DXT5 auto-selection** — Cannot force specific compression
4. **SVG import limitations** — Complex SVG features may not render
5. **No colour management** — Assumes sRGB input, linear output