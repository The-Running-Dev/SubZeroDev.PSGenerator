---
title: Installation
description: Run PSGenerator from its container image, or install the PowerShell module.
sidebar_position: 1
---

# Installation

Two ways to run PSGenerator. The image needs nothing installed on the host; the
module needs PowerShell 7.4 or later. Pick one.

## Use the Container Image

PowerShell and the module are already inside, and `pwsh` is the entry point:

```powershell
docker pull ghcr.io/the-running-dev/subzerodev.psgenerator:latest
```

Mount the directory you want to work on at `/workspace`:

```powershell
docker run --rm -it `
    -v ${PWD}:/workspace `
    ghcr.io/the-running-dev/subzerodev.psgenerator:latest
```

The module resolves by name, so command discovery imports it automatically:

```powershell
Initialize-PSModuleDirectory -Directory /workspace -ListCommands
```

`latest` tracks `main`. Every published build also carries an immutable
date-based tag such as `2026.07.26`; pin that when a reproducible environment
matters.

:::note

The image does not contain the Docker CLI, so a generated container-backed
command cannot execute inside it. Authoring, validation, inspection, generation,
and `-WhatIf` all work; running the generated command against a real container
needs Docker on the host.

:::

## Install the Module

Requirements:

- PowerShell 7.4 or later.
- Windows or Linux for the supported Version 1 experience.
- Docker only when invoking generated container commands or installing
  `/PSModule` from an image.

Confirm the local PowerShell version:

```powershell
$PSVersionTable.PSVersion
```

### From GitHub Packages

GitHub Packages requires an authenticated NuGet v3 request. Create a classic
GitHub personal access token with `read:packages`, then enter it through a secure
prompt so it does not appear in shell history:

```powershell
$token = Read-Host 'GitHub token (read:packages)' -AsSecureString
$credential = [pscredential]::new('YOUR_GITHUB_USERNAME', $token)

Register-PSResourceRepository `
    -Name SubZeroDevGitHub `
    -Uri 'https://nuget.pkg.github.com/The-Running-Dev/index.json' `
    -ApiVersion V3 `
    -Trusted

Install-PSResource `
    -Name SubZeroDev.PSGenerator `
    -Repository SubZeroDevGitHub `
    -Credential $credential `
    -Scope CurrentUser

Import-Module SubZeroDev.PSGenerator
```

:::note

The package does not exist until a GitHub Release with a tag matching the module
version is published. Until then, use the container image or a source checkout.

:::

Update an existing installation against the same registered repository and
credential:

```powershell
Update-PSResource `
    -Name SubZeroDev.PSGenerator `
    -Repository SubZeroDevGitHub `
    -Credential $credential
```

### From a Source Checkout

Useful before the first package release, and when working on the generator
itself:

```powershell
git clone https://github.com/The-Running-Dev/SubZeroDev.PSGenerator.git
Set-Location ./SubZeroDev.PSGenerator
Import-Module ./src/SubZeroDev.PSGenerator.psd1 -Force
```

Verify the exported commands:

```powershell
Get-Command -Module SubZeroDev.PSGenerator
```

## Docker Availability

The generator validates specifications, inspects directories, generates source,
and previews commands without starting Docker. Docker is required only for:

- executing a generated container-backed command;
- running the minimal end-to-end example; and
- installing a module from `/PSModule` inside an image.

Check availability:

```powershell
docker info
```

Continue with [Build Your First Module](./first-module.md).
