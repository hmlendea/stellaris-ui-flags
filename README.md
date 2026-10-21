[![Donate](https://img.shields.io/badge/-%E2%99%A5%20Donate-%23ff69b4)](https://hmlendea.go.ro/fund.html) [![Latest Release](https://img.shields.io/github/v/release/hmlendea/stellaris-ui-flags)](https://github.com/hmlendea/stellaris-ui-flags/releases/latest) [![License](https://img.shields.io/github/license/hmlendea/stellaris-ui-flags)](https://github.com/hmlendea/stellaris-ui-flags/blob/master/LICENSE)

# Stellaris UI Flags

Mod for Stellaris that adds hundreds of new flag designs matching the vanilla flag style.

## 📑 Table of Contents

- [Capabilities](#-capabilities)
- [Usage](#-usage)
- [Installation](#-installation)
- [Architecture](#-architecture)
- [Contributing](#-contributing)
- [Code of Conduct](#-code-of-conduct)
- [Privacy and Data](#-privacy-and-data)
- [Security](#-security)
- [Project Engagement](#-project-engagement)
- [License](#-license)

## ✨ Capabilities

- Hundreds of new flag designs across multiple thematic categories (aquatic, blocky, corporate, domination, fire, human, mechanical, ornate, pirate, plantoid, pointy, spherical, toxoid, and media-inspired categories)
- Flags authored in editable formats (SVG, AI, XCF, PNG, BMP) and converted through a reproducible build pipeline
- Three resolution variants per flag (128px main, 256px map, 24px small) with gradient bevel effect on main and small variants
- Stellaris-compatible DDS output (BC1/BC3 with mipmaps) generated via GIMP
- Localisation support for English flag names
- Custom colour palette and background textures
- Automated mod descriptor generation for Steam Workshop, Paradox Mods, and Nexus Mods

## 🚀 Usage

Build the mod package locally:

```bash
./build.sh 1.0.0
```

The command requires a version argument (e.g., `1.0.0`). The build pipeline:
1. Validates required tools (ImageMagick, Inkscape, GIMP with DDS plug-in, potrace)
2. Copies static assets (backgrounds, colours, localisation, thumbnail)
3. Generates `.mod` descriptor files
4. Processes each flag category: converts source formats to SVG, renders PNG at three sizes, applies gradient bevel, exports DDS
5. Outputs the complete mod package to `out/ui-flags/`

Required tools:
- ImageMagick (`convert`)
- Inkscape
- GIMP 2.10+ with DDS plug-in
- potrace

## 📦 Installation

[![Obtain it from Steam Workshop](https://raw.githubusercontent.com/hmlendea/readme-assets/master/badges/stores/steam-workshop.png)](https://steamcommunity.com/sharedfiles/filedetails/?id=1914541325) [![Obtain it from Paradox Mods](https://raw.githubusercontent.com/hmlendea/readme-assets/master/badges/stores/paradox-mods.png)](https://mods.paradoxplaza.com/mods/25419/Any) [![Obtain it from Nexus Mods](https://raw.githubusercontent.com/hmlendea/readme-assets/master/badges/stores/nexus.png)](https://www.nexusmods.com/stellaris/mods/75) [![Obtain it from GitHub](https://raw.githubusercontent.com/hmlendea/readme-assets/master/badges/stores/github.png)](https://github.com/hmlendea/stellaris-ui-flags/releases)

### Manual Installation

1. Download the [latest release](https://github.com/hmlendea/stellaris-ui-flags/releases/latest)
2. Extract the contents into your game's mod directory:
   - Linux: `~/.local/share/Paradox Interactive/Stellaris/mod/`
   - macOS: `~/Library/Application Support/Paradox Interactive/Stellaris/mod/`
   - Windows: `%USERPROFILE%\Documents\Paradox Interactive\Stellaris\mod\`
3. Enable the mod in the Stellaris launcher

## 🏗️ Architecture

See the [architecture documentation](./ARCHITECTURE.md) for the system context, principal components, runtime flows, ownership boundaries, dependencies, constraints, and extension points.

## 🤝 Contributing

You are welcome to submit any suggestion, feedback, or modification to this project.

When doing so, please:
- Submit focused pull requests that conform to the existing code style
- Maintain your branch synchronised with `master`
- Raise a new [issue](https://github.com/hmlendea/stellaris-ui-flags/issues) for problems or suggestions

See the [contributing guidelines](./CONTRIBUTING.md) for details on how to report issues, suggest enhancements, and submit changes.

## 📜 Code of Conduct

See the [Code of Conduct](./CODE_OF_CONDUCT.md) for the standards of conduct expected in all project spaces.

## 🛡️ Privacy and Data

Universum Infinitum: Flags does not collect personal data; it consists of local game assets.

For the detailed description of how the application handles privacy and personal data, see [PRIVACY.md](./PRIVACY.md).

The mod does not transmit, persist, or process personal data. Distribution platforms and Stellaris operate independently of the mod's data handling.

## 🔒 Security

Stellaris UI Flags follows a coordinated disclosure policy for security vulnerabilities.

For information on reporting security vulnerabilities, see [SECURITY.md](./SECURITY.md).

## 💝 Project Engagement

- Report issues or suggest features via [GitHub Issues](https://github.com/hmlendea/stellaris-ui-flags/issues)
- Support the project: [![Donate](https://img.shields.io/badge/-%E2%99%A5%20Donate-%23ff69b4)](https://hmlendea.go.ro/fund.html)
- Star the repository if you find it useful

## 📄 License

This project is licensed under the GNU General Public License v3.0 — see [LICENSE](./LICENSE) for details.
