# State and Persistence

## Overview

The build is **stateless by design** — no database, no cache metadata, no configuration store. All state lives in the filesystem:

| Location | Role | Lifetime |
|----------|------|----------|
| `source/` | Input state (immutable during build) | Repository |
| `build/` | Intermediate state | Until manually deleted |
| `out/` | Output state | Until manually deleted |
| `build.sh` constants | Configuration state | Repository |

## Directory State

### `source/` — Input State

- **Written by:** Contributors (never by build)
- **Read by:** Build script
- **Persistence:** Git-tracked; survives everything
- **State role:** Single source of truth for all content

### `build/` — Intermediate State

- **Written by:** Build script (SVG and PNG intermediates)
- **Read by:** Build script (subsequent stages)
- **Persistence:** Survives build completion; not cleaned automatically
- **Contents:**
  ```
  build/
  └── <category>/
      ├── <source_name>.svg      (format conversion output)
      ├── <source_name>.png     (128px render)
      ├── <source_name>_map.png (256px render)
      └── <source_name>_small.png (24px render)
  ```
- **State role:** Debugging aid; would support future optimisation (skip re-conversion)
- **Note:** Intermediates are NOT used for incremental skipping — only `out/` DDS files are checked

### `out/` — Output State

- **Written by:** Build script (DDS files, descriptors, static copies)
- **Read by:** Nothing in the build; consumed by game/distribution
- **Persistence:** Survives build completion; not cleaned automatically
- **Contents:**
  ```
  out/
  ├── ui-flags.mod              (root descriptor)
  └── ui-flags/
      ├── descriptor.mod        (package descriptor)
      ├── thumbnail.png
      ├── usage.txt
      └── flags/
          ├── backgrounds/
          ├── colors.txt
          └── <category>/
              ├── <name>.dds
              ├── map/<name>.dds
              └── small/<name>.dds
  ```
- **State role:** The incremental-build checkpoint — DDS existence determines skip/reprocess

## Incremental Build State

The **only** build state that affects behaviour is output file existence:

```bash
if [[ -f "$MAIN_DDS" && -f "$MAP_DDS" && -f "$SMALL_DDS" ]]; then
    continue  # skip asset
fi
```

### State Transitions Per Asset

```
                    ┌─────────────────────────────┐
                    │ All 3 DDS exist in out/?    │
                    └──────┬──────────────┬───────┘
                        yes│           no│
                           ▼              ▼
                    ┌────────────┐  ┌────────────────┐
                    │   SKIP     │  │  PROCESS       │
                    │ (no work)  │  │ (full pipeline) │
                    └────────────┘  └───────┬────────┘
                                            ▼
                                    ┌───────────────┐
                                    │ Write 3 DDS    │
                                    │ to out/        │
                                    └───────────────┘
```

### What Incremental State Does NOT Track

| Change Type | Detected? | Recovery |
|-------------|-----------|----------|
| New source file added | ✅ (no DDS exists) | Automatic |
| Source file modified | ❌ (DDS still exists) | Delete DDS or full rebuild |
| Source file deleted | ❌ (DDS remains) | Full rebuild |
| GIMP script modified | ❌ | Full rebuild |
| build.sh logic modified | ❌ | Full rebuild |
| colours.txt modified | ✅ (copied every build) | Automatic |
| Localisation modified | ✅ (copied every build) | Automatic |
| Backgrounds modified | ✅ (copied every build) | Automatic |
| Thumbnail modified | ✅ (copied every build) | Automatic |

### Full Rebuild

```bash
rm -rf build out
./build.sh <version>
```

This resets all intermediate and output state. Required after any non-static change.

## Static vs Dynamic State

| Content | State Type | Rebuild Behaviour |
|---------|-----------|-------------------|
| Flag DDS files | Dynamic (per-asset) | Skipped if outputs exist |
| Descriptors | Dynamic (generated) | Regenerated every build |
| Backgrounds | Static (copied) | Overwritten every build |
| colors.txt | Static (copied) | Overwritten every build |
| Localisation | Static (copied) | Overwritten every build |
| Thumbnail | Static (copied) | Overwritten every build |
| usage.txt | Static (copied) | Overwritten every build |

**Key distinction:** Static content always refreshes; dynamic content only refreshes when its outputs are missing. This means static edits (colours, localisation) take effect on any build, while flag edits require output deletion.

## Concurrency State

**None.** No locks, no PID files, no mutexes.

- Two simultaneous builds on the same checkout **will corrupt state** (both write to `build/` and `out/`)
- Sequential builds are safe
- Builds in separate checkouts are safe (independent directories)

## Persistence Across Builds

| Data | Persists? | Purpose of Persistence |
|------|-----------|------------------------|
| `build/` intermediates | Yes | Debugging; potential future optimisation |
| `out/` DDS files | Yes | Incremental skip checkpoint |
| `out/` static copies | Yes (overwritten) | Idempotent — no purpose beyond output |
| `out/` descriptors | Yes (overwritten) | Idempotent |
| Any metadata/cache file | No | Doesn't exist |

## State Recovery Scenarios

### Interrupted Build

- **State:** Partial `out/` (some assets have 3 DDS, some have 0–2)
- **Recovery:** Re-run `./build.sh <version>` — complete assets skip; incomplete ones reprocess
- **Safety:** Guaranteed by INV-18 (skip requires all three)

### Corrupted Output

- **State:** DDS files exist but are invalid (e.g., disk corruption, tool bug)
- **Recovery:** Delete the specific DDS files, re-run build
- **Detection:** In-game texture errors; manual inspection

### Stale Output After Source Edit

- **State:** Source changed, DDS unchanged (incremental skip)
- **Recovery:** `rm out/ui-flags/flags/<cat>/<name>*.dds` (and map/small variants), re-run build
- **Or:** Full rebuild for many changes

### Accidental `out/` Deletion

- **State:** All output gone, `build/` intact
- **Recovery:** Re-run build — full reprocessing (intermediates in `build/` are not reused for skipping, but SVG conversion is re-run anyway)

## Design Rationale

The stateless design (D7) trades reprocessing time for simplicity:

- ✅ No cache invalidation bugs possible
- ✅ No state format to migrate
- ✅ Trivially understandable behaviour
- ⚠️ Modified sources require manual intervention
- ⚠️ Full rebuilds take 5–15 minutes

Any future state tracking (e.g., hash-based) must maintain the invariant that **static content always refreshes** and **skip decisions are conservative** (prefer reprocessing over skipping).