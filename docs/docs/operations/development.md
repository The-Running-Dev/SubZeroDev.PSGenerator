---
title: Development and CI
description: Set up the repository and run quality, test, coverage, packaging, and container checks.
sidebar_position: 1
---

# Development and CI

## Repository layout

```text
src/                 Generator module
src/Public/          Exported commands
src/Private/         Internal functions
src/Plugins/         Built-in pipeline plugins
build/               Local build and CI entry points
tests/               Pester unit and integration tests
tests-e2e/           Real Docker end-to-end tests
examples/Minimal/    Maintained runnable example
docs/                Docusaurus-compatible documentation
```

`docs-template` is an external Docusaurus template checkout and is intentionally
excluded from PowerShell analysis.

## Import the development module

```powershell
Import-Module ./src/SubZeroDev.ContainerPSGenerator.psd1 -Force
Get-Command -Module SubZeroDev.ContainerPSGenerator
```

## Static analysis

```powershell
./build/Invoke-Quality.ps1 -InstallDependencies
```

The gate pins PSScriptAnalyzer 1.25.0 and analyzes repository-owned PowerShell under
`src`, `build`, `examples`, `tests`, and `tests-e2e` using
`.config/PSScriptAnalyzerSettings.psd1`.

After the dependency is installed:

```powershell
./build/Invoke-Quality.ps1
```

## Unit and integration tests

```powershell
Invoke-Pester -Path ./tests -Output Detailed
```

CI first stages the generator into a clean module directory and points tests at that
manifest. This prevents the development source tree from masking missing package
files.

## PowerShell 7.4 baseline

The baseline script requires an exact 7.4 runtime:

```powershell
./build/Test-PowerShellBaseline.ps1
```

It stages and imports the generator, generates the minimal module, verifies both
manifests require PowerShell 7.4, imports the generated module, and checks its export.

## NuGet package

```powershell
./build/Test-GeneratorNuGetPackage.ps1 -InstallDependencies
```

This:

1. stages a clean module;
2. creates a genuine `.nupkg`;
3. verifies package identity and repository metadata;
4. registers a temporary local PSResource repository;
5. saves and imports the package; and
6. verifies `Build-ContainerModule` is exported.

Output is under `artifacts/packages`.

## Container end-to-end tests

Docker must be running:

```powershell
$configuration = New-PesterConfiguration
$configuration.Run.Path = './tests-e2e'
$configuration.Run.Exit = $true
$configuration.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $configuration
```

The test builds the minimal image, installs `/PSModule`, imports it, invokes supported
non-hardware mappings, validates help and documentation, and removes temporary
resources.

## Local GitHub Actions with act

Install Docker and `act`, then run:

```powershell
./build/Invoke-CI.ps1
```

The script builds `.act/Dockerfile` as a local runner and runs:

- PowerShell 7.4 baseline on the Ubuntu matrix leg;
- PowerShell quality;
- Ubuntu Pester and coverage;
- NuGet package verification; and
- container end-to-end tests.

`act` uses Linux containers and does not reproduce the hosted Windows runner.
GitHub Actions remains authoritative for Windows.

## Hosted reports

GitHub Actions publishes:

- Windows and Ubuntu NUnit test reports;
- container end-to-end NUnit results;
- a JaCoCo line-coverage report and summary; and
- the generated `.nupkg` as a workflow artifact.

The packaged generator must remain at or above the configured 85% command and line
coverage thresholds.
