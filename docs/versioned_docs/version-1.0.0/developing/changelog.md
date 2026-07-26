---
title: Changelog
description: Unreleased Version 1 implementation history.
sidebar_position: 9
---

# Changelog

The project has not published its first release. All entries are currently
unreleased and will be consolidated into the first Version 1 release notes.

## Unreleased

### Added

- Declarative PSD1 specifications for module identity, commands, parameters, stable
  IDs, help, examples, validation, completion, and runtime mappings.
- Deterministic generation of module manifests, loaders, public commands, normalized
  JSON metadata, and Markdown command references.
- Docker mappings for arguments, environment variables, bind mounts, named volumes,
  ports, working directories, devices, GPUs, resource limits, secrets, and generic
  runtime options.
- Native `ValidateSet`, `ValidateRange`, `ValidatePattern`, and static argument
  completion.
- `-WhatIf` preview, verbose timing, runtime discovery, and focused Docker errors.
- Safe `/PSModule` extraction and installation from container images.
- Inspection for Dockerfiles, Compose, .NET, Node, README, PowerShell, GitHub Actions,
  NUKE, JSON Schema, and OpenAPI directory artifacts.
- Ordered internal plugin stages and typed execution diagnostics.
- Missing-specification initialization and command inference beneath `scripts`.
- Packaging and local execution of inferred scripts and exported module functions.
- Maintained script-only, build-agent, and real-container integration fixtures.
- PowerShell 7.4 Windows and Linux CI, static analysis, coverage enforcement, test
  reports, and container end-to-end validation.
- Genuine PowerShell NuGet package creation, local install verification, and
  release-driven GitHub Packages publishing.
- Docusaurus-compatible Version 1 user, author, reference, architecture, contributor,
  release, security, and troubleshooting documentation.
- MIT license, referenced from the README and the module manifest's `LicenseUri`.
- Markdown link, heading-anchor, and terminology gate enforced in CI by
  `build/Test-Documentation.ps1`.
- Versioned documentation: the newest release is served at the site root and the
  in-progress docs at `/next`, with snapshots cut by `./docs.ps1 -CreateVersion`.
- A published container image, `ghcr.io/the-running-dev/subzerodev.psgenerator`,
  carrying PowerShell 7.4 and the module on the all-users module path with
  `pwsh` as its entry point.
- `Initialize-PSModuleDirectory`, which scaffolds, generates, imports, and
  reports for a directory in one call. Previously a build script that only
  worked from inside a checkout; now a public command, and the natural first
  call when a directory is mounted into the container image.

### Changed

- Restricted inferred PowerShell commands to the directory `scripts` directory.
- Preserved complete script trees and relative dependency paths in generated modules.
- Kept `Build-PSModule` orchestration-only while routing behavior through
  ordered plugins.
- Raised generator and generated manifests to PowerShell 7.4.

### Fixed

- Inference no longer double-verbs a script that is already named `Verb-Noun`.
  `Test-Documentation.ps1` produced `Invoke-TestDocumentation`; it now produces
  `Test-Documentation`, and a lowercase file name such as `write-greeting.ps1`
  produces `Write-Greeting`.
- Empty generated modules now import without requiring a `Public` directory.
- Missing or null JSON Schema property collections are handled consistently.
- Switch parameters normalize to native PowerShell `switch`.
- Metadata validation now occurs before packaging providers run.
- Local NuGet directory verification constructs valid absolute file URIs on Windows
  and Linux.

## Release-Note Process

Before publishing:

1. move relevant unreleased entries into a versioned section;
2. add the release date;
3. identify breaking changes and migration steps;
4. link the GitHub Release; and
5. verify the version matches the module manifest.
