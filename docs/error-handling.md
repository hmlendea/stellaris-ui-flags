# Error Handling

## Overview

The build script uses a two-tier error philosophy:

1. **Fail-fast** for setup problems — abort immediately
2. **Continue-on-error** for asset problems — skip and proceed

There is no explicit error-handling framework (no `trap`, no logging library). Errors surface as:
- Explicit validation exits (setup)
- Tool stderr output (assets)
- Missing output files (silent failures)

## Fail-Fast Errors (Setup)

These abort the build with a message and non-zero exit code.

### Missing Version Argument

```
Usage: ./build.sh <version>
```

- **Check:** `$#` argument count / empty `$1`
- **Exit code:** 1
- **When:** Before any work begins

### Missing Source Directory

```
ERROR: source/ directory not found!
```

- **Check:** `[ -d "source" ]`
- **Exit code:** 1
- **When:** Before any work begins

### Missing Tools

```
ERROR: <tool> is not installed!
```

- **Check:** Tool detection returns empty for all three paths (system PATH, Flatpak system, Flatpak user)
- **Exit code:** 1
- **When:** One check per tool, before any work begins
- **Note:** All four tools are required even if the current sources don't need all of them

## Continue-On-Error (Assets)

Individual asset failures do not abort the build.

### Behaviour

- Conversion function fails (tool error, bad file)
- Main loop continues to next asset
- Failed asset produces no output (or partial output)
- Build completes with exit code 0

### Failure Modes by Stage

| Stage | Failure Cause | Observable Effect |
|-------|---------------|-------------------|
| Format → SVG | Unsupported extension | Asset skipped (no case matches) |
| Format → SVG | Corrupt source file | Tool stderr; no SVG produced |
| Format → SVG | Inkscape can't parse AI | Inkscape error; no SVG |
| Format → SVG | potrace fails on BMP | potrace error; no SVG |
| SVG → PNG | GIMP can't load SVG | GIMP error; no PNG |
| SVG → PNG | Invalid SVG structure | GIMP error or blank PNG |
| Bevel | GIMP script error | GIMP error; no beveled PNG |
| PNG → DDS | DDS plug-in missing | GIMP error: `file-dds-save` undefined |
| PNG → DDS | Invalid PNG input | GIMP error; no DDS |

### Partial Output States

A failed asset can leave:

| State | Files Present | Consequence |
|-------|---------------|-------------|
| No output | None | Flag absent from mod (silent) |
| Partial | 1–2 of 3 DDS | Incremental rebuild reprocesses (safe) |
| Intermediate only | SVG/PNG in `build/` | Harmless; no game output |

**Important:** Partial outputs are safe because the incremental check requires all three DDS files (INV-18).

## Silent Failure Risks

The build does not track or report failed assets. These failure modes produce no error at all:

| Scenario | Why Silent | Detection Method |
|----------|-----------|------------------|
| Unsupported file extension | No case in format switch | Compare source count vs output count |
| Tool succeeds but output invalid | No output validation | In-game testing |
| Filename collision | Second write overwrites first | Count check; names.txt audit |
| Empty category directory | Loop body never runs | Directory listing |

### Post-Build Verification

Because of silent failures, verify after building:

```bash
# Count sources vs outputs per category
for cat in source/flags/*/; do
    name=$(basename "$cat")
    src=$(find "$cat" -maxdepth 1 -type f | wc -l)
    out=$(find "out/ui-flags/flags/$name" -maxdepth 1 -name "*.dds" | wc -l)
    echo "$name: $src sources, $out outputs"
done
```

Mismatched counts indicate skipped or collided assets.

## Tool Error Output

### GIMP

GIMP batch errors print to stderr:

```
batch command: experienced an execution error
```

- **Cause:** Script-fu error (bad arguments, missing function, file error)
- **Action:** Check the specific script and input file
- **Debugging:** Run the failing GIMP command manually with the same arguments

### Inkscape

```
** (inkscape:1234): WARNING **: Cannot open file
```

- **Cause:** Corrupt or unsupported AI file
- **Action:** Re-export the source as SVG

### potrace

```
potrace: file.pbm: unexpected end of file
```

- **Cause:** Corrupt BMP input
- **Action:** Verify the intermediate BMP (check `build/` directory)

### ImageMagick

```
convert: no decode delegate for this image format
```

- **Cause:** PNG file corrupt or format unsupported
- **Action:** Verify source PNG opens in an image viewer

## Error Propagation Summary

```
build.sh invocation
│
├── Argument validation ──── fail ──→ exit 1 (usage message)
├── Source validation ────── fail ──→ exit 1 (error message)
├── Tool detection (×4) ──── fail ──→ exit 1 (per-tool message)
│
└── Main loop (per asset)
    ├── Format conversion ── fail ──→ skip asset, continue
    ├── SVG → PNG ─────────── fail ──→ skip asset, continue
    ├── Bevel ──────────────── fail ──→ skip asset, continue
    ├── PNG → DDS ─────────── fail ──→ skip asset, continue
    └── All succeed ───────────────→ asset complete
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Build completed (may include skipped assets) |
| 1 | Setup failure (arguments, source, tools) |

**Note:** Exit code 0 does not guarantee all assets processed — it only means setup succeeded and the loop completed.

## Improving Error Handling (Future Work)

Potential enhancements, none currently implemented:

| Enhancement | Benefit | Cost |
|-------------|---------|------|
| Failed-asset list at end of build | Immediate visibility of skips | Small |
| `set -euo pipefail` | Catches unexpected script errors | Risk: may abort on benign errors |
| Output file existence checks | Detects silent tool failures | Small |
| Collision detection in names.txt | Prevents silent overwrites | Small |
| Build summary report (counts) | Quick verification | Small |

Any such change must preserve the fail-fast/continue-on-error split (D10) and the incremental skip invariant (INV-18).