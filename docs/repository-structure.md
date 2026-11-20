# Repository Structure

## Source Tree Layout

```
stellaris-ui-flags/
├── ARCHITECTURE.md
├── build.sh
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── LICENSE
├── PRIVACY.md
├── README.md
├── SECURITY.md
├── build/
│   └── <category>/
│       ├── map/
│       └── small/
├── out/
│   ├── ui-flags/
│   │   ├── flags/
│   │   │   ├── <category>/
│   │   │   │   ├── map/
│   │   │   │   ├── small/
│   │   │   │   └── *.dds
│   │   │   ├── backgrounds/
│   │   │   └── colors.txt
│   │   ├── localisation/
│   │   │   └── ui-flags_l_english.yml
│   │   ├── thumbnail.png
│   │   └── descriptor.mod
│   └── ui-flags.mod
├── source/
│   ├── backgrounds/
│   ├── colours.txt
│   ├── flags/
│   │   ├── aquatic/
│   │   ├── blocky/
│   │   ├── corporate/
│   │   ├── domination/
│   │   ├── fire/
│   │   ├── human/
│   │   ├── mechanical/
│   │   ├── ornate/
│   │   ├── pirate/
│   │   ├── plantoid/
│   │   ├── pointy/
│   │   ├── spherical/
│   │   ├── toxoid/
│   │   ├── ui_civ/
│   │   ├── ui_civbe/
│   │   ├── ui_dune/
│   │   ├── ui_elder-scrolls/
│   │   ├── ui_galciv/
│   │   ├── ui_logos/
│   │   ├── ui_marvel/
│   │   ├── ui_other-media/
│   │   ├── ui_pandora/
│   │   ├── ui_pax-nova/
│   │   ├── ui_starcraft/
│   │   ├── ui_starwars/
│   │   ├── ui_total-war/
│   │   └── zoological/
│   ├── localisation.yml
│   ├── names.txt
│   ├── scripts/
│   │   ├── bevel_batch.py
│   │   ├── gimp_image_operations.py
│   │   ├── gimp_procedures.py
│   │   ├── gimp_script_arguments.py
│   │   ├── gimp_script_errors.py
│   │   ├── gradient_bevel.py
│   │   └── png_to_dds.py
│   └── thumbnail.png
├── .github/
│   ├── FUNDING.yml
│   ├── cover.png
│   └── workflows/
│       ├── nexus-mods.yml
│       └── steam-workshop.yml
└── docs/
    ├── INDEX.md
    ├── architecture.md
    ├── repository-overview.md
    ├── repository-structure.md
    ├── build-and-deployment.md
    ├── configuration.md
    ├── data-model.md
    ├── dependencies.md
    ├── design-decisions.md
    ├── api-reference/
    ├── behaviour/
    ├── components/
    └── flows/
```

## Module Organisation

### Source Assets (`source/`)

| Path | Purpose | Format |
|------|---------|--------|
| `source/flags/<category>/` | Flag source files per thematic category | SVG, PNG, BMP |
| `source/backgrounds/` | Background textures copied verbatim | DDS |
| `source/colours.txt` | Colour palette for flag/map/ship contexts | Stellaris colour format |
| `source/localisation.yml` | English category name localisation | YAML |
| `source/names.txt` | Source filename to output filename mapping | Key=value pairs |
| `source/thumbnail.png` | Mod thumbnail image | PNG |
| `source/scripts/*.py` | Build scripts for DDS export and the gradient bevel | Python |

### Build Pipeline (`build.sh`)

Single-file shell script containing:

- Configuration constants (Mod ID, name, version, Stellaris version, concurrency, attempt count)
- Path definitions (source, build, output directories)
- Tool detection (start-up tools plus a lazy GIMP lookup)
- Conversion functions (`bmp-to-svg`, `png-to-svg`, `svg-to-png`, `png-to-dds`, `export-map-dds`, `export-beveled-dds`, `bevel-pngs`)
- Utility functions (`get-flag-file-name`, `generate-mod-descriptor`, `collect-unbeveled-pngs`, `report-unbeveled-flags`)
- Main execution loop (category iteration → asset registration → parallel workers → batched bevel rounds → exports)

### Output Package (`out/ui-flags/`)

Conforms to Stellaris mod directory structure:

```
out/ui-flags/
├── descriptor.mod
├── flags/
│   ├── backgrounds/
│   ├── colors.txt
│   └── <category>/
│       ├── map/
│       ├── small/
│       └── *.dds
├── localisation/
│   └── ui-flags_l_english.yml
└── thumbnail.png
```

### CI/CD Workflows (`.github/workflows/`)

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `nexus-mods.yml` | Push tag `v*.*.*` | Download release asset, upload to Nexus Mods |
| `steam-workshop.yml` | Push tag `v*.*.*` | Download release asset, upload to Steam Workshop |

## File Naming Conventions

- **Source flags**: Descriptive names with format extension (e.g., `mighty-spanner.svg`, `pointy_1.png`)
- **Output flags**: `ui_<category>_<number>.dds` or mapped names from `names.txt`
- **Categories**: Lowercase with hyphens or underscores (e.g., `ui_elder-scrolls`, `ui_starcraft`, `ui_civ`)
- **Scripts**: Snake case with `.py` extension (e.g., `gradient_bevel.py`, `png_to_dds.py`)
- **Build directories**: Match category names exactly

## Gitignore Patterns

- `build/` — Intermediate build artefacts
- `out/` — Final build output
- `__pycache__/` — Python bytecode cache from the scripts under `source/scripts/`
- OS/editor files (`.DS_Store`, `*.swp`, etc.)