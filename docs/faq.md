# FAQ

## General

### What is this mod?

**Universum Infinitum: Flags** is a Stellaris graphics mod that adds 300+ flag designs across 25+ categories, 40+ background textures, and 30+ colours for empire customisation.

### Where can I get it?

- **Steam Workshop:** Item 1914541325
- **Nexus Mods:** Mod 75 (game: stellaris)
- **Paradox Mods:** Manual upload
- **GitHub Releases:** Versioned zip archives

### Is it compatible with my game version?

The descriptor declares `supported_version="v4.5.*"`. Check the release notes for your game version. Update `STELLARIS_VERSION` in `build.sh` and rebuild for other versions.

### Does it affect gameplay?

No. It is a pure graphics mod — only flag assets, colours, and localisation. No scripts, events, or mechanics are modified.

### Is it achievement-compatible?

Yes. Graphics mods do not disable achievements in Stellaris.

### What licence applies?

GNU GPL v3.0 — see [LICENSE](../LICENSE).

## Building

### Why does the build take so long?

Each asset requires 8 GIMP invocations (3 renders, 2 bevels, 3 DDS exports), each with ~0.5–1s startup overhead. 300+ assets × 8 calls = 5–15 minutes total.

### Can I speed up the build?

- Use incremental builds (only new assets processed)
- Use SVG sources (shortest conversion path)
- Ensure `build/` and `out/` are on local disk

### Why did my modified flag not rebuild?

Incremental builds skip assets when all three output DDS files exist — source modifications are not detected. Remove the specific outputs or do a full rebuild (`rm -rf build out`).

### Do I need all four tools?

Yes — ImageMagick, potrace, Inkscape, and GIMP are all validated at startup. Even if your sources are all SVG (Inkscape only used for AI), the build aborts if any tool is missing.

### Does Flatpak GIMP work?

Yes, the build script auto-detects Flatpak exports. **Caveat:** the DDS plug-in may not be included in the Flatpak package — install it into the Flatpak GIMP's plug-ins directory manually.

### Can I build on Windows?

Not directly — `build.sh` is a bash script. Options:
- **WSL (Windows Subsystem for Linux):** Install tools in WSL, run build there
- **Git Bash:** May work if tools are in PATH, but untested

### Can I build on macOS?

Theoretically yes (bash script, tools available via Homebrew), but untested. Tool detection paths are Linux-specific — system PATH detection works, Flatpak paths won't.

## Content

### What source formats are supported?

| Format | Conversion Path |
|--------|-----------------|
| `.svg` | Direct (best quality) |
| `.ai` | Inkscape → SVG |
| `.bmp` | potrace → SVG |
| `.png` | ImageMagick → BMP → potrace → SVG |
| `.xcf` | GIMP → PNG → BMP → potrace → SVG |

**SVG is strongly recommended** — other formats pass through lossy raster→vector tracing.

### Why does my PNG flag look different after conversion?

potrace traces raster images to vector paths. Anti-aliasing, gradients, and fine detail are lost or distorted. Use SVG sources for faithful reproduction.

### How do I add a new flag?

1. Place source in `source/flags/<category>/`
2. Optional: add name mapping to `source/names.txt`
3. Run `./build.sh <version>`

See [Quick Start](quick-start.md#add-a-new-flag).

### How do I add a new category?

1. `mkdir source/flags/my-category`
2. Add localisation: `FLAG_CATEGORY_my-category:0 "My Category"` in `source/localisation.yml`
3. Add flag assets
4. Rebuild

### Why does my category show "FLAG_CATEGORY_xxx" in game?

Missing localisation entry. The key must match the directory name exactly.

### Can I rename an output file without renaming the source?

Yes — add a mapping to `source/names.txt`:
```txt
source-name=my-output-name
```

### Why do map flags look flat while main flags look beveled?

By design. Main (128px) and small (24px) flags get a gradient bevel for a 3D embossed look; map (256px) flags render flat for map readability.

### Can I change the bevel appearance?

Yes — edit `source/scripts/gradient-bevel.lisp` (bevel-size, bevel-height, colours). Full rebuild required. Changes affect **all** flags.

### How do I add a colour?

Add an entry to `source/colours.txt` with `flag`, `map`, and `ship` HSV values. See [Configuration](configuration.md#colour-palette-configuration).

### What are the three colour contexts?

| Context | Applied To |
|---------|------------|
| `flag` | Main (128px) and small (24px) flags |
| `map` | Galaxy map flags (256px) |
| `ship` | Ship hull customisation |

## Distribution

### How do I release a new version?

1. `./build.sh <version>`
2. `cd out && zip -r ../ui-flags_<version>.zip ui-flags/`
3. Create GitHub Release with tag `v<version>`, upload zip
4. Tag push triggers Steam Workshop and Nexus Mods workflows
5. Manually upload to Paradox Mods

See [Build and Deployment](build-and-deployment.md#release-process).

### Why did the Steam Workshop workflow fail?

Most common: GitHub Release asset missing. The workflows download the release zip — create the release (with asset) before or immediately after pushing the tag.

### How do I roll back a release?

- GitHub: delete release and tag
- Steam Workshop: revert via Workshop interface
- Nexus Mods: hide/remove file via site
- Then release a fixed patch version

## Troubleshooting

### The build says a tool is missing but it's installed

The detection checks system PATH and two Flatpak export paths. If your tool is elsewhere (Snap, custom location), it won't be found. Install via detected methods or adjust the detection logic in `build.sh`.

### My flag is invisible in game

Alpha channel lost during processing. Check intermediate PNGs in `build/<category>/` — the source SVG likely has an opaque background that wasn't removed.

### DDS files won't open

GIMP DDS plug-in missing or wrong format. Verify with `gimp <file>.dds` locally.

More: [Troubleshooting](troubleshooting.md).

## Contributing

### How do I contribute a flag design?

See [CONTRIBUTING.md](../CONTRIBUTING.md). In short: SVG preferred, place in appropriate category, submit PR.

### Can I contribute a new category?

Yes — follow the category creation steps and include localisation.

### Are there content restrictions?

Franchise-referencing categories (`ui_starwars`, `ui_marvel`, etc.) exist for personal use. Consider intellectual property implications before redistribution.