# Change Guide

## Overview

This guide covers the common modification scenarios: adding content, changing processing, and changing distribution. Each scenario lists the exact files to touch, the invariants to preserve, and the verification steps.

## Scenario Index

| Scenario | Files Changed | Rebuild Needed |
|----------|---------------|----------------|
| Add a flag | `source/flags/<cat>/`, maybe `names.txt` | Incremental OK |
| Add a category | `source/flags/<new>/`, `source/localisation.yml` | Incremental OK |
| Add a background | `source/backgrounds/` | Any build (static copy) |
| Add a colour | `source/colours.txt` | Any build (static copy) |
| Modify a flag | Source file + delete outputs | Full or per-asset |
| Change bevel | `source/scripts/gradient-bevel.lisp` | Full rebuild |
| Change DDS settings | `source/scripts/png-to-dds.lisp` | Full rebuild |
| Change version constant | `build.sh` | Rebuild |
| Add distribution platform | `.github/workflows/` | None |

---

## Adding a Flag

### Steps

1. **Prepare source file**
   - Preferred: SVG with transparent background
   - Acceptable: PNG, BMP, XCF, AI (see format trade-offs in `source-assets.md`)
   - Design on transparent or solid-removable background (INV-14)

2. **Place in category directory**
   ```
   source/flags/<category>/<source_name>.<ext>
   ```
   - Use an existing category, or see "Adding a Category" below
   - Source name: descriptive, hyphenated (e.g., `double-headed-eagle`)

3. **Decide output filename**
   - Default: `ui_<source_name>` (hyphens preserved)
   - Custom: add line to `source/names.txt`:
     ```
     double-headed-eagle=ui_imperial_eagle
     ```
   - Check for collisions within the category (INV-8)

4. **Build**
   ```bash
   ./build.sh <version>
   ```
   Incremental build processes only the new asset.

5. **Verify**
   - Three DDS files exist in `out/ui-flags/flags/<category>/`, `map/`, `small/`
   - In-game: flag appears in category, renders in all contexts

### Invariants to Preserve

- INV-5: three variants produced
- INV-6: same filename across variants
- INV-8: no output name collision
- INV-14: removable background

---

## Adding a Category

### Steps

1. **Create directory**
   ```bash
   mkdir source/flags/<new_category>
   ```

2. **Add localisation entry** to `source/localisation.yml`:
   ```yaml
   l_english:
       FLAG_CATEGORY_<new_category>:0 "Display Name"
   ```
   - Key must exactly match directory name (INV-11)
   - Do this in the same change as the directory creation

3. **Add flags** to the new directory (see "Adding a Flag")

4. **Build and verify**
   - Category appears in game with localised name (not raw key)
   - Flags appear under the category

### Notes

- Empty category directories are valid but produce empty categories in game
- Category discovery is automatic — no registry to update

---

## Adding a Background

### Steps

1. **Prepare DDS file**
   - Valid DDS with mipmaps, power-of-two dimensions
   - BC1 (opaque) or BC3 (alpha) compression
   - Place in `source/backgrounds/<name>.dds`

2. **Build** (any build — static copy refreshes every run)

3. **Verify in game** — background appears in selection

### Invariants

- INV-13: valid DDS format (build does not validate)

---

## Adding a Colour

### Steps

1. **Edit `source/colours.txt`** — add entry to the `colors = { ... }` block:
   ```
   my_colour = { hsv = { 0.5 0.8 0.9 } use_as_border_color = randomizable_combo = yes }
   ```
   - Set `use_as_border_color` if the colour should appear in border context
   - Set `randomizable_combo` if it should appear in random empire generation

2. **Build** (any build — static copy refreshes)

3. **Verify in game** — colour appears in flag/map/ship pickers

### Invariants

- INV-12: valid Stellaris syntax

---

## Modifying an Existing Flag

### Problem

Incremental builds skip assets whose three DDS outputs exist (INV-18). A modified source will **not** be reprocessed.

### Procedure

1. Edit the source file in `source/flags/<category>/`

2. Delete the existing outputs:
   ```bash
   rm out/ui-flags/flags/<category>/<output_name>.dds
   rm out/ui-flags/flags/<category>/map/<output_name>.dds
   rm out/ui-flags/flags/<category>/small/<output_name>.dds
   ```

3. Rebuild:
   ```bash
   ./build.sh <version>
   ```

4. Verify in game

### Alternative: Full Rebuild

For many modifications:
```bash
rm -rf build out
./build.sh <version>
```

---

## Changing the Bevel Effect

### Files

- `source/scripts/gradient-bevel.lisp` — parameters and colours

### Parameters

| Parameter | Current | Effect |
|-----------|---------|--------|
| `bevel-size` | 22 | Emboss extent (px) |
| `bevel-width` | 2.5 | Bump map blur width |
| `bevel-height` | 40 | Emboss depth/intensity |

### Colour Stops

| Layer | From | To |
|-------|------|-----|
| Logo gradient | white | grey |
| Colour Overlay | gold (178,164,136) | dark gold (113,82,9) |

### Procedure

1. Edit parameters in `gradient-bevel.lisp`
2. **Full rebuild required** (script changes not detected by incremental builds):
   ```bash
   rm -rf build out
   ./build.sh <version>
   ```
3. Verify visually: main and small flags beveled, map flags flat (INV-7)

### Caution

- Bevel applies to main (128px) and small (24px) only — do not add it to the map path
- Extreme values distort small flags (24px has little room for a 22px bevel)

---

## Changing DDS Export Settings

### Files

- `source/scripts/png-to-dds.lisp` — compression, mipmaps, linearity

### Current Settings

| Setting | Value |
|---------|-------|
| Compression | DXT1 (opaque) / DXT5 (alpha) auto |
| Mipmaps | Enabled |
| Texture type | Linear |

### Procedure

1. Edit `png-to-dds.lisp`
2. Full rebuild (see above)
3. Verify: flags load in game without texture errors; check file sizes (DXT1 < DXT5)

---

## Changing Build Constants

### File

- `build.sh` — constants at top

### Constants

| Constant | Current | When to Change |
|----------|---------|----------------|
| `MOD_ID` | `ui-flags` | Never (breaks paths, Workshop item) |
| `MOD_NAME` | `Universum Infinitum: Flags` | Rebranding |
| `STELLARIS_VERSION` | `v4.5.*` | New Stellaris major version |

### Procedure

1. Edit constant
2. Full rebuild (descriptors regenerate every build, but clean rebuild is safer)
3. Verify descriptors in `out/`

---

## Adding a Distribution Platform

### Steps

1. Create `.github/workflows/<platform>.yml` mirroring `steam-workshop.yml`:
   - Trigger: tag push `v*.*.*`
   - Download Release asset
   - Upload via platform action or API

2. Add platform secrets to repository settings

3. Test with a patch release (`v<x>.<y>.<z+1>`)

4. Update documentation:
   - `docs/build-and-deployment.md` — deployment section
   - `docs/integrations.md` — new platform section
   - `docs/dependencies.md` — CI actions table

### Invariants

- INV-19: Release asset must exist before workflows run
- INV-20: version consistency across artefacts

---

## Changing Localisation

### Steps

1. Edit `source/localisation.yml`
2. Build (any build — static copy refreshes)
3. Verify category names in game

### Adding a Language

1. Create `source/localisation_<lang>.yml` with `l_<lang>:` block
2. Modify `build.sh` static staging to copy additional localisation files
3. Update documentation

**Note:** Currently English-only (D14); adding languages requires a build script change.

---

## Renaming a Flag

### Safe Procedure

1. Update `source/names.txt` mapping (or rename source file)
2. **Delete old outputs** from `out/` (stale DDS files persist otherwise):
   ```bash
   rm out/ui-flags/flags/<cat>/<old_name>*.dds
   rm out/ui-flags/flags/<cat>/map/<old_name>*.dds
   rm out/ui-flags/flags/<cat>/small/<old_name>*.dds
   ```
3. Full rebuild recommended (renames are error-prone with incremental state)

### Risk

- Stale outputs: old-named DDS files remain in `out/` and ship in the mod
- Collision: new name collides with existing flag (INV-8)

---

## Removing a Flag

### Procedure

1. Delete source file from `source/flags/<category>/`
2. Remove `names.txt` entry if present
3. **Full rebuild** (`rm -rf build out`) — incremental builds do not remove stale outputs
4. Verify old DDS absent from `out/`

---

## Pre-Release Checklist

For any release, regardless of change type:

- [ ] Full clean rebuild succeeds: `rm -rf build out && ./build.sh <version>`
- [ ] Source/output counts match per category
- [ ] All three variants present per flag
- [ ] Descriptors show correct version
- [ ] In-game verification of changed content
- [ ] No texture errors in game log
- [ ] GitHub Release created with zip asset
- [ ] Tag pushed (triggers Steam + Nexus workflows)
- [ ] Paradox Mods manual upload
- [ ] Version consistent everywhere (INV-20)

---

## Change Impact Matrix

| Change | Build Type | In-Game Test | Docs Update |
|--------|-----------|--------------|-------------|
| New flag | Incremental | Yes | No |
| New category | Incremental | Yes | Category tables |
| New background | Any | Yes | Backgrounds list |
| New colour | Any | Yes | Colours list |
| Modified flag | Per-asset or full | Yes | No |
| Script change | Full | Yes (visual) | gimp-scripts.md |
| build.sh change | Full | Yes | build-pipeline.md, api-reference |
| Constant change | Full | Yes | configuration.md |
| New platform | None | No | integrations.md, build-and-deployment.md |