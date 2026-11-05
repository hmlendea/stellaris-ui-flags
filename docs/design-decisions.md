# Design Decisions

## Overview

This document records the key design decisions in the project, their rationale, and their consequences. Understanding these prevents accidental regression during future changes.

## D1: Single Bash Build Script

**Decision:** All build logic lives in one `build.sh` script.

**Rationale:**
- Simple to understand, modify, and debug
- No build framework dependency (Make, CMake, etc.)
- Matches the scale of the project (asset pipeline, not compiled code)
- Portable across Linux systems with bash

**Consequences:**
- ✅ Zero build-system dependencies
- ✅ Entire pipeline visible in one file
- ⚠️ Script grows large as features are added
- ⚠️ No parallelism built in (sequential processing)

**Alternatives Considered:**
- Make: rejected — overkill, poor fit for file transformation pipelines
- Python: rejected — adds runtime dependency, no benefit at this scale

---

## D2: SVG as Canonical Intermediate Format

**Decision:** All source formats convert to SVG before rendering to PNG.

**Rationale:**
- Single rendering path for all sources (SVG → PNG at 3 sizes)
- Vector format scales cleanly to 128px, 256px, 24px
- One set of rendering logic to maintain
- GIMP SVG import handles the rasterisation

**Consequences:**
- ✅ Uniform pipeline regardless of source format
- ✅ Best possible quality at all three resolutions
- ⚠️ Raster sources (PNG/BMP/XCF) pass through lossy potrace tracing
- ⚠️ Extra conversion steps for raster sources

**Alternatives Considered:**
- Direct PNG → DDS per resolution: rejected — no unified scaling, quality varies by source resolution

---

## D3: Three Fixed Output Resolutions

**Decision:** Every flag produces exactly three DDS variants: 128px (main), 256px (map), 24px (small).

**Rationale:**
- Matches Stellaris's flag display contexts
- Game expects all three; missing variants cause display failures
- Fixed set keeps output predictable

**Consequences:**
- ✅ Complete game compatibility
- ✅ Predictable output structure
- ⚠️ No flexibility for additional contexts without build changes

---

## D4: Bevel on Main and Small, Not Map

**Decision:** Gradient bevel applied to 128px and 24px flags; 256px map flags render flat.

**Rationale:**
- Main/small flags benefit from 3D embossed look in UI
- Map flags need flat clarity at map zoom levels — bevel adds visual noise
- Small flags gain definition from bevel at tiny size

**Consequences:**
- ✅ Polished UI appearance where it matters
- ✅ Clean map rendering
- ⚠️ Inconsistent processing between variants (by design)

---

## D5: GIMP Script-fu for Image Processing

**Decision:** Use GIMP batch mode with Script-fu (Scheme) scripts for SVG rendering, bevel, and DDS export.

**Rationale:**
- GIMP provides all needed operations in one tool: SVG import, bump map, gradients, DDS export
- Script-fu enables headless batch operation
- DDS plug-in is GIMP-native (no separate DDS tool)
- Bump map + gradient blend produces the desired bevel effect

**Consequences:**
- ✅ Single tool for all advanced image operations
- ✅ Reproducible effects via scripts
- ⚠️ GIMP startup overhead per invocation (~0.5–1s × 8 calls per asset)
- ⚠️ GIMP 2.10+ and DDS plug-in required

**Alternatives Considered:**
- ImageMagick alone: rejected — no bump map, weaker SVG support, no DDS export
- Inkscape for SVG→PNG: rejected — would still need GIMP for bevel/DDS

---

## D6: potrace for Raster → Vector Conversion

**Decision:** Raster sources (PNG, BMP, XCF) are traced to SVG via potrace.

**Rationale:**
- potrace is the standard open-source bitmap tracer
- Produces clean SVG paths from high-contrast bitmaps
- Enables the unified SVG pipeline (D2)

**Consequences:**
- ✅ Free, fast, reliable for simple shapes
- ⚠️ Single-colour tracing — gradients and anti-aliasing lost
- ⚠️ Complex raster sources convert poorly

**Mitigation:** SVG is the recommended and preferred source format; raster tracing is a convenience path.

---

## D7: File-Existence Incremental Builds

**Decision:** Incremental builds skip assets when all three output DDS files exist.

**Rationale:**
- Trivial to implement, no metadata database needed
- Covers the common case: adding new assets to existing build
- No cache invalidation logic to maintain

**Consequences:**
- ✅ Fast incremental builds (<30s for a few new assets)
- ⚠️ Does not detect source modifications
- ⚠️ Does not detect script/configuration changes
- ⚠️ Full rebuild (`rm -rf build out`) required after edits

**Alternatives Considered:**
- Timestamp comparison: rejected — adds complexity, still misses script changes
- Hash-based caching: rejected — overkill for this project scale

---

## D8: names.txt Filename Mapping

**Decision:** Output filenames resolved via explicit `source=output` mapping file, defaulting to `ui_` prefix.

**Rationale:**
- Decouples source naming (descriptive, hyphenated) from output naming (game-friendly, underscored)
- Stable output names even when sources are renamed
- Explicit, greppable, diff-friendly mapping

**Consequences:**
- ✅ Output names independent of source names
- ✅ Simple lookup, easy to audit
- ⚠️ Mapping file must be maintained
- ⚠️ Collisions (two sources → same output) silently overwrite

---

## D9: Category-as-Directory Convention

**Decision:** Each subdirectory of `source/flags/` is a category; discovery is automatic.

**Rationale:**
- No registry or manifest to maintain
- Adding a category = creating a directory
- Filesystem is the source of truth

**Consequences:**
- ✅ Zero-configuration category addition
- ⚠️ Localisation must be added separately (or raw keys show in game)
- ⚠️ Empty directories produce empty categories

---

## D10: Fail-Fast Setup, Continue-On-Error Assets

**Decision:** Setup problems (missing tools, missing source) abort the build; individual asset failures are skipped.

**Rationale:**
- Missing tools mean every asset would fail — abort early
- One bad asset shouldn't block 300 good ones
- Maximises output from each build run

**Consequences:**
- ✅ Robust against individual corrupt assets
- ⚠️ Failed assets are silently absent from output
- ⚠️ Exit code does not reflect asset failures — manual verification needed

---

## D11: System + Flatpak Tool Detection

**Decision:** Tools detected via system PATH, then Flatpak system export, then Flatpak user export.

**Rationale:**
- Covers the two common Linux installation methods
- Flatpak increasingly default for GIMP/Inkscape on immutable distros
- No configuration needed by user

**Consequences:**
- ✅ Works out-of-box on most Linux distros
- ⚠️ Snap, Nix, custom paths not detected
- ⚠️ Flatpak GIMP may lack DDS plug-in (separate install)

---

## D12: Static Assets Copied Verbatim

**Decision:** Backgrounds (DDS), colours, localisation, and thumbnail are copied without transformation.

**Rationale:**
- These are already in game-native format
- No processing = no quality loss, no bugs
- Author controls exact content

**Consequences:**
- ✅ WYSIWYG for backgrounds and colours
- ⚠️ Background DDS must be valid (correct compression, mipmaps) — build doesn't validate

---

## D13: Tag-Triggered CI Deployment

**Decision:** Steam Workshop and Nexus Mods deployments trigger on `v*.*.*` tag push, downloading the GitHub Release asset.

**Rationale:**
- Tag = release intent; clear trigger point
- Release asset is the single distribution artefact — all platforms get identical content
- No build in CI (tools not installed on runners) — maintainer builds locally

**Consequences:**
- ✅ Identical artefact across platforms
- ✅ Simple workflow logic
- ⚠️ Release must exist before/with tag — otherwise workflows fail
- ⚠️ Local build required (CI can't run build.sh)

---

## D14: English-Only Localisation

**Decision:** Only `l_english` localisation is provided.

**Rationale:**
- Maintainer language; community can contribute translations
- Category names are the only localised strings

**Consequences:**
- ✅ Minimal maintenance
- ⚠️ Non-English players see English category names
- ⚠️ Adding languages requires new `l_<lang>:` files

---

## D15: GPL v3.0 Licence

**Decision:** Project licensed under GNU GPL v3.0.

**Rationale:**
- Strong copyleft ensures derivatives stay open
- Consistent with author's other projects

**Consequences:**
- ✅ Clear open-source terms
- ⚠️ Franchise-referencing content (Star Wars, Marvel categories) may have separate IP considerations regardless of code licence

---

## Decision Summary

| # | Decision | Key Trade-off |
|---|----------|---------------|
| D1 | Single bash script | Simplicity over scalability |
| D2 | SVG canonical intermediate | Uniform pipeline over raster fidelity |
| D3 | Three fixed resolutions | Game compliance over flexibility |
| D4 | Bevel main+small, not map | UI polish vs map clarity |
| D5 | GIMP Script-fu | One tool over per-invocation speed |
| D6 | potrace tracing | Convenience path with quality loss |
| D7 | Existence-based incremental | Simplicity over change detection |
| D8 | names.txt mapping | Explicitness over convention |
| D9 | Directory-as-category | Zero config over validation |
| D10 | Fail-fast/continue | Robustness over strictness |
| D11 | System+Flatpak detection | Coverage over configurability |
| D12 | Verbatim static copy | WYSIWYG over validation |
| D13 | Tag-triggered CI | Artefact consistency over build automation |
| D14 | English-only | Maintenance cost over coverage |
| D15 | GPL v3 | Copyleft over permissiveness |