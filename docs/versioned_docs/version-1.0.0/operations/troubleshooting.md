---
title: Troubleshooting
description: Diagnose installation, generation, inference, Docker, plugin, CI, and package failures.
sidebar_position: 5
---

# Troubleshooting

## PowerShell version is unsupported

**Symptom:** manifest import or baseline validation reports a runtime below 7.4.

```powershell
$PSVersionTable.PSVersion
```

Install PowerShell 7.4 or later. `Test-PowerShellBaseline.ps1` intentionally requires
exactly 7.4.x even when development uses a newer runtime.

## Specification was not found

Default path:

```text
PSModule/PSModule.psd1
```

Select another file:

```powershell
Build-ContainerModule -Specification ./config/MyModule.psd1
```

Or initialize:

```powershell
Initialize-ContainerModuleSpecification -Repository .
```

## Validation fails

Run validation independently:

```powershell
Test-ContainerModuleSpecification -Specification ./PSModule/PSModule.psd1
```

Common causes:

- a collection is a scalar hashtable instead of `@(...)`;
- duplicate command, parameter, or object IDs;
- invalid `Verb-Noun` command syntax;
- a parameter type contains unsupported syntax;
- `Mandatory` is not Boolean;
- an unknown typed validation, completion, or mapping;
- a mapping property does not match its parameter type; or
- invalid help or example strings.

## No inferred commands appear

Inference reads only `scripts/**/*.ps1` and explicitly exported functions in
`scripts/**/*.psm1`.

Check parse errors:

```powershell
$inspection = Get-ContainerModuleInspection
$inspection.Data.PowerShellFiles |
    Select-Object Path, IsCommandCandidate, SuggestedCommandName, ParseErrors
```

Move intended public entry points beneath `scripts`, fix parsing, and explicitly
export module functions.

## Scaffold does not refresh

The local repository harness preserves authored specifications and any scaffold with
runtime mappings. This prevents inference from overwriting intent.

To deliberately replace a specification:

```powershell
Initialize-ContainerModuleSpecification `
    -Repository . `
    -Force
```

Review or save the existing PSD1 first.

## Generated command calls Docker unexpectedly

Only commands with `SourceKind = 'Script'` or `ModuleFunction` use packaged local
source. A `SourcePath` alone does not select a script inside a container.

Inspect:

```powershell
$model = Get-ContainerModuleModel
$model.Commands |
    Select-Object Name, @{n='SourceKind';e={$_.Definition.SourceKind}},
        @{n='SourcePath';e={$_.Definition.SourcePath}}
```

Regenerate the scaffold from a source beneath `scripts` or author explicit container
mappings.

## Packaged script cannot find a sibling file

Scripts should resolve dependencies relative to their own location:

```powershell
$commonModule = Join-Path $PSScriptRoot 'modules/Common.psm1'
Import-Module $commonModule -Force
```

Do not use `$PWD` for packaged-source dependencies; it refers to the caller's current
directory, not the script directory.

## Docker is missing

```powershell
Get-Command docker
docker info
```

`-WhatIf` does not require Docker:

```powershell
Invoke-MyCommand -WhatIf
Install-ContainerModule example/image:latest -WhatIf
```

## Docker exits non-zero

Run with verbose tracing:

```powershell
Invoke-MyCommand -Verbose
```

Copy the reported arguments into a direct Docker invocation, then inspect:

- image availability;
- entry point and command contract;
- host path existence and sharing;
- container path permissions;
- port conflicts;
- device/GPU capabilities; and
- resource-limit syntax.

## Install-ContainerModule fails

The image must contain exactly one top-level manifest at `/PSModule`.

Inspect manually:

```powershell
$id = docker create example/image:latest
docker cp "${id}:/PSModule/." ./artifacts/ModuleInspection
docker rm --force $id
Get-ChildItem ./artifacts/ModuleInspection
Test-ModuleManifest ./artifacts/ModuleInspection/*.psd1
```

Use `-Force` only when replacing a destination intentionally. Existing destinations
remain untouched when staged validation fails.

## Inspector fails on repository data

Run inspection and detailed diagnostics:

```powershell
$inspection = Get-ContainerModuleInspection
$inspection | Get-ContainerModuleDiagnostic -Detailed
```

Current parsers may terminate on malformed `.csproj`, `package.json`,
`.nuke/parameters.json`, OpenAPI JSON, and authoritative `*.schema.json`. See
[Repository inspection](../reference/inspection.md) for supported subsets.

## Plugin fails

The error names the plugin and stage. Confirm:

- filename matches `<numeric-prefix>.<name>.ps1`;
- the script declares `Context`;
- the selected root exists only once;
- expected context properties exist at that stage;
- paths are repository-relative; and
- the plugin writes through the context instead of relying on pipeline output.

Repository plugins are not sandboxed.

## act differs from GitHub Actions

`act` runs Linux containers and cannot reproduce hosted Windows. It also uses nested
Docker behavior and shared mounts that differ from hosted runners.

Use `act` for rapid Linux feedback, direct Pester on Windows for host feedback, and
GitHub Actions as the authoritative cross-platform result.

## Package is not visible

Merging the publishing workflow does not publish a package. A published GitHub
Release with a tag matching `v<ModuleVersion>` triggers publication.

Check:

```powershell
gh release list
gh run list --workflow publish.yml
```

If there is no release and no workflow run, no package was pushed.

## GitHub Packages authentication fails

Consumer operations require credentials. Use a classic PAT with `read:packages`,
your GitHub username, and the owner feed:

```text
https://nuget.pkg.github.com/The-Running-Dev/index.json
```

Do not use the publishing workflow's `GITHUB_TOKEN` outside its workflow run.
