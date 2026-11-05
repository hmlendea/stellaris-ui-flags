# Output Package

## Overview

The output package is the distributable Stellaris mod produced by the build pipeline. It resides in `out/ui-flags/` and conforms to the Stellaris mod directory structure specification.

## Package Structure

```
out/ui-flags/
├── descriptor.mod              # Secondary descriptor (for mod directory)
├── flags/
│   ├── backgrounds/            # Background textures (DDS)
│   │   ├── ui_checkboard.dds
│   │   ├── ui_circle_bicolour.dds
│   │   └── ... (40+ files)
│   ├── colors.txt              # Colour palette (copied from source)
│   ├── aquatic/
│   │   ├── map/                # 256px DDS files
│   │   │   └── ui_aquatic_1.dds
│   │   ├── small/              # 24px DDS files
│   │   │   └── ui_aquatic_1.dds
│   │   └── ui_aquatic_1.dds    # 128px main DDS
│   ├── blocky/
│   │   ├── map/
│   │   ├── small/
│   │   └── *.dds
│   ├── corporate/
│   │   ├── map/
│   │   ├── small/
│   │   └── *.dds
│   └── ... (25+ categories)
├── localisation/
│   └── ui-flags_l_english.yml  # Localisation (copied from source)
└── thumbnail.png               # Mod thumbnail (copied from source)
```

## Root Descriptor

**File:** `out/ui-flags.mod` (in `out/`, not inside package)

```ini
name="Universum Infinitum: Flags"
path="mod/ui-flags"
supported_version="v4.5.*"
tags={
    "Graphics"
}
picture="thumbnail.png"
```

**Purpose:** Primary descriptor read by Stellaris launcher when mod is in `Documents/Paradox Interactive/Stellaris/mod/`.

**Fields:**
| Field | Value | Source |
|-------|-------|--------|
| `name` | `MOD_NAME` constant | `build.sh` |
| `path` | `mod/ui-flags` | Relative to mod root |
| `supported_version` | `STELLARIS_VERSION` constant | `build.sh` |
| `tags` | `{"Graphics"}` | Hardcoded |
| `picture` | `thumbnail.png` | Copied from source |

## Secondary Descriptor

**File:** `out/ui-flags/descriptor.mod`

```ini
name="Universum Infinitum: Flags"
path="."
supported_version="v4.5.*"
tags={
    "Graphics"
}
picture="thumbnail.png"
```

**Purpose:** Descriptor inside the mod package itself. Used when mod is loaded from `mod/ui-flags/` directory.

**Difference from root:** `path="."` (current directory) vs `path="mod/ui-flags"`.

## Flags Directory

### Backgrounds

**Location:** `flags/backgrounds/`

**Contents:** All DDS files from `source/backgrounds/` copied verbatim.

**Count:** 40+ files

**Format Requirements:**
- DDS with mipmaps
- BC1 (DXT1) or BC3 (DXT5) compression
- Power-of-two dimensions (typically 256x256 or 512x512)
- No alpha channel required for opaque backgrounds

### Colours

**File:** `flags/colors.txt`

**Source:** Copied from `source/colours.txt`

**Format:** Stellaris colour definition format (see [Configuration](../configuration.md#colour-palette-configuration))

**Usage:** Defines available colours for flag/map/ship contexts in empire customisation.

### Category Directories

Each category under `source/flags/` produces a directory under `flags/`:

```
flags/<category>/
├── map/                    # 256px DDS (galaxy map)
│   └── <flag_name>.dds
├── small/                  # 24px DDS (UI icons)
│   └── <flag_name>.dds
├── <flag_name>.dds         # 128px DDS (main flag)
└── usage.txt               # Optional, copied from source
```

**Naming:** Output filenames derived from `names.txt` mapping or default `ui_<source_name>`.

### DDS File Specifications

#### Main Flag (128px)

| Property | Value |
|----------|-------|
| Resolution | 128x128px |
| Format | DDS |
| Compression | BC3 (DXT5) with alpha |
| Mipmaps | Yes |
| Bevel Effect | Applied (gradient bevel) |
| Colour Context | `flag` from colors.txt |

#### Map Flag (256px)

| Property | Value |
|----------|-------|
| Resolution | 256x256px |
| Format | DDS |
| Compression | BC3 (DXT5) with alpha |
| Mipmaps | Yes |
| Bevel Effect | **Not applied** |
| Colour Context | `map` from colors.txt |

#### Small Flag (24px)

| Property | Value |
|----------|-------|
| Resolution | 24x24px |
| Format | DDS |
| Compression | BC3 (DXT5) with alpha |
| Mipmaps | Yes |
| Bevel Effect | Applied (gradient bevel) |
| Colour Context | `flag` from colors.txt |

## Localisation

**File:** `localisation/ui-flags_l_english.yml`

**Source:** Copied from `source/localisation.yml`

**Format:**
```yaml
l_english:
 FLAG_CATEGORY_aquatic:0 "Aquatic"
 FLAG_CATEGORY_blocky:0 "Blocky"
 # ... all categories
```

**Encoding:** UTF-8

**Language:** English only (`l_english`)

## Thumbnail

**File:** `thumbnail.png`

**Source:** Copied from `source/thumbnail.png`

**Specifications:**
- Format: PNG
- Recommended: 256x256px
- Used in: Stellaris launcher, Steam Workshop, Nexus Mods, GitHub Releases

## Stellaris Mod Compliance

### Required Structure

The package follows Stellaris mod requirements:

1. **Descriptor file** (`.mod`) in mod root or parent directory
2. **Mod directory** with same name as `path` in descriptor
3. **Localisation** in `localisation/` with `l_<language>:` prefix
4. **Flags** in `flags/` with `colors.txt`, `backgrounds/`, and category subdirectories
5. **Thumbnail** at package root

### Flag System Integration

Stellaris loads flags via:
1. `flags/colors.txt` — colour palette
2. `flags/backgrounds/*.dds` — background textures
3. `flags/<category>/*.dds` — main flag emblems (128px)
4. `flags/<category>/map/*.dds` — map flags (256px)
5. `flags/<category>/small/*.dds` — small flags (24px)
6. `localisation/*_l_<language>.yml` — category names

### Version Compatibility

`supported_version` in descriptor must match game version pattern. Current: `v4.5.*`

## Distribution Artefacts

### Release Archive

For distribution platforms, the package is typically zipped:

```bash
cd out
zip -r ui-flags_<version>.zip ui-flags/
```

**Archive Structure:**
```
ui-flags_1.0.0.zip
└── ui-flags/
    ├── descriptor.mod
    ├── flags/
    ├── localisation/
    └── thumbnail.png
```

### Platform-Specific Requirements

| Platform | Artefact | Notes |
|----------|----------|-------|
| Steam Workshop | `ui-flags/` directory | Uploaded via Steam Workshop API |
| Nexus Mods | `ui-flags_<version>.zip` | Zip archive uploaded |
| Paradox Mods | `ui-flags_<version>.zip` | Manual upload via web |
| GitHub Releases | `ui-flags_<version>.zip` | Attached to release |

## Validation Checklist

### Pre-Release Validation

- [ ] `out/ui-flags.mod` exists with correct version, name, path
- [ ] `out/ui-flags/descriptor.mod` exists with `path="."`
- [ ] `out/ui-flags/flags/colors.txt` matches `source/colours.txt`
- [ ] `out/ui-flags/localisation/ui-flags_l_english.yml` matches source
- [ ] `out/ui-flags/thumbnail.png` exists and is valid PNG
- [ ] All category directories present under `flags/`
- [ ] Each category has `map/`, `small/`, and main DDS files
- [ ] Background DDS files present in `flags/backgrounds/`
- [ ] DDS files open correctly in GIMP (verify format, mipmaps)
- [ ] No missing or zero-byte DDS files

### In-Game Validation

- [ ] Mod appears in Stellaris launcher
- [ ] Mod loads without errors
- [ ] All categories visible in empire customisation
- [ ] Flags display correctly in all three contexts (main, map, small)
- [ ] Colours match palette
- [ ] Backgrounds selectable and render correctly
- [ ] Thumbnail displays in launcher
- [ ] No texture errors in log (`Documents/Paradox Interactive/Stellaris/logs/error.log`)

## Common Issues

| Issue | Cause | Resolution |
|-------|-------|------------|
| Mod not appearing | Descriptor path mismatch | Verify `path` in `.mod` matches directory name |
| Flags missing | DDS format invalid | Re-export with GIMP DDS plug-in, ensure mipmaps |
| Colours wrong | HSV values incorrect | Verify `colors.txt` HSV ranges (0-1 for H,S; V can exceed 1) |
| Categories missing | Localisation key mismatch | Verify `FLAG_CATEGORY_<dir>` matches directory name exactly |
| Map flags wrong size | Wrong resolution | Ensure map output is 256px, not 128px |
| Small flags blurry | No mipmaps | Verify DDS export includes mipmap generation |

## Package Size

Typical package size: **50-150 MB** depending on flag count and DDS compression.

Breakdown:
- DDS files: ~90% (main + map + small per flag)
- Backgrounds: ~5%
- Text files: <1%
- Thumbnail: <1%

## Clean Build vs Incremental

| Build Type | Output Package |
|------------|----------------|
| Clean (`rm -rf build out`) | Complete rebuild, all assets processed |
| Incremental | Only new/changed assets processed; existing outputs preserved |

**Note:** Incremental builds do not detect source file modifications. For source changes, clean build required.