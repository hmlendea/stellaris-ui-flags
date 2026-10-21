# Stellaris UI Flags Architecture

This document describes the current architecture of the Stellaris UI Flags mod repository. The repository contains source assets and a build pipeline that produces a Stellaris-compatible mod package.

## 📑 Table of Contents

- [Purpose](#-purpose)
- [System Context](#-system-context)
- [Architectural Style](#-architectural-style)
- [Runtime Flow](#-runtime-flow)
- [Architectural Areas](#-architectural-areas)
- [Data Architecture](#-data-architecture)
- [Interfaces and Integrations](#-interfaces-and-integrations)
- [Dependency Direction and Rules](#-dependency-direction-and-rules)
- [External Dependencies](#-external-dependencies)
- [Deployment and Operations](#-deployment-and-operations)
- [Compatibility Contracts](#-compatibility-contracts)
- [Testing and Verification](#-testing-and-verification)
- [Design Constraints](#-design-constraints)
- [Extension Points](#-extension-points)
- [Source Map](#-source-map)
- [Related Documentation](#-related-documentation)

## 🎯 Purpose

The repository provides a mod for Stellaris that adds hundreds of new flag designs matching the vanilla flag style. The architecture encompasses the source asset organisation, the build pipeline that converts source images to the DDS format required by Stellaris, and the packaging process that produces a distributable mod directory and descriptor files.

Audience: mod maintainers, contributors adding new flag assets, and users building the mod locally.

## 🌐 System Context

The system boundary is the repository and its build script. External actors and systems:

```mermaid
flowchart LR
    Contributor[Contributor] -->|Adds source assets| Repo[(Repository)]
    Maintainer[Maintainer] -->|Runs build.sh| Build[Build Pipeline]
    Build -->|Produces| ModPackage[Mod Package]
    ModPackage -->|Installed by| Steam[Steam Workshop]
    ModPackage -->|Installed by| Paradox[Paradox Mods]
    ModPackage -->|Installed by| Nexus[Nexus Mods]
    ModPackage -->|Loaded by| Stellaris[Stellaris Game]
    Tools[ImageMagick, Inkscape, GIMP, potrace] -->|Required by| Build
```

The principal external boundaries are:
- **Source Assets:** Contributor-provided flag designs in various formats (BMP, XCF, PNG, AI, SVG) organised by category directories under `source/flags/`.
- **Build Tools:** ImageMagick (`convert`), Inkscape, GIMP (with DDS plug-in), and potrace must be present on the build machine.
- **Distribution Platforms:** Steam Workshop, Paradox Mods, Nexus Mods consume the built mod package.
- **Stellaris Game:** Loads the mod package at runtime; expects DDS flag textures and localisation/colour definitions.

## 🏗️ Architectural Style

The repository follows a **pipeline-oriented asset processing architecture**:

- **Source-first organisation:** Assets are authored and stored in lossless or editable formats, grouped by thematic category.
- **Declarative build script:** `build.sh` encodes the complete conversion pipeline as a sequence of format transformations, driven by file discovery.
- **Immutable outputs:** The build writes to `build/` (intermediate) and `out/` (final) directories; source assets are never modified.
- **Category isolation:** Each flag category is processed independently, enabling parallelism and incremental builds.

```mermaid
flowchart TB
    subgraph Source[Source Assets]
        Flags[source/flags/*/]
        Backgrounds[source/backgrounds/]
        Colours[source/colours.txt]
        Localisation[source/localisation.yml]
        Names[source/names.txt]
        Thumbnail[source/thumbnail.png]
    end

    subgraph Pipeline[Build Pipeline]
        Discover[Discover Categories & Files]
        Convert[Format Conversion]
        Bevel[Gradient Bevel]
        DDS[DDS Export]
        Package[Package Mod]
    end

    subgraph Output[Build Output]
        BuildDir[build/*/]
        OutDir[out/ui-flags/]
        Descriptor[*.mod files]
    end

    Source --> Discover
    Discover --> Convert
    Convert --> Bevel
    Bevel --> DDS
    DDS --> Package
    Package --> BuildDir
    Package --> OutDir
    Package --> Descriptor
```

The principal architecture boundaries are:
- **Source Area:** `source/` — authoring formats, category taxonomy, localisation, colour palette, naming map.
- **Build Pipeline:** `build.sh` + `source/scripts/` — conversion logic, tool orchestration, output layout.
- **Output Area:** `out/` — distributable mod package conforming to Stellaris mod structure.

## 🔄 Runtime Flow

```mermaid
flowchart TD
    Start([build.sh invoked with version]) --> Validate[Validate tools & source dir]
    Validate --> Prepare[Create output directories]
    Prepare --> CopyStatic[Copy backgrounds, colours, localisation, thumbnail]
    Prepare --> GenDescriptor[Generate .mod descriptor files]
    CopyStatic --> LoopCategories[For each category in source/flags/]
    GenDescriptor --> LoopCategories
    LoopCategories --> LoopFiles[For each asset file in category]
    LoopFiles --> SkipUsage[Skip usage.txt]
    SkipUsage --> ResolveName[Resolve output filename via names.txt]
    ResolveName --> ConvertToSVG[Convert source to SVG]
    ConvertToSVG --> RenderMain[Render 128px PNG]
    RenderMain --> ApplyBevelMain[Apply gradient bevel]
    ApplyBevelMain --> ExportMain[Export main DDS]
    ConvertToSVG --> RenderMap[Render 256px PNG]
    RenderMap --> ExportMap[Export map DDS]
    ConvertToSVG --> RenderSmall[Render 24px PNG]
    RenderSmall --> ApplyBevelSmall[Apply gradient bevel]
    ApplyBevelSmall --> ExportSmall[Export small DDS]
    ExportMain --> NextFile
    ExportMap --> NextFile
    ExportSmall --> NextFile
    NextFile --> MoreFiles{More files?}
    MoreFiles -->|Yes| LoopFiles
    MoreFiles -->|No| MoreCategories{More categories?}
    MoreCategories -->|Yes| LoopCategories
    MoreCategories -->|No| Complete([Mod package ready in out/])
```

The principal runtime sequence is:
1. **Initialisation:** Validate required tools (ImageMagick, Inkscape, GIMP, potrace), verify source directory exists, parse version argument.
2. **Static asset staging:** Copy backgrounds, colours.txt, localisation.yml, thumbnail.png to output layout; generate primary and secondary `.mod` descriptor files.
3. **Category iteration:** For each subdirectory under `source/flags/`, create build and output subdirectories (main, map, small).
4. **Asset conversion:** For each asset file, resolve final filename via `names.txt`, convert source format to SVG, then render three PNG sizes (128px main, 256px map, 24px small), apply gradient bevel to main and small, export all three to DDS.
5. **Completion:** Mod package resides in `out/ui-flags/` with descriptor files in `out/`.

## 🗂️ Architectural Areas

### Source Assets

Paths:
- `source/flags/` — category directories, each containing flag source files and optional `usage.txt`.
- `source/backgrounds/` — background textures copied verbatim to output.
- `source/colours.txt` — colour palette definitions copied to `flags/colors.txt` in output.
- `source/localisation.yml` — English localisation copied to `localisation/ui-flags_l_english.yml`.
- `source/names.txt` — mapping from source filename (without extension) to output filename.
- `source/thumbnail.png` — mod thumbnail copied to output root.
- `source/scripts/` — GIMP Script-fu scripts for DDS export, SVG→PNG, XCF→PNG, gradient bevel.

Responsibilities:
- Provide authoring formats and taxonomic organisation for flag designs.
- Define naming overrides, colour palette, and localisation strings.
- Supply reusable background textures and build-time scripts.

Boundary rules:
- Source files are never modified by the build.
- Category directories define the output category structure.
- `names.txt` is the single source of truth for output filenames.

### Build Pipeline

Paths:
- `build.sh` — top-level orchestration, tool detection, directory management, conversion loop.
- `source/scripts/*.lisp` — GIMP Script-fu implementations for format conversions and effects.

Responsibilities:
- Detect and validate external tool dependencies.
- Manage intermediate (`build/`) and final (`out/`) directory trees.
- Execute conversion pipeline per asset: source → SVG → PNG (multiple sizes) → DDS.
- Apply gradient bevel effect to main and small variants.
- Generate Stellaris mod descriptor files.

Boundary rules:
- All file paths are derived from repository root; no hardcoded absolute paths.
- Tool binaries are resolved via standard locations and Flatpak exports.
- Intermediate build artefacts are retained for incremental builds.

### Output Package

Paths:
- `out/ui-flags/` — root of distributable mod package.
- `out/ui-flags/flags/` — category subdirectories with `map/`, `small/`, and main DDS files.
- `out/ui-flags/flags/backgrounds/` — copied background textures.
- `out/ui-flags/flags/colors.txt` — copied colour palette.
- `out/ui-flags/localisation/ui-flags_l_english.yml` — copied localisation.
- `out/ui-flags/thumbnail.png` — copied thumbnail.
- `out/ui-flags.mod` and `out/ui-flags/descriptor.mod` — mod descriptors.

Responsibilities:
- Conform to Stellaris mod directory layout and descriptor format.
- Provide DDS textures at required resolutions (128px, 256px, 24px).
- Include all metadata required by distribution platforms.

Boundary rules:
- Output structure is fixed by Stellaris mod specification.
- Descriptor files must contain correct version, name, path, tags, and supported_version.

## 💾 Data Architecture

```mermaid
flowchart LR
    SourceFormats[Source Formats\nBMP, XCF, PNG, AI, SVG] --> SVG[SVG Intermediate]
    SVG --> PNG128[PNG 128px]
    SVG --> PNG256[PNG 256px]
    SVG --> PNG24[PNG 24px]
    PNG128 --> Bevel128[Gradient Bevel]
    PNG24 --> Bevel24[Gradient Bevel]
    Bevel128 --> DDSMain[DDS Main]
    PNG256 --> DDSMap[DDS Map]
    Bevel24 --> DDSSmall[DDS Small]
    Names[names.txt] --> Filename[Output Filename]
    Colours[colours.txt] --> OutputColours[flags/colors.txt]
    Localisation[localisation.yml] --> OutputLoc[localisation/*.yml]
    Backgrounds[backgrounds/] --> OutputBG[flags/backgrounds/]
```

| Data or Store | Owner | Representation and Storage | Lifecycle or Consistency |
|---------------|-------|----------------------------|--------------------------|
| `source/flags/*/*.{bmp,xcf,png,ai,svg}` | Contributor | Lossless/editable raster or vector files | Authored once; immutable during build |
| `source/names.txt` | Maintainer | `source_name=output_name` lines | Updated when new flags added; build reads only |
| `source/colours.txt` | Maintainer | Stellaris colour definitions | Copied verbatim to output |
| `source/localisation.yml` | Maintainer | YAML localisation keys/values | Copied verbatim to output |
| `source/backgrounds/*.dds` | Contributor | DDS textures | Copied verbatim to output |
| `build/*/` | Build Pipeline | Intermediate SVG, PNG, BMP | Ephemeral; recreated each build |
| `out/ui-flags/flags/*/*.dds` | Build Pipeline | DDS (BC1/BC3, mipmaps via GIMP) | Final artefacts; shipped to platforms |
| `out/ui-flags/*.mod` | Build Pipeline | Text descriptor | Regenerated each build with version |

## 🔌 Interfaces and Integrations

| Interface or Integration | Direction | Contract | Owner | Failure Semantics |
|--------------------------|-----------|----------|-------|-------------------|
| `build.sh` CLI | Inbound | `build.sh <version>` | Build Pipeline | Exits non-zero with error message if version missing or tools absent |
| ImageMagick `convert` | Outbound | BMP→PNG flattening | Build Pipeline | Build fails if binary missing or conversion fails |
| Inkscape CLI | Outbound | AI→SVG, SVG→PNG (fallback) | Build Pipeline | Build fails if binary missing or conversion fails |
| GIMP Script-fu | Outbound | XCF→PNG, SVG→PNG, PNG→DDS, gradient bevel | Build Pipeline | Build fails if GIMP or DDS plug-in missing |
| potrace CLI | Outbound | BMP→SVG vectorisation | Build Pipeline | Build fails if binary missing or tracing fails |
| Stellaris Mod Descriptor | Outbound | `.mod` file format (version, name, path, tags, supported_version) | Build Pipeline | Mod not recognised by launcher if malformed |
| Steam Workshop / Paradox Mods / Nexus Mods | Outbound | Zip of `out/ui-flags/` + descriptor | Maintainer | Platform rejects upload if structure invalid |

## 🧭 Dependency Direction and Rules

```mermaid
flowchart TD
    Build[build.sh] --> Scripts[source/scripts/*.lisp]
    Build --> Tools[External Tools]
    Source[source/] --> Build
    Build --> Output[out/]
    Output --> Platforms[Distribution Platforms]
    Output --> Stellaris[Stellaris Game]
```

The principal dependency rules are:
- Build pipeline depends only on source assets and external tools; no runtime dependencies.
- Source assets have no dependencies on build outputs.
- Output package has no dependencies on build tools at runtime.
- Category directories are independent; no cross-category references.
- `names.txt` is a build-time dependency for filename resolution; not shipped.

## 📦 External Dependencies

| Dependency | Responsibility | Integration Boundary | Architectural Consequence |
|------------|----------------|----------------------|---------------------------|
| ImageMagick (`convert`) | Raster flattening (PNG→BMP) | CLI invoked by `build.sh` | Must be in PATH; version not pinned |
| Inkscape | Vector conversion (AI→SVG, SVG→PNG fallback) | CLI invoked by `build.sh` | Flatpak and system paths probed; version not pinned |
| GIMP + DDS plug-in | XCF→PNG, SVG→PNG, PNG→DDS, gradient bevel | Script-fu via `source/scripts/` | Requires GIMP 2.10+ with DDS plug-in; Flatpak and system paths probed |
| potrace | BMP→SVG vectorisation | CLI invoked by `build.sh` | Must be in PATH; version not pinned |
| Stellaris v4.0.* | Target game version | `supported_version` in descriptor | Mod compatibility bound to game version range |

## 🚀 Deployment and Operations

| Concern | Current Design | Architectural Consequence |
|---------|----------------|---------------------------|
| Build invocation | Manual: `./build.sh <version>` | Version argument required; no CI/CD pipeline in repository |
| Output artefact | Directory tree `out/ui-flags/` + `out/ui-flags.mod` | Maintainer zips and uploads to platforms |
| Persistent state | None (build is stateless) | Incremental builds reuse `build/` intermediates |
| Scaling | Single-threaded category loop | Large flag counts increase build time linearly |
| Recovery | Re-run `build.sh` with same version | Idempotent: existing output files skipped if present |
| Operator responsibility | Provide version, ensure tools installed, upload artefacts | No automated publishing |

## 🛡️ Compatibility Contracts

| Contract | Owner | Invariant | Verification | Change Policy |
|----------|-------|-----------|--------------|---------------|
| Stellaris mod descriptor format | Build Pipeline | `version`, `name`, `path`, `tags`, `supported_version` fields present | Launcher loads mod without error | Update `STELLARIS_VERSION` in `build.sh` when game updates |
| DDS texture format (BC1/BC3, mipmaps) | GIMP DDS plug-in | Stellaris reads flag textures without error | Visual verification in-game | Regenerate if GIMP plug-in changes output format |
| Flag filename mapping (`names.txt`) | Maintainer | Each source file maps to unique output filename | Build logs show no collisions | Add entries for new flags; never remove existing |
| Category directory structure | Maintainer | Output categories mirror source categories | `out/ui-flags/flags/` matches `source/flags/` | New categories added as directories under `source/flags/` |
| Localisation key format | Maintainer | Keys follow `flag_<category>_<name>` pattern | In-game text displays correctly | Follow existing key pattern for new flags |

## ✅ Testing and Verification

No automated test suite exists. Verification is manual:

- **Build verification:** Run `./build.sh <version>` and confirm `out/ui-flags/` contains expected category directories, DDS files, descriptor files, and no error output.
- **In-game verification:** Install built mod, launch Stellaris, verify new flags appear in empire creation and flag selector, confirm localisation text renders correctly.
- **Platform verification:** Upload to Steam Workshop / Paradox Mods / Nexus Mods and confirm platform accepts package.

Execute the principal automated verification with:

```bash
./build.sh 1.0.0-test
```

## ⚠️ Design Constraints

- **Tool availability:** Build requires four external CLI/GUI tools (ImageMagick, Inkscape, GIMP, potrace) with specific capabilities (DDS plug-in for GIMP). Absence of any tool halts the build.
- **Single-threaded execution:** Category and file loops run sequentially; no parallelism exploited.
- **Intermediate retention:** `build/` directory grows with each build; no automatic cleanup.
- **Version coupling:** `STELLARIS_VERSION` in `build.sh` must be updated manually when Stellaris releases a new major version.
- **Format coverage:** Only BMP, XCF, PNG, AI, SVG source formats are supported; other formats require new conversion functions.
- **No CI/CD:** Repository lacks GitHub Actions or other automation for build validation or release packaging.

## 🔧 Extension Points

### New Flag Category

1. Create directory under `source/flags/<category>/`.
2. Add source flag files (BMP, XCF, PNG, AI, SVG) to the directory.
3. Add entries to `source/names.txt` mapping source filenames to desired output filenames.
4. Optionally add `usage.txt` for attribution.
5. Run build; category appears automatically in output.

### New Source Format

1. Add conversion function to `build.sh` (e.g., `webp-to-svg`).
2. Extend the `if/elif` chain in the asset loop to invoke the new function.
3. Ensure required CLI tool is detected in validation section.

### New Output Resolution

1. Add render step in asset loop (e.g., `svg-to-png` at new size).
2. Add output subdirectory creation (e.g., `large/`).
3. Add DDS export for new resolution.
4. Verify Stellaris consumes the new variant.

## 🗺️ Source Map

| Area | Path |
|------|------|
| Build orchestration | `build.sh` |
| GIMP Script-fu scripts | `source/scripts/` |
| Flag source assets | `source/flags/` |
| Background textures | `source/backgrounds/` |
| Colour palette | `source/colours.txt` |
| Localisation | `source/localisation.yml` |
| Filename mapping | `source/names.txt` |
| Mod thumbnail | `source/thumbnail.png` |
| Build intermediates | `build/` |
| Distribution package | `out/` |

## 📚 Related Documentation

- [README.md](./README.md) — project overview, installation, links to distribution platforms.
- [CONTRIBUTING.md](./CONTRIBUTING.md) — contribution guidelines, development setup, PR process.
- [SECURITY.md](./SECURITY.md) — security vulnerability reporting policy.
- [PRIVACY.md](./PRIVACY.md) — data handling statement.
- [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md) — community conduct standards.
- [LICENSE](./LICENSE) — GNU GPL v3.0 license text.