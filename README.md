# SubZeroDev.PSGenerator

[![Test](https://github.com/The-Running-Dev/SubZeroDev.PSGenerator/actions/workflows/test.yml/badge.svg)](https://github.com/The-Running-Dev/SubZeroDev.PSGenerator/actions/workflows/test.yml)
[![Publish](https://github.com/The-Running-Dev/SubZeroDev.PSGenerator/actions/workflows/publish.yml/badge.svg)](https://github.com/The-Running-Dev/SubZeroDev.PSGenerator/actions/workflows/publish.yml)
[![Docs build](https://github.com/The-Running-Dev/SubZeroDev.PSGenerator/actions/workflows/docs-build.yml/badge.svg)](https://github.com/The-Running-Dev/SubZeroDev.PSGenerator/actions/workflows/docs-build.yml)
[![Documentation](https://img.shields.io/badge/docs-psgenerator.subzerodev.com-blue)](https://psgenerator.subzerodev.com/)

SubZeroDev.PSGenerator is a PowerShell 7.4+ build tool that generates
repository-specific PowerShell modules for containerized applications.

Repositories define native commands, parameters, validation, completion, help, and
Docker runtime mappings in `PSModule/PSModule.psd1`. The generator produces a
self-contained module that can be embedded at `/PSModule` in an image and installed
locally.

> **Status:** The Version 1 MVP workflow is implemented. Documentation, release
> policy, inspector hardening, and the first published package remain in progress.

## Quick start

```powershell
Import-Module ./src/SubZeroDev.PSGenerator.psd1 -Force

Test-PSModuleSpecification `
    -Specification ./examples/Minimal/PSModule/PSModule.psd1

Build-PSModule `
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
[psgenerator.subzerodev.com](https://psgenerator.subzerodev.com/).

### Get started

- [Installation](https://psgenerator.subzerodev.com/getting-started/installation)
- [Build your first module](https://psgenerator.subzerodev.com/getting-started/first-module)
- [Infer commands from a script repository](https://psgenerator.subzerodev.com/getting-started/script-repositories)

### Build and package modules

- [Runtime mappings](https://psgenerator.subzerodev.com/guides/runtime-mappings)
- [Validation, completion, and help](https://psgenerator.subzerodev.com/guides/validation-completion-help)
- [Container packaging and installation](https://psgenerator.subzerodev.com/guides/container-packaging)
- [Trusted plugins](https://psgenerator.subzerodev.com/guides/trusted-plugins)

### Reference

- [Specification](https://psgenerator.subzerodev.com/reference/specification)
- [Commands](https://psgenerator.subzerodev.com/reference/commands)
- [Repository inspection](https://psgenerator.subzerodev.com/reference/inspection)
- [Generated output](https://psgenerator.subzerodev.com/reference/generated-output)

### Project

- [Architecture](https://psgenerator.subzerodev.com/architecture/overview)
- [Plugin pipeline](https://psgenerator.subzerodev.com/architecture/plugins)
- [Development and CI](https://psgenerator.subzerodev.com/operations/development)
- [Releases and GitHub Packages](https://psgenerator.subzerodev.com/operations/releases)
- [Security](https://psgenerator.subzerodev.com/operations/security)
- [Troubleshooting](https://psgenerator.subzerodev.com/operations/troubleshooting)

See the
[engineering roadmap](https://github.com/The-Running-Dev/SubZeroDev.PSGenerator/blob/main/TODO.md)
and
[documentation roadmap](https://psgenerator.subzerodev.com/TODO)
for remaining work.

## Core workflow

```text
Repository specification
        │
        ▼
Build-PSModule
        │
        ▼
Generated PowerShell module
        │
        ├── import and test locally
        └── copy to /PSModule in the image
                    │
                    ▼
             Install-PSModule
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
[Releases and GitHub Packages](https://psgenerator.subzerodev.com/operations/releases).

## License

Released under the
[MIT License](https://github.com/The-Running-Dev/SubZeroDev.PSGenerator/blob/main/LICENSE).
