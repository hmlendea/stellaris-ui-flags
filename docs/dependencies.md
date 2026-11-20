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
| Commands used | `convert` (raster flattening) and `magick` (pixel reads, `svg-to-png` compositing) |
| Purpose | PNG → BMP flattening, alpha derivation, DDS pixel extraction |
| Install (Debian/Ubuntu) | `sudo apt install imagemagick` |
| Install (Fedora) | `sudo dnf install ImageMagick` |
| Install (Arch) | `sudo pacman -S imagemagick` |
| Flatpak | N/A (system tool) |

**Used by:** `png-to-bmp`, `bmp-to-svg` (via `png-to-svg`), `svg-to-png`, `png_to_dds.py`

The start-up check tests `/usr/bin/convert`. The alphabet channel derivation in `svg-to-png` and the
pixel extraction in `png_to_dds.py` use `magick`.

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

**Used by:** `bmp-to-svg`

**Flags used:** `--opaque`, `-s` (SVG output), `-o` (output file)

---

### GIMP

| Property | Value |
|----------|-------|
| Minimum version | 3.0 |
| Command used | `gimp` |
| Purpose | Python-Fu execution: gradient bevel (batched) |
| Install (Debian/Ubuntu) | `sudo apt install gimp` |
| Flatpak ID | `org.gimp.GIMP` |

**Used by:** `bevel-pngs` via `execute-gimp-script-file`

**Flags used:** `--new-instance` (isolated session), `-i` (no interface), `--batch-interpreter=python-fu-eval`, `-b` (batch command), `--quit`

**Detection paths (in order, resolved lazily at the first bevel session):**
1. `/usr/bin/gimp`
2. `/var/lib/flatpak/exports/bin/org.gimp.GIMP`
3. `${HOME}/.local/share/flatpak/exports/bin/org.gimp.GIMP`

GIMP is **not** required at start-up; a build in which every flag is already processed never starts a
session and therefore never needs GIMP installed.

## GIMP Plug-ins

GIMP 3 bundles every plug-in the build requires, including the GEGL operations used by the bevel
effect. No separate plug-in package is needed.

### Built-in Plug-ins (bundled with GIMP)

| Plug-in | PDB Function | Purpose |
|---------|--------------|---------|
| PNG import | `file-png-load` | Load PNG files |
| PNG export | `file-png-export` | Write PNG files |
| Gaussian Blur | `gegl:gaussian-blur` | Bump map smoothing |
| Bump Map | `gegl:bump-map` | Bevel embossing |

## CI/CD Dependencies

### GitHub Actions

| Workflow | Action | Version | Purpose |
|----------|--------|---------|---------|
| steam-workshop-release.yml | `actions/checkout` | v7 | Repository checkout |
| steam-workshop-release.yml | `hmlendea/steam-workshop-update` | latest | Steam Workshop upload |
| nexus-mods-release.yml | `actions/checkout` | v7 | Repository checkout |
| nexus-mods-release.yml | `Nexus-Mods/upload-action` | v1.0.0-beta.11 | Nexus Mods upload |

### Release Build Tools

Both release workflows install the toolchain on the runner before building:

| Tool | Package | Purpose |
|------|---------|---------|
| GIMP | `gimp` | Python-Fu execution for the batched gradient bevel |
| ImageMagick | `imagemagick` | PNG→BMP flattening, alpha derivation, pixel reads |
| librsvg | `librsvg2-bin` | SVG→PNG rasterisation |
| potrace | `potrace` | BMP→SVG vectorisation |

### Secrets

| Secret | Workflow | Purpose |
|--------|----------|---------|
| `STEAM_USERNAME` | steam-workshop-release.yml | Steam account login |
| `STEAM_PASSWORD` | steam-workshop-release.yml | Steam account password |
| `STEAM_2FASEED` | steam-workshop-release.yml | Steam 2FA seed for TOTP |
| `NEXUSMODS_API_KEY` | nexus-mods-release.yml | Nexus Mods API key |

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
├── ImageMagick (convert, magick)
│   └── Used by: png-to-bmp, png-to-svg, svg-to-png, png_to_dds.py
├── rsvg-convert
│   └── Used by: svg-to-png
├── Python 3
│   └── Used by: png-to-dds
├── potrace
│   └── Used by: bmp-to-svg
└── GIMP (lazy, only for bevel sessions)
    ├── PNG import (file-png-load)
    │   └── Used by: gradient_bevel
    ├── PNG export (file-png-export)
    │   └── Used by: gradient_bevel
    ├── Gaussian Blur (gegl:gaussian-blur)
    │   └── Used by: gradient_bevel
    └── Bump Map (gegl:bump-map)
        └── Used by: gradient_bevel

The SVG rasterisation and the DDS export do not use GIMP, so each flag needs only the bevels.
```

## Version Compatibility

| Tool | Tested Versions | Notes |
|------|-----------------|-------|
| GIMP | 3.0.x, 3.2.x | Primary target |
| librsvg | 2.6x | `rsvg-convert` for SVG rasterisation |
| Python | 3.x | Writes the DDS directly |
| ImageMagick | 6.x, 7.x | The build uses both `convert` (raster flattening) and `magick` (pixel reads and compositing) |
| potrace | 1.x | Stable API |

**GIMP 2 note:** GIMP 2.10 is end of life and unsupported. The scripts use the GIMP 3 Python-Fu API and the GEGL filter API; the previous GIMP 2.10 Script-fu scripts and the separate `gimp-dds` plug-in are no longer used.

**ImageMagick note:** The build uses `convert` for the raster flattening step and `magick` for the SVG alpha derivation and the DDS pixel extraction. IM7 keeps `convert` as a legacy alias, so both commands work on IM6 and IM7.

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
convert --version
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