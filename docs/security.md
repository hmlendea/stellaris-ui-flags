# Security

## Overview

The project is a content mod with a build pipeline — a low-risk security profile. Key areas:

1. **CI secrets** — Steam and Nexus credentials in GitHub Actions
2. **Build inputs** — source files processed by external tools
3. **No runtime code** — output is pure content, no scripts executed by the game

## Threat Model Summary

| Asset | Threat | Mitigation | Residual Risk |
|-------|--------|------------|---------------|
| CI secrets | Leakage via workflow logs/forks | GitHub Actions secret masking | Low |
| Steam credentials | Account compromise | Dedicated credentials, 2FA seed scoped to workflow | Medium |
| Build tools | Malicious source files exploiting tool parsers | Sources are trusted (maintainer-controlled) | Low |
| Mod output | Malicious content in game | Content-only; no executable code | Very low |
| Repository | Supply chain via dependencies | No package dependencies; pinned GitHub Actions | Low |

## CI Secrets Handling

### Secrets in Use

| Secret | Workflow | Purpose |
|--------|----------|---------|
| `STEAM_USERNAME` | steam-workshop.yml | Steam login |
| `STEAM_PASSWORD` | steam-workshop.yml | Steam password |
| `STEAM_2FASEED` | steam-workshop.yml | TOTP seed for 2FA |
| `NEXUS_UPLOADER_USERNAME` | nexus-mods.yml | Nexus login |
| `NEXUS_UPLOADER_PASSWORD` | nexus-mods.yml | Nexus password |

### Protection Mechanisms

- **GitHub Actions secret store:** Values stored encrypted, masked in logs
- **Masking:** GitHub automatically replaces secret values with `***` in workflow logs
- **Scope:** Secrets only available to workflows in this repository
- **Fork PRs:** Secrets not exposed to pull requests from forks

### Risks and Practices

| Risk | Status | Notes |
|------|--------|-------|
| Secrets printed in logs | Mitigated | GitHub masking; avoid `echo` of secrets in workflow edits |
| Secrets in workflow file | Not present | Workflows reference `${{ secrets.* }}` only |
| Over-broad permissions | Minimal | Workflows only need contents:read + actions write |
| Credential reuse | Recommended against | Use dedicated accounts for CI uploads |

### Steam 2FA Seed

The `STEAM_2FASEED` is the shared secret used to generate TOTP codes. **This is equivalent to the account's second factor.**

- Compromise of the seed + password = full account access
- Store only in GitHub secret store
- Never commit, log, or transmit outside the workflow
- Consider a dedicated Steam account for mod publishing

## Build Input Security

### Source Files Processed by External Tools

The build parses contributor-supplied files with:

| Tool | Parses | Attack Surface |
|------|--------|----------------|
| GIMP | PNG | Image format parsers (historically had CVEs) |
| potrace | BMP | Bitmap parser |
| ImageMagick | PNG, SVG via rsvg | Image parsers (notorious CVE history) |

**Current exposure:** Low — sources are maintainer-curated, not user-uploaded.

**Practice:** Review contributed source files before building with them. Do not build untrusted archives.

### Batch Script Parameter Injection

GIMP batch parameters are passed through environment variables, and the script path is interpolated into the batch expression:

```bash
local GIMP_BATCH_COMMAND="import sys; sys.path.insert(0, '${SOURCE_SCRIPTS_DIR_PATH}'); exec(open('${GIMP_SCRIPT_PATH}').read())"
env GIMP_SCRIPT_IMAGE_PATHS="${INPUT_PATHS}" "${GIMP_BINARY}" --new-instance -i \
    --batch-interpreter=python-fu-eval -b "${GIMP_BATCH_COMMAND}" --quit
```

The script path is resolved from `SOURCE_SCRIPTS_DIR_PATH`, which is derived from the repository
root, not from contributor input.

- The script path and directory are interpolated into the batch expression, so a path containing `'` could alter it
- Parameters are passed as environment values, not as code, so filenames cannot inject Python
- **Current exposure:** Low — paths are derived from the repository root and filenames are maintainer-controlled
- **Practice:** Avoid quotes and parentheses in source filenames; the `ui_` prefix and `names.txt` mapping constrain output names

## Output Security

The mod package contains **no executable content**:

| Content Type | Executable? |
|--------------|-------------|
| DDS textures | No |
| colors.txt | No (data only) |
| Localisation YAML | No (data only) |
| descriptor.mod | No (data only) |
| thumbnail.png | No |

Stellaris parses these as data. There is no mod code, no DLLs, no scripts the game executes. The mod cannot affect the game beyond displaying content.

## Repository Security

### Dependencies

- **No package dependencies** (no npm, pip, NuGet, etc.)
- **GitHub Actions:** `actions/checkout` (official), `hmlendea/steam-workshop-update`, `hmlendea/nexusmods-update` (third-party)
- **Third-party actions:** Pinned to latest — consider SHA-pinning for supply-chain hardening

### Licence

GNU GPL v3.0 — code and scripts are open source. Content includes franchise-referencing designs (Star Wars, Marvel, etc.) with separate IP considerations; see `SECURITY.md` and `PRIVACY.md` in the repository root.

## Security Practices for Contributors

| Practice | Reason |
|----------|--------|
| Never commit secrets | Credentials in Git history are permanent |
| Use dedicated upload accounts | Limits blast radius of CI compromise |
| Review source files before building | Tool parser attack surface |
| Avoid special characters in filenames | Batch expression injection prevention |
| Report vulnerabilities privately | See `SECURITY.md` for contact |

## Security Checklist for Release

Before publishing a release:

- [ ] No secrets in repository or workflow files
- [ ] Workflow logs from previous runs contain no leaked credentials
- [ ] Source files reviewed (no unexpected binaries)
- [ ] Output package contains only expected content types (DDS, txt, yml, png, mod)
- [ ] Upload credentials still scoped and valid
- [ ] `SECURITY.md` contact information current