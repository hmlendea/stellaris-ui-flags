# API Usage Examples

## Overview

This document provides concrete command examples for all build functions, GIMP scripts, and common operations. Use these as reference when debugging, extending, or testing the pipeline.

## Build Script Functions

### get-flag-file-name

```bash
# Source the function (or copy from build.sh)
source build.sh

# Default behaviour (no mapping)
get-flag-file-name "my-flag"
# Output: ui_my-flag

# With names.txt mapping
echo "my-flag=custom_name" > source/names.txt
get-flag-file-name "my-flag"
# Output: custom_name
```

### generate-mod-descriptor

```bash
# Root descriptor
generate-mod-descriptor "out/ui-flags.mod" "mod/ui-flags"

# Package descriptor
generate-mod-descriptor "out/ui-flags/descriptor.mod" "."
```

### Format Conversion Functions

```bash
# BMP → SVG
bmp-to-svg "source/flags/human/flag.bmp" "build/human/flag.svg"

# PNG → SVG (via BMP + potrace)
png-to-svg "source/flags/human/flag.png" "build/human/flag.svg"
```

### SVG → PNG Rendering

```bash
# Main (128px)
svg-to-png "build/human/flag.svg" "build/human/flag.png" 128

# Map (256px)
svg-to-png "build/human/flag.svg" "build/human/flag_map.png" 256

# Small (24px)
svg-to-png "build/human/flag.svg" "build/human/flag_small.png" 24
```

### Bevel Application

The bevel is applied in place, rewriting each intermediate PNG. The images are batched into shared
GIMP sessions so that the per-invocation start-up cost is paid once per batch.

```bash
# Bevel the main and small flags of several flags in one GIMP session
bevel-pngs "1" \
    "build/human/ui_flag.png" \
    "build/human/small/ui_flag.png" \
    "build/plantoid/ui_flag.png" \
    "build/plantoid/small/ui_flag.png"

# Retry whichever bevels are still missing after a session is killed
collect-unbeveled-pngs
bevel-pngs "2" "${FLAG_BEVEL_PATHS[@]}"
```

### PNG → DDS Export

```bash
# Main flag
png-to-dds "build/human/flag.png" "out/ui-flags/flags/human/ui_flag.dds"

# Map flag
png-to-dds "build/human/flag_map.png" "out/ui-flags/flags/human/map/ui_flag.dds"

# Small flag
png-to-dds "build/human/flag_small.png" "out/ui-flags/flags/human/small/ui_flag.dds"
```

---

## GIMP Python-Fu Direct Invocation

Parameters are supplied through `GIMP_SCRIPT_*` environment variables, and the script directory is added to the module search path so the shared modules resolve.

```bash
GIMP_DIRECTORY_PATH="source/scripts"
```

### svg-to-png (build.sh)

```bash
# Render SVG to PNG at specified size, over a white background
rsvg-convert -w 128 -h 128 -b white -o /tmp/raw.png "/path/to/input.svg"
BACKGROUND=$(magick /tmp/raw.png -format '%[pixel:p{3,0}]' info:)
magick /tmp/raw.png \( +clone -fill "$BACKGROUND" -colorize 100 \) \
    -compose Difference -composite -colorspace Gray /tmp/alpha.png
magick -size 128x128 xc:white /tmp/alpha.png -alpha off \
    -compose CopyOpacity -composite -type TrueColorAlpha \
    -define png:color-type=6 "/path/to/output.png"
```

### bevel_batch.py

```bash
# Apply the gradient bevel to a newline-separated batch, rewriting each PNG in place
env GIMP_SCRIPT_IMAGE_PATHS="build/human/ui_flag.png
build/human/small/ui_flag.png" \
    gimp -i --batch-interpreter=python-fu-eval \
    -b "import sys; sys.path.insert(0, '${GIMP_DIRECTORY_PATH}'); exec(open('${GIMP_DIRECTORY_PATH}/bevel_batch.py').read())" --quit

# Parameters:
#   GIMP_SCRIPT_IMAGE_PATHS — newline-separated PNG paths, each rewritten in place
```

### gradient_bevel.py

```bash
# Apply gradient bevel to a single PNG, rewriting it in place
env GIMP_SCRIPT_IMAGE_PATH="/path/to/input.png" \
    gimp -i --batch-interpreter=python-fu-eval \
    -b "import sys; sys.path.insert(0, '${GIMP_DIRECTORY_PATH}'); exec(open('${GIMP_DIRECTORY_PATH}/gradient_bevel.py').read())" --quit

# Parameters:
#   GIMP_SCRIPT_IMAGE_PATH — PNG path, rewritten in place
# Parameters (hardcoded in script):
#   BLUR_RADIUS: 2.5
#   BUMP_AZIMUTH: 115.0
#   BUMP_ELEVATION: 40.0
#   BUMP_DEPTH: 5
#   Relief: white silhouette on black
#   Colour Overlay: gold (178,164,136) to dark gold (113,82,9)
```

### png_to_dds.py

```bash
# Export PNG to DDS
env GIMP_SCRIPT_INPUT_IMAGE_PATH="/path/to/input.png" \
    GIMP_SCRIPT_OUTPUT_IMAGE_PATH="/path/to/output.dds" \
    python3 "${GIMP_DIRECTORY_PATH}/png_to_dds.py"

# Parameters:
#   GIMP_SCRIPT_INPUT_IMAGE_PATH  — Input PNG path
#   GIMP_SCRIPT_OUTPUT_IMAGE_PATH — Output DDS path
# Parameters (hardcoded in script):
#   Compression: none (uncompressed BGRA8)
#   Mipmaps: none
```

---

## Complete Asset Pipeline (Manual)

For a single flag `source/flags/human/earth.svg` → output `ui_earth`. The scripts are invoked through the same helper as `build.sh`, so define it first:

```bash
SOURCE_SCRIPTS_DIR_PATH="source/scripts"

run-gimp-script() {
    local SCRIPT_LABEL="${1}" && shift
    local SCRIPT_PATH="${SOURCE_SCRIPTS_DIR_PATH}/${SCRIPT_LABEL}.py"
    local -a SCRIPT_ARGUMENTS=()

    while [ "$#" -gt 0 ]; do
        SCRIPT_ARGUMENTS+=("GIMP_SCRIPT_${1}=${2}")
        shift 2
    done

    env "${SCRIPT_ARGUMENTS[@]}" gimp -i --batch-interpreter=python-fu-eval \
        -b "import sys; sys.path.insert(0, '${SOURCE_SCRIPTS_DIR_PATH}'); exec(open('${SCRIPT_PATH}').read())" --quit
}
```

```bash
# 1. SVG already exists, copy to build/
cp source/flags/human/earth.svg build/human/earth.svg

# 2. Render 128px PNG
svg-to-png "build/human/earth.svg" "build/human/earth.png" 128

# 3. Render 256px PNG (map)
svg-to-png "build/human/earth.svg" "build/human/earth_map.png" 256

# 4. Render 24px PNG (small)
svg-to-png "build/human/earth.svg" "build/human/earth_small.png" 24

# 5. Apply the bevel to main and small in one GIMP session (in place)
bevel-pngs "1" "build/human/earth.png" "build/human/earth_small.png"

# 6. Export main, map and small DDS
env GIMP_SCRIPT_INPUT_IMAGE_PATH="build/human/earth.png" \
    GIMP_SCRIPT_OUTPUT_IMAGE_PATH="out/ui-flags/flags/human/ui_earth.dds" \
    python3 "${SOURCE_SCRIPTS_DIR_PATH}/png_to_dds.py"
env GIMP_SCRIPT_INPUT_IMAGE_PATH="build/human/earth_map.png" \
    GIMP_SCRIPT_OUTPUT_IMAGE_PATH="out/ui-flags/flags/human/map/ui_earth.dds" \
    python3 "${SOURCE_SCRIPTS_DIR_PATH}/png_to_dds.py"
env GIMP_SCRIPT_INPUT_IMAGE_PATH="build/human/earth_small.png" \
    GIMP_SCRIPT_OUTPUT_IMAGE_PATH="out/ui-flags/flags/human/small/ui_earth.dds" \
    python3 "${SOURCE_SCRIPTS_DIR_PATH}/png_to_dds.py"
```

---

## Build Invocation

```bash
# Standard build
./build.sh 1.2.3

# With debug tracing
bash -x ./build.sh 1.2.3 2>&1 | tee build.log

# Capture output only
./build.sh 1.2.3 2>&1 | tee build.log

# Full rebuild
rm -rf build out && ./build.sh 1.2.3
```

---

## Adding Content

### Add a Flag

```bash
# 1. Place source
cp my-flag.svg source/flags/human/my-flag.svg

# 2. Optional: custom output name
echo "my-flag=ui_custom_name" >> source/names.txt

# 3. Build (incremental)
./build.sh 1.2.3

# 4. Verify
ls -la out/ui-flags/flags/human/ui_custom_name.dds
ls -la out/ui-flags/flags/human/map/ui_custom_name.dds
ls -la out/ui-flags/flags/human/small/ui_custom_name.dds
```

### Add a Category

```bash
# 1. Create directory
mkdir source/flags/new_category

# 2. Add localisation
echo '    FLAG_CATEGORY_new_category:0 "New Category"' >> source/localisation.yml

# 3. Add flags
cp flag1.svg source/flags/new_category/
cp flag2.svg source/flags/new_category/

# 4. Build
./build.sh 1.2.3

# 5. Verify in game
```

### Add a Background

```bash
# 1. Place DDS
cp my-background.dds source/backgrounds/

# 2. Build (any build refreshes static content)
./build.sh 1.2.3

# 3. Verify
ls -la out/ui-flags/flags/backgrounds/my-background.dds
```

### Add a Colour

```bash
# 1. Edit colours.txt (add to colors = { ... } block)
cat >> source/colours.txt << 'EOF'
    my_colour = {
        hsv = { 0.5 0.8 0.9 }
        use_as_border_color = yes
        randomizable_combo = yes
    }
EOF

# 2. Build
./build.sh 1.2.3

# 3. Verify
grep my_colour out/ui-flags/flags/colors.txt
```

---

## Debugging Individual Stages

### Test SVG Rendering

```bash
svg-to-png "build/human/earth.svg" "/tmp/test.png" 128
# Check /tmp/test.png
```

### Test Bevel

```bash
bevel-pngs "test" "/tmp/test.png"
# Check /tmp/test.png and /tmp/test.png.beveled
```

### Test DDS Export

```bash
env GIMP_SCRIPT_INPUT_IMAGE_PATH="/tmp/test.png" \
    GIMP_SCRIPT_OUTPUT_IMAGE_PATH="/tmp/test.dds" \
    python3 "source/scripts/png_to_dds.py"
# Check /tmp/test.dds opens in GIMP
```

### Test Format Conversion

```bash
# BMP → SVG
bmp-to-svg "source/flags/human/flag.bmp" "/tmp/flag.svg"

# PNG → SVG
png-to-svg "source/flags/human/flag.png" "/tmp/flag.svg"
```

---

## Verification Commands

### Count Sources vs Outputs

```bash
for cat in source/flags/*/; do
    name=$(basename "$cat")
    src=$(find "$cat" -maxdepth 1 -type f | wc -l)
    out=$(find "out/ui-flags/flags/$name" -maxdepth 1 -name "*.dds" 2>/dev/null | wc -l)
    echo "$name: $src sources, $out outputs"
done
```

### Verify Three Variants Per Flag

```bash
for dds in out/ui-flags/flags/*/*.dds; do
    base=$(basename "$dds")
    cat=$(dirname "$dds" | xargs basename)
    [[ -f "out/ui-flags/flags/$cat/map/$base" ]] || echo "MISSING map: $cat/$base"
    [[ -f "out/ui-flags/flags/$cat/small/$base" ]] || echo "MISSING small: $cat/$base"
done
```

### Check Descriptors

```bash
cat out/ui-flags.mod
cat out/ui-flags/descriptor.mod
```

### Check Localisation

```bash
grep FLAG_CATEGORY out/ui-flags/ui-flags_l_english.yml
```

### Check Colours

```bash
cat out/ui-flags/flags/colors.txt
```

---

## Release Commands

### Create Release Zip

```bash
cd out
zip -r ../ui-flags-1.2.3.zip ui-flags/
```

### Local Install (Symlink)

```bash
MOD_DIR=~/.local/share/Paradox\ Interactive/Stellaris/mod
ln -sf "$(pwd)/out/ui-flags" "$MOD_DIR/ui-flags"
ln -sf "$(pwd)/out/ui-flags.mod" "$MOD_DIR/ui-flags.mod"
```

### Local Install (Copy)

```bash
MOD_DIR=~/.local/share/Paradox\ Interactive/Stellaris/mod
cp -r out/ui-flags "$MOD_DIR/"
cp out/ui-flags.mod "$MOD_DIR/"
```

---

## Tool Verification

```bash
# Check all tools
which magick rsvg-convert potrace gimp python3

# Check Flatpak paths
ls /var/lib/flatpak/exports/bin/org.gimp.GIMP

# Check the DDS export
env GIMP_SCRIPT_INPUT_IMAGE_PATH="/tmp/test.png" \
    GIMP_SCRIPT_OUTPUT_IMAGE_PATH="/tmp/test.dds" \
    python3 "source/scripts/png_to_dds.py" 2>&1 | grep -i error
# No output = working
```

---

## Common Patterns

### Per-Asset Rebuild

```bash
# Delete outputs for one flag
rm out/ui-flags/flags/human/ui_earth.dds
rm out/ui-flags/flags/human/map/ui_earth.dds
rm out/ui-flags/flags/human/small/ui_earth.dds

# Rebuild
./build.sh 1.2.3
```

### Full Clean Rebuild

```bash
rm -rf build out
./build.sh 1.2.3
```

### Debug Build with Tracing

```bash
bash -x ./build.sh 1.2.3 2>&1 | tee trace.log
# Search trace.log for specific asset or function
grep "earth" trace.log
```

### Capture All Errors

```bash
./build.sh 1.2.3 2>&1 | tee build.log
grep -iE "error|fail|execution error" build.log
```