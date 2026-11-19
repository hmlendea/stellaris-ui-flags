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

**Used by:** `png-to-svg`, `xcf-to-svg`

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

**Used by:** `bmp-to-svg`, `png-to-svg`, `xcf-to-svg`

**Flags used:** `-s` (SVG output), `-o` (output file)

---

### Inkscape

| Property | Value |
|----------|-------|
| Minimum version | 1.0 |
| Command used | `inkscape` |
| Purpose | AI → SVG conversion |
| Install (Debian/Ubuntu) | `sudo apt install inkscape` |
| Flatpak ID | `org.inkscape.Inkscape` |

**Used by:** `ai-to-svg`

**Flags used:** `--export-type=svg`, `--export-filename=<path>`

**Detection paths (in order):**
1. System PATH (`which inkscape`)
2. `/var/lib/flatpak/exports/bin/org.inkscape.Inkscape`
3. `~/.local/share/flatpak/exports/bin/org.inkscape.Inkscape`

---

### GIMP

| Property | Value |
|----------|-------|
| Minimum version | 3.0 |
| Command used | `gimp` |
| Purpose | Python-Fu execution: SVG→PNG, XCF→PNG, bevel, DDS export |
| Install (Debian/Ubuntu) | `sudo apt install gimp` |
| Flatpak ID | `org.gimp.GIMP` |

**Used by:** `svg-to-png`, `png-to-dds`, `apply-gradient-bevel`, `xcf-to-png`

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
| SVG import | `file-svg-load` | Load SVG files at a target size |
| PNG import | `file-png-load` | Load PNG files |
| PNG export | `file-png-export` | Write PNG files |
| DDS export | `file-dds-export` | Write DDS textures |
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
├── ImageMagick (convert)
│   └── Used by: png-to-svg, xcf-to-svg
├── potrace
│   └── Used by: bmp-to-svg, png-to-svg, xcf-to-svg
├── Inkscape
│   └── Used by: ai-to-svg
└── GIMP
    ├── SVG import (file-svg-load)
    │   └── Used by: svg-to-png
    ├── PNG export (file-png-export)
    │   └── Used by: svg-to-png, gradient-bevel, xcf-to-png
    ├── DDS export (file-dds-export)
    │   └── Used by: png-to-dds
    ├── Colour to Alpha (gegl:color-to-alpha)
    │   └── Used by: svg-to-png
    ├── Gaussian Blur (gegl:gaussian-blur)
    │   └── Used by: gradient-bevel
    └── Bump Map (gegl:bump-map)
        └── Used by: gradient-bevel
```

## Version Compatibility

| Tool | Tested Versions | Notes |
|------|-----------------|-------|
| GIMP | 3.0.x, 3.2.x | Primary target |
| Inkscape | 1.x | CLI flags stable since 1.0 |
| ImageMagick | 6.x, 7.x | `convert` deprecated in 7.x but still works |
| potrace | 1.x | Stable API |

**GIMP 2 note:** GIMP 2.10 is end of life and unsupported. The scripts use the GIMP 3 Python-Fu API and the GEGL filter API; the previous GIMP 2.10 Script-fu scripts and the separate `gimp-dds` plug-in are no longer used.

**ImageMagick 7 note:** `convert` is a legacy alias; `magick` is the new command. The build script uses `convert` — works with both via compatibility symlink.

## Installation Summary

### Debian/Ubuntu

```bash
sudo apt install imagemagick potrace inkscape gimp
```

### Fedora

```bash
sudo dnf install ImageMagick potrace inkscape gimp
```

### Flatpak (tools only)

```bash
flatpak install flathub org.inkscape.Inkscape
flatpak install flathub org.gimp.GIMP
# ImageMagick and potrace must be system packages
```

### Verification

```bash
convert --version
potrace --version
inkscape --version
gimp --version
```

## Known Issues

| Issue | Impact | Workaround |
|-------|--------|------------|
| ImageMagick 7 `convert` deprecation | Warning messages | Ignore warnings; function unchanged |
| Inkscape AI import limitations | Complex AI files convert poorly | Export SVG from Illustrator instead |
| potrace single-colour tracing | Gradients lost in PNG/BMP sources | Use SVG sources |