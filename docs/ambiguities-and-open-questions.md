# Ambiguities and Open Questions

## Overview

This document records areas where the project's behaviour is ambiguous, undocumented in the codebase, or where open questions remain. These are candidates for clarification, testing, or future improvement — not defects.

## Build System

### A1: Flatpak GIMP DDS Plug-in Availability

**Question:** Does the Flatpak GIMP (`org.gimp.GIMP`) include the DDS plug-in?

**Context:** Tool detection supports Flatpak GIMP (D11), but the DDS plug-in (`file-dds-save`) is a separate package. Flatpak sandboxing may prevent plug-in installation into the expected directory.

**Impact:** If Flatpak GIMP lacks DDS support, all builds fail at the PNG→DDS stage — but only on systems using Flatpak GIMP.

**Resolution Path:** Test on a Flatpak-only system; document result; potentially add plug-in detection to build validation.

---

### A2: ImageMagick 7 `convert` Deprecation

**Question:** How long will `convert` remain available in ImageMagick 7?

**Context:** IM7 replaced `convert` with `magick`, keeping `convert` as a legacy alias. Some distributions may drop the alias.

**Impact:** Build breaks on systems without the alias.

**Resolution Path:** Detect `magick` as fallback; or require IM6. Low priority — most distros still ship the alias.

---

### A3: Inkscape AI Import Fidelity

**Question:** How well does Inkscape 1.x import modern Adobe Illustrator files?

**Context:** AI format has evolved (CC versions use different internal structures). Inkscape's import filter has known limitations with complex AI features (gradients, meshes, effects).

**Impact:** AI-sourced flags may convert with lost detail. Current AI sources in the repository convert acceptably (observed), but new AI files may behave differently.

**Resolution Path:** Prefer SVG exports from source tools; document AI limitations for contributors.

---

### A4: potrace Tracing Quality Threshold

**Question:** What source characteristics make potrace tracing unacceptable?

**Context:** potrace traces single-colour bitmaps. Sources with gradients, soft edges, or fine detail produce poor SVGs. The boundary between "acceptable" and "unacceptable" is subjective.

**Impact:** Raster-sourced flags may lose detail. PNG/XCF sources in the repository were accepted at some quality level, but the threshold is undocumented.

**Resolution Path:** Document source preparation guidelines; consider a quality checklist for raster sources.

---

### A5: Incremental Build Safety After Script Changes

**Question:** Should the build detect script changes and force reprocessing?

**Context:** Incremental builds skip assets based on output existence only (D7). Changing `gradient-bevel.lisp` or `png-to-dds.lisp` does not trigger reprocessing — stale outputs persist.

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

### A11: CI Build Absence

**Question:** Should CI build the mod?

**Context:** Workflows only download the Release asset (D13). Building in CI would require installing GIMP, Inkscape, potrace, ImageMagick on runners — feasible but adds workflow complexity.

**Impact:** Release artefact depends on maintainer's local environment; reproducibility not guaranteed.

**Resolution Path:** If pursued: CI job installs tools, runs build, uploads artefact, then triggers platform workflows. Trade-off: CI time vs reproducibility.

---

### A12: Paradox Mods Automation

**Question:** Can Paradox Mods uploads be automated?

**Context:** Paradox Mods is the only manual channel. No known API/action exists for automated upload.

**Impact:** Manual step in every release; possible forgotten uploads.

**Resolution Path:** Monitor for API availability; document the manual step prominently.

---

### A13: Release Asset Naming Convention

**Question:** Is there a canonical zip filename format?

**Context:** Workflows download "the release asset" — the exact filename pattern isn't enforced. Different names across releases could break workflow inputs.

**Impact:** Workflow failure if asset name doesn't match the workflow's expected pattern.

**Resolution Path:** Document and enforce a naming convention (e.g., `ui-flags-<version>.zip`); verify workflow input patterns match.

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

### A17: Script-fu Parameter Completeness

**Question:** Are all tunable Script-fu parameters documented?

**Context:** `gimp-scripts.md` documents the main parameters (bevel size/width/height, colour stops, DDS settings). Minor parameters (interpolation method, bump map channel) may exist in the scripts.

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