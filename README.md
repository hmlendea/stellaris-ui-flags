[![Donate](https://img.shields.io/badge/-%E2%99%A5%20Donate-%23ff69b4)](https://hmlendea.go.ro/funding)
[![Latest Release](https://img.shields.io/github/v/release/hmlendea/stellaris-ui-flags)](https://github.com/hmlendea/stellaris-ui-flags/releases/latest)
[![License](https://img.shields.io/github/license/hmlendea/stellaris-ui-flags)](https://github.com/hmlendea/stellaris-ui-flags/blob/master/LICENSE)

# Stellaris UI Flags

Mod for Stellaris that adds hundreds of new flag designs matching the vanilla flag style.

## 📑 Table of Contents

- [Capabilities](#capabilities)
- [Use Cases](#use-cases)
- [Usage](#usage)
- [Installation](#installation)
  - [Manual Installation](#manual-installation)
- [Localisation](#localisation)
- [Compatibility](#compatibility)
- [Privacy and Data](#privacy-and-data)
- [Development](#development)
  - [Requirements](#requirements)
  - [Setup](#setup)
  - [Build](#build)
- [GitHub Actions](#github-actions)
- [Project Structure](#project-structure)
  - [Directories](#directories)
- [Architecture](#architecture)
- [Documentation](#documentation)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)
- [Contributing](#contributing)
- [Code of Conduct](#code-of-conduct)
- [Related Projects](#related-projects)
- [Security](#security)
- [Support](#support)
- [Project Engagement](#project-engagement)
- [License](#license)

## ✨ Capabilities

- Hundreds of new flag designs organised by thematic category (aquatic, blocky, corporate, domination, fire, human, mechanical, ornate, pirate, plantoid, pointy, spherical, toxoid, zoological, and media-inspired categories)
- Editable source assets (SVG, PNG, BMP) converted through a reproducible build pipeline
- Three DDS resolution variants per flag: 128px main, 256px map, and 24px small
- Gradient bevel effect applied to the main and small variants
- Stellaris-compatible uncompressed DDS textures written directly by the build
- English localisation of flag category names
- Custom colour palette and background textures
- Automated Stellaris mod descriptor generation

## 🎯 Use Cases

- **Players:** Add hundreds of new flag designs to Stellaris that match the vanilla flag style.
- **Modders and contributors:** Author new flag designs as editable SVG, PNG, or BMP assets and convert them through the build pipeline.
- **Maintainers:** Build and package the mod for distribution to Steam Workshop, Paradox Mods, Nexus Mods, and GitHub Releases.

## 🚀 Usage

Build the mod package from the command line:

```bash
./build.sh 1.0.0
```

The command requires a version argument (for example `1.0.0`) and writes the built mod package to `out/ui-flags/`. The pipeline validates the required tools, copies the static assets, generates the mod descriptor, converts each flag to DDS at three resolutions with gradient bevels, and assembles the distributable package.

## 📦 Installation

[![Obtain it from Nexus Mods](https://raw.githubusercontent.com/hmlendea/readme-assets/master/badges/stores/nexus.png)](https://nexusmods.com/stellaris/mods/75)
[![Obtain it from Steam Workshop](https://raw.githubusercontent.com/hmlendea/readme-assets/master/badges/stores/steam-workshop.png)](https://steamcommunity.com/sharedfiles/filedetails/?id=1914541325)
[![Obtain it from Paradox Mods](https://raw.githubusercontent.com/hmlendea/readme-assets/master/badges/stores/paradox-mods.png)](https://mods.paradoxplaza.com/mods/25419/Any)
[![Obtain it from GitHub](https://raw.githubusercontent.com/hmlendea/readme-assets/master/badges/stores/github.png)](https://github.com/hmlendea/stellaris-ui-flags/releases)

### Manual Installation

1. Download the [latest release](https://github.com/hmlendea/stellaris-ui-flags/releases/latest)
2. Extract the contents into your game's mod directory:
   - Linux: `~/.local/share/Paradox Interactive/Stellaris/mod/`
   - macOS: `~/Library/Application Support/Paradox Interactive/Stellaris/mod/`
   - Windows: `%USERPROFILE%\Documents\Paradox Interactive\Stellaris\mod\`
3. Enable the mod in the Stellaris launcher

## 🌍 Localisation

The mod provides English localisation for its flag category names.

| Language | Locale | Status |
|----------|--------|--------|
| English | `en` | Complete |

## 🧩 Compatibility

| Component | Supported Versions | Notes |
|-----------|--------------------|-------|
| Stellaris | `v4.5.*` | Declared by the generated mod descriptor (`supported_version`) |

## 🛡️ Privacy and Data

Stellaris UI Flags does not collect personal data; it consists of local game assets.

For the detailed description of how the application handles privacy and personal data, see the [Privacy Statement](./PRIVACY.md).

The mod does not transmit, persist, or process personal data. Distribution platforms and Stellaris operate independently of the mod's data handling.

## 🛠️ Development

### Requirements

- [ImageMagick](https://imagemagick.org/) (`convert`, `magick`)
- [librsvg](https://gitlab.gnome.org/GNOME/librsvg) (`rsvg-convert`)
- [GIMP](https://www.gimp.org/) 3.0 or later (resolved lazily, only for the bevels)
- [potrace](https://potrace.sourceforge.net/)
- [Python 3](https://www.python.org/)

### Setup

```bash
git clone https://github.com/hmlendea/stellaris-ui-flags.git
cd stellaris-ui-flags
```

No dependency installation is required; the build runs entirely from the repository scripts and the tools listed above.

### Build

```bash
./build.sh 1.0.0
```

## ⚙️ GitHub Actions

| Workflow | Purpose | What it does |
|----------|---------|--------------|
| [ steam-workshop-release.yml ](https://github.com/hmlendea/stellaris-ui-flags/blob/master/.github/workflows/steam-workshop-release.yml) | Release to Steam Workshop | Runs on a `v*.*.*` tag push or manual dispatch: checks out the tag, installs the build tools, builds the mod, zips and extracts the package, and uploads the mod directory to Workshop item `1914541325` with a changelog link |
| [ nexus-mods-release.yml ](https://github.com/hmlendea/stellaris-ui-flags/blob/master/.github/workflows/nexus-mods-release.yml) | Release to Nexus Mods | Runs on a `v*.*.*` tag push or manual dispatch: checks out the tag, installs the build tools, builds the mod, zips the package, and uploads `ui-flags.zip` to Nexus Mods |

## 🗂️ Project Structure

The repository separates editable source assets from the generated mod package, with the build pipeline defined by a single build script.

### Directories

| Directory | Purpose |
|-----------|---------|
| `source/` | Editable source assets, colour palette, localisation, and conversion scripts |
| `source/flags/` | Flag designs grouped by thematic category |
| `source/backgrounds/` | Background textures used by the flags |
| `source/scripts/` | Python scripts for the DDS export and the batched gradient bevel |
| `docs/` | Repository documentation |
| `out/` | Generated mod package (build output) |

## 🏗️ Architecture

Stellaris UI Flags is a pipeline-oriented asset repository that converts editable flag sources into Stellaris-compatible DDS textures and packages them into a distributable mod.

See the [Architecture Documentation](./ARCHITECTURE.md) for the system context, principal components, runtime processes, ownership boundaries, dependencies, constraints, and extension points.

## 📚 Documentation

Comprehensive documentation is available in the [docs/](./docs/) directory:

| Resource | Description |
|----------|-------------|
| [Quick Start](./docs/quick-start.md) | Getting started guide for newcomers |
| [Architecture](./docs/architecture.md) | Detailed architecture complementing root ARCHITECTURE.md |
| [Repository Overview](./docs/repository-overview.md) | Repository purpose, scope, and entry points |
| [Repository Structure](./docs/repository-structure.md) | Source tree layout and module organisation |
| [Build and Deployment](./docs/build-and-deployment.md) | Build pipeline, deployment, and environments |
| [Configuration](./docs/configuration.md) | Configuration schema, sources, and precedence |
| [Components](./docs/components/) | Per-component deep dives (source assets, build pipeline, output package, GIMP scripts) |
| [Flows](./docs/flows/) | End-to-end execution flows (build execution, asset conversion, mod packaging) |
| [Behaviour](./docs/behaviour/INDEX.md) | Observable build, in-game, content, platform, and edge-case behaviour |
| [API Reference](./docs/api-reference/INDEX.md) | Build function signatures and usage |
| [API Usage Examples](./docs/api-usage-examples.md) | Concrete command examples for all operations |
| [Testing](./docs/testing.md) | Test strategy and verification procedures |
| [Troubleshooting](./docs/troubleshooting.md) | Common issues and solutions |
| [FAQ](./docs/faq.md) | Frequently asked questions |
| [Change Guide](./docs/change-guide.md) | How to modify common areas safely |
| [Design Decisions](./docs/design-decisions.md) | Key architectural choices with rationale |
| [Invariants](./docs/invariants.md) | System-wide invariants and contracts |
| [Error Handling](./docs/error-handling.md) | Error taxonomy and recovery patterns |
| [State and Persistence](./docs/state-and-persistence.md) | Build state, intermediates, incremental builds |
| [Concurrency and Scheduling](./docs/concurrency-and-scheduling.md) | Parallelism and scheduling |
| [Logging](./docs/logging.md) | Build logging and diagnostics |
| [Security](./docs/security.md) | Security model and mitigations |
| [Integrations](./docs/integrations.md) | External platform integrations |
| [Dependencies](./docs/dependencies.md) | External and internal dependencies |
| [Data Model](./docs/data-model.md) | Domain entities and relationships |
| [Ambiguities and Open Questions](./docs/ambiguities-and-open-questions.md) | Unresolved items and known gaps |

## 🩺 Troubleshooting

See [Troubleshooting Guide](./docs/troubleshooting.md) for diagnostic procedures and resolutions to recurring problems.

## ❓ FAQ

See the [FAQ](./docs/faq.md) for responses to frequently raised inquiries.

## 🤝 Contributing

You are welcome to submit any suggestion, feedback, or modification to this project.

When doing so, please:
- Maintain cross-platform compatibility
- Submit focused pull requests that conform to the existing code style
- Maintain your branch synchronised with `master`
- Revise the documentation when functionality changes
- Raise a new [issue](https://github.com/hmlendea/stellaris-ui-flags/issues) for problems or suggestions

See the [Contributing Guidelines](./CONTRIBUTING.md) for details on how to report issues, suggest enhancements, and submit changes.

## 📜 Code of Conduct

See the [Code of Conduct](./CODE_OF_CONDUCT.md) for the standards of conduct expected in all project spaces.

## 🔗 Related Projects

- [Character Traits](https://github.com/hmlendea/stellaris-ui-character-traits): Mod for Stellaris that adds various new character traits.
- [Deposit Blockers](https://github.com/hmlendea/stellaris-ui-deposit-blockers): Mod for Stellaris that adds various new deposit blockers.
- [Galaxy Sizes](https://github.com/hmlendea/stellaris-ui-galaxy-sizes): Mod for Stellaris that adds more galaxy sizes to the game.
- [Name Lists](https://github.com/hmlendea/stellaris-ui-name-lists): Mod for Stellaris that adds dozens of new and detailed name lists into the game.
- [Planet Modifiers](https://github.com/hmlendea/stellaris-ui-planet-modifiers): Mod for Stellaris that adds various new planet modifiers.
- [Species Names](https://github.com/hmlendea/stellaris-ui-species-names): Mod for Stellaris that adds hundreds of new species names into the game.
- [Species Traits](https://github.com/hmlendea/stellaris-ui-species-traits): Mod for Stellaris that adds dozens of new species traits, as well as increasing the number of maximum selectable traits.
- [Star Names](https://github.com/hmlendea/stellaris-ui-star-names): Mod for Stellaris that adds tens of thousands of new names for stars, nebulae, asteroids, and black holes.

## 🔒 Security

Stellaris UI Flags follows a coordinated disclosure policy for security vulnerabilities.

For information on reporting security vulnerabilities, see the [Security Policy](./SECURITY.md).

## 💬 Support

For support, please [open an issue](https://github.com/hmlendea/stellaris-ui-flags/issues).

## 💝 Project Engagement

Discovered a problem with Stellaris UI Flags or have a suggestion for it? [Open an issue](https://github.com/hmlendea/stellaris-ui-flags/issues)!

If you find this project useful, consider [funding it](https://hmlendea.go.ro/funding) or starring ⭐️ it on GitHub, or giving it a thumbs up and adding it as a favourite on the [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=1914541325)!

[![Donate](https://raw.githubusercontent.com/hmlendea/readme-assets/master/donate_generic.png)](https://hmlendea.go.ro/funding)

## 📄 License

This project is being distributed under the `GNU General Public License v3.0`.
See [LICENSE](./LICENSE) for additional information.
