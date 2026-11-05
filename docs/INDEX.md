# Stellaris UI Flags Documentation

## Repository Summary

Stellaris UI Flags is a mod for the game Stellaris that adds hundreds of new flag designs matching the vanilla flag style. The repository contains source assets in editable formats (SVG, AI, XCF, PNG, BMP) and a reproducible build pipeline that converts these assets into Stellaris-compatible DDS textures at three resolutions (128px main, 256px map, 24px small) with gradient bevel effects.

## Root Document Map

- [README.md](../README.md) — Project overview, installation, distribution links, GitHub Actions, documentation catalogue
- [ARCHITECTURE.md](../ARCHITECTURE.md) — High-level architecture overview
- [SECURITY.md](../SECURITY.md) — Security policy and vulnerability reporting
- [PRIVACY.md](../PRIVACY.md) — Privacy and data handling
- [LICENSE](../LICENSE) — GNU GPL v3.0 license
- [CONTRIBUTING.md](../CONTRIBUTING.md) — Contribution guidelines
- [CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md) — Community standards

## Documentation Catalogue

### Core Documentation

| File | Description |
|------|-------------|
| [architecture.md](./architecture.md) | Detailed architecture complementing root ARCHITECTURE.md |
| [repository-overview.md](./repository-overview.md) | Repository purpose, scope, and entry points |
| [repository-structure.md](./repository-structure.md) | Source tree layout and module organisation |
| [build-and-deployment.md](./build-and-deployment.md) | Build pipeline, deployment, and environments |
| [configuration.md](./configuration.md) | Configuration schema, sources, and precedence |
| [data-model.md](./data-model.md) | Domain entities, relationships, and persistence |
| [dependencies.md](./dependencies.md) | External and internal dependencies |
| [design-decisions.md](./design-decisions.md) | Key architectural and design choices with rationale |
| [invariants.md](./invariants.md) | System-wide invariants and contracts |
| [error-handling.md](./error-handling.md) | Error taxonomy, handling patterns, recovery |
| [state-and-persistence.md](./state-and-persistence.md) | Build state, intermediate artefacts, incremental builds |
| [concurrency-and-scheduling.md](./concurrency-and-scheduling.md) | Parallelism, incremental builds, and scheduling |
| [logging.md](./logging.md) | Build logging, output formatting, and diagnostics |
| [security.md](./security.md) | Security model, threats, mitigations |
| [integrations.md](./integrations.md) | External system integrations (distribution platforms) |
| [testing.md](./testing.md) | Test strategy, organisation, coverage |
| [change-guide.md](./change-guide.md) | How to modify common areas safely |
| [ambiguities-and-open-questions.md](./ambiguities-and-open-questions.md) | Unresolved items, TODOs, known gaps |

### Component Deep Dives

| File | Description |
|------|-------------|
| [components/source-assets.md](./components/source-assets.md) | Source asset organisation, formats, and taxonomy |
| [components/build-pipeline.md](./components/build-pipeline.md) | Build script orchestration and tool integration |
| [components/output-package.md](./components/output-package.md) | Output mod package structure and Stellaris compliance |
| [components/gimp-scripts.md](./components/gimp-scripts.md) | GIMP Script-fu scripts for format conversion and effects |

### Execution Flows

| File | Description |
|------|-------------|
| [flows/build-execution.md](./flows/build-execution.md) | End-to-end build pipeline execution |
| [flows/asset-conversion.md](./flows/asset-conversion.md) | Per-asset format conversion pipeline |
| [flows/mod-packaging.md](./flows/mod-packaging.md) | Mod descriptor generation and packaging |

### Behaviour

| File | Description |
|------|-------------|
| [behaviour/INDEX.md](./behaviour/INDEX.md) | Observable build, in-game, content, platform, and edge-case behaviour |

### Reference

| File | Description |
|------|-------------|
| [api-reference/INDEX.md](./api-reference/INDEX.md) | API reference index (not applicable — no HTTP API) |
| [api-usage-examples.md](./api-usage-examples.md) | Build command examples and usage patterns |
| [faq.md](./faq.md) | Frequently asked questions |
| [quick-start.md](./quick-start.md) | Getting started guide for newcomers |
| [troubleshooting.md](./troubleshooting.md) | Common issues and solutions |

## Navigation Aids

- **Start here** (newcomers): [quick-start.md](./quick-start.md) → [repository-overview.md](./repository-overview.md) → [build-and-deployment.md](./build-and-deployment.md)
- **Deep dive** (component owners): [components/](./components/) → [architecture.md](./architecture.md) → [design-decisions.md](./design-decisions.md)
- **Flows** (debuggers): [flows/](./flows/) → [error-handling.md](./error-handling.md) → [troubleshooting.md](./troubleshooting.md)
- **Behaviour** (observers): [behaviour/INDEX.md](./behaviour/INDEX.md) → [testing.md](./testing.md) → [integrations.md](./integrations.md)

## Maintenance Metadata

- Last reviewed: 2026-11-05
- Owner: Repository maintainers
- Coverage status: Initial generation — comprehensive coverage of build pipeline, asset organisation, and output packaging