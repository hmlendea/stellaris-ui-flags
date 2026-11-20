# Integrations

## Overview

The project integrates with four external distribution platforms and three CI/CD workflows. There are no API integrations, webhooks, or third-party services in the build itself — all integrations are deployment-time.

## Integration Map

```
                    ┌──────────────────┐
                    │  GitHub Release  │
                    │  (zip artefact)  │
                    └────────┬─────────┘
                             │ downloaded by
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
    ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
    │   Steam     │  │  Nexus      │  │  Paradox    │
    │  Workshop   │  │  Mods       │  │  Mods       │
    │  (auto)     │  │  (auto)     │  │  (manual)   │
    └─────────────┘  └─────────────┘  └─────────────┘
              ▲              ▲
              │              │
    ┌─────────────┐  ┌─────────────┐
    │ steam-      │  │ nexus-      │
    │ workshop    │  │ mods        │
    │ .yml        │  │ .yml        │
    └─────────────┘  └─────────────┘
              ▲              ▲
              └──────┬───────┘
                     │ tag push v*.*.*
              ┌──────┴───────┐
              │   GitHub     │
              │   Actions    │
              └──────────────┘
```

## Steam Workshop

### Identity

| Property | Value |
|----------|-------|
| App ID | 281990 (Stellaris) |
| Item ID | 1914541325 |
| Update method | Automated via GitHub Actions |

### Workflow: `steam-workshop-release.yml`

| Property | Value |
|----------|-------|
| Trigger | Tag push matching `v*.*.*`, or manual dispatch |
| Action | `hmlendea/steam-workshop-update` |
| Input | Mod package built in the workflow |

### Secrets

| Secret | Purpose |
|--------|---------|
| `STEAM_USERNAME` | Steam account username |
| `STEAM_PASSWORD` | Steam account password |
| `STEAM_2FASEED` | Shared secret for TOTP 2FA codes |

### Process

1. Maintainer tags release `v<version>`
2. Workflow triggers and checks out the tag
3. Workflow installs the build tools and builds the mod with `./build.sh`
4. Workflow packages the built mod and extracts it to `release/`
5. Action authenticates to Steam (username + password + generated 2FA code)
6. Action uploads the mod directory as a new Workshop item version
7. Workshop item updated; subscribers receive update

### Failure Modes

| Failure | Cause | Recovery |
|---------|-------|----------|
| Build failure | Missing source or tool failure on the runner | Inspect the workflow log; re-run after a fix |
| Auth failure | Wrong/expired credentials | Update secrets |
| 2FA failure | Invalid seed | Update `STEAM_2FASEED` |
| Upload rejected | Package structure invalid | Rebuild package, re-release |

## Nexus Mods

### Identity

| Property | Value |
|----------|-------|
| Game | stellaris |
| Mod ID | 75 |
| File ID | 921613 |
| Update method | Automated via GitHub Actions |

### Workflow: `nexus-mods-release.yml`

| Property | Value |
|----------|-------|
| Trigger | Tag push matching `v*.*.*`, or manual dispatch |
| Action | `Nexus-Mods/upload-action` |
| Input | Mod package built in the workflow |

### Secrets

| Secret | Purpose |
|--------|---------|
| `NEXUSMODS_API_KEY` | Nexus Mods API key |

### Process

Identical shape to Steam Workshop: tag → workflow → install tools → build → package → authenticate → upload.

### Failure Modes

Same categories as Steam Workshop (build failure, auth failure, upload rejection).

## Paradox Mods

### Identity

| Property | Value |
|----------|-------|
| Update method | **Manual** |
| Automation | None |

### Process

1. Maintainer builds and zips the package
2. Maintainer logs into Paradox Mods portal
3. Maintainer uploads zip manually
4. No CI involvement

**Note:** No workflow file exists for Paradox Mods. This is the only fully manual distribution channel.

## GitHub Releases

### Role

GitHub Releases is the **public artefact archive** — maintainers can attach the zip produced by a release workflow for manual download.

### Process

1. Maintainer creates Release on GitHub with tag `v<version>`
2. Tag push triggers the Steam/Nexus workflows, which build and publish from that tag
3. Maintainer may attach the locally built `ui-flags_<version>.zip` for manual download

### Ordering

No ordering constraint exists between the Release and the tag-triggered workflows, because each workflow builds its own archive from the tag.

## GitHub Actions

### Workflow Files

| File | Purpose |
|------|---------|
| `.github/workflows/steam-workshop-release.yml` | Steam Workshop deployment |
| `.github/workflows/nexus-mods-release.yml` | Nexus Mods deployment |

### Common Structure

```yaml
on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - run: sudo apt-get install -y gimp imagemagick librsvg2-bin potrace
      - run: ./build.sh "<version>"
      - uses: <platform-action>@<version>
        with:
          # platform-specific inputs
        env:
          # secrets
```

### What CI Does NOT Do

- ❌ Run tests (none exist)
- ✅ Install the toolchain, build the mod, package it, and upload it

**Rationale (D13):** Each release workflow builds from the pushed tag, so the archive is reproducible from the repository alone.

## Local Distribution

### Manual Zip

For direct sharing or backup:

```bash
cd out
zip -r ui-flags-<version>.zip ui-flags/
```

### Local Install (Development)

```bash
# Copy
cp -r out/ui-flags ~/.local/share/Paradox\ Interactive/Stellaris/mod/
cp out/ui-flags.mod ~/.local/share/Paradox\ Interactive/Stellaris/mod/

# Or symlink (auto-updates with rebuilds)
ln -s "$(pwd)/out/ui-flags" ~/.local/share/Paradox\ Interactive/Stellaris/mod/ui-flags
ln -s "$(pwd)/out/ui-flags.mod" ~/.local/share/Paradox\ Interactive/Stellaris/mod/ui-flags.mod
```

## Integration Consistency Requirements

| Requirement | Invariant | Enforcement |
|-------------|-----------|-------------|
| Same content on all platforms | D13 (single artefact source) | Both workflows build from the same tag |
| Version matches tag | INV-20 | Manual procedure |
| Every workflow builds its archive | INV-19 | Workflow build step |
| Secrets valid | — | Manual rotation |

## Integration Failure Recovery

| Platform | Failure | Recovery |
|----------|---------|----------|
| Steam Workshop | Workflow failed | Fix cause (build/credentials), re-run workflow or re-push tag |
| Nexus Mods | Workflow failed | Same as Steam |
| Paradox Mods | Upload not done | Manual upload when available |
| GitHub Release | Asset missing | Upload asset to the release if a manual download copy is wanted |

## Adding a New Platform (Future)

To add a distribution platform:

1. Determine if an action exists for it (for example a `Nexus-Mods/*` or `hmlendea/*` action)
2. If yes: create a workflow mirroring the `steam-workshop-release.yml` structure, install the build tools, build with `./build.sh`, and add secrets
3. If no: add to manual distribution list (like Paradox Mods)
4. Update `build-and-deployment.md` and this document
5. Ensure the platform receives the same Release zip artefact (consistency)