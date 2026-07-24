---
title: ContainerPSGenerator
description: Generate native PowerShell modules for containerized applications.
sidebar_position: 1
---

# SubZeroDev.ContainerPSGenerator

[![Test](https://github.com/The-Running-Dev/SubZeroDev.ContainerPSGenerator/actions/workflows/test.yml/badge.svg)](https://github.com/The-Running-Dev/SubZeroDev.ContainerPSGenerator/actions/workflows/test.yml)
[![Publish](https://github.com/The-Running-Dev/SubZeroDev.ContainerPSGenerator/actions/workflows/publish.yml/badge.svg)](https://github.com/The-Running-Dev/SubZeroDev.ContainerPSGenerator/actions/workflows/publish.yml)
[![Docs build](https://github.com/The-Running-Dev/SubZeroDev.ContainerPSGenerator/actions/workflows/docs-build.yml/badge.svg)](https://github.com/The-Running-Dev/SubZeroDev.ContainerPSGenerator/actions/workflows/docs-build.yml)
[![Documentation](https://img.shields.io/badge/docs-psgenerator.subzerodev.com-blue)](/)

SubZeroDev.ContainerPSGenerator is a PowerShell 7.4+ build tool that generates
repository-specific PowerShell modules for containerized applications.

Repositories define native commands, parameters, validation, completion, help, and
Docker runtime mappings in `PSModule/PSModule.psd1`. The generator produces a
self-contained module that can be embedded at `/PSModule` in an image and installed
locally.

> **Status:** The Version 1 MVP workflow is implemented. Documentation, release
> policy, inspector hardening, and the first published package remain in progress.

## Quick start

```powershell
Import-Module ./src/SubZeroDev.ContainerPSGenerator.psd1 -Force

Test-ContainerModuleSpecification `
    -Specification ./examples/Minimal/PSModule/PSModule.psd1

Build-ContainerModule `
    -Specification ./examples/Minimal/PSModule/PSModule.psd1 `
    -Output ./artifacts/PSModule

Import-Module ./artifacts/PSModule/ExampleContainer.psd1 -Force
Invoke-Example -Repository . -Message hello -WhatIf
```

Run the complete Docker lifecycle:

```powershell
./examples/Minimal/Run-Example.ps1
```

## Documentation

The complete manual is published at
[psgenerator.subzerodev.com](/).

### Get started

- [Installation](/getting-started/installation)
- [Build your first module](/getting-started/first-module)
- [Infer commands from a script repository](/getting-started/script-repositories)

### Build and package modules

- [Runtime mappings](/guides/runtime-mappings)
- [Validation, completion, and help](/guides/validation-completion-help)
- [Container packaging and installation](/guides/container-packaging)
- [Trusted plugins](/guides/trusted-plugins)

### Reference

- [Specification](/reference/specification)
- [Commands](/reference/commands)
- [Repository inspection](/reference/inspection)
- [Generated output](/reference/generated-output)

### Project

- [Architecture](/architecture/overview)
- [Plugin pipeline](/architecture/plugins)
- [Development and CI](/operations/development)
- [Releases and GitHub Packages](/operations/releases)
- [Security](/operations/security)
- [Troubleshooting](/operations/troubleshooting)

See the
[engineering roadmap](https://github.com/The-Running-Dev/SubZeroDev.ContainerPSGenerator/blob/main/TODO.md)
and
[documentation roadmap](/TODO)
for remaining work.

## Core workflow

```text
Repository specification
        │
        ▼
Build-ContainerModule
        │
        ▼
Generated PowerShell module
        │
        ├── import and test locally
        └── copy to /PSModule in the image
                    │
                    ▼
             Install-ContainerModule
```

Generated commands support native PowerShell types, `ValidateSet`,
`ValidateRange`, `ValidatePattern`, static completion, comment-based help, Markdown
references, `-WhatIf`, verbose tracing, and ordered Docker argument rendering.

Inference can expose standalone scripts and explicitly exported module functions
beneath a repository's `scripts` directory without turning unrelated PowerShell
files into commands.

## Development checks

```powershell
./build/Invoke-Quality.ps1 -InstallDependencies
Invoke-Pester -Path ./tests -Output Detailed
./build/Test-GeneratorNuGetPackage.ps1 -InstallDependencies
```

With Docker and `act` installed:

```powershell
./build/Invoke-CI.ps1
```

Hosted CI validates PowerShell 7.4 on Windows and Linux, Pester tests, coverage,
static analysis, NuGet packaging, and a real container end-to-end workflow.

## Platform and trust boundary

PowerShell 7.4 is the minimum runtime. Windows and Linux are supported and tested.
macOS is best-effort for Version 1.

Repository plugins are trusted, unsandboxed PowerShell code. Review them before
running the generator.

## Package publication

The GitHub Packages workflow runs only when a GitHub Release is published with a tag
matching `v<ModuleVersion>`. Merging the workflow does not itself create a package.
See
[Releases and GitHub Packages](/operations/releases).

## License

No license has been selected yet.
