---
title: Security model
description: Trust boundaries, secrets, generated code, and vulnerability reporting.
sidebar_position: 4
---

# Security model

## Supported versions

No version has been released. Security fixes currently target the latest `main`
revision. A supported-version table will replace this statement when the first
package is published.

## Trusted inputs

Treat these inputs as code:

- repository PSD1 specifications;
- repository plugin `.ps1` files;
- PowerShell scripts and modules packaged beneath `scripts`; and
- generated modules before importing them.

PowerShell data files can contain data-language expressions supported by
`Import-PowerShellDataFile`. Plugins are fully unsandboxed scripts.

Only generate or import modules from repositories and plugin roots you trust.

## Plugin permissions

A plugin runs with the generator process's:

- filesystem permissions;
- process execution rights;
- environment variables;
- network access; and
- available credentials.

There is no Version 1 sandbox or permission manifest. Review plugin source and pin
the repository revision used by CI.

## Container boundary

Generated commands can expose:

- host paths through bind mounts;
- Docker volumes;
- devices and GPUs;
- environment values;
- ports;
- secret files; and
- arbitrary supported runtime options.

Use least-privilege mappings:

- prefer read-only mounts;
- avoid mounting broad host directories;
- restrict device permissions;
- do not expose the Docker socket;
- prefer narrow secret targets;
- validate user-controlled runtime options; and
- preview with `-WhatIf`.

## Secrets

`Secret` mappings mount a host file read-only. The generator does not encrypt,
upload, or redact the file. The container process can read the mounted content.

Do not:

- store secret contents in the PSD1;
- include secrets in examples or generated documentation;
- pass secrets through verbose logging;
- commit local package tokens; or
- place tokens directly in command history.

GitHub Packages consumer credentials should be entered as `SecureString`.
Publishing uses the workflow-scoped `GITHUB_TOKEN`.

## Generated source review

Before publishing a container module:

```powershell
Build-ContainerModule
Get-ChildItem ./artifacts/PSModule -Recurse
Get-Content ./artifacts/PSModule/Public/*.ps1
```

Review runtime arguments, source paths, mount access, and image identity. Generated
modules are ordinary PowerShell code and should pass the same review standards as
authored modules.

## Container image integrity

`Install-ContainerModule` validates module structure, not image provenance. Use
trusted registries, immutable digests where appropriate, and repository-specific
signature or attestation policies.

## Reporting a vulnerability

Do not disclose an unpatched vulnerability in a public issue. Use the repository's
private GitHub security-reporting channel when available. Include:

- affected version or commit;
- impact and trust boundary;
- minimal reproduction;
- expected and actual behavior;
- suggested mitigation; and
- whether active exploitation is known.

If private reporting is unavailable, contact the repository owner privately before
opening a public issue.
