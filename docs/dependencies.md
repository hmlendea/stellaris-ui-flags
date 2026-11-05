# Dependencies

## Overview

The project has three dependency categories:

1. **Build-time tools** — required to run `build.sh`
2. **GIMP plug-ins** — required by Script-fu scripts
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
| Minimum version | 2.10 |
| Command used | `gimp` |
| Purpose | Script-fu execution: SVG→PNG, XCF→PNG, bevel, DDS export |
| Install (Debian/Ubuntu) | `sudo apt install gimp gimp-dds` |
| Flatpak ID | `org.gimp.GIMP` |

**Used by:** `svg-to-png`, `png-to-dds`, `apply-gradient-bevel`, `xcf-to-png`

**Flags used:** `-i` (no interface), `-b` (batch command)

**Detection paths (in order):**
1. System PATH (`which gimp`)
2. `/var/lib/flatpak/exports/bin/org.gimp.GIMP`
3. `~/.local/share/flatpak/exports/bin/org.gimp.GIMP`

## GIMP Plug-ins

### DDS Plug-in

| Property | Value |
|----------|-------|
| Required PDB function | `file-dds-save` |
| Purpose | DDS texture export |
| Package (Debian/Ubuntu) | `gimp-dds` |
| Manual install | Copy plug-in binary to GIMP plug-ins directory |

**Plug-in directories:**
- System: `/usr/lib/gimp/2.0/plug-ins/`
- User: `~/.config/GIMP/2.10/plug-ins/`
- Flatpak: `~/.var/app/org.gimp.GIMP/config/GIMP/2.10/plug-ins/`

**Note:** Flatpak GIMP may not bundle the DDS plug-in — install manually.

### Built-in Plug-ins (bundled with GIMP)

| Plug-in | PDB Function | Purpose |
|---------|--------------|---------|
| SVG import | `gimp-file-load` (SVG) | Load SVG files |
| Colour to Alpha | `plug-in-colortoalpha` | Remove solid backgrounds |
| Bump Map | `plug-in-bump-map` | Bevel embossing |
| Gaussian Blur | `plug-in-gauss` | Bump map smoothing |

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
    ├── DDS plug-in (file-dds-save)
    │   └── Used by: png-to-dds
    ├── SVG import (built-in)
    │   └── Used by: svg-to-png
    ├── Colour to Alpha (built-in)
    │   └── Used by: svg-to-png
    ├── Bump Map (built-in)
    │   └── Used by: gradient-bevel
    └── Gaussian Blur (built-in)
        └── Used by: gradient-bevel
```

## Version Compatibility

| Tool | Tested Versions | Notes |
|------|-----------------|-------|
| GIMP | 2.10.x | Primary target |
| GIMP | 2.99.x (dev) | Generally works; Script-fu API stable |
| Inkscape | 1.x | CLI flags stable since 1.0 |
| ImageMagick | 6.x, 7.x | `convert` deprecated in 7.x but still works |
| potrace | 1.x | Stable API |

**ImageMagick 7 note:** `convert` is a legacy alias; `magick` is the new command. The build script uses `convert` — works with both via compatibility symlink.

## Installation Summary

### Debian/Ubuntu

```bash
sudo apt install imagemagick potrace inkscape gimp gimp-dds
```

### Fedora

```bash
sudo dnf install ImageMagick potrace inkscape gimp
# DDS plug-in: install manually or from COPR
```

### Flatpak (tools only)

```bash
flatpak install flathub org.inkscape.Inkscape
flatpak install flathub org.gimp.GIMP
# ImageMagick and potrace must be system packages
# DDS plug-in: install into Flatpak GIMP manually
```

### Verification

```bash
convert --version
potrace --version
inkscape --version
gimp --version

# Verify DDS plug-in
gimp -i -b "(png-to-dds \"/tmp/test.png\" \"/tmp/test.dds\")" -b "(gimp-quit 0)" 2>&1 | grep -i "error"
# No output = plug-in working (assuming valid /tmp/test.png)
```

## Known Issues

| Issue | Impact | Workaround |
|-------|--------|------------|
| Flatpak GIMP missing DDS plug-in | DDS export fails | Install plug-in into Flatpak config dir |
| ImageMagick 7 `convert` deprecation | Warning messages | Ignore warnings; function unchanged |
| Inkscape AI import limitations | Complex AI files convert poorly | Export SVG from Illustrator instead |
| potrace single-colour tracing | Gradients lost in PNG/BMP sources | Use SVG sources |