# Troubleshooting

## Build Failures

### Missing Version Argument

**Symptom:**
```
Usage: ./build.sh <version>
```

**Cause:** No version argument provided.

**Fix:**
```bash
./build.sh 1.0.0
```

---

### Missing Source Directory

**Symptom:**
```
MISSING SOURCE DIRECTORY
```

**Cause:** `source/` directory not found — wrong working directory.

**Fix:**
```bash
cd /path/to/stellaris-ui-flags
./build.sh 1.0.0
```

---

### ImageMagick Not Installed

**Symptom:**
```
ImageMagick is not installed
```

**Cause:** `convert` command not found in PATH or Flatpak exports.

**Fix:**
```bash
# Debian/Ubuntu
sudo apt install imagemagick

# Fedora
sudo dnf install ImageMagick

# Arch
sudo pacman -S imagemagick

# Verify
convert --version
```

---

### potrace Not Installed

**Symptom:**
```
potrace is not installed
```

**Fix:**
```bash
# Debian/Ubuntu
sudo apt install potrace

# Fedora
sudo dnf install potrace

# Verify
potrace --version
```

---

### Inkscape Not Found

**Symptom:**
```
Inkscape is not installed
```

**Cause:** Inkscape not in PATH, and Flatpak exports not detected.

**Fix:**
```bash
# System install
sudo apt install inkscape

# Or Flatpak
flatpak install flathub org.inkscape.Inkscape

# Verify Flatpak export exists
ls /var/lib/flatpak/exports/bin/org.inkscape.Inkscape 2>/dev/null
ls ~/.local/share/flatpak/exports/bin/org.inkscape.Inkscape 2>/dev/null
```

**If Flatpak installed but not detected:** Ensure the export path matches exactly. The build script checks:
- `/var/lib/flatpak/exports/bin/org.inkscape.Inkscape`
- `~/.local/share/flatpak/exports/bin/org.inkscape.Inkscape`

---

### GIMP Not Found

**Symptom:**
```
GIMP is not installed
```

**Fix:**
```bash
# System install
sudo apt install gimp

# Or Flatpak
flatpak install flathub org.gimp.GIMP
```

**Important:** GIMP 2.10 is end of life and is not supported. The scripts require GIMP 3.0 or later.
The DDS export no longer runs inside GIMP at all, so it does not depend on any GIMP plug-in.

---

### DDS Conversion Fails

**Symptom:** `Failure while converting '…png' to '…dds'`.

**Cause:** The intermediate PNG is missing, empty or truncated, which happens when a long-lived
GIMP session crashes while writing it. The conversion itself has no external dependencies beyond
ImageMagick.

**Fix:** Re-run the build. The retry loop discards an unusable PNG and renders it again.

**Verify the conversion on a known-good PNG:**
```bash
env GIMP_SCRIPT_INPUT_IMAGE_PATH="/tmp/test.png" \
    GIMP_SCRIPT_OUTPUT_IMAGE_PATH="/tmp/test.dds" \
    python3 source/scripts/png_to_dds.py
# Should produce /tmp/test.dds without error
```

## Asset Processing Issues

### Unsupported Format Warning

**Symptom:**
```
Unsupported format: source/flags/human/somefile.txt
```

**Cause:** File in category directory with unsupported extension.

**Supported Formats:** `.svg`, `.png`, `.xcf`, `.ai`, `.bmp`

**Fix:** Remove or move the file out of the category directory. Note: `usage.txt` files are handled specially and copied, not converted.

---

### Asset Silently Missing From Output

**Symptom:** Flag not in `out/ui-flags/flags/<category>/` after build.

**Diagnosis:**
```bash
# Check build intermediates
ls build/<category>/
# If no .svg file: source conversion failed

# Check source file
file source/flags/<category>/<flag>.*
# Verify format matches extension

# Run conversion manually
env GIMP_SCRIPT_INPUT_IMAGE_PATH="build/<cat>/<flag>.svg" \
    GIMP_SCRIPT_OUTPUT_IMAGE_PATH="/tmp/test.png" \
    GIMP_SCRIPT_OUTPUT_IMAGE_SIZE="128" \
    gimp -i --batch-interpreter=python-fu-eval \
    -b "import sys; sys.path.insert(0, 'source/scripts'); exec(open('source/scripts/svg_to_png.py').read())" --quit
```

**Common Causes:**
- Corrupt source file
- SVG with unsupported features (external references, animations)
- XCF with unsupported layer modes
- AI version not supported by Inkscape
- PNG with complex gradients (potrace produces poor/empty trace)

---

### Flag Renders Blank or Invisible

**Symptom:** DDS file exists but flag invisible in game.

**Cause:** Alpha channel lost during processing.

**Diagnosis:**
```bash
# Check intermediate PNG
gimp build/<category>/<flag>.png
# Verify has transparency (alpha channel)

# Check bevel output
gimp build/<category>/<flag>_bevel.png
```

**Fix:**
- Ensure source SVG has transparent background (not white)
- If PNG source: ensure background is a solid colour (colour-to-alpha can remove it)
- Check the background removal logic in `source/scripts/svg_to_png.py`

---

### Flag Has Wrong Background

**Symptom:** Flag shows white or coloured square behind emblem.

**Cause:** `svg_to_png.py` failed to remove the solid background.

**Fix:**
- Edit source SVG: remove background rect, keep only emblem
- Or set background to a colour the script can detect and remove

---

### Bevel Looks Wrong

**Symptom:** Flag bevel too strong, too weak, or distorted.

**Cause:** `gradient_bevel.py` parameters not suited to the asset.

**Fix:** Adjust parameters in `source/scripts/gradient_bevel.py`:
```python
BLUR_RADIUS = 2.5       # Increase for softer edges
BUMP_DEPTH = 5          # Increase for deeper emboss
BUMP_ELEVATION = 40.0   # Increase for a higher light angle
```

**Note:** Parameters are global — affect all flags. Full rebuild required.

---

### Map Flag Has Bevel

**Symptom:** Map (256px) flag shows bevel effect.

**Cause:** Logic error in build script — map path should skip bevel.

**Fix:** Verify `build.sh` map processing:
```bash
# Should be: svg-to-png → png-to-dds (NO apply-gradient-bevel)
```

---

### Output Filename Unexpected

**Symptom:** Flag output name doesn't match source name.

**Cause:** `names.txt` mapping applied.

**Diagnosis:**
```bash
grep "^<source_name>=" source/names.txt
```

**Fix:** Update or remove the entry in `source/names.txt`.

---

### Filename Collision

**Symptom:** One flag missing; another appears twice (or with wrong content).

**Cause:** Two source files map to same output name.

**Diagnosis:**
```bash
# Find duplicate output names
awk -F= '{print $2}' source/names.txt | sort | uniq -d
```

**Fix:** Rename one of the mappings in `names.txt`.

## Game Issues

### Mod Not Appearing in Launcher

**Diagnosis:**
```bash
# Verify descriptor exists and is valid
cat <mod-dir>/ui-flags.mod

# Verify path matches directory
ls <mod-dir>/ui-flags/
```

**Check:**
- `path="mod/ui-flags"` in root descriptor
- Directory `ui-flags/` exists at that relative location
- `supported_version` matches game version

**Fix:** Rebuild with correct `STELLARIS_VERSION` in `build.sh` if game version mismatch.

---

### Categories Show Raw Keys

**Symptom:** Category list shows `FLAG_CATEGORY_my-cat` instead of "My Category".

**Cause:** Missing localisation entry.

**Fix:** Add to `source/localisation.yml`:
```yaml
 FLAG_CATEGORY_my-cat:0 "My Category"
```

**Key must match directory name exactly** (including hyphens, underscores).

---

### Flags Missing In-Game

**Symptom:** Category present but no flags inside.

**Diagnosis:**
```bash
# Verify DDS files exist
ls out/ui-flags/flags/<category>/
ls out/ui-flags/flags/<category>/map/
ls out/ui-flags/flags/<category>/small/

# Verify DDS valid (opens in GIMP)
gimp out/ui-flags/flags/<category>/<flag>.dds
```

**Requirements:**
- All three variants (main, map, small) must exist
- Same filename in all three locations
- Valid DDS file (uncompressed BGRA8, square dimensions)

---

### Colours Wrong or Missing

**Symptom:** Custom colours don't appear, or render incorrectly.

**Diagnosis:**
```bash
# Verify colors.txt copied
diff source/colours.txt out/ui-flags/flags/colors.txt

# Check format
cat out/ui-flags/flags/colors.txt
```

**Common Errors:**
- HSV values out of range (H,S must be 0–1; V can exceed 1)
- Missing `flag`, `map`, or `ship` context
- Syntax errors (missing braces, semicolons)

---

### Texture Errors in Log

**Symptom:** Errors in `Documents/Paradox Interactive/Stellaris/logs/error.log`.

**Common Entries:**
```
Failed to load texture: flags/<category>/<flag>.dds
```

**Causes:**
- Invalid DDS file (corrupt header or truncated data)
- Non-square dimensions
- Corrupt file

**Fix:** Rebuild the affected asset:
```bash
rm out/ui-flags/flags/<category>/<flag>*.dds
rm out/ui-flags/flags/<category>/map/<flag>.dds
rm out/ui-flags/flags/<category>/small/<flag>.dds
./build.sh <version>
```

## Incremental Build Issues

### Modified Source Not Rebuilt

**Symptom:** Changed source file, but output unchanged.

**Cause:** Incremental build skips assets with existing outputs — does not detect source changes.

**Fix:**
```bash
# Option 1: Remove specific outputs
rm out/ui-flags/flags/<category>/<flag>.dds
rm out/ui-flags/flags/<category>/map/<flag>.dds
rm out/ui-flags/flags/<category>/small/<flag>.dds
./build.sh <version>

# Option 2: Full rebuild
rm -rf build out
./build.sh <version>
```

### Script Changes Not Applied

**Symptom:** Modified `gradient_bevel.py` but output unchanged.

**Cause:** Incremental skip — existing outputs not regenerated.

**Fix:** Full rebuild required after script changes:
```bash
rm -rf build out
./build.sh <version>
```

## Performance Issues

### Build Too Slow

**Expected:** 5–15 minutes full build; <30s incremental.

**Causes of Slowness:**
- Very complex SVGs (slow GIMP import)
- XCF sources (longest conversion path)
- Slow disk (intermediates on network storage)

**Optimisations:**
- Use SVG sources (fastest path)
- Keep incremental builds where possible
- Ensure `build/` and `out/` on local disk

### GIMP Startup Overhead

**Cause:** 8 GIMP invocations per asset (~0.5–1s each).

**Mitigation:** None currently — architecture invokes GIMP per operation. Batch processing would require script refactoring.

## Distribution Issues

### Steam Workshop Update Fails

**Symptom:** GitHub Actions workflow `steam-workshop.yml` fails.

**Common Causes:**
- GitHub Release asset missing (tag pushed without release)
- Secrets expired or changed (`STEAM_USERNAME`, `STEAM_PASSWORD`, `STEAM_2FASEED`)
- Steam Workshop item inaccessible

**Fix:**
1. Verify GitHub Release exists with tag and zip asset
2. Check secrets in repository settings
3. Re-run workflow

### Nexus Mods Update Fails

**Symptom:** GitHub Actions workflow `nexus-mods.yml` fails.

**Common Causes:**
- GitHub Release asset missing
- Secrets invalid (`NEXUS_UPLOADER_USERNAME`, `NEXUS_UPLOADER_PASSWORD`)

**Fix:**
1. Verify release asset exists
2. Check secrets
3. Re-run workflow

## Debugging Techniques

### Verbose Build Output

```bash
# Add to top of build.sh temporarily
set -x
```

Shows every command executed.

### Inspect Intermediates

```bash
# After build, check intermediate files
ls -la build/<category>/
# Check the SVG, the 128px render, and the 24px render
gimp build/<category>/<flag>.svg
# The bevel is applied in place to the 128px and 24px renders
gimp build/<category>/<flag>.png
gimp build/<category>/map/<flag>.png
gimp build/<category>/small/<flag>.png
```

### Test Individual Scripts

The scripts read their parameters from `GIMP_SCRIPT_*` environment variables.

```bash
# svg_to_png
env GIMP_SCRIPT_INPUT_IMAGE_PATH="input.svg" \
    GIMP_SCRIPT_OUTPUT_IMAGE_PATH="output.png" \
    GIMP_SCRIPT_OUTPUT_IMAGE_SIZE="128" \
    gimp -i --batch-interpreter=python-fu-eval \
    -b "import sys; sys.path.insert(0, 'source/scripts'); exec(open('source/scripts/svg_to_png.py').read())" --quit

# gradient_bevel
env GIMP_SCRIPT_IMAGE_PATH="input.png" \
    gimp -i --batch-interpreter=python-fu-eval \
    -b "import sys; sys.path.insert(0, 'source/scripts'); exec(open('source/scripts/gradient_bevel.py').read())" --quit

# png_to_dds
env GIMP_SCRIPT_INPUT_IMAGE_PATH="input.png" \
    GIMP_SCRIPT_OUTPUT_IMAGE_PATH="output.dds" \
    gimp -i --batch-interpreter=python-fu-eval \
    -b "import sys; sys.path.insert(0, 'source/scripts'); exec(open('source/scripts/png_to_dds.py').read())" --quit

# xcf_to_png
env GIMP_SCRIPT_INPUT_IMAGE_PATH="input.xcf" \
    GIMP_SCRIPT_OUTPUT_IMAGE_PATH="output.png" \
    gimp -i --batch-interpreter=python-fu-eval \
    -b "import sys; sys.path.insert(0, 'source/scripts'); exec(open('source/scripts/xcf_to_png.py').read())" --quit
```

### Interactive Debugging

Load the script in a Python-Fu console session and call its function directly with the desired arguments.

### Verify DDS Files

```bash
# Open in GIMP — it should load correctly
gimp out/ui-flags/flags/<category>/<flag>.dds

# Check the file size (expected: 128 + width × height × 4 bytes)
ls -la out/ui-flags/flags/<category>/<flag>.dds
```

## Getting Help

- **Repository issues:** [GitHub Issues](https://github.com/hmlendea/stellaris-ui-flags/issues)
- **Steam Workshop page:** Item 1914541325
- **Nexus Mods page:** Mod 75
- **Build logs:** Check terminal output during `./build.sh`