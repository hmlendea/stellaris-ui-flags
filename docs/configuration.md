# Configuration

## Configuration Sources

The Stellaris UI Flags build pipeline uses multiple configuration sources with the following precedence (highest to lowest):

| Source | Location | Scope | Modifiable |
|--------|----------|-------|------------|
| Command-line argument | `./build.sh <version>` | Build version | Yes (per build) |
| Script constants | `build.sh` (top of file) | Mod identity, Stellaris version | Yes (maintainer) |
| Colour palette | `source/colours.txt` | Flag/map/ship colours | Yes (contributor) |
| Localisation | `source/localisation.yml` | Category names | Yes (contributor) |
| Filename mapping | `source/names.txt` | Output filenames | Yes (contributor) |
| Source assets | `source/flags/<category>/` | Flag designs | Yes (contributor) |
| Background textures | `source/backgrounds/` | Background images | Yes (contributor) |
| Thumbnail | `source/thumbnail.png` | Mod thumbnail | Yes (contributor) |
| GIMP scripts | `source/scripts/*.lisp` | Conversion behaviour | Yes (maintainer) |

## Build Script Constants

Located at the top of `build.sh`:

```bash
MOD_ID="ui-flags"
MOD_NAME="Universum Infinitum: Flags"
MOD_VERSION="${1}"           # From command line
STELLARIS_VERSION="v4.5.*"   # Supported game version
```

### Modifiable Constants

| Constant | Description | Change Impact |
|----------|-------------|---------------|
| `MOD_ID` | Mod directory name, descriptor ID | Changes output directory, descriptor `path` |
| `MOD_NAME` | Display name in Stellaris launcher | User-visible name only |
| `STELLARIS_VERSION` | `supported_version` in descriptor | Compatibility with game versions |

## Colour Palette Configuration

**File:** `source/colours.txt`

**Format:** Stellaris colour definition format with HSV/RGB values for three contexts:

```txt
colors = {
    colour_name = {
        flag = hsv { H S V }      # Flag context (main/small)
        map = hsv { H S V }       # Map context (256px)
        ship = hsv { H S V }      # Ship context
        use_as_border_color = yes/no
    }
}

randomizable_combo = { colour1 colour2 colour3 }
```

### Colour Contexts

| Context | Resolution | Use Case | Bevel Applied |
|---------|------------|----------|---------------|
| `flag` | 128px / 24px | Empire flag, UI icons | Yes |
| `map` | 256px | Galaxy map flags | No |
| `ship` | Variable | Ship hull patterns | N/A |

### Adding New Colours

1. Add entry to `colors` block with unique name
2. Define HSV values for all three contexts
3. Set `use_as_border_color` appropriately
4. Optionally add to `randomizable_combo` for random empire generation
5. Run build — colours copied to `out/ui-flags/flags/colors.txt`

### HSV Value Ranges

- **H (Hue):** 0.0–1.0 (0.0 = red, 0.33 = green, 0.66 = blue)
- **S (Saturation):** 0.0–1.0 (0.0 = greyscale, 1.0 = full colour)
- **V (Value):** 0.0–1.0+ (can exceed 1.0 for emissive/bright colours)

RGB format also supported: `rgb { R G B }` with values 0–255.

## Localisation Configuration

**File:** `source/localisation.yml`

**Format:** YAML with `l_english:` prefix:

```yaml
l_english:
 FLAG_CATEGORY_<category_id>:0 "Display Name"
```

### Category ID Mapping

Category IDs are derived from directory names under `source/flags/` with special handling:

| Directory Name | Category ID | Example |
|----------------|-------------|---------|
| `aquatic` | `aquatic` | `FLAG_CATEGORY_aquatic` |
| `ui_elder-scrolls` | `ui_elder-scrolls` | `FLAG_CATEGORY_ui_elder-scrolls` |
| `ui_starcraft` | `ui_starcraft` | `FLAG_CATEGORY_ui_starcraft` |

### Adding New Categories

1. Create `source/flags/<new-category>/`
2. Add localisation entry: `FLAG_CATEGORY_<new-category>:0 "Display Name"`
3. Run build — category automatically discovered

## Filename Mapping Configuration

**File:** `source/names.txt`

**Format:** Key=value pairs, one per line:

```txt
source_filename=output_filename
```

### Resolution Logic

In `build.sh`, function `get-flag-file-name`:

```bash
FLAG_FILE_NAME=$(grep "^${SOURCE_FILE_NAME}=" "${FLAG_NAMES_FILE_PATH}" | awk -F= '{print $2}')
if [ -z "${FLAG_FILE_NAME}" ]; then
    echo "${FILE_PREFIX}${SOURCE_FILE_NAME}"  # Default: ui_<source_name>
else
    echo "${FLAG_FILE_NAME}"                  # Mapped name
fi
```

### Mapping Rules

| Source Filename | names.txt Entry | Output Filename |
|-----------------|-----------------|-----------------|
| `mighty-spanner.svg` | `mighty-spanner=ui_mechanical_1` | `ui_mechanical_1.dds` |
| `eye-target.svg` | (no entry) | `ui_eye-target.dds` |
| `custom-flag.png` | `custom-flag=my_special_flag` | `my_special_flag.dds` |

### Prefix Constant

`FILE_PREFIX="ui_"` in `get-flag-file-name` function — change to modify default prefix.

## Background Textures Configuration

**Directory:** `source/backgrounds/`

**Format:** DDS files copied verbatim to `out/ui-flags/flags/backgrounds/`

**Current Assets:** 40+ background textures including:
- Geometric patterns (checkerboard, circles, diamonds, hexagons)
- Stripes and gradients (diagonal, horizontal, vertical)
- Shapes (stars, crosses, cog, house, hills)
- Special effects (fallout, galciv, new dawn, webstar)

**Adding Backgrounds:**
1. Place DDS file in `source/backgrounds/`
2. Run build — automatically copied to output

## Thumbnail Configuration

**File:** `source/thumbnail.png`

**Requirements:**
- PNG format
- Recommended size: 256x256px or similar
- Used as mod icon in Stellaris launcher and distribution platforms

**Changing Thumbnail:**
1. Replace `source/thumbnail.png`
2. Run build — copied to `out/ui-flags/thumbnail.png`

## GIMP Script-fu Configuration

**Directory:** `source/scripts/`

### Script Files

| Script | Purpose | Key Parameters |
|--------|---------|----------------|
| `gradient-bevel.lisp` | Applies gradient bevel effect | `bevel-size`, `bevel-width`, `bevel-height`, colours |
| `png-to-dds.lisp` | Exports PNG to DDS | DDS compression settings |
| `svg-to-png.lisp` | Renders SVG to PNG | `OUTPUT_IMAGE_SIZE`, background handling |
| `xcf-to-png.lisp` | Exports XCF to PNG | Layer merging |

### Modifying Gradient Bevel

Edit `source/scripts/gradient-bevel.lisp`:

```lisp
(bevel-size 22)      ; Bevel size in pixels
(bevel-width 2.5)   ; Blur width
(bevel-height 40)   ; Bump map height
(indentX (+ bevel-size 12))
(indentY (+ bevel-size (/ height 8)))
```

Colour stops:
```lisp
; Logo layer gradient (bevel)
(gimp-context-set-foreground '(255 255 255))  ; White highlight
(gimp-context-set-background '(127 127 127))  ; Grey shadow

; Colour overlay layer
(gimp-context-set-foreground '(178 164 136))  ; Gold highlight
(gimp-context-set-background '(113 82 9))     ; Dark gold shadow
```

### Modifying DDS Export

Edit `source/scripts/png-to-dds.lisp`:

```lisp
(file-dds-save RUN-NONINTERACTIVE image drawable
               imageOutPath imageOutPath
               0 0 0 0 0 0 0 0 0 1.0 0 0 0.5)
```

Parameters (in order): compression, mipmaps, etc. — see GIMP DDS plug-in documentation.

## Stellaris Version Compatibility

**Constant:** `STELLARIS_VERSION="v4.5.*"` in `build.sh`

**Format:** Stellaris version pattern for `supported_version` in descriptor.

**Updating for New Game Version:**
1. Change `STELLARIS_VERSION` to new version pattern (e.g., `v4.6.*`)
2. Rebuild mod
3. Test in-game compatibility

**Version Pattern Syntax:**
- Exact: `v4.5.3`
- Wildcard minor: `v4.5.*`
- Wildcard patch: `v4.*`
- Range not supported — single pattern only

## Environment-Specific Configuration

### Local Development

No additional configuration needed. All settings in source files.

### GitHub Actions

Secrets configured in repository settings:

| Secret | Used By | Purpose |
|--------|---------|---------|
| `STEAM_USERNAME` | steam-workshop.yml | Steam account |
| `STEAM_PASSWORD` | steam-workshop.yml | Steam account |
| `STEAM_2FASEED` | steam-workshop.yml | Steam 2FA |
| `NEXUS_UPLOADER_USERNAME` | nexus-mods.yml | Nexus Mods account |
| `NEXUS_UPLOADER_PASSWORD` | nexus-mods.yml | Nexus Mods account |

No build-time configuration in workflows — they download pre-built release assets.

## Configuration Validation

### Build-Time Validation

The build script validates:

1. **Version argument provided:** `if [ -z "${MOD_VERSION}" ]`
2. **Source directory exists:** `[ ! -d "${SOURCE_DIR_PATH}" ]`
3. **Required tools available:** Checks for `convert`, `potrace`, Inkscape, GIMP
4. **Output file creation:** Verifies each conversion step produces output

### Manual Validation

Before release, verify:

1. **Descriptor files:** Check `out/ui-flags.mod` and `out/ui-flags/descriptor.mod` have correct version, name, path
2. **Colour file:** Verify `out/ui-flags/flags/colors.txt` matches `source/colours.txt`
3. **Localisation:** Verify `out/ui-flags/localisation/ui-flags_l_english.yml` matches source
4. **DDS files:** Spot-check DDS files open correctly in GIMP
5. **In-game test:** Install mod and verify flags appear in all three contexts

## Configuration Drift Prevention

### Single Source of Truth

| Configuration | Source of Truth | Copied To |
|---------------|-----------------|-----------|
| Colours | `source/colours.txt` | `out/ui-flags/flags/colors.txt` |
| Localisation | `source/localisation.yml` | `out/ui-flags/localisation/ui-flags_l_english.yml` |
| Thumbnail | `source/thumbnail.png` | `out/ui-flags/thumbnail.png` |
| Backgrounds | `source/backgrounds/` | `out/ui-flags/flags/backgrounds/` |
| Descriptors | `build.sh` constants | `out/ui-flags.mod`, `out/ui-flags/descriptor.mod` |

### Drift Detection

Run build and compare:
```bash
diff source/colours.txt out/ui-flags/flags/colors.txt
diff source/localisation.yml out/ui-flags/localisation/ui-flags_l_english.yml
```

Should produce no differences.