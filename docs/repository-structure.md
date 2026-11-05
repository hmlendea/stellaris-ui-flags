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
│   │   ├── gradient-bevel.lisp
│   │   ├── png-to-dds.lisp
│   │   ├── svg-to-png.lisp
│   │   └── xcf-to-png.lisp
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
| `source/flags/<category>/` | Flag source files per thematic category | SVG, AI, XCF, PNG, BMP |
| `source/backgrounds/` | Background textures copied verbatim | DDS |
| `source/colours.txt` | Colour palette for flag/map/ship contexts | Stellaris colour format |
| `source/localisation.yml` | English category name localisation | YAML |
| `source/names.txt` | Source filename to output filename mapping | Key=value pairs |
| `source/thumbnail.png` | Mod thumbnail image | PNG |
| `source/scripts/*.lisp` | GIMP Script-fu conversion scripts | Scheme/Lisp |

### Build Pipeline (`build.sh`)

Single-file shell script containing:

- Configuration constants (Mod ID, name, version, Stellaris version)
- Path definitions (source, build, output directories)
- Tool detection (Inkscape, GIMP binaries - system + Flatpak)
- Conversion functions (`bmp-to-svg`, `png-to-svg`, `xcf-to-svg`, `ai-to-svg`, `svg-to-png`, `png-to-dds`, `apply-gradient-bevel`)
- Utility functions (`get-flag-file-name`, `generate-mod-descriptor`)
- Main execution loop (category iteration → file iteration → conversion pipeline)

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

- **Source flags**: Descriptive names with format extension (e.g., `mighty-spanner.svg`, `ui_mechanical_1.png`)
- **Output flags**: `ui_<category>_<number>.dds` or mapped names from `names.txt`
- **Categories**: Lowercase with hyphens (e.g., `ui_elder-scrolls`, `ui_starcraft`)
- **Scripts**: Kebab-case with `.lisp` extension (e.g., `gradient-bevel.lisp`)
- **Build directories**: Match category names exactly

## Gitignore Patterns

- `build/` — Intermediate build artefacts
- `out/` — Final build output
- `*.zip` — Release archives
- OS/editor files (`.DS_Store`, `*.swp`, etc.)