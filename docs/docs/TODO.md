---
title: Documentation roadmap
description: Remaining documentation delivery and review work.
sidebar_position: 99
---

# Documentation roadmap

This backlog tracks user, repository-author, contributor, and release
documentation separately from the engineering roadmap in
[`TODO.md`](https://github.com/The-Running-Dev/SubZeroDev.ContainerPSGenerator/blob/main/TODO.md).
It is ordered by the shortest path from a new user finding
the project to successfully generating, testing, and publishing a container module.

Documentation must describe implemented Version 1 behavior only. Planned Phase 2
contracts should be identified as proposals and must not be presented as stable
features.

## Definition of done

The Version 1 documentation is ready when a person unfamiliar with the repository
can use only the published documentation to:

1. install the generator from GitHub Packages;
2. author or infer a repository specification;
3. generate and import a module;
4. preview and test its commands locally;
5. package the generated module in a container;
6. diagnose common failures; and
7. contribute a tested change to the generator.

Every documented command must be copy-pasteable from the repository root or state
its required working directory. Examples must be exercised manually or by automated
tests before their task is considered complete.

## 1. Release-blocking user journey

- [x] Restructure the root README as a concise landing page containing the project
  purpose, current status, installation command, five-minute example, supported
  platforms, and links to detailed guides.
- [x] Write a clean-machine getting-started guide covering GitHub Packages
  authentication, installation, import, specification creation, generation,
  command discovery, `-WhatIf`, and cleanup.
- [x] Write a repository-author tutorial that starts with an empty repository and
  produces a working `PSModule/PSModule.psd1`, generated module, and container image.
- [x] Write a script-only repository tutorial covering automatic specification
  initialization, the `scripts` directory boundary, inferred script commands,
  exported `.psm1` functions, refresh behavior, and runtime-mapping limitations.
- [x] Create a complete Version 1 specification reference for root properties,
  commands, parameters, stable IDs, mappings, validation, completion, help,
  examples, source kinds, container images, typed-object rejection behavior, and
  the extension boundary.
- [x] Add tested recipes for every supported parameter mapping: Argument,
  Environment, Mount, Volume, Port, WorkingDirectory, Device, Gpu, ResourceLimit,
  Secret, and RuntimeOption.
- [x] Add tested recipes for every supported validation, static-completion, help,
  notes, and structured-example feature.
- [x] Document the generated package layout, `/PSModule` container contract,
  installation lifecycle, replacement safety, module import, and generated Markdown
  command references.
- [x] Write troubleshooting guidance for PowerShell 7.4, Docker availability,
  GitHub Packages credentials, package visibility, `act`, plugin failures,
  malformed specifications, malformed inspected artifacts, missing runtime
  mappings, path resolution, and failed container commands.
- [x] Document Windows and Linux support and clearly identify macOS as unvalidated,
  best-effort Version 1 behavior.

## 2. Reference documentation

- [x] Document each public generator command with purpose, syntax, parameters,
  outputs, side effects, examples, failure behavior, and links to related guides.
- [x] Document every inspection metadata shape and the repository files from which
  it is produced.
- [x] Document the supported Version 1 input subset and malformed-input behavior for
  Dockerfiles, Docker Compose, .NET, Node, README, PowerShell ASTs, GitHub Actions,
  NUKE, JSON Schema, and OpenAPI inspection.
- [x] Document inspector exclusions for generated output, dependencies, caches,
  source-control directories, and nested repositories.
- [x] Write an architecture overview for specification loading, inspection,
  validation, normalization, runtime adaptation, generation, rendering, and
  packaging.
- [x] Document the shared plugin context, stage ordering, discovery convention,
  diagnostics, trust boundary, and current internal contract without promising
  Phase 2 compatibility.
- [x] Add a trusted repository-plugin example spanning at least one inspection stage
  and one generation or packaging stage.
- [x] Document deterministic output guarantees and which artifacts are suitable for
  source control, CI artifacts, container layers, and package feeds.

## 3. Contributor and release operations

- [x] Add a contributor guide with environment setup, branch and PR expectations,
  repository layout, formatting, Pester, coverage, Docker end-to-end tests, and
  local `act` usage.
- [x] Add a security guide with supported-version and private vulnerability-reporting
  guidance.
- [ ] Select and add a `LICENSE`, then reference it from the README and package
  metadata.
- [x] Add a changelog using a consistent release-note format and backfill the
  Version 1 implementation milestones.
- [x] Document module versioning, release-tag format, immutable package versions,
  GitHub Release creation, GitHub Packages publishing, package visibility, and
  rollback or superseding-release procedures.
- [x] Create a release checklist covering version changes, changelog entries,
  documentation review, clean-machine validation, CI, package installation, release
  publication, and post-publication smoke testing.
- [x] Document the CI job matrix, test and coverage reports, package artifact,
  publishing workflow permissions, and which hosted checks cannot be reproduced
  faithfully with `act`.

## 4. Documentation delivery and quality

- [x] Define the documentation navigation and map existing Markdown files into the
  `docs-template` Docusaurus structure without duplicating the root README.
- [ ] Integrate the documentation content with `docs-template` while preserving a
  readable GitHub Markdown experience.
- [ ] Add automated Markdown link validation and spelling or terminology checks with
  focused exclusions for code, generated references, and product names.
- [ ] Add a CI build for the documentation site and fail on broken navigation,
  unresolved links, or Docusaurus compilation errors.
- [ ] Publish versioned documentation for the first release and link it from the
  README, GitHub repository description, and GitHub Release.
- [ ] Perform a clean-reader review that follows the complete user journey without
  relying on source-code knowledge, then record and resolve every ambiguity found.

## Deferred documentation

- [ ] Public third-party plugin SDK documentation.
- [ ] Additional runtime documentation, including Podman.
- [ ] Cross-command tutorials and advanced composition patterns.
- [ ] Versioned migration guides for compatibility changes after Version 1.
