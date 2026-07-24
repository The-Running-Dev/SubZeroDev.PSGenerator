---
title: ContainerPSGenerator
description: Generate native PowerShell modules for containerized applications.
id: template-overview
sidebar_position: 1
---

# SubZeroDev.ContainerPSGenerator

SubZeroDev.ContainerPSGenerator turns a repository-owned PowerShell data file into a
complete PowerShell module for a containerized application. Generated commands expose
native parameters, validation, completion, help, and `-WhatIf`, then translate bound
values into deterministic `docker run` arguments.

The generated module is embedded at `/PSModule` in the application image. Users copy
and validate it with `Install-ContainerModule`, import it normally, and invoke native
PowerShell commands instead of assembling Docker command lines.

## Choose your path

- **I want to try the generator:** start with
  [Installation](getting-started/installation.md), then
  [Build your first module](getting-started/first-module.md).
- **My repository already contains PowerShell scripts:** use
  [Script repository inference](getting-started/script-repositories.md).
- **I am defining a production interface:** read the
  [Specification reference](reference/specification.md) and
  [Runtime mapping guide](guides/runtime-mappings.md).
- **I am embedding the result in an image:** follow
  [Container packaging and installation](guides/container-packaging.md).
- **I am maintaining the generator:** begin with
  [Development and CI](operations/development.md) and
  [Architecture](architecture/overview.md).

## Version 1 capabilities

Version 1 supports:

- PowerShell 7.4 on Windows and Linux;
- declarative PSD1 specifications;
- deterministic manifests, loaders, commands, metadata, and Markdown references;
- Docker argument, environment, mount, volume, port, working-directory, device,
  GPU, resource-limit, secret, and generic runtime-option mappings;
- native `ValidateSet`, `ValidateRange`, `ValidatePattern`, and static completion;
- repository inspection and ordered plugin diagnostics;
- local script and exported module-function discovery beneath `scripts`;
- `/PSModule` container installation;
- local and hosted validation of a PowerShell NuGet package; and
- release-driven publishing to GitHub Packages.

Docker is the only Version 1 runtime. A public, compatibility-stable plugin SDK and
additional runtimes are deferred.

## The shortest complete workflow

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

Continue with [Build your first module](getting-started/first-module.md) for a
step-by-step explanation.

## Support boundary

PowerShell 7.4 is the minimum supported runtime. Windows and Linux are tested in CI.
macOS is best-effort and is not part of the required Version 1 test matrix.

Repository plugins execute as trusted, unsandboxed PowerShell code. Review plugin
source before running it.
