# Build and Deployment

## Build Pipeline

### Overview

The build pipeline is a single shell script (`build.sh`) that orchestrates the complete conversion of source assets to a Stellaris-compatible mod package. It is a **declarative pipeline** where the sequence of transformations is encoded directly in the script.

### Pipeline Stages

```
┌─────────────────────────────────────────────────────────────────┐
│                        BUILD PIPELINE                           │
├─────────────────────────────────────────────────────────────────┤
│  1. INITIALISATION                                              │
│     ├── Validate version argument                               │
│     ├── Verify source directory exists                          │
│     └── Validate required tools (convert, potrace, inkscape,    │
│         gimp)                                                   │
├─────────────────────────────────────────────────────────────────┤
│  2. STATIC ASSET STAGING                                        │
│     ├── Create output directories                               │
│     ├── Copy backgrounds → out/ui-flags/flags/backgrounds/      │
│     ├── Copy colours.txt → out/ui-flags/flags/colors.txt        │
│     ├── Copy localisation.yml → out/ui-flags/localisation/      │
│     ├── Copy thumbnail.png → out/ui-flags/thumbnail.png         │
│     └── Generate .mod descriptor files                          │
├─────────────────────────────────────────────────────────────────┤
│  3. CATEGORY ITERATION                                          │
│     └── For each directory in source/flags/:                    │
│         ├── Create build/<category>/map/ and /small/            │
│         ├── Create out/ui-flags/flags/<category>/map/ and       │
│         │   /small/                                             │
│         ├── Copy usage.txt if present                           │
│         └── Process each asset file                             │
├─────────────────────────────────────────────────────────────────┤
│  4. ASSET CONVERSION (per file)                                 │
│     ├── Resolve output filename via names.txt                   │
│     ├── Convert source format → SVG                             │
│     │   ├── BMP → potrace → SVG                                 │
│     │   ├── PNG → BMP → potrace → SVG                           │
│     │   ├── XCF → PNG → BMP → potrace → SVG                     │
│     │   ├── AI → Inkscape → SVG                                 │
│     │   └── SVG → copy                                          │
│     ├── Render SVG → 128px PNG (main)                           │
│     ├── Apply gradient bevel to main PNG                        │
│     ├── Export main PNG → DDS                                   │
│     ├── Render SVG → 256px PNG (map)                            │
│     ├── Export map PNG → DDS (no bevel)                         │
│     ├── Render SVG → 24px PNG (small)                           │
│     ├── Apply gradient bevel to small PNG                       │
│     └── Export small PNG → DDS                                  │
├─────────────────────────────────────────────────────────────────┤
│  5. COMPLETION                                                  │
│     └── Mod package ready in out/ui-flags/                      │
└─────────────────────────────────────────────────────────────────┘
```

### Tool Detection

The build script detects tools in this priority order:

| Tool | Primary Path | Flatpak (system) | Flatpak (user) |
|------|--------------|------------------|----------------|
| Inkscape | `/usr/bin/inkscape` | `/var/lib/flatpak/exports/bin/org.inkscape.Inkscape` | `~/.local/share/flatpak/exports/bin/org.inkscape.Inkscape` |
| GIMP | `/usr/bin/gimp` | `/var/lib/flatpak/exports/bin/org.gimp.GIMP` | `~/.local/share/flatpak/exports/bin/org.gimp.GIMP` |
| ImageMagick | `/usr/bin/convert` | N/A | N/A |
| potrace | `/usr/bin/potrace` | N/A | N/A |

### Incremental Builds

The pipeline supports incremental builds by checking output existence:

```bash
if [ -f "${FLAG_OUTPUT_MAIN_FILE_PATH}" ] && \
   [ -f "${FLAG_OUTPUT_MAP_FILE_PATH}" ] && \
   [ -f "${FLAG_OUTPUT_SMALL_FILE_PATH}" ]; then
    continue  # Skip already-processed asset
fi
```

This allows re-running the build after adding new assets without reprocessing existing ones.

## Build Configuration

### Required Arguments

```bash
./build.sh <version>
```

- `version`: Semantic version string (e.g., `1.0.0`, `2.3.1`)

### Environment Variables

No environment variables are required. All configuration is via:
- Script constants (`MOD_ID`, `MOD_NAME`, `STELLARIS_VERSION`)
- Source files (`colours.txt`, `localisation.yml`, `names.txt`)
- Command-line argument (version)

### Modifiable Constants (in `build.sh`)

| Constant | Default | Purpose |
|----------|---------|---------|
| `MOD_ID` | `ui-flags` | Mod directory name and descriptor ID |
| `MOD_NAME` | `Universum Infinitum: Flags` | Display name in Stellaris launcher |
| `STELLARIS_VERSION` | `v4.5.*` | Supported game version in descriptor |

## Deployment

### Local Build Output

After successful build:

```
out/
├── ui-flags/                 # Distributable mod package
│   ├── descriptor.mod        # Secondary descriptor (for mod directory)
│   ├── flags/
│   │   ├── backgrounds/      # Background textures
│   │   ├── colors.txt        # Colour palette
│   │   └── <category>/       # Per-category flag DDS files
│   │       ├── map/          # 256px DDS
│   │       ├── small/        # 24px DDS
│   │       └── *.dds         # 128px main DDS
│   ├── localisation/
│   │   └── ui-flags_l_english.yml
│   └── thumbnail.png
└── ui-flags.mod              # Primary descriptor (for mod root)
```

### Distribution Package Creation

For distribution platforms, the `out/ui-flags/` directory is typically zipped:

```bash
cd out
zip -r ui-flags_<version>.zip ui-flags/
```

### GitHub Releases

Release assets are uploaded manually or via CI to GitHub Releases with naming convention:
- `ui-flags_<version>.zip` (e.g., `ui-flags_1.0.0.zip`)

### Steam Workshop Deployment

**Workflow:** `.github/workflows/steam-workshop.yml`

**Trigger:** Push tag matching `v*.*.*`

**Process:**
1. Checkout repository
2. Download release asset from GitHub Releases
3. Unzip to `release/`
4. Upload `release/ui-flags/` to Steam Workshop using `hmlendea/steam-workshop-update` action
5. Changelog note includes link to GitHub release

**Secrets Required:**
- `STEAM_USERNAME`
- `STEAM_PASSWORD`
- `STEAM_2FASEED`

**Configuration:**
- App ID: `281990` (Stellaris)
- Item ID: `1914541325`

### Nexus Mods Deployment

**Workflow:** `.github/workflows/nexus-mods.yml`

**Trigger:** Push tag matching `v*.*.*`

**Process:**
1. Checkout repository
2. Download release asset from GitHub Releases
3. Upload `release.zip` to Nexus Mods using `hmlendea/nexusmods-update` action

**Secrets Required:**
- `NEXUS_UPLOADER_USERNAME`
- `NEXUS_UPLOADER_PASSWORD`

**Configuration:**
- Game ID: `stellaris`
- Mod ID: `75`

### Paradox Mods Deployment

**Process:** Manual upload via Paradox Mods web interface

**Artifact:** `ui-flags_<version>.zip` from GitHub Releases

**No automated workflow currently exists.**

## Environments

### Local Development

**Requirements:**
- Linux/macOS/WSL (build.sh is a bash script)
- All build tools installed (ImageMagick, Inkscape, GIMP 2.10+, potrace)
- GIMP DDS plug-in installed
- Sufficient disk space for intermediate artefacts

**Typical Workflow:**
```bash
# Clone repository
git clone https://github.com/hmlendea/stellaris-ui-flags.git
cd stellaris-ui-flags

# Add/modify source assets in source/flags/

# Build mod
./build.sh 1.0.0-dev

# Test by copying out/ui-flags/ to Stellaris mod directory
# Enable in Stellaris launcher
```

### GitHub Actions (CI/CD)

**Runner:** `ubuntu-latest`

**Pre-installed Tools:** The workflows assume tools are available. The `hmlendea/steam-workshop-update` and `hmlendea/nexusmods-update` actions handle their own dependencies.

**Workflow Execution:**
1. Triggered on version tag push (`v*.*.*`)
2. Downloads release asset from GitHub Releases
3. Uploads to respective platform

**Limitations:**
- No build step in CI (build is done locally by maintainer)
- Release asset must be pre-uploaded to GitHub Releases
- No automated testing in CI

## Release Process

### Standard Release

1. **Prepare release:**
   ```bash
   # Ensure all changes committed
   git status
   
   # Build final version
   ./build.sh 1.2.3
   
   # Verify output
   ls -la out/ui-flags/
   ```

2. **Create release archive:**
   ```bash
   cd out
   zip -r ../ui-flags_1.2.3.zip ui-flags/
   cd ..
   ```

3. **Create GitHub Release:**
   - Go to GitHub Releases
   - Click "Create a new release"
   - Tag: `v1.2.3`
   - Title: `Version 1.2.3`
   - Upload `ui-flags_1.2.3.zip`
   - Publish release

4. **Automated deployment:**
   - GitHub Actions workflows trigger on tag push
   - Steam Workshop and Nexus Mods updated automatically
   - Paradox Mods updated manually

### Versioning Scheme

Semantic versioning: `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes to mod structure or compatibility
- **MINOR**: New flag categories, significant asset additions
- **PATCH**: Bug fixes, minor asset corrections, typo fixes

### Rollback Procedure

If a release has issues:

1. **GitHub Releases:** Delete the release and tag
2. **Steam Workshop:** Use Steam Workshop interface to revert to previous version
3. **Nexus Mods:** Use Nexus Mods interface to hide/remove problematic file
4. **Paradox Mods:** Use Paradox Mods interface to update with fixed version

## Troubleshooting Build Issues

### Common Failures

| Error | Cause | Resolution |
|-------|-------|------------|
| `MISSING SOURCE DIRECTORY` | `source/` not found | Run from repository root |
| `ImageMagick is not installed` | `convert` not in PATH | Install ImageMagick |
| `potrace is not installed` | `potrace` not in PATH | Install potrace |
| `Inkscape is not installed` | Inkscape not found | Install Inkscape or ensure Flatpak export |
| `GIMP is not installed` | GIMP not found | Install GIMP 2.10+ with DDS plug-in |
| `Failure while converting` | Tool execution failed | Check tool versions, input file validity |

### Debugging Tips

1. **Run with verbose output:** Add `set -x` at top of `build.sh` temporarily
2. **Check intermediate files:** Inspect `build/<category>/` for PNG/SVG intermediates
3. **Test individual conversions:** Call conversion functions manually
4. **Verify DDS output:** Open with GIMP to confirm format and mipmaps

### Performance Considerations

- **Sequential processing:** Assets processed one at a time (no parallelism)
- **Incremental builds:** Skip existing outputs — significant speedup on re-runs
- **Tool startup overhead:** GIMP/Inkscape invoked per asset — dominant cost
- **Typical build time:** 5-15 minutes for full rebuild depending on asset count