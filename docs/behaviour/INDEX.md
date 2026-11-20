# Behaviour

## Overview

This document describes the observable behaviour of the mod and its build pipeline — what users and contributors can expect from the system under normal and exceptional conditions.

## Build Pipeline Behaviour

### Normal Operation

**Invocation:** `./build.sh <version>`

**Observable Sequence:**

1. **Session banner** — the first line reports the chosen bevel batch size and GIMP concurrency
2. **Tool validation** — errors printed if a start-up tool is missing, exit 1
3. **Asset staging** — no output, files copied silently
4. **Asset processing** — `magick`/`potrace`/`rsvg-convert` progress lines and their own output
5. **Bevel rounds** — one `[INFO] Beveling '<path>'` line per image inside each GIMP session
6. **Retry notice** — `Beveling <n> flags again on attempt <n>...` when a round was incomplete
7. **Completion** — `Produced <n> of <n> flag DDS files.`; any unbeveled flags are reported before it

**Expected Duration:**
- Full build: several minutes, bounded by the number of GIMP bevel sessions (378 assets)
- Incremental: <30 seconds (few new assets)

### Incremental Build Behaviour

**Trigger:** Re-running build without cleaning `build/` and `out/`

**Behaviour:**
- Assets with all three output DDS files present are **skipped silently**
- New assets are processed normally
- No indication of skipped vs processed count

**Limitations:**
- Source file modifications are **not detected** — modified sources are skipped if outputs exist
- Script/configuration changes are **not detected**
- Full rebuild required after changing `gradient_bevel.py` or conversion logic

### Error Behaviour

**Setup Errors (fail fast):**

| Condition | Behaviour |
|-----------|-----------|
| Missing version argument | Print `Please specify a version!`, exit 1 |
| Missing `source/` directory | Print "MISSING SOURCE DIRECTORY", exit 255 (`-1`) |
| Missing ImageMagick | Print error, exit 1 |
| Missing potrace | Print error, exit 1 |
| Missing Python 3 or `rsvg-convert` | Print error, exit 1 |
| Missing GIMP | Print error only when the first bevel session starts, exit 1 |

**Asset Errors (continue):**

| Condition | Behaviour |
|-----------|-----------|
| Unsupported file extension | Print `[WARNING] Unsupported source format`, skip asset |
| Conversion tool failure | Asset skipped, pipeline continues |
| Bevel failure on one image | Warning logged, batch continues; the image is retried in the next round |
| Session killed mid-batch | Images it never reached stay unmarked and are retried, then reported if still missing |

**Design Philosophy:** Setup problems abort immediately; individual asset problems don't block the rest of the build.

### Output Behaviour

**On Success:**
- Complete mod package at `out/ui-flags/`
- Root descriptor at `out/ui-flags.mod`
- Final line: `Produced <n> of <n> flag DDS files.`
- Exit code 0

**On Partial Failure:**
- Package contains successfully processed assets
- Failed assets simply absent from output
- Bevels that remained unmarked are listed with a diagnosed reason before the final count
- Exit code reflects any fatal conversion/export error (see [Error Handling](error-handling.md))

**Implication:** The final count and any unbeveled report should be checked after each build; a skipped asset is otherwise silent.

## Mod Behaviour In-Game

### Empire Customisation

**Flag Selection:**
- All categories appear in flag category picker
- Category names from localisation file
- Flags within category selectable as emblems
- Backgrounds selectable from `flags/backgrounds/`
- Colours selectable from `flags/colors.txt`

**Colour Behaviour:**
- `flag` context colours applied to main (128px) and small (24px) flags
- `map` context colours applied to map (256px) flags
- `ship` context colours available for ship customisation
- `use_as_border_color = yes` colours appear as border options

### Visual Rendering

**Main Flag (128px):**
- Gradient bevel applied — raised, embossed appearance
- Gold-tinted highlight/shadow gradient
- Used in: empire view, diplomacy, species view

**Map Flag (256px):**
- Flat rendering — no bevel
- Used in: galaxy map, system view
- Larger resolution for map zoom levels

**Small Flag (24px):**
- Gradient bevel applied
- Used in: fleet lists, UI icons, notifications
- Bevel adds definition at small size

### Random Empire Generation

- `randomizable_combo` entries used for random colour schemes
- Categories and flags available to AI empires
- Backgrounds randomly selected from available options

## Content Behaviour

### Category Discovery

**Behaviour:** Any directory under `source/flags/` is treated as a category.

**Implications:**
- Empty directories produce empty categories (no flags)
- Directories without localisation entries show raw key name (e.g., `FLAG_CATEGORY_newcat`)
- `usage.txt` files are copied but not parsed by the game

### Filename Resolution

**Behaviour:** Output names resolved via `names.txt`, defaulting to `ui_` prefix.

**Collision Risk:** Two source files mapping to the same output name overwrite each other. The build does not detect or warn about collisions.

**Example:**
```
names.txt:
  eagle=ui_domination_1
  hawk=ui_domination_1   # Collision! Second overwrites first
```

### Background Handling

**Behaviour:** the `svg-to-png` stage removes the flat background colour by taking the
difference from the sampled corner colour.

**Failure Mode:** Complex or gradient backgrounds are not removed — they appear in output.

**Assumption:** Source assets have emblem on solid or transparent background.

## Platform Distribution Behaviour

### Steam Workshop

**Update Trigger:** Git tag push (`v*.*.*`)

**Behaviour:**
- Downloads release asset from GitHub Releases
- Uploads to existing Workshop item (ID: 1914541325)
- Changelog includes GitHub release URL
- Previous version replaced

**Failure:** Workflow fails visibly in GitHub Actions; Workshop retains previous version.

### Nexus Mods

**Update Trigger:** Git tag push (`v*.*.*`)

**Behaviour:**
- Downloads release asset from GitHub Releases
- Uploads as new file version to mod (ID: 75)
- Previous versions retained as "old versions"

**Failure:** Workflow fails visibly; Nexus retains previous version.

### Paradox Mods

**Update:** Manual only — no automation.

### GitHub Releases

**Update:** Manual — maintainer creates release and uploads zip asset.

**Dependency:** Steam Workshop and Nexus Mods workflows **depend on** the GitHub Release existing. Tag push without a published release causes both workflows to fail.

## Edge Cases

### Empty Category Directory

**Behaviour:** Directory created in output, no flags. Category appears in game with no options.

### Source File Without Extension

**Behaviour:** `${FILE_NAME%.*}` yields the full name; treated as having empty extension; falls to unsupported format case; skipped.

### Duplicate Source Names Across Categories

**Behaviour:** Allowed — categories are separate namespaces. `human/eagle.svg` and `domination/eagle.svg` both produce `ui_eagle.dds` in their respective directories.

### Very Large SVG

**Behaviour:** Scaled to fit target size; no maximum dimension limit. Very complex SVGs may render or bevel slowly, or exhaust a GIMP session's memory.

### Corrupt Source File

**Behaviour:** The relevant conversion tool fails; the asset produces no output; the pipeline continues. The failure usually appears only in that asset's worker log under `build/`.

### Missing names.txt

**Behaviour:** `grep` fails silently; all assets use default `ui_` prefix naming.

### Missing localisation Entry

**Behaviour:** Category shows raw localisation key in game (e.g., `FLAG_CATEGORY_newcat`).

### Missing Thumbnail

**Behaviour:** the `cp` that stages `source/thumbnail.png` fails, and the build continues; the mod has no thumbnail. The descriptor carries no `picture` field, so the launcher falls back to its default icon.

## State Persistence

**Between Builds:**
- `build/` retains intermediates (SVG, PNG) — enables incremental builds
- `out/` retains outputs — enables incremental skip logic
- Neither is cleaned automatically

**Clean State:** `rm -rf build out` restores pristine state.

## Concurrency

**Behaviour:** Not supported. Concurrent builds on the same working copy will corrupt outputs (shared `build/` and `out/` directories, no locking).

**Recommendation:** One build at a time per working copy.

## Determinism

**Deterministic:** Filename resolution, directory structure, descriptor content (given same version argument).

**Non-Deterministic:**
- File iteration order (filesystem-dependent, affects nothing observable)
- DDS compression artefacts (tool version-dependent)
- Bevel rendering (GIMP version-dependent)

**Implication:** Rebuilding with different tool versions may produce slightly different DDS output. Content is visually equivalent but not byte-identical.