---
title: Changelog
description: Unreleased Version 1 implementation history.
sidebar_position: 6
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
  NUKE, JSON Schema, and OpenAPI repository artifacts.
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

### Changed

- Restricted inferred PowerShell commands to the repository `scripts` directory.
- Preserved complete script trees and relative dependency paths in generated modules.
- Kept `Build-ContainerModule` orchestration-only while routing behavior through
  ordered plugins.
- Raised generator and generated manifests to PowerShell 7.4.

### Fixed

- Empty generated modules now import without requiring a `Public` directory.
- Missing or null JSON Schema property collections are handled consistently.
- Switch parameters normalize to native PowerShell `switch`.
- Metadata validation now occurs before packaging providers run.
- Local NuGet repository verification constructs valid absolute file URIs on Windows
  and Linux.

## Release-note process

Before publishing:

1. move relevant unreleased entries into a versioned section;
2. add the release date;
3. identify breaking changes and migration steps;
4. link the GitHub Release; and
5. verify the version matches the module manifest.
