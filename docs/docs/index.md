---
title: PSGenerator
description: Generate native PowerShell modules for containerized applications.
sidebar_position: 1
---

# PSGenerator

[![Test](https://github.com/The-Running-Dev/SubZeroDev.PSGenerator/actions/workflows/test.yml/badge.svg)](https://github.com/The-Running-Dev/SubZeroDev.PSGenerator/actions/workflows/test.yml)
[![Docs](https://github.com/The-Running-Dev/SubZeroDev.PSGenerator/actions/workflows/docs.yml/badge.svg)](https://github.com/The-Running-Dev/SubZeroDev.PSGenerator/actions/workflows/docs.yml)
[![Container](https://github.com/The-Running-Dev/SubZeroDev.PSGenerator/actions/workflows/container.yml/badge.svg)](https://github.com/The-Running-Dev/SubZeroDev.PSGenerator/actions/workflows/container.yml)
[![Documentation](https://img.shields.io/badge/docs-psgenerator.subzerodev.com-blue)](/)

Give PSGenerator a container image and a description of the commands it should
expose, and it writes you a PowerShell module. Your users then run
`Invoke-Thing -Message hello` instead of remembering a `docker run` line.

> **Status:** Version 1. The generator, the container packaging contract, and the
> documentation are complete. The first published package is still pending.

## Run It

Two ways, both fine. Pick one.

**Container image** — nothing to install, PowerShell and the module are already
inside:

```powershell
docker run --rm -it `
    -v ${PWD}:/workspace `
    ghcr.io/the-running-dev/subzerodev.psgenerator:latest
```

**PowerShell module** — if you already have PowerShell 7.4 or later:

```powershell
Import-Module SubZeroDev.PSGenerator
```

Installing the module from GitHub Packages needs one-time authentication; see
[Installation](/using/installation) for that and
for running from a source checkout.

## Your First Module

Describe a command in `PSModule/PSModule.psd1`, then:

```powershell
Test-PSModuleSpecification -Specification ./PSModule/PSModule.psd1
Build-PSModule -Specification ./PSModule/PSModule.psd1 -Output ./artifacts/PSModule

Import-Module ./artifacts/PSModule/YourModule.psd1 -Force
Get-Help Invoke-YourCommand -Full
```

[Build Your First Module](/using/first-module)
walks through it end to end. To try the complete Docker lifecycle against a real
image, run `./examples/Minimal/Run-Example.ps1` from a source checkout.

## Documentation

The manual lives at
[psgenerator.subzerodev.com](/).

**[Using](/using/)** — install it, describe your
commands, package the result:

- [Installation](/using/installation)
- [Build Your First Module](/using/first-module)
- [Script Directory Inference](/using/script-directories)
- [Runtime Mappings](/using/runtime-mappings)
- [Container Packaging](/using/container-packaging)
- [Specification Reference](/using/specification)
- [Troubleshooting](/using/troubleshooting)

**[Developing](/developing/)** — how PSGenerator
itself is built:

- [Architecture Overview](/developing/overview)
- [Internal Plugin System](/developing/plugins)
- [Security Model](/developing/security)
- [Contributing](/developing/contributing)

## How It Works

```text
Specification
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

Generated commands are ordinary PowerShell: native types, `ValidateSet`,
`ValidateRange`, `ValidatePattern`, static completion, comment-based help,
Markdown references, `-WhatIf`, verbose tracing, and ordered Docker arguments.

If your directory already has scripts, inference can turn standalone `.ps1` files
and explicitly exported module functions beneath `scripts` into commands without
sweeping in unrelated PowerShell.

## Platform and Trust Boundary

PowerShell 7.4 is the minimum runtime. Windows and Linux are supported and tested;
macOS is best-effort for Version 1.

Local plugins are trusted, unsandboxed PowerShell. Review them before running the
generator against a directory you did not write.

## License

Released under the
[MIT License](https://github.com/The-Running-Dev/SubZeroDev.PSGenerator/blob/main/LICENSE).
