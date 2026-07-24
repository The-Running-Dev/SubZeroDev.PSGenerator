---
title: Installation
description: Install ContainerPSGenerator from source or GitHub Packages.
sidebar_position: 1
---

# Installation

## Requirements

- PowerShell 7.4 or later.
- Docker when invoking generated container commands or installing `/PSModule` from
  an image.
- Windows or Linux for the supported Version 1 experience.

Confirm the local PowerShell version:

```powershell
$PSVersionTable.PSVersion
```

## Use a source checkout

Until the first package release is published, importing from a source checkout is
the direct installation path:

```powershell
git clone https://github.com/The-Running-Dev/SubZeroDev.ContainerPSGenerator.git
Set-Location ./SubZeroDev.ContainerPSGenerator
Import-Module ./src/SubZeroDev.ContainerPSGenerator.psd1 -Force
```

Verify the exported commands:

```powershell
Get-Command -Module SubZeroDev.ContainerPSGenerator
```

To test the same clean module layout used by CI:

```powershell
$manifest = ./build/New-GeneratorModulePackage.ps1
Import-Module $manifest.FullName -Force
```

The staged module is written to
`artifacts/module/SubZeroDev.ContainerPSGenerator` by default.

## Install from GitHub Packages

GitHub Packages requires an authenticated NuGet v3 request. Create a classic GitHub
personal access token with `read:packages`, then enter it through a secure prompt so
it does not appear in shell history:

```powershell
$token = Read-Host 'GitHub token (read:packages)' -AsSecureString
$credential = [pscredential]::new('YOUR_GITHUB_USERNAME', $token)

Register-PSResourceRepository `
    -Name SubZeroDevGitHub `
    -Uri 'https://nuget.pkg.github.com/The-Running-Dev/index.json' `
    -ApiVersion V3 `
    -Trusted

Install-PSResource `
    -Name SubZeroDev.ContainerPSGenerator `
    -Repository SubZeroDevGitHub `
    -Credential $credential `
    -Scope CurrentUser

Import-Module SubZeroDev.ContainerPSGenerator
```

:::note

The package does not exist until a GitHub Release with a tag matching the module
version is published. Installing from source remains valid before the first release.

:::

Update an existing installation with the same repository and credential:

```powershell
Update-PSResource `
    -Name SubZeroDev.ContainerPSGenerator `
    -Repository SubZeroDevGitHub `
    -Credential $credential
```

## Docker availability

The generator can validate specifications, inspect repositories, generate source,
and preview commands without starting Docker. Docker is required for:

- executing a generated container-backed command;
- running the minimal end-to-end example;
- installing a module from `/PSModule` inside an image; and
- running the full local CI workflow.

Check availability:

```powershell
docker info
```

Continue with [Build your first module](first-module.md).
