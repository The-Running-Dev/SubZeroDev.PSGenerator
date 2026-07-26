---
title: Container Packaging and Installation
description: Embed generated modules at /PSModule and install them safely.
sidebar_position: 7
---

# Container Packaging and Installation

Every compliant image stores one complete generated module at:

```text
/PSModule
```

## Generate During the Directory Build

```powershell
Build-PSModule `
    -Specification ./PSModule/PSModule.psd1 `
    -Output ./artifacts/PSModule
```

Treat `artifacts/PSModule` as build output. Generate it before the Docker build so a
single directory commit defines both the application and its PowerShell interface.

## Copy into the Final Image

```dockerfile
FROM mcr.microsoft.com/powershell:7.4-ubuntu-22.04

WORKDIR /app
COPY ./app/ /app/
COPY ./artifacts/PSModule/ /PSModule/

ENTRYPOINT ["pwsh", "-NoLogo", "-NoProfile", "-File", "/app/start.ps1"]
```

The `/PSModule` directory must contain exactly one top-level `.psd1` module manifest.
That manifest must pass `Test-ModuleManifest`.

## Install from an Image

```powershell
Install-PSModule `
    ghcr.io/example/example-container:latest
```

The default destination is `~/PSModule`. Choose a module-specific destination when
installing more than one generated module:

```powershell
Install-PSModule `
    ghcr.io/example/example-container:latest `
    -Destination ~/Modules/ExampleContainer
```

Preview without calling Docker or changing files:

```powershell
Install-PSModule `
    ghcr.io/example/example-container:latest `
    -Destination ~/Modules/ExampleContainer `
    -WhatIf
```

Replace an existing destination only after the staged module validates:

```powershell
Install-PSModule `
    ghcr.io/example/example-container:latest `
    -Destination ~/Modules/ExampleContainer `
    -Force
```

## Installation Safety

`Install-PSModule`:

1. resolves and rejects a filesystem-root destination;
2. refuses to replace an existing destination without `-Force`;
3. creates a temporary container without starting it;
4. copies `/PSModule` into a sibling staging directory;
5. requires exactly one top-level manifest;
6. validates that manifest;
7. replaces the destination only after validation succeeds; and
8. removes the temporary container and failed staging data.

If copying or validation fails, an existing destination is preserved.

## Import the Installed Module

```powershell
Import-Module ~/Modules/ExampleContainer/ExampleContainer.psd1 -Force
Get-Command -Module ExampleContainer
```

The installation contains generated command references:

```powershell
Get-ChildItem ~/Modules/ExampleContainer/Documentation
```

## Run the Maintained Example

From the generator directory:

```powershell
./examples/Minimal/Run-Example.ps1
```

The script generates the module, builds the image, installs and imports it, invokes
the command, validates help and Markdown documentation, and cleans up. Use
`-KeepArtifacts` to inspect the generated and installed layouts.
