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

**Supported Formats:** `.svg`, `.png`, `.bmp`

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
rsvg-convert -w 128 -h 128 -b white -o /tmp/raw.png "build/<cat>/<flag>.svg"
magick identify /tmp/raw.png
```

**Common Causes:**
- Corrupt source file
- SVG with unsupported features (external references, animations)
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
- Ensure the SVG renders the emblem in a colour that differs from the background; the alpha channel is that difference
- Traced SVGs draw black shapes with no background rectangle, so the stage renders them over white
- If PNG source: ensure background is a solid colour (colour-to-alpha can remove it)
- Check the background removal logic in the `svg-to-png` function in `build.sh`

---

### Flag Has Wrong Background

**Symptom:** Flag shows white or coloured square behind emblem.

**Cause:** the `svg-to-png` stage failed to remove the solid background.

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

### Some Flags Were Not Beveled

**Symptom:**
```
[ERROR] 2 flags were not beveled after 8 attempts:
  - build/corporate/ui_bitcoin.png
    source: build/corporate/ui_bitcoin.svg
    reason: the GIMP session bevel-8-0.log crashed (segmentation fault) while beveling this flag
  - build/corporate/small/ui_bitcoin.png
    source: build/corporate/ui_bitcoin.svg
    reason: the GIMP session bevel-8-0.log crashed (segmentation fault) while beveling 'build/corporate/ui_bitcoin.png', before it reached this flag
```

**Cause:** A GIMP session was killed or crashed before it reached every image it was given. The usual
causes are memory exhaustion (the OOM killer reports exit code `137`) and a GIMP segmentation fault.

**How to read the report:** The final error lists every unbeveled image with three lines each:

| Line | Meaning |
|------|---------|
| `- <png>` | The intermediate PNG that has no completion marker |
| `source:` | The SVG it was rasterised from |
| `reason:` | The root cause, taken from the session the flag was handed to |

The reported reasons are:

| Reason | Meaning | Fix |
|--------|---------|-----|
| `killed by the OOM killer` | The session ran out of memory | Lower `FLAG_BEVEL_BATCH_SIZE`, or lower `FLAG_GIMP_CONCURRENCY` |
| `crashed (segmentation fault)` | GIMP itself crashed | Retry; if persistent, lower the batch size |
| `finished without beveling it` | The script raised an error on that image | Read the session log for the accompanying `[WARNING]` line |
| `while beveling this flag` | The session died on this very image | This image is the likely culprit |
| `before it reached this flag` | The session died on an earlier image in the same batch | Not this flag's fault; it was simply never attempted |
| `never reported any progress` | The session died before it started any image | Lower the batch size or concurrency |
| `never handed to a GIMP session` | The image was never submitted | Check the source SVG; re-run |

**Diagnostic artefacts:** Each session writes three files under `build/`:

| File | Contents |
|------|----------|
| `bevel-<round>-<chunk>.log` | GIMP output, including one `[INFO] Beveling '<path>'` line per image |
| `bevel-<round>-<chunk>.log.flags` | The flags that session was given |
| `bevel-<round>-<chunk>.log.exit` | The session's exit code |

The last `[INFO] Beveling` line in a log identifies the image the session was working on when it
died. These files are deleted at the start of the next build.

---

### Map Flag Has Bevel

**Symptom:** Map (256px) flag shows bevel effect.

**Cause:** Logic error in build script — map path should skip bevel.

**Fix:** Verify that the map PNG is never registered for beveling in `build.sh`:
```bash
# The map PNG is rasterised and exported directly; only the main and small PNGs
# are added to FLAG_MAIN_PNG_PATHS and FLAG_SMALL_PNG_PATHS, which feed the bevel rounds.
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
- A very small `FLAG_BEVEL_BATCH_SIZE`, which multiplies the GIMP session starts
- Too few GIMP sessions (`FLAG_GIMP_CONCURRENCY`) on a machine with spare memory
- Very complex SVGs (slow rasterisation)
- Slow disk (intermediates on network storage)

**Optimisations:**
- Use SVG sources (fastest path)
- Raise `FLAG_BEVEL_BATCH_SIZE` while memory allows
- Keep incremental builds where possible
- Ensure `build/` and `out/` on local disk

### GIMP Session Startup

**Cause:** One GIMP start per bevel batch; the session's cost is dominated by its start-up.

**Mitigation:** Raise `FLAG_BEVEL_BATCH_SIZE` so fewer sessions are needed, up to the point where
the session memory grows enough to risk being killed.

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
# svg-to-png (no GIMP)
rsvg-convert -w 128 -h 128 -b white -o /tmp/raw.png "input.svg"
magick identify /tmp/raw.png

# bevel_batch (batched, one session for the whole list)
env GIMP_SCRIPT_IMAGE_PATHS="input_a.png
input_b.png" \
    gimp -i --batch-interpreter=python-fu-eval \
    -b "import sys; sys.path.insert(0, 'source/scripts'); exec(open('source/scripts/bevel_batch.py').read())" --quit

# png_to_dds
env GIMP_SCRIPT_INPUT_IMAGE_PATH="input.png" \
    GIMP_SCRIPT_OUTPUT_IMAGE_PATH="output.dds" \
    python3 source/scripts/png_to_dds.py
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