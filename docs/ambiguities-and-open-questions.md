# Ambiguities and Open Questions

## Overview

This document records areas where the project's behaviour is ambiguous, undocumented in the codebase, or where open questions remain. These are candidates for clarification, testing, or future improvement — not defects.

## Build System

### A1: Flatpak GIMP DDS Export Availability

**Question:** Does the Flatpak GIMP (`org.gimp.GIMP`) include the DDS export plug-in?

**Context:** Tool detection supports Flatpak GIMP (D11). The build does not export DDS through GIMP
at all; `png_to_dds.py` writes the uncompressed format directly, so no DDS plug-in is required. The
only GIMP operations used are PNG load/export, Gaussian blur, and bump map.

**Impact:** None. GIMP is needed only for the batched gradient bevel.

**Resolution Path:** Resolved — GIMP 3 bundles every operation the bevel requires. Residual risk: a custom GIMP build without those filters.

---

### A2: ImageMagick Command Coverage

**Question:** Which ImageMagick command names does the build depend upon?

**Context:** The build uses `convert` for the raster flattening step (checked at `/usr/bin/convert`) and `magick` for the SVG alpha derivation and the DDS pixel extraction. IM7 keeps `convert` as a legacy alias; some distributions may drop it.

**Impact:** The build aborts at start-up if `/usr/bin/convert` is absent, even though `magick` exists.

**Resolution Path:** Resolve the flattening step to `magick` when `/usr/bin/convert` is missing. Low priority — most distributions still ship the alias.

---

### A4: potrace Tracing Quality Threshold

**Question:** What source characteristics make potrace tracing unacceptable?

**Context:** potrace traces single-colour bitmaps. Sources with gradients, soft edges, or fine detail produce poor SVGs. The boundary between "acceptable" and "unacceptable" is subjective.

**Impact:** Raster-sourced flags may lose detail. PNG sources in the repository were accepted at some quality level, but the threshold is undocumented.

**Resolution Path:** Document source preparation guidelines; consider a quality checklist for raster sources.

---

### A5: Incremental Build Safety After Script Changes

**Question:** Should the build detect script changes and force reprocessing?

**Context:** Incremental builds skip assets based on output existence only (D7). Changing `gradient_bevel.py` or `png_to_dds.py` does not trigger reprocessing — stale outputs persist.

**Impact:** Contributors may believe a script change took effect when it didn't. Current mitigation: documentation (change-guide.md) instructs full rebuild.

**Resolution Path:** Options: (a) hash scripts and compare, (b) touch all outputs on script change, (c) document only (current). Trade-off: complexity vs safety.

---

### A6: Empty Category Handling

**Question:** Should empty category directories be an error?

**Context:** An empty `source/flags/<cat>/` produces an empty output category directory. The game may display an empty category or ignore it — behaviour unverified.

**Impact:** Cosmetic; possible confusion.

**Resolution Path:** Verify in-game behaviour; decide whether to warn or error.

---

## Content

### A7: Franchise Content Licensing

**Question:** What is the licensing status of franchise-referencing flag designs (Star Wars, Marvel, Elder Scrolls, etc.)?

**Context:** The project is GPL v3.0 (D15), but GPL covers code/scripts, not necessarily the artistic designs referencing third-party IP. Categories like `ui_star-wars`, `ui_marvel`, `ui_elder-scrolls` contain designs derived from copyrighted properties.

**Impact:** Legal ambiguity for redistribution and derivatives. The mod is freely distributed; no known challenges, but the position is undocumented.

**Resolution Path:** Document the maintainer's position (e.g., fan content, non-commercial) in README or a dedicated statement.

---

### A8: Localisation Scope

**Question:** Should localisation expand beyond English?

**Context:** Only `l_english` exists (D14). Category names are the only localised strings. Community translations are possible but there's no infrastructure (no translation files, no workflow).

**Impact:** Non-English players see English category names.

**Resolution Path:** If pursued: add `l_<lang>` files, modify static staging to copy them, update documentation.

---

### A9: Colour Context Completeness

**Question:** Are all three contexts (flag, map, ship) defined for every colour?

**Context:** `colours.txt` entries may specify contexts. Whether every colour defines all three, or the game applies defaults, is not verified.

**Impact:** Possible inconsistent colour availability across contexts.

**Resolution Path:** Audit `colours.txt` entries; verify in-game.

---

### A10: Background DDS Specification Compliance

**Question:** Do all backgrounds meet Stellaris's exact DDS requirements?

**Context:** Backgrounds are copied verbatim (D12). Requirements (compression type, dimensions, mipmap chain) are assumed but not validated by the build.

**Impact:** A non-compliant background fails in-game with no build-time warning.

**Resolution Path:** Add optional validation step (e.g., header inspection) or document requirements for contributors.

---

## Distribution

### A11: CI Build Environment

**Question:** Does the CI build environment match the maintainer's local one closely enough?

**Context:** The release workflows install GIMP, ImageMagick, librsvg, and potrace from the Ubuntu runner's repositories and then run `build.sh`. The runner's GIMP and ImageMagick versions track the Ubuntu image, so a version that changes the bevel or alpha output could alter the published textures.

**Impact:** A runner toolchain change could alter the published textures without a repository change.

**Resolution Path:** If pursued: pin the runner image (`ubuntu-24.04` instead of `ubuntu-latest`) and verify a release's textures in game after a runner image update.

---

### A12: Paradox Mods Automation

**Question:** Can Paradox Mods uploads be automated?

**Context:** Paradox Mods is the only manual channel. No known API/action exists for automated upload.

**Impact:** Manual step in every release; possible forgotten uploads.

**Resolution Path:** Monitor for API availability; document the manual step prominently.

---

### A13: Manual GitHub Release Asset

**Question:** Should the public GitHub Release carry a zip asset?

**Context:** Neither workflow consumes a GitHub Release asset any more; each builds the package from the tag itself. A maintainer may still attach `ui-flags_<version>.zip` to the Release for manual download.

**Impact:** The public download artefact is optional and maintainer-produced, so it can lag the tag.

**Resolution Path:** Either drop the attached asset in favour of workflow artefacts, or keep attaching it as part of the tagging step and document the naming convention (`ui-flags_<version>.zip`).

---

## Game Behaviour

### A14: Stellaris Version Compatibility Range

**Question:** Which Stellaris versions does the mod actually support?

**Context:** `STELLARIS_VERSION="v4.5.*"` declares support, but the mod is pure content (textures + data). Older/newer versions may work fine — the declared version is a launcher hint, not a tested range.

**Impact:** Players on other versions see compatibility warnings or unexpected behaviour.

**Resolution Path:** Test across versions; update constant; document tested range.

---

### A15: Flag Display Context Coverage

**Question:** Are there display contexts beyond main/map/small?

**Context:** The pipeline produces exactly three variants (D3). If Stellaris introduces new flag display contexts (new UI, new resolutions), the mod may need additional variants.

**Impact:** Future game updates could reveal missing variants.

**Resolution Path:** Monitor game updates; extend pipeline if new contexts appear.

---

### A16: Random Empire Generation Behaviour

**Question:** How does `randomizable_combo` interact with the full colour/flag set?

**Context:** Colours marked `randomizable_combo` participate in random empire generation. The exact selection algorithm (game-side) and how it pairs with backgrounds/flags is not documented here.

**Impact:** Random empires may produce unexpected combinations.

**Resolution Path:** Game-side behaviour; observe and document patterns if relevant.

---

## Documentation

### A17: Python-Fu Parameter Completeness

**Question:** Are all tunable Python-Fu parameters documented?

**Context:** `gimp-scripts.md` documents the main parameters (blur radius, emboss elevation and depth, colour stops, DDS settings). Minor parameters may exist in the shared `gimp_image_operations.py` module.

**Impact:** Contributors modifying scripts may miss tunable values.

**Resolution Path:** Cross-check script source against documentation; update as needed.

---

### A18: names.txt Global Scope

**Question:** Is the global scope of names.txt mappings intentional?

**Context:** A mapping applies to any category. Two categories with same-named sources would both map to the same output name — potentially intentional (shared designs) or accidental (collision).

**Impact:** Cross-category name collisions possible.

**Resolution Path:** Document the global scope explicitly; consider per-category mapping files if collisions arise.

---

## How to Resolve an Entry

1. Investigate (test, read source, ask maintainer)
2. Update the relevant documentation with findings
3. If behaviour changes, update the affected docs
4. Remove the entry from this document (or mark resolved with a date)

**Goal:** This document should shrink over time as ambiguities are resolved and documented elsewhere.