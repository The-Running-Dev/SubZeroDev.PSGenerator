---
title: Development and CI
description: Set up the repository and run quality, test, coverage, packaging, and container checks.
sidebar_position: 4
---

# Development and CI

## Directory Layout

```text
src/                 Generator module
src/Public/          Exported commands
src/Private/         Internal functions
src/Plugins/         Built-in pipeline plugins
build/               Local build and CI entry points
tests/               Pester unit and integration tests
tests-e2e/           Real Docker end-to-end tests
examples/Minimal/    Maintained runnable example
docs/                Docusaurus project and authored documentation
```

The documentation build pulls the published docs-template container image from GHCR.
It does not require a template repository checkout, Git submodule initialization, or
Node dependency setup in this repository.

## Documentation Site

Build this project's Docusaurus image locally:

```powershell
./docs.ps1 -BuildOnly
```

The script generates `docs/docs/index.md` from the root `README.md`. It prepends
stable Docusaurus title, description, and sidebar metadata, then rewrites
`https://psgenerator.subzerodev.com/` to `/` in the generated page. The README
therefore remains the homepage source of truth while local and staging links stay on
their current origin.

Run `./docs.ps1` to serve a baked image, or `./docs.ps1 -Live` to bind-mount the
authored Markdown and configuration for local editing.

In CI, `docs.yml` carries the triggers and calls one of two reusable workflows
that run every step inside `ghcr.io/the-running-dev/docs-template:latest`. A pull
request calls `docs-ci.yml`, which builds the site and archives the Pages
artifact without publishing, so a break in the deploy path is caught before
merge. A push to `main` calls `docs-deploy.yml`, which builds, uploads, and
deploys to GitHub Pages.

Both prefer the repository secret `REGISTRY_TOKEN` and fall back to the
workflow's `GITHUB_TOKEN`. `REGISTRY_TOKEN` must have `read:packages`; the
fallback works only when the published package grants this repository read
access.

`docs-ci.yml` and `docs-deploy.yml` are installed from Docusaurus-Template and
kept byte-identical to it, so `setup-docs-workflow.ps1` stays safe to re-run.

## Import the Development Module

```powershell
Import-Module ./src/SubZeroDev.PSGenerator.psd1 -Force
Get-Command -Module SubZeroDev.PSGenerator
```

To import the same clean layout CI tests against, stage it first. This is worth
doing before trusting a local pass, because the development tree can mask a file
missing from the package:

```powershell
$manifest = ./build/New-GeneratorModulePackage.ps1
Import-Module $manifest.FullName -Force
```

The staged module is written to `artifacts/module/SubZeroDev.PSGenerator` by
default.

## Static Analysis

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

## Documentation Links and Terminology

```powershell
./build/Test-Documentation.ps1
```

The gate validates authored Markdown that the documentation site build never sees.
Docusaurus already fails on unresolved links inside `docs/`, so this check covers
the rest: root Markdown such as `README.md` and `TODO.md`, plus cross-file relative
links and heading anchors everywhere.

It reports three rule kinds:

- `MarkdownLink` and `MarkdownAnchor` — a relative target that does not exist on
  disk, or a `#fragment` with no matching heading in the target document. Explicit
  `{#custom-id}` headings and duplicate-heading `-1` suffixes are both honored.
- `Terminology` — product-name casing from `.config/DocumentationRules.psd1`.
- `GeneratedFile` — a generated file whose committed copy no longer matches its
  source. `docs/docs/index.md` is generated from `README.md`, so editing the
  README without regenerating leaves the published homepage stale. The finding
  names the first line that differs.

  Both `docs.ps1` and this check call
  `build/ConvertTo-DocumentationHomepage.ps1` to produce the expected content,
  so the check cannot drift from the generator. Regenerate with any `docs.ps1`
  run, including `./docs.ps1 -BuildOnly`.

External and site-absolute links are reported as out of scope rather than fetched,
so the gate never depends on network reachability. Terminology rules apply to prose
only: fenced code, inline code, link targets, and bare URLs are masked first, so
commands, file paths, and URLs are never flagged.

Add terminology rules and path exclusions in `.config/DocumentationRules.psd1`.
Pass `-Path` to scan a subset:

```powershell
./build/Test-Documentation.ps1 -Path ./docs/docs
```

## Unit and Integration Tests

```powershell
Invoke-Pester -Path ./tests -Output Detailed
```

CI first stages the generator into a clean module directory and points tests at that
manifest. This prevents the development source tree from masking missing package
files.

### Maintained Fixtures

The suite includes isolated copies of a script-only directory and an authored
build-agent directory, under `tests/fixtures/directories`. Tests copy them to
temporary directories before initialization or generation, so the tracked fixture
sources stay unchanged.

## PowerShell 7.4 Baseline

The baseline script requires an exact 7.4 runtime:

```powershell
./build/Test-PowerShellBaseline.ps1
```

It stages and imports the generator, generates the minimal module, verifies both
manifests require PowerShell 7.4, imports the generated module, and checks its export.

## NuGet Package

```powershell
./build/Test-GeneratorNuGetPackage.ps1 -InstallDependencies
```

This:

1. stages a clean module;
2. creates a genuine `.nupkg`;
3. verifies package identity and repository metadata;
4. registers a temporary local PSResource repository;
5. saves and imports the package; and
6. verifies `Build-PSModule` is exported.

Output is under `artifacts/packages`.

## Container End-to-End Tests

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
- documentation links and terminology;
- Ubuntu Pester and coverage;
- NuGet package verification; and
- container end-to-end tests.

`act` uses Linux containers and does not reproduce the hosted Windows runner.
GitHub Actions remains authoritative for Windows.

## Hosted Reports

GitHub Actions publishes:

- Windows and Ubuntu NUnit test reports;
- container end-to-end NUnit results;
- a JaCoCo line-coverage report and summary; and
- the generated `.nupkg` as a workflow artifact.

The packaged generator must remain at or above the configured 85% command and line
coverage thresholds.
