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

### Workflow: `steam-workshop.yml`

| Property | Value |
|----------|-------|
| Trigger | Tag push matching `v*.*.*` |
| Action | `hmlendea/steam-workshop-update` |
| Input | GitHub Release asset (zip) |

### Secrets

| Secret | Purpose |
|--------|---------|
| `STEAM_USERNAME` | Steam account username |
| `STEAM_PASSWORD` | Steam account password |
| `STEAM_2FASEED` | Shared secret for TOTP 2FA codes |

### Process

1. Maintainer tags release `v<version>`
2. Workflow triggers, checks out repository
3. Workflow downloads release asset (zip) from GitHub Release
4. Action authenticates to Steam (username + password + generated 2FA code)
5. Action uploads zip as new Workshop item version
6. Workshop item updated; subscribers receive update

### Failure Modes

| Failure | Cause | Recovery |
|---------|-------|----------|
| Asset not found | Release created without zip, or tag before release | Create release with asset; re-run workflow |
| Auth failure | Wrong/expired credentials | Update secrets |
| 2FA failure | Invalid seed | Update `STEAM_2FASEED` |
| Upload rejected | Zip structure invalid | Rebuild package, re-release |

## Nexus Mods

### Identity

| Property | Value |
|----------|-------|
| Game | stellaris |
| Mod ID | 75 |
| Update method | Automated via GitHub Actions |

### Workflow: `nexus-mods.yml`

| Property | Value |
|----------|-------|
| Trigger | Tag push matching `v*.*.*` |
| Action | `hmlendea/nexusmods-update` |
| Input | GitHub Release asset (zip) |

### Secrets

| Secret | Purpose |
|--------|---------|
| `NEXUS_UPLOADER_USERNAME` | Nexus Mods account username |
| `NEXUS_UPLOADER_PASSWORD` | Nexus Mods account password (or API key) |

### Process

Identical shape to Steam Workshop: tag → workflow → download release asset → authenticate → upload.

### Failure Modes

Same categories as Steam Workshop (asset missing, auth failure, upload rejection).

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

GitHub Releases is the **artefact source of truth** — both automated workflows download the zip from the Release attached to the tag.

### Process

1. Maintainer creates Release on GitHub with tag `v<version>`
2. Maintainer attaches zip artefact (built locally)
3. Tag push triggers Steam/Nexus workflows
4. Workflows download the attached zip

### Critical Ordering

The Release (with asset) must exist when workflows run. If the tag is pushed before the Release asset is uploaded, workflows fail with "asset not found".

**Recommended sequence:**
1. Build package locally
2. Create GitHub Release with tag `v<version>` and attach zip
3. Push tag (or push tag first, then immediately attach asset)
4. Workflows trigger and download the asset

## GitHub Actions

### Workflow Files

| File | Purpose |
|------|---------|
| `.github/workflows/steam-workshop.yml` | Steam Workshop deployment |
| `.github/workflows/nexus-mods.yml` | Nexus Mods deployment |

### Common Structure

```yaml
on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hmlendea/<action>@latest
        with:
          # platform-specific inputs
        env:
          # secrets
```

### What CI Does NOT Do

- ❌ Build the mod (no GIMP/Inkscape/potrace on runners)
- ❌ Run tests (none exist)
- ❌ Validate the package
- ✅ Only download and upload the pre-built artefact

**Rationale (D13):** Build tools are heavy and platform-specific; the maintainer builds locally where tools are installed and verified.

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
| Same zip on all platforms | D13 (single artefact) | Workflows download same Release asset |
| Version matches tag | INV-20 | Manual procedure |
| Release asset exists before workflows | INV-19 | Manual procedure |
| Secrets valid | — | Manual rotation |

## Integration Failure Recovery

| Platform | Failure | Recovery |
|----------|---------|----------|
| Steam Workshop | Workflow failed | Fix cause (asset/credentials), re-run workflow or re-push tag |
| Nexus Mods | Workflow failed | Same as Steam |
| Paradox Mods | Upload not done | Manual upload when available |
| GitHub Release | Asset missing | Upload asset to existing release; re-run workflows |

## Adding a New Platform (Future)

To add a distribution platform:

1. Determine if an `hmlendea/*` action exists for it
2. If yes: create workflow mirroring steam-workshop.yml structure, add secrets
3. If no: add to manual distribution list (like Paradox Mods)
4. Update `build-and-deployment.md` and this document
5. Ensure the platform receives the same Release zip artefact (consistency)