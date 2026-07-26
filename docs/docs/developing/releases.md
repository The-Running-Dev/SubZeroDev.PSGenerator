---
title: Releases and GitHub Packages
description: Version, validate, publish, and verify a generator release.
sidebar_position: 7
---

# Releases and GitHub Packages

Publishing is release-driven. Merging code into `main` does not create a package.

## Version Contract

The module version is declared in:

```text
src/SubZeroDev.PSGenerator.psd1
```

GitHub Release tags must use:

```text
v<ModuleVersion>
```

For `ModuleVersion = '1.0.0'`, the tag is:

```text
v1.0.0
```

The publishing workflow accepts three numeric version components and rejects a tag
that does not exactly match the manifest.

## Pre-release Validation

From a clean checkout:

```powershell
./build/Invoke-Quality.ps1 -InstallDependencies
./build/Test-Documentation.ps1
Invoke-Pester -Path ./tests -Output Detailed
./build/Test-GeneratorNuGetPackage.ps1 -InstallDependencies
```

Run the PowerShell 7.4 baseline with an exact 7.4 runtime:

```powershell
./build/Test-PowerShellBaseline.ps1
```

Then run the Docker end-to-end suite:

```powershell
Invoke-Pester -Path ./tests-e2e -Output Detailed
```

Confirm:

- the manifest version is final;
- release notes describe user-visible behavior and breaking changes;
- installation and getting-started documentation match the release;
- required checks pass on `main`; and
- the version has never been published.

## Container Image

The image is published on a different cadence from the package. Every push to
`main` that touches `Dockerfile`, `.dockerignore`, or `src/**` builds
`ghcr.io/the-running-dev/subzerodev.psgenerator` and pushes two tags: an
immutable date-based `YYYY.MM.DD` and `latest`.

Pull requests build and smoke-test the image without pushing, so a broken image
blocks the merge instead of reaching `main`. The smoke test asserts from outside
the image that `pwsh` starts on 7.4, and that the commands it exposes match the
manifest exactly.

Because `latest` follows `main` rather than a release tag, it can be ahead of the
published package. Pin a date tag when the environment must be reproducible.

## Publish

1. Merge the release-ready changes to `main`.
2. Create a GitHub Release targeting the final `main` commit.
3. Tag it with the exact `v<ModuleVersion>` value.
4. Link the documentation for that version in the release notes, for example
   `https://psgenerator.subzerodev.com/`, which serves the newest release.
5. Publish the release.

The `Publish` GitHub Actions workflow then:

1. validates tag syntax;
2. compares the tag to the module manifest;
3. builds the `.nupkg`;
4. installs and imports it from a temporary local feed;
5. uploads it as a workflow artifact; and
6. pushes it to
   `https://nuget.pkg.github.com/The-Running-Dev/index.json`.

The workflow uses its short-lived `GITHUB_TOKEN` with `contents: read` and
`packages: write`. No long-lived publishing token is stored.

## Package Identity and Linkage

The package ID is:

```text
SubZeroDev.PSGenerator
```

The package contains Git repository metadata linking it to:

```text
https://github.com/The-Running-Dev/SubZeroDev.PSGenerator.git
```

GitHub may initially create the package with private visibility. A package
administrator controls visibility and directory access in package settings.

## Consumer Verification

After the workflow succeeds, follow
[Installation](../using/installation.md) from a clean user profile.

Verify:

```powershell
Get-InstalledPSResource SubZeroDev.PSGenerator
Import-Module SubZeroDev.PSGenerator -Force
Get-Command -Module SubZeroDev.PSGenerator
```

Then validate and build the minimal example.

## Failed Publication

If validation fails, fix the source and create a new release version. NuGet package
versions are immutable. Do not overwrite or silently reuse a published version.

If the GitHub Release exists but the package does not:

1. open Actions and select the `Publish` workflow;
2. confirm the event is `release`;
3. inspect tag-versus-manifest validation;
4. inspect the local package install test;
5. inspect `dotnet nuget push`; and
6. confirm workflow `packages: write` permission.

Deleting a release does not make reuse of an already published package version a
safe release strategy.
