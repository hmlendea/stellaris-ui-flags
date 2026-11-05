# Repository Overview

## Purpose

The Stellaris UI Flags repository provides a mod for the game Stellaris that adds hundreds of new flag designs matching the vanilla flag style. The repository encompasses:

- **Source assets**: Flag designs authored in editable formats (SVG, AI, XCF, PNG, BMP) organised by thematic category
- **Build pipeline**: A reproducible shell script (`build.sh`) that converts source assets to Stellaris-compatible DDS textures
- **Output package**: A distributable mod directory conforming to Stellaris mod structure with descriptor files for Steam Workshop, Paradox Mods, and Nexus Mods

## Scope

The repository owns:

- Source flag assets under `source/flags/` organised into 25+ thematic categories
- Background textures under `source/backgrounds/`
- Colour palette definition (`source/colours.txt`)
- English localisation (`source/localisation.yml`)
- Filename mapping (`source/names.txt`)
- GIMP Script-fu conversion scripts (`source/scripts/`)
- Build orchestration script (`build.sh`)
- GitHub Actions workflows for automated releases

The repository does not own:

- The Stellaris game engine or its mod loading system
- Distribution platforms (Steam Workshop, Paradox Mods, Nexus Mods)
- External build tools (ImageMagick, Inkscape, GIMP, potrace)
- Player game saves or runtime state

## Entry Points

### Build Entry Point

```bash
./build.sh <version>
```

Example: `./build.sh 1.0.0`

The build script is the sole entry point for producing the mod package. It requires a version argument and validates all required tools before execution.

### Source Asset Entry Points

Contributors add new flags by placing source files in the appropriate category directory under `source/flags/`. The build pipeline automatically discovers and processes all files.

### Distribution Entry Points

The built mod package in `out/ui-flags/` is consumed by:

- Steam Workshop (via GitHub Actions workflow)
- Paradox Mods (manual or automated upload)
- Nexus Mods (via GitHub Actions workflow)
- Direct GitHub Releases download

## Principal Capabilities

1. **Multi-format source support**: Accepts SVG, AI, XCF, PNG, BMP source formats
2. **Three-resolution output**: Generates 128px (main), 256px (map), and 24px (small) DDS textures
3. **Gradient bevel effect**: Applies signature bevel to main and small variants matching vanilla style
4. **Category taxonomy**: 25+ thematic categories with localised names
5. **Custom colour palette**: 30+ colours with HSV/RGB definitions for flag, map, and ship contexts
6. **Localisation support**: English category names via YAML localisation
7. **Filename mapping**: `names.txt` maps source filenames to output filenames
8. **Automated mod descriptors**: Generates `.mod` files for all distribution platforms
9. **Incremental builds**: Skips already-processed assets based on output existence
10. **CI/CD integration**: GitHub Actions workflows for Steam Workshop and Nexus Mods releases