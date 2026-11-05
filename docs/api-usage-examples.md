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

# XCF → SVG (via PNG → BMP → potrace)
xcf-to-svg "source/flags/human/flag.xcf" "build/human/flag.svg"

# AI → SVG (via Inkscape)
ai-to-svg "source/flags/human/flag.ai" "build/human/flag.svg"
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

```bash
# Main flag bevel
apply-gradient-bevel "build/human/flag.png" "build/human/flag_beveled.png"

# Small flag bevel
apply-gradient-bevel "build/human/flag_small.png" "build/human/flag_small_beveled.png"
```

### PNG → DDS Export

```bash
# Main flag
png-to-dds "build/human/flag_beveled.png" "out/ui-flags/flags/human/ui_flag.dds"

# Map flag
png-to-dds "build/human/flag_map.png" "out/ui-flags/flags/human/map/ui_flag.dds"

# Small flag
png-to-dds "build/human/flag_small_beveled.png" "out/ui-flags/flags/human/small/ui_flag.dds"
```

### XCF → PNG (Direct)

```bash
# For XCF sources that skip SVG intermediate (not used in current pipeline)
xcf-to-png "source/flags/human/flag.xcf" "build/human/flag.png"
```

---

## GIMP Script-fu Direct Invocation

### svg-to-png.lisp

```bash
# Render SVG to PNG at specified size
gimp -i -b "(svg-to-png \"/path/to/input.svg\" \"/path/to/output.png\" 128)" -b "(gimp-quit 0)"

# Arguments:
#   1. Input SVG path (string)
#   2. Output PNG path (string)
#   3. Size in pixels (integer) — square output
```

### apply-gradient-bevel.lisp

```bash
# Apply gradient bevel to PNG
gimp -i -b "(apply-gradient-bevel \"/path/to/input.png\" \"/path/to/output.png\")" -b "(gimp-quit 0)"

# Arguments:
#   1. Input PNG path (string)
#   2. Output PNG path (string)
# Parameters (hardcoded in script):
#   bevel-size: 22
#   bevel-width: 2.5
#   bevel-height: 40
#   Logo gradient: white → grey
#   Colour Overlay: gold (178,164,136) → dark gold (113,82,9)
```

### png-to-dds.lisp

```bash
# Export PNG to DDS
gimp -i -b "(png-to-dds \"/path/to/input.png\" \"/path/to/output.dds\")" -b "(gimp-quit 0)"

# Arguments:
#   1. Input PNG path (string)
#   2. Output DDS path (string)
# Parameters (hardcoded in script):
#   Compression: DXT1 (opaque) / DXT5 (alpha) auto
#   Mipmaps: enabled
#   Texture type: linear
```

### xcf-to-png.lisp

```bash
# Convert XCF to PNG (merge visible layers)
gimp -i -b "(xcf-to-png \"/path/to/input.xcf\" \"/path/to/output.png\")" -b "(gimp-quit 0)"

# Arguments:
#   1. Input XCF path (string)
#   2. Output PNG path (string)
```

---

## Complete Asset Pipeline (Manual)

For a single flag `source/flags/human/earth.svg` → output `ui_earth`:

```bash
# 1. SVG already exists, copy to build/
cp source/flags/human/earth.svg build/human/earth.svg

# 2. Render 128px PNG
gimp -i -b "(svg-to-png \"build/human/earth.svg\" \"build/human/earth.png\" 128)" -b "(gimp-quit 0)"

# 3. Apply bevel to main
gimp -i -b "(apply-gradient-bevel \"build/human/earth.png\" \"build/human/earth_beveled.png\")" -b "(gimp-quit 0)"

# 4. Export main DDS
gimp -i -b "(png-to-dds \"build/human/earth_beveled.png\" \"out/ui-flags/flags/human/ui_earth.dds\")" -b "(gimp-quit 0)"

# 5. Render 256px PNG (map)
gimp -i -b "(svg-to-png \"build/human/earth.svg\" \"build/human/earth_map.png\" 256)" -b "(gimp-quit 0)"

# 6. Export map DDS (no bevel)
gimp -i -b "(png-to-dds \"build/human/earth_map.png\" \"out/ui-flags/flags/human/map/ui_earth.dds\")" -b "(gimp-quit 0)"

# 7. Render 24px PNG (small)
gimp -i -b "(svg-to-png \"build/human/earth.svg\" \"build/human/earth_small.png\" 24)" -b "(gimp-quit 0)"

# 8. Apply bevel to small
gimp -i -b "(apply-gradient-bevel \"build/human/earth_small.png\" \"build/human/earth_small_beveled.png\")" -b "(gimp-quit 0)"

# 9. Export small DDS
gimp -i -b "(png-to-dds \"build/human/earth_small_beveled.png\" \"out/ui-flags/flags/human/small/ui_earth.dds\")" -b "(gimp-quit 0)"
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
gimp -i -b "(svg-to-png \"build/human/earth.svg\" \"/tmp/test.png\" 128)" -b "(gimp-quit 0)"
# Check /tmp/test.png
```

### Test Bevel

```bash
gimp -i -b "(apply-gradient-bevel \"/tmp/test.png\" \"/tmp/test_beveled.png\")" -b "(gimp-quit 0)"
# Check /tmp/test_beveled.png
```

### Test DDS Export

```bash
gimp -i -b "(png-to-dds \"/tmp/test_beveled.png\" \"/tmp/test.dds\")" -b "(gimp-quit 0)"
# Check /tmp/test.dds opens in GIMP
```

### Test Format Conversion

```bash
# PNG → SVG
png-to-svg "source/flags/human/flag.png" "/tmp/flag.svg"

# AI → SVG
ai-to-svg "source/flags/human/flag.ai" "/tmp/flag.svg"

# XCF → SVG
xcf-to-svg "source/flags/human/flag.xcf" "/tmp/flag.svg"
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
which convert potrace inkscape gimp

# Check Flatpak paths
ls /var/lib/flatpak/exports/bin/org.gimp.GIMP
ls /var/lib/flatpak/exports/bin/org.inkscape.Inkscape

# Check DDS plug-in
gimp -i -b "(png-to-dds \"/tmp/test.png\" \"/tmp/test.dds\")" -b "(gimp-quit 0)" 2>&1 | grep -i error
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