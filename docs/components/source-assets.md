# Source Assets

## Overview

Source assets are the authoritative input files for the mod. They reside in `source/` and are organised by type and category. The build pipeline treats source assets as **immutable inputs** — they are never modified by the build process.

## Directory Structure

```
source/
├── colours.txt              # Colour palette (Stellaris format)
├── localisation.yml         # Category name localisation
├── names.txt                # Filename mapping (source → output)
├── thumbnail.png            # Mod thumbnail
├── backgrounds/             # Background textures (DDS)
│   ├── ui_checkboard.dds
│   ├── ui_circle_bicolour.dds
│   ├── ui_diagonal_stripe.dds
│   └── ... (40+ files)
├── flags/                   # Flag designs by category
│   ├── aquatic/
│   ├── blocky/
│   ├── corporate/
│   ├── domination/
│   ├── fire/
│   ├── human/
│   ├── mechanical/
│   ├── ornate/
│   ├── pirate/
│   ├── plantoid/
│   ├── pointy/
│   ├── spherical/
│   ├── toxoid/
│   ├── ui_civ/
│   ├── ui_civbe/
│   ├── ui_dune/
│   ├── ui_elder-scrolls/
│   ├── ui_galciv/
│   ├── ui_logos/
│   ├── ui_marvel/
│   ├── ui_other-media/
│   ├── ui_pandora/
│   ├── ui_pax-nova/
│   ├── ui_starcraft/
│   ├── ui_starwars/
│   ├── ui_total-war/
│   └── zoological/
└── scripts/                 # GIMP Script-fu scripts
    ├── gradient-bevel.lisp
    ├── png-to-dds.lisp
    ├── svg-to-png.lisp
    └── xcf-to-png.lisp
```

## Asset Taxonomy

### By Format

| Format | Extension | Source Location | Conversion Path |
|--------|-----------|-----------------|-----------------|
| SVG | `.svg` | `source/flags/*/` | Direct → PNG → DDS |
| PNG | `.png` | `source/flags/*/` | PNG → BMP → SVG → PNG → DDS |
| XCF | `.xcf` | `source/flags/*/` | XCF → PNG → BMP → SVG → PNG → DDS |
| AI | `.ai` | `source/flags/*/` | AI → SVG → PNG → DDS |
| BMP | `.bmp` | `source/flags/*/` | BMP → SVG → PNG → DDS |
| DDS | `.dds` | `source/backgrounds/` | Copied verbatim |

### By Category Type

| Category Prefix | Description | Examples |
|-----------------|-------------|----------|
| (none) | Base game species archetypes | `aquatic`, `human`, `plantoid`, `toxoid` |
| `ui_` | UI-style / geometric designs | `ui_civ`, `ui_logos`, `ui_galciv` |
| `ui_<franchise>` | Media franchise references | `ui_starwars`, `ui_marvel`, `ui_dune` |

### Category Directory Structure

Each category under `source/flags/` contains:

```
source/flags/<category>/
├── flag-design-1.svg
├── flag-design-2.png
├── flag-design-3.xcf
├── flag-design-4.ai
├── usage.txt              # Optional: usage restrictions/notes
└── ... (more assets)
```

## Format Details

### SVG (Preferred)

**Advantages:**
- Vector format — scales cleanly to all three resolutions
- Single source → three outputs without quality loss
- Direct rendering by Inkscape (fastest path)

**Requirements:**
- Valid SVG 1.1
- No external references (embedded images only)
- ViewBox defined for consistent rendering

**Example:**
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <rect fill="#FFD700" width="128" height="128"/>
  <path fill="#8B0000" d="M32,32 L96,32 L64,96 Z"/>
</svg>
```

### PNG (Raster Source)

**Conversion:** PNG → BMP (ImageMagick) → SVG (potrace) → PNG (Inkscape) → DDS

**Limitations:**
- Raster-to-vector tracing (potrace) may lose detail
- Best for simple, high-contrast designs
- Anti-aliased edges trace poorly

**Best Practices:**
- Use solid colours, no gradients
- High contrast between foreground/background
- Minimum 128x128px source resolution

### XCF (GIMP Native)

**Conversion:** XCF → PNG (GIMP) → BMP → SVG → PNG → DDS

**Use Case:**
- Layered designs with effects
- Complex compositions requiring GIMP editing

**Limitations:**
- Longest conversion path
- Layer merging flattens effects

### AI (Adobe Illustrator)

**Conversion:** AI → SVG (Inkscape) → PNG → DDS

**Requirements:**
- Inkscape must support the AI version
- Complex AI features may not convert

### BMP (Bitmap)

**Conversion:** BMP → SVG (potrace) → PNG → DDS

**Use Case:**
- Legacy assets
- Simple monochrome designs

### DDS (Backgrounds Only)

**Location:** `source/backgrounds/`

**Handling:** Copied directly to output — no conversion

**Requirements:**
- Valid DDS with mipmaps
- BC1/BC3 compression (DXT1/DXT5)
- Power-of-two dimensions

## Category Reference

### Base Game Archetypes

| Category | Theme | Typical Designs |
|----------|-------|-----------------|
| `aquatic` | Oceanic, marine life | Fish, waves, coral, tridents |
| `blocky` | Geometric, voxel | Cubes, pixels, Minecraft-style |
| `corporate` | Business, logos | Clean logos, initials, geometric |
| `domination` | Military, conquest | Eagles, swords, shields, laurels |
| `fire` | Flame, volcanic | Fire, magma, phoenix, embers |
| `human` | Historical, cultural | Flags, coats of arms, symbols |
| `mechanical` | Industrial, robotic | Gears, cogs, circuitry, rivets |
| `ornate` | Decorative, baroque | Filigree, flourishes, heraldry |
| `pirate` | Piracy, nautical | Skulls, crossbones, ships, maps |
| `plantoid` | Botanical, organic | Leaves, vines, flowers, trees |
| `pointy` | Sharp, angular | Spikes, triangles, stars, shards |
| `spherical` | Round, planetary | Globes, orbits, spheres, rings |
| `toxoid` | Toxic, hazardous | Biohazard, radiation, slime, gas |
| `zoological` | Animal kingdom | Animal silhouettes, paw prints |

### UI-Style Categories

| Category | Source Inspiration |
|----------|-------------------|
| `ui_civ` | Civilization series UI |
| `ui_civbe` | Civilization: Beyond Earth |
| `ui_dune` | Dune franchise |
| `ui_elder-scrolls` | The Elder Scrolls |
| `ui_galciv` | Galactic Civilizations |
| `ui_logos` | Generic logo designs |
| `ui_marvel` | Marvel Comics/MCU |
| `ui_other-media` | Miscellaneous media |
| `ui_pandora` | Pandora: First Contact |
| `ui_pax-nova` | Pax Nova |
| `ui_starcraft` | StarCraft |
| `ui_starwars` | Star Wars |
| `ui_total-war` | Total War series |

## Background Textures

**Location:** `source/backgrounds/`

**Count:** 40+ files

**Categories:**

| Pattern Type | Examples |
|--------------|----------|
| Checkerboard | `ui_checkboard.dds`, `ui_checkboard_inverted.dds` |
| Circles | `ui_circle_bicolour.dds`, `ui_circle_halfinverted.dds`, `ui_circle_hallow.dds` |
| Crosses | `ui_cross.dds`, `ui_diagonal_cross.dds`, `ui_diagonal_cross2.dds` |
| Diagonals | `ui_diagonal_stripe.dds`, `ui_diagonal_flipped.dds` |
| Diamonds | `ui_diamond.dds`, `ui_diamond2.dds`, `ui_diamond3.dds` |
| Hexagons | `ui_hexagon.dds`, `ui_double_hemispheres_hexagonal.dds` |
| Stripes | `ui_stripes_horizontal.dds`, `ui_straight_stripes.dds`, `ui_stripe_large.dds` |
| Stars | `ui_star.dds`, `ui_star2.dds`, `ui_star_bicolour.dds`, `ui_webstar.dds` |
| Shapes | `ui_cog.dds`, `ui_house.dds`, `ui_hills.dds`, `ui_square.dds` |
| Special | `ui_fallout.dds`, `ui_galciv_terran.dds`, `ui_new_dawn_flipped.dds` |

**Usage:** Selected as flag background in empire customisation. Each provides a distinct visual texture behind the flag emblem.

## Colour Palette

**File:** `source/colours.txt`

**Structure:**
```txt
colors = {
    colour_name = {
        flag = hsv { H S V }
        map = hsv { H S V }
        ship = hsv { H S V }
        use_as_border_color = yes/no
    }
}

randomizable_combo = { colour1 colour2 colour3 }
```

**Current Colours:** 30+ defined colours including:
- Standard: `white`, `black`, `grey`, `red`, `blue`, `green`, `yellow`, `orange`, `purple`, `pink`, `brown`
- Metallic: `gold`, `silver`, `bronze`, `copper`, `steel`, `iron`
- Special: `emerald`, `ruby`, `sapphire`, `amethyst`, `obsidian`, `pearl`
- Sci-fi: `plasma`, `void`, `neon`, `cyber`, `hologram`

**Randomizable Combos:** Pre-defined triads for random empire generation.

## Localisation

**File:** `source/localisation.yml`

**Format:**
```yaml
l_english:
 FLAG_CATEGORY_aquatic:0 "Aquatic"
 FLAG_CATEGORY_blocky:0 "Blocky"
 FLAG_CATEGORY_ui_starwars:0 "Star Wars"
 # ... 25+ entries
```

**Key Pattern:** `FLAG_CATEGORY_<directory_name>:0 "Display Name"`

**Language Support:** English only (`l_english`). Additional languages would require new `l_<language>:` sections.

## Filename Mapping

**File:** `source/names.txt`

**Format:**
```txt
source_filename=output_filename
```

**Examples:**
```txt
mighty-spanner=ui_mechanical_1
eye-target=ui_mechanical_2
imperial-eagle=ui_domination_1
```

**Resolution Logic:**
1. Look up source filename (without extension) in `names.txt`
2. If found, use mapped value
3. If not found, default to `ui_<source_filename>`

**Purpose:** Ensures consistent, predictable output filenames regardless of source naming conventions.

## Thumbnail

**File:** `source/thumbnail.png`

**Specifications:**
- Format: PNG
- Recommended: 256x256px
- Used in: Stellaris launcher, Steam Workshop, Nexus Mods, GitHub Releases

## GIMP Script-fu Scripts

**Location:** `source/scripts/`

| Script | Purpose | Invoked By |
|--------|---------|------------|
| `gradient-bevel.lisp` | Applies 3D bevel effect with gradient shading | `apply-gradient-bevel` function |
| `png-to-dds.lisp` | Exports PNG to DDS with game-compatible settings | `png-to-dds` function |
| `svg-to-png.lisp` | Renders SVG to PNG at specified size | `svg-to-png` function |
| `xcf-to-png.lisp` | Exports XCF (GIMP) to PNG | `xcf-to-png` function |

See [GIMP Scripts Component](../components/gimp-scripts.md) for detailed documentation.

## Asset Addition Workflow

### Adding a New Flag Design

1. **Choose category** (or create new directory under `source/flags/`)
2. **Create source asset** in preferred format (SVG recommended)
3. **Place in category directory:** `source/flags/<category>/my-flag.svg`
4. **Optional:** Add entry to `source/names.txt` for custom output name
5. **Run build:** `./build.sh <version>`
6. **Verify output:** Check `out/ui-flags/flags/<category>/`

### Adding a New Category

1. **Create directory:** `mkdir source/flags/my-category`
2. **Add flag assets** to directory
3. **Add localisation:** Add `FLAG_CATEGORY_my-category:0 "My Category"` to `source/localisation.yml`
4. **Optional:** Add `usage.txt` for special restrictions
5. **Run build** — category auto-discovered

### Adding a Background Texture

1. **Create DDS file** with proper format (BC1/BC3, mipmaps, power-of-two)
2. **Place in:** `source/backgrounds/my-background.dds`
3. **Run build** — auto-copied to output

### Adding a Colour

1. **Edit `source/colours.txt`**
2. **Add colour definition** with flag/map/ship HSV values
3. **Set `use_as_border_color`** appropriately
4. **Optional:** Add to `randomizable_combo`
5. **Run build** — copied to output

## Validation Rules

### Source Asset Validation (Build-Time)

| Check | Failure Action |
|-------|----------------|
| Source directory exists | Abort build |
| Required tools available | Abort build |
| Conversion produces output | Skip asset, continue |
| Output DDS files created | Skip asset, continue |

### Manual Validation (Pre-Release)

- [ ] All source assets render without errors
- [ ] Output DDS files open in GIMP
- [ ] Colours match palette in-game
- [ ] Localisation displays correctly
- [ ] Thumbnail appears in launcher
- [ ] Backgrounds selectable in empire customisation

## File Naming Conventions

### Source Files

- Lowercase with hyphens: `my-flag-design.svg`
- Descriptive names: `imperial-eagle.svg`, `corporate-logo-1.png`
- No spaces or special characters

### Output Files (via names.txt or default)

- Prefix: `ui_` (configurable via `FILE_PREFIX` in build.sh)
- Category prefix encouraged: `ui_mechanical_1`, `ui_domination_eagle`
- Lowercase with underscores: `ui_mechanical_gear.dds`

### Background Files

- Prefix: `ui_`
- Descriptive: `ui_checkboard.dds`, `ui_diagonal_stripe.dds`
- Lowercase with underscores

## Asset Counts (Approximate)

| Asset Type | Count |
|------------|-------|
| Flag designs (all categories) | 300+ |
| Background textures | 40+ |
| Colours defined | 30+ |
| Categories | 25+ |
| GIMP scripts | 4 |
| Localisation entries | 25+ |
| Filename mappings | 100+ |