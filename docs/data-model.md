# Data Model

## Overview

The project has no database or in-memory data structures. The "data model" is the **filesystem layout and file formats** that carry information through the pipeline. This document models that data: its entities, relationships, and lifecycle.

## Entity Relationship

```
┌─────────────────────────────────────────────────────────────────┐
│ MOD (ui-flags)                                                  │
│  ├── descriptor.mod (root) ──── path: mod/ui-flags              │
│  └── package/                                                     │
│       ├── descriptor.mod ──────── path: .                        │
│       ├── thumbnail.png                                             │
│       ├── usage.txt                                                 │
│       └── flags/                                                    │
│            ├── colors.txt ──────── (global colour definitions)     │
│            ├── backgrounds/ ────── (global background DDS set)     │
│            └── CATEGORY ──────── (1..N)                            │
│                 ├── FLAG ─────── (0..N per category)               │
│                 │    ├── <name>.dds      (main, 128px)             │
│                 │    ├── map/<name>.dds  (map, 256px)              │
│                 │    └── small/<name>.dds (small, 24px)            │
│                 └── (localisation key: FLAG_CATEGORY_<cat>)        │
└─────────────────────────────────────────────────────────────────┘
```

## Entities

### 1. Source Asset

**Location:** `source/flags/<category>/<source_name>.<ext>`

| Attribute | Type | Description |
|-----------|------|-------------|
| category | string | Parent directory name; becomes game category |
| source_name | string | Filename without extension |
| ext | enum | `svg`, `ai`, `xcf`, `png`, `bmp` |
| output_name | string | Resolved via names.txt or `ui_<source_name>` |

**Lifecycle:**
```
Created by contributor → read by build → converted to SVG intermediate
```

**Constraints:**
- One source asset → one output flag (1:1)
- Output name must be unique within category (INV-8, manual)
- Background must be removable (INV-14, manual)

---

### 2. Category

**Location:** `source/flags/<category>/`

| Attribute | Type | Description |
|-----------|------|-------------|
| name | string | Directory name |
| localisation_key | string | `FLAG_CATEGORY_<name>` |
| flags | list | Source assets within directory |

**Lifecycle:**
```
Directory created → discovered by build → output directory created → flags placed
```

**Constraints:**
- Category name = directory name (INV-9 structural)
- Localisation entry must exist (INV-11, manual)
- Empty category produces empty output directory (edge case)

---

### 3. Flag (Output)

**Location:** `out/ui-flags/flags/<category>/`

| Attribute | Type | Description |
|-----------|------|-------------|
| name | string | Output filename base (from names.txt or default) |
| main.dds | file | 128px, BC3, beveled |
| map.dds | file | 256px, BC3, flat |
| small.dds | file | 24px, BC3, beveled |

**Lifecycle:**
```
Source asset → SVG intermediate → PNG renders (×3) → bevel (×2) → DDS (×3)
```

**Constraints:**
- Exactly three variants (INV-5)
- Same base filename across variants (INV-6)
- Map variant never beveled (INV-7)

---

### 4. Filename Mapping (names.txt)

**Location:** `source/names.txt`

**Format:** `source_name=output_name` per line

| Attribute | Type | Description |
|-----------|------|-------------|
| source_name | string | Matches source filename (without extension) |
| output_name | string | Desired output filename |

**Resolution logic:**
```
output_name = names.txt[source_name]  OR  "ui_" + source_name
```

**Scope:** Global — mappings apply across all categories.

**Constraints:**
- No duplicate output_name within a category (INV-8, manual)
- Unmapped sources get `ui_` prefix automatically

---

### 5. Colour Definition (colours.txt)

**Location:** `source/colours.txt` → copied to `out/ui-flags/flags/colors.txt`

**Format:** Stellaris `colors = { ... }` block

**Entity per colour:**

| Attribute | Type | Description |
|-----------|------|-------------|
| name | string | Colour identifier |
| hsv | triple | Hue, saturation, value |
| use_as_border_color | bool | Enables border colour context |
| randomizable_combo | bool | Enables random empire generation |

**Contexts (per flag colour slot):**
- `flag` — primary flag colour
- `map` — map icon colour
- `ship` — ship colour

**Lifecycle:**
```
Authored → copied verbatim every build → parsed by game
```

**Constraints:**
- Valid Stellaris syntax (INV-12, manual)
- US spelling `colors.txt` in output (game requirement)

---

### 6. Background

**Location:** `source/backgrounds/<name>.dds` → `out/ui-flags/flags/backgrounds/`

| Attribute | Type | Description |
|-----------|------|-------------|
| name | string | Filename base |
| format | DDS | BC1/BC3 with mipmaps |

**Lifecycle:**
```
Authored (external tool) → copied verbatim → displayed in game
```

**Constraints:**
- Valid DDS (INV-13, manual)
- No transformation by build

---

### 7. Localisation Entry

**Location:** `source/localisation.yml` → `out/ui-flags/ui-flags_l_english.yml`

**Format:**
```yaml
l_english:
    FLAG_CATEGORY_<name>:0 "Display Name"
```

**Entity per entry:**

| Attribute | Type | Description |
|-----------|------|-------------|
| key | string | `FLAG_CATEGORY_<category_dir>` |
| value | string | Display text |

**Lifecycle:**
```
Authored → renamed on copy → parsed by game
```

**Constraints:**
- Key must match category directory name (INV-11, manual)
- English only (D14)

---

### 8. Descriptor

**Two instances:**

| Instance | Location | `path` value |
|----------|----------|--------------|
| Root | `out/ui-flags.mod` | `mod/ui-flags` |
| Package | `out/ui-flags/descriptor.mod` | `.` |

**Attributes:**

| Field | Value | Source |
|-------|-------|--------|
| name | `Universum Infinitum: Flags` | MOD_NAME constant |
| version | `<build argument>` | `$1` |
| path | see above | Hardcoded per instance |
| tags | `{"Graphics"}` | Hardcoded |
| picture | `thumbnail.png` | Hardcoded |
| supported_version | `v4.5.*` | STELLARIS_VERSION constant |

**Lifecycle:**
```
Generated every build (overwritten) → read by Stellaris launcher
```

---

### 9. Build Intermediate

**Location:** `build/<category>/<source_name>.<ext>`

| File | Produced By | Consumed By |
|------|-------------|-------------|
| `<name>.svg` | Format conversion (any source) | svg-to-png (×3 sizes) |
| `<name>.png` | svg-to-png (128px) | apply-gradient-bevel |
| `<name>_map.png` | svg-to-png (256px) | png-to-dds |
| `<name>_small.png` | svg-to-png (24px) | apply-gradient-bevel |
| `<name>_beveled.png` | apply-gradient-bevel | png-to-dds |
| `<name>_small_beveled.png` | apply-gradient-bevel | png-to-dds |
| `<name>.bmp` | convert (PNG/XCF paths) | potrace |

**Lifecycle:**
```
Created during build → persist after build → deleted only by manual rm -rf
```

**Note:** Intermediates are not used for incremental decisions (only `out/` DDS existence matters).

## Data Flow Summary

```
source/flags/<cat>/<src>.<ext>
        │
        ├─ names.txt lookup ──→ output_name
        │
        ▼
build/<cat>/<src>.svg                    (format conversion)
        │
        ├─→ build/<cat>/<src>.png ──bevel──→ <src>_beveled.png ──→ out/.../<out>.dds (main)
        ├─→ build/<cat>/<src>_map.png ─────────────────────────────→ out/.../map/<out>.dds
        └─→ build/<cat>/<src>_small.png ─bevel──→ ..._small_beveled.png → out/.../small/<out>.dds
```

## Static vs Dynamic Data

| Data | Type | Refresh Behaviour |
|------|------|-------------------|
| Flag DDS | Dynamic | Per-asset incremental skip |
| Descriptors | Generated | Every build |
| colours.txt / colors.txt | Static copy | Every build |
| localisation | Static copy (renamed) | Every build |
| backgrounds | Static copy | Every build |
| thumbnail | Static copy | Every build |
| usage.txt | Static copy | Every build |

## Key Relationships

| From | To | Cardinality | Via |
|------|----|-------------|-----|
| Mod | Category | 1:N | Directory |
| Category | Flag | 1:N | Directory |
| Flag | DDS variant | 1:3 | Filename + subdirectory |
| Source asset | Flag | 1:1 | Pipeline |
| Category | Localisation key | 1:1 | Naming convention |
| names.txt entry | Source asset | 0..1:1 | Optional mapping |
| Colour | Context | 1:3 | flag/map/ship slots |