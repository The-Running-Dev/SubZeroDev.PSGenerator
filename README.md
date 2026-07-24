# SubZeroDev.ContainerPSGenerator

[![Test](https://github.com/The-Running-Dev/SubZeroDev.ContainerPSGenerator/actions/workflows/test.yml/badge.svg)](https://github.com/The-Running-Dev/SubZeroDev.ContainerPSGenerator/actions/workflows/test.yml)
[![Publish](https://github.com/The-Running-Dev/SubZeroDev.ContainerPSGenerator/actions/workflows/publish.yml/badge.svg)](https://github.com/The-Running-Dev/SubZeroDev.ContainerPSGenerator/actions/workflows/publish.yml)

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

The Docusaurus-compatible Markdown manual is under [`docs/docs/`](docs/docs/index.md):

- [Installation](docs/docs/getting-started/installation.md)
- [Build your first module](docs/docs/getting-started/first-module.md)
- [Script repository inference](docs/docs/getting-started/script-repositories.md)
- [Runtime mappings](docs/docs/guides/runtime-mappings.md)
- [Specification reference](docs/docs/reference/specification.md)
- [Command reference](docs/docs/reference/commands.md)
- [Repository inspection](docs/docs/reference/inspection.md)
- [Container packaging and installation](docs/docs/guides/container-packaging.md)
- [Architecture](docs/docs/architecture/overview.md)
- [Development and CI](docs/docs/operations/development.md)
- [Releases and GitHub Packages](docs/docs/operations/releases.md)
- [Troubleshooting](docs/docs/operations/troubleshooting.md)

See [the engineering roadmap](TODO.md) and
[the documentation roadmap](docs/docs/TODO.md) for remaining work.

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
See [Releases and GitHub Packages](docs/operations/releases.md).

## License

No license has been selected yet.
