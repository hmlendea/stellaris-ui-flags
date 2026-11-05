# Testing

## Overview

There is **no automated test suite**. Validation is manual, at three levels:

1. **Build verification** — script and count checks after building
2. **Output verification** — file structure and format checks
3. **In-game verification** — the only true end-to-end test

## Why No Automated Tests

| Reason | Detail |
|--------|--------|
| Content project | Output is data, not code — few unit-testable units |
| Visual output | Correctness is "looks right in game" — hard to assert |
| Tool dependence | Tests would need GIMP/Inkscape/potrace installed — same cost as building |
| Scale | Full build (5–15 min) is itself the integration test |

The build script's functions are the closest thing to units; they can be exercised individually (see below).

## Level 1: Build Verification

### Run and Capture

```bash
./build.sh <version> 2>&1 | tee build.log
```

### Check for Errors

```bash
grep -iE "error|fail" build.log
```

Expected: no GIMP `execution error` lines, no tool failures.

### Count Completeness

```bash
for cat in source/flags/*/; do
    name=$(basename "$cat")
    src=$(find "$cat" -maxdepth 1 -type f | wc -l)
    out=$(find "out/ui-flags/flags/$name" -maxdepth 1 -name "*.dds" 2>/dev/null | wc -l)
    [[ $src -eq $out ]] || echo "MISMATCH: $name ($src sources, $out outputs)"
done
```

Expected: no mismatches. Mismatches indicate skipped assets (errors) or filename collisions (silent overwrites).

### Verify Three Variants Per Flag

```bash
for dds in out/ui-flags/flags/*/*.dds; do
    base=$(basename "$dds")
    cat=$(dirname "$dds" | xargs basename)
    [[ -f "out/ui-flags/flags/$cat/map/$base" ]] || echo "MISSING map: $cat/$base"
    [[ -f "out/ui-flags/flags/$cat/small/$base" ]] || echo "MISSING small: $cat/$base"
done
```

Expected: no missing variants (INV-5, INV-6).

## Level 2: Output Verification

### Structure Check

```bash
test -f out/ui-flags.mod && echo "root descriptor OK"
test -f out/ui-flags/descriptor.mod && echo "package descriptor OK"
test -f out/ui-flags/thumbnail.png && echo "thumbnail OK"
test -f out/ui-flags/flags/colors.txt && echo "colors OK"
test -d out/ui-flags/flags/backgrounds && echo "backgrounds OK"
```

### Descriptor Content Check

```bash
cat out/ui-flags.mod
```

Verify: correct `version`, `path="mod/ui-flags"`, `tags`, `picture`.

```bash
cat out/ui-flags/descriptor.mod
```

Verify: correct `version`, `path="."`.

### DDS Format Check

```bash
file out/ui-flags/flags/human/*.dds
```

Expected: DDS image data. For deeper validation, open in an image viewer supporting DDS (e.g., GIMP) and confirm:

- Main (128px): correct size, bevel visible, transparency preserved
- Map (256px): correct size, **no bevel** (INV-7)
- Small (24px): correct size, bevel visible

### Localisation Key Check

For each category directory, confirm the key exists:

```bash
for cat in source/flags/*/; do
    name=$(basename "$cat")
    grep -q "FLAG_CATEGORY_$name" source/localisation.yml || echo "MISSING localisation: $name"
done
```

Expected: no missing keys (INV-11).

## Level 3: In-Game Verification

The definitive test. Only in-game testing validates:

- Flag rendering in all contexts (empire creation, galaxy map, diplomacy)
- Colour application (primary/secondary/background contexts)
- Background display
- Category names (localisation)
- Random empire generation using the flags

### Procedure

1. Copy or symlink `out/ui-flags` to the Stellaris mods directory:
   - Linux: `~/.local/share/Paradox Interactive/Stellaris/mod/`
   - Windows: `Documents\Paradox Interactive\Stellaris\mod\`
2. Copy `out/ui-flags.mod` alongside it
3. Launch Stellaris, enable the mod in the launcher
4. Test each change:
   - New flag: find it in its category during empire creation
   - New category: confirm category appears with localised name
   - New colour: confirm it appears in colour pickers
   - New background: confirm it appears in background selection
5. Check contexts: empire creation preview, galaxy map, diplomacy screen
6. Check the game log (`error.log`) for texture load failures

### Regression Points

After any build change, verify:

| Change | Verify |
|--------|--------|
| New flag | All three contexts render (main, map, small) |
| Bevel script change | Main and small flags look correct; map still flat |
| DDS export change | All flags load without texture errors |
| colours.txt change | Colours apply correctly to flags, borders, ships |
| Descriptor change | Mod appears in launcher with correct version |
| Localisation change | Category names display correctly |

## Testing Individual Pipeline Functions

For debugging, exercise build functions in isolation. Source the script functions (or copy them) and call directly:

### Test SVG → PNG

```bash
gimp -i -b "(svg-to-png \"/tmp/test.svg\" \"/tmp/test.png\")" -b "(gimp-quit 0)"
```

Verify `/tmp/test.png` exists and opens correctly.

### Test Bevel

```bash
gimp -i -b "(apply-gradient-bevel \"/tmp/test.png\" \"/tmp/test_beveled.png\")" -b "(gimp-quit 0)"
```

Verify bevel effect visible.

### Test DDS Export

```bash
gimp -i -b "(png-to-dds \"/tmp/test.png\" \"/tmp/test.dds\")" -b "(gimp-quit 0)"
```

Verify `/tmp/test.dds` opens in GIMP or a DDS viewer.

### Test Full Asset Path

Pick one source file, run the complete chain manually, compare against build output. This isolates whether a bug is in the scripts or in the build loop logic.

## Test Data

Use simple, known-good test sources:

- **SVG:** A basic shape (star, square) with transparent background
- **PNG:** High-contrast black-on-white design (traces well via potrace)
- **XCF:** Simple two-layer file

Keep test sources out of `source/flags/` (they'd be built into the mod) — use `/tmp` or a scratch directory with a manual pipeline run.

## Testing Checklist Summary

### After Every Build

- [ ] No errors in build log
- [ ] Source/output counts match per category
- [ ] All three variants present per flag
- [ ] Descriptors present and correct
- [ ] Static content present (colors.txt, backgrounds, localisation, thumbnail)

### Before Every Release

- [ ] All above checks pass
- [ ] In-game verification completed for changed content
- [ ] No texture errors in game log
- [ ] Version correct in descriptors and release artefacts
- [ ] Full rebuild from clean (`rm -rf build out`) succeeds

### After Script/Logic Changes

- [ ] Full rebuild (incremental skips would hide script changes)
- [ ] Visual spot-check of affected flags in all three variants
- [ ] In-game verification