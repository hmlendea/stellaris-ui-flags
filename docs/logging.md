# Logging

## Overview

There is **no logging framework**. The build produces:

1. **Progress messages** — `echo` statements in `build.sh`
2. **Tool output** — stdout/stderr from GIMP, Inkscape, potrace, ImageMagick
3. **No log files** — everything goes to the terminal

## Build Script Output

### Progress Messages

`build.sh` uses plain `echo` for progress reporting:

| Message Pattern | When |
|-----------------|------|
| Tool detection results | Setup — reports which tool path was found |
| Category iteration | Once per category directory |
| Per-asset processing | Once per flag asset |
| Completion | End of build |

### Message Format

Messages are unstructured plain text — no timestamps, no levels, no categories.

```
Processing category: human
Processing flag: ui_earth
...
```

### Verbosity

- **No verbosity flag** — output is fixed
- **No quiet mode**
- **No debug mode** (use `bash -x ./build.sh` for tracing — see below)

## Tool Output

### GIMP

GIMP batch mode prints to stderr:

| Output | Meaning |
|--------|---------|
| `batch command: experienced an execution error` | Script-fu failure — check arguments and input file |
| Nothing (success) | Operation completed |
| Plug-in warnings | Non-fatal; usually ignorable |

GIMP startup also prints version/warning noise to stderr on each invocation — this is normal and not an error indicator.

### Inkscape

| Output | Meaning |
|--------|---------|
| `WARNING **: Cannot open file` | Source AI file unreadable |
| Nothing | Success |

### potrace

| Output | Meaning |
|--------|---------|
| `potrace: <file>: unexpected end of file` | Corrupt BMP input |
| Nothing | Success |

### ImageMagick

| Output | Meaning |
|--------|---------|
| `convert: no decode delegate for this image format` | Unsupported/corrupt PNG |
| `convert: ... deprecated` (ImageMagick 7) | Warning only — safe to ignore |

## Capturing Logs

### Full Session Capture

```bash
./build.sh <version> 2>&1 | tee build.log
```

- `2>&1` merges stderr (where tool errors go) into stdout
- `tee` writes to terminal and file simultaneously

### Error-Only Capture

```bash
./build.sh <version> 2>&1 | tee build.log | grep -iE "error|fail|warning"
```

### Debug Tracing

```bash
bash -x ./build.sh <version> 2>&1 | tee trace.log
```

- Prints every command before execution (with `+` prefix)
- Very verbose — use for diagnosing script logic, not tool failures
- Trace shows variable expansion, useful for path/naming issues

### GIMP Script Debugging

Run a single GIMP operation manually with full output:

```bash
gimp -i -b "(svg-to-png \"/path/to/input.svg\" \"/path/to/output.png\")" -b "(gimp-quit 0)"
```

- Errors print directly to terminal
- Interactive alternative: GIMP → Filters → Script-Fu → Console

## What Is NOT Logged

| Missing | Consequence |
|---------|-------------|
| Failed asset list | Skipped assets invisible; must count outputs manually |
| Per-asset timing | Performance analysis requires manual timing |
| Build summary (counts) | No quick verification of completeness |
| Tool versions used | Reproducibility requires manual capture |
| Timestamps | Cannot correlate output to time |

## Log Analysis Patterns

### Finding Failed Assets

```bash
grep -B2 "execution error" build.log
```

Shows context before each GIMP failure — typically the asset being processed.

### Counting Processed Assets

```bash
grep -c "Processing flag" build.log
```

Compare against source file count to detect silent skips.

### Extracting All Errors

```bash
grep -iE "error|cannot|fail" build.log | sort | uniq -c | sort -rn
```

Groups and counts error types for quick triage.

## Recommendations

For debugging builds:

1. Always capture: `./build.sh <version> 2>&1 | tee build.log`
2. Check for GIMP errors: `grep "execution error" build.log`
3. Verify counts: compare processed vs source counts
4. For script logic issues: `bash -x` tracing
5. For single-asset issues: run the GIMP command manually

For future enhancement, a failed-asset summary at build end would eliminate most manual log analysis (see `error-handling.md`).