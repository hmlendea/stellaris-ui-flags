# Quick Start

## Prerequisites

### Required Software

| Tool | Version | Purpose | Install (Debian/Ubuntu) |
|------|---------|---------|-------------------------|
| Bash | 4.0+ | Build script execution | Pre-installed |
| ImageMagick | 6.0+ | PNG/BMP conversion | `sudo apt install imagemagick` |
| potrace | 1.0+ | Raster → vector tracing | `sudo apt install potrace` |
| Inkscape | 1.0+ | SVG rendering, AI import | `sudo apt install inkscape` |
| GIMP | 2.10+ | Script-fu, XCF, DDS export | `sudo apt install gimp gimp-dds` |

**Flatpak alternative** (auto-detected by build script):
```bash
flatpak install flathub org.inkscape.Inkscape
flatpak install flathub org.gimp.GIMP
```

**Note:** GIMP requires the DDS plug-in (`gimp-dds` package on Debian/Ubuntu).

### Verify Installation

```bash
convert --version
potrace --version
inkscape --version
gimp --version
```

## Build the Mod

### 1. Clone Repository

```bash
git clone https://github.com/hmlendea/stellaris-ui-flags.git
cd stellaris-ui-flags
```

### 2. Run Build

```bash
./build.sh 1.0.0
```

**Argument:** Version string (e.g., `1.0.0`, `2.3.1`)

**Duration:** 5–15 minutes for full build (300+ assets).

### 3. Verify Output

```bash
# Check package exists
ls out/ui-flags/

# Check descriptor
cat out/ui-flags.mod

# Count flags
find out/ui-flags/flags -name "*.dds" | wc -l
```

## Install in Stellaris

### Option A: Copy to Mod Directory

```bash
# Linux
cp -r out/ui-flags ~/.local/share/Paradox\ Interactive/Stellaris/mod/
cp out/ui-flags.mod ~/.local/share/Paradox\ Interactive/Stellaris/mod/

# Windows (from WSL or Git Bash)
cp -r out/ui-flags "/c/Users/<user>/Documents/Paradox Interactive/Stellaris/mod/"
cp out/ui-flags.mod "/c/Users/<user>/Documents/Paradox Interactive/Stellaris/mod/"
```

### Option B: Symlink (Development)

```bash
ln -s "$(pwd)/out/ui-flags" ~/.local/share/Paradox\ Interactive/Stellaris/mod/ui-flags
ln -s "$(pwd)/out/ui-flags.mod" ~/.local/share/Paradox\ Interactive/Stellaris/mod/ui-flags.mod
```

### Enable in Game

1. Launch Stellaris
2. Open **Mods** menu (launcher)
3. Enable **Universum Infinitum: Flags**
4. Start game
5. New game → Empire customisation → verify categories and flags appear

## Add a New Flag

### 1. Choose or Create Category

Existing categories: `source/flags/` (aquatic, human, mechanical, etc.)

New category:
```bash
mkdir source/flags/my-category
```

### 2. Add Source Asset

Preferred format: **SVG** (vector, best quality)

```bash
cp my-flag-design.svg source/flags/my-category/
```

Supported formats: `.svg`, `.png`, `.xcf`, `.ai`, `.bmp`

### 3. Optional: Custom Output Name

Add to `source/names.txt`:
```txt
my-flag-design=ui_my_custom_name
```

Without entry, output defaults to `ui_my-flag-design.dds`.

### 4. Add Localisation (New Categories Only)

Add to `source/localisation.yml`:
```yaml
 FLAG_CATEGORY_my-category:0 "My Category"
```

### 5. Rebuild

```bash
./build.sh 1.0.1
```

Incremental build processes only the new asset (<30 seconds).

### 6. Verify

```bash
ls out/ui-flags/flags/my-category/
# Should show: ui_my_custom_name.dds, map/, small/
```

## Add a Background Texture

1. Create DDS file (BC1/BC3 compression, mipmaps, power-of-two dimensions)
2. Place in `source/backgrounds/`
3. Rebuild: `./build.sh <version>`

## Add a Colour

Edit `source/colours.txt`:

```txt
colors = {
    my_colour = {
        flag = hsv { 0.5 0.8 1.0 }
        map = hsv { 0.5 0.8 1.0 }
        ship = hsv { 0.5 0.8 1.0 }
        use_as_border_color = no
    }
}
```

Rebuild: `./build.sh <version>`

## Full Rebuild

Use when sources change or scripts are modified:

```bash
rm -rf build out
./build.sh 1.0.0
```

**Note:** Incremental builds do not detect source modifications — always full rebuild after editing existing assets.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `MISSING SOURCE DIRECTORY` | Run from repository root |
| Tool not found | Install tool or verify Flatpak export path |
| Flags missing from output | Check source file format is supported |
| Mod not in launcher | Verify descriptor `path` matches directory name |
| Categories show raw keys | Add localisation entry for category |

See [Troubleshooting](troubleshooting.md) for details.

## Next Steps

- [Repository Overview](repository-overview.md) — What this mod contains
- [Build and Deployment](build-and-deployment.md) — Full pipeline details
- [Configuration](configuration.md) — Customise colours, names, categories
- [Contributing](../CONTRIBUTING.md) — Contribution guidelines