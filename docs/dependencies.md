# Dependencies

## Overview

The project has three dependency categories:

1. **Build-time tools** — required to run `build.sh`
2. **GIMP plug-ins** — required by the Python-Fu scripts (all bundled with GIMP 3)
3. **CI/CD actions** — required by GitHub Actions workflows

There are no runtime dependencies — the output is a pure content mod consumed by Stellaris itself.

## Build-Time Tools

### ImageMagick

| Property | Value |
|----------|-------|
| Minimum version | 6.0 |
| Command used | `convert` |
| Purpose | PNG → BMP conversion (intermediate step for raster sources) |
| Install (Debian/Ubuntu) | `sudo apt install imagemagick` |
| Install (Fedora) | `sudo dnf install ImageMagick` |
| Install (Arch) | `sudo pacman -S imagemagick` |
| Flatpak | N/A (system tool) |

**Used by:** `png-to-svg`

---

### librsvg (`rsvg-convert`)

| Property | Value |
|----------|-------|
| Minimum version | 2.40 |
| Command used | `rsvg-convert` |
| Purpose | SVG rasterisation to PNG |
| Install (Debian/Ubuntu) | `sudo apt install librsvg2-bin` |
| Install (Fedora) | `sudo dnf install librsvg2-tools` |
| Install (Arch) | `sudo pacman -S librsvg` |
| Flatpak | N/A (system tool) |

**Used by:** `svg-to-png`

**Flags used:** `-w`, `-h` (output size), `-b white` (background), `-o` (output file)

The `-b white` background is required. SVGs traced from bitmaps draw black shapes with no background
rectangle, so a transparent background would render black on black and the emblem would be invisible.

---

### potrace

| Property | Value |
|----------|-------|
| Minimum version | 1.0 |
| Command used | `potrace` |
| Purpose | Raster (BMP) → vector (SVG) tracing |
| Install (Debian/Ubuntu) | `sudo apt install potrace` |
| Install (Fedora) | `sudo dnf install potrace` |
| Flatpak | N/A (system tool) |

**Used by:** `bmp-to-svg`, `png-to-svg`

**Flags used:** `-s` (SVG output), `-o` (output file)

---

### GIMP

| Property | Value |
|----------|-------|
| Minimum version | 3.0 |
| Command used | `gimp` |
| Purpose | Python-Fu execution: gradient bevel |
| Install (Debian/Ubuntu) | `sudo apt install gimp` |
| Flatpak ID | `org.gimp.GIMP` |

**Used by:** `bevel-pngs`

**Flags used:** `-i` (no interface), `--batch-interpreter=python-fu-eval`, `-b` (batch command), `--quit`

**Detection paths (in order):**
1. System PATH (`which gimp`)
2. `/var/lib/flatpak/exports/bin/org.gimp.GIMP`
3. `~/.local/share/flatpak/exports/bin/org.gimp.GIMP`

## GIMP Plug-ins

GIMP 3 bundles every plug-in the build requires, including the GEGL operations used by the bevel
effect. No separate plug-in package is needed.

### Built-in Plug-ins (bundled with GIMP)

| Plug-in | PDB Function | Purpose |
|---------|--------------|---------|
| PNG import | `file-png-load` | Load PNG files |
| PNG export | `file-png-export` | Write PNG files |
| Colour to Alpha | `gegl:color-to-alpha` | Remove solid backgrounds |
| Gaussian Blur | `gegl:gaussian-blur` | Bump map smoothing |
| Bump Map | `gegl:bump-map` | Bevel embossing |

## CI/CD Dependencies

### GitHub Actions

| Workflow | Action | Version | Purpose |
|----------|--------|---------|---------|
| steam-workshop.yml | `actions/checkout` | v4 | Repository checkout |
| steam-workshop.yml | `hmlendea/steam-workshop-update` | latest | Steam Workshop upload |
| nexus-mods.yml | `actions/checkout` | v4 | Repository checkout |
| nexus-mods.yml | `hmlendea/nexusmods-update` | latest | Nexus Mods upload |

### Secrets

| Secret | Workflow | Purpose |
|--------|----------|---------|
| `STEAM_USERNAME` | steam-workshop.yml | Steam account login |
| `STEAM_PASSWORD` | steam-workshop.yml | Steam account password |
| `STEAM_2FASEED` | steam-workshop.yml | Steam 2FA seed for TOTP |
| `NEXUS_UPLOADER_USERNAME` | nexus-mods.yml | Nexus Mods account |
| `NEXUS_UPLOADER_PASSWORD` | nexus-mods.yml | Nexus Mods password |

## Runtime Dependencies

**None.** The output mod package contains only:
- DDS textures (game-native format)
- Text configuration (game-native format)
- YAML localisation (game-native format)
- PNG thumbnail

Stellaris consumes these directly — no external libraries, frameworks, or code.

## Dependency Graph

```
build.sh
├── ImageMagick (magick)
│   └── Used by: png-to-svg, svg-to-png, png-to-dds
├── rsvg-convert
│   └── Used by: svg-to-png
├── Python 3
│   └── Used by: png-to-dds
├── potrace
│   └── Used by: bmp-to-svg, png-to-svg
└── GIMP
    ├── PNG import (gimp-file-load)
    │   └── Used by: gradient-bevel
    ├── PNG export (file-png-export)
    │   └── Used by: gradient-bevel
    ├── Gaussian Blur (gegl:gaussian-blur)
    │   └── Used by: gradient-bevel
    └── Bump Map (gegl:bump-map)
        └── Used by: gradient-bevel

The SVG rasterisation and the DDS export no longer use GIMP, so each flag needs only the bevels.
```

## Version Compatibility

| Tool | Tested Versions | Notes |
|------|-----------------|-------|
| GIMP | 3.0.x, 3.2.x | Primary target |
| librsvg | 2.6x | `rsvg-convert` for SVG rasterisation |
| Python | 3.x | Writes the DDS directly |
| ImageMagick | 6.x, 7.x | `convert` deprecated in 7.x but still works |
| potrace | 1.x | Stable API |

**GIMP 2 note:** GIMP 2.10 is end of life and unsupported. The scripts use the GIMP 3 Python-Fu API and the GEGL filter API; the previous GIMP 2.10 Script-fu scripts and the separate `gimp-dds` plug-in are no longer used.

**ImageMagick 7 note:** `convert` is a legacy alias; `magick` is the new command. The build script uses `convert` — works with both via compatibility symlink.

## Installation Summary

### Debian/Ubuntu

```bash
sudo apt install imagemagick librsvg2-bin potrace gimp
```

### Fedora

```bash
sudo dnf install ImageMagick librsvg2-tools potrace gimp
```

### Flatpak (GIMP only)

```bash
flatpak install flathub org.gimp.GIMP
# ImageMagick, rsvg-convert, potrace and Python must be system packages
```

### Verification

```bash
magick --version
rsvg-convert --version
potrace --version
gimp --version
python3 --version
```

## Known Issues

| Issue | Impact | Workaround |
|-------|--------|------------|
| ImageMagick 7 `convert` deprecation | Warning messages | Ignore warnings; function unchanged |
| potrace single-colour tracing | Gradients lost in PNG/BMP sources | Use SVG sources |