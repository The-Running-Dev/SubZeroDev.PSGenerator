# Version 1 roadmap

This roadmap is ordered by dependency and release risk. `Specifications.md` defines
the Version 1 behavior contract and remaining boundary; `README.md` describes what
is implemented today. User, contributor, and release documentation is tracked
separately in [`docs/TODO.md`](docs/TODO.md).

Completed implementation history is summarized below instead of occupying the active
work queue.

## Version 1 policy decisions

- PowerShell 7.4 is the minimum supported version.
- Windows and Linux are supported and validated in CI. macOS is best-effort for
  Version 1 and is not a required CI platform.
- Malformed optional repository artifacts should emit actionable warnings and allow
  inspection to continue. Explicitly authoritative inputs, such as files named
  `*.schema.json`, should fail when malformed.
- Version 1 will document and test the supported subset of Compose, GitHub Actions,
  and OpenAPI YAML instead of adding a shared YAML dependency.
- Runtime mappings that depend on repository-specific invocation intent must be
  authored explicitly. Inference must not guess intent from names or paths.

## 1. MVP blockers

- [x] Make `Build-ContainerModule` orchestration-only and keep it as the single public
  build command.
- [x] Add deterministic package regression tests that prove repeated builds produce
  identical files without changing current behavior.
- [x] Build and test a packaged copy of the generator module from a clean location
  instead of testing only the development module under `src/`.
- [x] Add maintained integration fixtures for representative script-only and
  build-agent repositories without embedding external source checkouts.
- [x] Expand `examples/Minimal` into a buildable, runnable container example covering
  generate, build, install, import, invoke, help, and cleanup.
- [x] Verify generated Markdown documentation in the packaged module end-to-end.
- [x] Reconcile `Specifications.md`, `README.md`, command help, examples, and generated
  documentation with the final Version 1 behavior.

## 2. Release quality gates

- [x] Add PowerShell static analysis and formatting checks.
- [x] Measure the packaged-generator coverage baseline, define a minimum acceptable
  threshold, and enforce it in CI.
- [x] Raise generator and generated-module manifests to PowerShell 7.4 and validate
  that baseline explicitly on Windows and Linux.
- [x] Complete the release-blocking documentation journey in
  [`docs/TODO.md`](docs/TODO.md).

## 3. Inspector hardening

Complete these in order so every inspector follows the same policy:

- [ ] Implement the Version 1 malformed-input policy: warn and continue for optional
  artifacts, but fail for explicitly authoritative malformed inputs.
- [ ] Confirm recursive inspectors never traverse generated output, dependency,
  cache, or source-control directories.
- [ ] Add fixtures for multi-project repositories, alternate casing, spaces in paths,
  and symbolic links.
- [ ] Apply focused malformed-input behavior to Dockerfiles, Compose files, project
  manifests, README files, workflows, NUKE configuration, schemas, and OpenAPI
  documents.
- [ ] Test the supported Version 1 subset of Compose, GitHub Actions, and OpenAPI
  YAML; its documentation is tracked separately.
- [ ] Handle Dockerfile continuations, build arguments used by `FROM`, and additional
  instruction metadata.

## 4. End-to-end behavior

- [x] Exercise argument, environment, mount, port, working-directory, volume,
  resource-limit, secret, and runtime-option mappings in the real container test.
- [ ] Exercise device and GPU mappings only on runners that expose the required host
  capabilities; do not make unavailable hardware an MVP blocker.

## 5. Release preparation

- [ ] Complete contributor, policy, and release documentation in
  [`docs/TODO.md`](docs/TODO.md).
- [ ] Finalize module identity, versioning, tags, release notes, and distribution
  approach.
- [ ] Produce a release candidate and run the complete success-criteria workflow from
  a clean machine or runner.

## Version 1 definition of done

- [x] A repository author can define `PSModule/PSModule.psd1` and generate a complete
  module package.
- [x] The generated module is embedded at `/PSModule` in a real image.
- [x] A user can install it with `Install-ContainerModule`, import it, invoke generated
  commands, and use `Get-Help` without manually constructing `docker run` arguments.
- [x] Built-in stages execute through the ordered internal plugin pipeline and expose
  actionable execution diagnostics.
- [x] Direct Pester, hosted Windows and Linux CI, local `act`, and the real container
  end-to-end workflow pass.
- [x] The generator's distributed package is tested from a clean location.
- [x] Documentation accurately distinguishes implemented Version 1 behavior from
  Phase 2 plans.
- [ ] Release quality gates and the clean-run release-candidate workflow pass.

## Completed milestones

- [x] Repository inspection and typed developer diagnostics.
- [x] Validation errors with specification IDs and source context.
- [x] Ordered validator, object-model processor, code-generator,
  template-renderer, Docker runtime-adapter, and packaging-provider plugins.
- [x] Deterministic manifest, loader, command, metadata, and Markdown generation.
- [x] Declarative mappings, validation attributes, static completion, help, and
  `-WhatIf`.
- [x] `/PSModule` container packaging, installation, import, invocation, and cleanup.
- [x] Hosted unit, end-to-end, and code-coverage reporting.
- [x] Missing-specification initialization and PowerShell command inference limited
  to the repository's `scripts` directory.
- [x] Packaging of the complete `scripts` tree and local-repository command testing.
- [x] Empty-module support and malformed JSON Schema handling.
- [x] Installable PowerShell NuGet package validation and release-driven publishing
  to GitHub Packages.

## Deferred to Phase 2

- [ ] Public and stable plugin SDK.
- [ ] Third-party plugin packaging and distribution.
- [ ] Plugin contract versioning and compatibility policy.
- [ ] Extension-model refinement.
- [ ] Object inheritance, templates, composition, and reuse mechanisms.
- [ ] Additional container runtimes such as Podman.
- [ ] Advanced documentation generation, including cross-command tutorials.
